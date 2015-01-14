//
//  Deferred.swift
//  BrightFutures
//
//  Created by Thomas Visser on 14/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

public class Deferred<T> {
    
    var result: T? = nil

    typealias CallbackInternal = (deferred: Deferred<T>) -> ()
    public typealias CompletionCallback = (result: T) -> ()
    
    
    /**
    * This queue is used for all callback related administrative tasks
    * to prevent that a callback is added to a completed future and never
    * executed or perhaps excecuted twice.
    */
    let callbackAdministrationQueue = Queue()
    
    /**
    * All callbacks are executed serially on this queue. This is on
    * top of the execution context, which is either given by the client
    * or returned from executionContextForCurrentContext
    */
    let callbackExecutionQueue = Queue();
    var callbacks: [CallbackInternal] = Array<CallbackInternal>()
    
    /**
    * Should be run on the callbackAdministrationQueue
    */
    private func runCallbacks() {
        for callback in self.callbacks {
            callback(deferred: self)
        }
        
        self.callbacks.removeAll()
    }
    
    internal func executionContextForCurrentContext() -> ExecutionContext {
        return NSThread.isMainThread() ? Queue.main : Queue.global
    }

    public required init() {
        
    }
}

/**
* This extension contains all (static) methods for Future creation
*/
public extension Deferred {
    public class func completed(result: T) -> Self {
        let res = self()
        res.result = result
        
        return res
    }
    
    public class func completeAfter(delay: NSTimeInterval, withResult result: T) -> Self {
        let res = self()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC))), Queue.global.queue) {
            res.complete(result)
        }
        
        return res
    }
    
    /**
    * Returns a Future that will never succeed
    */
    public class func never() -> Deferred<T> {
        return self()
    }
}

/**
* This extension contains methods to query the current status
* of the future and to access the result and/or error
*/
public extension Deferred {
    
    public var isCompleted: Bool {
        get {
            return self.result != nil
        }
    }
    
    public func forced() -> T {
        return forced(Double.infinity)!
    }
    
    public func forced(time: NSTimeInterval) -> T? {
        if let certainResult = self.result {
            return certainResult
        } else {
            let sema = dispatch_semaphore_create(0)
            var res: T? = nil
            self.onComplete(context: Queue.global) {
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
}

public extension Deferred {
    func complete(result: T) {
        let succeeded = tryComplete(result)
        assert(succeeded)
    }
    
    func tryComplete(result: T) -> Bool {
        return self.callbackAdministrationQueue.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = result
            self.runCallbacks()
            return true;
        };
    }
}

/**
* This extension contains all methods for registering callbacks
*/
public extension Deferred {
    
    public func onComplete(callback: CompletionCallback) -> Deferred<T> {
        return self.onComplete(context: executionContextForCurrentContext(), callback: callback)
    }
    
    public func onComplete(context c: ExecutionContext, callback: CompletionCallback) -> Deferred<T> {
        let wrappedCallback : Deferred<T> -> () = { future in
            if let realRes = self.result {
                c.execute {
                    self.callbackExecutionQueue.sync {
                        callback(result: realRes)
                        return
                    }
                    return
                }
            }
        }
        
        self.callbackAdministrationQueue.sync {
            if self.result == nil {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
        
        return self
    }
}
