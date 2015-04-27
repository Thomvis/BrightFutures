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

/// Boxes a value of type `T`
/// We have to box the Result value until Swift supports variable-layout enums
public final class Box<T> {
    
    /// The boxed value
    public let value: T
    
    /// Creates a new box with the given value
    public init(_ value: T) {
        self.value = value
    }
}

/// Represents the result of a failable operation, 
/// which is either a succes with a value of type `T` 
/// or a failure with an NSError
public enum Result<T> {
    case Success(Box<T>)
    case Failure(NSError)
    
    /// Creates a new .Success that wraps the given value
    public init(_ value: T) {
        self = .Success(Box(value))
    }
    
    /// `true` iff this result is a .Success
    public var isSuccess: Bool {
        get {
            switch self {
            case .Success(_):
                return true
            case .Failure(_):
                return false
            }
        }
    }
    
    /// `true` iff this result is a .Failure
    public var isFailure: Bool {
        get {
            return !self.isSuccess
        }
    }
    
    /// Returns the value associated with this result if it is a .Success, `nil` otherwise
    public var value: T? {
        get {
            switch self {
            case .Success(let boxedValue):
                return boxedValue.value
            default:
                return nil
            }
        }
    }
    
    /// Returns the error associated with this result if it is a .Failure, `nil` otherwise
    public var error: NSError? {
        get {
            switch self {
            case .Failure(let error):
                return error
            default:
                return nil
            }
        }
    }
}

extension Result {
    
    /// Returns a .Success with the value returned from the given closure when invoked with the
    /// value associated with this result if it is a .Success. If this result is a .Failure, a
    /// .Failure with the same error is returned.
    public func map<U>(@noescape f:T -> U) -> Result<U> {
        switch self {
        case .Success(let boxedValue):
            return Result<U>.Success(Box(f(boxedValue.value)))
        case .Failure(let err):
            return Result<U>.Failure(err)
        }
    }
    
    /// Enables the chaining of two failable operations where the second operation
    /// depends on the success value of the first.
    /// Like map, the given closure (that performs the second operation) is only executed
    /// if the first operation result (this result) is a .Success
    /// If a regular `map` was used, the result would be `Result<Result<U>>`.
    /// The implementation of this function uses `map`, but then flattens the result before returning it.
    public func flatMap<U>(@noescape f: T -> Result<U>) -> Result<U> {
        return flatten(self.map(f))
    }
    
    /// Enables the chaining of two failable operations where the second operation is asynchronous and
    /// represented by a future. See `flatMap<U>(@noescape f: T -> Result<U>) -> Result<U>`
    public func flatMap<U>(@noescape f: T -> Future<U>) -> Future<U> {
        return flatten(self.map(f))
    }
}

extension Result {
    
    /// Returns `self.value` if this result is a .Success, or the given value otherwise
    public func recover(value: T) -> T {
        return self.value ?? value
    }
    
    /// Returns this result if it is a .Success, or the given result otherwise
    public func recoverWith(result: Result<T>) -> Result<T> {
        switch self {
        case .Success(_):
            return self
        case .Failure(_):
            return result
        }
    }

}

/// Returns a .Failure with the error from the outer or inner result if either of the two failed
/// or a .Success with the success value from the inner Result
public func flatten<T>(result: Result<Result<T>>) -> Result<T> {
    switch result {
    case .Success(let boxedValue):
        return boxedValue.value
    case .Failure(let err):
        return Result<T>.Failure(err)
    }
}

/// Returns the inner future if the outer result succeeded or a failed future
/// with the error from the outer result otherwise
public func flatten<T>(result: Result<Future<T>>) -> Future<T> {
    switch result {
    case .Success(let boxedFuture):
        return boxedFuture.value
    case .Failure(let err):
        return Future.failed(err)
    }
}

/// Turns a sequence of `Result<T>`'s into a Result with an array of T's (`Result<[T]>`)
/// If one of the results in the given sequence is a .Failure, the returned result is a .Failure with the
/// error from the first failed result from the sequence.
public func sequence<S: SequenceType, T where S.Generator.Element == Result<T>>(seq: S) -> Result<[T]> {
    return reduce(seq, Result([])) { (res, elem) -> Result<[T]> in
        switch res {
        case .Success(let boxedResultSequence):
            switch elem {
            case .Success(let boxedElemValue):
                let newSeq = boxedResultSequence.value + [boxedElemValue.value]
                return Result<[T]>.Success(Box(newSeq))
            case .Failure(let elemError):
                return Result<[T]>.Failure(elemError)
            }
        case .Failure(let err):
            return res
        }
    }
}

/// The `.Failure` coalescing operator (Short-hand for `lhs.recover(rhs()`)
public func ?? <T>(lhs: Result<T>, @autoclosure rhs: () -> T) -> T {
    return lhs.recover(rhs())
}

/// The `.Failure` coalescing operator (Short-hand for `lhs.recoverWith(rhs()`)
public func ?? <T>(lhs: Result<T>, @autoclosure rhs: () -> Result<T>) -> Result<T> {
    return lhs.recoverWith(rhs())
}
