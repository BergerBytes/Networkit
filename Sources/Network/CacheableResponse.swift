import Foundation
import Debug
import Cache

public enum CachePolicy {
    case never
    
    /// A timed cache policy
    /// - Warning: Passing a timed policy with all values set to 0 is not allowed.
    case timed(days: Int = 0, hours: Int = 0, minutes: Int = 0)
    case forever
    
    func asExpiry() -> Expiry? {
        switch self {
        case .never:
            return nil
            
        case .timed(let days, let hours, let minutes):
            let daysToSeconds = days * 24 * 60 * 60
            let hoursToSeconds = hours * 60 * 60
            let minutesToSeconds = minutes * 60
            
            return .seconds(.init(daysToSeconds + hoursToSeconds + minutesToSeconds))
            
        case .forever:
            return .never
        }
    }
}

public protocol CacheableResponse: RequestableResponse {
    static var cachePolicy: CachePolicy { get }
}

extension CacheableResponse {
    public static func fetch(given parameters: P, with networkManager: NetworkManager = .shared) {
        fetch(given: parameters, with: networkManager, dataCallback: { _ in })
    }
    
    @discardableResult
    public static func observe(on object: AnyObject, given parameters: P, with networkManager: NetworkManager = .shared, observer: @escaping (_ data: Self) -> Void) -> ObserverToken {
        let request = Self.requestTask(given: parameters, dataCallback: { _ in })
                
        let token = networkManager.addObserver(for: request.id, on: object) { data in
            guard
                let value = data.value as? Self
            else {
                Debug.log(level: .error, "Type mismatch", params: ["Expected Type" : Self.self])
                return
            }
            
            DispatchQueue.main.async {
                observer(value)
            }
        }
        
        let isExpired = try? networkManager.storage.isExpiredObject(forKey: request.id)
        if isExpired != false {
            NetworkManager.shared.enqueue(request)
        }
        
        // Return any cached data.
        if let cachedData = (try? networkManager.storage.object(forKey: request.id))?.value as? Self {
            observer(cachedData)
        }
        
        return token
    }
}

extension CacheableResponse where Self.P == NoParameters {
    @discardableResult
    public static func observe(on object: AnyObject, observer: @escaping (_ data: Self) -> Void) -> ObserverToken {
        observe(on: object, given: .none, observer: observer)
    }
    
    public static func fetch(with networkManager: NetworkManager = .shared, force: Bool = false) {
        fetch(with: networkManager, force: force, dataCallback: { _ in })
    }
    
    public static func fetch(with networkManager: NetworkManager = .shared, force: Bool = false, dataCallback: @escaping (Self) -> Void) {
        let requestTask = Self.requestTask(given: .none, dataCallback: dataCallback)
        
        let isExpired = (try? networkManager.storage.isExpiredObject(forKey: requestTask.id)) ?? true
        Debug.log("Is Expired: \(isExpired)")
        if isExpired || force {
            networkManager.enqueue(requestTask)
        }
    }
}
