//
//  Async.swift
//  BrightFutures
//
//  Created by Thomas Visser on 09/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public protocol AsyncType {
    typealias Value
    
    var value: Value? { get }
    
    init()
    init(value: Value)
    init<A: AsyncType where A.Value == Value>(other: A)
    
    func onComplete(context c: ExecutionContext, callback: Value -> Void) -> Self
}

public extension AsyncType {
    /// `true` if the future completed (either `isSuccess` or `isFailure` will be `true`)
    public var isCompleted: Bool {
        return self.value != nil
    }
}

internal protocol MutableAsyncType: AsyncType {
    /// Completes the Async with the given result
    /// If the Async is already completed, this function throws an error
    func complete(value: Value) throws
}

extension MutableAsyncType {
    
    /// Tries to complete the Async with the given value
    /// If the Async is already completed, nothing happens and `false` is returned
    /// otherwise the future is completed and `true` is returned
    func tryComplete(result: Value) -> Bool {
        do {
            try complete(result)
            return true
        } catch {
            return false
        }
    }

    func completeWith<A: AsyncType where A.Value == Value>(other: A) {
        other.onComplete(context: ImmediateExecutionContext) {
            try! self.complete($0)
        }
    }
}
