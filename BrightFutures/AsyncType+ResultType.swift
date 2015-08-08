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
    public func onSuccess(context c: ExecutionContext = DefaultThreadingModel(), callback: Value.Value -> Void) -> Self {
        self.onComplete(context: c) { result in
            result.analysis(ifSuccess: callback, ifFailure: { _ in })
        }
        
        return self
    }
    
    /// Adds the given closure as a callback for when the future fails. The closure is executed on the given context.
    /// If no context is given, the behavior is defined by the default threading model (see README.md)
    /// Returns self
    public func onFailure(context c: ExecutionContext = DefaultThreadingModel(), callback: Value.Error -> Void) -> Self {
        self.onComplete(context: c) { result in
            result.analysis(ifSuccess: { _ in }, ifFailure: callback)
        }
        return self
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
        
        self.onComplete(context: c) { result in
            result.analysis(
                ifSuccess: { try! res.success($0) },
                ifFailure: { res.completeWith(task($0)) })
        }
        
        return res
    }
    
    /// See `mapError<E1>(context c: ExecutionContext, f: E -> E1) -> Future<T, E1>`
    /// The given closure is executed according to the default threading model (see README.md)
    public func mapError<E1: ErrorType>(f: Value.Error -> E1) -> Future<Value.Value, E1> {
        return mapError(context: DefaultThreadingModel(), f: f)
    }
    
    /// Returns a future that fails with the error returned from the given closure when it is invoked with the error
    /// from this future. If this future succeeds, the returned future succeeds with the same value and the closure is not executed.
    /// The closure is executed on the given context.
    public func mapError<E1: ErrorType>(context c: ExecutionContext, f: Value.Error -> E1) -> Future<Value.Value, E1> {
        let res = Future<Value.Value, E1>()
        
        self.onComplete(context:c) { result in
            result.analysis(
                ifSuccess: { try! res.success($0) } ,
                ifFailure: { try! res.failure(f($0)) })
        }
        
        return res
    }
}