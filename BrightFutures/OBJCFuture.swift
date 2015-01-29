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
    
    public var result: BFResult? {
        get {
            if let res = self.future.result {
                return BFResult(result: res)
            }
            return nil
        }
    }
    
    internal convenience override init() {
        self.init(future: Future<AnyObject>())
    }
    
    internal init(future: Future<AnyObject>) {
        self.future = future
    }
    
    public class func never() -> BFFuture {
        return BFFuture()
    }
    
    public class func succeeded(value: AnyObject) -> BFFuture {
        return BFFuture(future: Future.succeeded(value))
    }
    
    public func onComplete(callback: (BFResult) -> ()) -> BFFuture {
        self.future.onComplete { result in
            callback(BFResult(result: result))
        }
        
        return self
    }
    
}

@objc public class BFPromise : NSObject {
    
}

@objc public class BFResult : NSObject {
    public let error: NSError?
    public let value: AnyObject?
    
    internal init(result: Result<AnyObject>) {
        switch result {
        case .Success(let boxedValue):
            self.value = boxedValue.value
        case .Failure(let error):
            self.error = error
        }
    }
}