//
//  InvalidationToken.swift
//  BrightFutures
//
//  Created by Thomas Visser on 15/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

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
    func invalidate() throws
}

/// A default invalidation token implementation
public class InvalidationToken : ManualInvalidationTokenType {
   
    public let future = Future<NoValue, BrightFuturesError<NoError>>()
    
    /// The synchronous context on which the invalidation and callbacks are executed
    public let context = toContext(Semaphore(value: 1))
    
    /// Creates a new valid token
    public init() { }
    
    /// Indicates if the token is invalid
    public var isInvalid: Bool {
        return future.isCompleted
    }
    
    /// Invalidates the token
    public func invalidate() throws {
        try future.failure(.InvalidationTokenInvalidated)
    }
}
