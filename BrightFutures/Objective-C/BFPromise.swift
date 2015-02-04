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

@objc public class BFPromise : NSObject {
    
    private let promise: Promise<AnyObject>
    
    public var future: BFFuture {
        return bridge(self.promise.future)
    }
    
    public override init() {
        self.promise = Promise<AnyObject>()
    }
    
    public func completeWith(future: BFFuture) {
        self.promise.completeWith(bridge(future))
    }
    
    public func success(value: AnyObject) {
        self.promise.success(value)
    }
    
    public func trySuccess(value: AnyObject) -> Bool {
        return self.promise.trySuccess(value)
    }
    
    public func failure(error: NSError) {
        self.promise.failure(error)
    }
    
    public func tryFailure(error: NSError) -> Bool {
        return self.promise.tryFailure(error)
    }
    
    public func complete(result: BFResult) {
        return self.promise.complete(bridge(result))
    }
    
    public func tryComplete(result: BFResult) -> Bool {
        return self.promise.tryComplete(bridge(result))
    }
}