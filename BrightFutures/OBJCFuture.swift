//
//  OBJCFuture.swift
//  BrightFutures
//
//  Created by Thomas Visser on 29/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

func bridge(future: Future<AnyObject>) -> BFFuture {
    return BFFuture(future: future)
}

func bridge(future: BFFuture) -> Future<AnyObject> {
    return future.future
}

func bridge(result: Result<AnyObject>) -> BFResult {
    return bridge(result)!
}

func bridge(optionalResult: Result<AnyObject>?) -> BFResult? {
    if let res = optionalResult {
        switch res {
        case .Success(let boxedValue):
            return BFResult(value: boxedValue.value)
        case .Failure(let error):
            return BFResult(error: error)
        }
    }
    
    return nil
}

func bridge(result: BFResult) -> Result<AnyObject> {
    if result.isSuccess {
        return Result.Success(Box(result.value!))
    }
    return Result.Failure(result.error!)
}

func bridge(result: BFExecutionContext) -> ExecutionContext {
    return toContext(result)
}

func bridge<T>(f: T -> Future<AnyObject>) -> (T -> BFFuture) {
    return { param in
        bridge(f(param))
    }
}

func bridge<T>(f: T -> BFFuture) -> (T -> Future<AnyObject>) {
    return { param in
        bridge(f(param))
    }
}

func bridge<T>(f: T -> BFResult) -> (T -> Result<AnyObject>) {
    return { param in
        bridge(f(param))
    }
}

func bridge(f: BFResult -> ()) -> (Result<AnyObject> -> ()) {
    return { res in
        f(bridge(res))
    }
}

func bridge<L: AnyObject,R: AnyObject>(future: Future<(L,R)>) -> Future<AnyObject> {
    return future.map { l,r -> AnyObject in
        [l, r]
    }
}

@objc public class BFFuture: NSObject {
    
    let future: Future<AnyObject>
    
    internal convenience override init() {
        self.init(future: Future<AnyObject>())
    }
    
    internal init(future: Future<AnyObject>) {
        self.future = future
    }
}

public extension BFFuture {

    public var result: BFResult? {
        return bridge(self.future.result)
    }
    
    public var value: AnyObject? {
        return self.future.value
    }
    
    public var error: NSError? {
        return self.future.error
    }
    
    public var isSuccess: Bool {
        return self.future.isSuccess
    }
    
    public var isFailure: Bool {
        return self.future.isFailure
    }
    
    public var isCompleted: Bool {
        return self.result != nil
    }
    
    public class func succeeded(value: AnyObject) -> BFFuture {
        return bridge(Future.succeeded(value))
    }
    
    public class func failed(error: NSError) -> BFFuture {
        return bridge(Future.failed(error))
    }

    public class func completed(result: BFResult) -> BFFuture {        
        return bridge(Future<AnyObject>.completed(bridge(result)))
    }
    
    public class func completeAfter(delay: NSTimeInterval, withValue value: AnyObject) -> BFFuture {
        return bridge(Future.completeAfter(delay, withValue: value))
    }
    
    public class func never() -> BFFuture {
        return BFFuture()
    }
    
}

public extension BFFuture {
    
    public func forced() -> BFResult? {
        return bridge(self.future.forced())
    }
    
    public func forced(timeout: NSTimeInterval) -> BFResult? {
        return bridge(self.future.forced(timeout))
    }
}
    
public extension BFFuture {

    public func onComplete(callback: (BFResult) -> ()) -> BFFuture {
        self.future.onComplete(bridge(callback))
        return self
    }

    public func onComplete(context c: BFExecutionContext, callback: (BFResult) -> ()) -> BFFuture {
        self.future.onComplete(bridge(c), bridge(callback))
        return self
    }
    
    public func onSuccess(callback: (AnyObject) -> ()) -> BFFuture {
        self.future.onSuccess(callback)
        return self
    }
    
    public func onSuccess(context c: BFExecutionContext, callback: (AnyObject) -> ()) -> BFFuture {
        self.future.onSuccess(toContext(c), callback)
        return self
    }
    
    public func onFailure(callback: (NSError) -> ()) -> BFFuture {
        self.future.onFailure(callback)
        return self
    }
    
    public func onFailure(context c: BFExecutionContext, callback: (NSError) -> ()) -> BFFuture {
        self.future.onFailure(toContext(c), callback)
        return self
    }
}

public extension BFFuture {
    
    public func flatMap(f: AnyObject -> BFFuture) -> BFFuture {
        return bridge(self.future.flatMap(bridge(f)))
    }
    
    public func flatMap(context c: BFExecutionContext, f: AnyObject -> BFFuture) -> BFFuture {
        return bridge(self.future.flatMap(toContext(c), bridge(f)))
    }
    
    public func flatMapResult(f: AnyObject -> BFResult) -> BFFuture {
        return bridge(self.future.flatMap(bridge(f)))
    }
    
    public func flatMapResult(context c: BFExecutionContext, f: AnyObject -> BFResult) -> BFFuture {
        return bridge(self.future.flatMap(toContext(c), bridge(f)))
    }
    
    public func map(f: AnyObject -> AnyObject) -> BFFuture {
        return bridge(self.future.map(f))
    }
    
    public func map(context c: BFExecutionContext, f: AnyObject -> AnyObject) -> BFFuture {
        return bridge(self.future.map(context: toContext(c), f: f))
    }
    
    public func andThen(callback: BFResult -> ()) -> BFFuture {
        return bridge(self.future.andThen(bridge(callback)))
    }
    
    public func andThen(context c: BFExecutionContext, callback: BFResult -> ()) -> BFFuture {
        return bridge(self.future.andThen(toContext(c), bridge(callback)))
    }
    
    public func recover(task: (NSError) -> AnyObject) -> BFFuture {
        return bridge(self.future.recover(task))
    }
    
    public func recover(context c: BFExecutionContext, task: (NSError) -> AnyObject) -> BFFuture {
        return bridge(self.future.recover(toContext(c), task))
    }
    
    public func recoverAsync(task: (NSError) -> BFFuture) -> BFFuture {
        return bridge(self.future.recoverWith(bridge(task)))
    }
    
    public func recoverAsync(context c: BFExecutionContext, task: (NSError) -> BFFuture) -> BFFuture {
        return bridge(self.future.recoverWith(bridge(c), bridge(task)))
    }
    
    // Returns an array with two elements instead of a tuple
    public func zip(that: BFFuture) -> BFFuture {
        return bridge(bridge(self.future.zip(bridge(that))))
    }
    
    public func filter(p: AnyObject -> Bool) -> BFFuture {
        return bridge(self.future.filter(p))
    }
}

@objc public class BFExecutionContext {
    
    public class var mainQueue: BFExecutionContext {
        struct Static {
            static let instance : BFExecutionContext = BFExecutionContext(context: Queue.main.context)
        }
        return Static.instance
    }
    
    public class var globalQueue: BFExecutionContext {
        struct Static {
            static let instance : BFExecutionContext = BFExecutionContext(context: Queue.global.context)
        }
        return Static.instance
    }
    
    public class var immediate: BFExecutionContext {
        struct Static {
            static let instance : BFExecutionContext = BFExecutionContext(context: { task in task() })
        }
        return Static.instance
    }
    
    internal let context: ExecutionContext
    
    public init(context: ExecutionContext) {
        self.context = context
    }

}

func toContext(context: BFExecutionContext) -> ExecutionContext {
    return context.context
}

@objc public class BFPromise : NSObject {
    
    private let promise: Promise<AnyObject>
    
    public var future: BFFuture {
        return bridge(self.promise.future)
    }
    
    public override init() {
        self.promise = Promise<AnyObject>()
    }
    
    public func completeWith(future: BFFuture) {
        self.promise.completeWith(bridge(future))
    }
    
    public func success(value: AnyObject) {
        self.promise.success(value)
    }
    
    public func trySuccess(value: AnyObject) -> Bool {
        return self.promise.trySuccess(value)
    }
    
    public func failure(error: NSError) {
        self.promise.failure(error)
    }
    
    public func tryFailure(error: NSError) -> Bool {
        return self.promise.tryFailure(error)
    }
    
    public func complete(result: BFResult) {
        return self.promise.complete(bridge(result))
    }
    
    public func tryComplete(result: BFResult) -> Bool {
        return self.promise.tryComplete(bridge(result))
    }
    
}


@objc public class BFResult {
    
    internal var success: Bool
    public var value: AnyObject?
    public var error: NSError?
    
    public var isSuccess: Bool {
        return success
    }
    
    public var isFailure: Bool {
        return !self.isSuccess
    }
    
    public init(value: AnyObject?) {
        self.value = value
        self.success = true
    }
    
    public init(error: NSError) {
        self.error = error
        self.success = false
    }
}

