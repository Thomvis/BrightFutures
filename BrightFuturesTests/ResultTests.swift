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
import Result
import BrightFutures

extension Result {
    var isSuccess: Bool {
        return self.analysis(ifSuccess: { _ in return true }, ifFailure: { _ in return false })
    }
    var isFailure: Bool {
        return !isSuccess
    }
}

class ResultTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSuccess() {
        let result = Result<Int,NSError>(value: 3)
        XCTAssert(result.isSuccess)
        XCTAssertFalse(result.isFailure)
        XCTAssertEqual(result.value!, 3)
        XCTAssertNil(result.error)
        
        let result1 = Result<Int,NSError>(value: 4)
        XCTAssert(result1.isSuccess)
        XCTAssertFalse(result1.isFailure)
        XCTAssertEqual(result1.value!, 4)
        XCTAssertNil(result1.error)
    }
    
    func testFailure() {
        let error = NSError(domain: "TestDomain", code: 2, userInfo: nil)
        let result = Result<Int, NSError>(error: error)
        XCTAssert(result.isFailure)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.error!, error)
        XCTAssertNil(result.value)
    }
    
    func testMapSuccess() {
        let r = Result<Int,NSError>(value: 2).map { i -> Bool in
            XCTAssertEqual(i, 2)
            return i % 2 == 0
        }
        
        XCTAssertTrue(r.isSuccess)
        XCTAssertEqual(r.value!, true)
    }
    
    func testMapFailure() {
        let r = Result<Int, NSError>(error: NSError(domain: "error", code: 1, userInfo: nil)).map { i -> Int in
            XCTAssert(false, "map should not get called if the result failed")
            return i * 2
        }
        
        XCTAssert(r.isFailure)
        XCTAssertEqual(r.error!.domain, "error")
    }
    
    func testFlatMapResultSuccess() {
        let r = divide(20, 5).flatMap {
            divide($0, 2)
        }
        
        XCTAssertEqual(r.value!, 2)
    }
    
    func testFlatMapResultFailure() {
        let r = divide(20, 0).flatMap { i -> Result<Int, MathError> in
            XCTAssert(false, "flatMap should not get called if the result failed")
            return divide(i, 2)
        }
        
        XCTAssert(r.isFailure)
        XCTAssertEqual(r.error!, MathError.DivisionByZero)
    }

    func testFlatMapFutureSuccess() {
        let f = flatMap(divide(100, 10)) { i -> Future<Int, MathError> in
            return future {
                fibonacci(i)
            }.promoteError()
        }
        
        let e = self.expectation()
        
        f.onSuccess { i in
            XCTAssertEqual(i, 55)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFlatMapFutureFailure() {
        let f = flatMap(divide(100, 0)) { i -> Future<Int, MathError> in
            XCTAssert(false, "flatMap should not get called if the result failed")
            return future {
                fibonacci(i)
            }.promoteError()
        }
        
        let e = self.expectation()
        
        f.onFailure { err in
            XCTAssertEqual(err, MathError.DivisionByZero)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testSequenceSuccess() {
        let results: [Result<Int, MathError>] = (1...10).map { i in
            return divide(123, i)
        }
        
        let result: Result<[Int], MathError> = sequence(results)
        
        let outcome = [123, 61, 41, 30, 24, 20, 17, 15, 13, 12]
        XCTAssertEqual(result.value!, outcome)
    }
    
    func testSequenceFailure() {
        let results: [Result<Int, MathError>] = (-10...10).map { i in
            return divide(123, i)
        }
        
        let r = sequence(results)
        XCTAssert(r.isFailure)
        XCTAssertEqual(r.error!, MathError.DivisionByZero)
    }

    func testRecoverNeeded() {
        let r = divide(10, 0).recover(2)
        XCTAssertEqual(r, 2)
        
        XCTAssertEqual(divide(10, 0) ?? 2, 2)
    }

    func testRecoverUnneeded() {
        let r = divide(10, 3).recover(10)
        XCTAssertEqual(r, 3)
        
        XCTAssertEqual(divide(10, 3) ?? 10, 3)
    }
}

enum MathError: ErrorType {
    case DivisionByZero
}

func divide(a: Int, _ b: Int) -> Result<Int, MathError> {
    if (b == 0) {
        return Result(error: .DivisionByZero)
    }
    
    return Result(value: a / b)
}
