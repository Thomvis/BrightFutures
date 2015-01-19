//
//  InvalidationTokenTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 19/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures

class InvalidationTokenTests: XCTestCase {

    func testInvalidationTokenInit() {
        let token = DefaultInvalidationToken()
        XCTAssert(!token.isInvalid, "a token is valid by default")
    }
    
    func testInvalidateToken() {
        let token = DefaultInvalidationToken()
        token.invalidate()
        XCTAssert(token.isInvalid, "a token should become invalid after invalidating")
    }
    
    func testInvalidationTokenFuture() {
        let token = DefaultInvalidationToken()
        XCTAssertNotNil(token.future, "token should have a future")
        if let future = token.future {
            XCTAssert(!future.isCompleted, "token should have a future and not be complete")
            token.invalidate()
            XCTAssert(future.error != nil, "future should have an error")
            if let error = future.error {
                XCTAssertEqual(error.domain, BrightFuturesErrorDomain)
                XCTAssertEqual(error.code, FutureInvalidatedError)
            }
        }
    }
    
    func testProactiveInvalidation() {
        let token = DefaultInvalidationToken()
        let e = self.expectation()
        Future<Void>.never().validate(token).onComplete { result in
            XCTAssert(result.error != nil, "validate should fail with error ")
            e.fulfill()
        }
        token.invalidate()
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testInvalidationAfterCompletion() {
        let token = DefaultInvalidationToken()
        let e = self.expectation()
        Future<Void>.succeeded().validate(token).onSuccess { val in
            XCTAssert(true, "onSuccess should get called")
            NSThread.sleepForTimeInterval(1) // give failure time to propagate
            e.fulfill()
        }.onFailure { error in
            XCTAssert(false, "onFailure should not get called")
        }
        
        token.invalidate()
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testCompletionAfterInvalidation() {
        let token = DefaultInvalidationToken()
        let p = Promise<Int>()
        
        let e = self.expectation()
        p.future.validate(token).onSuccess { val in
            XCTAssert(false, "onSuccess should not get called")
        }.onFailure { error in
            XCTAssertEqual(error.code, FutureInvalidatedError, "future invalid error")
            NSThread.sleepForTimeInterval(1) // give success time to propagate
            e.fulfill()
        }
        
        token.invalidate()
        p.success(2)
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testObjectExistenceInvalidation() {
        var object: NSObject? = NSObject()
        var token = ObjectExistenceInvalidationToken(object: object!)
        
        XCTAssert(!token.isInvalid)

        object = nil

        XCTAssert(token.isInvalid)
    }
}
