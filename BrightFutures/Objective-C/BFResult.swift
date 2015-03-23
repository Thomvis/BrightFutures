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
 * An Objective-C compatible Result
 *
 * This is a reimplementation, rather than a compatibility 
 * layer because it would result in approximately the same 
 * amount of code.
 */
@objc public class BFResult {
    
    internal let success: Bool
    public let value: AnyObject?
    public let error: NSError?
    
    public var isSuccess: Bool {
        return success
    }
    
    public var isFailure: Bool {
        return !self.isSuccess
    }
    
    public class func success(value: AnyObject?) -> BFResult {
        return BFResult(value: value)
    }
    
    public class func failure(error: NSError) -> BFResult {
        return BFResult(error: error)
    }
    
    public init(value: AnyObject?) {
        self.value = value
        self.success = true
        self.error = nil;
    }

    public init(error: NSError) {
        self.error = error
        self.success = false
        self.value = nil;
    }
}

func bridge(result: Result<AnyObject?>) -> BFResult {
    return bridge(result)!
}

func bridge(optionalResult: Result<AnyObject?>?) -> BFResult? {
    if let res = optionalResult {
        switch res {
        case .Success(let boxedValue):
            return BFResult(value: boxedValue.value)
        case .Failure(let error):
            return BFResult(error: error)
        }
    }
    
    return nil
}

func bridge(result: BFResult) -> Result<AnyObject?> {
    if result.isSuccess {
        return Result.Success(Box(result.value))
    }
    return Result.Failure(result.error!)
}

func bridge<T>(f: T -> BFResult) -> (T -> Result<AnyObject?>) {
    return { param in
        bridge(f(param))
    }
}

func bridge(f: BFResult -> ()) -> (Result<AnyObject?> -> ()) {
    return { res in
        f(bridge(res))
    }
}
