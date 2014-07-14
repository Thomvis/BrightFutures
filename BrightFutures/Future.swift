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
        assert(result.value || result.error)
        
        switch result.state {
        case State.Success:
            return self.trySuccess(result.value!)
        default:
            return self.tryError(result.error!)
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
                c.execute {
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
    
    func map<U>(f: T -> U) -> Future<U> {
        return self.map(context: self.defaultCallbackExecutionContext, f)
    }
    
    func map<U>(context c: ExecutionContext, f: T -> U) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result.state {
            case .Success:
                p.success(f(result.value!))
                break;
            default:
                p.error(result.error!)
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
    
    func zip<U>(that: Future<U>) -> Future<(T,U)> {
        let p = Promise<(T,U)>()
        self.onComplete { thisResult in
            switch thisResult.state {
                case .Success:
                    that.onComplete { thatResult in
                        switch thatResult.state {
                        case .Success:
                            let combinedResult = (thisResult.value!, thatResult.value!)
                            p.success(combinedResult)
                            break
                        default:
                            p.error(thatResult.error!)
                            break
                        }
                    }
                    break
                default:
                    p.error(thisResult.error!)
                    break
                
            }

        }
        return p.future
    }
    
    func filter(p: T -> Bool) -> Future<T> {
        let promise = Promise<T>()
        
        self.onComplete { result in
            switch result.state {
            case .Success:
                if p(result.value!) {
                    promise.completeWith(self)
                } else {
                    promise.error(NSError(domain: NoSuchElementError, code: 0, userInfo: nil))
                }
                break
            default:
                promise.error(result.error!)
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