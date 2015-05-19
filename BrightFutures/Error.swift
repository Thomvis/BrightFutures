//
//  Error.swift
//  BrightFutures
//
//  Created by Thomas Visser on 14/05/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation
import Box

public protocol ErrorType {
    /// An NSError describing this error
    var nsError: NSError { get }
}

public enum NoError {}

extension NoError: ErrorType {
    public var nsError: NSError {
        fatalError("Impossible to construct NoError")
    }
}

extension NSError: ErrorType {
    public var nsError: NSError {
        return self
    }
}

public let BrightFuturesErrorDomain = "nl.thomvis.BrightFutures"

/// An enum representing every possible error code for errors returned by BrightFutures
public enum BrightFuturesError: ErrorType {
    
    case NoSuchElement
    case InvalidationTokenInvalidated
    case External(error: ErrorType)

    public var nsError: NSError {
        switch self {
        case .NoSuchElement:
            return NSError(domain: BrightFuturesErrorDomain, code: 0, userInfo: nil)
        case .InvalidationTokenInvalidated:
            return NSError(domain: BrightFuturesErrorDomain, code: 1, userInfo: nil)
        case .External(let error):
            return error.nsError
        }
    }

}