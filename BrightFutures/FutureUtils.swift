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
 *
 * NOTE: the methods in this class should work on any Sequence, but the Swift compiler is currently
 * not supporting this fully.
 */
public class FutureUtils {
    
    public class func firstCompletedOf<T>(seq: [Future<T>]) -> Future<T> {
        let p = Promise<T>()
        
        for fut in seq {
            fut.onComplete { res in
                p.tryComplete(res)
                return
            }
        }
        
        return p.future
    }
    
    public class func fold<T,R>(seq: [Future<T>], context c: ExecutionContext = Queue.global, zero: R, op: (R, T) -> R) -> Future<R> {
        return seq.reduce(Future.succeeded(zero), combine: { zero, elem in
            return zero.flatMap { zeroVal in
                elem.map(context: c) { elemVal, _ in
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
    
    public class func traverse<T, U>(seq: [T], fn: T -> Future<U>) -> Future<[U]> {
        return self.traverse(seq, context: Queue.global, fn: fn)
    }
    
    public class func traverse<T, U>(seq: [T], context c: ExecutionContext, fn: T -> Future<U>) -> Future<[U]> {
        
        return self.fold(map(seq, fn), context: c, zero: [U](), op: { (list: [U], elem: U) -> [U] in
            // this should be even nicer in beta 5
            var l = list
            l += elem
            return l
        })
    }
    
}