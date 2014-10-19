//
//  Result.swift
//  BrightFutures
//
//  Created by Thomas Visser on 19/10/14.
//  Copyright (c) 2014 Thomas Visser. All rights reserved.
//

import Foundation

/**
 * We have to box the Result value until Swift supports variable-layout enums
 */
public final class Box<T> {
    public let value: T
    
    init(_ value: T) {
        self.value = value
    }
}

public enum Result<T> {
    case Success(Box<T>)
    case Failure(NSError)
    
    init(_ value: T) {
        self = .Success(Box(value))
    }
    
    init(_ error: NSError) {
        self = .Failure(error)
    }
    
    public func failed(fn: (NSError -> ())? = nil) -> Bool {
        switch self {
        case .Success(_):
            return false
            
        case .Failure(let err):
            if let fnn = fn {
                fnn(err)
            }
            return true
        }
    }
    
    public func succeeded(fn: (T -> ())? = nil) -> Bool {
        switch self {
        case .Success(let val):
            if let fnn = fn {
                fnn(val.value)
            }
            return true
        case .Failure(let err):
            return false
        }
    }
    
    public func handle(success: (T->())? = nil, failure: (NSError->())? = nil) {
        switch self {
        case .Success(let val):
            if let successCb = success {
                successCb(val.value)
            }
        case .Failure(let err):
            if let failureCb = failure {
                failureCb(err)
            }
        }
    }
}
