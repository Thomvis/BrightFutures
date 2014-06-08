//
//  Future.swift
//  TVFutures
//
//  Created by Thomas Visser on 03/06/14.
//
//

import Foundation



func future<T: AnyObject>(task: (inout NSError?) -> T?, executionContext: ExecutionContext = defaultExecutionContext) -> Future<T> {
    var promise = Promise<T>();
    
    executionContext.execute {
        var error: NSError?
        let result = task(&error)
        
        if let certainError = error {
            promise.complete(TaskResult(error: certainError))
        } else {
            promise.complete(TaskResult(value: result))
        }
    }
    
    return promise.future
}

func future<T: AnyObject>(task: () -> T?, executionContext: ExecutionContext = defaultExecutionContext) -> Future<T> {
    
    let wrappedTask : (inout NSError?) -> T? = { error in
        return task()
    }
    
    return future(wrappedTask)
}

class Future<T: AnyObject> {
    typealias Callback = (future: Future<T>) -> ()

    let q = Queue()
    
    var result = TaskResult<T>()
    
    var callbacks: Array<Callback> = Array<Callback>()
    
    class func succeeded(value: T?) -> Future<T> {
        let res = Future<T>();
        res.result = TaskResult(value: value)
        
        return res
    }
    
    class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = TaskResult(error: error)
        
        return res
    }
    
    func complete(result: TaskResult<T>) {
        if !tryComplete(result) {
            
        }
    }
    
    func tryComplete(result: TaskResult<T>) -> Bool {
        switch result {
        case let res where res.state == State.Success:
            return self.trySuccess(res.value)
        default:
            if let certainError = result.error {
                return self.tryError(certainError)
            } else {
                return self.tryError(NSError.errorWithDomain("domain", code: 1, userInfo: nil));
            }
        }
    }
    
    func success(value: T?) {
        self.trySuccess(value)
    }
    
    func trySuccess(value: T?) -> Bool {
        return (q.sync {
            if self.result.state != .Pending {
                return false;
            }
            
            self.result = TaskResult(value: value)
            self.runCallbacks()
            return true;
        })!;
    }
    
    func error(error: NSError) {
        if !self.tryError(error) {

        }
    }
    
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
    
    func onComplete(callback: TaskResult<T> -> (), executionContext: ExecutionContext = defaultExecutionContext) {
        q.sync {
            let wrappedCallback : Future<T> -> () = { future in
                executionContext.execute {
                    callback(future.result)
                }
            }
            
            if self.result.state == .Pending {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
    }
    
    func onSuccess(callback: T? -> (), executionContext: ExecutionContext = defaultExecutionContext) {
        self.onComplete({ result in
            if result.state == .Success {
                callback(result.value)
            }
        }, executionContext: executionContext)
    }
    
    func onFailure(callback: NSError -> (), executionContext: ExecutionContext = defaultExecutionContext) {
        self.onComplete { result in
            if result.state == .Failure {
                callback(result.error!)
            }
        }
    }
    
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

struct TaskResult<T> {
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