//
//  FutureDebugTests.swift
//  BrightFutures
//
//  Created by Oleksii on 23/09/2016.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import XCTest
import Result
@testable import BrightFutures

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
    let line: UInt = #line
    let function = #function
    
    func testStringLastPathComponent() {
        XCTAssertEqual("/tmp/scratch.tiff".lastPathComponent, "scratch.tiff")
        XCTAssertEqual("/tmp/scratch".lastPathComponent, "scratch")
        XCTAssertEqual("/tmp/".lastPathComponent, "tmp")
        XCTAssertEqual("scratch///".lastPathComponent, "scratch")
        XCTAssertEqual("/".lastPathComponent, "/")
    }
    
    func testDebugFutureSuccess() {
        let logger = TestLogger()
        let f = Future<Void, NoError>(value: ()).debug(logger: logger, file: file, line: line, function: function)
        let expectedMessage = "\(file.lastPathComponent) at line \(line), func: \(function) - future succeeded"
        let debugExpectation = self.expectation(description: "debugLogged")
        
        f.onSuccess {
            XCTAssertEqual(logger.lastLoggedMessage, expectedMessage)
            debugExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDebugFutureFailure() {
        let logger = TestLogger()
        let f = Future<Void, NSError>(error: error).debug(logger: logger, file: file, line: line, function: function)
        let debugExpectation = self.expectation(description: "debugLogged")
        let expectedMessage = "\(file.lastPathComponent) at line \(line), func: \(function) - future failed"
        
        f.onFailure { _ in
            XCTAssertEqual(logger.lastLoggedMessage, expectedMessage)
            debugExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDebugFutureSuccessWithIdentifier() {
        let logger = TestLogger()
        
        let f = Future<Void, NoError>(value: ()).debug(testIdentifier, logger: logger)
        let debugExpectation = self.expectation(description: "debugLogged")
        
        f.onSuccess {
            XCTAssertEqual(logger.lastLoggedMessage, "Future \(self.testIdentifier) succeeded")
            debugExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDebugFutureFailureWithIdentifier() {
        let logger = TestLogger()
        let f = Future<Void, NSError>(error: error).debug(testIdentifier, logger: logger)
        let debugExpectation = self.expectation(description: "debugLogged")
        
        f.onFailure { _ in
            XCTAssertEqual(logger.lastLoggedMessage, "Future \(self.testIdentifier) failed")
            debugExpectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
}
