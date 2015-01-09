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

public class Promise<T> {

    public let future: Future<T>
    
    public init() {
        self.future = Future<T>()
    }
    
    public func completeWith(future: Future<T>) {
        future.onComplete { result in
            switch result {
            case .Success(let val):
                self.success(val.value)
            case .Failure(let err):
                self.failure(err)
            }
        }
    }
    
    public func success(value: T) {
        self.future.success(value)
    }
    
    public func trySuccess(value: T) -> Bool {
        return self.future.trySuccess(value)
    }
    
    public func failure(error: NSError) {
        self.future.failure(error)
    }
    
    public func tryFailure(error: NSError) -> Bool {
        return self.future.tryFailure(error)
    }
    
    public func complete(result: Result<T>) {
        return self.future.complete(result)
    }
    
    public func tryComplete(result: Result<T>) -> Bool {
        return self.future.tryComplete(result)
    }
    
}