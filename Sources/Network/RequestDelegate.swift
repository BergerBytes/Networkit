import Foundation

public protocol NetworkID { }

public protocol RequestDelegate: AnyObject {
    func requestStarted(id: NetworkID?)
    func requestCompleted(id: NetworkID?)
    func requestFailed(id: NetworkID?, error: Error)
}

public struct RequestDelegateConfig {
    weak var delegate: RequestDelegate?
    let id: NetworkID?
    
    public init(_ delegate: RequestDelegate?, id: NetworkID?) {
        self.delegate = delegate
        self.id = id
    }
}
