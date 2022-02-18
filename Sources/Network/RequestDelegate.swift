import Foundation

public protocol RequestIdentifier { }

public protocol RequestDelegate: AnyObject {
    func requestStarted(id: RequestIdentifier?)
    func requestCompleted(id: RequestIdentifier?)
    func requestFailed(id: RequestIdentifier?, error: Error)
}

public struct RequestDelegateConfig {
    weak var delegate: RequestDelegate?
    let id: RequestIdentifier?
    
    public init(_ delegate: RequestDelegate?, id: RequestIdentifier?) {
        self.delegate = delegate
        self.id = id
    }
}
