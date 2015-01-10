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

    /// The future that will be completed by this promise.
    public let future: Future<T>
    
    public init() {
        self.future = Future<T>()
    }
    
    /**
    Completes the promise's future on completion of the given future.
    
    When the given future completes, this promise's future will be completed
    using the result of the given future.
    
    :param: future The future to use for completion.
    */
    public func completeWith(future: Future<T>) {
        future.onComplete { result in
            switch result {
            case .Success(let val):
                self.success(val.value)
            case .Failure(let err):
                self.error(err)
            }
        }
    }

    /**
    Completes the promise's future as success with the given value.
    If the future was already completed, an assertion will be raised.
    
    :param: value The value to complete the future with.
    */
    public func success(value: T) {
        self.future.success(value)
    }
    
    /**
    Completes the promise's future as success with the given error.
    
    :param: value The value to complete the future with.
    
    :returns: False if the future was already completed, true otherwise.
    */
    public func trySuccess(value: T) -> Bool {
        return self.future.trySuccess(value)
    }

    /**
    Completes the promise's future as failed with the given error.
    If the future was already completed, an assertion will be raised.
    
    :param: value The error to complete the future with.
    */
    public func error(error: NSError) {
        self.future.error(error)
    }
    
    /**
    Completes the promise's future as failed with the given error.
    
    :param: error The error to complete the future with.
    
    :returns: False if the future was already completed, true otherwise.
    */
    public func tryError(error: NSError) -> Bool {
        return self.future.tryError(error)
    }
    
    /**
    Completes the promise's future with the given result.
    
    :param: result The result to complete the future with.
    
    :returns: False if the future was already completed, true otherwise.
    */
    public func tryComplete(result: Result<T>) -> Bool {
        return self.future.tryComplete(result)
    }
    
}