//
//  Async+ResultType.swift
//  BrightFutures
//
//  Created by Thomas Visser on 10/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//
import Result

public extension AsyncType where Value: ResultType {
    /// `true` if the future completed with success, or `false` otherwise
    public var isSuccess: Bool {
        return result?.analysis(ifSuccess: { _ in return true }, ifFailure: { _ in return false }) ?? false
    }
    
    /// `true` if the future failed, or `false` otherwise
    public var isFailure: Bool {
        return !isSuccess
    }
    
    /// Adds the given closure as a callback for when the future succeeds. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onSuccess(context: ExecutionContext = DefaultThreadingModel(), callback: Value.Value -> Void) -> Self {
        self.onComplete(context) { result in
            result.analysis(ifSuccess: callback, ifFailure: { _ in })
        }
        
        return self
    }
    
    /// Adds the given closure as a callback for when the future fails. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onFailure(context: ExecutionContext = DefaultThreadingModel(), callback: Value.Error -> Void) -> Self {
        self.onComplete(context) { result in
            result.analysis(ifSuccess: { _ in }, ifFailure: callback)
        }
        return self
    }
    
    /// Enables the the chaining of two future-wrapped asynchronous operations where the second operation depends on the success value of the first.
    /// Like map, the given closure (that returns the second operation) is only executed if the first operation (this future) is successful.
    /// If a regular `map` was used, the result would be a `Future<Future<U>>`. The implementation of this function uses `map`, but then flattens the result
    /// before returning it.
    ///
    /// If this future fails, the returned future will fail with the same error.
    /// If this future succeeds, the returned future will complete with the future returned from the given closure.
    ///
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func flatMap<U>(context: ExecutionContext, f: Value.Value -> Future<U, Value.Error>) -> Future<U, Value.Error> {
        return map(context, f: f).flatten()
    }
    
    /// See `flatMap<U>(context c: ExecutionContext, f: T -> Future<U, E>) -> Future<U, E>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func flatMap<U>(f: Value.Value -> Future<U, Value.Error>) -> Future<U, Value.Error> {
        return flatMap(DefaultThreadingModel(), f: f)
    }
    
    /// Transforms the given closure returning `Result<U>` to a closure returning `Future<U>` and then calls
    /// `flatMap<U>(context c: ExecutionContext, f: T -> Future<U>) -> Future<U>`
    public func flatMap<U>(context: ExecutionContext, f: Value.Value -> Result<U, Value.Error>) -> Future<U, Value.Error> {
        return self.flatMap(context) { value in
            return Future<U, Value.Error>(result: f(value))
        }
    }
    
    /// See `flatMap<U>(context c: ExecutionContext, f: T -> Result<U, E>) -> Future<U, E>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func flatMap<U>(f: Value.Value -> Result<U, Value.Error>) -> Future<U, Value.Error> {
        return flatMap(DefaultThreadingModel(), f: f)
    }
    
    /// See `map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func map<U>(f: Value.Value -> U) -> Future<U, Value.Error> {
        return self.map(DefaultThreadingModel(), f: f)
    }
    
    /// Returns a future that succeeds with the value returned from the given closure when it is invoked with the success value
    /// from this future. If this future fails, the returned future fails with the same error.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func map<U>(context: ExecutionContext, f: Value.Value -> U) -> Future<U, Value.Error> {
        let res = Future<U, Value.Error>()
        
        self.onComplete(context, callback: { (result: Value) in
            result.analysis(
                ifSuccess: { try! res.success(f($0)) },
                ifFailure: { try! res.failure($0) })
        })
        
        return res
    }
    
    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func recover(context c: ExecutionContext = DefaultThreadingModel(), task: Value.Error -> Value.Value) -> Future<Value.Value, NoError> {
        return self.recoverWith(context: c) { error -> Future<Value.Value, NoError> in
            return Future<Value.Value, NoError>(value: task(error))
        }
    }
    
    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// This function should be used in cases where there are two asynchronous operations where the second operation (returned from the given closure)
    /// should only be executed if the first (this future) fails.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    public func recoverWith<E1: ErrorType>(context c: ExecutionContext = DefaultThreadingModel(), task: Value.Error -> Future<Value.Value, E1>) -> Future<Value.Value, E1> {
        let res = Future<Value.Value, E1>()
        
        self.onComplete(c) { result in
            result.analysis(
                ifSuccess: { try! res.success($0) },
                ifFailure: { res.completeWith(task($0)) })
        }
        
        return res
    }
    
    /// See `mapError<E1>(context c: ExecutionContext, f: E -> E1) -> Future<T, E1>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func mapError<E1: ErrorType>(f: Value.Error -> E1) -> Future<Value.Value, E1> {
        return mapError(DefaultThreadingModel(), f: f)
    }
    
    /// Returns a future that fails with the error returned from the given closure when it is invoked with the error
    /// from this future. If this future succeeds, the returned future succeeds with the same value and the closure is not executed.
    /// The closure is executed on the given context.
    public func mapError<E1: ErrorType>(context: ExecutionContext, f: Value.Error -> E1) -> Future<Value.Value, E1> {
        let res = Future<Value.Value, E1>()
        
        self.onComplete(context) { result in
            result.analysis(
                ifSuccess: { try! res.success($0) } ,
                ifFailure: { try! res.failure(f($0)) })
        }
        
        return res
    }
}

public extension AsyncType where Value: ResultType, Value.Value: AsyncType, Value.Value.Value: ResultType, Value.Error == Value.Value.Value.Error {
    /// Returns a future that fails with the error from the outer or inner future or succeeds with the value from the inner future
    /// if both futures succeed.
    public func flatten() -> Future<Value.Value.Value.Value, Value.Error> {
        let f = Future<Value.Value.Value.Value, Value.Error>()
        
        onComplete(ImmediateExecutionContext) { res in
            res.analysis(ifSuccess: { innerFuture -> () in
                innerFuture.onComplete(ImmediateExecutionContext) { (res:Value.Value.Value) in
                    res.analysis(ifSuccess: { try! f.success($0) }, ifFailure: { err in try! f.failure(err) })
                }
                }, ifFailure: { try! f.failure($0) })
        }
        
        return f
    }
    
}

public extension AsyncType where Value: ResultType, Value.Error == NoError {
    /// 'promotes' a `Future` with error type `NoError` to a `Future` with an error type of choice.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompletedOf`
    /// This is a safe operation, because a `Future` with error type `NoError` is guaranteed never to fail
    public func promoteError<E: ErrorType>() -> Future<Value.Value, E> {
        return mapError(ImmediateExecutionContext) { $0 as! E } // future will never fail, so this map block will never get called
    }
}

public extension AsyncType where Value: ResultType, Value.Error == BrightFuturesError<NoError> {
    /// 'promotes' a `Future` with error type `BrightFuturesError<NoError>` to a `Future` with an
    /// `BrightFuturesError<E>` error type where `E` can be any type conforming to `ErrorType`.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompletedOf`
    /// This is a safe operation, because a `BrightFuturesError<NoError>` will never be `.External`
    public func promoteError<E: ErrorType>() -> Future<Value.Value, BrightFuturesError<E>> {
        return mapError(ImmediateExecutionContext) { err in
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
}

public extension AsyncType where Value: ResultType, Value.Value == NoValue {
    /// 'promotes' a `Future` with value type `NoValue` to a `Future` with a value type of choice.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompletedOf`
    /// This is a safe operation, because a `Future` with value type `NoValue` is guaranteed never to succeed
    public func promoteValue<T>() -> Future<T, Value.Error> {
        return map(ImmediateExecutionContext) { $0 as! T } // future will never succeed, so this map block will never get called
    }
}

