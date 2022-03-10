import Foundation

/// A Network task that should be merged if the same request is found already queued.
public protocol MergableRequest: QueueableTask {
    var delegate: MulticastDelegate<RequestDelegate> { get }
    var requestIdentifier: RequestIdentifier? { get }
    
    /// Check for wether or this task should be merged with the provided task.
    /// - Parameter task: The task to merge with.
    /// - Returns: Bool True if tasks should be merged.
    func shouldBeMerged(with task: MergableRequest) -> Bool
}
