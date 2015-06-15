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
        let f = Future<Int, NoError>.succeeded(2)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { result in
            XCTAssert(result == .Success(2))
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
        let f = Future<Void, NoError>.succeeded()
        XCTAssert(f.isCompleted, "void future should be completed")
        XCTAssert(f.isSuccess, "void future should be success")
    }
    
    func testFailedFuture() {
        let error = NSError(domain: "test", code: 0, userInfo: nil)
        let f = Future<Void, NSError>.failed(error)
        
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
        let f = Future<Int, NoError>.completeAfter(1, withResult: Result(value: 3))
        
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
        let f = Future<Int, NoError>.never()
        XCTAssert(!f.isCompleted)
        
        sleep(UInt32(Double(arc4random_uniform(100))/100.0))
        
        XCTAssert(!f.isCompleted)
    }
    
    func testForceTypeSuccess() {
        let f: Future<Double, NoError> = Future.succeeded(NSTimeInterval(3.0))
        let f1: Future<NSTimeInterval, NoError> = f.forceType()
        
        XCTAssertEqual(NSTimeInterval(3.0), f1.result!.value!, "Should be a time interval")
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
        
        let f: Future<NoValue, TestError> = Future.failed(SubError())
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
        Future<Int, NSError>.succeeded(fibonacci(10)).onSuccess { value in
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
    
    func testPromise() {
        let p = Promise<Int, NoError>()
        
        Queue.global.async {
            try! p.success(fibonacci(10))
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
    
    func testCustomExecutionContext() {
        let f = future(context: ImmediateExecutionContext) {
            fibonacci(10)
        }
        
        let e = self.expectationWithDescription("immediate success expectation")
        
        f.onSuccess(context: ImmediateExecutionContext) { value in
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(0, handler: nil)
    }
    
    func testMainExecutionContext() {
        let e = self.expectation()
        
        future { _ -> Int in
            XCTAssert(!NSThread.isMainThread())
            return 1
        }.onSuccess(context: Queue.main.context) { value in
            XCTAssert(NSThread.isMainThread())
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testDefaultCallbackExecutionContextFromMain() {
        let f = Future<Int, NoError>.succeeded(1)
        let e = self.expectation()
        f.onSuccess { _ in
            XCTAssert(NSThread.isMainThread(), "the callback should run on main")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testDefaultCallbackExecutionContextFromBackground() {
        let f = Future<Int, NoError>.succeeded(1)
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
}

// MARK: Functional Composition
/**
* This extension contains all tests related to functional composition
*/
extension BrightFuturesTests {

    func testAndThen() {
        
        var answer = 10
        
        let e = self.expectation()
        
        let f = Future<Int, NoError>.succeeded(4)
        let f1 = f.andThen { result in
            if let val = result.value {
                answer *= val
            }
            return
        }
        
        let f2 = f1.andThen { result in
            answer += 2
        }
        
        f.onSuccess { fval in
            f1.onSuccess { f1val in
                f2.onSuccess { f2val in
                    
                    XCTAssertEqual(fval, f1val, "future value should be passed transparantly")
                    XCTAssertEqual(f1val, f2val, "future value should be passed transparantly")
                    
                    e.fulfill()
                }
                return
            }
            return
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
        
        XCTAssertEqual(42, answer, "andThens should be executed in order")
    }
    
    func testSimpleMap() {
        let e = self.expectation()
        
        func divideByFive(i: Int) -> Int {
            return i / 5
        }
        
        Future<Int, NoError>.succeeded(fibonacci(10)).map(divideByFive).onSuccess { val in
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

        XCTFail("fails with an EXC_BAD_ACCESS")
//        let e1 = self.expectation()
//        
//
//        let f: Future<Int, NoError> = Future<Int, NSError>.failed(NSError(domain: "NaN", code: 0, userInfo: nil)) ?? future(fibonacci(5))
//        
//        f.onSuccess {
//            XCTAssertEqual($0, 5)
//            e1.fulfill()
//        }
//        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZip() {
        let f = Future<Int, NoError>.succeeded(1)
        let f1 = Future<Int, NoError>.succeeded(2)
        
        let e = self.expectation()
        
        f.zip(f1).onSuccess { (a, b) in
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
        
        let f1 = Future<Int, NSError>.succeeded(2)
        
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
        
        let f1 = Future<Int, NSError>.succeeded(2)
        
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
        Future<Int, NoError>.succeeded(3).filter { $0 > 5}.onComplete { result in
            if let err = result.error {
                XCTAssert(err == BrightFuturesError<NoError>.NoSuchElement, "filter should yield no result")
            }
            
            e.fulfill()
        }
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFilterPasses() {
        let e = self.expectation()
        Future<String, NoError>.succeeded("Thomas").filter { $0.hasPrefix("Th") }.onComplete { result in
            if let val = result.value {
                XCTAssert(val == "Thomas", "Filter should pass")
            }
            
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

    func testForcedFuture() {
        var x = 10
        let f: Future<Void, NoError> = future { () -> () in
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
    
    func testFlatMap() {
        let e = self.expectation()
        
        let finalString = "Greg"
        
        let flatMapped = Future<String, NoError>.succeeded("Thomas").flatMap { _ in
            return Future<String, NoError>.succeeded(finalString)
        }
        
        flatMapped.onSuccess { s in
            XCTAssertEqual(s, finalString, "strings are not equal")
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
        XCTFail("does not compile")
//        
//        let n = 10
//        
//        let f = Array(1...n).traverse { i in
//            Future<Int, NoError>.succeeded(fibonacci(i))
//        }
//        
//        let e = self.expectation()
//        
//        f.onSuccess { fibSeq in
//            XCTAssertEqual(fibSeq.count, n)
//            
//            for var i = 0; i < fibSeq.count; i++ {
//                XCTAssertEqual(fibSeq[i], fibonacci(i+1))
//            }
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(4, handler: nil)
    }
    
    func testUtilsTraverseEmpty() {
        XCTFail("does not compile")
        
//        let e = self.expectation()
//        traverse([Int]()) {Future<Int, NoError>.succeeded($0)}.onSuccess { res in
//            XCTAssertEqual(res.count, 0);
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseSingleError() {
        XCTFail("does not compile")
//        let e = self.expectation()
//        
//        let evenFuture: Int -> Future<Bool, NSError> = { i in
//            return future {
//                if i % 2 == 0 {
//                    return Result(value: true)
//                } else {
//                    return Result(error: NSError(domain: "traverse-single-error", code: i, userInfo: nil))
//                }
//            }
//        }
//        
//        let f = traverse([2,4,6,8,9,10], context: Queue.global.context, f: evenFuture)
//            
//            
//        f.onFailure { err in
//            XCTAssertEqual(err.code, 9)
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseMultipleErrors() {
        XCTFail("does not compile")
//        let e = self.expectation()
//        
//        let evenFuture: Int -> Future<Bool, NSError> = { i in
//            return future { err in
//                if i % 2 == 0 {
//                    return Result(value: true)
//                } else {
//                    return Result(error: NSError(domain: "traverse-single-error", code: i, userInfo: nil))
//                }
//            }
//        }
//        
//        traverse([20,22,23,26,27,30], f: evenFuture).onFailure { err in
//            XCTAssertEqual(err.code, 23)
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseWithExecutionContext() {
        XCTFail("does not compile")
//        let e = self.expectation()
//        
//        traverse(Array(1...10), context: Queue.main.context) { _ -> Future<Int, NoError> in
//            XCTAssert(NSThread.isMainThread())
//            return Future.succeeded(1)
//        }.onComplete { _ in
//            e.fulfill()
//        }
//
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsReduce() {
        // create a list of Futures containing the Fibonacci sequence
        let fibonacciList = (1...10).map { val in
            fibonacciFuture(val)
        }

        let e = self.expectation()
        fibonacciList.reduce(0, combine: { $0 + $1 }).onSuccess { val in
            XCTAssertEqual(val, 143)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsReduceWithError() {
        let error = NSError(domain: "fold-with-error", code: 0, userInfo: nil)
        
        // create a list of Futures containing the Fibonacci sequence and one error
        let fibonacciList = (1...10).map { val -> Future<Int, NSError> in
            if val == 3 {
                return Future<Int, NSError>.failed(error)
            } else {
                return fibonacciFuture(val).promoteError()
            }
        }
        
        let e = self.expectation()
        
        fibonacciList.reduce(0, combine: { $0 + $1 }).onFailure { err in
            XCTAssertEqual(err, error)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsReduceWithExecutionContext() {
        let e = self.expectation()
        
        [Future<Int, NoError>(value: 1)].reduce(10, context: Queue.main.context) { acc, elem -> Int in
            XCTAssert(NSThread.isMainThread())
            return acc + elem
        }.onSuccess { val in
            XCTAssertEqual(val, 11)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsReducedWithEmptyList() {
        let z = "NaN"
        
        let e = self.expectation()
        
        [Future<String, NoError>]().reduce(z, combine: { $0 + $1 }).onSuccess { val in
            XCTAssertEqual(val, z)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFirstCompleted() {
        let futures: [Future<Int, NoError>] = [
            Future.completeAfter(0.2, withValue: 3),
            Future.completeAfter(0.3, withValue: 13),
            Future.completeAfter(0.4, withValue: 23),
            Future.completeAfter(0.3, withValue: 4),
            Future.completeAfter(0.1, withValue: 9),
            Future.completeAfter(0.4, withValue: 83),
        ]
        
        let e = self.expectation()
        
        futures.firstCompletedOf().onSuccess { val in
            XCTAssertEqual(val, 9)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsSequence() {
        XCTFail("does not compile")
//        let futures = (1...10).map { fibonacciFuture($0) }
//        
//        let e = self.expectation()
//        
//        sequence(futures).onSuccess { fibs in
//            for (index, num) in fibs.enumerate() {
//                XCTAssertEqual(fibonacci(index+1), num)
//            }
//            
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsSequenceEmpty() {
        XCTFail("does not compile")
//        let e = self.expectation()
//        
//        sequence([Future<Int, NoError>]()).onSuccess { val in
//            XCTAssertEqual(val.count, 0)
//            
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFindSuccess() {
        XCTFail("does not compile")
//        let futures: [Future<Int, NoError>] = [
//            Future.succeeded(1),
//            Future.completeAfter(0.2, withValue: 3),
//            Future.succeeded(5),
//            Future.succeeded(7),
//            Future.completeAfter(0.3, withValue: 8),
//            Future.succeeded(9)
//        ];
//        
//        let f = find(futures, context: Queue.global.context) { val in
//            return val % 2 == 0
//        }
//        
//        let e = self.expectation()
//        
//        f.onSuccess { val in
//            XCTAssertEqual(val, 8, "First matching value is 8")
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFindNoSuchElement() {
        XCTFail("does not compile")
//        let futures: [Future<Int, NoError>] = [
//            Future.succeeded(1),
//            Future.completeAfter(0.2, withValue: 3),
//            Future.succeeded(5),
//            Future.succeeded(7),
//            Future.completeAfter(0.4, withValue: 9),
//        ];
//        
//        let f = find(futures) { val in
//            return val % 2 == 0
//        }
//        
//        let e = self.expectation()
//        
//        f.onFailure { err in
//            XCTAssert(err == BrightFuturesError<NoError>.NoSuchElement, "No matching elements")
//            e.fulfill()
//        }
//        
//        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
 
}

/**
 * This extension contains miscellaneous tests
 */
extension BrightFuturesTests {
    // Creates a lot of futures and adds completion blocks concurrently, which should all fire
    func testStress() {
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
            
            future.onComplete(context: context) { res in
                e.fulfill()
            }
            
            
        }
        
        for _ in 1...instances*10 {
            let f = randomFuture()
            
            let context = randomContext()
            let e = self.expectationWithDescription("future completes in context \(context)")
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                usleep(arc4random_uniform(100))
                
                f.onComplete(context: context) { res in
                    e.fulfill()
                }
            }
        }
        
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
    
    func testSerialCallbacks() {
        let p = Promise<Void, NoError>()
        
        var executingCallbacks = 0
        for _ in 0..<10 {
            let e = self.expectation()
            p.future.onComplete(context: Queue.global.context) { _ in
                XCTAssert(executingCallbacks == 0, "This should be the only executing callback")
                
                executingCallbacks++
                
                // sleep a bit to increase the chances of other callback blocks executing
                NSThread.sleepForTimeInterval(0.06)
                
                executingCallbacks--
                
                e.fulfill()
            }
            
            let e1 = self.expectation()
            p.future.onComplete(context: Queue.main.context) { _ in
                XCTAssert(executingCallbacks == 0, "This should be the only executing callback")
                
                executingCallbacks++
                
                // sleep a bit to increase the chances of other callback blocks executing
                NSThread.sleepForTimeInterval(0.06)
                
                executingCallbacks--
                
                e1.fulfill()
            }
        }
        
        try! p.success()
        
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
        Future<Int, NoError>.succeeded(1).onSuccess(context: Queue.main.context) { val in
            XCTAssertEqual(dispatch_get_specific(&key), valuePointer, "we should now too be on the main queue")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
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
    return Future<Int, NoError>.succeeded(fibonacci(n))
}

func getMutablePointer (object: AnyObject) -> UnsafeMutablePointer<Void> {
    return UnsafeMutablePointer<Void>(bitPattern: Word(ObjectIdentifier(object).uintValue))
}
