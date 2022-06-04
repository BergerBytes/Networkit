import Foundation

class DictionaryEncoder {
    private let jsonEncoder = JSONEncoder()

    /// Encodes given Encodable value into an array or dictionary
    func encode<T>(_ value: T) throws -> [String: Any] where T: Encodable {
        let jsonData = try jsonEncoder.encode(value)
        return try JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as! [String : Any]
    }
}

class DictionaryDecoder {
    func decode<T: Decodable>(_ type: T.Type, from value: [String: Any]) -> T? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed) else {
            return nil
        }
        
        return try? JSONDecoder().decode(type, from: jsonData)
    }
}
