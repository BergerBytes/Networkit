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

import Debug
import Foundation

class TaskQueue {
    private lazy var internalThread = DispatchQueue(label: "com.network.queue.\(definition.id)")
    private let definition: QueueDefinition
    private var operations = NSHashTable<TaskOperation>.weakObjects()

    private let pendingQueue: PriorityQueue<TaskOperation>
    private let operationQueue: OperationQueue

    private var operationCount = 0

    init(definition: QueueDefinition) {
        self.definition = definition
        pendingQueue = .init()
        operationQueue = .init()

        operationQueue.maxConcurrentOperationCount = definition.concurrentTaskPolicy.maxConcurrentOperationCount
    }

    func set(priority: Operation.QueuePriority, for id: QueueableTask.ID) {
        internalThread.async {
            self.pendingQueue.update(priority: priority, of: id)
        }
    }

    func enqueue(task: QueueableTask) {
        internalThread.async {
            if
                let mergable = task as? MergableTask,
                let activeTask = self.operations.allObjects.first(where: {
                    $0.isFinished == false && $0.id == task.id
                })?.task as? MergableTask,
                mergable.shouldBeMerged(with: activeTask)
            {
                do {
                    try mergable.merge(into: activeTask)
                    return
                } catch {
                    Log.error(
                        "Failed to merge tasks, queuing new task.",
                        params: ["New Task": mergable, "Existing Task": activeTask, "error": error]
                    )
                }
            }

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
            }

            self.operations.add(operation)
            if self.operationCount >= self.operationQueue.maxConcurrentOperationCount {
                self.pendingQueue.enqueue(operation)
            } else {
                self.operationCount += 1
                self.operationQueue.addOperation(operation)
            }
        }
    }
}
