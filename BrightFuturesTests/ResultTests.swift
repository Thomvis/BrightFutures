//
//  ResultTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 20/12/14.
//  Copyright (c) 2014 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures

class ResultTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSuccess() {
        let result = Result.Success(Box(3))
        XCTAssert(result.isSuccess)
        XCTAssertFalse(result.isFailure)
        XCTAssertEqual(result.value!, 3)
        XCTAssertNil(result.error)
        
        let result1 = Result(4)
        XCTAssert(result1.isSuccess)
        XCTAssertFalse(result1.isFailure)
        XCTAssertEqual(result1.value!, 4)
        XCTAssertNil(result1.error)
    }
    
    func testFailure() {
        let error = NSError()
        let result = Result<Int>.Failure(error)
        XCTAssert(result.isFailure)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.error!, error)
        XCTAssertNil(result.value)
    }
    
}
