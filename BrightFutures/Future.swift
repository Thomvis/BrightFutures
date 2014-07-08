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

class Future<T> {
    typealias CallbackInternal = (future: Future<T>) -> ()
    typealias CompletionCallback = (result: TaskResult<T>) -> ()
    typealias SuccessCallback = (T) -> ()
    typealias FailureCallback = (NSError) -> ()
    
    let q = Queue()
    
    var result = TaskResult<T>()
    
    var value: T? {
        switch result.state {
        case .Success:
            return result.value as? T
        default:
            return nil
        }
    }
    
    var error: NSError? {
        switch result.state {
        case .Failure:
            return result.error
        default:
            return nil
        }
    }
    
    var callbacks: [CallbackInternal] = Array<CallbackInternal>()
    
    let defaultCallbackExecutionContext = QueueExecutionContext()
    
    class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = TaskResult(value: value)
        
        return res
    }
    
    class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = TaskResult(error: error)
        
        return res
    }
    
    // TODO: private
    func complete(result: TaskResult<T>) {
        if !tryComplete(result) {
            
        }
    }
    
    // TODO: private
    func tryComplete(result: TaskResult<T>) -> Bool {
        switch result {
        case let res where res.state == State.Success:
            return self.trySuccess(res.value!)
        default:
            if let certainError = result.error {
                return self.tryError(certainError)
            } else {
                return self.tryError(NSError.errorWithDomain("domain", code: 1, userInfo: nil));
            }
        }
    }
    
    // TODO: private
    func success(value: T) {
        self.trySuccess(value)
    }
    
    // TODO: private
    func trySuccess(value: T) -> Bool {
        return (q.sync {
            if self.result.state != .Pending {
                return false;
            }
            
            self.result = TaskResult(value: value)
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
            if self.result.state != .Pending {
                return false;
            }
            
            self.result = TaskResult(error: error)
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
                future.callbackExecutionContext(c).execute {
                    callback(result: self.result)
                }
            }
            
            if self.result.state == .Pending {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
    }
    
    func andThen<U>(callback: TaskResult<T> -> Future<U>) -> Future<U> {
        return self.andThen(context: self.defaultCallbackExecutionContext, callback: callback)
    }
    
    func andThen<U>(context c: ExecutionContext, callback: TaskResult<T> -> Future<U>) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c) { result in
            let subFuture = callback(result)
            p.completeWith(subFuture)
        }

        return p.future
    }
    
    func andThen<U>(callback: TaskResult<T> -> U) -> Future<U> {
        return self.andThen(context: self.defaultCallbackExecutionContext, callback: callback)
    }
    
    func andThen<U>(context c: ExecutionContext, callback: TaskResult<T> -> U) -> Future<U> {
        return self.andThen(context: c) { result -> Future<U> in
            return Future<U>.succeeded(callback(result))
        }
    }
    
    func onSuccess(callback: SuccessCallback) {
        self.onSuccess(context: self.defaultCallbackExecutionContext, callback)
    }
    
    func onSuccess(context c: ExecutionContext, callback: SuccessCallback) {
        self.onComplete(context: c) { result in
            if !result.error {
                callback(result.value!)
            }
        }
    }
    
    func onFailure(callback: FailureCallback) {
        self.onFailure(context: self.defaultCallbackExecutionContext, callback)
    }
    
    func onFailure(context c: ExecutionContext, callback: FailureCallback) {
        self.onComplete(context: c) { result in
            if result.error {
                callback(result.error!)
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
            if result.error {
                p.completeWith(task(result.error!))
            } else {
                p.completeWith(self)
            }
        }
        
        return p.future;
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
    
    // TODO: private
    func callbackExecutionContext(context: ExecutionContext?) -> ExecutionContext {
        if let givenContext = context {
            return givenContext
        } else {
            return self.defaultCallbackExecutionContext
        }
    }
}

enum State {
    case Pending, Success, Failure
}

struct TaskResult<T> { // should be generic, but compiler issues prevent this
    let state: State
    let value: T?
    let error: NSError?
    
    init() {
        self.state = .Pending
        self.value = nil
        self.error = nil
    }
    
    init(value: T?) {
        self.state = .Success
        self.value = value
        self.error = nil
    }
    
    init (error: NSError) {
        self.state = .Failure
        self.value = nil
        self.error = error
    }
    
}