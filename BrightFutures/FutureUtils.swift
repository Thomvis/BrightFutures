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
        
        return self.fold(map(seq, fn), context: c, zero: [U](), op: { (list: [U], elem: U) -> [U] in
            // this should be even nicer in beta 5
            var l = list
            l += elem
            return l
        })
    }
    
}