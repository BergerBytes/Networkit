import Foundation

/// An operation to execute a QueueableTask
class TaskOperation: Operation {
    private let lockQueue = DispatchQueue(label: "com.queuetask.taskoperation", attributes: .concurrent)

    var id: String { task.id }
    let task: QueueableTask
    
    override var isAsynchronous: Bool {
        true
    }
    
    internal init(task: QueueableTask) {
        self.task = task
        super.init()
        queuePriority = task.priority
    }
    
    @available(*, unavailable, message: "TaskOperations should never be started directly!")
    override func start() {
        isFinished = false
        isExecuting = true
        main()
    }
    
    override func main() {
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
    
    override var description: String {
        "Operation: STARTED: \(isExecuting), PRIORITY: \(queuePriority.description) \"\(task.id.components(separatedBy: ".com").last!.split(separator: "|").first!.replacingOccurrences(of: " ", with: ""))\""
    }
    
    private var _isExecuting: Bool = false
    override private(set) var isExecuting: Bool {
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
        override private(set) var isFinished: Bool {
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
