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
    
    // The synchronous context on which the invalidation and callbacks are executed
    var context: ExecutionContext { get }
}

public protocol ManualInvalidationTokenType : InvalidationTokenType {
    func invalidate()
}

public class InvalidationToken : ManualInvalidationTokenType {
    
    let promise = Promise<Void>()
    
    public let context = toContext(Semaphore(value: 1))
    
    public init() { }
    
    public var isInvalid: Bool {
        return promise.future.isCompleted
    }
    
    public var future: Future<Void> {
        return self.promise.future
    }
    
    public func invalidate() {
        self.promise.failure(errorFromCode(.InvalidationTokenInvalidated))
    }
}
