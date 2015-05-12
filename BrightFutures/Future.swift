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
import Result

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(@autoclosure(escaping) task: () -> T) -> Future<T> {
    return future(context: Queue.global.context, task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(task: () -> T) -> Future<T> {
    return future(context: Queue.global.context, task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T>(context c: ExecutionContext, task: () -> T) -> Future<T> {
    return future(context: c, { () -> Result<T,NSError> in
        return Result(value: task())
    })
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(@autoclosure(escaping) task: () -> Result<T,NSError>) -> Future<T> {
    return future(context: Queue.global.context, task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(task: () -> Result<T,NSError>) -> Future<T> {
    return future(context: Queue.global.context, task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T>(context c: ExecutionContext, task: () -> Result<T,NSError>) -> Future<T> {
    let promise = Promise<T>();
    
    c {
        let result = task()
        switch result {
        case .Success(let boxedValue):
            promise.success(boxedValue.value)
        case .Failure(let boxedError):
            promise.failure(boxedError.value)
        }
    }
    
    return promise.future
}

/// Defines BrightFutures' default threading behavior:
/// - if on the main thread, `Queue.main.context` is returned
/// - if off the main thread, `Queue.global.context` is returned
func executionContextForCurrentContext() -> ExecutionContext {
    return toContext(NSThread.isMainThread() ? Queue.main : Queue.global)
}

/// The error domain used for all errors returned by BrightFutures
public let BrightFuturesErrorDomain = "nl.thomvis.BrightFutures"

/// An enum representing every possible error code for errors returned by BrightFutures
public enum ErrorCode: Int {
    case NoSuchElement
    case InvalidationTokenInvalidated
    
    var errorDescription: String {
        switch self {
        case .NoSuchElement:
            return "No such element"
        case .InvalidationTokenInvalidated:
            return "Invalidation token invalidated"
        }
    }
}

/// Creates an NSError instance with the given code, failure reason and the
internal func errorFromCode(code: ErrorCode, failureReason: String? = nil) -> NSError {
    var userInfo = [
        NSLocalizedDescriptionKey : code.errorDescription
    ]
    
    if let reason = failureReason {
        userInfo[NSLocalizedFailureReasonErrorKey] = reason
    }
    
    return NSError(domain: BrightFuturesErrorDomain, code: code.rawValue, userInfo: userInfo)
}

/// A Future represents the outcome of an asynchronous operation
/// The outcome will be represented as an instance of the `Result` enum and will be stored
/// in the `result` property. As long as the operation is not yet completed, `result` will be nil.
/// Interested parties can be informed of the completion by using one of the available callback
/// registration methods (e.g. onComplete, onSuccess & onFailure) or by immediately composing/chaining
/// subsequent actions (e.g. map, flatMap, recover, andThen, etc.).
///
/// For more info, see the project README.md
public class Future<T> {
    
    typealias CallbackInternal = (future: Future<T>) -> ()
    typealias CompletionCallback = (result: Result<T,NSError>) -> ()
    typealias SuccessCallback = (T) -> ()
    public typealias FailureCallback = (NSError) -> ()
    
    /// The result of the operation this Future represents or `nil` if it is not yet completed
    public internal(set) var result: Result<T,NSError>? = nil
    
    /// This queue is used for all callback related administrative tasks
    /// to prevent that a callback is added to a completed future and never
    /// executed or perhaps excecuted twice.
    let callbackAdministrationQueue = Queue()

    /// Upon completion of the future, all callbacks are asynchronously scheduled to their
    /// respective execution contexts (which is either given by the client or returned from
    /// executionContextForCurrentContext). Inside the context, this semaphore will be used
    /// to make sure that all callbacks are executed serially.
    let callbackExecutionSemaphore = Semaphore(value: 1);
    var callbacks: [CallbackInternal] = Array<CallbackInternal>()
    
    internal init() {
        
    }
    
    /// Should be run on the callbackAdministrationQueue
    private func runCallbacks() {
        for callback in self.callbacks {
            callback(future: self)
        }
        
        self.callbacks.removeAll()
    }
}

/// The internal API for completing a Future
internal extension Future {
    /// Completes the future with the given result
    /// If the future is already completed, this function does nothing
    /// and an assert will be raised (if enabled)
    func complete(result: Result<T,NSError>) {
        let succeeded = tryComplete(result)
        assert(succeeded)
    }
    
    /// Tries to complete the future with the given result
    /// If the future is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func tryComplete(result: Result<T,NSError>) -> Bool {
        switch result {
        case .Success(let val):
            return self.trySuccess(val.value)
        case .Failure(let err):
            return self.tryFailure(err.value)
        }
    }

    /// Completes the future with the given success value
    /// If the future is already completed, this function does nothing
    /// and an assert will be raised (if enabled)
    func success(value: T) {
        let succeeded = self.trySuccess(value)
        assert(succeeded)
    }
    
    /// Tries to complete the future with the given success value
    /// If the future is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func trySuccess(value: T) -> Bool {
        return self.callbackAdministrationQueue.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = Result(value: value)
            self.runCallbacks()
            return true;
        };
    }
    
    /// Completes the future with the given error
    /// If the future is already completed, this function does nothing
    /// and an assert will be raised (if enabled)
    func failure(error: NSError) {
        let succeeded = self.tryFailure(error)
        assert(succeeded)
    }
    
    /// Tries to complete the future with the given error
    /// If the future is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func tryFailure(error: NSError) -> Bool {
        return self.callbackAdministrationQueue.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = Result(error: error)
            self.runCallbacks()
            return true;
        };
    }
}

/// This extension contains all functions to query the current state of the Future in a synchronous & non-blocking fashion
public extension Future {
    
    /// Returns the value that the future succesfully completed with, or `nil` if the future failed or is still in progress
    public var value: T? {
        get {
            return self.result?.value
        }
    }

    /// Returns the error that the future failed with, or `nil` if the future succeeded or is still in progress
    public var error: NSError? {
        get {
            return self.result?.error
        }
    }
    
    /// `true` if the future completed with success, or `false` otherwise
    public var isSuccess: Bool {
        get {
            return result?.analysis(ifSuccess: { _ in return true }, ifFailure: { _ in return false }) ?? false
        }
    }
    
    /// `true` if the future failed, or `false` otherwise
    public var isFailure: Bool {
        get {
            return !isSuccess
        }
    }
    
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        get {
            return self.result != nil
        }
    }
}

/// This extension contains all (static) methods for Future creation
public extension Future {

    /// Returns a new future that succeeded with the given value
    public class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = Result(value: value)
        
        return res
    }
    
    /// Returns a new future that failed with the given error
    public class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = Result(error: error)
        
        return res
    }
    
    /// Returns a new future that completed with the given result
    public class func completed<T>(result: Result<T,NSError>) -> Future<T> {
        let res = Future<T>()
        res.result = result
        
        return res
    }
    
    /// Returns a new future that will succeed with the given value after the given time interval
    /// The implementation of this function uses dispatch_after
    public class func completeAfter(delay: NSTimeInterval, withValue value: T) -> Future<T> {
        let res = Future<T>()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC))), Queue.global.underlyingQueue) {
            res.success(value)
        }
        
        return res
    }
    
    /// Returns a new future that will never complete
    public class func never() -> Future<T> {
        return Future<T>()
    }
    
    /// Returns a new future with the new type.
    /// The value that this future succeeds with will be downcasted to the new type using `as!` and may fail
    public func asType<U>() -> Future<U> {
        return self.map { $0 as! U }
    }
    
    /// Returns a new future that completes with this future, but returns Void on success
    public func asVoid() -> Future<Void> {
        return self.map { _ in return () }
    }
}

/// This extension contains methods to query the current status
/// of the future and to access the result and/or error
public extension Future {
    
    /// Blocks the current thread until the future is completed and then returns the result
    public func forced() -> Result<T,NSError>? {
        return self.forced(TimeInterval.Forever)
    }
    

    /// See `forced(timeout: TimeInterval) -> Result<T,NSError>?`
    public func forced(timeout: NSTimeInterval) -> Result<T,NSError>? {
        return self.forced(.In(timeout))
    }
    
    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(timeout: TimeInterval) -> Result<T,NSError>? {
        if let certainResult = self.result {
            return certainResult
        } else {
            let sema = Semaphore(value: 0)
            var res: Result<T,NSError>? = nil
            self.onComplete(context: Queue.global.context) {
                res = $0
                sema.signal()
            }
            
            sema.wait(timeout)
            
            return res
        }
    }
}


/// This extension contains all methods for registering callbacks
public extension Future {
    
    /// Adds the given closure as a callback for when the future completes. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onComplete(context c: ExecutionContext = executionContextForCurrentContext(), callback: CompletionCallback) -> Future<T> {
        let wrappedCallback : Future<T> -> () = { future in
            if let realRes = self.result {
                c {
                    self.callbackExecutionSemaphore.execute {
                        callback(result: realRes)
                        return
                    }
                    return
                }
            }
        }
        
        self.callbackAdministrationQueue.sync {
            if self.result == nil {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
        
        return self
    }

    /// Adds the given closure as a callback for when the future succeeds. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onSuccess(context c: ExecutionContext = executionContextForCurrentContext(), callback: SuccessCallback) -> Future<T> {
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

    /// Adds the given closure as a callback for when the future fails. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onFailure(context c: ExecutionContext = executionContextForCurrentContext(), callback: FailureCallback) -> Future<T> {
        self.onComplete(context: c) { result in
            switch result {
            case .Failure(let err):
                callback(err.value)
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

    /// Enables the the chaining of two future-wrapped asynchronous operations where the second operation depends on the success value of the first.
    /// Like map, the given closure (that returns the second operation) is only executed if the first operation (this future) is successful.
    /// If a regular `map` was used, the result would be a `Future<Future<U>>`. The implementation of this function uses `map`, but then flattens the result
    /// before returning it.
    ///
    /// If this future fails, the returned future will fail with the same error.
    /// If this future succeeds, the returned future will complete with the future returned from the given closure.
    ///
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func flatMap<U>(context c: ExecutionContext = executionContextForCurrentContext(), f: T -> Future<U>) -> Future<U> {
        return flatten(map(context: c, f: f))
    }

    /// Transforms the given closure returning `Result<U>` to a closure returning `Future<U>` and then calls
    /// `flatMap<U>(context c: ExecutionContext, f: T -> Future<U>) -> Future<U>`
    public func flatMap<U>(context c: ExecutionContext = executionContextForCurrentContext(), f: T -> Result<U,NSError>) -> Future<U> {
        return self.flatMap(context: c) { value in
            Future.completed(f(value))
        }
    }

    /// See `map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func map<U>(f: (T) -> U) -> Future<U> {
        return self.map(context: executionContextForCurrentContext(), f: f)
    }
    
    /// Returns a future that succeeds with the value returned from the given closure when it is invoked with the success value
    /// from this future. If this future fails, the returned future fails with the same error.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result {
            case .Success(let v):
                p.success(f(v.value))
                break;
            case .Failure(let e):
                p.failure(e.value)
                break;
            }
        })
        
        return p.future
    }

    /// Adds the given closure as a callback for when this future completes.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns a future that completes with the result from this future but only after executing the given closure
    public func andThen(context c: ExecutionContext = executionContextForCurrentContext(), callback: Result<T,NSError> -> ()) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result in
            callback(result)
            p.completeWith(self)
        }

        return p.future
    }

    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func recover(context c: ExecutionContext = executionContextForCurrentContext(), task: (NSError) -> T) -> Future<T> {
        return self.recoverWith(context: c) { error -> Future<T> in
            return Future.succeeded(task(error))
        }
    }

    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// This function should be used in cases where there are two asynchronous operations where the second operation (returned from the given closure)
    /// should only be executed if the first (this future) fails.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func recoverWith(context c: ExecutionContext = executionContextForCurrentContext(), task: (NSError) -> Future<T>) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result -> () in
            switch result {
            case .Failure(let err):
                p.completeWith(task(err.value))
            case .Success(let val):
                p.completeWith(self)
            }
        }
        
        return p.future;
    }
    
    /// Returns a future that succeeds with a tuple consisting of the success value of this future and the success value of the given future
    /// If either of the two futures fail, the returned future fails with the failure of this future or that future (in this order)
    public func zip<U>(that: Future<U>) -> Future<(T,U)> {
        return self.flatMap { thisVal -> Future<(T,U)> in
            return that.map { thatVal in
                return (thisVal, thatVal)
            }
        }
    }
    
    /// Returns a future that succeeds with the value that this future succeeds with if it passes the test 
    /// (i.e. the given closure returns `true` when invoked with the success value) or an error with code
    /// `ErrorCode.NoSuchElement` if the test failed.
    /// If this future fails, the returned future fails with the same error.
    public func filter(p: T -> Bool) -> Future<T> {
        return self.flatMap { value -> Result<T,NSError> in
            if p(value) {
                return Result(value: value)
            } else {
                return Result(error: errorFromCode(.NoSuchElement))
            }
        }
    }
}

/**
 I'd like this to be in InvalidationToken.swift, but the compiler does not like that.
 */
public extension Future {
    
    func firstCompletedOfSelfAndToken(token: InvalidationTokenType) -> Future<T> {
        return firstCompletedOf([self, token.future.asType()])
    }

    /// See `onComplete(context c: ExecutionContext = executionContextForCurrentContext(), callback: CompletionCallback) -> Future<T>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onComplete(context c: ExecutionContext = executionContextForCurrentContext(), token: InvalidationTokenType, callback: Result<T,NSError> -> ()) -> Future<T> {
        firstCompletedOfSelfAndToken(token).onComplete(context: c) { res in
            token.context {
                if !token.isInvalid {
                    callback(res)
                }
            }
        }
        return self;
    }

    /// See `onSuccess(context c: ExecutionContext = executionContextForCurrentContext(), callback: SuccessCallback) -> Future<T>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onSuccess(context c: ExecutionContext = executionContextForCurrentContext(), token: InvalidationTokenType, callback: SuccessCallback) -> Future<T> {
        firstCompletedOfSelfAndToken(token).onSuccess(context: c) { value in
            token.context {
                if !token.isInvalid {
                    callback(value)
                }
            }
        }
        
        return self
    }

    /// See `onFailure(context c: ExecutionContext = executionContextForCurrentContext(), callback: FailureCallback) -> Future<T>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onFailure(context c: ExecutionContext = executionContextForCurrentContext(), token: InvalidationTokenType, callback: FailureCallback) -> Future<T> {
        firstCompletedOfSelfAndToken(token).onFailure(context: c) { error in
            token.context {
                if !token.isInvalid {
                    callback(error)
                }
            }
        }
        return self
    }
}

/// Returns a future that fails with the error from the outer or inner future or succeeds with the value from the inner future 
/// if both futures succeed.
public func flatten<T>(future: Future<Future<T>>) -> Future<T> {
    let p = Promise<T>()
    
    future.onComplete { result in
        switch result {
        case .Success(let boxedFuture):
            p.completeWith(boxedFuture.value)
        case .Failure(let e):
            p.failure(e.value)
        }
    }
    
    return p.future
}

/// Short-hand for `lhs.recover(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <T>(lhs: Future<T>, @autoclosure(escaping) rhs: () -> T) -> Future<T> {
    return lhs.recover(context: executionContextForCurrentContext(), task: { _ in
        return rhs()
    })
}

/// Short-hand for `lhs.recoverWith(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <T>(lhs: Future<T>, @autoclosure(escaping) rhs: () -> Future<T>) -> Future<T> {
    return lhs.recoverWith(context: executionContextForCurrentContext(), task: { _ in
        return rhs()
    })
}
