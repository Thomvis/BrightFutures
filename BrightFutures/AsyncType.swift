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
    
    var value: Value? { get }
    
    init()
    init(value: Value)
    init(value: Value, delay: NSTimeInterval)
    init<A: AsyncType where A.Value == Value>(other: A)
    
    func onComplete(context c: ExecutionContext, callback: Value -> Void) -> Self
    
    func map<U>(context: ExecutionContext, transform: Value -> U) -> Async<U>;
}

public extension AsyncType {
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return self.value != nil
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
