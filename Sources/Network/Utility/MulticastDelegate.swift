import Foundation

/// `MulticastDelegate` lets you easily create a "multicast delegate" for a given protocol or class.
open class MulticastDelegate<T> {
    
    /// The delegates hash table.
    fileprivate let delegates: NSHashTable<AnyObject>
    
    /// Use the property to check if no delegates are contained there.
    ///
    /// - returns: `true` if there are no delegates at all, `false` if there is at least one.
    public var isEmpty: Bool {
        delegates.allObjects.isEmpty
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
        guard
            let delegate = delegate,
            containsDelegate(delegate) == false
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
        delegates.remove(delegate as AnyObject)
    }
    
    /// Use this method to invoke a closure on each delegate.
    ///
    /// - Note: Alternatively, you can use the `|>` operator to invoke a given closure on each delegate.
    ///
    /// - parameter invocation: The closure to be invoked on each delegate.
    public func invokeDelegates(_ invocation: (T) -> ()) {
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
        delegates.contains(delegate as AnyObject)
    }
}

/// Use this operator to add a delegate.
///
/// - Note: This is a convenience operator for calling `addDelegate`.
///
/// - parameter left:   The multicast delegate
/// - parameter right:  The delegate to be added
public func +=<T>(left: MulticastDelegate<T>, right: T?) {
    left.addDelegate(right)
}

/// Use this operator to combine the delgates of two multicast delegates.
///
/// - parameter left:   The multicast delegate
/// - parameter right:  The multicast delegate to add
public func +=<T>(left: MulticastDelegate<T>, right: MulticastDelegate<T>) {
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
public func -=<T>(left: MulticastDelegate<T>, right: T?) {
    if let right = right {
        left.removeDelegate(right)
    }
}

precedencegroup MulticastPrecedence {
    associativity: left
    higherThan: TernaryPrecedence
}
infix operator |> : MulticastPrecedence

/// Use this operator invoke a closure on each delegate.
///
/// - Note: This is a convenience operator for calling `invokeDelegates`.
///
/// - parameter left: The multicast delegate
/// - parameter right: The closure to be invoked on each delegate
///
/// - returns: The `MulticastDelegate` after all its delegates have been invoked
public func |><T>(left: MulticastDelegate<T>, right: (T) -> ()) {
    left.invokeDelegates(right)
}
