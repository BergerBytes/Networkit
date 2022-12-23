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

/// `MulticastDelegate` lets you easily create a "multicast delegate" for a given protocol or class.
public final class MulticastDelegate<T> {
    /// The delegates hash table.
    fileprivate let delegates: NSHashTable<AnyObject>

    fileprivate let lock = NSLock()

    /// Use the property to check if no delegates are contained there.
    ///
    /// - returns: `true` if there are no delegates at all, `false` if there is at least one.
    public var isEmpty: Bool {
        defer { lock.unlock() }
        lock.lock()

        return delegates.allObjects.isEmpty
    }

    /// Use this method to initialize a new `MulticastDelegate` specifying whether delegate references should be weak or strong.
    ///
    /// - parameter strongReferences: Whether delegates should be strongly referenced, false by default.
    /// - returns: A new `MulticastDelegate` instance
    public init(strongReferences: Bool = false) {
        delegates = strongReferences ? NSHashTable<AnyObject>() : NSHashTable<AnyObject>.weakObjects()
    }

    /// Use this method to initialize a new `MulticastDelegate` specifying the storage options yourself.
    ///
    /// - parameter options: The underlying storage options to use
    /// - returns: A new `MulticastDelegate` instance
    public init(options: NSPointerFunctions.Options) {
        delegates = NSHashTable<AnyObject>(options: options, capacity: 0)
    }

    /// Use this method to add a delelgate.
    ///
    /// - Note: Alternatively, you can use the `+=` operator to add a delegate.
    ///
    /// - parameter delegate: The delegate to be added.
    public func addDelegate(_ delegate: T?) {
        defer { lock.unlock() }
        lock.lock()

        guard
            let delegate,
            unsafeContainsDelegate(delegate) == false
        else {
            return
        }

        delegates.add(delegate as AnyObject)
    }

    /// Use this method to remove a previously-added delegate.
    ///
    /// - Note: Alternatively, you can use the `-=` operator to add a delegate.
    ///
    /// - parameter delegate:  The delegate to be removed.
    public func removeDelegate(_ delegate: T) {
        defer { lock.unlock() }
        lock.lock()

        delegates.remove(delegate as AnyObject)
    }

    /// Use this method to invoke a closure on each delegate.
    ///
    /// - Note: Alternatively, you can use the `|>` operator to invoke a given closure on each delegate.
    ///
    /// - parameter invocation: The closure to be invoked on each delegate.
    public func invokeDelegates(_ invocation: (T) -> Void) {
        defer { lock.unlock() }
        lock.lock()

        for delegate in delegates.allObjects.compactMap({ $0 as? T }) {
            invocation(delegate)
        }
    }

    /// Use this method to determine if the multicast delegate contains a given delegate.
    ///
    /// - parameter delegate:   The given delegate to check if it's contained
    ///
    /// - returns: `true` if the delegate is found or `false` otherwise
    public func containsDelegate(_ delegate: T) -> Bool {
        defer { lock.unlock() }
        lock.lock()

        return delegates.contains(delegate as AnyObject)
    }

    private func unsafeContainsDelegate(_ delegate: T) -> Bool {
        delegates.contains(delegate as AnyObject)
    }
}

/// Use this operator to add a delegate.
///
/// - Note: This is a convenience operator for calling `addDelegate`.
///
/// - parameter left:   The multicast delegate
/// - parameter right:  The delegate to be added
public func += <T>(left: MulticastDelegate<T>, right: T?) {
    left.addDelegate(right)
}

/// Use this operator to combine the delgates of two multicast delegates.
///
/// - parameter left:   The multicast delegate
/// - parameter right:  The multicast delegate to add
public func += <T>(left: MulticastDelegate<T>, right: MulticastDelegate<T>) {
    defer { right.lock.unlock() }
    right.lock.lock()

    right.delegates.allObjects
        .compactMap { $0 as? T }
        .forEach { left.addDelegate($0) }
}

/// Use this operator to remove a delegate.
///
/// - Note: This is a convenience operator for calling `removeDelegate`.
///
/// - parameter left: The multicast delegate
/// - parameter right: The delegate to be removed
public func -= <T>(left: MulticastDelegate<T>, right: T?) {
    if let right {
        left.removeDelegate(right)
    }
}

precedencegroup MulticastPrecedence {
    associativity: left
    higherThan: TernaryPrecedence
}

infix operator |>: MulticastPrecedence

/// Use this operator invoke a closure on each delegate.
///
/// - Note: This is a convenience operator for calling `invokeDelegates`.
///
/// - parameter left: The multicast delegate
/// - parameter right: The closure to be invoked on each delegate
///
/// - returns: The `MulticastDelegate` after all its delegates have been invoked
public func |> <T>(left: MulticastDelegate<T>, right: (T) -> Void) {
    left.invokeDelegates(right)
}
