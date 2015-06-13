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
            XCTAssert(error == BrightFuturesError.InvalidationTokenInvalidated)
        }
    }
    
    func testCompletionAfterInvalidation() {
        let token = InvalidationToken()
        
        let p = Promise<Int, NSError>()
        
        p.future.onSuccess(token: token) { val in
            XCTAssert(false, "onSuccess should not get called")
        }.onFailure(token: token) { error in
            XCTAssert(false, "onSuccess should not get called")
        }
        
        let e = self.expectation()
        Queue.global.async {
            token.invalidate()
            p.success(2)
            NSThread.sleepForTimeInterval(0.2); // make sure onSuccess is not called
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testStress() {
        class Counter {
            var i = 0
        }
        
        var token: InvalidationToken!
        let counter = Counter()
        for _ in 1...100 {
            token = InvalidationToken()
            let currentI = counter.i
            let e = self.expectation()
            future { () -> Bool in
                let sleep: NSTimeInterval = NSTimeInterval(arc4random() % 100) / 100000.0
                NSThread.sleepForTimeInterval(sleep)
                return true
            }.onSuccess(context: Queue.global.context, token: token) { _ in
                XCTAssert(!token.isInvalid)
                XCTAssertEqual(currentI, counter.i, "onSuccess should only get called if the counter did not increment")
            }.onComplete(context: Queue.global.context) { _ in
                NSThread.sleepForTimeInterval(0.0001);
                e.fulfill()
            }
            
            NSThread.sleepForTimeInterval(0.0005)
            
            token.context {
                counter.i++
                token.invalidate()
            }
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
}
