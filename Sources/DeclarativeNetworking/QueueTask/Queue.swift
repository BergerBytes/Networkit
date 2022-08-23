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

public class QueueManager {
    var queues = [QueueDefinition: Queue]()
    
    func enqueue<Task: QueueableTask>(task: Task) {
        queues[task.queueDefinition, default: .init(definition: task.queueDefinition)]
            .enqueue(task: task)
    }
}

class Queue {
    private lazy var internalThread = DispatchQueue(label: "com.network.queue.\(definition.id)")
    private let definition: QueueDefinition
    private let pendingQueue: PriorityQueue<TaskOperation>
    private let operationQueue: OperationQueue
    private var operationCount = 0
    
    init(definition: QueueDefinition) {
        self.definition = definition
        pendingQueue = .init()
        operationQueue = .init()
        if case let .limit(count) = definition.concurrentTaskPolicy {
            operationQueue.maxConcurrentOperationCount = Int(count)
        }
    }
    
    func enqueue(task: QueueableTask) {
        internalThread.async {
            let operation = task.newOperation()
            operation.completionBlock = { [weak self] in
                guard let self = self else { return }
                self.internalThread.async {
                    self.operationCount -= 1
                    while
                        self.operationCount < self.operationQueue.maxConcurrentOperationCount,
                        let next = self.pendingQueue.dequeue()
                    {
                        self.operationCount += 1
                        self.operationQueue.addOperation(next)
                    }
                }
                
                if self.operationCount >= self.operationQueue.maxConcurrentOperationCount {
                    self.pendingQueue.enqueue(operation)
                } else {
                    self.operationCount += 1
                    self.operationQueue.addOperation(operation)
                }
            }
        }
    }
}
