//
//  Async.swift
//  BrightFutures
//
//  Created by Thomas Visser on 09/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public class Async<Value>: AsyncType {

    typealias CompletionCallback = Value -> ()
    
    public var value: Value? {
        willSet {
            assert(value == nil)
        }
        
        didSet {
            assert(value != nil)
            try! runCallbacks()
        }
    }
    
    private let queue = Queue()
    private let callbackExecutionSemaphore = Semaphore(value: 1);
    private var callbacks = [CompletionCallback]()
    
    public required init() {
        
    }
    
    public required init(value: Value) {
        self.value = value
    }
    
    public required init<A: AsyncType where A.Value == Value>(other: A) {
        completeWith(other)
    }
    
    private func runCallbacks() throws {
        guard let value = self.value else {
            throw BrightFuturesError<NoError>.IllegalState
        }
        
        for callback in self.callbacks {
            callback(value)
        }
        
        self.callbacks.removeAll()
    }
    
    public func complete(value: Value) throws {
        try queue.sync {
            guard self.value == nil else {
                throw BrightFuturesError<NoError>.IllegalState
            }
            
            self.value = value
        }
    }
    
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return self.value != nil
    }
    
    public func onComplete(context c: ExecutionContext = DefaultThreadingModel(), callback: Value -> ()) -> Self {
        let wrappedCallback : Value -> () = { future in
            if let value = self.value {
                c {
                    self.callbackExecutionSemaphore.execute {
                        callback(value)
                        return
                    }
                    return
                }
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

extension Async: MutableAsyncType { }
