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

/**
 * This class is the equivalent to Scala's Future object (i.e. singleton/static class)
 *
 * NOTE: the methods in this class should work on any Sequence, but the Swift compiler is currently
 * not supporting this fully.
 */
public class FutureUtils {
    
    public class func firstCompletedOf<T>(seq: [Future<T>]) -> Future<T> {
        let p = Promise<T>()
        
        for fut in seq {
            fut.onComplete(context: Queue.global.context) { res in
                p.tryComplete(res)
                return
            }
        }
        
        return p.future
    }
    
    public class func find<T>(seq: [Future<T>], context c: ExecutionContext = Queue.global.context, p: T -> Bool) -> Future<T> {
        return self.sequence(seq).flatMap(context: c) { val -> Result<T> in
            for elem in val {
                if (p(elem)) {
                    return .Success(Box(elem))
                }
            }
            return .Failure(errorFromCode(.NoSuchElement))
        }
    }
    
    public class func fold<T,R>(seq: [Future<T>], context c: ExecutionContext = Queue.global.context, zero: R, op: (R, T) -> R) -> Future<R> {
        return seq.reduce(Future.succeeded(zero), combine: { zero, elem in
            return zero.flatMap { zeroVal in
                elem.map(context: c) { elemVal in
                    return op(zeroVal, elemVal)
                }
            }
        })
    }
    
    public class func sequence<T>(seq: [Future<T>]) -> Future<[T]> {
        return self.traverse(seq, fn: { (fut: Future<T>) -> Future<T> in
            return fut
        })
    }
    
    public class func traverse<T, U>(seq: [T], context c: ExecutionContext = Queue.global.context, fn: T -> Future<U>) -> Future<[U]> {
        
        return self.fold(map(seq, fn), context: c, zero: [U](), op: { (list: [U], elem: U) -> [U] in
            return list + [elem]
        })
    }
    
}