import Foundation

open class QueueableTask: Identifiable {
    public let id: String
    public let type: TaskType

    open var priority: Operation.QueuePriority = .normal
    
    public init(id: String, type: TaskType) {
        self.id = id
        self.type = type
    }
    
    open func preProcess() async { }
    
    open func process() async { }
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
