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
    
    func testCompletedFuture() {
        let f = Future<Int>.succeeded(2)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { result in
            XCTAssert(result.succeeded())
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
        
        XCTAssert(f.succeeded())
        
        var didCallSucceeded = false
        f.succeeded { val in
            XCTAssertEqual(val, 2)
            didCallSucceeded = true
        }
        
        XCTAssert(didCallSucceeded)
        
        f.failed { _ in
            XCTAssert(false)
        }
        
        f.completed(success: { val in
            XCTAssert(true)
        }, failure: { err in
            XCTAssert(false)
        })
    }
    
    func testFailedFuture() {
        let error = NSError(domain: "test", code: 0, userInfo: nil)
        let f = Future<Bool>.failed(error)
        
        let completeExpectation = self.expectationWithDescription("immediate complete")
        
        f.onComplete { result in
            switch result {
            case .Success(let val):
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
        
        XCTAssert(f.failed())
        
        var didCallFailed = false
        f.failed { err in
            XCTAssertEqual(error, err)
            didCallFailed = true
        }
        
        XCTAssert(didCallFailed)
        
        f.succeeded { _ in
            XCTAssert(false)
        }
        
        f.completed(success: { val in
            XCTAssert(false)
        }, failure: { err in
            XCTAssert(true)
        })
    }
    
    func testCompleteAfterFuture() {
        let f = Future.completeAfter(1, withValue: 3)
        
        XCTAssertFalse(f.completed())
        
        NSThread.sleepForTimeInterval(0.2)

        XCTAssertFalse(f.completed())
        
        NSThread.sleepForTimeInterval(1.0)

        XCTAssert(f.completed())
        
        f.succeeded { val in
            XCTAssertEqual(val, 3);
        }
    }
    
    // this is inherently impossible to test, but we'll give it a try
    func testNeverCompletingFuture() {
        let f = Future<Int>.never()
        XCTAssert(!f.completed())
        
        sleep(UInt32(Double(arc4random_uniform(100))/100.0))
        
        XCTAssert(!f.completed())
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
        
        let f : Future<String?> = future { error in
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
    
    func testAutoClosure() {
        let names = ["Steve", "Tim"]
        
        let f = future(names.count)
        let e = self.expectationWithDescription("")
        
        f.onSuccess { value in
            XCTAssert(value == 2)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
        
        let e1 = self.expectationWithDescription("-")
        future(fibonacci(10)).onSuccess { value in
            XCTAssert(value == 55);
            e1.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testPromise() {
        let p = Promise<Int>()
        
        Queue.global.async {
            p.success(fibonacci(10))
        }
        
        let e = self.expectationWithDescription("complete expectation")
        
        p.future.onComplete { result in
            switch result {
            case .Success(let val):
                XCTAssert(55 == val)
            case .Failure(_):
                XCTAssert(false)
            }
            
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testCustomExecutionContext() {
        let f = future(context: ImmediateExecutionContext()) { _ in
            fibonacci(10)
        }
        
        let e = self.expectationWithDescription("immediate success expectation")
        
        f.onSuccess(context: ImmediateExecutionContext()) { value in
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(0, handler: nil)
    }
    
    func testMainExecutionContext() {
        let e = self.expectationWithDescription("")
        
        future { _ -> Int in
            XCTAssert(!NSThread.isMainThread())
            return 1
        }.onSuccess(context: Queue.main) { value in
            XCTAssert(NSThread.isMainThread())
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testMapSuccess() {
        let e = self.expectationWithDescription("")
        
        future { _ in
            fibonacci(10)
        }.map { value, _ -> String? in
            if value > 5 {
                return "large"
            }
            return "small"
        }.map { sizeString, _ -> Bool? in
            return sizeString == "large"
        }.onSuccess { numberIsLarge in
            XCTAssert(numberIsLarge)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testMapFailure() {
        
        let e = self.expectationWithDescription("")
        
        future { (inout error:NSError?) -> Int? in
            error = NSError(domain: "Tests", code: 123, userInfo: nil)
            return nil
        }.map { number, _ in
            XCTAssert(false, "map should not be evaluated because of failure above")
        }.map { number, _ in
            XCTAssert(false, "this map should also not be evaluated because of failure above")
        }.onFailure { error in
            XCTAssert(error.domain == "Tests")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testAndThen() {
        
        var answer = 10
        
        let e = self.expectationWithDescription("")
        
        let f = future(4)
        let f1 = f.andThen { result in
            result.succeeded { val in
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

    func testTransparentOnFailure() {
        let e = self.expectationWithDescription("")
        
        future { _ in
            3
        }.recover { _ in
            5
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
    
    func testZip() {
        let f = future(1)
        let f1 = future(2)
        
        let e = self.expectationWithDescription("")
        
        f.zip(f1).onSuccess { (let a, let b) in
            XCTAssertEqual(a, 1)
            XCTAssertEqual(b, 2)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZipThisFails() {
        let f = future { error -> Int? in
            sleep(1)
            error = NSError(domain: "test", code: 2, userInfo: nil)
            return nil
        }
        
        let f1 = future(2)
        
        let e = self.expectationWithDescription("")
        
        f.zip(f1).onFailure { error in
            XCTAssert(error.domain == "test")
            XCTAssertEqual(error.code, 2)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZipThatFails() {
        let f = future { error -> Int? in
            sleep(1)
            error = NSError(domain: "tester", code: 3, userInfo: nil)
            return nil
        }
        
        let f1 = future(2)
        
        let e = self.expectationWithDescription("")
        
        f1.zip(f).onFailure { error in
            XCTAssert(error.domain == "tester")
            XCTAssertEqual(error.code, 3)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testZipBothFail() {
        let f = future { error -> Int? in
            sleep(1)
            error = NSError(domain: "f-error", code: 3, userInfo: nil)
            return nil
        }
        
        let f1 = future { error -> Int? in
            sleep(1)
            error = NSError(domain: "f1-error", code: 4, userInfo: nil)
            return nil
        }
        
        let e = self.expectationWithDescription("")
        
        f.zip(f1).onFailure { error in
            XCTAssert(error.domain == "f-error")
            XCTAssertEqual(error.code, 3)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFilterNoSuchElement() {
        let e = self.expectationWithDescription("")
        future(3).filter { $0 > 5}.onComplete { result in
            result.failed { err in
                XCTAssert(err.domain == NoSuchElementError, "filter should yield no result")
            }

            e.fulfill()
        }
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testFilterPasses() {
        let e = self.expectationWithDescription("")
        future("Thomas").filter { $0.hasPrefix("Th") }.onComplete { result in
            result.succeeded { val in
                XCTAssert(val == "Thomas", "Filter should pass")
            }

            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

    func testForcedFuture() {
        var x = 10
        let f: Future<Void> = future { _ in
            NSThread.sleepForTimeInterval(0.5)
            x = 3
            return ()
        }
        f.forced()
        XCTAssertEqual(x, 3)
    }
    
    func testForcedFutureWithTimeout() {
        let f: Future<Void> = future { _ in
            NSThread.sleepForTimeInterval(0.5)
            return ()
        }
        
        XCTAssert(!f.forced(0.2))
        
        XCTAssert(f.forced(0.3))
    }

    func testComposedMapError() {
        let e = self.expectationWithDescription("")

        let error = NSError(domain: "map-error", code: 5, userInfo: nil)
        future("Thomas").map{ (s: String, inout err: NSError?) -> Int? in
            err = error
            return 3
        }.onComplete { result in
            switch(result) {
            case .Failure(let e):
                XCTAssert(error == e, "functional map composition should fail")
            case .Success(_):
                XCTFail("functional map composition should fail")
            }
            e.fulfill()
        }

        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

    func testUtilsTraverseSuccess() {
        let n = 10
        
        let f = FutureUtils.traverse(1...n) { i in
            future(fibonacci(i)).andThen { res in
                res.succeeded(println)
                return
            }
        }
        
        let e = self.expectationWithDescription("")
        
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
        let e = self.expectationWithDescription("")
        FutureUtils.traverse([Int](), {future($0)}).onSuccess { res in
            XCTAssertEqual(res.count, 0);
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseSingleError() {
        let e = self.expectationWithDescription("")
        
        let evenFuture: Int -> Future<Bool> = { i in
            return future { err in
                if i % 2 == 0 {
                    return true
                } else {
                    err = NSError(domain: "traverse-single-error", code: i, userInfo: nil)
                    return false
                }
            }
        }
        
        FutureUtils.traverse([2,4,6,8,9,10], evenFuture).onFailure { err in
            XCTAssertEqual(err.code, 9)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseMultipleErrors() {
        let e = self.expectationWithDescription("")
        
        let evenFuture: Int -> Future<Bool> = { i in
            return future { err in
                if i % 2 == 0 {
                    return true
                } else {
                    err = NSError(domain: "traverse-single-error", code: i, userInfo: nil)
                    return false
                }
            }
        }
        
        FutureUtils.traverse([20,22,23,26,27,30], evenFuture).onFailure { err in
            XCTAssertEqual(err.code, 23)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsTraverseWithExecutionContext() {
        let e = self.expectationWithDescription("")
        
        FutureUtils.traverse(1...10, context: Queue.main) { _ -> Future<Int> in
            XCTAssert(NSThread.isMainThread())
            return future(1)
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
        
        let e = self.expectationWithDescription("")
        
        FutureUtils.fold(fibonacciList, zero: 0, op: { $0 + $1 }).onSuccess { val in
            XCTAssertEqual(val, 143)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFoldWithError() {
        let error = NSError(domain: "fold-with-error", code: 0, userInfo: nil)
        
        // create a list of Futures containing the Fibonacci sequence and one error
        let fibonacciList = (1...10).map { val -> Future<Int> in
            if val == 3 {
                return Future<Int>.failed(error)
            } else {
                return fibonacciFuture(val)
            }
        }
        
        let e = self.expectationWithDescription("")
        
        FutureUtils.fold(fibonacciList, zero: 0, op: { $0 + $1 }).onFailure { err in
            XCTAssertEqual(err, error)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFoldWithExecutionContext() {
        let e = self.expectationWithDescription("")
        
        FutureUtils.fold([Future.succeeded(1)], context: Queue.main, zero: 10) { remainder, elem -> Int in
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
        
        let e = self.expectationWithDescription("")
        
        FutureUtils.fold([Future<String>](), zero: z, op: { $0 + $1 }).onSuccess { val in
            XCTAssertEqual(val, z)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testUtilsFirstCompleted() {
        let futures = [
            Future.completeAfter(0.2, withValue: 3),
            Future.completeAfter(0.3, withValue: 13),
            Future.completeAfter(0.4, withValue: 23),
            Future.completeAfter(0.3, withValue: 4),
            Future.completeAfter(0.1, withValue: 9),
            Future.completeAfter(0.4, withValue: 83),
        ]
        
        let e = self.expectationWithDescription("")
        
        FutureUtils.firstCompletedOf(futures).onSuccess { val in
            XCTAssertEqual(val, 9)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }

    func testFlatMap() {
        let e = self.expectationWithDescription("")

        let finalString = "Greg"
        let flatMapped: Future<String> = future("Thomas").flatMap { _ in
            return future(finalString)
        }

        flatMapped.onSuccess { s in
            XCTAssertEqual(s, finalString, "strings are not equal")
            e.fulfill()
        }

        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
 
    // Creates a lot of futures and adds completion blocks concurrently, which should all fire
    func testStress() {
        let instances = 100;
        var successfulFutures = [Future<Int>]()
        var failingFutures = [Future<Int>]()
        let contexts: [ExecutionContext] = [ImmediateExecutionContext(), Queue.main, Queue.global]
        
        let randomContext: () -> ExecutionContext = { contexts[Int(arc4random_uniform(UInt32(contexts.count)))] }
        let randomFuture: () -> Future<Int> = {
            if arc4random() % 2 == 0 {
                return successfulFutures[Int(arc4random_uniform(UInt32(successfulFutures.count)))]
            } else {
                return failingFutures[Int(arc4random_uniform(UInt32(failingFutures.count)))]
            }
        }
        
        var finalSum = 0;
        
        for _ in 1...instances {
            var future: Future<Int>
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
    
    func failingFuture<U>() -> Future<U> {
        return future { error in
            usleep(arc4random_uniform(100))
            error = NSError(domain: "failedFuture", code: 0, userInfo: nil)
            return nil
        }
    }
    
    func succeedingFuture<U>(val: U) -> Future<U> {
        return future { _ in
            usleep(arc4random_uniform(100))
            return val
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

func fibonacciFuture(n: Int) -> Future<Int> {
    return future(fibonacci(n))
}
