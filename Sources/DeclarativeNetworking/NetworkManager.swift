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
import DevKit
import Foundation

struct ObserverEntry {
    let cancelTokenId: UUID
    let callback: (Data) -> Void
    weak var object: AnyObject?
}

public extension QueueDefinition {
    static let networkDefault = QueueDefinition(id: "com.networkmanager.default", concurrentTaskPolicy: .limit(10))
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

    private let queueManager = QueueManager.shared

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
                                self.queueManager.set(priority: .veryLow, for: key)
                            }
                        }

                    case let .failure(error):
                        Log.error(in: .network, "Failed to get item", info: ["Key": key, "Error": error.localizedDescription])
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
                    self?.queueManager.set(priority: .veryLow, for: key)
                }
            }
        }
    }

    public func enqueue(_ task: QueueableTask) {
        queueManager.enqueue(task: task)
    }

    @inlinable public func request<T: Requestable>(_: T.Type, delegate: RequestDelegateConfig?, dataCallback: @escaping (T) -> Void) where T.P == NoParameters {
        enqueue(T.requestTask(delegate: delegate, dataCallback: dataCallback))
    }

    @inlinable public func get(object key: String) throws -> Data? {
        try storage.object(forKey: key)
    }

    public func save(object: Data, key: String, cachePolicy: CachePolicy) throws {
        try storage.setObject(object, forKey: key, expiry: cachePolicy.asExpiry())
    }

    @inlinable public func isObjectExpired(for key: String) throws -> Bool {
        try storage.isExpiredObject(forKey: key)
    }

    @inlinable public func expiryDate(for key: String) throws -> Date {
        try storage.expiryForObject(forKey: key).date
    }

    @inlinable public func expireObject(for key: String) throws {
        try storage.setObject(
            try storage.object(forKey: key),
            forKey: key,
            expiry: .seconds(0)
        )
    }

    @inlinable public func removeExpiredObjects() throws {
        try storage.removeExpiredObjects()
    }

    @inlinable public func removeAllObjects() throws {
        try storage.removeAll()
    }

    @inlinable public func remove(object key: String) throws {
        try storage.removeObject(forKey: key)
    }
}
