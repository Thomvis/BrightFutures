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
    init(@noescape resolver: (result: Value throws -> Void) -> Void)
    
    func onComplete(context: ExecutionContext, callback: Value -> Void) -> Self
}

public extension AsyncType {
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return result != nil
    }
    
    /// Blocks the current thread until the future is completed and then returns the result
    public func forced() -> Value? {
        return forced(TimeInterval.Forever)
    }
    
    
    /// See `forced(timeout: TimeInterval) -> Value?`
    public func forced(timeout: NSTimeInterval) -> Value? {
        return forced(.In(timeout))
    }
    
    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(timeout: TimeInterval) -> Value? {
        if let result = result {
            return result
        } else {
            let sema = Semaphore(value: 0)
            var res: Value? = nil
            onComplete(Queue.global.context) {
                res = $0
                sema.signal()
            }
            
            sema.wait(timeout)
            
            return res
        }
    }
}

public extension AsyncType where Value: AsyncType {
    public func flatten() -> Self.Value {
        return Self.Value { complete in
            self.onComplete(ImmediateExecutionContext) { value in
                value.onComplete(ImmediateExecutionContext) { innerValue in
                    try! complete(innerValue)
                }
            }
        }
    }
}
