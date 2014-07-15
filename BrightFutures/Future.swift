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

func future<T>(context c: ExecutionContext = QueueExecutionContext.global, task: (inout NSError?) -> T?) -> Future<T> {
    let promise = Promise<T>();
    
    c.execute {
        var error: NSError?
        let result = task(&error)
        
        if let certainError = error {
            promise.error(certainError)
        } else {
            promise.success(result!)
        }
    }

    return promise.future
}

func future<T>(context c: ExecutionContext = QueueExecutionContext.global, task: @auto_closure () -> T?) -> Future<T> {
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
    
    var result: TaskState<T> = .Pending
    
    var value: T? {
        switch result {
        case .Done(.Success(let v)):
            return v()
        default:
            return nil
        }
    }
    
    var error: NSError? {
        switch result {
        case .Done(.Failure(let e)):
            return e
        default:
            return nil
        }
    }

    var forced: TaskResult<T> {
        let sema = dispatch_semaphore_create(0)
        var res: TaskResult<T>? = nil
        self.onComplete {
            res = $0
            dispatch_semaphore_signal(sema)
        }
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER)
        return res!
    }

    var callbacks: [CallbackInternal] = Array<CallbackInternal>()
    
    let defaultCallbackExecutionContext = QueueExecutionContext()

    class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = .Done(.Success(value))
        
        return res
    }
    
    class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = .Done(.Failure(error))
        
        return res
    }
    
    // TODO: private
    func complete(result: TaskState<T>) {
        if !tryComplete(result) {
            
        }
    }
    
    // TODO: private
    func tryComplete(result: TaskState<T>) -> Bool {
        switch result {
        case .Done(.Success(let v)):
            return self.trySuccess(v())
        case .Done(.Failure(let e)):
            return self.tryError(e)
        case .Pending:
            assert(false)
            return false
        }
    }
    
    // TODO: private
    func success(value: T) {
        self.trySuccess(value)
    }
    
    // TODO: private
    func trySuccess(value: T) -> Bool {
        return (q.sync {
            switch (self.result) {
            case .Pending:
                break
            case .Done(_):
                return false;
            }

            self.result = .Done(.Success(value))
            self.runCallbacks()
            return true;
        })!;
    }
    
    // TODO: private
    func error(error: NSError) {
        if !self.tryError(error) {

        }
    }
    
    // TODO: private
    func tryError(error: NSError) -> Bool {
        return (q.sync {
            switch (self.result) {
            case .Pending:
                break
            case .Done(_):
                return false
            }

            self.result = .Done(.Failure(error))
            self.runCallbacks()
            return true;
        })!;
    }
    
    func onComplete(callback: CompletionCallback) {
        self.onComplete(context: self.defaultCallbackExecutionContext, callback: callback)
    }
    
    func onComplete(context c: ExecutionContext, callback: CompletionCallback) {
        q.sync {
            let wrappedCallback : Future<T> -> () = { future in
                c.execute { _ in
                    switch(self.result) {
                    case .Done(let res):
                        callback(result: res)
                    case .Pending:
                        assert(false)
                        break
                    }
                }
            }

            switch (self.result) {
            case .Pending:
                self.callbacks.append(wrappedCallback)
            case .Done(_):
                wrappedCallback(self)
            }
        }
    }

    func map<U>(f: T -> U) -> Future<U> {
        return self.map(context: self.defaultCallbackExecutionContext, f)
    }
    
    func map<U>(context c: ExecutionContext, f: T -> U) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result {
            case .Success(let v):
                p.success(f(v()))
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
            switch (result) {
            case .Success(let v):
                callback(v())
            case .Failure(_):
                break
            }
        }
    }
    
    func onFailure(callback: FailureCallback) {
        self.onFailure(context: self.defaultCallbackExecutionContext, callback)
    }
    
    func onFailure(context c: ExecutionContext, callback: FailureCallback) {
        self.onComplete(context: c) { result in
            switch (result) {
            case .Failure(let e):
                callback(e)
            case .Success(_):
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
            switch (result) {
            case .Failure(let e):
                p.completeWith(task(e))
            case .Success(_):
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
                            let combinedResult = (thisValue(), thatValue())
                            p.success(combinedResult)
                            break
                        case .Failure(let error):
                            p.error(error)
                            break
                        }
                    }
                    break
                case .Failure(let error):
                    p.error(error)
                    break
                
            }

        }
        return p.future
    }
    
    func filter(p: T -> Bool) -> Future<T> {
        let promise = Promise<T>()
        
        self.onComplete { result in
            switch result {
            case .Success(let v):
                if p(v()) {
                    promise.completeWith(self)
                } else {
                    promise.error(NSError(domain: NoSuchElementError, code: 0, userInfo: nil))
                }
                break
            case .Failure(let e):
                promise.error(e)
                break
            }
        }
        
        return promise.future
    }

    class func foreach<U>(seq: SequenceOf<Future<U>>, pf: U -> ()) {

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

enum TaskState<T> {
    case Pending
    case Done(TaskResult<T>)
}

enum TaskResult<T> {
    // workaround for not having nested generic enums yet
    case Success(@auto_closure () -> T)
    case Failure(NSError)
}