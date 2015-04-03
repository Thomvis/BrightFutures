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

public func future<T>(task: () -> T) -> Future<T> {
    return future(context: Queue.global.context, task)
}

public func future<T>(context c: ExecutionContext, task: () -> T) -> Future<T> {
    return future(context: c, { () -> Result<T> in
        return Result<T>(task())
    })
}

public func future<T>(task: () -> Result<T>) -> Future<T> {
    return future(context: Queue.global.context, task)
}

public func future<T>(context c: ExecutionContext, task: () -> Result<T>) -> Future<T> {
    let promise = Promise<T>();
    
    c {
        let result = task()
        switch result {
        case .Success(let boxedValue):
            promise.success(boxedValue.value)
        case .Failure(let error):
            promise.failure(error)
		case .Progress(let progress, let total):
			promise.progress(progress, total: total)
        }
    }
    
    return promise.future
}

func executionContextForCurrentContext() -> ExecutionContext {
    return toContext(NSThread.isMainThread() ? Queue.main : Queue.global)
}

public let BrightFuturesErrorDomain = "nl.thomvis.BrightFutures"

public enum ErrorCode: Int {
    case NoSuchElement
    case InvalidationTokenInvalidated
    
    var errorDescription: String {
        switch self {
        case .NoSuchElement:
            return "No such element"
        case .InvalidationTokenInvalidated:
            return "Invalidation token invalidated"
        }
    }
}

internal func errorFromCode(code: ErrorCode, failureReason: String? = nil) -> NSError {
    var userInfo = [
        NSLocalizedDescriptionKey : code.errorDescription
    ]
    
    if let reason = failureReason {
        userInfo[NSLocalizedFailureReasonErrorKey] = reason
    }
    
    return NSError(domain: BrightFuturesErrorDomain, code: code.rawValue, userInfo: userInfo)
}

public class Future<T> {
    
    typealias CallbackInternal = (future: Future<T>) -> ()
    typealias CompletionCallback = (result: Result<T>) -> ()
    typealias SuccessCallback = (T) -> ()
	public typealias ProgressCallback = (progress: Float, total: Float) -> ()
    public typealias FailureCallback = (NSError) -> ()
    
    var result: Result<T>? = nil
	var progress: Float = 0.0
	var total: Float = 1.0
    
    /**
     * This queue is used for all callback related administrative tasks
     * to prevent that a callback is added to a completed future and never
     * executed or perhaps excecuted twice.
     */
    let callbackAdministrationQueue = Queue()
    
    /**
     * Upon completion of the future, all callbacks are asynchronously scheduled to their
     * respective execution contexts (which is either given by the client or returned from
     * executionContextForCurrentContext). Inside the context, this semaphore will be used
     * to make sure that all callbacks are executed serially.
     */
    let callbackExecutionSemaphore = Semaphore(value: 1);
    var callbacks: [CallbackInternal] = Array<CallbackInternal>()
	
	let progressCallbackAdministrationQueue = Queue()
	var progressCallbacks: [CallbackInternal] = Array<CallbackInternal>()
    
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
		self.progressCallbacks.removeAll()
    }
	
	private func runProgressCallbacks() {
		for callback in self.progressCallbacks {
			callback(future: self)
		}
	}
}

/**
 * The internal API for completing a Future
 */
internal extension Future {
    func complete(result: Result<T>) {
        let succeeded = tryComplete(result)
        assert(succeeded)
    }
    
    func tryComplete(result: Result<T>) -> Bool {
        switch result {
        case .Success(let val):
            return self.trySuccess(val.value)
        case .Failure(let err):
            return self.tryFailure(err)
		case .Progress(let progress, let total):
			return self.tryProgress(progress, total: total)
        }
    }
    
    func success(value: T) {
        let succeeded = self.trySuccess(value)
        assert(succeeded)
    }
    
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
    
    func failure(error: NSError) {
        let succeeded = self.tryFailure(error)
        assert(succeeded)
    }
    
    func tryFailure(error: NSError) -> Bool {
        return self.callbackAdministrationQueue.sync {
            if self.result != nil {
                return false;
            }
            
            self.result = .Failure(error)
            self.runCallbacks()
            return true;
        };
    }
	
	func progress(progress: Float, total: Float) {
		let succeeded = self.tryProgress(progress, total: total)
		assert(succeeded)
	}
	
	func tryProgress(progress: Float, total: Float) -> Bool {
		return self.progressCallbackAdministrationQueue.sync {
			self.progress = progress
			self.total = total
			self.runProgressCallbacks()
			return true;
		};
	}
}

/**
 * This extension contains all (static) methods for Future creation
 */
public extension Future {
    
    public var value: T? {
        get {
            return self.result?.value
        }
    }
    
    public var error: NSError? {
        get {
            return self.result?.error
        }
    }
    
    public var isSuccess: Bool {
        get {
            return self.result?.isSuccess ?? false
        }
    }
    
    public var isFailure: Bool {
        get {
            return self.result?.isFailure ?? false
        }
    }
    
    public var isCompleted: Bool {
        get {
            return self.result != nil
        }
    }
    
    public class func succeeded(value: T) -> Future<T> {
        let res = Future<T>();
        res.result = Result(value)
        
        return res
    }
    
    public class func failed(error: NSError) -> Future<T> {
        let res = Future<T>();
        res.result = .Failure(error)
        
        return res
    }
    
    public class func completed<T>(result: Result<T>) -> Future<T> {
        let res = Future<T>()
        res.result = result
        
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
    
    /**
     * Returns a future with the new (type-inferred) type.
     * That future is only completed when this future fails with an error.
     */
    public func asType<U>() -> Future<U> {
        let p = Promise<U>()
        
        self.onFailure { err in
            p.failure(err)
        }
        
        return p.future
    }
}

/**
 * This extension contains methods to query the current status
 * of the future and to access the result and/or error
 */
public extension Future {
    
    public func forced() -> Result<T>? {
        return self.forced(nil)
    }
    
    public func forced(timeout: NSTimeInterval?) -> Result<T>? {
        return self.forced( timeout.map { .In($0) } ?? .Forever )
    }
    
    public func forced(timeout: TimeInterval) -> Result<T>? {
        if let certainResult = self.result {
            return certainResult
        } else {
            let sema = Semaphore(value: 0)
            var res: Result<T>? = nil
            self.onComplete(context: Queue.global.context) {
                res = $0
                sema.signal()
            }
            
            sema.wait(timeout)
            
            return res
        }
    }
}

/**
 * This extension contains all methods for registering callbacks
 */
public extension Future {
    public func onComplete(callback: CompletionCallback) -> Future<T> {
        return onComplete(context: executionContextForCurrentContext(), callback: callback)
    }

    public func onComplete(context c: ExecutionContext, callback: CompletionCallback) -> Future<T> {
        let wrappedCallback : Future<T> -> () = { future in
            if let realRes = self.result {
                c {
                    self.callbackExecutionSemaphore.execute {
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

    public func onSuccess(callback: SuccessCallback) -> Future<T> {
        return onSuccess(context: executionContextForCurrentContext(), callback: callback)
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
        return onFailure(callback: callback)
    }

    public func onFailure(context c: ExecutionContext = executionContextForCurrentContext(), callback: FailureCallback) -> Future<T> {
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
	
	public func onProgress(callback: ProgressCallback) -> Future<T> {
		return onProgress(callback: callback)
	}
	
	public func onProgress(context c: ExecutionContext = executionContextForCurrentContext(), callback: ProgressCallback) -> Future<T> {
		let wrappedCallback : Future<T> -> () = { future in
			c {
				callback(progress: future.progress, total: future.total)
				return
			}
		}
		
		self.progressCallbackAdministrationQueue.sync {
			self.progressCallbacks.append(wrappedCallback)
		}
		
		return self
	}
}

/**
 * This extension contains all methods related to functional composition
 */
public extension Future {

    public func flatMap<U>(f: T -> Future<U>) -> Future<U> {
        return flatMap(context: executionContextForCurrentContext(), f: f)
    }

    public func flatMap<U>(context c: ExecutionContext, f: T -> Future<U>) -> Future<U> {
        let p: Promise<U> = Promise()
        self.onComplete(context: c) { res in
            switch (res) {
            case .Failure(let e):
                p.failure(e)
            case .Success(let v):
                p.completeWith(f(v.value))
			case .Progress(let progress, let total):
				p.progress(progress, total: total)
            }
        }
        return p.future
    }

    public func flatMap<U>(f: T -> Result<U>) -> Future<U> {
        return flatMap(context: executionContextForCurrentContext(), f: f)
    }

    public func flatMap<U>(context c: ExecutionContext, f: T -> Result<U>) -> Future<U> {
        return self.flatMap(context: c) { value in
            Future.completed(f(value))
        }
    }

    public func map<U>(f: (T) -> U) -> Future<U> {
        return self.map(context: executionContextForCurrentContext(), f: f)
    }

    public func map<U>(context c: ExecutionContext, f: (T) -> U) -> Future<U> {
        let p = Promise<U>()
        
        self.onComplete(context: c, callback: { result in
            switch result {
            case .Success(let v):
                p.success(f(v.value))
                break;
            case .Failure(let e):
                p.failure(e)
                break;
			case .Progress(let progress, let total):
				p.progress(progress, total: total)
				break;
            }
        })
        
        return p.future
    }

    public func andThen(callback: Result<T> -> ()) -> Future<T> {
        return andThen(context: executionContextForCurrentContext(), callback: callback)
    }

    public func andThen(context c: ExecutionContext, callback: Result<T> -> ()) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result in
            callback(result)
            p.completeWith(self)
        }

        return p.future
    }

    public func recover(task: (NSError) -> T) -> Future<T> {
        return recover(context:executionContextForCurrentContext(), task: task)
    }

    public func recover(context c: ExecutionContext, task: (NSError) -> T) -> Future<T> {
        return self.recoverWith(context: c) { error -> Future<T> in
            return Future.succeeded(task(error))
        }
    }

    public func recoverWith(task: (NSError) -> Future<T>) -> Future<T> {
        return recoverWith(context: executionContextForCurrentContext(), task: task)
    }

    public func recoverWith(context c: ExecutionContext, task: (NSError) -> Future<T>) -> Future<T> {
        let p = Promise<T>()
        
        self.onComplete(context: c) { result -> () in
            switch result {
            case .Failure(let err):
                p.completeWith(task(err))
            case .Success(let val):
                p.completeWith(self)
			case .Progress(let progress, let total):
				break;
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
        return self.flatMap { value -> Result<T> in
            if p(value) {
                return .Success(Box(value))
            } else {
                return .Failure(errorFromCode(.NoSuchElement))
            }
        }
    }
}

/**
 I'd like this to be in InvalidationToken.swift, but the compiler does not like that.
 */
public extension Future {
    
    func firstCompletedOfSelfAndToken(token: InvalidationTokenType) -> Future<T> {
        return FutureUtils.firstCompletedOf([self, token.future.asType()])
    }
    
    public func onComplete(#token: InvalidationTokenType, callback: Result<T> -> ()) -> Future<T> {
        return onComplete(context: executionContextForCurrentContext(), token: token, callback: callback)
    }

    public func onComplete(context c: ExecutionContext, token: InvalidationTokenType, callback: Result<T> -> ()) -> Future<T> {
        firstCompletedOfSelfAndToken(token).onComplete(context: c) { res in
            token.context {
                if !token.isInvalid {
                    callback(res)
                }
            }
        }
        return self;
    }

    public func onSuccess(#token: InvalidationTokenType, callback: SuccessCallback) -> Future<T> {
        return onSuccess(context: executionContextForCurrentContext(), token: token, callback: callback)
    }

    public func onSuccess(context c: ExecutionContext, token: InvalidationTokenType, callback: SuccessCallback) -> Future<T> {
        firstCompletedOfSelfAndToken(token).onSuccess(context: c) { value in
            token.context {
                if !token.isInvalid {
                    callback(value)
                }
            }
        }
        
        return self
    }

    public func onFailure(#token: InvalidationTokenType, callback: FailureCallback) -> Future<T> {
        return onFailure(context: executionContextForCurrentContext(), token: token, callback: callback)
    }

    public func onFailure(context c: ExecutionContext, token: InvalidationTokenType, callback: FailureCallback) -> Future<T> {
        firstCompletedOfSelfAndToken(token).onFailure(context: c) { error in
            token.context {
                println("Failure")
                if !token.isInvalid {
                    callback(error)
                }
            }
        }
        return self
    }
}
