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

public extension Future {
    
    private func firstCompletedOfSelfAndToken(token: InvalidationTokenType) -> Future<T, BrightFuturesError<E>> {
        return firstCompletedOf([
            self.mapError {
                BrightFuturesError(external: $0)
            },
            token.future.promoteError().promoteValue()
            ]
        )
    }
    
    /// See `onComplete(context c: ExecutionContext = DefaultThreadingModel(), callback: CompletionCallback) -> Future<T, E>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onComplete(context: ExecutionContext = DefaultThreadingModel(), token: InvalidationTokenType, callback: Value -> Void) -> Self {
        firstCompletedOfSelfAndToken(token).onComplete(context) { res in
            token.context {
                if !token.isInvalid {
                    callback(self.result!)
                }
            }
        }
        return self
    }
    
    /// See `onSuccess(context c: ExecutionContext = DefaultThreadingModel(), callback: SuccessCallback) -> Future<T, E>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onSuccess(context: ExecutionContext = DefaultThreadingModel(), token: InvalidationTokenType, callback: SuccessCallback) -> Future<T, E> {
        firstCompletedOfSelfAndToken(token).onSuccess(context) { value in
            token.context {
                if !token.isInvalid {
                    callback(value)
                }
            }
        }
        
        return self
    }
    
    /// See `onFailure(context c: ExecutionContext = DefaultThreadingModel(), callback: FailureCallback) -> Future<T, E>`
    /// If the given invalidation token is invalidated when the future is completed, the given callback is not invoked
    public func onFailure(context: ExecutionContext = DefaultThreadingModel(), token: InvalidationTokenType, callback: FailureCallback) -> Future<T, E> {
        firstCompletedOfSelfAndToken(token).onFailure(context) { error in
            token.context {
                if !token.isInvalid {
                    callback(self.result!.error!)
                }
            }
        }
        return self
    }
}