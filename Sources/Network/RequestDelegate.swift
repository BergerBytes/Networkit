import Foundation

public protocol RequestDelegate: AnyObject {
    func requestStarted(id: Identifiable?)
    func requestCompleted(id: Identifiable?)
    func requestFailed(id: Identifiable?, error: Error)
}

public struct RequestDelegateConfig {
    weak var delegate: RequestDelegate?
    let id: Identifiable?
    
    public init(_ delegate: RequestDelegate?, id: Identifiable?) {
        self.delegate = delegate
        self.id = id
    }
}
