import Foundation
import Debug
import Cache

public protocol RequestableResponse: Codable {
    associatedtype P: NetworkParameters
    
    static var method: RequestMethod { get }
    static func url(given parameters: P) -> URL
    static func headers(given parameters: P) -> [String: String]?
    static func handle(response: URLResponse, data: Data?) -> Error?
}

extension RequestableResponse {
    public static func headers(given parameters: P) -> [String: String]? { nil }
    
    public static func fetch(given parameters: P, delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, dataCallback: @escaping (Self) -> Void) {
        let requestTask = Self.requestTask(given: parameters, delegate: delegate, dataCallback: dataCallback)
                
        if Self.self is Cacheable.Type {
            let isExpired = (try? networkManager.isObjectExpired(for: requestTask.id)) ?? true
            if isExpired {
                networkManager.enqueue(requestTask)
            } else if let data: Self = try? networkManager.get(object: requestTask.id) {
                dataCallback(data)
            }
        } else {
            networkManager.enqueue(requestTask)
        }
    }
    
    /// Create a URLSessionNetworkTask for a request response.
    /// - Parameter parameters: The parameters for the network response.
    /// - Returns: A URL session task. (QueueableTask)
    public static func requestTask(given parameters: P, delegate: RequestDelegateConfig?, dataCallback: @escaping (Self) -> Void) -> QueueableTask {
        URLSessionNetworkTask(
            method: method,
            url: url(given: parameters),
            parameters: parameters,
            headers: headers(given: parameters),
            cachePolicy: (Self.self as? Cacheable.Type)?.cachePolicy,
            dataCallback: dataCallback,
            delegate: delegate
        )
    }
}

extension RequestableResponse where P == NoParameters {
    /// Create a URLSessionNetworkTask for a request response without any parameter requirements.
    /// - Returns: The URL session task. (QueueableTask)
    public static func requestTask(delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> QueueableTask {
        requestTask(given: .none, delegate: delegate, dataCallback: dataCallback)
    }
}

public enum RequestMethod: String {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case trace = "TRACE"
    case options = "OPTIONS"
    case connect = "CONNECT"
    case patch = "PATCH"
}
