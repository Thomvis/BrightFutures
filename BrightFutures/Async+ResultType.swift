//
//  Async+ResultType.swift
//  BrightFutures
//
//  Created by Thomas Visser on 10/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//
import Result

public extension Async where Value: ResultType {
    /// Completes the future with the given success value
    /// If the future is already completed, this function does nothing
    /// and an assert will be raised (if enabled)
    func success(value: Value.Value) throws {
        try complete(Value(value: value))
    }
    
    /// Tries to complete the future with the given success value
    /// If the future is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func trySuccess(value: Value.Value) -> Bool {
        return tryComplete(Value(value: value))
    }
    
    /// Completes the future with the given error
    /// If the future is already completed, this function does nothing
    /// and an assert will be raised (if enabled)
    func failure(error: Value.Error) throws {
        try complete(Value(error: error))
    }
    
    /// Tries to complete the future with the given error
    /// If the future is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func tryFailure(error: Value.Error) -> Bool {
        return tryComplete(Value(error: error))
    }
    
    /// `true` if the future completed with success, or `false` otherwise
    public var isSuccess: Bool {
        return value?.analysis(ifSuccess: { _ in return true }, ifFailure: { _ in return false }) ?? false
    }
    
    /// `true` if the future failed, or `false` otherwise
    public var isFailure: Bool {
        return !isSuccess
    }
}