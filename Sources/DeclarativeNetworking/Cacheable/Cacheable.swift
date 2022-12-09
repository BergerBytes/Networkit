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

public protocol Cacheable {
    static var cachePolicy: CachePolicy { get }

    /// Controls if cached data is returned when observing an endpoint if the data is expired.
    /// If true the observer will receive the cached data back regardless if it is expired or not, a request will still be made if the data is expired.
    /// Default value is true.
    static var returnCachedDataIfExpired: Bool { get }
}

enum CacheableError: Error {
    case failedToDecode
}

public extension Cacheable {
    static var returnCachedDataIfExpired: Bool { true }
}

public typealias CacheableResponse = Requestable & Cacheable

public extension Cacheable where Self: Requestable {
    @available(*, deprecated, renamed: "request(given:delegate:force:with:)")
    @inlinable static func fetch(given parameters: P, delegate: RequestDelegateConfig? = nil, force: Bool = false, with networkManager: NetworkManagerProvider = NetworkManager.shared) {
        _request(given: parameters, delegate: delegate, force: force, with: networkManager, dataCallback: nil, resultCallback: nil)
    }

    @inlinable static func request(given parameters: P, delegate: RequestDelegateConfig? = nil, force: Bool = false, with networkManager: NetworkManagerProvider = NetworkManager.shared) {
        _request(given: parameters, delegate: delegate, force: force, with: networkManager, dataCallback: nil, resultCallback: nil)
    }

    @available(*, deprecated, renamed: "request(given:delegate:force:with:dataCallback:)")
    static func fetch(given parameters: P, delegate: RequestDelegateConfig?, force: Bool = false, with networkManager: NetworkManagerProvider = NetworkManager.shared, dataCallback: ((Self) -> Void)?) {
        _request(given: parameters, delegate: delegate, force: force, with: networkManager, dataCallback: dataCallback, resultCallback: nil)
    }

    static func _request(given parameters: P, delegate: RequestDelegateConfig?, force: Bool, with networkManager: NetworkManagerProvider = NetworkManager.shared, dataCallback: ((Self) -> Void)?, resultCallback: ((Result<Self, Error>) -> ())?) {
        let id = Self.generateId(given: parameters)
        let isExpired = force || (try? networkManager.isObjectExpired(for: id)) == true

        if
            !isExpired,
            case let .success(data) = Self.cachedData(for: id, with: networkManager)
        {
            if let dataCallback {
                Task { @MainActor [dataCallback, data] in
                    dataCallback(data)
                }
            }
            
            if let resultCallback {
                Task { @MainActor [resultCallback, data] in
                    resultCallback(.success(data))
                }
            }

            return
        }

        networkManager.enqueue(Self.requestTask(given: parameters, delegate: delegate, dataCallback: dataCallback, resultCallback: resultCallback))
    }

    @discardableResult
    @inlinable static func observe(on object: AnyObject, given parameters: P, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        var token: CancellationToken?
        return observe(on: object, given: parameters, token: &token, delegate: delegate, dataCallback: dataCallback)
    }

    @discardableResult
    static func observe(on object: AnyObject, given parameters: P, token: inout CancellationToken?, delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        let request = Self.requestTask(given: parameters, delegate: delegate, dataCallback: { _ in })

        // If there is an uncanceled existing token,
        // we can compare the requestKey with our new request id and avoid returning rebuilding observer.
        let duplicateRequest = token != nil && token?.isCanceled == false && request.id == token?.requestKey

        if !duplicateRequest {
            token?.cancel()

            let observerToken = networkManager.addObserver(for: request.id, on: object) { data in
                guard
                    let value = try? Self.decoder.decode(Self.self, from: data)
                else {
                    Log.error(in: .network, "Type mismatch", params: ["Expected Type": Self.self])
                    return
                }

                DispatchQueue.main.async {
                    dataCallback(value)
                }
            }

            token = observerToken
        }

        var isExpired = (try? networkManager.isObjectExpired(for: request.id)) ?? true

        // If the new cache policy would expire before the existing cached expiry date, set isExpired to true.
        if
            isExpired == false,
            let cacheExpiryDate = try? networkManager.expiryDate(for: request.id),
            let newExpiryDate = Self.cachePolicy.asExpiry()?.date,
            cacheExpiryDate.distance(to: newExpiryDate) < 0
        {
            isExpired = true
        }

        // Return any cached data if not expired or expired data is allowed.
        if isExpired == false || returnCachedDataIfExpired {
            switch cachedData(for: request.id, with: networkManager) {
            case let .success(data):
                dataCallback(data)

            case .failure: // if the data is unable to be decoded, set isExpired to true and delete the cached object.
                isExpired = true
                try? networkManager.remove(object: request.id)
            }
        }

        if isExpired {
            networkManager.enqueue(request)
        }

        return token!
    }

    /// Ensures valid data exists for the given requestable. If no cache data is found or it fails to decode the data will be fetched in the background.
    /// - Parameters:
    ///   - parameters: The parameters for the requestable.
    ///   - networkManager: Injected network manager.
    @available(*, deprecated, message: "Use a request method without a delegate / callback.")
    static func fillCache(given parameters: P, with networkManager: NetworkManagerProvider = NetworkManager.shared) {
        let request = Self.requestTask(given: parameters, delegate: nil, dataCallback: nil)
        if case .failure = cachedData(for: request.id, with: networkManager) {
            networkManager.enqueue(request)
        }
    }
}

// MARK: - Cacheable where Self: Requestable, Self.P: EmptyInitializable

public extension Cacheable where Self: Requestable, Self.P: EmptyInitializable {
    @discardableResult
    @inlinable static func observe(on object: AnyObject, token: inout CancellationToken?, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        observe(on: object, given: .init(), token: &token, delegate: delegate, dataCallback: dataCallback)
    }

    @discardableResult
    @inlinable static func observe(on object: AnyObject, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        var token: CancellationToken?
        return observe(on: object, given: .init(), token: &token, delegate: delegate, dataCallback: dataCallback)
    }

    @available(*, deprecated, renamed: "request(delegate:with:force:)")
    @inlinable static func fetch(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false) {
        _request(given: .init(), delegate: delegate, force: force, with: networkManager, dataCallback: nil, resultCallback: nil)
    }

    @inlinable static func request(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false) {
        _request(given: .init(), delegate: delegate, force: force, with: networkManager, dataCallback: nil, resultCallback: nil)
    }

    @available(*, deprecated, renamed: "request(delegate:with:force:dataCallback:)")
    static func fetch(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false, dataCallback: ((Self) -> Void)?) {
        request(delegate: delegate, with: networkManager, force: force, dataCallback: dataCallback)
    }

    static func request(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false, dataCallback: ((Self) -> Void)?) {
        _request(given: .init(), delegate: delegate, force: force, with: networkManager, dataCallback: dataCallback, resultCallback: nil)
    }
    
    static func request(with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false, callback: ((Result<Self, Error>) -> Void)?) {
        _request(given: .init(), delegate: nil, force: force, with: networkManager, dataCallback: nil, resultCallback: callback)
    }
}

// MARK: - Cacheable where Self: Requestable, Self.P == NoParameters

public extension Cacheable where Self: Requestable, Self.P == NoParameters {
    @discardableResult
    @inlinable static func observe(on object: AnyObject, token: inout CancellationToken?, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        observe(on: object, given: .none, token: &token, delegate: delegate, dataCallback: dataCallback)
    }

    @discardableResult
    static func observe(on object: AnyObject, delegate: RequestDelegateConfig?, dataCallback: @escaping (_ data: Self) -> Void) -> CancellationToken {
        var token: CancellationToken?
        return observe(on: object, given: .none, token: &token, delegate: delegate, dataCallback: dataCallback)
    }

    @available(*, deprecated, renamed: "request(delegate:with:force:)")
    @inlinable static func fetch(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false) {
        _request(given: .none, delegate: delegate, force: force, with: networkManager, dataCallback: nil, resultCallback: nil)
    }

    @inlinable static func request(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false) {
        _request(given: .none, delegate: delegate, force: force, with: networkManager, dataCallback: nil, resultCallback: nil)
    }

    @available(*, deprecated, renamed: "request(delegate:with:force:dataCallback:)")
    static func fetch(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false, dataCallback: ((Self) -> Void)?) {
        _request(given: .none, delegate: delegate, force: force, with: networkManager, dataCallback: dataCallback, resultCallback: nil)
    }

    static func request(delegate: RequestDelegateConfig?, with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false, dataCallback: ((Self) -> Void)?) {
        _request(given: .none, delegate: delegate, force: force, with: networkManager, dataCallback: dataCallback, resultCallback: nil)
    }
    
    static func request(with networkManager: NetworkManagerProvider = NetworkManager.shared, force: Bool = false, callback: ((Result<Self, Error>) -> Void)?) {
        _request(given: .none, delegate: nil, force: force, dataCallback: nil, resultCallback: callback)
    }

    /// NoParameters convenience version of of ``fillCache(given:with:)``
    static func fillCache(with networkManager: NetworkManagerProvider = NetworkManager.shared) {
        let request = Self.requestTask(given: .none, delegate: nil, dataCallback: nil)
        if case .failure = cachedData(for: request.id, with: networkManager) {
            networkManager.enqueue(request)
        }
    }
}

extension Cacheable where Self: Requestable {
    /// Returns any cached data found in storage regardless of it's expiration.
    @inline(__always) private static func cachedData(for id: String, with networkManager: NetworkManagerProvider) -> Result<Self, Error> {
        Self.cachedData(type: Self.self, for: id, decoder: Self.decoder, with: networkManager)
    }
}

extension Cacheable {
    /// Returns any cached data found in storage regardless of it's expiration.
    static func cachedData<T: Requestable>(type _: T.Type, for id: String, decoder: ResponseDecoder, with networkManager: NetworkManagerProvider) -> Result<T, Error> {
        if
            let data = try? networkManager.get(object: id),
            let decodedData: T = try? decoder.decode(T.self, from: data)
        {
            return .success(decodedData)
        } else {
            return .failure(CacheableError.failedToDecode)
        }
    }
}
