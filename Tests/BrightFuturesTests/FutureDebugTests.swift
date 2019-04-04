//
//  FutureDebugTests.swift
//  BrightFutures
//
//  Created by Oleksii on 23/09/2016.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures

class TestLogger: LoggerType {
    var lastLoggedMessage: String?
    
    func log(message: String) {
        lastLoggedMessage = message
    }
}

class FutureDebugTests: XCTestCase {
    let testIdentifier = "testFutureIdentifier"
    let error = NSError(domain: "test", code: 0, userInfo: nil)
    let file = #file
    let fileName = (#file as NSString).lastPathComponent
    let line: UInt = #line
    let function = #function
    
    func testDebugFuture() {
        let logger = TestLogger()
        let f = Future<Void, Never>(value: ()).debug(logger: logger, file: file, line: line, function: function)
        let expectedMessage = "\(fileName) at line \(line), func: \(function) - future completed"
        let debugExpectation = self.expectation(description: "debugLogged")
        
        f.onSuccess { _ in
            XCTAssertEqual(logger.lastLoggedMessage, expectedMessage)
            debugExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDebugFutureWithIdentifier() {
        let logger = TestLogger()
        
        let f = Future<Void, Never>(value: ()).debug(testIdentifier, logger: logger)
        let debugExpectation = self.expectation(description: "debugLogged")
        
        f.onSuccess { _ in
            XCTAssertEqual(logger.lastLoggedMessage, "Future \(self.testIdentifier) completed")
            debugExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
}
