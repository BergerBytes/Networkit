//
//  File.swift
//
//
//  Created by Michael Berger on 11/11/23.
//

import Foundation

extension Encodable {
    func sortedKeyValueString() -> String? {
        let encoder = JSONEncoder()

        // Step 1: Encode to a Dictionary representation
        guard let jsonData = try? encoder.encode(self),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
              let dictionary = jsonObject as? [String: Any]
        else {
            return nil
        }

        // Step 2: Sort keys and serialize
        let sortedKeys = dictionary.keys.sorted()
        var components: [String] = []

        for key in sortedKeys {
            if let value = dictionary[key] {
                components.append("\(key):\(value)")
            }
        }

        return components.joined(separator: "|")
    }
}
