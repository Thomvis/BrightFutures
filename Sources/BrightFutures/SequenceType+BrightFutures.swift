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

extension Sequence {
    /// Turns a sequence of T's into an array of `Future<U>`'s by calling the given closure for each element in the sequence.
    /// If no context is provided, the given closure is executed on `Queue.global`
    public func traverse<U, E, A: AsyncType>(_ context: @escaping ExecutionContext = DispatchQueue.global().context, f: (Iterator.Element) -> A) -> Future<[U], E> where A.Value: ResultProtocol, A.Value.Value == U, A.Value.Error == E {
        return map(f).fold(context, zero: [U]()) { (list: [U], elem: U) -> [U] in
            return list + [elem]
        }
    }
}

extension Sequence where Iterator.Element: AsyncType {
    /// Returns a future that returns with the first future from the given sequence that completes
    /// (regardless of whether that future succeeds or fails)
    public func firstCompleted() -> Iterator.Element {
        let res = Async<Iterator.Element.Value>()
        for fut in self {
            fut.onComplete(DispatchQueue.global().context) {
                res.tryComplete($0)
            }
        }
        return Iterator.Element(other: res)
    }
}

extension Sequence where Iterator.Element: AsyncType, Iterator.Element.Value: ResultProtocol {
    
    //// The free functions in this file operate on sequences of Futures
    
    /// Performs the fold operation over a sequence of futures. The folding is performed
    /// on `Queue.global`.
    /// (The Swift compiler does not allow a context parameter with a default value
    /// so we define some functions twice)
    public func fold<R>(_ zero: R, f: @escaping (R, Iterator.Element.Value.Value) -> R) -> Future<R, Iterator.Element.Value.Error> {
        return fold(DispatchQueue.global().context, zero: zero, f: f)
    }
    
    /// Performs the fold operation over a sequence of futures. The folding is performed
    /// in the given context.
    public func fold<R>(_ context: @escaping ExecutionContext, zero: R, f: @escaping (R, Iterator.Element.Value.Value) -> R) -> Future<R, Iterator.Element.Value.Error> {
        return reduce(Future<R, Iterator.Element.Value.Error>(value: zero)) { zero, elem in
            return zero.flatMap(MaxStackDepthExecutionContext) { zeroVal in
                elem.map(context) { elemVal in
                    return f(zeroVal, elemVal)
                }
            }
        }
    }
    
    /// Turns a sequence of `Future<T>`'s into a future with an array of T's (Future<[T]>)
    /// If one of the futures in the given sequence fails, the returned future will fail
    /// with the error of the first future that comes first in the list.
    public func sequence() -> Future<[Iterator.Element.Value.Value], Iterator.Element.Value.Error> {
        return traverse(ImmediateExecutionContext) {
            return $0
        }
    }
    
    /// See `find<S: SequenceType, T where S.Iterator.Element == Future<T>>(seq: S, context c: ExecutionContext, p: T -> Bool) -> Future<T>`
    public func find(_ p: @escaping (Iterator.Element.Value.Value) -> Bool) -> Future<Iterator.Element.Value.Value, BrightFuturesError<Iterator.Element.Value.Error>> {
        return find(DispatchQueue.global().context, p: p)
    }
    
    /// Returns a future that succeeds with the value from the first future in the given
    /// sequence that passes the test `p`.
    /// If any of the futures in the given sequence fail, the returned future fails with the
    /// error of the first failed future in the sequence.
    /// If no futures in the sequence pass the test, a future with an error with NoSuchElement is returned.
    public func find(_ context: @escaping ExecutionContext, p: @escaping (Iterator.Element.Value.Value) -> Bool) -> Future<Iterator.Element.Value.Value, BrightFuturesError<Iterator.Element.Value.Error>> {
        return sequence().mapError(ImmediateExecutionContext) { error in
            return BrightFuturesError(external: error)
        }.flatMap(context) { val -> Result<Iterator.Element.Value.Value, BrightFuturesError<Iterator.Element.Value.Error>> in
            for elem in val {
                if (p(elem)) {
                    return Result(value: elem)
                }
            }
            return Result(error: .noSuchElement)
        }
    }
}

extension Sequence where Iterator.Element: ResultProtocol {
    /// Turns a sequence of `Result<T>`'s into a Result with an array of T's (`Result<[T]>`)
    /// If one of the results in the given sequence is a .failure, the returned result is a .failure with the
    /// error from the first failed result from the sequence.
    public func sequence() -> Result<[Iterator.Element.Value], Iterator.Element.Error> {
        return reduce(Result(value: [])) { (res, elem) -> Result<[Iterator.Element.Value], Iterator.Element.Error> in
            switch res {
            case .success(let resultSequence):
                return elem.analysis(ifSuccess: {
                    let newSeq = resultSequence + [$0]
                    return Result(value: newSeq)
                }, ifFailure: {
                    return Result(error: $0)
                })
            case .failure(_):
                return res
            }
        }
    }
}
