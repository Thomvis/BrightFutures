//
//  Deferred.swift
//  BrightFutures
//
//  Created by Thomas Visser on 13/06/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public protocol DeferredType {
    typealias Res
    
    var result: Res? { get }
    
    init(result: Res)
    
    func onComplete(context c: ExecutionContext, callback: Res -> ()) -> Self
}

public extension DeferredType {
    
    func flatMap<D: DeferredType, U where D.Res == U>(f: Res -> D) -> D {
        return map(transform: f).flatten()
    }
    
    func map<U>(context c: ExecutionContext = executionContextForCurrentContext(),transform: Res -> U) -> Deferred<U> {
        fatalError()
    }
    
}

extension DeferredType where Res: DeferredType {
    
    func flatten() -> Res {
        fatalError()
    }
    
}

public class Deferred<R>: DeferredType {
    typealias Res = R
    
    public var result: R? {
        willSet {
            assert(result == nil)
        }
        
        didSet {
            runCallbacks()
        }
    }
    
    private let queue = Queue()
    let callbackExecutionSemaphore = Semaphore(value: 1);
    private var callbacks = Array<(Deferred<R> -> ())>()
    
    public init() {
        
    }
    
    public required init(result: R) {
        self.result = result
    }
    
    private func runCallbacks() {
        for callback in self.callbacks {
            callback(self)
        }
        
        self.callbacks.removeAll()
    }
    
    func complete(result: R) throws {
        try queue.sync {
            guard self.result == nil else {
                throw BrightFuturesError<NoError>.IllegalState
            }
            
            self.result = result
        }
    }
    
    func tryComplete(result: R) -> Bool {
        do {
            try complete(result)
            return true
        } catch {
            return false
        }
    }
    
    public func onComplete(context c: ExecutionContext = executionContextForCurrentContext(), callback: Res -> ()) -> Self {
        let wrappedCallback : Deferred<R> -> () = { future in
            if let realRes = self.result {
                c {
                    self.callbackExecutionSemaphore.execute {
                        callback(realRes)
                        return
                    }
                    return
                }
            }
        }
        
        queue.sync {
            if self.result == nil {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
        
        return self
    }
}

public func deferred<R>(context: ExecutionContext = Queue.global.context, task: () -> R) -> Deferred<R> {
    
    let d = Deferred<R>()
    
    context {
        try! d.complete(task())
    }
    
    return d
}

