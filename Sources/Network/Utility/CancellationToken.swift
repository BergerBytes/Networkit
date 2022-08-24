import Cache

public class CancellationToken {
    private let cancellationClosure: () -> Void
    let requestKey: String

    public private(set) var isCanceled = false

    public init(key: String, cancellationClosure: @escaping () -> Void) {
        self.requestKey = key
        self.cancellationClosure = cancellationClosure
    }

    public func cancel() {
        cancellationClosure()
        isCanceled = true
    }
}
