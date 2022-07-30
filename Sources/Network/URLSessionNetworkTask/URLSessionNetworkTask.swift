import CryptoKit
import Debug
import Foundation

public class URLSessionNetworkTask<R: Requestable>: QueueableTask {
    enum Errors: Error {
        case invalidURL
        case noResponse
    }
    
    private let urlSession: URLSession
    
    private let method: RequestMethod
    private let url: URL
    private let parameters: R.P
    private let headers: [String: String]?
    private let cachePolicy: CachePolicy?
    public var dataCallbacks = [(R) -> Void]()
    public let delegate = MulticastDelegate<RequestDelegate>()
    public let requestIdentifier: RequestIdentifier?
    private let networkManager: NetworkManagerProvider
    public var resultCallbacks = [(Result<R, Error>) -> Void]()
    
    public required init(
        urlSession: URLSession = .shared,
        method: RequestMethod,
        url: URL,
        parameters: R.P,
        headers: [String: String]?,
        cachePolicy: CachePolicy?,
        dataCallback: ((R) -> Void)?,
        delegate: RequestDelegateConfig?,
        resultCallback: ((Result<R, Error>) -> Void)? = nil,
        networkManager: NetworkManagerProvider = NetworkManager.shared
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
        self.requestIdentifier = delegate?.id
        
        if let resultCallback = resultCallback {
            self.resultCallbacks.append(resultCallback)
        }
        self.networkManager = networkManager
                
        super.init(id: R.generateId(given: parameters), type: .standard)
        
        if self.dataCallbacks.isEmpty {
            priority = .veryLow
        }
    }
    
    public override func process() async {
        await super.process()
        
        DispatchQueue.main.sync {
            delegate.invokeDelegates { $0.requestStarted(id: requestIdentifier) }
        }
                        
        guard
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            failed(error: Errors.invalidURL)
            return
        }
        
        urlComponents.queryItems = parameters.asQuery()?.compactMap { key, value in
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
        urlRequest.httpBody = parameters.asBody()
        
        headers?.forEach { key, value in
            urlRequest.addValue(value, forHTTPHeaderField: key)
        }
        
        do {
            if #available(iOS 15.0, macOS 12.0, *) {
                let (data, response) = try await urlSession.data(for: urlRequest)
                
                if let error = R.handle(response: response, data: data) {
                    failed(error: error)
                    return
                }
                
                let decodedData = try R.decoder.decode(R.self, from: data)
                complete(response: decodedData, data: data)
            } else {
                let task = urlSession.dataTask(with: urlRequest) { data, response, error in
                    do {
                        if let error = error {
                            self.failed(error: error)
                            return
                        }
                        
                        guard
                            let response = response
                        else {
                            self.failed(error: Errors.noResponse)
                            return
                        }
                        
                        if let error = R.handle(response: response, data: data) {
                            self.failed(error: error)
                            return
                        }
                        
                        guard let data = data else {
                            self.failed(error: Errors.noResponse)
                            return
                        }
                        
                        let decodedData = try R.decoder.decode(R.self, from: data)
                        self.complete(response: decodedData, data: data)
                    }
                    catch {
                        Log.error(in: .network, error)
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
            Log.error(in: .network, error)
            failed(error: error)
        }
    }
    
    open func complete(response: R, data: Data) {
        DispatchQueue.main.sync {
            if let cachePolicy = cachePolicy {
                do {
                    try networkManager.save(object: data, key: id, cachePolicy: cachePolicy)
                }
                catch {
                    Log.error(in: .network, error)
                }
            }
            
            resultCallbacks.forEach { $0(.success(response)) }
            
            self.delegate.invokeDelegates { $0.requestCompleted(id: self.requestIdentifier) }
            self.dataCallbacks.forEach { $0(response) }
        }
    }
    
    open func failed(error: Error) {
        DispatchQueue.main.sync {
            resultCallbacks.forEach { $0(.failure(error)) }
            self.delegate.invokeDelegates { $0.requestFailed(id: self.requestIdentifier, error: error) }
        }
    }
}

// MARK: - MergableRequest

extension URLSessionNetworkTask: MergableRequest {
    public func shouldBeMerged(with task: MergableRequest) -> Bool {
        guard let task = task as? Self else { return false }
        return id == task.id
    }
    
    public func merge(into existingTask: MergableRequest) throws {
        existingTask.delegate += delegate
        if let existingTask = existingTask as? URLSessionNetworkTask<R> {
            existingTask.resultCallbacks += resultCallbacks
            existingTask.dataCallbacks += dataCallbacks
        }
    }
}

// MARK: - CustomDebugStringConvertible

extension URLSessionNetworkTask: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(id) | \(priority)"
    }
}
