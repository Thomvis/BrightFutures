//
//  InvalidationToken.swift
//  BrightFutures
//
//  Created by Thomas Visser on 15/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

/// The error code that a token's future will fail with when the token is invalidated
public let InvalidationTokenInvalid = 1

/// The type that all invalidation tokens conform to
public protocol InvalidationTokenType {
    
    /// Indicates if the token is invalid
    var isInvalid : Bool { get }
    
    /// The Future will fail with an error with code `InvalidationTokenInvalid` when the token invalidates
    var future: Future<Void> { get }
    
    /// The synchronous context on which the invalidation and callbacks are executed
    var context: ExecutionContext { get }
}

/// The type that all invalidation tokens that can be manually invalidated conform to
public protocol ManualInvalidationTokenType : InvalidationTokenType {
    func invalidate()
}

/// A default invalidation token implementation
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
