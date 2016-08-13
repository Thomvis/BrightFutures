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
import Result

class QueueTests: XCTestCase {

    func testMain() {
        let e = self.expectation(description: "")
        DispatchQueue.global().async {
            Queue.main.sync {
                XCTAssert(Thread.isMainThread, "executing on the main queue should happen on the main thread")
            }
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testSync() {
        var i = 1
        Queue.global.sync {
            i += 1
        }
        XCTAssert(i == 2, "sync should execute the block synchronously")
    }
    
    func testSyncWithResult() {
        let input = "42"
        let output: String = Queue.global.sync {
            input
        }
        
        XCTAssertEqual(input, output, "sync should return the return value of the block")
    }
    
    func testSyncThrowsNone() {
        let t: () throws -> Void = { }
        do {
            try Queue.global.sync(t)
            XCTAssert(true)
        } catch _ {
            XCTFail()
        }
    }
    
    func testSyncThrowsError() {
        let t: () throws -> Void = { throw TestError.justAnError }
        do {
            try Queue.global.sync(t)
            XCTFail()
        } catch TestError.justAnError {
            XCTAssert(true)
        } catch _ {
            XCTFail()
        }
    }
    
    func testAsync() {
        var res = 2
        let e = self.expectation(description: "")
        Queue.global.async {
            Thread.sleep(forTimeInterval: 1.0)
            res *= 2
            e.fulfill()
        }
        res += 2
        self.waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(res, 8, "async should not execute immediately")
    }
    
    func testAsyncFuture() {
        let f = Queue.global.asyncValue { () -> String in
            Thread.sleep(forTimeInterval: 1.0)
            return "fibonacci"
        }
        
        let e = self.expectation(description: "")
        f.onSuccess { val in
            XCTAssertEqual(val, "fibonacci", "the future should succeed with the value from the async block")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testAfter() {
        var res = 2
        let e = self.expectation(description: "")
        Queue.global.after(.in(1.0)) {
            res *= 2
            e.fulfill()
        }
        res += 2
        self.waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(res, 8, "delay should not execute immediately")
    }

    func testAfterFuture() {
        // unfortunately, the compiler is not able to figure out that we want the
        // future-returning async method
        let f: Future<String, NoError> = Queue.global.after(.in(1.0)) {
            return "fibonacci"
        }
        
        let e = self.expectation(description: "")
        f.onSuccess { val in
            XCTAssertEqual(val, "fibonacci", "the future should succeed with the value from the async block")
            e.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }

}
