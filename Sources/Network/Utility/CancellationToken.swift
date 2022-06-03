import Cache

public class CancellationToken {
    private let cancellationClosure: () -> Void
    
    public init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }
    
    public func cancel() {
        cancellationClosure()
    }
    
    deinit {
        cancel()
    }
}
