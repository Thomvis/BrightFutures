//
//  FutureUtils.swift
//  BrightFutures
//
//  Created by Thomas Visser on 15/07/14.
//  Copyright (c) 2014 Thomas Visser. All rights reserved.
//

import Foundation

/**
 * This class is the equivalent to Scala's Future object (i.e. singleton/static class)
 */
public class FutureUtils {
    
    public class func fold<T,R>(seq: [Future<T>], context c: ExecutionContext = Queue.global, zero: R, op: (R, T) -> R) -> Future<R> {
        return seq.reduce(Future.succeeded(zero), combine: { zero, elem in
            return zero.flatMap { zeroVal in
                elem.map(context: c) { elemVal, _ in
                    return op(zeroVal, elemVal)
                }
            }
        })
    }
    
    public class func traverse<S : Sequence,T, U where S.GeneratorType.Element == T>(seq: S, fn: T -> Future<U>) -> Future<[U]> {
        return self.traverse(seq, context: Queue.global, fn: fn)
    }
    
    public class func traverse<S : Sequence,T, U where S.GeneratorType.Element == T>(seq: S, context c: ExecutionContext, fn: T -> Future<U>) -> Future<[U]> {
        let futureSequence = map(seq, fn)

        let p = Promise<[U]>()
        var resultingArray = [U]()
        
        var baseFuture = Future<Void>.succeeded()
        for future in futureSequence {
            let p1 = Promise<Void>()
            baseFuture = baseFuture.andThen { _ in
                future.onComplete(context: c) { res in
                    switch res {
                    case .Success(let val):
                        resultingArray.append(val)
                        p1.success()
                    case .Failure(let err):
                        p.tryError(err)
                    }
                }
                return
            }
            baseFuture = p1.future
        }
        
        baseFuture.onSuccess { _ in
            p.success(resultingArray)
        }
        
        baseFuture.onFailure { err in
            p.error(err)
        }
        
        return p.future
    }
    
}