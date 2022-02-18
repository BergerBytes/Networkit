import Foundation
import Cache
import Debug
import AnyCodable

struct ObserverEntry {
    let callback: (AnyCodable) -> Void
    weak var object: AnyObject?
}

public protocol NetworkManagerProvider {
    func addObserver(for key: String, on object: AnyObject, dataCallback: @escaping (AnyCodable) -> Void) -> ObserverToken
    func enqueue(_ task: QueueableTask)
    func request<T: RequestableResponse>(_ response: T.Type, delegate: RequestDelegateConfig?, dataCallback: @escaping (T) -> Void) where T.P == NoParameters
    
    func isObjectExpired(for key: String) throws -> Bool
    func get<T>(object key: String) throws -> T?
    func save<T: Encodable>(object: T, key: String, cachePolicy: CachePolicy) throws
    func removeExpiredObjects() throws
    func removeAllObjects() throws
}

public class NetworkManager: NetworkManagerProvider {
    public static var shared: NetworkManagerProvider = NetworkManager()
    
    static let diskConfig = DiskConfig(
        name: "com.network.cache",
        expiry: .seconds(30 * 24 * 60 * 60), // 30 Days
        maxSize: 100_000_000, // 100mb
        protectionType: .complete
    )
    
    static let memoryConfig = MemoryConfig(
        countLimit: 100
    )
    
    public private(set) lazy var storage = try! Storage<String, AnyCodable>(diskConfig: Self.diskConfig, memoryConfig: Self.memoryConfig, transformer: TransformerFactory.forCodable(ofType: AnyCodable.self))
    private(set) var observers = [String: [ObserverEntry]]()
    private let observerQueue = DispatchQueue(label: "com.network.observerQueue")
    
    private let operationQueue = OperationQueue()
    
    init() {
        storage.addStorageObserver(self) { observer, storage, change in
            switch change {
            case .add(let key):
                storage.async.entry(forKey: key) { result in
                    switch result {
                    case .value(let data):
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
                        
                    case .error(let error):
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
    
    public func addObserver(for key: String, on object: AnyObject, dataCallback: @escaping (AnyCodable) -> Void) -> ObserverToken {
        observerQueue.async {
            self.observers[key, default: []].append(.init(callback: dataCallback, object: object))
        }
        
        return ObserverToken { [weak self] in
            self?.observerQueue.async {
                self?.observers.removeValue(forKey: key)
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
    
    public func request<T: RequestableResponse>(_ response: T.Type, delegate: RequestDelegateConfig?, dataCallback: @escaping (T) -> Void) where T.P == NoParameters {
        enqueue(T.requestTask(delegate: delegate, dataCallback: dataCallback))
    }
    
    public func isObjectExpired(for key: String) throws -> Bool {
        try storage.isExpiredObject(forKey: key)
    }
    
    public func get<T>(object key: String) throws -> T? {
        try storage.object(forKey: key).value as? T
    }
    
    public func save<T: Encodable>(object: T, key: String, cachePolicy: CachePolicy) throws {
        try storage.setObject(.init(object), forKey: key, expiry: cachePolicy.asExpiry())
    }
    
    public func removeExpiredObjects() throws {
        try storage.removeExpiredObjects()
    }
    
    public func removeAllObjects() throws {
        try storage.removeAll()
    }
}
