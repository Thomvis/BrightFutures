//
//  PromiseTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 16/10/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures
import Result

class PromiseTests: XCTestCase {

    func testSuccessPromise() {
        let p = Promise<Int, NoError>()
        
        Queue.global.async {
            p.success(fibonacci(10))
        }
        
        let e = self.expectationWithDescription("complete expectation")
        
        p.future.onComplete { result in
            switch result {
            case .Success(let val):
                XCTAssert(Int(55) == val)
            case .Failure(_):
                XCTAssert(false)
            }
            
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFailurePromise() {
        let p = Promise<Int, TestError>()
        
        Queue.global.async {
            p.tryFailure(TestError.JustAnError)
        }
        
        let e = self.expectationWithDescription("complete expectation")
        
        p.future.onComplete { result in
            switch result {
            case .Success(_):
                XCTFail("should not be success")
            case .Failure(let err):
                XCTAssertEqual(err, TestError.JustAnError)
            }
            
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testCompletePromise() {
        let p = Promise<Int, TestError>()
        p.complete(Result(value: 2))
        
        XCTAssertEqual(p.future.value, 2)
    }
    
    func testPromiseCompleteWithSuccess() {
        let p = Promise<Int, TestError>()
        p.tryComplete(Result(value: 2))
        
        XCTAssert(p.future.isSuccess)
        XCTAssert(p.future.forced() == Result<Int, TestError>(value:2))
    }
    
    func testPromiseCompleteWithFailure() {
        let p = Promise<Int, TestError>()
        p.tryComplete(Result(error: TestError.JustAnError))
        
        XCTAssert(p.future.isFailure)
        XCTAssert(p.future.forced() == Result<Int, TestError>(error:TestError.JustAnError))
    }
    
    func testPromiseTrySuccessTwice() {
        let p = Promise<Int, NoError>()
        XCTAssert(p.trySuccess(1))
        XCTAssertFalse(p.trySuccess(2))
        XCTAssertEqual(p.future.forced().value!, 1)
    }
    
    func testPromiseTryFailureTwice() {
        let p = Promise<Int, TestError>()
        XCTAssert(p.tryFailure(TestError.JustAnError))
        XCTAssertFalse(p.tryFailure(TestError.JustAnotherError))
        XCTAssertEqual(p.future.forced().error!, TestError.JustAnError)
    }
    
    func testPromiseCompleteWithSucceedingFuture() {
        let p = Promise<Int, NoError>()
        let q = Promise<Int, NoError>()
        
        p.completeWith(q.future)
        
        XCTAssert(!p.future.isCompleted)
        q.success(1)
        XCTAssertEqual(p.future.value, 1)
    }
    
    func testPromiseCompleteWithFailingFuture() {
        let p = Promise<Int, TestError>()
        let q = Promise<Int, TestError>()
        
        p.completeWith(q.future)
        
        XCTAssert(!p.future.isCompleted)
        q.failure(.JustAnError)
        XCTAssertEqual(p.future.error, .JustAnError)
    }
}
