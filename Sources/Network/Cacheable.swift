import Foundation
import Debug
import Cache
import AnyCodable

public enum CachePolicy {
    /// The object will be put in cache but expire immediately.
    /// - Note: This is useful for ensuring data is always returned from cache while still triggering a request.
    case never
    
    /// A timed cache policy.
    /// - Warning: Passing a timed policy with all values set to 0 is not allowed.
    case timed(days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0)
    
    /// The cache will never expire.
    case forever
    
    func asExpiry() -> Expiry? {
        switch self {
        case .never:
            return .seconds(0)
            
        case let .timed(days, hours, minutes, seconds):
            let daysToSeconds = days * 24 * 60 * 60
            let hoursToSeconds = hours * 60 * 60
            let minutesToSeconds = minutes * 60
            
            return .seconds(.init(daysToSeconds + hoursToSeconds + minutesToSeconds + seconds))
            
        case .forever:
            return .never
        }
    }
}

public protocol Cacheable {
    static var cachePolicy: CachePolicy { get }
    
    /// Controls if cached data is returned when observing an endpoint if the data is expired.
    /// If true the observer will receive the cached data back regardless if it is expired or not, a request will still be made if the data is expired.
    /// Default value is true.
    static var returnCachedDataIfExpired: Bool { get }
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
    public static func observe(on object: AnyObject, given parameters: P, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> ObserverToken {
        var observer: ObserverToken?
        return observe(on: object, given: parameters, observer: &observer, delegate: delegate, dataCallback: dataCallback)
    }
    
    @discardableResult
    public static func observe(on object: AnyObject, given parameters: P, observer: inout ObserverToken?, delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, dataCallback: @escaping (_ data: Self) -> Void) -> ObserverToken {
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
        
        observer = observerToken
                                
        var isExpired = (try? networkManager.isObjectExpired(for: request.id)) ?? true
        
        // If the new cache policy would expire before the existing cached expiry date, set isExpired to true.
        if
            let cacheExpiryDate = try? networkManager.expiry(for: request.id).date,
            let newExpiryDate = Self.cachePolicy.asExpiry()?.date,
            cacheExpiryDate.distance(to: newExpiryDate) < 0
        {
            isExpired = true
        }
        
        // Return any cached data if not expired or expired data is allowed.
        if isExpired == false || returnCachedDataIfExpired {
            // Decode the data.
            if let cachedData: Self = try? networkManager.get(object: request.id) {
                dataCallback(cachedData)
            } else if
                let cachedData: [String: Any] = try? networkManager.get(object: request.id),
                let decodedData = DictionaryDecoder().decode(Self.self, from: cachedData)
            {
                dataCallback(decodedData)
            } else { // if the data is unable to be decoded, set isExpired to true and delete the cached object.
                isExpired = true
                try? networkManager.remove(object: request.id)
            }
        }
        
        if isExpired {
            networkManager.enqueue(request)
        }
        
        return observerToken
    }
}

extension Cacheable where Self: Requestable, Self.P == NoParameters {
    @discardableResult
    public static func observe(on object: AnyObject, observer: inout ObserverToken?, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> ObserverToken {
        observe(on: object, given: .none, observer: &observer, delegate: delegate, dataCallback: dataCallback)
    }
    
    @discardableResult
    public static func observe(on object: AnyObject, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> ObserverToken {
        var observer: ObserverToken?
        return observe(on: object, given: .none, observer: &observer, delegate: delegate, dataCallback: dataCallback)
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
}
