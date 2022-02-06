import Foundation

internal extension Array {
    /// Safely subscript into an array. This will perform a bounds check on the passed in index.
    ///
    /// - Parameter index: the index to look up in the array.
    /// - Returns: an element if the index is within bounds of the array; otherwise, nil.
    subscript(safe index: Index?) -> Element? {
        guard
            let index = index,
            self.indices.contains(index)
        else {
            return nil
        }
        
        return self[index]
    }
}
