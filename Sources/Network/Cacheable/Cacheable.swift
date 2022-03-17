import Foundation
import Debug
import Cache
import AnyCodable

public protocol Cacheable {
    static var cachePolicy: CachePolicy { get }
    
    /// Controls if cached data is returned when observing an endpoint if the data is expired.
    /// If true the observer will receive the cached data back regardless if it is expired or not, a request will still be made if the data is expired.
    /// Default value is true.
    static var returnCachedDataIfExpired: Bool { get }
}

enum CacheableError: Error {
    case failedToDecode
}

public extension Cacheable {
    static var returnCachedDataIfExpired: Bool { true }
}

public typealias CacheableResponse = Requestable & Cacheable

extension Cacheable where Self: Requestable {
    public static func fetch(given parameters: P, delegate: RequestDelegateConfig? = nil, with networkManager: NetworkManagerProvider = NetworkManager.shared) {
        fetch(given: parameters, delegate: delegate, with: networkManager, dataCallback: { _ in })
    }
    
    @discardableResult
    public static func observe(on object: AnyObject, given parameters: P, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        var token: CancellationToken?
        return observe(on: object, given: parameters, token: &token, delegate: delegate, dataCallback: dataCallback)
    }
    
    @discardableResult
    public static func observe(on object: AnyObject, given parameters: P, token: inout CancellationToken?, delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        token?.cancel()
        
        let request = Self.requestTask(given: parameters, delegate: delegate, dataCallback: { _ in })
        
        let observerToken = networkManager.addObserver(for: request.id, on: object) { data in
            guard
                let value = data.value as? Self
            else {
                Debug.log(level: .error, "Type mismatch", params: ["Expected Type" : Self.self])
                return
            }
            
            DispatchQueue.main.async {
                dataCallback(value)
            }
        }
        
        token = observerToken
                                
        var isExpired = (try? networkManager.isObjectExpired(for: request.id)) ?? true
        
        // If the new cache policy would expire before the existing cached expiry date, set isExpired to true.
        if
            let cacheExpiryDate = try? networkManager.expiryDate(for: request.id),
            let newExpiryDate = Self.cachePolicy.asExpiry()?.date,
            cacheExpiryDate.distance(to: newExpiryDate) < 0
        {
            isExpired = true
        }
        
        // Return any cached data if not expired or expired data is allowed.
        if isExpired == false || returnCachedDataIfExpired {
            switch cachedData(for: request.id, with: networkManager) {
            case let .success(data):
                dataCallback(data)
                
            case .failure: // if the data is unable to be decoded, set isExpired to true and delete the cached object.
                isExpired = true
                try? networkManager.remove(object: request.id)
            }
        }
        
        if isExpired {
            networkManager.enqueue(request)
        }
        
        return observerToken
    }
    
    /// Ensures valid data exists for the given requestable. If no cache data is found or it fails to decode the data will be fetched in the background.
    /// - Parameters:
    ///   - parameters: The parameters for the requestable.
    ///   - networkManager: Injected network manager.
    public static func fillCache(given parameters: P, with networkManager: NetworkManagerProvider = NetworkManager.shared) {
        let request = Self.requestTask(given: parameters, delegate: nil, dataCallback: nil)
        if case .failure = cachedData(for: request.id, with: networkManager) {
            networkManager.enqueue(request)
        }
    }
}

extension Cacheable where Self: Requestable, Self.P == NoParameters {
    @discardableResult
    public static func observe(on object: AnyObject, token: inout CancellationToken?, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        observe(on: object, given: .none, token: &token, delegate: delegate, dataCallback: dataCallback)
    }
    
    @discardableResult
    public static func observe(on object: AnyObject, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        var token: CancellationToken?
        return observe(on: object, given: .none, token: &token, delegate: delegate, dataCallback: dataCallback)
    }
    
    public static func fetch(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false) {
        fetch(delegate: delegate, with: networkManager, force: force, dataCallback: { _ in })
    }
    
    public static func fetch(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false, dataCallback: @escaping (Self) -> Void) {
        let requestTask = Self.requestTask(given: .none, delegate: delegate, dataCallback: dataCallback)
        
        let isExpired = (try? networkManager.isObjectExpired(for: requestTask.id)) ?? true
        Debug.log("Is Expired: \(isExpired)")
        if isExpired || force {
            networkManager.enqueue(requestTask)
        }
    }
    
    /// NoParameters convenience version of of ``fillCache(given:with:)``
    public static func fillCache(with networkManager: NetworkManagerProvider = NetworkManager.shared) {
        let request = Self.requestTask(given: .none, delegate: nil, dataCallback: nil)
        if case .failure = cachedData(for: request.id, with: networkManager) {
            networkManager.enqueue(request)
        }
    }
}

extension Cacheable where Self: Requestable {
    /// Returns any cached data found in storage regardless of it's expiration.
    private static func cachedData(for id: String, with networkManager: NetworkManagerProvider) -> Result<Self, Error> {
        if let cachedData: Self = try? networkManager.get(object: id) {
            return .success(cachedData)
        } else if
            let cachedData: [String: Any] = try? networkManager.get(object: id),
            let decodedData = DictionaryDecoder().decode(Self.self, from: cachedData)
        {
            return .success(decodedData)
        } else {
            return .failure(CacheableError.failedToDecode)
        }
    }
}
