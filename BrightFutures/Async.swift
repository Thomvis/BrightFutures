//
//  Async.swift
//  BrightFutures
//
//  Created by Thomas Visser on 09/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public class Async<Value>: AsyncType {

    typealias CompletionCallback = Value -> Void
    
    public private(set) var value: Value? {
        willSet {
            assert(value == nil)
        }
        
        didSet {
            assert(value != nil)
            try! runCallbacks()
        }
    }
    
    /// This queue is used for all callback related administrative tasks
    /// to prevent that a callback is added to a completed future and never
    /// executed or perhaps excecuted twice.
    private let queue = Queue()

    /// Upon completion of the future, all callbacks are asynchronously scheduled to their
    /// respective execution contexts (which is either given by the client or returned from
    /// DefaultThreadingModel). Inside the context, this semaphore will be used
    /// to make sure that all callbacks are executed serially.
    private let callbackExecutionSemaphore = Semaphore(value: 1);
    private var callbacks = [CompletionCallback]()
    
    public required init() {
        
    }
    
    public required init(value: Value) {
        self.value = value
    }
    
    public required init(value: Value, delay: NSTimeInterval) {
        Queue.global.after(TimeInterval.In(delay)) {
            try! self.complete(value)
        }
    }
    
    public required init<A: AsyncType where A.Value == Value>(other: A) {
        completeWith(other)
    }
    
    private func runCallbacks() throws {
        guard let result = self.value else {
            throw BrightFuturesError<NoError>.IllegalState
        }
        
        for callback in self.callbacks {
            callback(result)
        }
        
        self.callbacks.removeAll()
    }
    
    /// Adds the given closure as a callback for when the Async completes. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onComplete(context c: ExecutionContext = DefaultThreadingModel(), callback: Value -> Void) -> Self {
        let wrappedCallback : Value -> Void = { value in
            c {
                self.callbackExecutionSemaphore.execute {
                    callback(value)
                }
                return
            }
        }
        
        queue.sync {
            if let value = self.value {
                wrappedCallback(value)
            } else {
                self.callbacks.append(wrappedCallback)

            }
        }
        
        return self
    }
    
}

extension Async: MutableAsyncType {
    func complete(value: Value) throws {
        try queue.sync {
            guard self.value == nil else {
                throw BrightFuturesError<NoError>.IllegalState
            }
            
            self.value = value
        }
    }
}

extension Async: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return "Async<\(Value.self)>(\(self.value))"
    }
    
    public var debugDescription: String {
        return description
    }
}
