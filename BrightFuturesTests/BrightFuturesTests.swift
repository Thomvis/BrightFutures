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
import Result

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
        let f = Future<Int, NoError>(value: 2)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { result in
            XCTAssert(result.isSuccess)
            completeExpectation.fulfill()
        }
        
        let successExpectation = self.expectationWithDescription("immediate success")
        
        f.onSuccess { value in
            XCTAssert(value == 2, "Computation should be returned")
            successExpectation.fulfill()
        }
        
        f.onFailure { _ in
            XCTFail("failure block should not get called")
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testCompletedVoidFuture() {
        let f = Future<Void, NoError>(value: ())
        XCTAssert(f.isCompleted, "void future should be completed")
        XCTAssert(f.isSuccess, "void future should be success")
    }
    
    func testFailedFuture() {
        let error = NSError(domain: "test", code: 0, userInfo: nil)
        let f = Future<Void, NSError>(error: error)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { result in
            switch result {
            case .Success(_):
                XCTAssert(false)
            case .Failure(let err):
                XCTAssertEqual(err, error)
            }
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
    
    func testCompleteAfterFuture() {
        let f = Future<Int, NoError>(value: 3, delay: 1)
        
        XCTAssertFalse(f.isCompleted)
        
        NSThread.sleepForTimeInterval(0.2)

        XCTAssertFalse(f.isCompleted)
        
        NSThread.sleepForTimeInterval(1.0)

        XCTAssert(f.isCompleted)
        
        if let val = f.value {
            XCTAssertEqual(val, 3);
        }
    }
    
    // this is inherently impossible to test, but we'll give it a try
    func testNeverCompletingFuture() {
        let f = Future<Int, NoError>()
        XCTAssert(!f.isCompleted)
        XCTAssert(!f.isSuccess)
        XCTAssert(!f.isFailure)
        
        sleep(UInt32(Double(arc4random_uniform(100))/100.0))
        
        XCTAssert(!f.isCompleted)
    }
    
    func testFutureWithOther() {
        let p = Promise<Int, NoError>()
        let f = Future(other: p.future)
        
        XCTAssert(!f.isCompleted)
        
        p.success(1)
        
        XCTAssertEqual(f.value, 1);
    }
    
    func testForceTypeSuccess() {
        let f: Future<Double, NoError> = Future(value: NSTimeInterval(3.0))
        let f1: Future<NSTimeInterval, NoError> = f.forceType()
        
        XCTAssertEqual(NSTimeInterval(3.0), f1.result!.value!, "Should be a time interval")
    }
    
    func testAsVoid() {
        let f = future(fibonacci(10))
        
        let e = self.expectation()
        f.asVoid().onComplete { v in
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testForceTypeFailure() {
        class TestError: ErrorType {
            var _domain: String { return "TestError" }
            var _code: Int { return 1 }
        }
        
        class SubError: TestError {
            override var _domain: String { return "" }
            override var _code: Int { return 2 }
        }
        
        let f: Future<NoValue, TestError> = Future(error: SubError())
        let f1: Future<NoValue, SubError> = f.forceType()
        
        XCTAssertEqual(f1.result!.error!._code, 2, "Should be a SubError")
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
        
        let f : Future<String?, NSError> = future {
            Result(error: NSError(domain: "NaN", code: 0, userInfo: nil))
        }
        
        let failureExpectation = self.expectationWithDescription("failure expected")
        
        f.onFailure { error in
            XCTAssert(error.domain == "NaN")
            failureExpectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(3, handler: nil)
    }
    
    func testAutoClosure() {
        let names = ["Steve", "Tim"]
        
        let f = future(names.count)
        let e = self.expectation()
        
        f.onSuccess { value in
            XCTAssert(value == 2)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
        
        let e1 = self.expectation()
        Future<Int, NSError>(value: fibonacci(10)).onSuccess { value in
            XCTAssert(value == 55);
            e1.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testAutoClosureWithResult() {
        let f = future(Result<Int, NoError>(value:2))
        let e = self.expectation()
        
        f.onSuccess { value in
            XCTAssert(value == 2)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
        
        let f1 = future(Result<Int,BrightFuturesError<NoError>>(error: .NoSuchElement))
        let e1 = self.expectation()

        f1.onFailure { error in
            XCTAssert(error == BrightFuturesError<NoError>.NoSuchElement)
            e1.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

    
    func testCustomExecutionContext() {
        let f = future(ImmediateExecutionContext) {
            fibonacci(10)
        }
        
        let e = self.expectationWithDescription("immediate success expectation")
        
        f.onSuccess(ImmediateExecutionContext) { value in
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(0, handler: nil)
    }
    
    func testMainExecutionContext() {
        let e = self.expectation()
        
        future { _ -> Int in
            XCTAssert(!NSThread.isMainThread())
            return 1
        }.onSuccess(Queue.main.context) { value in
            XCTAssert(NSThread.isMainThread())
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testDefaultCallbackExecutionContextFromMain() {
        let f = Future<Int, NoError>(value: 1)
        let e = self.expectation()
        f.onSuccess { _ in
            XCTAssert(NSThread.isMainThread(), "the callback should run on main")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testDefaultCallbackExecutionContextFromBackground() {
        let f = Future<Int, NoError>(value: 1)
        let e = self.expectation()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            f.onSuccess { _ in
                XCTAssert(!NSThread.isMainThread(), "the callback should not be on the main thread")
                e.fulfill()
            }
            return
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testPromoteErrorNoSuchElement() {
        let f: Future<Int, BrightFuturesError<TestError>> = future(3).filter { _ in false }.promoteError()
        
        let e = self.expectation()
        f.onFailure { err in
            XCTAssert(err == BrightFuturesError<TestError>.NoSuchElement)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testWrapCompletionHandlerValueError() {
        func testCall(val: Int, completionHandler: (Int?, TestError?) -> Void) {
            if val == 0 {
                completionHandler(nil, TestError.JustAnError)
            } else {
                completionHandler(val, nil)
            }
        }
        
        let f = future { testCall(2, completionHandler: $0) }
        XCTAssertEqual(f.value!, 2)
        
        let f2 = future { testCall(0, completionHandler: $0) }
        XCTAssert(f2.error! == .External(TestError.JustAnError))
    }
    
    func testWrapCompletionHandlerValue() {
        func testCall(val: Int, completionHandler: Int -> Void) {
            completionHandler(val)
        }
        
        func testCall2(val: Int, completionHandler: Int? -> Void) {
            completionHandler(nil)
        }
        
        let f = future { testCall(3, completionHandler: $0) }
        XCTAssertEqual(f.value!, 3)
        
        let f2 = future { testCall2(4, completionHandler:  $0) }
        XCTAssert(f2.value! == nil)
    }
    
    func testWrapCompletionHandlerError() {
        func testCall(val: Int, completionHandler: TestError? -> Void) {
            if val == 0 {
                completionHandler(nil)
            } else {
                completionHandler(TestError.JustAnError)
            }
        }
        
        let f = future { testCall(0, completionHandler: $0) }
        XCTAssert(f.error == nil)
        
        let f2 = future { testCall(2, completionHandler: $0) }
        XCTAssert(f2.error == TestError.JustAnError)
    }
    
    func testWrapResultCompletionHandlerValue() {
        func testCall(val: Int, completionHandler: Result<Int,NSError> -> Void) {
            completionHandler(.Success(val))
        }
        
        func testCall2(val: Int, completionHandler: Result<Int,TestError> -> Void) {
            completionHandler(.Failure(.JustAnError))
        }
        
        let f = future { testCall(3, completionHandler: $0) }
        XCTAssertEqual(f.value!, 3)
        
        let f2 = future { testCall2(4, completionHandler:  $0) }
        XCTAssert(f2.error! == .JustAnError)
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
        
        let f = Future<Int, NoError>(value: 4)
        let f1 = f.andThen { result in
            if let val = result.value {
                answer *= val
            }
        }
        
        let f2 = f1.andThen { result in
            answer += 2
        }
        
        f1.onSuccess { fval in
            f1.onSuccess { f1val in
                f2.onSuccess { f2val in
                    
                    XCTAssertEqual(fval, f1val, "future value should be passed transparently")
                    XCTAssertEqual(f1val, f2val, "future value should be passed transparantly")
                    
                    e.fulfill()
                }
            }
        }
        
        self.waitForExpectationsWithTimeout(20, handler: nil)
        
        XCTAssertEqual(42, answer, "andThens should be executed in order")
    }
    
    func testSimpleMap() {
        let e = self.expectation()
        
        func divideByFive(i: Int) -> Int {
            return i / 5
        }
        
        Future<Int, NoError>(value: fibonacci(10)).map(divideByFive).onSuccess { val in
            XCTAssertEqual(val, 11, "The 10th fibonacci number (55) divided by 5 is 11")
            e.fulfill()
            return
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testMapSuccess() {
        let e = self.expectation()
        
        future {
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
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testMapFailure() {
        
        let e = self.expectation()
        
        future { () -> Result <Int,NSError> in
            Result(error: NSError(domain: "Tests", code: 123, userInfo: nil))
        }.map { number in
            XCTAssert(false, "map should not be evaluated because of failure above")
        }.map { number in
            XCTAssert(false, "this map should also not be evaluated because of failure above")
        }.onFailure { error in
            XCTAssert(error.domain == "Tests")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

    func testRecover() {
        let e = self.expectation()
        Future<Int, TestError>(error: TestError.JustAnError).recover { _ in
            return 3
        }.onSuccess { val in
            XCTAssertEqual(val, 3)
            e.fulfill()
        }
    
        let recov: () -> Int = {
            return 5
        }
        
        let e1 = self.expectation()
        (Future<Int, TestError>(error: TestError.JustAnError) ?? recov()).onSuccess { value in
            XCTAssert(value == 5)
            e1.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testSkippedRecover() {
        let e = self.expectation()
        
        future { _ in
            3
        }.recover { _ in
            XCTFail("recover task should not be executed")
            return 5
        }.onSuccess { value in
            XCTAssert(value == 3)
            e.fulfill()
        }
        
        let e1 = self.expectation()
        
        
        let recov: () -> Int = {
            XCTFail("recover task should not be executed")
            return 5
        }
        
        (future(3) ?? recov()).onSuccess { value in
            XCTAssert(value == 3)
            e1.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testRecoverWith() {
        let e = self.expectation()
        
        future {
            Result(error: NSError(domain: "NaN", code: 0, userInfo: nil))
        }.recoverWith { _ in
            return future { _ in
                fibonacci(5)
            }
        }.onSuccess { value in
            XCTAssert(value == 5)
            e.fulfill()
        }
        
        let e1 = self.expectation()
        
        let f: Future<Int, NoError> = Future<Int, NSError>(error: NSError(domain: "NaN", code: 0, userInfo: nil)) ?? future(fibonacci(5))
        
        f.onSuccess {
            XCTAssertEqual($0, 5)
            e1.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testMapError() {
        let e = self.expectation()
        
        Future<Int, TestError>(error: .JustAnError).mapError { _ in
            return TestError.JustAnotherError
        }.onFailure { error in
            XCTAssertEqual(error, TestError.JustAnotherError)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZip() {
        let f = Future<Int, NoError>(value: 1)
        let f1 = Future<Int, NoError>(value: 2)
        
        let e = self.expectation()
        
        f.zip(f1).onSuccess { (let a, let b) in
            XCTAssertEqual(a, 1)
            XCTAssertEqual(b, 2)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZipThisFails() {
        let f: Future<Bool, NSError> = future { () -> Result<Bool,NSError> in
            sleep(1)
            return Result(error: NSError(domain: "test", code: 2, userInfo: nil))
        }
        
        let f1 = Future<Int, NSError>(value: 2)
        
        let e = self.expectation()
        
        f.zip(f1).onFailure { error in
            XCTAssert(error.domain == "test")
            XCTAssertEqual(error.code, 2)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZipThatFails() {
        let f = future { () -> Result<Int,NSError> in
            sleep(1)
            return Result(error: NSError(domain: "tester", code: 3, userInfo: nil))
        }
        
        let f1 = Future<Int, NSError>(value: 2)
        
        let e = self.expectation()
        
        f1.zip(f).onFailure { error in
            XCTAssert(error.domain == "tester")
            XCTAssertEqual(error.code, 3)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZipBothFail() {
        let f = future { () -> Result<Int,NSError> in
            sleep(1)
            return Result(error: NSError(domain: "f-error", code: 3, userInfo: nil))
        }
        
        let f1 = future { () -> Result<Int,NSError> in
            sleep(1)
            return Result(error: NSError(domain: "f1-error", code: 4, userInfo: nil))
        }
        
        let e = self.expectation()
        
        f.zip(f1).onFailure { error in
            XCTAssert(error.domain == "f-error")
            XCTAssertEqual(error.code, 3)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFilterNoSuchElement() {
        let e = self.expectation()
        Future<Int, NoError>(value: 3).filter { $0 > 5}.onComplete { result in
            if let err = result.error {
                XCTAssert(err == BrightFuturesError<NoError>.NoSuchElement, "filter should yield no result")
            }
            
            e.fulfill()
        }
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFilterPasses() {
        let e = self.expectation()
        Future<String, NoError>(value: "Thomas").filter { $0.hasPrefix("Th") }.onComplete { result in
            if let val = result.value {
                XCTAssert(val == "Thomas", "Filter should pass")
            }
            
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFilterFailedFuture() {
        let f = Future<Int, TestError>(error: TestError.JustAnError)
        
        let e = self.expectation()
        f.filter { _ in false }.onFailure { error in
            XCTAssert(error == BrightFuturesError(external: TestError.JustAnError))
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

    func testForcedFuture() {
        var x = 10
        let f: Future<Void, NoError> = future { () -> Void in
            NSThread.sleepForTimeInterval(0.5)
            x = 3
        }
        f.forced()
        XCTAssertEqual(x, 3)
    }
    
    func testForcedFutureWithTimeout() {
        let f: Future<Void, NoError> = future {
            NSThread.sleepForTimeInterval(0.5)
        }
        
        XCTAssert(f.forced(0.1) == nil)
        
        XCTAssert(f.forced(0.5) != nil)
    }
    
    func testForcingCompletedFuture() {
        let f = Future<Int, NoError>(value: 1)
        XCTAssertEqual(f.forced().value!, 1)
    }
    
    func testDelay() {
        let t0 = CACurrentMediaTime()
        let f = Future<Int, NoError>(value: 1).delay(0);
        XCTAssertFalse(f.isCompleted)
        var isAsync = false
        
        let e = self.expectation()
        f.onComplete(ImmediateExecutionContext) { _ in
            XCTAssert(NSThread.isMainThread())
            XCTAssert(isAsync)
            XCTAssert(CACurrentMediaTime() - t0 >= 0)
        }.delay(1).onComplete { _ in
            XCTAssert(NSThread.isMainThread())
            XCTAssert(CACurrentMediaTime() - t0 >= 1)
            e.fulfill()
        }
        isAsync = true
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testDelayOnGlobalQueue() {
        let e = self.expectation()
        Queue.global.async {
            Future<Int, NoError>(value: 1).delay(0).onComplete(ImmediateExecutionContext) { _ in
                XCTAssert(!NSThread.isMainThread())
                e.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFlatMap() {
        let e = self.expectation()
        
        let finalString = "Greg"
        
        let flatMapped = Future<String, NoError>(value: "Thomas").flatMap { _ in
            return Future<String, NoError>(value: finalString)
        }
        
        flatMapped.onSuccess { s in
            XCTAssertEqual(s, finalString, "strings are not equal")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
	
	func testFlatMapByPassingFunction() {
		let e = self.expectation()
		
		func toString(n: Int) -> Future<String, NoError> {
			return Future<String, NoError>(value: "\(n)")
		}
		
		let n = 1
		let flatMapped = Future<Int, NoError>(value: n).flatMap(toString)
		
		flatMapped.onSuccess { s in
			XCTAssertEqual(s, "\(n)", "strings are not equal")
			e.fulfill()
		}
		
		self.waitForExpectationsWithTimeout(2, handler: nil)
	}
    
    func testFlatMapResult() {
        let e = self.expectation()
        
        Future<Int, NoError>(value: 3).flatMap { _ in
            Result(value: 22)
        }.onSuccess { val in
            XCTAssertEqual(val, 22)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
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
            Future<Int, NoError>(value: fibonacci(i))
        }
        
        let e = self.expectation()
        
        f.onSuccess { fibSeq in
            XCTAssertEqual(fibSeq.count, n)
            
            for var i = 0; i < fibSeq.count; i++ {
                XCTAssertEqual(fibSeq[i], fibonacci(i+1))
            }
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    func testUtilsTraverseEmpty() {
        let e = self.expectation()
        [Int]().traverse { Future<Int, NoError>(value: $0) }.onSuccess { res in
            XCTAssertEqual(res.count, 0);
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseSingleError() {
        let e = self.expectation()
        
        let evenFuture: Int -> Future<Bool, NSError> = { i in
            return future {
                if i % 2 == 0 {
                    return Result(value: true)
                } else {
                    return Result(error: NSError(domain: "traverse-single-error", code: i, userInfo: nil))
                }
            }
        }
        
        let f = [2,4,6,8,9,10].traverse(Queue.global.context, f: evenFuture)
            
            
        f.onFailure { err in
            XCTAssertEqual(err.code, 9)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseMultipleErrors() {
        let e = self.expectation()
        
        let evenFuture: Int -> Future<Bool, NSError> = { i in
            return future { err in
                if i % 2 == 0 {
                    return Result(value: true)
                } else {
                    return Result(error: NSError(domain: "traverse-single-error", code: i, userInfo: nil))
                }
            }
        }
        
        [20,22,23,26,27,30].traverse(f: evenFuture).onFailure { err in
            XCTAssertEqual(err.code, 23)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseWithExecutionContext() {
        let e = self.expectation()
        
        Array(1...10).traverse(Queue.main.context) { _ -> Future<Int, NoError> in
            XCTAssert(NSThread.isMainThread())
            return Future(value: 1)
        }.onComplete { _ in
            e.fulfill()
        }

        self.waitForExpectationsWithTimeout(2, handler: nil)
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
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
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
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFoldWithExecutionContext() {
        let e = self.expectation()
        
        [Future<Int, NoError>(value: 1)].fold(Queue.main.context, zero: 10) { remainder, elem -> Int in
            XCTAssert(NSThread.isMainThread())
            return remainder + elem
        }.onSuccess { val in
            XCTAssertEqual(val, 11)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFoldWithEmptyList() {
        let z = "NaN"
        
        let e = self.expectation()
        
        [Future<String, NoError>]().fold(z, f: { $0 + $1 }).onSuccess { val in
            XCTAssertEqual(val, z)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFirstCompleted() {
        let futures: [Future<Int, NoError>] = [
            Future(value: 3, delay: 0.2),
            Future(value: 13, delay: 0.3),
            Future(value: 23, delay: 0.4),
            Future(value: 4, delay: 0.3),
            Future(value: 9, delay: 0.1),
            Future(value: 83, delay: 0.4),
        ]
        
        let e = self.expectation()
        
        futures.firstCompleted().onSuccess { val in
            XCTAssertEqual(val, 9)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsSequence() {
        let futures = (1...10).map { fibonacciFuture($0) }
        
        let e = self.expectation()
        
        futures.sequence().onSuccess { fibs in
            for (index, num) in fibs.enumerate() {
                XCTAssertEqual(fibonacci(index+1), num)
            }
            
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsSequenceEmpty() {
        let e = self.expectation()
        
        [Future<Int, NoError>]().sequence().onSuccess { val in
            XCTAssertEqual(val.count, 0)
            
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFindSuccess() {
        let futures: [Future<Int, NoError>] = [
            Future(value: 1),
            Future(value: 3, delay: 0.2),
            Future(value: 5),
            Future(value: 7),
            Future(value: 8, delay: 0.3),
            Future(value: 9)
        ];
        
        let f = futures.find(Queue.global.context) { val in
            return val % 2 == 0
        }
        
        let e = self.expectation()
        
        f.onSuccess { val in
            XCTAssertEqual(val, 8, "First matching value is 8")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFindNoSuchElement() {
        let futures: [Future<Int, NoError>] = [
            Future(value: 1),
            Future(value: 3, delay: 0.2),
            Future(value: 5),
            Future(value: 7),
            Future(value: 9, delay: 0.4),
        ];
        
        let f = futures.find { val in
            return val % 2 == 0
        }
        
        let e = self.expectation()
        
        f.onFailure { err in
            XCTAssert(err == BrightFuturesError<NoError>.NoSuchElement, "No matching elements")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFindWithError() {
        let f = [Future<Bool, TestError>(error: .JustAnError)].find(ImmediateExecutionContext) { $0 }
        XCTAssert(f.error! == BrightFuturesError<TestError>.External(.JustAnError));
    }

    func testPromoteError() {
        let _: Future<Int, TestError> = Future<Int, NoError>().promoteError()
    }
    
    func testPromoteBrightFuturesError() {
        let _: Future<Int, BrightFuturesError<TestError>> = Future<Int, BrightFuturesError<NoError>>(error: .NoSuchElement).promoteError()
        let _: Future<Int, BrightFuturesError<TestError>> = Future<Int, BrightFuturesError<NoError>>(error: .InvalidationTokenInvalidated).promoteError()
        let _: Future<Int, BrightFuturesError<TestError>> = Future<Int, BrightFuturesError<NoError>>(error: .IllegalState).promoteError()
    }
    
    func testPromoteValue() {
        let _: Future<Int, TestError> = Future<NoValue, TestError>().promoteValue()
    }
 
    func testFlatten() {
        let a: Async<Int> = Async(result: Async(result: 2)).flatten()
        a.onComplete(ImmediateExecutionContext) { val in
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
        self.measureBlock {
            let instances = 100;
            var successfulFutures = [Future<Int, NSError>]()
            var failingFutures = [Future<Int, NSError>]()
            let contexts: [ExecutionContext] = [ImmediateExecutionContext, Queue.main.context, Queue.global.context]
            
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
                let e = self.expectationWithDescription("future completes in context \(context)")
                
                future.onComplete(context) { res in
                    e.fulfill()
                }
                
                
            }
            
            for _ in 1...instances*10 {
                let f = randomFuture()
                
                let context = randomContext()
                let e = self.expectationWithDescription("future completes in context \(context)")
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    usleep(arc4random_uniform(100))
                    
                    f.onComplete(context) { res in
                        e.fulfill()
                    }
                }
            }
            
            self.waitForExpectationsWithTimeout(10, handler: nil)
        }
    }
    
    func testSerialCallbacks() {
        let p = Promise<Void, NoError>()
        
        var executingCallbacks = 0
        for _ in 0..<10 {
            let e = self.expectation()
            p.future.onComplete(Queue.global.context) { _ in
                XCTAssert(executingCallbacks == 0, "This should be the only executing callback")
                
                executingCallbacks++
                
                // sleep a bit to increase the chances of other callback blocks executing
                NSThread.sleepForTimeInterval(0.06)
                
                executingCallbacks--
                
                e.fulfill()
            }
            
            let e1 = self.expectation()
            p.future.onComplete(Queue.main.context) { _ in
                XCTAssert(executingCallbacks == 0, "This should be the only executing callback")
                
                executingCallbacks++
                
                // sleep a bit to increase the chances of other callback blocks executing
                NSThread.sleepForTimeInterval(0.06)
                
                executingCallbacks--
                
                e1.fulfill()
            }
        }
        
        p.success()
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    // Test for https://github.com/Thomvis/BrightFutures/issues/18
    func testCompletionBlockOnMainQueue() {
        var key = "mainqueuespecifickey"
        let value = "value"
        let valuePointer = getMutablePointer(value)
    
        
        dispatch_queue_set_specific(dispatch_get_main_queue(), &key, valuePointer, nil)
        XCTAssertEqual(dispatch_get_specific(&key), valuePointer, "value should have been set on the main (i.e. current) queue")
        
        let e = self.expectation()
        Future<Int, NoError>(value: 1).onSuccess(Queue.main.context) { val in
            XCTAssertEqual(dispatch_get_specific(&key), valuePointer, "we should now too be on the main queue")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testRelease() {
        weak var f: Future<Int, NoError>? = nil
        
        var f1: Future<Int, NoError>? = Future<Int, NoError>().map { $0 }.recover { _ in
            0
        }.onSuccess { _ in }.onComplete { _ in }
        
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
    
}

/**
 * This extension contains utility methods used in the tests above
 */
extension XCTestCase {
    func expectation() -> XCTestExpectation {
        return self.expectationWithDescription("no description")
    }
    
    func failingFuture<U>() -> Future<U, NSError> {
        return future { error in
            usleep(arc4random_uniform(100))
            return Result(error: NSError(domain: "failedFuture", code: 0, userInfo: nil))
        }
    }
    
    func succeedingFuture<U>(val: U) -> Future<U, NSError> {
        return future { _ in
            usleep(arc4random_uniform(100))
            return Result(value: val)
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

func fibonacciFuture(n: Int) -> Future<Int, NoError> {
    return Future<Int, NoError>(value: fibonacci(n))
}

func getMutablePointer (object: AnyObject) -> UnsafeMutablePointer<Void> {
    return UnsafeMutablePointer<Void>(bitPattern: Int(ObjectIdentifier(object).uintValue))
}
