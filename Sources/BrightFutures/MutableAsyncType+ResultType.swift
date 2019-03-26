//
//  MutableAsyncType+ResultType.swift
//  BrightFutures
//
//  Created by Thomas Visser on 22/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

internal extension MutableAsyncType where Value: ResultProtocol {
    /// Completes the future with the given success value
    /// If the future is already completed, this function does nothing
    /// and an assert will be raised (if enabled)
    func success(_ value: Value.Value) {
        complete(Value(value: value))
    }
    
    /// Tries to complete the future with the given success value
    /// If the future is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func trySuccess(_ value: Value.Value) -> Bool {
        return tryComplete(Value(value: value))
    }
    
    /// Completes the future with the given error
    /// If the future is already completed, this function does nothing
    /// and an assert will be raised (if enabled)
    func failure(_ error: Value.Error) {
        complete(Value(error: error))
    }
    
    /// Tries to complete the future with the given error
    /// If the future is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func tryFailure(_ error: Value.Error) -> Bool {
        return tryComplete(Value(error: error))
    }
}
