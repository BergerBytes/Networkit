//
//  File.swift
//  
//
//  Created by Michael Berger on 8/11/22.
//

import Foundation

/// First-in first-out queue (FIFO)
///
/// New elements are added to the end of the queue. Dequeuing pulls elements from
/// the front of the queue.
/// Enqueuing and dequeuing are O(1) operations.
final class PriorityQueue<Element: TaskOperation> {
    private var array = [Element?]()
    private var head = 0

    var isEmpty: Bool { count == 0 }
    var count: Int { array.count - head }

    init() { }

    init(_ sequence: some Sequence<Element>) {
        array = Array(sequence)
    }
}

extension PriorityQueue {
    func enqueue(_ element: Element) {
        array.append(element)
        sort()
    }

    func enqueue(_ elements: [Element]) {
        array.append(contentsOf: elements)
        sort()
    }
    
    @discardableResult
    func update(priority: Operation.QueuePriority, of id: QueueableTask.ID) -> Bool {
        guard let task = array.first(where: { $0?.id == id }) as? Element else {
            return false
        }
        
        task.queuePriority = priority
        sort()
        return true
    }
    
    private func sort() {
        array = array.sorted(by: { lhs, rhs in
            guard let lhs else { return true }
            guard let rhs else { return false }
            
            return lhs > rhs
        })
    }

    func dequeue() -> Element? {
        guard let element = array[safe: head] else {
            return nil
        }

        array[head] = nil
        head += 1

        let percentage = Double(head) / Double(array.count)
        if array.count > 50, percentage > 0.25 {
            array.removeFirst(head)
            head = 0
        }

        return element
    }

    var peekNext: Element? {
        if isEmpty {
            return nil
        } else {
            return array[head]
        }
    }

    var peekLast: Element? {
        if isEmpty {
            return nil
        } else {
            return array.last as? Element
        }
    }

    var peekAll: [Element] {
        array[head ... count - 1]
            .compactMap { $0 }
    }

    func removeAll(keepingCapacity keepCapacity: Bool = false) {
        array.removeAll(keepingCapacity: keepCapacity)
        head = 0
    }
}

// Internal extension for testing.
internal extension PriorityQueue {
    var _array: [Element?] {
        array
    }

    var _head: Int {
        head
    }
}
