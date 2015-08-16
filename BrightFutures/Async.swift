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
    
    public private(set) var result: Value? {
        willSet {
            assert(result == nil)
        }
        
        didSet {
            assert(result != nil)
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
    
    public required init(result: Value) {
        self.result = result
    }
    
    public required init(result: Value, delay: NSTimeInterval) {
        Queue.global.after(TimeInterval.In(delay)) {
            try! self.complete(result)
        }
    }
    
    public required init<A: AsyncType where A.Value == Value>(other: A) {
        completeWith(other)
    }
    
    public required init(@noescape resolver: (result: Value throws -> Void) -> Void) {
        resolver { val in
            try self.complete(val)
        }
    }
    
    private func runCallbacks() throws {
        guard let result = self.result else {
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
    public func onComplete(context: ExecutionContext = DefaultThreadingModel(), callback: Value -> Void) -> Self {
        let wrappedCallback : Value -> Void = { value in
            context {
                self.callbackExecutionSemaphore.execute {
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
    func complete(value: Value) throws {
        try queue.sync {
            guard self.result == nil else {
                throw BrightFuturesError<NoError>.IllegalState
            }
            
            self.result = value
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
