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
    
    public init(_ value: T) {
        self.value = value
    }
}

/**
A result represents a result from a future.

- Success: Indicates that the future completed with success.
- Failure: Indicates that the future completed with failure.
*/
public enum Result<T> {
    case Success(Box<T>)
    case Failure(NSError)
    
    public init(_ value: T) {
        self = .Success(Box(value))
    }
    
    /// True if this result is a success, false otherwise.
    public var isSuccess: Bool {
        get {
            switch self {
            case .Success(_):
                return true
            case .Failure(_):
                return false
            }
        }
    }
    
    /// True if this result is a failure, false otherwise.
    public var isFailure: Bool {
        get {
            return !self.isSuccess
        }
    }
    
    /// The success value or nil in case of failure.
    public var value: T? {
        get {
            switch self {
            case .Success(let boxedValue):
                return boxedValue.value
            default:
                return nil
            }
        }
    }
    
    /// The failure error or nil in case of success.
    public var error: NSError? {
        get {
            switch self {
            case .Failure(let error):
                return error
            default:
                return nil
            }
        }
    }
}
