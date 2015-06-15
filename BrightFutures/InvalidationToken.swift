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
    public func invalidate() throws {
        try self.promise.failure(.InvalidationTokenInvalidated)
    }
}

public extension DeferredType {
    
    public func onComplete(context c: ExecutionContext = defaultContext(), token: InvalidationToken, callback: Res -> ()) -> Self {
        onComplete(context: c) { res in
            token.context {
                if !token.isInvalid {
                    callback(res)
                }
            }
        }
        
        return self
    }
    
}

public extension DeferredType where Res: ResultType, Res.Error: ErrorType {
    public func onSuccess(context c: ExecutionContext = defaultContext(), token: InvalidationTokenType, callback: Res.Value -> ()) -> Self {
        onSuccess(context: c) { value in
            token.context {
                if !token.isInvalid {
                    callback(value)
                }
            }
        }
        
        return self
    }
    
    public func onFailure(context c: ExecutionContext = defaultContext(), token: InvalidationTokenType, callback: Res.Error -> ()) -> Self {
        onFailure(context: c) { error in
            token.context {
                if !token.isInvalid {
                    callback(self.result!.error!)
                }
            }
        }
        return self
    }
}
