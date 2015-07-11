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
public func future<T>(@autoclosure(escaping) task: () -> T) -> Future<T, NoError> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(task: () -> T) -> Future<T, NoError> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T>(context c: ExecutionContext, task: () -> T) -> Future<T, NoError> {
    return future(context: c) { () -> Result<T, NoError> in
        return Result(value: task())
    }
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T, E>(@autoclosure(escaping) task: () -> Result<T, E>) -> Future<T, E> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T, E>(task: () -> Result<T, E>) -> Future<T, E> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T, E>(context c: ExecutionContext, task: () -> Result<T, E>) -> Future<T, E> {
    let future = Future<T, E>();
    
    c {
        let result = task()
        try! future.complete(result)
    }
    
    return future
}

/// A Future represents the outcome of an asynchronous operation
/// The outcome will be represented as an instance of the `Result` enum and will be stored
/// in the `result` property. As long as the operation is not yet completed, `result` will be nil.
/// Interested parties can be informed of the completion by using one of the available callback
/// registration methods (e.g. onComplete, onSuccess & onFailure) or by immediately composing/chaining
/// subsequent actions (e.g. map, flatMap, recover, andThen, etc.).
///
/// For more info, see the project README.md
public final class Future<T, E: ErrorType>: Async<Result<T, E>> {
    
    typealias CompletionCallback = (result: Result<T,E>) -> Void
    typealias SuccessCallback = T -> Void
    public typealias FailureCallback = E -> Void
    
    public required init() {
        super.init()
    }
    
    public required init(value: Future.Value) {
        super.init(value: value)
    }
    
    public required init<A: AsyncType where A.Value == Value>(other: A) {
        super.init(other: other)
    }
    
    public convenience init(successValue: T) {
        self.init(value: Result(value: successValue))
    }
    
    public convenience init(error: E) {
        self.init(value: Result(error: error))
    }
    
    public var result: Future.Value? {
        return self.value
    }
    
}

/// This extension contains all (static) methods for Future creation
public extension Future {
    
    /// Returns a new future that will succeed with the given value after the given time interval
    /// The implementation of this function uses dispatch_after
    public class func completeAfter(delay: NSTimeInterval, withValue value: T) -> Future<T, E> {
        let res = Future<T, E>()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC))), Queue.global.underlyingQueue) {
            try! res.success(value)
        }
        
        return res
    }
    
    /// Returns a new future that will never complete
    public class func never() -> Future<T, E> {
        return Future<T, E>()
    }
    
    /// Returns a new future with the new type.
    /// The value or error will be casted using `as!` and may cause a runtime error
    public func forceType<U, E1>() -> Future<U, E1> {
        return self.map(context: ImmediateExecutionContext) {
            $0 as! U
        }.mapError(context: ImmediateExecutionContext) {
            $0 as! E1
        }
    }
    
    /// Returns a new future that completes with this future, but returns Void on success
    public func asVoid() -> Future<Void, E> {
        return self.map(context: ImmediateExecutionContext) { _ in return () }
    }
}

/// This extension contains methods to query the current status
/// of the future and to access the result and/or error
public extension Future {
    
    /// Blocks the current thread until the future is completed and then returns the result
    public func forced() -> Result<T, E>? {
        return self.forced(TimeInterval.Forever)
    }
    

    /// See `forced(timeout: TimeInterval) -> Result<T, E>?`
    public func forced(timeout: NSTimeInterval) -> Result<T, E>? {
        return self.forced(.In(timeout))
    }
    
    /// Blocks the current thread until the future is completed, but no longer than the given timeout
    /// If the future did not complete before the timeout, `nil` is returned, otherwise the result of the future is returned
    public func forced(timeout: TimeInterval) -> Result<T, E>? {
        if let value = self.value {
            return value
        } else {
            let sema = Semaphore(value: 0)
            var res: Result<T, E>? = nil
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
    
    /// Adds the given closure as a callback for when the future succeeds. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onSuccess(context c: ExecutionContext = DefaultThreadingModel(), callback: SuccessCallback) -> Future<T, E> {
        self.onComplete(context: c) { result in
            result.analysis(ifSuccess: callback, ifFailure: { _ in })
        }
        
        return self
    }

    /// Adds the given closure as a callback for when the future fails. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onFailure(context c: ExecutionContext = DefaultThreadingModel(), callback: FailureCallback) -> Future<T, E> {
        self.onComplete(context: c) { result in
            result.analysis(ifSuccess: { _ in }, ifFailure: callback)
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
    public func flatMap<U>(context c: ExecutionContext, f: T -> Future<U, E>) -> Future<U, E> {
        return flatten(map(context: c, f: f))
    }
	
	/// See `flatMap<U>(context c: ExecutionContext, f: T -> Future<U, E>) -> Future<U, E>`
	/// The given closure is executed according to the default threading model (see README.md)
	public func flatMap<U>(f: T -> Future<U, E>) -> Future<U, E> {
		return flatMap(context: DefaultThreadingModel(), f: f)
	}

    /// Transforms the given closure returning `Result<U>` to a closure returning `Future<U>` and then calls
    /// `flatMap<U>(context c: ExecutionContext, f: T -> Future<U>) -> Future<U>`
    public func flatMap<U>(context c: ExecutionContext, f: T -> Result<U, E>) -> Future<U, E> {
        return self.flatMap(context: c) { value in
            return Future<U, E>.init(value: f(value))
        }
    }

	/// See `flatMap<U>(context c: ExecutionContext, f: T -> Result<U, E>) -> Future<U, E>`
	/// The given closure is executed according to the default threading model (see README.md)
	public func flatMap<U>(f: T -> Result<U, E>) -> Future<U, E> {
		return flatMap(context: DefaultThreadingModel(), f: f)
	}

    /// See `map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func map<U>(f: (T) -> U) -> Future<U, E> {
        return self.map(context: DefaultThreadingModel(), f: f)
    }
    
    /// Returns a future that succeeds with the value returned from the given closure when it is invoked with the success value
    /// from this future. If this future fails, the returned future fails with the same error.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U, E> {
        let res = Future<U, E>()
        
        self.onComplete(context: c, callback: { (result: Result<T, E>) in
            result.analysis(
                ifSuccess: { try! res.success(f($0)) },
                ifFailure: { try! res.failure($0) })
        })
        
        return res
    }
    
    /// See `mapError<E1>(context c: ExecutionContext, f: E -> E1) -> Future<T, E1>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func mapError<E1>(f: E -> E1) -> Future<T, E1> {
        return mapError(context: DefaultThreadingModel(), f: f)
    }
    
    /// Returns a future that fails with the error returned from the given closure when it is invoked with the error
    /// from this future. If this future succeeds, the returned future succeeds with the same value and the closure is not executed.
    /// The closure is executed on the given context.
    public func mapError<E1>(context c: ExecutionContext, f: E -> E1) -> Future<T, E1> {
        let res = Future<T, E1>()
        
        self.onComplete(context:c) { result in
            result.analysis(
                ifSuccess: { try! res.success($0) } ,
                ifFailure: { try! res.failure(f($0)) })
        }
        
        return res
    }

    /// Adds the given closure as a callback for when this future completes.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns a future that completes with the result from this future but only after executing the given closure
    public func andThen(context c: ExecutionContext = DefaultThreadingModel(), callback: Result<T, E> -> Void) -> Future<T, E> {
        let res = Future<T, E>()
        
        self.onComplete(context: c) { result in
            callback(result)
            try! res.complete(result)
        }

        return res
    }

    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func recover(context c: ExecutionContext = DefaultThreadingModel(), task: (E) -> T) -> Future<T, NoError> {
        return self.recoverWith(context: c) { error -> Future<T, NoError> in
            return Future<T, NoError>(successValue: task(error))
        }
    }

    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// This function should be used in cases where there are two asynchronous operations where the second operation (returned from the given closure)
    /// should only be executed if the first (this future) fails.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func recoverWith<E1: ErrorType>(context c: ExecutionContext = DefaultThreadingModel(), task: (E) -> Future<T, E1>) -> Future<T, E1> {
        let res = Future<T, E1>()
        
        self.onComplete(context: c) { result in
            result.analysis(
                ifSuccess: { try! res.success($0) },
                ifFailure: { res.completeWith(task($0)) })
        }
        
        return res
    }
    
    /// Returns a future that succeeds with a tuple consisting of the success value of this future and the success value of the given future
    /// If either of the two futures fail, the returned future fails with the failure of this future or that future (in this order)
    public func zip<U>(that: Future<U, E>) -> Future<(T,U), E> {
        return self.flatMap { thisVal -> Future<(T,U), E> in
            return that.map { thatVal in
                return (thisVal, thatVal)
            }
        }
    }
    
    /// Returns a future that succeeds with the value that this future succeeds with if it passes the test 
    /// (i.e. the given closure returns `true` when invoked with the success value) or an error with code
    /// `ErrorCode.NoSuchElement` if the test failed.
    /// If this future fails, the returned future fails with the same error.
    public func filter(p: (T -> Bool)) -> Future<T, BrightFuturesError<E>> {
        return self.mapError { error -> BrightFuturesError<E> in
            return BrightFuturesError(external: error)
        }.flatMap { value -> Result<T, BrightFuturesError<E>> in
            if p(value) {
                return Result(value: value)
            } else {
                return Result(error: .NoSuchElement)
            }
        }
    }
}

/**
 I'd like this to be in InvalidationToken.swift, but the compiler does not like that.
 */
public extension Future {
    
    private func firstCompletedOfSelfAndToken(token: InvalidationTokenType) -> Future<T, BrightFuturesError<E>> {
        return firstCompletedOf([
            self.mapError {
                BrightFuturesError(external: $0)
            },
            promoteError(promoteValue(token.future))
            ]
        )
    }

    /// See `onComplete(context c: ExecutionContext = DefaultThreadingModel(), callback: CompletionCallback) -> Future<T, E>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onComplete(context c: ExecutionContext = DefaultThreadingModel(), token: InvalidationTokenType, callback: Result<T, E> -> Void) -> Future<T, E> {
        firstCompletedOfSelfAndToken(token).onComplete(context: c) { res in
            token.context {
                if !token.isInvalid {
                    callback(self.result!)
                }
            }
        }
        return self;
    }

    /// See `onSuccess(context c: ExecutionContext = DefaultThreadingModel(), callback: SuccessCallback) -> Future<T, E>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onSuccess(context c: ExecutionContext = DefaultThreadingModel(), token: InvalidationTokenType, callback: SuccessCallback) -> Future<T, E> {
        firstCompletedOfSelfAndToken(token).onSuccess(context: c) { value in
            token.context {
                if !token.isInvalid {
                    callback(value)
                }
            }
        }
        
        return self
    }

    /// See `onFailure(context c: ExecutionContext = DefaultThreadingModel(), callback: FailureCallback) -> Future<T, E>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onFailure(context c: ExecutionContext = DefaultThreadingModel(), token: InvalidationTokenType, callback: FailureCallback) -> Future<T, E> {
        firstCompletedOfSelfAndToken(token).onFailure(context: c) { error in
            token.context {
                if !token.isInvalid {
                    callback(self.result!.error!)
                }
            }
        }
        return self
    }
}

/// Returns a future that fails with the error from the outer or inner future or succeeds with the value from the inner future 
/// if both futures succeed.
public func flatten<T, E>(future: Future<Future<T, E>, E>) -> Future<T, E> {
    let res = Future<T, E>()
    
    future.onComplete { result in
        result.analysis(
            ifSuccess: { res.completeWith($0) },
            ifFailure: { try! res.failure($0) })
    }
    
    return res
}

/// Short-hand for `lhs.recover(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <T, E>(lhs: Future<T, E>, @autoclosure(escaping) rhs: () -> T) -> Future<T, NoError> {
    return lhs.recover(context: DefaultThreadingModel(), task: { _ in
        return rhs()
    })
}

/// Short-hand for `lhs.recoverWith(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <T, E, E1>(lhs: Future<T, E>, @autoclosure(escaping) rhs: () -> Future<T, E1>) -> Future<T, E1> {
    return lhs.recoverWith(context: DefaultThreadingModel(), task: { _ in
        return rhs()
    })
}

/// 'promotes' a `Future` with error type `NoError` to a `Future` with an error type of choice.
/// This allows the `Future` to be used more easily in combination with other futures 
/// for operations such as `sequence` and `firstCompletedOf`
/// This is a safe operation, because a `Future` with error type `NoError` is guaranteed never to fail
public func promoteError<T, E>(future: Future<T, NoError>) -> Future<T, E> {
    return future.mapError(context: ImmediateExecutionContext) { $0 as! E } // future will never fail, so this map block will never get called
}

/// 'promotes' a `Future` with error type `BrightFuturesError<NoError>` to a `Future` with an 
/// `BrightFuturesError<E>` error type where `E` can be any type conforming to `ErrorType`.
/// This allows the `Future` to be used more easily in combination with other futures
/// for operations such as `sequence` and `firstCompletedOf`
/// This is a safe operation, because a `BrightFuturesError<NoError>` will never be `.External`
public func promoteError<T, E>(future: Future<T, BrightFuturesError<NoError>>) -> Future<T, BrightFuturesError<E>> {
    return future.mapError(context: ImmediateExecutionContext) { err in
        switch err {
        case .NoSuchElement:
            return BrightFuturesError<E>.NoSuchElement
        case .InvalidationTokenInvalidated:
            return BrightFuturesError<E>.InvalidationTokenInvalidated
        case .IllegalState:
            return BrightFuturesError<E>.IllegalState
        case .External(_):
            fatalError("Encountered BrightFuturesError.External with NoError, which should be impossible")
        }
    }
}

/// Can be used as the value type of a `Future` or `Result` to indicate it can never be a success.
/// This is guaranteed by the type system, because `NoValue` has no possible values and thus cannot be created.
public enum NoValue { }

/// 'promotes' a `Future` with value type `NoValue` to a `Future` with a value type of choice.
/// This allows the `Future` to be used more easily in combination with other futures
/// for operations such as `sequence` and `firstCompletedOf`
/// This is a safe operation, because a `Future` with value type `NoValue` is guaranteed never to succeed
public func promoteValue<T, E>(future: Future<NoValue, E>) -> Future<T, E> {
    return future.map(context: ImmediateExecutionContext) { $0 as! T } // future will never succeed, so this map block will never get called
}
