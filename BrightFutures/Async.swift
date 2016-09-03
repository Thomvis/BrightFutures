//
//  Async.swift
//  BrightFutures
//
//  Created by Thomas Visser on 09/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

/// Implementation of the `AsyncType` protocol
/// `Async` represents the result of an asynchronous operation
/// and is typically returned from a method that initiates that
/// asynchronous operation.
/// Clients of that method receive the `Async` and can use it
/// to register a callback for when the result of the asynchronous
/// operation comes in.
/// 
/// This class is often not used directly. Instead, its subclass
/// `Future` is used.
open class Async<Value>: AsyncType {

    typealias CompletionCallback = (Value) -> Void
    
    /// The actual result of the operation that the receiver represents or
    /// `.None` if the operation is not yet completed.
    public fileprivate(set) var result: Value? {
        willSet {
            assert(result == nil)
        }
        
        didSet {
            assert(result != nil)
            runCallbacks()
        }
    }
    
    /// This queue is used for all callback related administrative tasks
    /// to prevent that a callback is added to a completed future and never
    /// executed or perhaps excecuted twice.
    fileprivate let queue = DispatchQueue(label: "Internal Async Queue")

    /// Upon completion of the future, all callbacks are asynchronously scheduled to their
    /// respective execution contexts (which is either given by the client or returned from
    /// DefaultThreadingModel). Inside the context, this semaphore will be used
    /// to make sure that all callbacks are executed serially.
    fileprivate let callbackExecutionSemaphore = DispatchSemaphore(value: 1);
    fileprivate var callbacks = [CompletionCallback]()
    
    /// Creates an uncompleted `Async`
    public required init() {
        
    }
    
    /// Creates an `Async` that is completed with the given result
    public required init(result: Value) {
        self.result = result
    }
    
    /// Creates an `Async` that will be completed with the given result after the specified delay
    public required init(result: Value, delay: DispatchTimeInterval) {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + delay) {
            self.complete(result)
        }
    }
    
    /// Creates an `Async` that is completed when the given other `Async` is completed
    public required init<A: AsyncType>(other: A) where A.Value == Value {
        completeWith(other)
    }
    
    /// Creates an `Async` that can be completed by calling the `result` closure passed to
    /// the `resolver`. Example:
    ///
    ///     Async { res in
    ///         Queue.async {
    ///             // do some work
    ///             res(42) // complete the async with result '42'
    ///         }
    ///     }
    ///
    public required init(resolver: (_ result: @escaping (Value) -> Void) -> Void) {
        resolver { val in
            self.complete(val)
        }
    }
    
    private func runCallbacks() {
        guard let result = self.result else {
            assert(false, "can only run callbacks on a completed future")
            return
        }
        
        for callback in self.callbacks {
            callback(result)
        }
        
        self.callbacks.removeAll()
    }
    
    /// Adds the given closure as a callback for when the Async completes. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    @discardableResult
    open func onComplete(_ context: ExecutionContext = DefaultThreadingModel(), callback: @escaping (Value) -> Void) -> Self {
        let wrappedCallback : (Value) -> Void = { [weak self] value in
            let s = self
            context {
                s?.callbackExecutionSemaphore.context {
                    callback(value)
                }
                return
            }
        }
        
        queue.sync {
            if let value = self.result {
                wrappedCallback(value)
            } else {
                self.callbacks.append(wrappedCallback)

            }
        }
        
        return self
    }
    
}

extension Async: MutableAsyncType {
    @discardableResult
    func tryComplete(_ value: Value) -> Bool{
        return queue.sync {
            guard self.result == nil else {
                return false
            }
            
            self.result = value
            return true
        }
    }
}

extension Async: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "Async<\(Value.self)>(\(self.result))"
    }
    
    public var debugDescription: String {
        return description
    }
}
