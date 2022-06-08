import Foundation
import Cache
import Debug

struct ObserverEntry {
    let cancelTokenId: UUID
    let callback: (Data) -> Void
    weak var object: AnyObject?
}

public protocol NetworkManagerProvider {
    func addObserver(for key: String, on object: AnyObject, dataCallback: @escaping (Data) -> Void) -> CancellationToken
    func enqueue(_ task: QueueableTask)
    func request<T: Requestable>(_ response: T.Type, delegate: RequestDelegateConfig?, dataCallback: @escaping (T) -> Void) where T.P == NoParameters
    
    func get(object key: String) throws -> Data?
    func save(object: Data, key: String, cachePolicy: CachePolicy) throws
    
    func isObjectExpired(for key: String) throws -> Bool
    func expiryDate(for key: String) throws -> Date
    
    func remove(object key: String) throws
    func removeExpiredObjects() throws
    func removeAllObjects() throws
}

public class NetworkManager: NetworkManagerProvider {
    public static var shared: NetworkManagerProvider = NetworkManager()
    
    static let diskConfig = DiskConfig(
        name: "com.network.cache",
        expiry: .seconds(0),
        maxSize: 100_000_000 // 100mb
    )
    
    static let memoryConfig = MemoryConfig()
    
    public private(set) lazy var storage = try! Storage<String, Data>(diskConfig: Self.diskConfig, memoryConfig: Self.memoryConfig, transformer: TransformerFactory.forCodable(ofType: Data.self))
    private(set) var observers = [String: [ObserverEntry]]()
    private let observerQueue = DispatchQueue(label: "com.network.observerQueue")
    
    private let operationQueue = OperationQueue()
    
    init() {
        storage.addStorageObserver(self) { observer, storage, change in
            switch change {
            case .add(let key):
                storage.async.entry(forKey: key) { result in
                    switch result {
                    case let .success(data):
                        self.observerQueue.async {
                            var entries = self.observers[key] ?? []
                            for (index, entry) in entries.enumerated().reversed() {
                                guard
                                    entry.object != nil
                                else {
                                    entries.remove(at: index)
                                    continue
                                }
                                
                                DispatchQueue.main.async {
                                    entry.callback(data.object)
                                }
                            }
                            
                            self.observers[key] = entries
                        }
                        
                    case let .failure(error):
                        Debug.log(level: .error, "Failed to get item", params: ["Key": key, "Error" : error.localizedDescription])
                    }
                }
                
            case .remove:
                break
                
            case .removeAll:
                break
                
            case .removeExpired:
                break
                
            }
        }
    }
    
    public func addObserver(for key: String, on object: AnyObject, dataCallback: @escaping (Data) -> Void) -> CancellationToken {
        // Create a cancelTokenId to match up observer entry when canceling.
        let cancelTokenId = UUID.init()
        
        observerQueue.async { [cancelTokenId] in
            self.observers[key, default: []].append(.init(cancelTokenId: cancelTokenId, callback: dataCallback, object: object))
        }
        
        return CancellationToken(key: key) { [weak self, cancelTokenId] in
            self?.observerQueue.async {
                self?.observers[key, default: []].removeAll(where: { $0.cancelTokenId == cancelTokenId })
            }
        }
    }
    
    public func enqueue(_ task: QueueableTask) {
        if
            let task = task as? MergableRequest,
            let existingTask = self.operationQueue.operations
                .filter({ !$0.isFinished && !$0.isCancelled })
                .compactMap({ ($0 as? TaskOperation)?.task as? MergableRequest})
                .first(where: { task.shouldBeMerged(with: $0) })
        {
            existingTask.delegate += task.delegate
            return
        }
        
        operationQueue.addOperation(task.newOperation())
    }
    
    public func request<T: Requestable>(_ response: T.Type, delegate: RequestDelegateConfig?, dataCallback: @escaping (T) -> Void) where T.P == NoParameters {
        enqueue(T.requestTask(delegate: delegate, dataCallback: dataCallback))
    }
    
    public func get(object key: String) throws -> Data? {
        try storage.object(forKey: key)
    }
    
    public func save(object: Data, key: String, cachePolicy: CachePolicy) throws {
        try storage.setObject(object, forKey: key, expiry: cachePolicy.asExpiry())
    }
    
    public func isObjectExpired(for key: String) throws -> Bool {
        try storage.isExpiredObject(forKey: key)
    }
    
    public func expiryDate(for key: String) throws -> Date {
        try storage.expiryForObject(forKey: key).date
    }
    
    public func removeExpiredObjects() throws {
        try storage.removeExpiredObjects()
    }
    
    public func removeAllObjects() throws {
        try storage.removeAll()
    }
    
    public func remove(object key: String) throws {
        try storage.removeObject(forKey: key)
    }
}
