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
    
    /// The future will fail with an error with .InvalidationTokenInvalidated when the token invalidates
    var future: Future<NoValue, BrightFuturesError<NoError>> { get }
    
    /// The synchronous context on which the invalidation and callbacks are executed
    var context: ExecutionContext { get }
}

/// The type that all invalidation tokens that can be manually invalidated conform to
public protocol ManualInvalidationTokenType : InvalidationTokenType {
    /// Invalidates the token
    func invalidate()
}

/// A default invalidation token implementation
public class InvalidationToken : ManualInvalidationTokenType {
   
    let promise = Promise<NoValue, BrightFuturesError<NoError>>()
    
    /// The synchronous context on which the invalidation and callbacks are executed
    public let context = toContext(Semaphore(value: 1))
    
    /// Creates a new valid token
    public init() { }
    
    /// Indicates if the token is invalid
    public var isInvalid: Bool {
        return promise.future.isCompleted
    }
    
    /// The future will fail with an error with .InvalidationTokenInvalidated when the token invalidates
    public var future: Future<NoValue, BrightFuturesError<NoError>> {
        return self.promise.future
    }
    
    /// Invalidates the token
    public func invalidate() {
        self.promise.failure(.InvalidationTokenInvalidated)
    }
}
