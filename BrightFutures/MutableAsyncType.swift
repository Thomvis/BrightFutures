//
//  MutableAsyncType.swift
//  BrightFutures
//
//  Created by Thomas Visser on 14/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

internal protocol MutableAsyncType: AsyncType {
    /// Complete the Async with the given value
    /// If the Async is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func tryComplete(result: Value) -> Bool
}

extension MutableAsyncType {
    
    /// Completes the Async with the given result
    /// If the Async is already completed, this function throws an error
    func complete(result: Value) {
        if !tryComplete(result) {
            print(result)
            let error = "Attempted to completed an Async that is already completed. This could become a fatalError."
            assert(false, error)
            print(error)
        }
    }
    
    func completeWith<A: AsyncType where A.Value == Value>(other: A) {
        other.onComplete(ImmediateExecutionContext, callback: self.complete)
    }
}