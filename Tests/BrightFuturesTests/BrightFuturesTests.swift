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
import BrightFutures

class BrightFuturesTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}

extension BrightFuturesTests {
    func testCompletedFuture() {
        let f = Future<Int, Never>(value: 2)
        
        let completeExpectation = self.expectation(description: "immediate complete")
        
        f.onComplete { result in
            XCTAssert(result.isSuccess)
            completeExpectation.fulfill()
        }
        
        let successExpectation = self.expectation(description: "immediate success")
        
        f.onSuccess { value in
            XCTAssert(value == 2, "Computation should be returned")
            successExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testCompletedVoidFuture() {
        let f = Future<Void, Never>(value: ())
        XCTAssert(f.isCompleted, "void future should be completed")
        XCTAssert(f.isSuccess, "void future should be success")
    }
    
    func testFailedFuture() {
        let error = NSError(domain: "test", code: 0, userInfo: nil)
        let f = Future<Void, NSError>(error: error)
        
        let completeExpectation = self.expectation(description: "immediate complete")
        
        f.onComplete { result in
            switch result {
            case .success(_):
                XCTAssert(false)
            case .failure(let err):
                XCTAssertEqual(err, error)
            }
            completeExpectation.fulfill()
        }
        
        let failureExpectation = self.expectation(description: "immediate failure")
        
        f.onFailure { err in
            XCTAssert(err == error)
            failureExpectation.fulfill()
        }
        
        f.onSuccess { value in
            XCTFail("success should not be called")
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testCompleteAfterFuture() {
        let f = Future<Int, Never>(value: 3, delay: 1.second)
        
        XCTAssertFalse(f.isCompleted)
        
        Thread.sleep(forTimeInterval: 0.2)

        XCTAssertFalse(f.isCompleted)
        
        Thread.sleep(forTimeInterval: 1.0)

        XCTAssert(f.isCompleted)
        
        if let val = f.value {
            XCTAssertEqual(val, 3);
        }
    }
    
    func testFailedAfterFuture() {
        let f = Future<Int, TestError>(error: .justAnError, delay: 1.second)
        
        XCTAssertFalse(f.isCompleted)
        
        Thread.sleep(forTimeInterval: 0.2)

        XCTAssertFalse(f.isCompleted)
        
        Thread.sleep(forTimeInterval: 1.0)

        XCTAssert(f.isCompleted)
        
        if let error = f.error {
            switch error {
            case .justAnError:
                XCTAssert(true)
            case .justAnotherError:
                XCTAssert(false)
            }
        }
    }
    
    // this is inherently impossible to test, but we'll give it a try
    func testNeverCompletingFuture() {
        let f = Future<Int, Never>()
        XCTAssert(!f.isCompleted)
        XCTAssert(!f.isSuccess)
        XCTAssert(!f.isFailure)
        
        sleep(UInt32(Double(arc4random_uniform(100))/100.0))
        
        XCTAssert(!f.isCompleted)
    }
    
    func testFutureWithOther() {
        let p = Promise<Int, Never>()
        let f = Future(other: p.future)
        
        XCTAssert(!f.isCompleted)
        
        p.success(1)
        
        XCTAssertEqual(f.value, 1);
    }
    
    func testForceTypeSuccess() {
        let f: Future<Double, Never> = Future(value: Foundation.TimeInterval(3.0))
        let f1: Future<Foundation.TimeInterval, Never> = f.forceType()
        
        XCTAssertEqual(TimeInterval(3.0), f1.result!.value!, "Should be a time interval")
    }
    
    func testAsVoid() {
        let f = Future<Int, Never>(value: 10)
        
        let e = self.expectation()
        f.asVoid().onComplete { v in
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testForceTypeFailure() {
        class TestError: Error {
            var _domain: String { return "TestError" }
            var _code: Int { return 1 }
        }
        
        class SubError: TestError {
            override var _domain: String { return "" }
            override var _code: Int { return 2 }
        }
        
        let f: Future<Never, TestError> = Future(error: SubError())
        let f1: Future<Never, SubError> = f.forceType()
        
        XCTAssertEqual(f1.result!.error!._code, 2, "Should be a SubError")
    }
    
    func testDefaultCallbackExecutionContextFromMain() {
        let f = Future<Int, Never>(value: 1)
        let e = self.expectation()
        f.onSuccess { _ in
            XCTAssert(Thread.isMainThread, "the callback should run on main")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDefaultCallbackExecutionContextFromBackground() {
        let f = Future<Int, Never>(value: 1)
        let e = self.expectation()
        DispatchQueue.global().async {
            f.onSuccess { _ in
                XCTAssert(!Thread.isMainThread, "the callback should not be on the main thread")
                e.fulfill()
            }
            return
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testPromoteErrorNoSuchElement() {
        let f: Future<Int, BrightFuturesError<TestError>> = Future(value: 3).filter { _ in false }.promoteError()
        
        let e = self.expectation()
        f.onFailure { err in
            XCTAssert(err == BrightFuturesError<TestError>.noSuchElement)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testWrapCompletionHandlerValueError() {
        func testCall(_ val: Int, completionHandler: (Int?, TestError?) -> Void) {
            if val == 0 {
                completionHandler(nil, TestError.justAnError)
            } else {
                completionHandler(val, nil)
            }
        }
        
        let f = BrightFutures.materialize { (handler: (Int?, TestError?) -> Void) -> Void in
            testCall(2, completionHandler: handler)
        }
        XCTAssertEqual(f.value!, 2)
        
        let f2 = BrightFutures.materialize { (handler: (Int?, TestError?) -> Void) -> Void in
            testCall(0, completionHandler: handler)
        }
        XCTAssert(f2.error! == TestError.justAnError)
    }
    
    func testWrapCompletionHandlerValue() {
        func testCall(_ val: Int, completionHandler: (Int) -> Void) {
            completionHandler(val)
        }
        
        func testCall2(_ val: Int, completionHandler: (Int?) -> Void) {
            completionHandler(nil)
        }
        
        let f = BrightFutures.materialize { testCall(3, completionHandler: $0) }
        XCTAssertEqual(f.value!, 3)
        
        let f2 = BrightFutures.materialize { testCall2(4, completionHandler:  $0) }
        XCTAssert(f2.value! == nil)
    }
    
    func testWrapCompletionHandlerError() {
        func testCall(_ val: Int, completionHandler: (TestError?) -> Void) {
            if val == 0 {
                completionHandler(nil)
            } else {
                completionHandler(TestError.justAnError)
            }
        }
        
        let f = BrightFutures.materialize { testCall(0, completionHandler: $0) }
        XCTAssert(f.error == nil)
        
        let f2 = BrightFutures.materialize { testCall(2, completionHandler: $0) }
        XCTAssert(f2.error! == TestError.justAnError)
    }
}

// MARK: Functional Composition
/**
* This extension contains all tests related to functional composition
*/
extension BrightFuturesTests {

    func testAndThen() {
        
        var answer = 10
        
        let e = self.expectation()
        
        let f = Future<Int, Never>(value: 4)
        let f1 = f.andThen { result in
            if let val = result.value {
                answer *= val
            }
        }
        
        let f2 = f1.andThen { result in
            answer += 2
        }
        
        f.onSuccess { fval in
            f1.onSuccess { f1val in
                f2.onSuccess { f2val in
                    
                    XCTAssertEqual(fval, f1val, "future value should be passed transparently")
                    XCTAssertEqual(f1val, f2val, "future value should be passed transparently")
                    
                    e.fulfill()
                }
            }
        }
        
        self.waitForExpectations(timeout: 20, handler: nil)
        
        XCTAssertEqual(42, answer, "andThens should be executed in order")
    }
    
    func testSimpleMap() {
        let e = self.expectation()
        
        func divideByFive(_ i: Int) -> Int {
            return i / 5
        }
        
        Future<Int, Never>(value: fibonacci(10)).map(divideByFive).onSuccess { val in
            XCTAssertEqual(val, 11, "The 10th fibonacci number (55) divided by 5 is 11")
            e.fulfill()
            return
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testMapSuccess() {
        let e = self.expectation()
        
        DispatchQueue.global().asyncValue {
            fibonacci(10)
        }.map { value -> String in
            if value > 5 {
                return "large"
            }
            return "small"
        }.map { sizeString -> Bool in
            return sizeString == "large"
        }.onSuccess { numberIsLarge in
            XCTAssert(numberIsLarge)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testMapFailure() {
        
        let e = self.expectation()
        
        DispatchQueue.global().asyncResult { () -> Result <Int,NSError> in
            .failure(NSError(domain: "Tests", code: 123, userInfo: nil))
        }.map { number in
            XCTAssert(false, "map should not be evaluated because of failure above")
        }.map { number in
            XCTAssert(false, "this map should also not be evaluated because of failure above")
        }.onFailure { error in
            XCTAssert(error.domain == "Tests")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }

    func testMapByKeyPath() {
        struct S {
            let a: Int
        }

        let e = self.expectation()

        DispatchQueue.global().asyncValue {
            S(a: 10)
        }.map(\.a).onSuccess { keyPathValue in
            XCTAssertEqual(keyPathValue, 10)
            e.fulfill()
        }

        self.waitForExpectations(timeout: 2, handler: nil)
    }

    func testRecover() {
        let e = self.expectation()
        Future<Int, TestError>(error: TestError.justAnError).recover { _ in
            return 3
        }.onSuccess { val in
            XCTAssertEqual(val, 3)
            e.fulfill()
        }
    
        let recov: () -> Int = {
            return 5
        }
        
        let e1 = self.expectation()
        (Future<Int, TestError>(error: TestError.justAnError) ?? recov()).onSuccess { value in
            XCTAssert(value == 5)
            e1.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testSkippedRecover() {
        let e = self.expectation()
        
        DispatchQueue.global().asyncValue {
            3
        }.onSuccess { value in
            XCTAssert(value == 3)
            e.fulfill()
        }
        
        let e1 = self.expectation()
        
        
        let recov: () -> Int = {
            XCTFail("recover task should not be executed")
            return 5
        }
        
        (Future<Int, Never>(value: 3) ?? recov()).onSuccess { value in
            XCTAssert(value == 3)
            e1.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testRecoverWith() {
        let e = self.expectation()
        
        DispatchQueue.global().asyncResult {
            .failure(NSError(domain: "NaN", code: 0, userInfo: nil))
        }.recoverWith { _ in
            return DispatchQueue.global().asyncValue {
                fibonacci(5)
            }
        }.onSuccess { value in
            XCTAssert(value == 5)
            e.fulfill()
        }
        
        let e1 = self.expectation()
        
        let f: Future<Int, Never> = Future<Int, NSError>(error: NSError(domain: "NaN", code: 0, userInfo: nil)) ?? Future(value: fibonacci(5))
        
        f.onSuccess {
            XCTAssertEqual($0, 5)
            e1.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testMapError() {
        let e = self.expectation()
        
        Future<Int, TestError>(error: .justAnError).mapError { _ in
            return TestError.justAnotherError
        }.onFailure { error in
            XCTAssertEqual(error, TestError.justAnotherError)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testZip() {
        let f = Future<Int, Never>(value: 1)
        let f1 = Future<Int, Never>(value: 2)
        
        let e = self.expectation()
        
        f.zip(f1).onSuccess { (arg) in
            let (a, b) = arg
            XCTAssertEqual(a, 1)
            XCTAssertEqual(b, 2)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testZipThisFails() {
        let f: Future<Bool, NSError> = DispatchQueue.global().asyncResult { () -> Result<Bool,NSError> in
            sleep(1)
            return .failure(NSError(domain: "test", code: 2, userInfo: nil))
        }
        
        let f1 = Future<Int, NSError>(value: 2)
        
        let e = self.expectation()
        
        f.zip(f1).onFailure { error in
            XCTAssert(error.domain == "test")
            XCTAssertEqual(error.code, 2)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testZipThatFails() {
        let f = DispatchQueue.global().asyncResult { () -> Result<Int,NSError> in
            sleep(1)
            return .failure(NSError(domain: "tester", code: 3, userInfo: nil))
        }
        
        let f1 = Future<Int, NSError>(value: 2)
        
        let e = self.expectation()
        
        f1.zip(f).onFailure { error in
            XCTAssert(error.domain == "tester")
            XCTAssertEqual(error.code, 3)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testZipBothFail() {
        let f = DispatchQueue.global().asyncResult { () -> Result<Int,NSError> in
            sleep(1)
            return .failure(NSError(domain: "f-error", code: 3, userInfo: nil))
        }
        
        let f1 = DispatchQueue.global().asyncResult { () -> Result<Int,NSError> in
            sleep(1)
            return .failure(NSError(domain: "f1-error", code: 4, userInfo: nil))
        }
        
        let e = self.expectation()
        
        f.zip(f1).onFailure { error in
            XCTAssert(error.domain == "f-error")
            XCTAssertEqual(error.code, 3)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testFilterNoSuchElement() {
        let e = self.expectation()
        Future<Int, Never>(value: 3).filter { $0 > 5}.onComplete { result in
            if let err = result.error {
                XCTAssert(err == BrightFuturesError<Never>.noSuchElement, "filter should yield no result")
            }
            
            e.fulfill()
        }
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testFilterPasses() {
        let e = self.expectation()
        Future<String, Never>(value: "Thomas").filter { $0.hasPrefix("Th") }.onComplete { result in
            if let val = result.value {
                XCTAssert(val == "Thomas", "Filter should pass")
            }
            
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testFilterFailedFuture() {
        let f = Future<Int, TestError>(error: TestError.justAnError)
        
        let e = self.expectation()
        f.filter { _ in false }.onFailure { error in
            XCTAssert(error == BrightFuturesError(external: TestError.justAnError))
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }

    func testForcedFuture() {
        var x = 10
        let f: Future<Void, Never> = DispatchQueue.global().asyncValue { () -> Void in
            Thread.sleep(forTimeInterval: 0.5)
            x = 3
        }
        let _ = f.forced()
        XCTAssertEqual(x, 3)
    }
    
    func testForcedFutureWithTimeout() {
        let f: Future<Void, Never> = DispatchQueue.global().asyncValue {
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        XCTAssert(f.forced(100.milliseconds.fromNow) == nil)
        
        XCTAssert(f.forced(500.milliseconds.fromNow) != nil)
    }
    
    func testForcingCompletedFuture() {
        let f = Future<Int, Never>(value: 1)
        XCTAssertEqual(f.forced().value!, 1)
    }
    
    func testDelay() {
        let t0 = CACurrentMediaTime()
        let f = Future<Int, Never>(value: 1).delay(0.seconds);
        XCTAssertFalse(f.isCompleted)
        var isAsync = false
        
        let e = self.expectation()
        f.onComplete(immediateExecutionContext) { _ in
            XCTAssert(Thread.isMainThread)
            XCTAssert(isAsync)
            XCTAssert(CACurrentMediaTime() - t0 >= 0)
        }.delay(1.second).onComplete { _ in
            XCTAssert(Thread.isMainThread)
            XCTAssert(CACurrentMediaTime() - t0 >= 1)
            e.fulfill()
        }
        isAsync = true
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDelayOnGlobalQueue() {
        let e = self.expectation()
        DispatchQueue.global().async {
            Future<Int, Never>(value: 1).delay(0.seconds).onComplete(immediateExecutionContext) { _ in
                XCTAssert(!Thread.isMainThread)
                e.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDelayChaining() {
        let e = self.expectation()
        let t0 = CACurrentMediaTime()
        let _ = Future<Void, Never>(value: ())
            .delay(1.second)
            .andThen { _ in XCTAssert(CACurrentMediaTime() - t0 >= 1) }
            .delay(1.second)
            .andThen { _ in
                XCTAssert(CACurrentMediaTime() - t0 >= 2)
                e.fulfill()
            }

        self.waitForExpectations(timeout: 3, handler: nil)
    }

    func testFlatMap() {
        let e = self.expectation()
        
        let finalString = "Greg"
        
        let flatMapped = Future<String, Never>(value: "Thomas").flatMap { _ in
            return Future<String, Never>(value: finalString)
        }
        
        flatMapped.onSuccess { s in
            XCTAssertEqual(s, finalString, "strings are not equal")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
	
	func testFlatMapByPassingFunction() {
		let e = self.expectation()
		
		func toString(_ n: Int) -> Future<String, Never> {
			return Future<String, Never>(value: "\(n)")
		}
		
		let n = 1
		let flatMapped = Future<Int, Never>(value: n).flatMap(toString)
		
		flatMapped.onSuccess { s in
			XCTAssertEqual(s, "\(n)", "strings are not equal")
			e.fulfill()
		}
		
		self.waitForExpectations(timeout: 2, handler: nil)
	}
    
    func testFlatMapResult() {
        let e = self.expectation()
        
        Future<Int, Never>(value: 3).flatMap { _ in
             Result.success(22)
        }.onSuccess { val in
            XCTAssertEqual(val, 22)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
}

// MARK: FutureUtils
/**
 * This extension contains all tests related to FutureUtils
 */
extension BrightFuturesTests {
    func testUtilsTraverseSuccess() {
        let n = 10
        
        let f = (Array(1...n)).traverse { i in
            Future<Int, Never>(value: fibonacci(i))
        }
        
        let e = self.expectation()
        
        f.onSuccess { fibSeq in
            XCTAssertEqual(fibSeq.count, n)
            
            for i in 0 ..< fibSeq.count {
                XCTAssertEqual(fibSeq[i], fibonacci(i+1))
            }
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 4, handler: nil)
    }
    
    func testUtilsTraverseEmpty() {
        let e = self.expectation()
        [Int]().traverse { Future<Int, Never>(value: $0) }.onSuccess { res in
            XCTAssertEqual(res.count, 0);
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsTraverseSingleError() {
        let e = self.expectation()
        
        let evenFuture: (Int) -> Future<Bool, NSError> = { i in
            return DispatchQueue.global().asyncResult {
                if i % 2 == 0 {
                    return .success(true)
                } else {
                    return .failure(NSError(domain: "traverse-single-error", code: i, userInfo: nil))
                }
            }
        }
        
        let f = [2,4,6,8,9,10].traverse(DispatchQueue.global().context, f: evenFuture)
            
            
        f.onFailure { err in
            XCTAssertEqual(err.code, 9)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsTraverseMultipleErrors() {
        let e = self.expectation()
        
        let evenFuture: (Int) -> Future<Bool, NSError> = { i in
            return DispatchQueue.global().asyncResult {
                if i % 2 == 0 {
                    return .success(true)
                } else {
                    return .failure(NSError(domain: "traverse-single-error", code: i, userInfo: nil))
                }
            }
        }
        
        [20,22,23,26,27,30].traverse(f: evenFuture).onFailure { err in
            XCTAssertEqual(err.code, 23)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsTraverseWithExecutionContext() {
        let e = self.expectation()
        
        Array(1...10).traverse(DispatchQueue.main.context) { _ -> Future<Int, Never> in
            XCTAssert(Thread.isMainThread)
            return Future(value: 1)
        }.onComplete { _ in
            e.fulfill()
        }

        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsLargeSequence() {
        let promises = (1...500).map { _ in Promise<Int,Never>() }
        let futures = promises.map { $0.future }
        
        let e = self.expectation()
        
        
        futures.sequence().onSuccess { nums in
            for (index, num) in nums.enumerated() {
                XCTAssertEqual(index, num)
            }
            
            e.fulfill()
        }
        
        for (i, promise) in promises.enumerated() {
            DispatchQueue.global().async {
                promise.success(i)
            }
        }
        
        self.waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testUtilsFold() {
        // create a list of Futures containing the Fibonacci sequence
        let fibonacciList = (1...10).map { val in
            fibonacciFuture(val)
        }
        
        let e = self.expectation()
        
        fibonacciList.fold(0, f: { $0 + $1 }).onSuccess { val in
            XCTAssertEqual(val, 143)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFoldWithError() {
        let error = NSError(domain: "fold-with-error", code: 0, userInfo: nil)
        
        // create a list of Futures containing the Fibonacci sequence and one error
        let fibonacciList = (1...10).map { val -> Future<Int, NSError> in
            if val == 3 {
                return Future<Int, NSError>(error: error)
            } else {
                return fibonacciFuture(val).promoteError()
            }
        }
        
        let e = self.expectation()
        
        fibonacciList.fold(0, f: { $0 + $1 }).onFailure { err in
            XCTAssertEqual(err, error)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFoldWithExecutionContext() {
        let e = self.expectation()
        
        [Future<Int, Never>(value: 1)].fold(DispatchQueue.main.context, zero: 10) { remainder, elem -> Int in
            XCTAssert(Thread.isMainThread)
            return remainder + elem
        }.onSuccess { val in
            XCTAssertEqual(val, 11)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFoldWithEmptyList() {
        let z = "NaN"
        
        let e = self.expectation()
        
        [Future<String, Never>]().fold(z, f: { $0 + $1 }).onSuccess { val in
            XCTAssertEqual(val, z)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFirstCompleted() {
        let futures: [Future<Int, Never>] = [
            Future(value: 3, delay: 500.milliseconds),
            Future(value: 13, delay: 300.milliseconds),
            Future(value: 23, delay: 400.milliseconds),
            Future(value: 4, delay: 300.milliseconds),
            Future(value: 9, delay: 100.milliseconds),
            Future(value: 83, delay: 400.milliseconds),
        ]
        
        let e = self.expectation()
        
        futures.firstCompleted().onSuccess { val in
            XCTAssertEqual(val, 9)
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFirstCompletedWithError() {
        let futures: [Future<Int, TestError>] = [
            Future(value: 3, delay: 500.milliseconds),
            Future(error: .justAnotherError, delay: 300.milliseconds),
            Future(value: 23, delay: 400.milliseconds),
            Future(value: 4, delay: 300.milliseconds),
            Future(error: .justAnError, delay: 100.milliseconds),
            Future(value: 83, delay: 400.milliseconds),
        ]
        
        let e = self.expectation()
        
        futures.firstCompleted().onSuccess { _ in
            XCTAssert(false)
            e.fulfill()
        }.onFailure { error in
            switch error {
            case .justAnError:
                XCTAssert(true)
            case .justAnotherError:
                XCTAssert(false)
            }
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsSequence() {
        let futures = (1...10).map { fibonacciFuture($0) }
        
        let e = self.expectation()
        
        futures.sequence().onSuccess { fibs in
            for (index, num) in fibs.enumerated() {
                XCTAssertEqual(fibonacci(index+1), num)
            }
            
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsSequenceEmpty() {
        let e = self.expectation()
        
        [Future<Int, Never>]().sequence().onSuccess { val in
            XCTAssertEqual(val.count, 0)
            
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFindSuccess() {
        let futures: [Future<Int, Never>] = [
            Future(value: 1),
            Future(value: 3, delay: 200.milliseconds),
            Future(value: 5),
            Future(value: 7),
            Future(value: 8, delay: 300.milliseconds),
            Future(value: 9)
        ];
        
        let f = futures.find(DispatchQueue.global().context) { val in
            return val % 2 == 0
        }
        
        let e = self.expectation()
        
        f.onSuccess { val in
            XCTAssertEqual(val, 8, "First matching value is 8")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFindNoSuchElement() {
        let futures: [Future<Int, Never>] = [
            Future(value: 1),
            Future(value: 3, delay: 200.milliseconds),
            Future(value: 5),
            Future(value: 7),
            Future(value: 9, delay: 400.milliseconds),
        ];
        
        let f = futures.find { val in
            return val % 2 == 0
        }
        
        let e = self.expectation()
        
        f.onFailure { err in
            XCTAssert(err == BrightFuturesError<Never>.noSuchElement, "No matching elements")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testUtilsFindWithError() {
        let f = [Future<Bool, TestError>(error: .justAnError)].find(immediateExecutionContext) { $0 }
        XCTAssert(f.error! == BrightFuturesError<TestError>.external(.justAnError));
    }

    func testPromoteError() {
        let _: Future<Int, TestError> = Future<Int, Never>().promoteError()
    }
    
    func testPromoteBrightFuturesError() {
        let _: Future<Int, BrightFuturesError<TestError>> = Future<Int, BrightFuturesError<Never>>(error: .noSuchElement).promoteError()
        let _: Future<Int, BrightFuturesError<TestError>> = Future<Int, BrightFuturesError<Never>>(error: .invalidationTokenInvalidated).promoteError()
        let _: Future<Int, BrightFuturesError<TestError>> = Future<Int, BrightFuturesError<Never>>(error: .illegalState).promoteError()
    }
    
    func testPromoteValue() {
        let _: Future<Int, TestError> = Future<Never, TestError>().promoteValue()
    }
 
    func testFlatten() {
        let a: Async<Int> = Async(result: Async(result: 2)).flatten()
        a.onComplete(immediateExecutionContext) { val in
            XCTAssertEqual(val, 2)
        }
    }
    
}

/**
 * This extension contains miscellaneous tests
 */
extension BrightFuturesTests {
    // Creates a lot of futures and adds completion blocks concurrently, which should all fire
    func testStress() {
        self.measure {
            let instances = 100;
            var successfulFutures = [Future<Int, NSError>]()
            var failingFutures = [Future<Int, NSError>]()
            let contexts: [ExecutionContext] = [immediateExecutionContext, DispatchQueue.main.context, DispatchQueue.global().context]
            
            let randomContext: () -> ExecutionContext = { contexts[Int(arc4random_uniform(UInt32(contexts.count)))] }
            let randomFuture: () -> Future<Int, NSError> = {
                if arc4random() % 2 == 0 {
                    return successfulFutures[Int(arc4random_uniform(UInt32(successfulFutures.count)))]
                } else {
                    return failingFutures[Int(arc4random_uniform(UInt32(failingFutures.count)))]
                }
            }
            
            var finalSum = 0;
            
            for _ in 1...instances {
                var future: Future<Int, NSError>
                if arc4random() % 2 == 0 {
                    let futureResult: Int = Int(arc4random_uniform(10))
                    finalSum += futureResult
                    future = self.succeedingFuture(futureResult)
                    successfulFutures.append(future)
                } else {
                    future = self.failingFuture()
                    failingFutures.append(future)
                }
                
                let context = randomContext()
                let e = self.expectation(description: "future completes in context \(String(describing: context))")
                
                future.onComplete(context) { res in
                    e.fulfill()
                }
                
                
            }
            
            for _ in 1...instances*10 {
                let f = randomFuture()
                
                let context = randomContext()
                let e = self.expectation(description: "future completes in context \(String(describing: context))")
                
                DispatchQueue.global().async {
                    usleep(arc4random_uniform(100))
                    
                    f.onComplete(context) { res in
                        e.fulfill()
                    }
                }
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }
    
    func testSerialCallbacks() {
        let p = Promise<Void, Never>()
        
        var executingCallbacks = 0
        for _ in 0..<10 {
            let e = self.expectation()
            p.future.onComplete(DispatchQueue.global().context) { _ in
                XCTAssert(executingCallbacks == 0, "This should be the only executing callback")
                
                executingCallbacks += 1
                
                // sleep a bit to increase the chances of other callback blocks executing
                Thread.sleep(forTimeInterval: 0.06)
                
                executingCallbacks -= 1
                
                e.fulfill()
            }
            
            let e1 = self.expectation()
            p.future.onComplete(DispatchQueue.main.context) { _ in
                XCTAssert(executingCallbacks == 0, "This should be the only executing callback")
                
                executingCallbacks += 1
                
                // sleep a bit to increase the chances of other callback blocks executing
                Thread.sleep(forTimeInterval: 0.06)
                
                executingCallbacks -= 1
                
                e1.fulfill()
            }
        }
        
        p.success(())
        
        self.waitForExpectations(timeout: 5, handler: nil)
    }
    
    // Test for https://github.com/Thomvis/BrightFutures/issues/18
    func testCompletionBlockOnMainQueue() {
        let key = DispatchSpecificKey<String>()
        let value = "value"
    
        
        DispatchQueue.main.setSpecific(key: key, value: value)
        XCTAssertEqual(DispatchQueue.getSpecific(key: key), value, "value should have been set on the main (i.e. current) queue")
        
        let e = self.expectation()
        Future<Int, Never>(value: 1).onSuccess(DispatchQueue.main.context) { val in
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), value, "we should now too be on the main queue")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testRelease() {
        weak var f: Future<Int, Never>? = nil
        
        var f1: Future<Int, Never>? = Future<Int, Never>().map { $0 }.onSuccess { _ in }.onComplete { _ in }
        
        f = f1
        XCTAssertNotNil(f1);
        XCTAssertNotNil(f);
        f1 = nil
        XCTAssertNil(f1)
        XCTAssertNil(f)
    }
    
    func testDescription() {
        let a = Async(result: 1)
        XCTAssertEqual(a.description, "Async<Int>(Optional(1))")
        XCTAssertEqual(a.debugDescription, a.description)
    }

    func testDynamicMemberLookup() {
        struct Person {
            let name: String
        }

        let f = Future<Person, Never>(value: Person(name: "Thomas"))
        let f1 = f.name
        XCTAssertEqual(f1.value!, "Thomas")
    }
    
}

/**
 * This extension contains utility methods used in the tests above
 */
extension XCTestCase {
    func expectation() -> XCTestExpectation {
        return self.expectation(description: "no description")
    }
    
    func failingFuture<U>() -> Future<U, NSError> {
        return DispatchQueue.global().asyncResult {
            usleep(arc4random_uniform(100))
            return .failure(NSError(domain: "failedFuture", code: 0, userInfo: nil))
        }
    }
    
    func succeedingFuture<U>(_ val: U) -> Future<U, NSError> {
        return DispatchQueue.global().asyncResult {
            usleep(arc4random_uniform(100))
            return .success(val)
        }
    }
}

func fibonacci(_ n: Int) -> Int {
    switch n {
    case 0...1:
        return n
    default:
        return fibonacci(n - 1) + fibonacci(n - 2)
    }
}

func fibonacciFuture(_ n: Int) -> Future<Int, Never> {
    return Future<Int, Never>(value: fibonacci(n))
}

func getMutablePointer (_ object: AnyObject) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(bitPattern: Int(UInt(bitPattern: ObjectIdentifier(object))))!
}
