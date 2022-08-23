//  Copyright © 2022 BergerBytes LLC. All rights reserved.
//
//  Permission to use, copy, modify, and/or distribute this software for any
//  purpose with or without fee is hereby granted, provided that the above
//  copyright notice and this permission notice appear in all copies.
//
//  THE SOFTWARE IS PROVIDED  AS IS AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
//  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
//  IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

import Cache
import Debug
import Foundation

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
    func expireObject(for key: String) throws
    
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

    private var operations = NSHashTable<TaskOperation>.weakObjects()
    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 10
        return queue
    }()

    init() {
        storage.addStorageObserver(self) { _, storage, change in
            switch change {
            case let .add(key):
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

                            if entries.isEmpty {
                                self.operations
                                    .allObjects.first(where: { $0.task.id == key })?
                                    .queuePriority = .veryLow
                            }
                        }

                    case let .failure(error):
                        Log.error(in: .network, "Failed to get item", params: ["Key": key, "Error": error.localizedDescription])
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
        let cancelTokenId = UUID()

        observerQueue.async { [cancelTokenId] in
            self.observers[key, default: []].append(.init(cancelTokenId: cancelTokenId, callback: dataCallback, object: object))
        }

        return CancellationToken(key: key) { [weak self, cancelTokenId] in
            self?.observerQueue.async {
                self?.observers[key, default: []].removeAll(where: { $0.cancelTokenId == cancelTokenId })
                if self?.observers[key]?.isEmpty == true {
                    self?.operations
                        .allObjects.first(where: { $0.task.id == key })?
                        .queuePriority = .veryLow
                }
            }
        }
    }

    public func enqueue(_ task: QueueableTask) {
        observerQueue.async {
            if
                let newTask = task as? MergableRequest,
                let existingTask = self.operations.allObjects
                .filter({ !$0.isFinished && !$0.isCancelled })
                .compactMap({ $0.task as? MergableRequest })
                .first(where: { newTask.shouldBeMerged(with: $0) })
            {
                do {
                    try newTask.merge(into: existingTask)
                    let operation = self.operations.allObjects.first(where: { $0.id == existingTask.id })
                    operation?.queuePriority = operation?.queuePriority.increment() ?? .normal
                    return
                } catch {
                    Log.error(in: .network, error)
                }
            }

            let operation = task.newOperation()
            operation.completionBlock = { [weak operation] in
                self.observerQueue.async {
                    self.operations.remove(operation)
                }
            }

            self.operations.add(operation)
            self.operationQueue.addOperation(operation)
        }
    }

    public func request<T: Requestable>(_: T.Type, delegate: RequestDelegateConfig?, dataCallback: @escaping (T) -> Void) where T.P == NoParameters {
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
    
    public func expireObject(for key: String) throws {
        try storage.setObject(
            try storage.object(forKey: key),
            forKey: key,
            expiry: .seconds(0)
        )
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
