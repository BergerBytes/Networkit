import Cache

public final class ObserverToken {
  private let cancellationClosure: () -> Void

  public init(cancellationClosure: @escaping () -> Void) {
    self.cancellationClosure = cancellationClosure
  }

  public func cancel() {
    cancellationClosure()
  }
}
