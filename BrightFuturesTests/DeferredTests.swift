//
//  DeferredTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 14/06/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures

class DeferredTests: XCTestCase {

    func testInitWithResult() {
        let d = Deferred(result: 3)
        XCTAssert(d.result == 3)
    }
    
    func testOnCompleteOnCompletedDeferred() {
        let d = Deferred(result: 3)
        XCTAssert(d.result == 3)
        
        let e = self.expectation()
        d.onComplete { res in
            XCTAssert(res == 3)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
    func testOnComplete() {
        let d = deferred { _ -> Int in
            sleep(1)
            return 3
        }
        XCTAssert(d.result == nil)
        
        let e = self.expectation()
        d.onComplete { res in
            XCTAssert(res == 3)
            e.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(2, handler: nil)
    }
    
}
