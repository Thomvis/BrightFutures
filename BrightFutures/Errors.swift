// The MIT License (MIT)
//
// Copyright (c) 2014 Thomas Visser
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Box

/// To be able to use a type as an error type with BrightFutures, it needs to conform
/// to this protocol.
public protocol ErrorType {
    /// An NSError describing this error
    var nsError: NSError { get }
}

/// Can be used as the value type of a `Future` or `Result` to indicate it can never fail.
/// This is guaranteed by the type system, because `NoError` has no possible values and thus cannot be created.
public class NoError {
    private init() {
        fatalError("impossible to instantiate NoError")
    }
}

/// Extends `NSError` to conform to `ErrorType`
extension NoError: ErrorType {
    
    /// From `ErrorType`: an NSError describing this error.
    /// Since `NoError` cannot be constructed, this property can also never be accessed.
    public var nsError: NSError {
        fatalError("Impossible to construct NoError")
    }
}

/// An extension of `NSError` to make it conform to `ErrorType`
extension NSError: ErrorType {
    
    /// From `ErrorType`: An NSError describing this error.
    /// Will return `self`.
    public var nsError: NSError {
        return self
    }
}

/// The name of the domain that will be used when returning `NSError` representations of `BrightFuturesError` instances
public let BrightFuturesErrorDomain = "nl.thomvis.BrightFutures"

/// An enum representing every possible error for errors returned by BrightFutures
/// A `BrightFuturesError` can also wrap an external error (e.g. coming from a user defined future)
/// in its `External` case. `BrightFuturesError` has the type of the external error as its generic parameter.
public enum BrightFuturesError<E: ErrorType>: ErrorType {
    
    case NoSuchElement
    case InvalidationTokenInvalidated
    case External(Box<E>)

    public init(external: E) {
        self = .External(Box(external))
    }
    
    /// From `ErrorType`: An NSError describing this error.
    public var nsError: NSError {
        switch self {
        case .NoSuchElement:
            return NSError(domain: BrightFuturesErrorDomain, code: 0, userInfo: nil)
        case .InvalidationTokenInvalidated:
            return NSError(domain: BrightFuturesErrorDomain, code: 1, userInfo: nil)
        case .External(let boxedError):
            return boxedError.value.nsError
        }
    }

}
