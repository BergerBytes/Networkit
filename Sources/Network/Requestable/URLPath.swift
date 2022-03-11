import Foundation

public class URLPath: ExpressibleByStringLiteral {
    private(set) var pathString = ""
    
    required public init(stringLiteral string: String) {
        add(string)
    }
    
    required convenience public init(_ string: String) {
        self.init(stringLiteral: string)
    }
    
    @discardableResult
    public func add(_ string: String) -> URLPath {
        pathString = pathString.appending("/\(string)")
        return self
    }
}

public func /<Convertible: EndpointPathStringConvertible> (left: Convertible, right: Convertible) -> URLPath {
    .init(left.pathString).add(right.pathString)
}

public func /<Convertible: EndpointPathStringConvertible> (left: URLPath, right: Convertible) -> URLPath {
    left.add(right.pathString)
}

/// A protocol indicating that a type is able to be _losslessly_ converted into a `String` for use in an url's path string.
public protocol EndpointPathStringConvertible {
    var pathString: String { get }
}

// Standard conformance for common types.

extension Int: EndpointPathStringConvertible { public var pathString: String { description } }
extension Int8: EndpointPathStringConvertible { public var pathString: String { description } }
extension Int16: EndpointPathStringConvertible { public var pathString: String { description } }
extension Int32: EndpointPathStringConvertible { public var pathString: String { description } }
extension Int64: EndpointPathStringConvertible { public var pathString: String { description } }

extension UInt: EndpointPathStringConvertible { public var pathString: String { description } }
extension UInt8: EndpointPathStringConvertible { public var pathString: String { description } }
extension UInt16: EndpointPathStringConvertible { public var pathString: String { description } }
extension UInt32: EndpointPathStringConvertible { public var pathString: String { description } }
extension UInt64: EndpointPathStringConvertible { public var pathString: String { description } }

extension String: EndpointPathStringConvertible { public var pathString: String { description } }
extension Substring: EndpointPathStringConvertible { public var pathString: String { description } }
extension Unicode.Scalar: EndpointPathStringConvertible { public var pathString: String { description } }
