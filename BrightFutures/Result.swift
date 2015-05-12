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

extension Result {
    
    /// Enables the chaining of two failable operations where the second operation is asynchronous and
    /// represented by a future. See `flatMap<U>(@noescape f: T -> Result<U>) -> Result<U>`
}

/// Returns a .Failure with the error from the outer or inner result if either of the two failed
/// or a .Success with the success value from the inner Result
public func flatten<T>(result: Result<Result<T,NSError>,NSError>) -> Result<T,NSError> {
    return result.analysis(ifSuccess: { $0 }, ifFailure: { Result(error: $0) })
}

/// Returns the inner future if the outer result succeeded or a failed future
/// with the error from the outer result otherwise
public func flatten<T>(result: Result<Future<T>,NSError>) -> Future<T> {
    return result.analysis(ifSuccess: { $0 }, ifFailure: { Future.failed($0) })
}

/// Turns a sequence of `Result<T>`'s into a Result with an array of T's (`Result<[T]>`)
/// If one of the results in the given sequence is a .Failure, the returned result is a .Failure with the
/// error from the first failed result from the sequence.
public func sequence<S: SequenceType, T where S.Generator.Element == Result<T,NSError>>(seq: S) -> Result<[T],NSError> {
    return reduce(seq, Result(value: [])) { (res, elem) -> Result<[T],NSError> in
        switch res {
        case .Success(let boxedResultSequence):
            switch elem {
            case .Success(let boxedElemValue):
                let newSeq = boxedResultSequence.value + [boxedElemValue.value]
                return Result<[T],NSError>(value: newSeq)
            case .Failure(let boxedElemError):
                return Result<[T],NSError>(error: boxedElemError.value)
            }
        case .Failure(let err):
            return res
        }
    }
}