//
//  NSOperationQueueTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 19/09/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import XCTest
@testable import BrightFutures

class NSOperationQueueTests: XCTestCase {

    func testMaxConcurrentOperationCount() {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 12
        var i = 0
        
        let sem = DispatchSemaphore(value: 1)
        
        (0...100).forEach { n in
            let e = self.expectation()
            queue.context {
                sem.context {
                    i += 1
                }
                XCTAssert(i <= queue.maxConcurrentOperationCount)
                
                sem.context {
                    i -= 1
                }
                XCTAssert(i >= 0)
                
                e.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 5, handler: nil)
        XCTAssertEqual(i, 0)
    }
    
}
