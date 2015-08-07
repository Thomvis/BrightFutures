//
//  Async.swift
//  BrightFutures
//
//  Created by Thomas Visser on 09/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public protocol AsyncType {
    typealias Value
    
    var result: Value? { get }
    
    init()
    init(result: Value)
    init(result: Value, delay: NSTimeInterval)
    init<A: AsyncType where A.Value == Value>(other: A)
    
    func onComplete(context c: ExecutionContext, callback: Value -> Void) -> Self
    
    func map<U>(context: ExecutionContext, transform: Value -> U) -> Async<U>;
}

public extension AsyncType {
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return self.result != nil
    }
    
    /// Blocks the current thread until the future is completed and then returns the result
    public func forced() -> Value? {
        return self.forced(TimeInterval.Forever)
    }
    
    
    /// See `forced(timeout: TimeInterval) -> Value?`
    public func forced(timeout: NSTimeInterval) -> Value? {
        return self.forced(.In(timeout))
    }
    
    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(timeout: TimeInterval) -> Value? {
        if let result = self.result {
            return result
        } else {
            let sema = Semaphore(value: 0)
            var res: Value? = nil
            self.onComplete(context: Queue.global.context) {
                res = $0
                sema.signal()
            }
            
            sema.wait(timeout)
            
            return res
        }
    }
    
    /// See `map<U>(context c: ExecutionContext, f: T -> U) -> Async<U>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func map<U>(transform: Value -> U) -> Async<U> {
        return self.map(DefaultThreadingModel(), transform: transform)
    }
    
    /// Returns an Async that succeeds with the value returned from the given closure when it is invoked with the success value
    /// from this future. If this Async fails, the returned future fails with the same error.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func map<U>(context: ExecutionContext, transform: Value -> U) -> Async<U> {
        let res = Async<U>()
        
        onComplete(context: context) { value in
            try! res.complete(transform(value))
        }
        
        return res
    }
    
}
