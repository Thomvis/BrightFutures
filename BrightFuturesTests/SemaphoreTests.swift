//
//  SemaphoreTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 30/08/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures


class SemaphoreTests: XCTestCase {
    
    func testInit() {
        let s = Semaphore(value: 2)
        XCTAssertEqual(s.wait(.in(0)), .success)
        XCTAssertEqual(s.wait(.in(0)), .success)
        XCTAssertEqual(s.wait(.in(0)), .timedOut)
        s.signal()
        s.signal()
    }
    
}
