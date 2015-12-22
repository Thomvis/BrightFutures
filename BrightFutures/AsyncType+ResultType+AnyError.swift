//
//  AsyncType+ResultType+AnyError.swift
//  BrightFutures
//
//  Created by Daniel Leping on 12/22/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation
import Result

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(@autoclosure(escaping) task: () throws -> T) -> Future<T, AnyError> {
    return future(Queue.global.context, task: task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(task: () throws -> T) -> Future<T, AnyError> {
    return future(Queue.global.context, task: task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T>(context: ExecutionContext, task: () throws -> T) -> Future<T, AnyError> {
    return future(context: context) { () -> Result<T, AnyError> in
        do {
            return Result(value: try task())
        } catch let e {
            return Result(error: AnyError(cause: e))
        }
    }
}