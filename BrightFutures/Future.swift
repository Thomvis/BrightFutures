// The MIT License (MIT)
//
// Copyright (c) 2014 Thomas Visser
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Result

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(@autoclosure(escaping) task: () -> T) -> Future<T, NoError> {
    return future(Queue.global.context, task: task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(task: () -> T) -> Future<T, NoError> {
    return future(Queue.global.context, task: task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T>(context: ExecutionContext, task: () -> T) -> Future<T, NoError> {
    return future(context: context) { () -> Result<T, NoError> in
        return Result(value: task())
    }
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T, E>(@autoclosure(escaping) task: () -> Result<T, E>) -> Future<T, E> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T, E>(task: () -> Result<T, E>) -> Future<T, E> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T, E>(context c: ExecutionContext, task: () -> Result<T, E>) -> Future<T, E> {
    let future = Future<T, E>();
    
    c {
        future.complete(task())
    }
    
    return future
}

/// A Future represents the outcome of an asynchronous operation
/// The outcome will be represented as an instance of the `Result` enum and will be stored
/// in the `result` property. As long as the operation is not yet completed, `result` will be nil.
/// Interested parties can be informed of the completion by using one of the available callback
/// registration methods (e.g. onComplete, onSuccess & onFailure) or by immediately composing/chaining
/// subsequent actions (e.g. map, flatMap, recover, andThen, etc.).
///
/// For more info, see the project README.md
public final class Future<T, E: ErrorType>: Async<Result<T, E>> {
    
    public typealias CompletionCallback = (result: Result<T,E>) -> Void
    public typealias SuccessCallback = T -> Void
    public typealias FailureCallback = E -> Void
    
    public required init() {
        super.init()
    }
    
    public required init(result: Future.Value) {
        super.init(result: result)
    }
    
    public init(value: T, delay: NSTimeInterval) {
        super.init(result: Result<T, E>(value: value), delay: delay)
    }
    
    public required init<A: AsyncType where A.Value == Value>(other: A) {
        super.init(other: other)
    }
    
    public convenience init(value: T) {
        self.init(result: Result(value: value))
    }
    
    public convenience init(error: E) {
        self.init(result: Result(error: error))
    }
    
    public required init(@noescape resolver: (result: Value -> Void) -> Void) {
        super.init(resolver: resolver)
    }
    
}

/// Short-hand for `lhs.recover(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <T, E>(lhs: Future<T, E>, @autoclosure(escaping) rhs: () -> T) -> Future<T, NoError> {
    return lhs.recover(context: DefaultThreadingModel(), task: { _ in
        return rhs()
    })
}

/// Short-hand for `lhs.recoverWith(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <T, E, E1>(lhs: Future<T, E>, @autoclosure(escaping) rhs: () -> Future<T, E1>) -> Future<T, E1> {
    return lhs.recoverWith(context: DefaultThreadingModel(), task: { _ in
        return rhs()
    })
}

/// Can be used as the value type of a `Future` or `Result` to indicate it can never be a success.
/// This is guaranteed by the type system, because `NoValue` has no possible values and thus cannot be created.
public enum NoValue { }
