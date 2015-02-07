//
//  InvalidationToken.swift
//  BrightFutures
//
//  Created by Thomas Visser on 15/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

public let InvalidationTokenInvalid = 1

public protocol InvalidationTokenType {
    var isInvalid : Bool { get }
    
    var future: Future<Void> { get }
}

public protocol ManualInvalidationTokenType : InvalidationTokenType {
    func invalidate()
}

public class InvalidationToken : ManualInvalidationTokenType {
    
    let promise = Promise<Void>()
    
    public init() { }
    
    public var isInvalid: Bool {
        get {
            return promise.future.isCompleted
        }
    }
    
    public var future: Future<Void> {
        get {
            return self.promise.future
        }
    }
    
    public func invalidate() {
        self.promise.failure(errorFromCode(.InvalidationTokenInvalidated))
    }
}

public extension Future {
    
    public func validate(token: InvalidationTokenType) -> Future<T> {
        let p = Promise<T>()
        let c = Queue().context
        
        token.future.onFailure(context: c) { error in
            p.tryFailure(error)
            return
        }
        
        self.onComplete(context: c) { result in
            if token.isInvalid {
                p.tryFailure(errorFromCode(.InvalidationTokenInvalidated))
            } else {
                p.tryComplete(result)
            }
        }
        
        return p.future
    }
    
}