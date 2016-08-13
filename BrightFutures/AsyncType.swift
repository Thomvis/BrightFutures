//
//  Async.swift
//  BrightFutures
//
//  Created by Thomas Visser on 09/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public protocol AsyncType {
    associatedtype Value
    
    var result: Value? { get }
    
    init()
    init(result: Value)
    init(result: Value, delay: DispatchTimeInterval)
    init<A: AsyncType where A.Value == Value>(other: A)
    init(resolver: @noescape (result: (Value) -> Void) -> Void)
    
    @discardableResult
    func onComplete(_ context: ExecutionContext, callback: (Value) -> Void) -> Self
}

public extension AsyncType {
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return result != nil
    }
    
    /// Blocks the current thread until the future is completed and then returns the result
    public func forced() -> Value {
        return forced(timeout: DispatchTime.distantFuture)!
    }
    
    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(timeout: DispatchTime) -> Value? {
        if let result = result {
            return result
        }
        
        let sema = DispatchSemaphore(value: 0)
        var res: Value? = nil
        onComplete(DispatchQueue.global().context) {
            res = $0
            sema.signal()
        }
        
        let _ = sema.wait(timeout: timeout)
        
        return res
    }
    
    /// Alias of delay(queue:interval:)
    /// Will pass the main queue if we are currently on the main thread, or the
    /// global queue otherwise
    public func delay(_ interval: DispatchTimeInterval) -> Self {
        if Thread.isMainThread {
            return delay(DispatchQueue.main, interval: interval)
        }
        
        return delay(DispatchQueue.global(), interval: interval)
    }

    /// Returns an Async that will complete with the result that this Async completes with
    /// after waiting for the given interval
    /// The delay is implemented using dispatch_after. The given queue is passed to that function.
    /// If you want a delay of 0 to mean 'delay until next runloop', you will want to pass the main
    /// queue.
    public func delay(_ queue: DispatchQueue, interval: DispatchTimeInterval) -> Self {
        return Self { complete in
            onComplete(ImmediateExecutionContext) { result in
                queue.asyncAfter(deadline: DispatchTime.now() + interval) {
                    complete(result)
                }
            }
        }
    }
}

public extension AsyncType where Value: AsyncType {
    public func flatten() -> Self.Value {
        return Self.Value { complete in
            self.onComplete(ImmediateExecutionContext) { value in
                value.onComplete(ImmediateExecutionContext, callback: complete)
            }
        }
    }
}
