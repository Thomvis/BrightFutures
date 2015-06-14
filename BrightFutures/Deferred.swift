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
    
    init()
    init(result: Res)
    init<D: DeferredType where D.Res == Res>(other: D)
    
    func onComplete(context c: ExecutionContext, callback: Res -> ()) -> Self
}

internal protocol MutableDeferredType: DeferredType {
    func complete(result: Res) throws
}

extension MutableDeferredType {
    func tryComplete(result: Res) -> Bool {
        do {
            try complete(result)
            return true
        } catch {
            return false
        }
    }
    
    func completeWith<D: DeferredType where D.Res == Res>(other: D) {
        other.onComplete(context: ImmediateExecutionContext, callback: { try! self.complete($0) })
    }
}

public extension DeferredType {
    
    func flatMap<D: DeferredType, U where D.Res == U>(f: Res -> D) -> D {
        return map(f).flatten()
    }
    
    /// Shorthand for map(context:transform:), needed to be able to do d.map(func)
    func map<U>(transform: Res -> U) -> Deferred<U> {
        return map(context: defaultContext(), transform: transform)
    }
    
    func map<U>(context c: ExecutionContext, transform: Res -> U) -> Deferred<U> {
        let d = Deferred<U>()
        
        onComplete(context: c) { res in
            try! d.complete(transform(res))
        }
        
        return d
    }
    
    static func completed(result: Res) -> Self {
        return Self(result: result)
    }
    
    static func never() -> Self {
        return Self()
    }
    
    /// Returns a new future that will succeed with the given value after the given time interval
    /// The implementation of this function uses dispatch_after
    static func completeAfter(delay: NSTimeInterval, withResult result: Res) -> Self {
        let res = Deferred<Res>()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC))), Queue.global.underlyingQueue) {
            try! res.complete(result)
        }
        
        return Self(other: res)
    }
    
    public func forceType<U>() -> Deferred<U> {
        return map(context: ImmediateExecutionContext) {
            $0 as! U
        }
    }
    
    public func asVoid() -> Deferred<Void> {
        return map { _ in () }
    }
    
    public func forced() -> Res? {
        return self.forced(TimeInterval.Forever)
    }

    public func forced(timeout: NSTimeInterval) -> Res? {
        return self.forced(.In(timeout))
    }

    public func forced(timeout: TimeInterval) -> Res? {
        if let certainResult = self.result {
            return certainResult
        } else {
            let sema = Semaphore(value: 0)
            var res: Res? = nil

            self.onComplete(context: Queue.global.context) {
                res = $0
                sema.signal()
            }

            sema.wait(timeout)
            
            return res
        }
    }
    
    public func andThen(context c: ExecutionContext = defaultContext(), callback: Res -> ()) -> Self {
        let d = Deferred<Res>()
        
        onComplete(context: c) { res in
            callback(res)
            try! d.complete(res)
        }
        
        return Self(other: d)
    }
    
    public func zip<D: DeferredType>(other: D) -> Deferred<(Res,D.Res)> {
        return self.flatMap { thisVal -> Deferred<(Res,D.Res)> in
            return other.map { thatVal in
                return (thisVal, thatVal)
            }
        }
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
    private let callbackExecutionSemaphore = Semaphore(value: 1);
    private var callbacks = Array<(Deferred<R> -> ())>()
    
    public required init() {
        
    }
    
    public required init(result: R) {
        self.result = result
    }
    
    public required init<D: DeferredType where D.Res == Res>(other: D) {
        completeWith(other)
    }
    
    private func runCallbacks() {
        for callback in self.callbacks {
            callback(self)
        }
        
        self.callbacks.removeAll()
    }
    
    public func complete(result: R) throws {
        try queue.sync {
            guard self.result == nil else {
                throw BrightFuturesError<NoError>.IllegalState
            }
            
            self.result = result
        }
    }
    
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return self.result != nil
    }
    
    public func onComplete(context c: ExecutionContext = defaultContext(), callback: Res -> ()) -> Self {
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

extension Deferred: MutableDeferredType { }

public func deferred<R>(context: ExecutionContext = Queue.global.context, task: () -> R) -> Deferred<R> {
    
    let d = Deferred<R>()
    
    context {
        try! d.complete(task())
    }
    
    return d
}

