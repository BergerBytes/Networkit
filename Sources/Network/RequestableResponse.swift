import Foundation
import Debug
import Cache

public protocol RequestableResponse: Codable {
    associatedtype P: NetworkParameters
    
    static var method: RequestMethod { get }
    static func url(given parameters: P) -> URL
    static func headers(given parameters: P) -> [String: String]?
}

extension RequestableResponse {
    public static func headers(given parameters: P) -> [String: String]? { nil }
    
    public static func fetch(given parameters: P, with networkManager: NetworkManager = .shared, dataCallback: @escaping (Self) -> Void) {
        let requestTask = Self.requestTask(given: parameters, dataCallback: dataCallback)
        
        if Self.self is CacheableResponse.Type {
            let isExpired = (try? networkManager.storage.isExpiredObject(forKey: requestTask.id)) ?? true
            Debug.log("Is Expired: \(isExpired)")
            if isExpired {
                networkManager.enqueue(requestTask)
            } else if let data: Self = (try? networkManager.storage.object(forKey: requestTask.id))?.value as? Self {
                dataCallback(data)
            }
        } else {
            networkManager.enqueue(requestTask)
        }
    }
    
    /// Create a URLSessionNetworkTask for a request response.
    /// - Parameter parameters: The parameters for the network response.
    /// - Returns: The URL session task.
    static func requestTask(given parameters: P, dataCallback: @escaping (Self) -> Void) -> URLSessionNetworkTask<Self, P> {
        URLSessionNetworkTask(
            method: method,
            url: url(given: parameters),
            parameters: parameters,
            headers: headers(given: parameters),
            cachePolicy: (Self.self as? CacheableResponse.Type)?.cachePolicy,
            dataCallback: dataCallback
        )
    }
}

extension RequestableResponse where P == NoParameters {
    /// Create a URLSessionNetworkTask for a request response without any parameter requirements.
    /// - Returns: The URL session task.
    static func requestTask(observer: @escaping (_ data: Self) -> Void) -> URLSessionNetworkTask<Self, P> {
        requestTask(given: .none, dataCallback: observer)
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
