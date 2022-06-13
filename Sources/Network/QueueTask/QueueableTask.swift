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

extension QueueableTask {
    public struct TaskType {
        let name: String

        public init(name: String) {
            self.name = name
        }
        
        public static let standard = TaskType(name: "standard")
    }
}

// MARK: - Operation Creation

extension QueueableTask {
    internal func newOperation() -> TaskOperation {
        TaskOperation(task: self)
    }
}
