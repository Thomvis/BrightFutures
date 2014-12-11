//
//  QueueTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 11/12/14.
//  Copyright (c) 2014 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures

class QueueTests: XCTestCase {

    func testMain() {
        let e = self.expectationWithDescription("")
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            Queue.main.sync {
                XCTAssert(NSThread.isMainThread(), "executing on the main queue should happen on the main thread")
            }
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testSync() {
        var i = 1
        Queue.global.sync {
            i++
        }
        XCTAssert(i == 2, "sync should execute the block synchronously")
    }
    
    func testSyncWithResult() {
        let input = "42"
        let output = Queue.global.sync {
            input
        }
        
        XCTAssertEqual(input, output, "sync should return the return value of the block")
    }
    
    func testAsync() {
        var res = 2
        let e = self.expectationWithDescription("")
        Queue.global.async {
            NSThread.sleepForTimeInterval(1.0)
            res *= 2
            e.fulfill()
        }
        res += 2
        self.waitForExpectationsWithTimeout(2, handler: nil)
        XCTAssertEqual(res, 8, "async should not execute immediately")
    }
    
    func testAsyncFuture() {
        // unfortunately, the compiler is not able to figure out that we want the
        // future-returning async method
        let f: Future<String> = Queue.global.async({
            NSThread.sleepForTimeInterval(1.0)
            return "fibonacci"
        })
        
        let e = self.expectationWithDescription("")
        f.onSuccess { val in
            XCTAssertEqual(val, "fibonacci", "the future should succeed with the value from the async block")
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    

}
