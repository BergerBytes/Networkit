import Foundation

public protocol RequestBodyEncoder {
    func encode<T>(_ value: T) throws -> Data where T : Encodable
}

extension JSONEncoder: RequestBodyEncoder {}
