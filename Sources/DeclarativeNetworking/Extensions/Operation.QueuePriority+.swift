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

import Foundation

extension Operation.QueuePriority: CustomStringConvertible {
    public var description: String {
        switch self {
        case .veryLow:
            return "veryLow"

        case .low:
            return "low"

        case .normal:
            return "normal"

        case .high:
            return "high"

        case .veryHigh:
            return "veryHigh"

        @unknown default:
            return "unknown"
        }
    }

    func increment() -> Self {
        switch self {
        case .veryLow:
            return .normal

        case .low:
            return .normal

        case .normal:
            return .high

        case .high:
            return .veryHigh

        case .veryHigh:
            return .veryHigh

        @unknown default:
            return self
        }
    }

    func decrement() -> Self {
        switch self {
        case .veryLow:
            return .veryLow

        case .low:
            return .veryLow

        case .normal:
            return .low

        case .high:
            return .normal

        case .veryHigh:
            return .high

        @unknown default:
            return self
        }
    }
}
