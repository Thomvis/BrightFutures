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

import XCTest

class BrightFuturesTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCompletedFuture() {
        let f = Future<Int>.succeeded(2)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { (value, error) in
            XCTAssert(!error)
            completeExpectation.fulfill()
        }
        
        let successExpectation = self.expectationWithDescription("immediate success")
        
        f.onSuccess { value in
            XCTAssert(value != nil)
            XCTAssert(value == 2, "Computation should be returned")
            successExpectation.fulfill()
        }
        
        f.onFailure { _ in
            XCTFail("failure block should not get called")
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFailedFuture() {
        let error = NSError(domain: "test", code: 0, userInfo: nil)
        let f = Future<Bool>.failed(error)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { (value, futureError) in
            XCTAssert(!value)
            XCTAssert(futureError == error)
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
        
        let f = future { _ in
            fibonacci(10)
        }
        
        let e = self.expectationWithDescription("the computation succeeds")
        
        f.onSuccess { value in
            XCTAssert(value == 55)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testControlFlowSyntaxWithError() {
        
        let f : Future<String> = future { error in
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
        let p = Promise<Int>()
        
        Queue.global.async {
            p.success(fibonacci(10))
        }
        
        let e = self.expectationWithDescription("complete expectation")
        
        p.future.onComplete { (value, error) in
            XCTAssert(value == 55)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testCustomExecutionContext() {
        let f = future({ _ in
            fibonacci(10)
        }, executionContext: ImmediateExecutionContext())
        
        let e = self.expectationWithDescription("immediate success expectation")
        
        f.onSuccess({ value in
            e.fulfill()
        }, executionContext: ImmediateExecutionContext())
        
        self.waitForExpectationsWithTimeout(0, handler: nil)
    }
    
    func testCompletionChaining() {
        let e = self.expectationWithDescription("")
        
        future { _ in
            fibonacci(10)
        }.andThen { size, error -> String in
            if size > 5 {
                return "large"
            }
            return "small"
        }.andThen { label, error -> Bool in
            return label == "large"
        }.onSuccess { numberIsLarge in
            XCTAssert(numberIsLarge)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testTransparentOnFailure() {
        let e = self.expectationWithDescription("")
        
        future { (inout error:NSError?) -> Int in
            return 3
        }.recover { _ in
            return 5
        }.onSuccess { value in
            XCTAssert(value == 3)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testDefaultOnFailure() {
        let e = self.expectationWithDescription("")
        
        future { (inout error:NSError?) -> Int? in
            error = NSError(domain: "NaN", code: 0, userInfo: nil)
            return nil
        }.recoverWith { _ in
            return future { _ in
                fibonacci(5)
            }
        }.onSuccess { value in
            XCTAssert(value == 5)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testOptionalFuture() {
        let r = arc4random()
        
        let f: Future<Int?> = future { error in
            if r % 2 == 0 {
                return 2
            }
            return nil
        }
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
