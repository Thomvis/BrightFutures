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
        let token = InvalidationToken()
        XCTAssert(!token.isInvalid, "a token is valid by default")
    }
    
    func testInvalidateToken() {
        let token = InvalidationToken()
        token.invalidate()
        XCTAssert(token.isInvalid, "a token should become invalid after invalidating")
    }
    
    func testInvalidationTokenFuture() {
        let token = InvalidationToken()
        XCTAssertNotNil(token.future, "token should have a future")
        XCTAssert(!token.future.isCompleted, "token should have a future and not be complete")
        token.invalidate()
        XCTAssert(token.future.error != nil, "future should have an error")
        if let error = token.future.error {
            XCTAssertEqual(error.domain, BrightFuturesErrorDomain)
            XCTAssertEqual(error.code, InvalidationTokenInvalid)
        }
    }
    
    func testProactiveInvalidation() {
        let token = InvalidationToken()
        let e = self.expectation()
        Future<Void>.never().validate(token).onComplete { result in
            XCTAssert(result.error?.code == InvalidationTokenInvalid, "validate should fail with error even if the future never completes")
            e.fulfill()
        }
        token.invalidate()
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testInvalidationAfterCompletion() {
        let token = InvalidationToken()
        let e = self.expectation()
        
        let p = Promise<Void>()
        p.future.validate(token).onSuccess { val in
            XCTAssert(true, "onSuccess should get called")
            e.fulfill()
        }.onFailure { error in
            XCTAssert(false, "onFailure should not get called")
        }
        
        let e2 = self.expectation()
        Queue.global.async {
            p.success()
            token.invalidate()
            NSThread.sleepForTimeInterval(0.2); // make sure onFailure is not called
            e2.fulfill();
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testCompletionAfterInvalidation() {
        let token = InvalidationToken()
        let e = self.expectation()
        
        let p = Promise<Int>()
        p.future.validate(token).onSuccess { val in
            XCTAssert(false, "onSuccess should not get called")
        }.onFailure { error in
            XCTAssertEqual(error.code, InvalidationTokenInvalid, "future invalid error")
            e.fulfill()
        }
        
        let e2 = self.expectation()
        Queue.global.async {
            token.invalidate()
            p.success(2)
            NSThread.sleepForTimeInterval(0.2); // make sure onSuccess is not called
            e2.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
}
