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

/// An operation to execute a QueueableTask
public class TaskOperation: Operation {
    private let lockQueue = DispatchQueue(label: "com.queuetask.taskoperation", attributes: .concurrent)

    var id: String { task.id }
    let task: QueueableTask

    public override var isAsynchronous: Bool {
        true
    }

    public init(task: QueueableTask) {
        self.task = task
        super.init()
        queuePriority = task.priority
    }

    @available(*, unavailable, message: "TaskOperations should never be started directly!")
    public override func start() {
        isFinished = false
        isExecuting = true
        main()
    }

    public override func main() {
        Task {
            await task.preProcess()
            await task.process()
            finish()
        }
    }

    func finish() {
        isExecuting = false
        isFinished = true
    }

    public override var description: String {
        "Operation: STARTED: \(isExecuting), PRIORITY: \(queuePriority.description) \"\(task.id.components(separatedBy: ".com").last!.split(separator: "|").first!.replacingOccurrences(of: " ", with: ""))\""
    }

    private var _isExecuting: Bool = false
    public override private(set) var isExecuting: Bool {
        get {
            lockQueue.sync { () -> Bool in
                _isExecuting
            }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lockQueue.sync(flags: [.barrier]) {
                _isExecuting = newValue
            }
            didChangeValue(forKey: "isExecuting")
        }
    }

    private var _isFinished: Bool = false
    public override private(set) var isFinished: Bool {
        get {
            lockQueue.sync { () -> Bool in
                _isFinished
            }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lockQueue.sync(flags: [.barrier]) {
                _isFinished = newValue
            }
            didChangeValue(forKey: "isFinished")
        }
    }
}
