import Debug
import Foundation

public typealias NetworkParameters = Encodable & Hashable

public struct NoParameters: NetworkParameters {
    private init() {}
    public static let none = NoParameters()
}

public class URLSessionNetworkTask<R: Codable, P: NetworkParameters>: QueueableTask {
    private let urlSession: URLSession
    
    private let method: RequestMethod
    private let url: URL
    private let parameters: P
    private let cachePolicy: CachePolicy?
    private let dataCallback: ((R) -> Void)?
    private weak var delegate: RequestDelegate?
    private let delegateId: Identifiable?
    private let networkManager: NetworkManager
    
    required init(
        urlSession: URLSession = .shared,
        method: RequestMethod,
        url: URL,
        parameters: P,
        headers: [String: String]?,
        cachePolicy: CachePolicy?,
        dataCallback: ((R) -> Void)?,
        delegate: RequestDelegateConfig?,
        networkManager: NetworkManager = .shared
    ) {
        self.urlSession = urlSession
        
        self.method = method
        self.url = url
        self.parameters = parameters
        self.cachePolicy = cachePolicy
        self.dataCallback = dataCallback
        self.delegate = delegate?.delegate
        self.delegateId = delegate?.id
        self.networkManager = networkManager
        
        var hasher = Hasher()
        hasher.combine(method)
        hasher.combine(url)
        hasher.combine(parameters)
        
        super.init(id: "\(url) | \(hasher.finalize())", type: .standard)
    }
    
    public override func process() async {
        await super.process()
        
        delegate?.requestStarted(id: delegateId)
        
        do {
            if #available(iOS 15.0, *) {
                let (data, _) = try await urlSession.data(from: url)
                let response = try JSONDecoder().decode(R.self, from: data)
                complete(response: response)
            } else {
                let task = urlSession.dataTask(with: URLRequest(url: url)) { data, _, error in
                    do {
                        if let error = error {
                            self.failed(error: error)
                            return
                        }
                        
                        guard let data = data else {
                            return
                        }
                        
                        let response = try JSONDecoder().decode(R.self, from: data)
                        self.complete(response: response)
                    }
                    catch {
                        Debug.log(error: error)
                        self.failed(error: error)
                    }
                }
                task.resume()
                while task.state == .running {
                    try await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))
                }
            }
        }
        catch {
            Debug.log(error: error)
            failed(error: error)
        }
    }
    
    open func complete(response: R) {
        delegate?.requestCompleted(id: delegateId)
        dataCallback?(response)

        if let cachePolicy = cachePolicy {
            do {
                try networkManager.storage.setObject(.init(response), forKey: id, expiry: cachePolicy.asExpiry())
            }
            catch {
                Debug.log(error: error)
            }
        }
    }
    
    open func failed(error: Error) {
        delegate?.requestFailed(id: delegateId, error: error)
    }
}
