//
//  Async+ResultType.swift
//  BrightFutures
//
//  Created by Thomas Visser on 10/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

public extension AsyncType where Value: ResultProtocol {
    /// `true` if the future completed with success, or `false` otherwise
    var isSuccess: Bool {
        return result?.analysis(ifSuccess: { _ in return true }, ifFailure: { _ in return false }) ?? false
    }
    
    /// `true` if the future failed, or `false` otherwise
    var isFailure: Bool {
        return result?.analysis(ifSuccess: { _ in return false }, ifFailure: { _ in return true }) ?? false
    }
    
    var value: Value.Value? {
        return result?.result.value
    }
    
    var error: Value.Error? {
        return result?.result.error
    }
    
    /// Adds the given closure as a callback for when the future succeeds. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    @discardableResult
    func onSuccess(_ context: @escaping ExecutionContext = defaultContext(), callback: @escaping (Value.Value) -> Void) -> Self {
        self.onComplete(context) { result in
            result.analysis(ifSuccess: callback, ifFailure: { _ in })
        }
        
        return self
    }
    
    /// Adds the given closure as a callback for when the future fails. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    @discardableResult
    func onFailure(_ context: @escaping ExecutionContext = defaultContext(), callback: @escaping (Value.Error) -> Void) -> Self {
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
    func flatMap<U>(_ context: @escaping ExecutionContext, f: @escaping (Value.Value) -> Future<U, Value.Error>) -> Future<U, Value.Error> {
        return map(context, f: f).flatten()
    }
    
    /// See `flatMap<U>(context c: ExecutionContext, f: T -> Future<U, E>) -> Future<U, E>`
    /// The given closure is executed according to the default threading model (see README.md)
    func flatMap<U>(_ f: @escaping (Value.Value) -> Future<U, Value.Error>) -> Future<U, Value.Error> {
        return flatMap(defaultContext(), f: f)
    }
    
    /// Transforms the given closure returning `Result<U>` to a closure returning `Future<U>` and then calls
    /// `flatMap<U>(context c: ExecutionContext, f: T -> Future<U>) -> Future<U>`
    func flatMap<U>(_ context: @escaping ExecutionContext, f: @escaping (Value.Value) -> Result<U, Value.Error>) -> Future<U, Value.Error> {
        return self.flatMap(context) { value in
            return Future<U, Value.Error>(result: f(value))
        }
    }
    
    /// See `flatMap<U>(context c: ExecutionContext, f: T -> Result<U, E>) -> Future<U, E>`
    /// The given closure is executed according to the default threading model (see README.md)
    func flatMap<U>(_ f: @escaping (Value.Value) -> Result<U, Value.Error>) -> Future<U, Value.Error> {
        return flatMap(defaultContext(), f: f)
    }
    
    /// See `map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U>`
    /// The given closure is executed according to the default threading model (see README.md)
    func map<U>(_ f: @escaping (Value.Value) -> U) -> Future<U, Value.Error> {
        return self.map(defaultContext(), f: f)
    }

    #if !swift(>=5.2)
    /// Similar to `func map<U>(_ f: @escaping (Value.Value) -> U) -> Future<U, Value.Error>`, but using `KeyPath` instead of a closure
    func map<U>(_ keyPath: KeyPath<Value.Value, U>) -> Future<U, Value.Error> {
        return self.map(DefaultThreadingModel(), keyPath: keyPath)
    }
    #endif

    /// Returns a future that succeeds with the value returned from the given closure when it is invoked with the success value
    /// from this future. If this future fails, the returned future fails with the same error.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    func map<U>(_ context: @escaping ExecutionContext, f: @escaping (Value.Value) -> U) -> Future<U, Value.Error> {
        let res = Future<U, Value.Error>()
        
        self.onComplete(context, callback: { (result: Value) in
            result.analysis(
                ifSuccess: { res.success(f($0)) },
                ifFailure: { res.failure($0) })
        })
        
        return res
    }

    #if !swift(>=5.2)
    /// Similar to `func map<U>(_ context: @escaping ExecutionContext, f: @escaping (Value.Value) -> U) -> Future<U, Value.Error>`, but using `KeyPath` instead of a closure
    func map<U>(_ context: @escaping ExecutionContext, keyPath: KeyPath<Value.Value, U>) -> Future<U, Value.Error> {
        return self.map { $0[keyPath: keyPath] }
    }
    #endif

    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    func recover(context c: @escaping ExecutionContext = defaultContext(), task: @escaping (Value.Error) -> Value.Value) -> Future<Value.Value, Never> {
        return self.recoverWith(context: c) { error -> Future<Value.Value, Never> in
            return Future<Value.Value, Never>(value: task(error))
        }
    }
    
    /// Returns a future that completes with this future if this future succeeds or with the value returned from the given closure
    /// when it is invoked with the error that this future failed with.
    /// This function should be used in cases where there are two asynchronous operations where the second operation (returned from the given closure)
    /// should only be executed if the first (this future) fails.
    /// The closure is executed on the given context. If no context is given, the behavior is defined by the default threading model (see README.md)
    func recoverWith<E1>(context c: @escaping ExecutionContext = defaultContext(), task: @escaping (Value.Error) -> Future<Value.Value, E1>) -> Future<Value.Value, E1> {
        let res = Future<Value.Value, E1>()
        
        self.onComplete(c) { result in
            result.analysis(
                ifSuccess: { res.success($0) },
                ifFailure: { res.completeWith(task($0)) })
        }
        
        return res
    }
    
    /// See `mapError<E1>(context c: ExecutionContext, f: E -> E1) -> Future<T, E1>`
    /// The given closure is executed according to the default threading model (see README.md)
    func mapError<E1>(_ f: @escaping (Value.Error) -> E1) -> Future<Value.Value, E1> {
        return mapError(defaultContext(), f: f)
    }
    
    /// Returns a future that fails with the error returned from the given closure when it is invoked with the error
    /// from this future. If this future succeeds, the returned future succeeds with the same value and the closure is not executed.
    /// The closure is executed on the given context.
    func mapError<E1>(_ context: @escaping ExecutionContext, f: @escaping (Value.Error) -> E1) -> Future<Value.Value, E1> {
        let res = Future<Value.Value, E1>()
        
        self.onComplete(context) { result in
            result.analysis(
                ifSuccess: { res.success($0) } ,
                ifFailure: { res.failure(f($0)) })
        }
        
        return res
    }
    
    /// Returns a future that succeeds with a tuple consisting of the success value of this future and the success value of the given future
    /// If either of the two futures fail, the returned future fails with the failure of this future or that future (in this order)
    func zip<U>(_ that: Future<U, Value.Error>) -> Future<(Value.Value,U), Value.Error> {
        return flatMap(immediateExecutionContext) { thisVal -> Future<(Value.Value,U), Value.Error> in
            return that.map(immediateExecutionContext) { thatVal in
                return (thisVal, thatVal)
            }
        }
    }
    
    /// Returns a future that succeeds with the value that this future succeeds with if it passes the test
    /// (i.e. the given closure returns `true` when invoked with the success value) or an error with code
    /// `ErrorCode.noSuchElement` if the test failed.
    /// If this future fails, the returned future fails with the same error.
    func filter(_ p: @escaping (Value.Value) -> Bool) -> Future<Value.Value, BrightFuturesError<Value.Error>> {
        return self.mapError(immediateExecutionContext) { error in
            return BrightFuturesError(external: error)
        }.flatMap(immediateExecutionContext) { value -> Result<Value.Value, BrightFuturesError<Value.Error>> in
            if p(value) {
                return .success(value)
            } else {
                return .failure(.noSuchElement)
            }
        }
    }
    
    /// Returns a new future with the new type.
    /// The value or error will be casted using `as!` and may cause a runtime error
    func forceType<U, E1>() -> Future<U, E1> {
        return self.map(immediateExecutionContext) {
            $0 as! U
        }.mapError(immediateExecutionContext) {
            $0 as! E1
        }
    }
    
    /// Returns a new future that completes with this future, but returns Void on success
    func asVoid() -> Future<Void, Value.Error> {
        return self.map(immediateExecutionContext) { _ in return () }
    }
}

public extension AsyncType where Value: ResultProtocol, Value.Value: AsyncType, Value.Value.Value: ResultProtocol, Value.Error == Value.Value.Value.Error {
    /// Returns a future that fails with the error from the outer or inner future or succeeds with the value from the inner future
    /// if both futures succeed.
    func flatten() -> Future<Value.Value.Value.Value, Value.Error> {
        let f = Future<Value.Value.Value.Value, Value.Error>()
        
        onComplete(immediateExecutionContext) { res in
            res.analysis(ifSuccess: { innerFuture -> () in
                innerFuture.onComplete(immediateExecutionContext) { (res:Value.Value.Value) in
                    res.analysis(ifSuccess: { f.success($0) }, ifFailure: { err in f.failure(err) })
                }
            }, ifFailure: { f.failure($0) })
        }
        
        return f
    }
    
}

public extension AsyncType where Value: ResultProtocol, Value.Error == Never {
    /// 'promotes' a `Future` with error type `Never` to a `Future` with an error type of choice.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompleted`
    /// This is a safe operation, because a `Future` with error type `Never` is guaranteed never to fail
    func promoteError<E>() -> Future<Value.Value, E> {
        let res = Future<Value.Value, E>()
        
        self.onComplete(immediateExecutionContext) { result in
            switch result.result {
            case .success(let value):
                res.success(value)
            case .failure:
                break // future will never fail, so this cast will never get called
            }
        }
        
        return res
    }
}

public extension AsyncType where Value: ResultProtocol, Value.Error == BrightFuturesError<Never> {
    /// 'promotes' a `Future` with error type `BrightFuturesError<Never>` to a `Future` with an
    /// `BrightFuturesError<E>` error type where `E` can be any type conforming to `ErrorType`.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompleted`
    /// This is a safe operation, because a `BrightFuturesError<Never>` will never be `.External`
    func promoteError<E>() -> Future<Value.Value, BrightFuturesError<E>> {
        return mapError(immediateExecutionContext) { err in
            switch err {
            case .noSuchElement:
                return BrightFuturesError<E>.noSuchElement
            case .invalidationTokenInvalidated:
                return BrightFuturesError<E>.invalidationTokenInvalidated
            case .illegalState:
                return BrightFuturesError<E>.illegalState
            case .external(_):
                fatalError("Encountered BrightFuturesError.External with Never, which should be impossible")
            }
        }
    }
}

public extension AsyncType where Value: ResultProtocol, Value.Value == NoValue {
    /// 'promotes' a `Future` with value type `NoValue` to a `Future` with a value type of choice.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompleted`
    /// This is a safe operation, because a `Future` with value type `NoValue` is guaranteed never to succeed
    func promoteValue<T>() -> Future<T, Value.Error> {
        Future { completion in
            self.onComplete(immediateExecutionContext) { result in
                switch result.result {
                case .success:
                    break // future will never succeed, so this cast will never get called
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}

