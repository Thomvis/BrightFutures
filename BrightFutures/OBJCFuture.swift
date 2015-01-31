//
//  OBJCFuture.swift
//  BrightFutures
//
//  Created by Thomas Visser on 29/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import Foundation

@objc public class BFFuture: NSObject {
    
    let future: Future<AnyObject>
    
    internal convenience override init() {
        self.init(future: Future<AnyObject>())
    }
    
    internal init(future: Future<AnyObject>) {
        self.future = future
    }
}

public extension BFFuture {

    public var result: BFResult? {
        get {
            if let res = self.future.result {
                return BFResult.fromSwift(res)
            }
            return nil
        }
    }
    
    public var value: AnyObject? {
        get {
            return self.future.value
        }
    }
    
    public var error: NSError? {
        get {
            return self.future.error
        }
    }
    
    public var isSuccess: Bool {
        get {
            return self.future.isSuccess
        }
    }
    
    public var isFailure: Bool {
        get {
            return self.future.isFailure
        }
    }
    
    public var isCompleted: Bool {
        get {
            return self.result != nil
        }
    }
    
    public class func succeeded(value: AnyObject) -> BFFuture {
        return BFFuture(future: Future.succeeded(value))
    }
    
    public class func failed(error: NSError) -> BFFuture {
        return BFFuture(future: Future.failed(error))
    }

    public class func completed(result: BFResult) -> BFFuture {        
        return BFFuture(future: Future<AnyObject>.completed(result.swiftResult))
    }
    
    public class func completeAfter(delay: NSTimeInterval, withValue value: AnyObject) -> BFFuture {
        return BFFuture(future: Future.completeAfter(delay, withValue: value))
    }
    
    public class func never() -> BFFuture {
        return BFFuture()
    }
    
}

public extension BFFuture {
    
    public func forced() -> BFResult? {
        return BFResult.fromSwift(self.future.forced())
    }
    
    public func forced(timeout: NSTimeInterval) -> BFResult? {
        return BFResult.fromSwift(self.future.forced(timeout))
    }
}
    
public extension BFFuture {

    public func onComplete(callback: (BFResult) -> ()) -> BFFuture {
        self.future.onComplete { result in
            callback(BFResult.fromSwift(result))
        }
        
        return self
    }

    public func onCompleteWithContext(context c: ExecutionContext, callback: (BFResult) -> ()) -> BFFuture {
        self.future.onComplete(context: c) { result in
            callback(BFResult.fromSwift(result))
        }

        return self
    }
    
    
}

@objc public class BFPromise : NSObject {

}

@objc public protocol BFExecutionContext {
    func execute(task: () -> ());
}


@objc public class BFResult {
    
    internal var success: Bool
    public var value: AnyObject?
    public var error: NSError?
    
    public var isSuccess: Bool {
        get {
            return success
        }
    }
    
    public var isFailure: Bool {
        get {
            return !self.isSuccess
        }
    }
    
    public init(value: AnyObject) {
        self.value = value
        self.success = true
    }
    
    public init(error: NSError) {
        self.error = error
        self.success = false
    }
    
    internal class func fromSwift(result: Result<AnyObject>!) -> BFResult {
        return BFResult.fromSwift(result)!
    }

    internal class func fromSwift(result: Result<AnyObject>?) -> BFResult? {
        if let result = result {
            switch result {
            case .Success(let boxedValue):
                return BFResult(value: boxedValue.value)
            case .Failure(let error):
                return BFResult(error: error)
            }
        }
        
        return nil
    }
    
    internal var swiftResult : Result<AnyObject> {
        get {
            if self.isSuccess {
                return Result.Success(Box(self.value!))
            }
            return Result.Failure(self.error!)
        }
    }
}

