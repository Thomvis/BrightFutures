//
//  InvalidationTokenTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 19/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures
import Result

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
        XCTAssert(token.future.result?.error != nil, "future should have an error")
        if let error = token.future.result?.error {
            XCTAssert(error == BrightFuturesError<NoError>.invalidationTokenInvalidated)
        }
    }
    
    func testCompletionAfterInvalidation() {
        let token = InvalidationToken()
        
        let p = Promise<Int, NSError>()
        
        p.future.onSuccess(token.validContext) { val in
            XCTAssert(false, "onSuccess should not get called")
        }.onFailure(token.validContext) { error in
            XCTAssert(false, "onSuccess should not get called")
        }
        
        let e = self.expectation()
        DispatchQueue.global().async {
            token.invalidate()
            p.success(2)
            Thread.sleep(forTimeInterval: 0.2); // make sure onSuccess is not called
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testNonInvalidatedSucceededFutureOnSuccess() {
        let token = InvalidationToken()
        
        let e = self.expectation()
        Future<Int, NoError>(value: 3).onSuccess(token.validContext) { val in
            XCTAssertEqual(val, 3)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testNonInvalidatedSucceededFutureOnComplete() {
        let token = InvalidationToken()
        
        let e = self.expectation()
        Future<Int, NoError>(value: 3).onComplete(token.validContext) { res in
            XCTAssertEqual(res.value!, 3)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testNonInvalidatedFailedFutureOnFailure() {
        let token = InvalidationToken()
        
        let e = self.expectation()
        Future<Int, TestError>(error: TestError.justAnError).onFailure(token.validContext) { err in
            XCTAssertEqual(err, TestError.justAnError)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testStress() {
        class Counter {
            var i = 0
        }
        
        let q = DispatchQueue(label: "stress queue")
        
        var token: InvalidationToken!
        let counter = Counter()
        for _ in 1...100 {
            token = InvalidationToken()
            let currentI = counter.i
            let e = self.expectation()
            DispatchQueue.global().asyncValue { () -> Bool in
                let sleep: Foundation.TimeInterval = TimeInterval(arc4random() % 100) / 100000.0
                Thread.sleep(forTimeInterval: sleep)
                return true
            }.onSuccess(token.validContext(q.context)) { _ in
                XCTAssert(!token.isInvalid)
                XCTAssertEqual(currentI, counter.i, "onSuccess should only get called if the counter did not increment")
            }.onComplete(DispatchQueue.global().context) { _ in
                Thread.sleep(forTimeInterval: 0.0001);
                e.fulfill()
            }
            
            Thread.sleep(forTimeInterval: 0.0005)
            
            q.sync {
                token.invalidate()
                counter.i += 1
            }
        }
        
        self.waitForExpectations(timeout: 5, handler: nil)
    }
    
}
