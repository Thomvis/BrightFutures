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
    init(result: Value, delay: NSTimeInterval)
    init<A: AsyncType where A.Value == Value>(other: A)
    init(@noescape resolver: (result: Value -> Void) -> Void)
    
    func onComplete(context: ExecutionContext, callback: Value -> Void) -> Self
}

public extension AsyncType {
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return result != nil
    }
    
    /// Blocks the current thread until the future is completed and then returns the result
    public func forced() -> Value {
        return forced(TimeInterval.Forever)!
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
        }
        
        let sema = Semaphore(value: 0)
        var res: Value? = nil
        onComplete(Queue.global.context) {
            res = $0
            sema.signal()
        }
        
        sema.wait(timeout)
        
        return res
    }
    
    /// Alias of delay(queue:interval:)
    /// Will pass the main queue if we are currently on the main thread, or the
    /// global queue otherwise
    public func delay(interval: NSTimeInterval) -> Self {
        if NSThread.isMainThread() {
            return delay(Queue.main, interval: interval)
        }
        
        return delay(Queue.global, interval: interval)
    }

    /// Returns an Async that will complete with the result that this Async completes with
    /// after waiting for the given interval
    /// The delay is implemented using dispatch_after. The given queue is passed to that function.
    /// If you want a delay of 0 to mean 'delay until next runloop', you will want to pass the main
    /// queue.
    public func delay(queue: Queue, interval: NSTimeInterval) -> Self {
        return Self { complete in
            onComplete(ImmediateExecutionContext) { result in
                queue.after(.In(interval)) {
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
