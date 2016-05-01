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
import Result

/// An enum representing every possible error for errors returned by BrightFutures
/// A `BrightFuturesError` can also wrap an external error (e.g. coming from a user defined future)
/// in its `External` case. `BrightFuturesError` has the type of the external error as its generic parameter.
public enum BrightFuturesError<E: ErrorType>: ErrorType {
    
    /// Indicates that a matching element could not be found, e.g. while filtering or finding
    case NoSuchElement
    
    /// Used in the implementation of InvalidationToken
    case InvalidationTokenInvalidated
    
    /// Indicates that an invalid / unexpected state was reached. This error is used in places that should not be executed
    case IllegalState
    
    /// Wraps a different ErrorType instance
    case External(E)

    /// Constructs a BrightFutures.External with the given external error
    public init(external: E) {
        self = .External(external)
    }
}

/// Returns `true` if `left` and `right` are both of the same case ignoring .External associated value 
public func ==<E: Equatable>(lhs: BrightFuturesError<E>, rhs: BrightFuturesError<E>) -> Bool {
    switch (lhs, rhs) {
    case (.NoSuchElement, .NoSuchElement): return true
    case (.InvalidationTokenInvalidated, .InvalidationTokenInvalidated): return true
    case (.External(let lhs), .External(let rhs)): return lhs == rhs
    default: return false
    }
}

/// Returns `true` if `left` and `right` are both of the same case ignoring .External associated value
public func ==(lhs: BrightFuturesError<NoError>, rhs: BrightFuturesError<NoError>) -> Bool {
    switch (lhs, rhs) {
    case (.NoSuchElement, .NoSuchElement): return true
    case (.InvalidationTokenInvalidated, .InvalidationTokenInvalidated): return true
    case (.External(_), .External(_)): return true // this cannot happen because NoError cannot be instantiated
    default: return false
    }
}
