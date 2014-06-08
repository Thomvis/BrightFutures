//
//  BrightFuturesTests.swift
//  BrightFuturesTests
//
//  Created by Thomas Visser on 08/06/14.
//  Copyright (c) 2014 Thomas Visser. All rights reserved.
//

import XCTest

class BrightFuturesTests: XCTestCase {
    
    class ComputationResult {
        let value: Int
        
        init(_ value: Int) {
            self.value = value;
        }
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCompletedFuture() {
        let f = Future<ComputationResult>.succeeded(ComputationResult(2))
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { result in
            XCTAssert(result.state == State.Success)
            completeExpectation.fulfill()
        }
        
        let successExpectation = self.expectationWithDescription("immediate success")
        
        f.onSuccess { computation in
            XCTAssert(computation != nil)
            XCTAssert(computation!.value == 2, "Computation should be returned")
            successExpectation.fulfill()
        }
        
        f.onFailure { _ in
            XCTFail("failure block should not get called")
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFailedFuture() {
        let error = NSError(domain: "test", code: 0, userInfo: nil)
        let f = Future<ComputationResult>.failed(error)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { result in
            XCTAssert(result.state == State.Failure)
            XCTAssert(result.error == error)
            completeExpectation.fulfill()
        }
        
        let failureExpectation = self.expectationWithDescription("immediate failure")
        
        f.onFailure { err in
            XCTAssert(err == error)
            failureExpectation.fulfill()
        }
        
        f.onSuccess { value in
            XCTFail("success should not be called")
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testControlFlowSyntax() {
        
        let f = future {
            ComputationResult(fibonacci(10))
        }
        
        let e = self.expectationWithDescription("the computation succeeds")
        
        f.onSuccess { computation in
            XCTAssert(computation?.value == 55)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testControlFlowSyntaxWithError() {
        
        let f : Future<ComputationResult> = future { (inout error: NSError?) -> ComputationResult? in
            error = NSError(domain: "NaN", code: 0, userInfo: nil)
            return nil
        }
        
        let failureExpectation = self.expectationWithDescription("failure expected")
        
        f.onFailure { error in
            XCTAssert(error.domain == "NaN")
            failureExpectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(3, handler: nil)
    }
    
    func testPromise() {
        let p = Promise<ComputationResult>()
        
        Queue.global.async {
            p.success(ComputationResult(fibonacci(10)))
        }
        
        let e = self.expectationWithDescription("complete expectation")
        
        p.future.onComplete { result in
            XCTAssert(result.value!.value == 55)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
}

func fibonacci(n: Int) -> Int {
    switch n {
    case 0...1:
        return n
    default:
        return fibonacci(n - 1) + fibonacci(n - 2)
    }
}
