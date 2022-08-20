//  Copyright © 2022 BergerBytes LLC. All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED  AS IS AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

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
