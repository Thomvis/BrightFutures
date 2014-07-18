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

func future<T>(context c: ExecutionContext = Queue.global, task: (inout NSError?) -> T?) -> Future<T> {
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

func future<T>(context c: ExecutionContext = Queue.global, task: @auto_closure () -> T?) -> Future<T> {
    return future(context: c) { error in
        return task()
    }
}

let NoSuchElementError = "NoSuchElementError"

class Future<T> {
    
    typealias CallbackInternal = (future: Future<T>) -> ()
    typealias CompletionCallback = (result: TaskResult<T>) -> ()
    typealias SuccessCallback = (T) -> ()
    typealias FailureCallback = (NSError) -> ()
    
    let q = Queue()
    
    var result: TaskResult<T>? = nil
    
    var callbacks: [CallbackInternal] = Array<CallbackInternal>()
    
    let defaultCallbackExecutionContext = Queue()
    
    func succeeded(fn: (T -> ())? = nil) -> Bool {
        if let res = self.result {
            return res.succeeded(fn)
        }
        return false
    }
    
    func failed(fn: (NSError -> ())? = nil) -> Bool {
        if let res = self.result {
            return res.failed(fn)
        }
        return false
    }
    
    func completed(success: (T->())? = nil, failure: (NSError->())? = nil) -> Bool{
        if let res = self.result {
            res.handle(success: success, failure: failure)
            return true
        }
        return false
    }
    
    class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = TaskResult(value)
        
        return res
    }
    
    class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = TaskResult(error)
        
        return res
    }
    
    class func never() -> Future<T> {
        return Future<T>()
    }
    
    // TODO: private
    func complete(result: TaskResult<T>) {
        if !tryComplete(result) {
            
        }
    }
    
    // TODO: private
    func tryComplete(result: TaskResult<T>) -> Bool {
        switch result {
        case .Success(let val):
            return self.trySuccess(val)
        case .Failure(let err):
            return self.tryError(err)
        }
    }
    
    // TODO: private
    func success(value: T) {
        self.trySuccess(value)
    }
    
    // TODO: private
    func trySuccess(value: T) -> Bool {
        return q.sync {
            if self.result {
                return false;
            }
            
            self.result = TaskResult(value)
            self.runCallbacks()
            return true;
        };
    }
    
    // TODO: private
    func error(error: NSError) {
        if !self.tryError(error) {

        }
    }
    
    // TODO: private
    func tryError(error: NSError) -> Bool {
        return q.sync {
            if self.result {
                return false;
            }
            
            self.result = TaskResult(error)
            self.runCallbacks()
            return true;
        };
    }

    func forced() -> TaskResult<T> {
        return forced(DISPATCH_TIME_FOREVER)
    }

    func forced(time: dispatch_time_t) -> TaskResult<T> {
        if let certainResult = self.result {
            return certainResult
        } else {
            let sema = dispatch_semaphore_create(0)
            var res: TaskResult<T>? = nil
            self.onComplete {
                res = $0
                dispatch_semaphore_signal(sema)
            }
            dispatch_semaphore_wait(sema, time)
            return res!
        }
    }
    
    func onComplete(callback: CompletionCallback) {
        self.onComplete(context: self.defaultCallbackExecutionContext, callback: callback)
    }
    
    func onComplete(context c: ExecutionContext, callback: CompletionCallback) {
        q.sync {
            let wrappedCallback : Future<T> -> () = { future in
                if let realRes = self.result {
                    c.execute {
                        callback(result: realRes)
                    }
                }
            }
            
            if !self.result {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
    }

    func map<U>(f: (T, inout NSError?) -> U?) -> Future<U> {
        return self.map(context: self.defaultCallbackExecutionContext, f)
    }

    func map<U>(context c: ExecutionContext, f: (T, inout NSError?) -> U?) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result {
            case .Success(let v):
                var err: NSError? = nil
                let res = f(v, &err)
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

    func andThen(callback: TaskResult<T> -> ()) -> Future<T> {
        return self.andThen(context: self.defaultCallbackExecutionContext, callback: callback)
    }

    func andThen(context c: ExecutionContext, callback: TaskResult<T> -> ()) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result in
            callback(result)
            p.completeWith(self)
        }

        return p.future
    }
    
    func onSuccess(callback: SuccessCallback) {
        self.onSuccess(context: self.defaultCallbackExecutionContext, callback)
    }
    
    func onSuccess(context c: ExecutionContext, callback: SuccessCallback) {
        self.onComplete(context: c) { result in
            switch result {
            case .Success(let val):
                callback(val)
            default:
                break
            }
        }
    }
    
    func onFailure(callback: FailureCallback) {
        self.onFailure(context: self.defaultCallbackExecutionContext, callback)
    }
    
    func onFailure(context c: ExecutionContext, callback: FailureCallback) {
        self.onComplete(context: c) { result in
            switch result {
            case .Failure(let err):
                callback(err)
            default:
                break
            }
        }
    }
    
    func recover(task: (NSError) -> T) -> Future<T> {
        return self.recover(context: self.defaultCallbackExecutionContext, task)
    }
    
    func recover(context c: ExecutionContext, task: (NSError) -> T) -> Future<T> {
        return self.recoverWith(context: c) { error -> Future<T> in
            return Future.succeeded(task(error))
        }
    }
    
    func recoverWith(task: (NSError) -> Future<T>) -> Future<T> {
        return self.recoverWith(context: self.defaultCallbackExecutionContext, task: task)
    }
    
    func recoverWith(context c: ExecutionContext, task: (NSError) -> Future<T>) -> Future<T> {
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
    
    func zip<U>(that: Future<U>) -> Future<(T,U)> {
        let p = Promise<(T,U)>()
        self.onComplete { thisResult in
            switch thisResult {
                case .Success(let thisValue):
                    that.onComplete { thatResult in
                        switch thatResult {
                        case .Success(let thatValue):
                            let combinedResult: (T,U) = (thisValue, thatValue)
                            p.success(combinedResult)
                        case .Failure(let thatError):
                            p.error(thatError)
                        }
                    }
                    break
                case .Failure(let thisError):
                    p.error(thisError)
            }

        }
        return p.future
    }
    
    func filter(p: T -> Bool) -> Future<T> {
        let promise = Promise<T>()
        
        self.onComplete { result in
            switch result {
            case .Success(let val):
                if p(val) {
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
    
    // TODO: private
    func runCallbacks() {
        q.async {
            for callback in self.callbacks {
                callback(future: self)
            }
            
            self.callbacks.removeAll()
        }
    }
}

class TaskResultValueWrapper<T> {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    func __conversion() -> T {
        return self.value
    }
}

func ==<T: Equatable>(lhs: TaskResultValueWrapper<T>, rhs: T) -> Bool {
    return lhs.value == rhs
}

enum TaskResult<T> {
    case Success(TaskResultValueWrapper<T>)
    case Failure(NSError)
    
    init(_ value: T) {
        self = .Success(TaskResultValueWrapper(value))
    }
    
    init(_ error: NSError) {
        self = .Failure(error)
    }
    
    func failed(fn: (NSError -> ())? = nil) -> Bool {
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
    
    func succeeded(fn: (T -> ())? = nil) -> Bool {
        switch self {
        case .Success(let val):
            if let fnn = fn {
                fnn(val)
            }
            return true
        case .Failure(let err):
            return false
        }
    }
    
    func handle(success: (T->())? = nil, failure: (NSError->())? = nil) {
        switch self {
        case .Success(let val):
            if let successCb = success {
                successCb(val)
            }
        case .Failure(let err):
            if let failureCb = failure {
                failureCb(err)
            }
        }
    }
}

