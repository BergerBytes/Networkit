import Foundation

/// First-in first-out queue (FIFO)
/// New elements are added to the end of the queue. Dequeuing pulls elements from
/// the front of the queue.
/// Enqueuing and dequeuing are O(1) operations.
public struct Queue<T> {
    private var array = [T?]()
    private var head = 0
    
    public var isEmpty: Bool { count == 0 }
    public var count: Int { array.count - head }
    
    public init() {}
    
    public mutating func enqueue(_ element: T) {
        array.append(element)
    }
    
    public mutating func dequeue() -> T? {
        guard let element = array[safe: head] else {
            return nil
        }
        
        array[head] = nil
        head += 1
        
        let percentage = Double(head)/Double(array.count)
        if array.count > 50 && percentage > 0.25 {
            array.removeFirst(head)
            head = 0
        }
        
        return element
    }
    
    public var peekNext: T? {
        if isEmpty {
            return nil
        } else {
            return array[head]
        }
    }
    
    public var peekLast: T? {
        if isEmpty {
            return nil
        } else {
            return array.last as? T
        }
    }
}
