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

public func future<T>(context c: ExecutionContext = Queue.global, task: (inout NSError?) -> T?) -> Future<T> {
    let promise = Promise<T>();
    
    c.execute {
        var error: NSError?
        let result = task(&error)
        
        if let certainError = error {
            promise.error(certainError)
        } else if let certainResult = result {
            promise.success(certainResult)
        }
    }
    
    return promise.future
}

public func future<T>(context c: ExecutionContext = Queue.global, task: @autoclosure () -> T?) -> Future<T> {
    return future(context: c) { error in
        return task()
    }
}

public let NoSuchElementError = "NoSuchElementError"

public class Future<T> {
    
    typealias CallbackInternal = (future: Future<T>) -> ()
    typealias CompletionCallback = (result: Result<T>) -> ()
    typealias SuccessCallback = (T) -> ()
    public typealias FailureCallback = (NSError) -> ()
    
    let q = Queue()
    
    var result: Result<T>? = nil
    
    var callbacks: [CallbackInternal] = Array<CallbackInternal>()
    
    let defaultCallbackExecutionContext = Queue()
    
    public func succeeded(fn: (T -> ())? = nil) -> Bool {
        if let res = self.result {
            return res.succeeded(fn)
        }
        return false
    }
    
    public func failed(fn: (NSError -> ())? = nil) -> Bool {
        if let res = self.result {
            return res.failed(fn)
        }
        return false
    }
    
    public func completed(success: (T->())? = nil, failure: (NSError->())? = nil) -> Bool{
        if let res = self.result {
            res.handle(success: success, failure: failure)
            return true
        }
        return false
    }
    
    public class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = Result(value)
        
        return res
    }
    
    public class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = Result(error)
        
        return res
    }
    
    public class func completeAfter(delay: NSTimeInterval, withValue value: T) -> Future<T> {
        let res = Future<T>()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC))), Queue.global.queue) {
            res.success(value)
        }
        
        return res
    }
    
    /**
     * Returns a Future that will never succeed
     */
    public class func never() -> Future<T> {
        return Future<T>()
    }
    
    func complete(result: Result<T>) {
        let succeeded = tryComplete(result)
        assert(succeeded)
    }
    
    func tryComplete(result: Result<T>) -> Bool {
        switch result {
        case .Success(let val):
            return self.trySuccess(val.value)
        case .Failure(let err):
            return self.tryError(err)
        }
    }
    
    func success(value: T) {
        let succeeded = self.trySuccess(value)
        assert(succeeded)
    }
    
    func trySuccess(value: T) -> Bool {
        return q.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = Result(value)
            self.runCallbacks()
            return true;
        };
    }
    
    func error(error: NSError) {
        let succeeded = self.tryError(error)
        assert(succeeded)
    }
    
    func tryError(error: NSError) -> Bool {
        return q.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = Result(error)
            self.runCallbacks()
            return true;
        };
    }

    public func forced() -> Result<T> {
        return forced(Double.infinity)!
    }

    public func forced(time: NSTimeInterval) -> Result<T>? {
        if let certainResult = self.result {
            return certainResult
        } else {
            let sema = dispatch_semaphore_create(0)
            var res: Result<T>? = nil
            self.onComplete {
                res = $0
                dispatch_semaphore_signal(sema)
            }

            var timeout: dispatch_time_t
            if time.isFinite {
                timeout = dispatch_time(DISPATCH_TIME_NOW, Int64(time * NSTimeInterval(NSEC_PER_SEC)))
            } else {
                timeout = DISPATCH_TIME_FOREVER
            }
            
            dispatch_semaphore_wait(sema, timeout)
            
            return res
        }
    }
    
    public func onComplete(callback: CompletionCallback) -> Future<T> {
        return self.onComplete(context: self.defaultCallbackExecutionContext, callback: callback)
    }
    
    public func onComplete(context c: ExecutionContext, callback: CompletionCallback) -> Future<T> {
        q.sync {
            let wrappedCallback : Future<T> -> () = { future in
                if let realRes = self.result {
                    c.execute {
                        callback(result: realRes)
                    }
                }
            }
            
            if self.result == nil {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
        
        return self
    }

    public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
        return self.flatMap(context: self.defaultCallbackExecutionContext, f)
    }

    public func flatMap<U>(context c: ExecutionContext, f: T -> Future<U>) -> Future<U> {
        let p: Promise<U> = Promise()
        self.onComplete(context: c) { res in
            switch (res) {
            case .Failure(let e):
                p.error(e)
            case .Success(let v):
                p.completeWith(f(v.value))
            }
        }
        return p.future
    }

    public func map<U>(f: (T, inout NSError?) -> U?) -> Future<U> {
        return self.map(context: self.defaultCallbackExecutionContext, f)
    }

    public func map<U>(context c: ExecutionContext, f: (T, inout NSError?) -> U?) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result {
            case .Success(let v):
                var err: NSError? = nil
                let res = f(v.value, &err)
                if let e = err {
                    p.error(e)
                } else {
                    p.success(res!)
                }
                break;
            case .Failure(let e):
                p.error(e)
                break;
            }
        })
        
        return p.future
    }

    public func andThen(callback: Result<T> -> ()) -> Future<T> {
        return self.andThen(context: self.defaultCallbackExecutionContext, callback: callback)
    }

    public func andThen(context c: ExecutionContext, callback: Result<T> -> ()) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result in
            callback(result)
            p.completeWith(self)
        }

        return p.future
    }

    public func onSuccess(callback: SuccessCallback) -> Future<T> {
        return self.onSuccess(context: self.defaultCallbackExecutionContext, callback)
    }
    
    public func onSuccess(context c: ExecutionContext, callback: SuccessCallback) -> Future<T> {
        self.onComplete(context: c) { result in
            switch result {
            case .Success(let val):
                callback(val.value)
            default:
                break
            }
        }
        
        return self
    }
    
    public func onFailure(callback: FailureCallback) -> Future<T> {
        return self.onFailure(context: self.defaultCallbackExecutionContext, callback)
    }
    
    public func onFailure(context c: ExecutionContext, callback: FailureCallback) -> Future<T> {
        self.onComplete(context: c) { result in
            switch result {
            case .Failure(let err):
                callback(err)
            default:
                break
            }
        }
        return self
    }
    
    public func recover(task: (NSError) -> T) -> Future<T> {
        return self.recover(context: self.defaultCallbackExecutionContext, task)
    }
    
    public func recover(context c: ExecutionContext, task: (NSError) -> T) -> Future<T> {
        return self.recoverWith(context: c) { error -> Future<T> in
            return Future.succeeded(task(error))
        }
    }
    
    public func recoverWith(task: (NSError) -> Future<T>) -> Future<T> {
        return self.recoverWith(context: self.defaultCallbackExecutionContext, task: task)
    }
    
    public func recoverWith(context c: ExecutionContext, task: (NSError) -> Future<T>) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result -> () in
            switch result {
            case .Failure(let err):
                p.completeWith(task(err))
            case .Success(let val):
                p.completeWith(self)
            }
        }
        
        return p.future;
    }
    
    public func zip<U>(that: Future<U>) -> Future<(T,U)> {
        return self.flatMap { thisVal in
            return that.map { thatVal, _ in
                return (thisVal, thatVal)
            }
        }
    }
    
    public func filter(p: T -> Bool) -> Future<T> {
        let promise = Promise<T>()
        
        self.onComplete { result in
            switch result {
            case .Success(let val):
                if p(val.value) {
                    promise.completeWith(self)
                } else {
                    promise.error(NSError(domain: NoSuchElementError, code: 0, userInfo: nil))
                }
                break
            case .Failure(let err):
                promise.error(err)
            }
        }
        
        return promise.future
    }
    
    private func runCallbacks() {
        q.async {
            for callback in self.callbacks {
                callback(future: self)
            }
            
            self.callbacks.removeAll()
        }
    }
}
