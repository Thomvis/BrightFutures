// The MIT License (MIT)
//
// Copyright (c) 2014 Thomas Visser
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

public func future<T>(context c: ExecutionContext = Queue.global, task: () -> T) -> Future<T> {
    return future(context: c, { () -> Result<T> in
        return Result<T>(task())
    })
}

public func future<T>(context c: ExecutionContext = Queue.global, task: @autoclosure () -> T) -> Future<T> {
    return future(context: c, { () -> Result<T> in
        return Result<T>(task())
    })
}

public func future<T>(context c: ExecutionContext = Queue.global, task: () -> Result<T>) -> Future<T> {
    let promise = Promise<T>();
    
    c.execute {
        let result = task()
        switch result {
        case .Success(let boxedValue):
            promise.success(boxedValue.value)
        case .Failure(let error):
            promise.failure(error)
        }
    }
    
    return promise.future
}

public let NoSuchElementError = 0
public let BrightFuturesErrorDomain = "nl.thomvis.BrightFutures"

public class Future<T> : Deferred<Result<T>> {
    
    public typealias FailureCallback = (NSError) -> ()
    public typealias SuccessCallback = (T) -> ()
    
    public required init() {
        
    }
    
}

/**
 * The internal API for completing a Future
 */
internal extension Future {
    
    func success(value: T) {
        self.complete(.Success(Box(value)))
    }
    
    func trySuccess(value: T) -> Bool {
        return self.tryComplete(.Success(Box(value)))
    }
    
    func failure(error: NSError) {
        self.complete(.Failure(error))
    }
    
    func tryFailure(error: NSError) -> Bool {
        return self.tryComplete(.Failure(error))
    }
}

/**
 * This extension contains all (static) methods for Future creation
 */
public extension Future {
    
    public var value: T? {
        get {
            return self.result?.value
        }
    }
    
    public var error: NSError? {
        get {
            return self.result?.error
        }
    }
    
    public var isSuccess: Bool {
        get {
            return self.result?.isSuccess ?? false
        }
    }
    
    public var isFailure: Bool {
        get {
            return self.result?.isFailure ?? false
        }
    }
    
    public class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = Result(value)
        
        return res
    }
    
    public class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = .Failure(error)
        
        return res
    }
    
    public class func completed<T>(result: Result<T>) -> Future<T> {
        let res = Future<T>()
        res.result = result
        
        return res
    }
    
    public class func succeedAfter(delay: NSTimeInterval, withValue value: T) -> Future<T> {
        return Future.completeAfter(delay, withResult: .Success(Box(value)))
    }
    
    public class func failAfter(delay: NSTimeInterval, withValue error: NSError) -> Future<T> {
        return Future.completeAfter(delay, withResult: .Failure(error))
    }
}

/**
 * This extension contains all methods for registering callbacks
 */
public extension Future {
    
    public func onSuccess(callback: SuccessCallback) -> Future<T> {
        return self.onSuccess(context: executionContextForCurrentContext(), callback)
    }
    
    public func onSuccess(context c: ExecutionContext, callback: SuccessCallback) -> Future<T> {
        self.onComplete(context: c) { result in
            switch result {
            case .Success(let val):
                callback(val.value)
            default:
                break
            }
        }
        
        return self
    }
    
    public func onFailure(callback: FailureCallback) -> Future<T> {
        return self.onFailure(context: executionContextForCurrentContext(), callback)
    }
    
    public func onFailure(context c: ExecutionContext, callback: FailureCallback) -> Future<T> {
        self.onComplete(context: c) { result in
            switch result {
            case .Failure(let err):
                callback(err)
            default:
                break
            }
        }
        return self
    }
}

/**
 * This extension contains all methods related to functional composition
 */
public extension Future {

    public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
        return self.flatMap(context: executionContextForCurrentContext(), f)
    }

    public func flatMap<U>(context c: ExecutionContext, f: T -> Future<U>) -> Future<U> {
        let p: Promise<U> = Promise()
        self.onComplete(context: c) { res in
            switch (res) {
            case .Failure(let e):
                p.failure(e)
            case .Success(let v):
                p.completeWith(f(v.value))
            }
        }
        return p.future
    }
    
    public func flatMap<U>(f: T -> Result<U>) -> Future<U> {
        return self.flatMap(context: executionContextForCurrentContext(), f)
    }
    
    public func flatMap<U>(context c: ExecutionContext, f: T -> Result<U>) -> Future<U> {
        return self.flatMap(context: c) { value -> Future<U> in
            Future.completed(f(value))
        }
    }

    public func map<U>(f: (T) -> U) -> Future<U> {
        return self.map(context: executionContextForCurrentContext(), f)
    }

    public func map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result {
            case .Success(let v):
                p.success(f(v.value))
                break;
            case .Failure(let e):
                p.failure(e)
                break;
            }
        })
        
        return p.future
    }

    public func andThen(callback: Result<T> -> ()) -> Future<T> {
        return self.andThen(context: executionContextForCurrentContext(), callback: callback)
    }

    public func andThen(context c: ExecutionContext, callback: Result<T> -> ()) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result in
            callback(result)
            p.completeWith(self)
        }

        return p.future
    }
    
    public func recover(task: (NSError) -> T) -> Future<T> {
        return self.recover(context: executionContextForCurrentContext(), task)
    }
    
    public func recover(context c: ExecutionContext, task: (NSError) -> T) -> Future<T> {
        return self.recoverWith(context: c) { error -> Future<T> in
            return Future.succeeded(task(error))
        }
    }
    
    public func recoverWith(task: (NSError) -> Future<T>) -> Future<T> {
        return self.recoverWith(context: executionContextForCurrentContext(), task: task)
    }
    
    public func recoverWith(context c: ExecutionContext, task: (NSError) -> Future<T>) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result -> () in
            switch result {
            case .Failure(let err):
                p.completeWith(task(err))
            case .Success(let val):
                p.completeWith(self)
            }
        }
        
        return p.future;
    }
    
    public func zip<U>(that: Future<U>) -> Future<(T,U)> {
        return self.flatMap { thisVal -> Future<(T,U)> in
            return that.map { thatVal in
                return (thisVal, thatVal)
            }
        }
    }
    
    public func filter(p: T -> Bool) -> Future<T> {
        let promise = Promise<T>()
        
        self.onComplete { result in
            switch result {
            case .Success(let val):
                if p(val.value) {
                    promise.completeWith(self)
                } else {
                    promise.failure(NSError(domain: BrightFuturesErrorDomain, code: NoSuchElementError, userInfo: nil))
                }
                break
            case .Failure(let err):
                promise.failure(err)
            }
        }
        
        return promise.future
    }
}
