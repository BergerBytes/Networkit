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

import Foundation

public protocol NetworkParameters: Hashable & Encodable {
    @inlinable func asQuery() -> [String: Any]?
    @inlinable func asBody() -> Data?
}

extension Int: UnencodedNetworkParameters { }
extension Float: UnencodedNetworkParameters { }
extension Double: UnencodedNetworkParameters { }
extension String: UnencodedNetworkParameters { }
extension Bool: UnencodedNetworkParameters { }

public extension NetworkParameters {
    /// Encodes all properties as query parameters.
    typealias Query = QueryNetworkParameters

    /// Encodes all properties into the request body as JSON.
    typealias Body = BodyNetworkParameters

    /// Does not encode any properties into query parameters or the request body.
    typealias Unencoded = UnencodedNetworkParameters
}

/// Encodes all properties as query parameters.
public protocol QueryNetworkParameters: NetworkParameters { }
public extension QueryNetworkParameters {
    @inlinable func asBody() -> Data? { nil }
    func asQuery() -> [String: Any]? {
        try? DictionaryEncoder().encode(self)
    }
}

/// Encodes all properties into the request body as JSON.
///
/// - Note: By default the parameters will be encoded using a `JSONEncoder`,
/// this can be changed by implementing the `encoder` property.
public protocol BodyNetworkParameters: NetworkParameters {
    static var encoder: RequestBodyEncoder { get }
}

public extension BodyNetworkParameters {
    @inlinable func asQuery() -> [String: Any]? { nil }
    @inlinable func asBody() -> Data? {
        try? Self.encoder.encode(self)
    }

    @inlinable static var encoder: RequestBodyEncoder { JSONEncoder() }
}

/// Does not encode any properties into query parameters or the request body.
public protocol UnencodedNetworkParameters: NetworkParameters { }
public extension UnencodedNetworkParameters {
    @inlinable func asQuery() -> [String: Any]? { nil }
    @inlinable func asBody() -> Data? { nil }
}

public struct NoParameters: NetworkParameters {
    public static let none = NoParameters()

    private init() { }

    @inlinable public func asQuery() -> [String: Any]? { nil }
    @inlinable public func asBody() -> Data? { nil }
}
