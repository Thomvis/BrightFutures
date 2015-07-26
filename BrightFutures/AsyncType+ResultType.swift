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
    
}