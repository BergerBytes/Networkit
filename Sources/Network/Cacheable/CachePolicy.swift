import Cache
import Foundation

public enum CachePolicy {
    /// The object will be put in cache but expire immediately.
    /// - Note: This is useful for ensuring data is always returned from cache while still triggering a request.
    case expireImmediately
    
    /// A timed cache policy.
    /// - Warning: Passing a timed policy with all values set to 0 is not allowed.
    case timed(days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0)
    
    /// The cache will never expire.
    case forever
    
    func asExpiry() -> Expiry? {
        switch self {
        case .expireImmediately:
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
