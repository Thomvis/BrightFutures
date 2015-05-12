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

//// The free functions in this file operate on sequences of Futures

/// Performs the fold operation over a sequence of futures. The folding is performed
/// on `Queue.global`.
/// (The Swift compiler does not allow a context parameter with a default value
/// so we define some functions twice)
public func fold<S: SequenceType, T, R where S.Generator.Element == Future<T>>(seq: S, zero: R, f: (R, T) -> R) -> Future<R> {
    
    return fold(seq, context: Queue.global.context, zero, f)
}

/// Performs the fold operation over a sequence of futures. The folding is performed
/// in the given context.
public func fold<S: SequenceType, T, R where S.Generator.Element == Future<T>>(seq: S, context c: ExecutionContext, zero: R, f: (R, T) -> R) -> Future<R> {
    
    return reduce(seq, Future.succeeded(zero)) { zero, elem in
        return zero.flatMap { zeroVal in
            elem.map(context: c) { elemVal in
                return f(zeroVal, elemVal)
            }
        }
    }
}

/// See `traverse<S: SequenceType, T, U where S.Generator.Element == T>(seq: S, context c: ExecutionContext = Queue.global.context, f: T -> Future<U>) -> Future<[U]>`
public func traverse<S: SequenceType, T, U where S.Generator.Element == T>(seq: S, f: T -> Future<U>) -> Future<[U]> {
    return traverse(seq, context: Queue.global.context, f)
}

/// Turns a sequence of T's into an array of `Future<U>`'s by calling the given closure for each element in the sequence.
/// If no context is provided, the given closure is executed on `Queue.global`
public func traverse<S: SequenceType, T, U where S.Generator.Element == T>(seq: S, context c: ExecutionContext = Queue.global.context, f: T -> Future<U>) -> Future<[U]> {
    
    return fold(map(seq, f), context: c, [U]()) { (list: [U], elem: U) -> [U] in
        return list + [elem]
    }
}

/// Turns a sequence of `Future<T>`'s into a future with an array of T's (Future<[T]>)
/// If one of the futures in the given sequence fails, the returned future will fail
/// with the error of the first future that comes first in the list.
public func sequence<S: SequenceType, T where S.Generator.Element == Future<T>>(seq: S) -> Future<[T]> {
    return traverse(seq) { (fut: Future<T>) -> Future<T> in
        return fut
    }
}

/// See `find<S: SequenceType, T where S.Generator.Element == Future<T>>(seq: S, context c: ExecutionContext, p: T -> Bool) -> Future<T>`
public func find<S: SequenceType, T where S.Generator.Element == Future<T>>(seq: S, p: T -> Bool) -> Future<T> {
    return find(seq, context: Queue.global.context, p)
}

/// Returns a future that succeeds with the value from the first future in the given
/// sequence that passes the test `p`. 
/// If any of the futures in the given sequence fail, the returned future fails with the
/// error of the first failed future in the sequence.
/// If no futures in the sequence pass the test, a future with an error with NoSuchElement is returned.
public func find<S: SequenceType, T where S.Generator.Element == Future<T>>(seq: S, context c: ExecutionContext, p: T -> Bool) -> Future<T> {
    return sequence(seq).flatMap(context: c) { val -> Result<T,NSError> in
        for elem in val {
            if (p(elem)) {
                return Result(value: elem)
            }
        }
        return Result(error: errorFromCode(.NoSuchElement))
    }
}

/// Returns a future that returns with the first future from the given sequence that completes
/// (regardless of whether that future succeeds or fails)
public func firstCompletedOf<S: SequenceType, T where S.Generator.Element == Future<T>>(seq: S) -> Future<T> {
    let p = Promise<T>()
    
    for fut in seq {
        fut.onComplete(context: Queue.global.context) { res in
            p.tryComplete(res)
            return
        }
    }
    
    return p.future
}
