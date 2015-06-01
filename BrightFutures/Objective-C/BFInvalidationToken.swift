//
//  BFInvalidationToken.swift
//  BrightFutures
//
//  Created by Thomas Visser on 23/03/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

@objc public protocol BFInvalidationTokenType {
    var isInvalid : Bool { get }
    
    var future: BFFuture { get }
    
    var context: BFExecutionContext { get }
}

@objc public protocol BFManualInvalidationTokenType : BFInvalidationTokenType {
    func invalidate()
}

@objc public class BFInvalidationToken : NSObject, BFManualInvalidationTokenType {
    
    private let token: InvalidationToken
    
    internal init(token: InvalidationToken) {
        self.token = token
    }
    
    public override convenience init() {
        self.init(token: InvalidationToken())
    }
    
    public var context: BFExecutionContext {
        return bridge(token.context)
    }
    
    public var isInvalid: Bool {
        return token.isInvalid
    }
    
    public var future: BFFuture {
        return bridge(token.future)
    }
    
    public func invalidate() {
        token.invalidate()
    }
}

func bridge(token: InvalidationToken) -> BFInvalidationToken {
    return BFInvalidationToken(token: token)
}

func bridge(token: BFInvalidationTokenType) -> InvalidationTokenType {
    
    class _InvalidationToken: InvalidationTokenType {
        private let token: BFInvalidationTokenType
        
        private init(token: BFInvalidationTokenType) {
            self.token = token
        }
        
        private var context: ExecutionContext {
            return bridge(token.context)
        }
        
        private var future: Future<NoValue, BrightFuturesError<NoError>> {
            return bridge(token.future).forceType()
        }
        
        private var isInvalid: Bool {
            return token.isInvalid
        }
    }
    
    return _InvalidationToken(token: token)
}