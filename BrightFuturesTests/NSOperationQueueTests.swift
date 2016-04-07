//
//  NSOperationQueueTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 19/09/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures

class NSOperationQueueTests: XCTestCase {

    func testMaxConcurrentOperationCount() {
        let queue = NSOperationQueue()
        queue.maxConcurrentOperationCount = 12
        var i = 0
        
        let sem = Semaphore()
        
        (0...100).forEach { n in
            let e = self.expectation()
            queue.context {
                sem.execute {
                    i += 1
                }
                XCTAssert(i <= queue.maxConcurrentOperationCount)
                
                sem.execute {
                    i -= 1
                }
                XCTAssert(i >= 0)
                
                e.fulfill()
            }
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
        XCTAssertEqual(i, 0)
    }
    
}
