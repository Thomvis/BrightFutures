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

func future<T>(task: (inout NSError?) -> T, executionContext: ExecutionContext = QueueExecutionContext()) -> Future<T> {
    var promise = Promise<T>();
    
    executionContext.execute {
        var error: NSError?
        let result = task(&error)
        
        if let certainError = error {
            promise.error(certainError)
        } else {
            promise.success(result)
        }
    }
    
    return promise.future
}

class Future<T> {
    typealias Callback = (future: Future<T>) -> ()

    let q = Queue()
    
    var result = TaskResult()
    
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
    
    var callbacks: Array<Callback> = Array<Callback>()
    
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
    func complete(result: TaskResult) {
        if !tryComplete(result) {
            
        }
    }
    
    // TODO: private
    func tryComplete(result: TaskResult) -> Bool {
        switch result {
        case let res where res.state == State.Success:
            return self.trySuccess(res.value as T)
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
    
    func onComplete(callback: (value:T?, error: NSError?) -> (), executionContext: ExecutionContext? = nil) {
        q.sync {
            let wrappedCallback : Future<T> -> () = { future in
                future.callbackExecutionContext(executionContext).execute {
                    callback(value: future.value, error: future.result.error)
                }
            }
            
            if self.result.state == .Pending {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
    }
    
    func andThen<U>(callback: (value:T?, error: NSError?) -> Future<U>, executionContext: ExecutionContext? = nil) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete({ (value, error) in
            let subFuture = callback(value: value, error: error)
            p.completeWith(subFuture)
        }, executionContext: executionContext)

        return p.future
    }
    
    func andThen<U>(callback: (value:T?, error: NSError?) -> U, executionContext: ExecutionContext? = nil) -> Future<U> {
        return self.andThen({ value, error in
            return Future<U>.succeeded(callback(value: value, error: error))
        }, executionContext: executionContext)
    }
    
    func onSuccess(callback: T -> (), executionContext: ExecutionContext? = nil) {
        self.onComplete({ (value, error) in
            if !error {
                callback(value!)
            }
        }, executionContext: executionContext)
    }
    
    func onFailure(callback: NSError -> (), executionContext: ExecutionContext? = nil) {
        self.onComplete({ (value, error) in
            if error {
                callback(error!)
            }
        }, executionContext: executionContext)
    }
    
    func recover(task: (NSError) -> T, executionContext exec: ExecutionContext = QueueExecutionContext()) -> Future<T> {
        return self.recoverWith({ error -> Future<T> in
            return Future.succeeded(task(error))
        }, executionContext: exec)
    }
    
    func recoverWith(task: (NSError) -> Future<T>, executionContext exec: ExecutionContext = QueueExecutionContext()) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete({ (value, error) -> () in
            if error {
                p.completeWith(task(error!))
            } else {
                p.completeWith(self)
            }
            }, executionContext: exec)
        
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

struct TaskResult { // should be generic, but compiler issues prevent this
    let state: State
    let value: Any?
    let error: NSError?
    
    init() {
        self.state = .Pending
        self.value = nil
        self.error = nil
    }
    
    init(value: Any?) {
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