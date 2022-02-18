import Foundation
import Cache
import CryptoKit
import Debug

public protocol RequestableResponse: Codable {
    associatedtype P: NetworkParameters
    
    static var method: RequestMethod { get }
    static func url(given parameters: P) -> URL
    static func headers(given parameters: P) -> [String: String]?
    static func handle(response: URLResponse, data: Data?) -> Error?
    static func generateId(given parameters: P) -> String
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
    
    public static func generateId(given parameters: P) -> String {
        let urlString = url(given: parameters).absoluteString
        guard
            let encodedParameters = try? JSONEncoder().encode(parameters),
            let hash = try? SHA256.hash(data: JSONEncoder().encode([method.rawValue, urlString, String(decoding: encodedParameters, as: UTF8.self)]))
        else {
            Debug.log(
                level: .error,
                "Failed to runtime agnostically hash a URLSessionNetworkTask id. Falling back to Hasher().",
                params: [
                    "Response Type": "\(Self.self)",
                    "Parameters Type": "\(P.self)",
                    "URL": "\(urlString)",
                    "method": method.rawValue,
                ]
            )
            
            var hasher = Hasher()
            hasher.combine(method)
            hasher.combine(urlString)
            hasher.combine(parameters)
            
            return "\(urlString) | \(hasher.finalize())"
        }

        let stringHash = hash.map { String(format: "%02hhx", $0) }.joined()
        return "\(urlString) | \(stringHash)"
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
