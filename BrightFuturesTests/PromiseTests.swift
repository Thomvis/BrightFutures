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
        
        let e = self.expectation(description: "complete expectation")
        
        p.future.onComplete { result in
            switch result {
            case .success(let val):
                XCTAssert(Int(55) == val)
            case .failure(_):
                XCTAssert(false)
            }
            
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testFailurePromise() {
        let p = Promise<Int, TestError>()
        
        Queue.global.async {
            p.tryFailure(TestError.justAnError)
        }
        
        let e = self.expectation(description: "complete expectation")
        
        p.future.onComplete { result in
            switch result {
            case .success(_):
                XCTFail("should not be success")
            case .failure(let err):
                XCTAssertEqual(err, TestError.justAnError)
            }
            
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
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
        p.tryComplete(Result(error: TestError.justAnError))
        
        XCTAssert(p.future.isFailure)
        XCTAssert(p.future.forced() == Result<Int, TestError>(error:TestError.justAnError))
    }
    
    func testPromiseTrySuccessTwice() {
        let p = Promise<Int, NoError>()
        XCTAssert(p.trySuccess(1))
        XCTAssertFalse(p.trySuccess(2))
        XCTAssertEqual(p.future.forced().value!, 1)
    }
    
    func testPromiseTryFailureTwice() {
        let p = Promise<Int, TestError>()
        XCTAssert(p.tryFailure(TestError.justAnError))
        XCTAssertFalse(p.tryFailure(TestError.justAnotherError))
        XCTAssertEqual(p.future.forced().error!, TestError.justAnError)
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
        q.failure(.justAnError)
        XCTAssertEqual(p.future.error, .justAnError)
    }
}
