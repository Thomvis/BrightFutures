//
//  InvalidationToken.swift
//  BrightFutures
//
//  Created by Thomas Visser on 15/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

public let FutureInvalidatedError = 1

public protocol InvalidationToken {
    var isInvalid : Bool { get }
    
    var future: Future<Void>? { get }
}

public protocol ManualInvalidationTokenType : InvalidationToken {
    func invalidate()
}

public class ObjectExistenceInvalidationToken : InvalidationToken {
    weak var object: AnyObject?
    
    public var isInvalid: Bool {
        get {
            return object == nil
        }
    }
    
    public var future: Future<Void>? = nil
    
    public init(object: AnyObject) {
        self.object = object
    }
}

public class DefaultInvalidationToken : ManualInvalidationTokenType {
    
    let promise = Promise<Void>()
    
    public init() { }
    
    public var isInvalid: Bool {
        get {
            return promise.future.isCompleted
        }
    }
    
    public var future: Future<Void>? {
        get {
            return self.promise.future
        }
    }
    
    public func invalidate() {
        self.promise.failure(NSError(domain: BrightFuturesErrorDomain, code: FutureInvalidatedError, userInfo: nil))
    }
}

public extension Future {
    
    public func validate(token: InvalidationToken) -> Future<T> {
        let p = Promise<T>()
        let q = Queue()
        
        token.future?.onFailure(context: q) { error in
            p.tryFailure(error)
            return
        }
        
        self.onComplete(context: q) { result in
            if token.isInvalid {
                p.tryFailure(NSError(domain: BrightFuturesErrorDomain, code: FutureInvalidatedError, userInfo: nil))
            } else {
                p.tryComplete(result)
            }
        }
        
        return p.future
    }
    
}