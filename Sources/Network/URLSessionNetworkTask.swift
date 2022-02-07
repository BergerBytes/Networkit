import Debug
import Foundation

public typealias NetworkParameters = Hashable

public protocol EncodableNetworkParameters: NetworkParameters & Encodable {
    func asURL() -> [String: Any]?
    func asBody() -> Data?
}

public protocol URLNetworkParameters: EncodableNetworkParameters { }
public extension URLNetworkParameters {
    func asBody() -> Data? { nil }
    func asURL() -> [String : Any]? {
        try? DictionaryEncoder().encode(self)
    }
}

public protocol BodyNetworkParameters: EncodableNetworkParameters { }
public extension BodyNetworkParameters {
    func asURL() -> [String : Any]? { nil }
    func asBody() -> Data? {
        try? JSONEncoder().encode(self)
    }
}

public struct NoParameters: NetworkParameters {
    private init() {}
    public static let none = NoParameters()
}

/// A Network task that should be merged if the same request is found already queued.
public protocol MergableRequest: QueueableTask {
    var delegate: MulticastDelegate<RequestDelegate> { get }
    var delegateId: Identifiable? { get }
    
    /// Check for wether or this task should be merged with the provided task.
    /// - Parameter task: The task to merge with.
    /// - Returns: Booll True if tasks should be merged.
    func shouldBeMerged(with task: MergableRequest) -> Bool
}

public class URLSessionNetworkTask<R: Codable, P: NetworkParameters>: QueueableTask {
    enum Errors: Error {
        case invalidURL
    }
    
    private let urlSession: URLSession
    
    private let method: RequestMethod
    private let url: URL
    private let parameters: P
    private let headers: [String: String]?
    private let cachePolicy: CachePolicy?
    public var dataCallbacks = [(R) -> Void]()
    public let delegate = MulticastDelegate<RequestDelegate>()
    public let delegateId: Identifiable?
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
        self.headers = headers
        self.cachePolicy = cachePolicy
        if let dataCallback = dataCallback {
            self.dataCallbacks.append(dataCallback)
        }
        self.delegate += delegate?.delegate
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
        
        delegate.invokeDelegates { $0.requestStarted(id: delegateId) }
        
        let encodableParameters = parameters as? EncodableNetworkParameters
                
        guard
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            failed(error: Errors.invalidURL)
            return
        }
        
        urlComponents.queryItems = encodableParameters?.asURL()?.compactMap { key, value in
            URLQueryItem(name: key, value: "\(value)")
        }
        
        guard
            let url = urlComponents.url
        else {
            failed(error: Errors.invalidURL)
            return
        }
        
        var urlRequest = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 100
        )
        
        urlRequest.httpMethod = method.rawValue
        urlRequest.httpBody = encodableParameters?.asBody()
        
        headers?.forEach { key, value in
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
        
        do {
            if #available(iOS 15.0, *) {
                let (data, response) = try await urlSession.data(for: urlRequest)
                let decodedData = try JSONDecoder().decode(R.self, from: data)
                complete(response: decodedData)
            } else {
                let task = urlSession.dataTask(with: urlRequest) { data, response, error in
                    do {
                        if let error = error {
                            self.failed(error: error)
                            return
                        }
                        
                        guard let data = data else {
                            return
                        }
                        
                        let decodedData = try JSONDecoder().decode(R.self, from: data)
                        self.complete(response: decodedData)
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
        delegate.invokeDelegates { $0.requestCompleted(id: delegateId) }
        dataCallbacks.forEach { $0(response) }

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
        delegate.invokeDelegates { $0.requestFailed(id: delegateId, error: error) }
    }

}

// MARK: - MergableRequest

extension URLSessionNetworkTask: MergableRequest {
    public func shouldBeMerged(with task: MergableRequest) -> Bool {
        guard let task = task as? Self else { return false }
        return id == task.id
    }
}
