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
