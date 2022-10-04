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

public class QueueManager {
    public static let shared = QueueManager()
    private let lock = NSLock()
    private var queues = [QueueDefinition: TaskQueue]()

    public func set(priority: Operation.QueuePriority, for id: QueueableTask.ID) {
        defer { lock.unlock() }
        lock.lock()

        queues.forEach { $0.value.set(priority: priority, for: id) }
    }

    public func enqueue<Task: QueueableTask>(task: Task) {
        defer { lock.unlock() }
        lock.lock()

        var queue = queues[task.queueDefinition]
        if queue == nil {
            queue = .init(definition: task.queueDefinition)
            queues[task.queueDefinition] = queue
        }

        queue!.enqueue(task: task)
    }
}
