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

public func future<T>(context c: ExecutionContext = Queue.global, task: () -> T) -> Future<T> {
    return future(context: c, { () -> Result<T> in
        return Result<T>(task())
    })
}

public func future<T>(context c: ExecutionContext = Queue.global, task: @autoclosure () -> T) -> Future<T> {
    return future(context: c, { () -> Result<T> in
        return Result<T>(task())
    })
}

public func future<T>(context c: ExecutionContext = Queue.global, task: () -> Result<T>) -> Future<T> {
    let promise = Promise<T>();
    
    c.execute {
        let result = task()
        switch result {
        case .Success(let boxedValue):
            promise.success(boxedValue.value)
        case .Failure(let error):
            promise.error(error)
        }
    }
    
    return promise.future
}

public let NoSuchElementError = "NoSuchElementError"

public class Future<T> {
    
    typealias CallbackInternal = (future: Future<T>) -> ()
    typealias CompletionCallback = (result: Result<T>) -> ()
    typealias SuccessCallback = (T) -> ()
    public typealias FailureCallback = (NSError) -> ()
    
    var result: Result<T>? = nil
    
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
    
    internal init() {
        
    }
    
    /**
     * Should be run on the callbackAdministrationQueue
     */
    private func runCallbacks() {
        for callback in self.callbacks {
            callback(future: self)
        }
        
        self.callbacks.removeAll()
    }
    
    private func executionContextForCurrentContext() -> ExecutionContext {
        return NSThread.isMainThread() ? Queue.main : Queue.global
    }
}

/**
 * The internal API for completing a Future
 */
internal extension Future {
	
	/**
	Completes the future with the given result.
	If the future was already completed, an assertion will be raised.
	
	:param: result The result to complete the future with.
	*/
    func complete(result: Result<T>) {
        let succeeded = tryComplete(result)
        assert(succeeded)
    }
	
	/**
	Completes the future with the given result.
	
	:param: result The result to complete the future with.
	
	:returns: False if the future was already completed, true otherwise.
	*/
    func tryComplete(result: Result<T>) -> Bool {
        switch result {
        case .Success(let val):
            return self.trySuccess(val.value)
        case .Failure(let err):
            return self.tryError(err)
        }
    }
	
	/**
	Completes the future as success with the given value.
	If the future was already completed, an assertion will be raised.
	
	:param: value The value to complete the future with.
	*/
    func success(value: T) {
        let succeeded = self.trySuccess(value)
        assert(succeeded)
    }
	
	/**
	Completes the future as success with the given error.
	
	:param: value The value to complete the future with.
	
	:returns: False if the future was already completed, true otherwise.
	*/
    func trySuccess(value: T) -> Bool {
        return self.callbackAdministrationQueue.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = Result(value)
            self.runCallbacks()
            return true;
        };
    }
	
	/**
	Completes the future as failed with the given error.
	If the future was already completed, an assertion will be raised.
	
	:param: value The error to complete the future with.
	*/
    func error(error: NSError) {
        let succeeded = self.tryError(error)
        assert(succeeded)
    }
	
	/**
	Completes the future as failed with the given error.
	
	:param: error The error to complete the future with.
	
	:returns: False if the future was already completed, true otherwise.
	*/
    func tryError(error: NSError) -> Bool {
        return self.callbackAdministrationQueue.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = .Failure(error)
            self.runCallbacks()
            return true;
        };
    }
}

/**
 * This extension contains all (static) methods for Future creation
 */
public extension Future {
	
	/// The success value of this future, or nil if the future failed or isn't completed yet.
    public var value: T? {
        get {
            return self.result?.value
        }
    }
	
	/// The failure error of this future, or nil if the future succeeded or isn't completed yet.
    public var error: NSError? {
        get {
            return self.result?.error
        }
    }
	
	/// True if this future completed with success, false if the future failed or isn't completed yet.
    public var isSuccess: Bool {
        get {
            return self.result?.isSuccess ?? false
        }
    }
	
	/// True if this future completed with failure, false if the future succeeded or isn't completed yet.
    public var isFailure: Bool {
        get {
            return self.result?.isFailure ?? false
        }
    }
	
	/// True if the future is completed, false otherwise.
    public var isCompleted: Bool {
        get {
            return self.result != nil
        }
    }

	/**
	Returns a new Future which has a successful result with the given value.
	
	:param: value The success value.
	
	:returns: Future with success result.
	*/
    public class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = Result(value)
        
        return res
	}
	
	/**
	Returns a new Future which has a failed result with the given error.
	
	:param: error The error.
	
	:returns: Future with failed result.
	*/
    public class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = .Failure(error)
        
        return res
    }
	
	/**
	Returns a new Future with the given result.
	
	:param: result The result to set on the future.
	
	:returns: Future with given result.
	*/
    public class func completed<T>(result: Result<T>) -> Future<T> {
        let res = Future<T>()
        res.result = result
        
        return res
    }
	
	/**
	Returns a new Future which will be completed with success after a given delay.
	
	:param: delay The delay after which to complete the future.
	:param: value The value to complete the future as success with.
	
	:returns: Future.
	*/
    public class func completeAfter(delay: NSTimeInterval, withValue value: T) -> Future<T> {
        let res = Future<T>()
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * NSTimeInterval(NSEC_PER_SEC))), Queue.global.queue) {
            res.success(value)
        }
        
        return res
    }
	
	/**
	Returns a Future that will never succeed.
	*/
    public class func never() -> Future<T> {
        return Future<T>()
    }
}

/**
 * This extension contains methods to query the current status
 * of the future and to access the result and/or error
 */
public extension Future {

    public func forced() -> Result<T> {
        return forced(Double.infinity)!
    }

    public func forced(time: NSTimeInterval) -> Result<T>? {
        if let certainResult = self.result {
            return certainResult
        } else {
            let sema = dispatch_semaphore_create(0)
            var res: Result<T>? = nil
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

/**
 * This extension contains all methods for registering callbacks
 */
public extension Future {

	/**
	Registers the given callback to be executed when this future completes.
	
	:param: callback The function to be called.
	
	:returns: This future.
	*/
    public func onComplete(callback: CompletionCallback) -> Future<T> {
        return self.onComplete(context: executionContextForCurrentContext(), callback: callback)
    }
	
	/**
	Registers the given callback to be executed on the specified ExecutionContect when this future completes.
	
	:param: context  The execution context on which to call the function.
	:param: callback The function to be called.
	
	:returns: This future.
	*/
    public func onComplete(context c: ExecutionContext, callback: CompletionCallback) -> Future<T> {
        let wrappedCallback : Future<T> -> () = { future in
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
		
		// Add the callback to the queue, waiting the get executed when the future completes,
		// or call it immediately if the future result is already known.
        self.callbackAdministrationQueue.sync {
            if self.result == nil {
                self.callbacks.append(wrappedCallback)
            } else {
                wrappedCallback(self)
            }
        }
        
        return self
    }

	/**
	Registers the given callback to be executed when this future completes with success.
	
	:param: callback The function to be called.
	
	:returns: This future.
	*/
    public func onSuccess(callback: SuccessCallback) -> Future<T> {
        return self.onSuccess(context: executionContextForCurrentContext(), callback)
    }

	/**
	Registers the given callback to be executed on the specified ExecutionContect when this future completes with success.
	
	:param: context  The execution context on which to call the function.
	:param: callback The function to be called.
	
	:returns: This future.
	*/
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
	
	/**
	Registers the given callback to be executed when this future completes with failure.
	
	:param: callback The function to be called.
	
	:returns: This future.
	*/
    public func onFailure(callback: FailureCallback) -> Future<T> {
        return self.onFailure(context: executionContextForCurrentContext(), callback)
    }
	
	/**
	Registers the given callback to be executed on the specified execution context when this future completes with failure.
	
	:param: context  The execution context on which to call the function.
	:param: callback The function to be called.
	
	:returns: This future.
	*/
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
}

/**
 * This extension contains all methods related to functional composition
 */
public extension Future {

    public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
        return self.flatMap(context: executionContextForCurrentContext(), f)
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
    
    public func flatMap<U>(f: T -> Result<U>) -> Future<U> {
        return self.flatMap(context: executionContextForCurrentContext(), f)
    }
    
    public func flatMap<U>(context c: ExecutionContext, f: T -> Result<U>) -> Future<U> {
        return self.flatMap(context: c) { value in
            Future.completed(f(value))
        }
    }

	/**
	Returns a new Future that contains the error from this Future if this Future failed,
	or the return value from the given closure that was applied to the value of this Future.
	
	:param: f The closure to apply to the value of this Future.
	
	:returns: New Future
	*/
    public func map<U>(f: (T) -> U) -> Future<U> {
        return self.map(context: executionContextForCurrentContext(), f)
    }

	/**
	Returns a new Future that contains the error from this Future if this Future failed,
	or the return value from the given closure that was applied to the value of this Future.
	
	:param: f       The closure to apply to the value of this Future.
	:param: context The execution context to call the closure in.
	
	:returns: New Future
	*/
    public func map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result {
            case .Success(let v):
                p.success(f(v.value))
                break;
            case .Failure(let e):
                p.error(e)
                break;
            }
        })
        
        return p.future
    }

	/**
	Registers a given callback to be called when this future completes.
	
	:param: callback The callback to call when this future completes.
	
	:returns: A new future that will have the same result as this future.
	*/
    public func andThen(callback: Result<T> -> ()) -> Future<T> {
        return self.andThen(context: executionContextForCurrentContext(), callback: callback)
    }

	/**
	Registers a given callback to be called when this future completes.
	
	:param: context  The execution context in which to call the callback.
	:param: callback The callback to call when this future completes.
	
	:returns: A new future that will have the same result as this future.
	*/
    public func andThen(context c: ExecutionContext, callback: Result<T> -> ()) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result in
            callback(result)
            p.completeWith(self)
        }

        return p.future
    }
	
	/**
	Returns a future that, if this future succeeds, contains the value that this future succeeded with,
	or if this future fails, the value that is returned from the given closure.
	
	In practice, this means that when this future fails, the given closure will be called.
	the value returned from that closure will be used to complete this future with as success.
	
	:param: task The closure that provides a recovery value.
	
	:returns: A new future that will have the same result as this future.
	*/
    public func recover(task: (NSError) -> T) -> Future<T> {
        return self.recover(context: executionContextForCurrentContext(), task)
    }
	
	/**
	Returns a future that, if this future succeeds, contains the value that this future succeeded with,
	or if this future fails, the value that is returned from the given closure.
	
	In practice, this means that when this future fails, the given closure will be called,
	the value returned from that closure will be used to complete this future with as success.
	
	:param: context The execution context in which to call the closure.
	:param: task   The closure that provides a recovery value.
	
	:returns: A new future that will have the same result as this future.
	*/
    public func recover(context c: ExecutionContext, task: (NSError) -> T) -> Future<T> {
        return self.recoverWith(context: c) { error -> Future<T> in
            return Future.succeeded(task(error))
        }
    }
	
	/**
	Returns a future that, if this future succeeds, contains the value that this future succeeded with,
	or if this future fails, contains the result from the future that is returned from the given closure.
	
	In practice, this means that when this future fails, the given closure will be called,
	The future returned from that closure will be used to complete this future with.
	
	:param: task The closure that provides a recovery future.
	
	:returns: A new future that will have the same result as this future.
	*/
    public func recoverWith(task: (NSError) -> Future<T>) -> Future<T> {
        return self.recoverWith(context: executionContextForCurrentContext(), task: task)
    }
	
	/**
	Returns a future that, if this future succeeds, contains the value that this future succeeded with,
	or if this future fails, contains the result from the future that is returned from the given closure.
	
	In practice, this means that when this future fails, the given closure will be called,
	The future returned from that closure will be used to complete this future with.
	
	:param: context The execution context in which to call the closure.
	:param: task    The closure that provides a recovery future.
	
	:returns: A new future that will have the same result as this future.
	*/
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
        return self.flatMap { thisVal -> Future<(T,U)> in
            return that.map { thatVal in
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
}
