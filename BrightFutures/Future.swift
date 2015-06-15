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

public protocol ResultType {
    typealias Value
    typealias Error: ErrorType
    
    var value: Value? { get }
    var error: Error? { get }
    
    init(value: Value)
    init(error: Error)
    
    func analysis<U>(@noescape ifSuccess ifSuccess: Value -> U, @noescape ifFailure: Error -> U) -> U
}

extension Result: ResultType { }

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(@autoclosure(escaping) task: () -> T) -> Future<T, NoError> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on `Queue.global` and wraps the result of the task in a Future
public func future<T>(task: () -> T) -> Future<T, NoError> {
    return future(context: Queue.global.context, task: task)
}

/// Executes the given task on the given context and wraps the result of the task in a Future
public func future<T>(context c: ExecutionContext, task: () -> T) -> Future<T, NoError> {
    return future(context: c) { () -> Result<T, NoError> in
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
    let promise = Promise<T, E>();
    
    c {
        try! promise.complete(task())
    }
    
    return promise.future
}

/// Defines BrightFutures' default threading behavior:
/// - if on the main thread, `Queue.main.context` is returned
/// - if off the main thread, `Queue.global.context` is returned
func defaultContext() -> ExecutionContext {
    return toContext(NSThread.isMainThread() ? Queue.main : Queue.global)
}

/// A Future represents the outcome of an asynchronous operation
/// The outcome will be represented as an instance of the `Result` enum and will be stored
/// in the `result` property. As long as the operation is not yet completed, `result` will be nil.
/// Interested parties can be informed of the completion by using one of the available callback
/// registration methods (e.g. onComplete, onSuccess & onFailure) or by immediately composing/chaining
/// subsequent actions (e.g. map, flatMap, recover, andThen, etc.).
///
/// For more info, see the project README.md
public class Future<T, E: ErrorType>: Deferred<Result<T, E>> {
    
    public typealias FailureCallback = E -> ()
    
    public required init() {
        super.init()
    }
    
    public init(value: T) {
        super.init(result: Result(value: value))
    }
    
    public init(error: E) {
        super.init(result: Result(error: error))
    }

}

public extension DeferredType where Res: ResultType, Res.Error: ErrorType {
    
    /// Returns a new future that succeeded with the given value
    static func succeeded(value: Res.Value) -> Self {
        return completed(Res(value: value))
    }

    /// Returns a new future that failed with the given error
    static func failed(error: Res.Error) -> Self {
        return completed(Res(error: error))
    }
    
    static func completeAfter(delay: NSTimeInterval, withValue value: Res.Value) -> Self {
        return completeAfter(delay, withResult: Res(value: value))
    }
    
    static func completeAfter(delay: NSTimeInterval, withError error: Res.Error) -> Self {
        return completeAfter(delay, withResult: Res(error: error))
    }
    
    /// Returns the value that the future succesfully completed with, or `nil` if the future failed or is still in progress
    public var value: Res.Value? {
        return self.result?.value
    }
    
    /// Returns the error that the future failed with, or `nil` if the future succeeded or is still in progress
    public var error: Res.Error? {
        return self.result?.error
    }
    
    /// `true` if the future completed with success, or `false` otherwise
    public var isSuccess: Bool {
        return result?.analysis(ifSuccess: { _ in return true }, ifFailure: { _ in return false }) ?? false
    }
    
    /// `true` if the future failed, or `false` otherwise
    public var isFailure: Bool {
        return !isSuccess
    }
    
    public func onSuccess(context c: ExecutionContext = defaultContext(), callback: Res.Value -> ()) -> Self {
        return onComplete(context: c) { res in
            res.analysis(ifSuccess: callback, ifFailure: { _ in })
        }
    }

    public func onFailure(context c: ExecutionContext = defaultContext(), callback: Res.Error -> ()) -> Self {
        return onComplete(context: c) { res in
            res.analysis(ifSuccess: { _ in }, ifFailure: callback)
        }
    }
    
    /// Shorthand for map(context:transform:), needed to be able to do d.map(func)
    func map<U>(transform: Res.Value -> U) -> Future<U, Res.Error> {
        return map(context: defaultContext(), transform: transform)
    }

    func map<U>(context c: ExecutionContext, transform: Res.Value -> U) -> Future<U, Res.Error> {
        let f = Future<U, Res.Error>()
        
        onComplete(context: c) { res in
            res.analysis(ifSuccess: { try! f.success(transform($0)) }, ifFailure: { try! f.failure($0) })
        }
        
        return f
    }
    
    public func flatMap<U>(context c: ExecutionContext = defaultContext(), transform: Res.Value -> Future<U, Res.Error>) -> Future<U, Res.Error> {
        return map(context: c, transform: transform).flatten()
    }
    
    public func flatMap<U>(context c: ExecutionContext = defaultContext(), transform: Res.Value -> Result<U, Res.Error>) -> Future<U, Res.Error> {
        return map(context: c, transform: transform).flatten()
    }
    
    func mapError<E1>(context c: ExecutionContext, transform: Res.Error -> E1) -> Future<Res.Value, E1> {
        let f = Future<Res.Value, E1>()
        
        onComplete(context: c) { res in
            res.analysis(ifSuccess: { try! f.success($0) }, ifFailure: { try! f.failure(transform($0)) })
        }
        
        return f
    }
    
    public func recover(context c: ExecutionContext = defaultContext(), task: Res.Error -> Res.Value) -> Future<Res.Value, NoError> {
        return self.recoverWith(context: c) { error -> Future<Res.Value, NoError> in
            return Future<Res.Value, NoError>.succeeded(task(error))
        }
    }

    public func recoverWith<E1: ErrorType>(context c: ExecutionContext = defaultContext(), task: Res.Error -> Future<Res.Value, E1>) -> Future<Res.Value, E1> {
        let f = Future<Res.Value, E1>()

        onComplete(context: c) { result in
            result.analysis(ifSuccess: { try! f.success($0) }, ifFailure: { f.completeWith(task($0)) })
        }
        
        return f
    }
    
    public func zip<D: DeferredType where D.Res: ResultType, D.Res.Error == Res.Error>(other: D) -> Future<(Res.Value,D.Res.Value), D.Res.Error> {
        return flatMap(context: ImmediateExecutionContext) { (thisVal: Res.Value) -> Future<(Res.Value,D.Res.Value), D.Res.Error> in
            return other.map { otherVal in
                return (thisVal, otherVal)
            }
        }
    }
    
    public func filter(p: (Res.Value -> Bool)) -> Future<Res.Value, BrightFuturesError<Res.Error>> {
        return self.mapError(context: ImmediateExecutionContext) { error -> BrightFuturesError<Res.Error> in
            return BrightFuturesError(external: error)
        }.flatMap { value -> Result<Res.Value, BrightFuturesError<Res.Error>> in
            if p(value) {
                return Result.success(value)
            } else {
                return Result.failure(.NoSuchElement)
            }
        }
    }
    
    public func forceType<U, E1>() -> Future<U, E1> {
        return map(context: ImmediateExecutionContext) {
            $0 as! U
        }.mapError(context: ImmediateExecutionContext) {
            $0 as! E1
        }
    }
    
    public func asVoid() -> Future<Void,Res.Error> {
        return map { _ in () }
    }
    
}

internal extension MutableDeferredType where Res: ResultType {
    
    func success(value: Res.Value) throws {
        try complete(Res(value: value))
    }
    
    func failure(error: Res.Error) throws {
        try complete(Res(error: error))
    }
    
    func trySuccess(value: Res.Value) -> Bool {
        return tryComplete(Res(value: value))
    }
    
    func tryFailure(error: Res.Error) -> Bool {
        return tryComplete(Res(error: error))
    }
    
}

extension DeferredType where Res: ResultType, Res.Value: ResultType, Res.Error: ErrorType, Res.Error == Res.Value.Error {
    
    /// Flattens a result in a future
    public func flatten() -> Future<Res.Value.Value, Res.Error> {
        let f = Future<Res.Value.Value, Res.Error>()
        
        onComplete(context: ImmediateExecutionContext) { res in
            res.analysis(ifSuccess: { res in
                res.analysis(ifSuccess: { try! f.success($0); return }, ifFailure: { err in try! f.failure(err); return })
            }, ifFailure: {
                try! f.failure($0)
            })
        }
        
        return f
    }
    
}

extension DeferredType where Res: ResultType, Res.Value: DeferredType, Res.Value.Res: ResultType, Res.Error: ErrorType, Res.Value.Res.Error == Res.Error {
    
    /// Flattens a future in a future
    public func flatten() -> Future<Res.Value.Res.Value, Res.Error> {
        let f = Future<Res.Value.Res.Value, Res.Error>()

        onComplete(context: ImmediateExecutionContext) { res in
            res.analysis(ifSuccess: { innerFuture -> () in
                innerFuture.onComplete(context: ImmediateExecutionContext) { (res:Res.Value.Res) in
                    res.analysis(ifSuccess: { try! f.success($0) }, ifFailure: { err in try! f.failure(err) })
                }
            }, ifFailure: { try! f.failure($0) })
        }
        
        return f
    }
    
}

/// Short-hand for `lhs.recover(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <D: DeferredType where D.Res: ResultType, D.Res.Error: ErrorType>(lhs: D, @autoclosure(escaping) rhs: () -> D.Res.Value) -> Future<D.Res.Value, NoError> {
    return lhs.recover(context: defaultContext(), task: { _ in
        return rhs()
    })
}

/// Short-hand for `lhs.recoverWith(rhs())`
/// `rhs` is executed according to the default threading model (see README.md)
public func ?? <T, E, E1>(lhs: Future<T, E>, @autoclosure(escaping) rhs: () -> Future<T, E1>) -> Future<T, E1> {
    return lhs.recoverWith(context: defaultContext(), task: { _ in
        return rhs()
    })
}

extension DeferredType where Res: ResultType, Res.Error == NoError {
    /// 'promotes' a `Future` with error type `NoError` to a `Future` with an error type of choice.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompletedOf`
    /// This is a safe operation, because a `Future` with error type `NoError` is guaranteed never to fail
    public func promoteError<E>() -> Future<Res.Value, E> {
        return mapError(context: ImmediateExecutionContext) { $0 as! E } // future will never fail, so this map block will never get called
    }
}

extension DeferredType where Res: ResultType, Res.Error == BrightFuturesError<NoError> {
    ///// 'promotes' a `Future` with error type `BrightFuturesError<NoError>` to a `Future` with an
    ///// `BrightFuturesError<E>` error type where `E` can be any type conforming to `ErrorType`.
    ///// This allows the `Future` to be used more easily in combination with other futures
    ///// for operations such as `sequence` and `firstCompletedOf`
    ///// This is a safe operation, because a `BrightFuturesError<NoError>` will never be `.External`
    public func promoteError<E>() -> Future<Res.Value, BrightFuturesError<E>> {
        return mapError(context: ImmediateExecutionContext) { err in
            switch err {
            case .NoSuchElement:
                return BrightFuturesError<E>.NoSuchElement
            case .InvalidationTokenInvalidated:
                return BrightFuturesError<E>.InvalidationTokenInvalidated
            case .IllegalState:
                return BrightFuturesError<E>.IllegalState
            case .External(_):
                fatalError("Encountered BrightFuturesError.External with NoError, which should be impossible")
            }
        }
    }
}

/// Can be used as the value type of a `Future` or `Result` to indicate it can never be a success.
/// This is guaranteed by the type system, because `NoValue` has no possible values and thus cannot be created.
public enum NoValue { }

extension DeferredType where Res: ResultType, Res.Error: ErrorType, Res.Value == NoValue {
    /// 'promotes' a `Future` with value type `NoValue` to a `Future` with a value type of choice.
    /// This allows the `Future` to be used more easily in combination with other futures
    /// for operations such as `sequence` and `firstCompletedOf`
    /// This is a safe operation, because a `Future` with value type `NoValue` is guaranteed never to succeed
    public func promoteValue<U>() -> Future<U, Res.Error> {
        return map(context: ImmediateExecutionContext) { $0 as! U } // future will never succeed, so this map block will never get called
    }
}
