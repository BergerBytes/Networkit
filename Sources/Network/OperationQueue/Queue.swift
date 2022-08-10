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

public struct QueueDefinition: Hashable {
    public enum ConcurrentTaskPolicy: Hashable {
        case noLimit
        case limit(UInt)
    }
    
    public let id: String
    public let qualityOfService: QualityOfService
    public let concurrentTaskPolicy: ConcurrentTaskPolicy

    public init(id: String, qualityOfService: QualityOfService = .default, concurrentTaskPolicy: QueueDefinition.ConcurrentTaskPolicy) {
        self.id = id
        self.qualityOfService = qualityOfService
        self.concurrentTaskPolicy = concurrentTaskPolicy
    }
}

public struct DynamicQueueDefinition {
    public enum Rule {
        case priority(ClosedRange<QueuePriority>, to: QueueDefinition)
    }
    
    public let defaultQueue: QueueDefinition
    public let rules: [Rule]

    public init(defaultQueue: QueueDefinition, rules: [Rule]) {
        self.defaultQueue = defaultQueue
        self.rules = rules
    }
}

public enum QueuePolicy {
    case single(queue: QueueDefinition)
    case dynamic(DynamicQueueDefinition)
}

public typealias QueuePriority = Int

public extension QueuePriority {
    static let lowest = Int.min
    static let veryLow = -8
    static let low = -4
    static let normal = 0
    static let high = 4
    static let veryHigh = 8
    static let highest = Int.max
}

let foo = DynamicQueueDefinition(
    defaultQueue: .default,
    rules: [.priority(.lowest ... .highest, to: .default)]
)
