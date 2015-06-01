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

@objc public class BFFuture {
    
    let future: Future<AnyObject?, NSError>
    
    internal convenience init() {
        self.init(future: Future<AnyObject?, NSError>())
    }
    
    internal init<E: ErrorType>(future: Future<AnyObject?, E>) {
        self.future = future.mapError { $0.nsError }
    }
}

public extension BFFuture {
    
    public class func wrap(f: () -> AnyObject?) -> BFFuture {
        return self.wrapResult {
            BFResult(value: f())
        }
    }
    
    public class func wrapResult(f: () -> BFResult) -> BFFuture {
        return self.wrapResult(context: BFExecutionContext.globalQueue, block: f)
    }
    
    public class func wrap(context c: BFExecutionContext, block: () -> AnyObject?) -> BFFuture {
        return self.wrapResult(context: c) {
            BFResult(value: block())
        }
    }
    
    public class func wrapResult(context c: BFExecutionContext, block: () -> BFResult) -> BFFuture {
        
        let p = Promise<AnyObject?, NSError>()
        
        c.context {
            p.complete(bridge(block()))
        }
        
        return bridge(p.future)
    }
    
}

public extension BFFuture {
    
    public var result: BFResult? {
        return bridge(self.future.result)
    }
    
    public var value: AnyObject? {
        return self.future.value!
    }
    
    public var error: NSError? {
        return self.future.error
    }
    
    public var isSuccess: Bool {
        return self.future.isSuccess
    }
    
    public var isFailure: Bool {
        return self.future.isFailure
    }
    
    public var isCompleted: Bool {
        return self.result != nil
    }
    
    public class func succeeded(value: AnyObject?) -> BFFuture {
        return bridge(Future<AnyObject?, NSError>.succeeded(value))
    }
    
    public class func failed(error: NSError) -> BFFuture {
        return bridge(Future<NoValue, NSError>.failed(error))
    }
    
    public class func completed(result: BFResult) -> BFFuture {
        return bridge(Future<AnyObject?, NSError>.completed(bridge(result)))
    }
    
    public class func completeAfter(delay: NSTimeInterval, withValue value: AnyObject?) -> BFFuture {
        return bridge(Future<AnyObject?, NSError>.completeAfter(delay, withValue: value))
    }
    
    public class func never() -> BFFuture {
        return BFFuture()
    }
    
}

public extension BFFuture {
    
    public func forced() -> BFResult? {
        return bridge(self.future.forced())
    }
    
    public func forced(timeout: NSTimeInterval) -> BFResult? {
        return bridge(self.future.forced(timeout))
    }
}

public extension BFFuture {
    
    public func onComplete(callback: (BFResult) -> ()) -> BFFuture {
        self.future.onComplete(callback: bridge(callback))
        return self
    }
    
    public func onComplete(context c: BFExecutionContext, callback: (BFResult) -> ()) -> BFFuture {
        self.future.onComplete(context: bridge(c), callback: bridge(callback))
        return self
    }
    
    public func onSuccess(callback: (AnyObject?) -> ()) -> BFFuture {
        self.future.onSuccess(callback: callback)
        return self
    }
    
    public func onSuccess(context c: BFExecutionContext, callback: (AnyObject?) -> ()) -> BFFuture {
        self.future.onSuccess(context: toContext(c), callback: callback)
        return self
    }
    
    public func onFailure(callback: (NSError) -> ()) -> BFFuture {
        self.future.onFailure(callback: callback)
        return self
    }
    
    public func onFailure(context c: BFExecutionContext, callback: (NSError) -> ()) -> BFFuture {
        self.future.onFailure(context: toContext(c), callback: callback)
        return self
    }
}

public extension BFFuture {
    
    public func flatMap(f: AnyObject? -> BFFuture) -> BFFuture {
        return bridge(self.future.flatMap(f: bridge(f)))
    }
    
    public func flatMap(context c: BFExecutionContext, f: AnyObject? -> BFFuture) -> BFFuture {
        return bridge(self.future.flatMap(context: toContext(c), f: bridge(f)))
    }
    
    public func flatMapResult(f: AnyObject? -> BFResult) -> BFFuture {
        return bridge(self.future.flatMap(f: bridge(f)))
    }
    
    public func flatMapResult(context c: BFExecutionContext, f: AnyObject? -> BFResult) -> BFFuture {
        return bridge(self.future.flatMap(context: toContext(c), f: bridge(f)))
    }
    
    public func map(f: AnyObject? -> AnyObject?) -> BFFuture {
        return bridge(self.future.map(f))
    }
    
    public func map(context c: BFExecutionContext, f: AnyObject? -> AnyObject?) -> BFFuture {
        return bridge(self.future.map(context: toContext(c), f: f))
    }
    
    public func andThen(callback: BFResult -> ()) -> BFFuture {
        return bridge(self.future.andThen(callback: bridge(callback)))
    }
    
    public func andThen(context c: BFExecutionContext, callback: BFResult -> ()) -> BFFuture {
        return bridge(self.future.andThen(context: toContext(c), callback: bridge(callback)))
    }
    
    public func recover(task: (NSError) -> AnyObject?) -> BFFuture {
        return bridge(self.future.recover(task: task))
    }
    
    public func recover(context c: BFExecutionContext, task: (NSError) -> AnyObject?) -> BFFuture {
        return bridge(self.future.recover(context: toContext(c), task: task))
    }
    
    public func recoverAsync(task: (NSError) -> BFFuture) -> BFFuture {
        return bridge(self.future.recoverWith(task: bridge(task)))
    }
    
    public func recoverAsync(context c: BFExecutionContext, task: (NSError) -> BFFuture) -> BFFuture {
        return bridge(self.future.recoverWith(context: bridge(c), task: bridge(task)))
    }
    
    // Returns an array with two elements instead of a tuple
    public func zip(that: BFFuture) -> BFFuture {
        return bridge(bridge(self.future.zip(bridge(that))))
    }
    
    public func filter(p: AnyObject? -> Bool) -> BFFuture {
        return bridge(self.future.filter(p))
    }
}

public extension BFFuture {
    
    public func onComplete(#token: BFInvalidationTokenType, callback: BFResult -> ()) -> BFFuture {
        self.future.onComplete(token: bridge(token), callback: bridge(callback))
        return self
    }
    
    public func onComplete(context c: BFExecutionContext, token: BFInvalidationTokenType, callback: BFResult -> ()) -> BFFuture {
        
        self.future.onComplete(context: bridge(c), token: bridge(token), callback: bridge(callback))
        return self
    }
    
    public func onSuccess(#token: BFInvalidationTokenType, callback: AnyObject? -> ()) -> BFFuture {
        self.future.onSuccess(token: bridge(token), callback: callback)
        return self
    }
    
    public func onSuccess(context c: BFExecutionContext, token: BFInvalidationTokenType, callback: AnyObject? -> ()) -> BFFuture {
        self.future.onSuccess(context: bridge(c), token: bridge(token), callback: callback)
        return self
    }
    
    public func onFailure(#token: BFInvalidationTokenType, callback: (NSError) -> ()) -> BFFuture {
        
        self.future.onFailure(token: bridge(token), callback: callback)
        return self
    }
    
    public func onFailure(context c: BFExecutionContext, token: BFInvalidationTokenType, callback: (NSError) -> ()) -> BFFuture {
        
        self.future.onFailure(context: bridge(c), token: bridge(token), callback: callback)
        return self
    }
}

func bridge<E: ErrorType>(future: Future<AnyObject?, E>) -> BFFuture {
    return BFFuture(future: future)
}

//func bridge<E: ErrorType>(future: Future<Void, E>) -> BFFuture {
//    return BFFuture(future: future)
//}

func bridge<E: ErrorType>(future: Future<NoValue, E>) -> BFFuture {
    let f1: Future<AnyObject?, E> = promoteValue(future)
    return BFFuture(future: f1)
}

func bridge(future: BFFuture) -> Future<AnyObject?, NSError> {
    return future.future
}

//func bridge(future: BFFuture) -> Future<Void, NSError> {
//    return future.future.map { _ -> Void in }
//}

func bridge<T>(f: T -> Future<AnyObject?, NSError>) -> (T -> BFFuture) {
    return { param in
        bridge(f(param))
    }
}

func bridge<T>(f: T -> BFFuture) -> (T -> Future<AnyObject?, NSError>) {
    return { param in
        bridge(f(param))
    }
}

func bridge<E>(future: Future<(AnyObject?,AnyObject?), E>) -> Future<AnyObject?, E> {
    return future.map { tuple in
        return [tuple.0 ?? NSNull(), tuple.1 ?? NSNull()]
    }
}
