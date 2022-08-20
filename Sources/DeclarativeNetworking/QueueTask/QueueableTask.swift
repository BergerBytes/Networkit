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

open class QueueableTask: Identifiable, Hashable {
    public let id: String
    public let type: TaskType

    open var priority: Operation.QueuePriority = .normal

    public init(id: String, type: TaskType) {
        self.id = id
        self.type = type
    }

    open func preProcess() async { }

    open func process() async { }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: QueueableTask, rhs: QueueableTask) -> Bool {
        lhs.id == rhs.id
    }
}

public extension QueueableTask {
    struct TaskType {
        let name: String

        public init(name: String) {
            self.name = name
        }

        public static let standard = TaskType(name: "standard")
    }
}

// MARK: - Operation Creation

extension QueueableTask {
    func newOperation() -> TaskOperation {
        TaskOperation(task: self)
    }
}