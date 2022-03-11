import Foundation

public protocol NetworkParameters: Hashable & Encodable {
    func asQuery() -> [String: Any]?
    func asBody() -> Data?
}

extension Int: UnencodedNetworkParameters {}
extension Float: UnencodedNetworkParameters {}
extension Double: UnencodedNetworkParameters {}
extension String: UnencodedNetworkParameters {}
extension Bool: UnencodedNetworkParameters {}

extension NetworkParameters {
    /// Encodes all properties as query parameters.
    public typealias Query = QueryNetworkParameters
    
    /// Encodes all properties into the request body as JSON.
    public typealias Body = BodyNetworkParameters
    
    /// Does not encode any properties into query parameters or the request body.
    public typealias Unencoded = UnencodedNetworkParameters
}

/// Encodes all properties as query parameters.
public protocol QueryNetworkParameters: NetworkParameters { }
public extension QueryNetworkParameters {
    func asBody() -> Data? { nil }
    func asQuery() -> [String : Any]? {
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
    func asQuery() -> [String : Any]? { nil }
    func asBody() -> Data? {
        try? Self.encoder.encode(self)
    }
    
    static var encoder: RequestBodyEncoder { JSONEncoder() }
}

/// Does not encode any properties into query parameters or the request body.
public protocol UnencodedNetworkParameters: NetworkParameters { }
public extension UnencodedNetworkParameters {
    func asQuery() -> [String : Any]? { nil }
    func asBody() -> Data? { nil }
}

public struct NoParameters: NetworkParameters {
    public static let none = NoParameters()

    private init() {}
    
    public func asQuery() -> [String : Any]? { nil }
    public func asBody() -> Data? { nil }
}
