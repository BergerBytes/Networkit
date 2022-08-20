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

/// First-in first-out queue (FIFO)
/// New elements are added to the end of the queue. Dequeuing pulls elements from
/// the front of the queue.
/// Enqueuing and dequeuing are O(1) operations.
public struct Queue<T> {
    private var array = [T?]()
    private var head = 0

    public var isEmpty: Bool { count == 0 }
    public var count: Int { array.count - head }

    public init() { }

    public mutating func enqueue(_ element: T) {
        array.append(element)
    }

    public mutating func dequeue() -> T? {
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
