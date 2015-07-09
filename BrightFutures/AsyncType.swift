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
    
    func onComplete(context c: ExecutionContext, callback: Value -> ()) -> Self
}

internal protocol MutableAsyncType: AsyncType {
    func complete(value: Value) throws
    func tryComplete(value: Value) -> Bool
}

extension MutableAsyncType {
    
    /// Tries to complete the Async with the given value
    /// If the Async is already completed, nothing happens and `false` is returned
    /// otherwise the Async is completed and `true` is returned
    func tryComplete(value: Value) -> Bool {
        do {
            try complete(value)
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
