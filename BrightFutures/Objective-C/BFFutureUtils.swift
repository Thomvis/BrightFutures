//
//  BFFutureUtils.swift
//  BrightFutures
//
//  Created by Thomas Visser on 23/03/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

@objc public class BFFutureUtils {
    
    public class func firstCompletedOf(seq: [BFFuture]) -> BFFuture {
        return bridge(FutureUtils.firstCompletedOf(bridge(seq)))
    }
    
    public class func find(seq: [BFFuture], p: AnyObject? -> Bool) -> BFFuture {
        return bridge(FutureUtils.find(bridge(seq), p: p))
    }
    
    public class func find(seq: [BFFuture], context c: BFExecutionContext, p: AnyObject? -> Bool) -> BFFuture {
        return bridge(FutureUtils.find(bridge(seq), context: bridge(c), p: p))
    }

    public class func fold(seq: [BFFuture], zero: AnyObject?, op: (AnyObject?, AnyObject?) -> AnyObject?) -> BFFuture {
        return bridge(FutureUtils.fold(bridge(seq), zero: zero, op: op))
    }
    
    public class func fold(seq: [BFFuture], context c: BFExecutionContext = BFExecutionContext.globalQueue, zero: AnyObject?, op: (AnyObject?, AnyObject?) -> AnyObject?) -> BFFuture {
        return bridge(FutureUtils.fold(bridge(seq), context: bridge(c), zero: zero, op: op))
    }

    public class func sequence(seq: [BFFuture]) -> BFFuture {
        return bridge(FutureUtils.sequence(bridge(seq)).map(bridge))
    }
    
    public class func traverse(seq: [AnyObject], fn: AnyObject -> BFFuture) -> BFFuture {
        return bridge(FutureUtils.traverse(seq, fn: { obj -> Future<AnyObject?> in
            return fn(obj).future
        }).map(bridge))
    }
    
    public class func traverse(seq: [AnyObject], context c: BFExecutionContext, fn: AnyObject -> BFFuture) -> BFFuture {
        return bridge(FutureUtils.traverse(seq, fn: { obj -> Future<AnyObject?> in
            return fn(obj).future
        }).map(bridge))
    }
    
}

func bridge(seq: [BFFuture]) -> [Future<AnyObject?>] {
    return seq.map { bffuture in
        bffuture.future
    }
}

func bridge(seq: [AnyObject?]) -> NSArray {
    return seq.map { (elem:AnyObject?) -> AnyObject in
        return elem ?? NSNull()
    }
}

