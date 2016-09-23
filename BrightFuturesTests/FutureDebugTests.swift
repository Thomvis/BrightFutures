//
//  FutureDebugTests.swift
//  BrightFutures
//
//  Created by Oleksii on 23/09/2016.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import XCTest
@testable import BrightFutures

class TestLogger: LoggerType {
    var lastLoggedMessage: String?
    
    func log(message: String) {
        lastLoggedMessage = message
    }
}

class FutureDebugTests: XCTestCase {
    
    func testStringLastPathComponent() {
        XCTAssertEqual("/tmp/scratch.tiff".lastPathComponent, "scratch.tiff")
        XCTAssertEqual("/tmp/scratch".lastPathComponent, "scratch")
        XCTAssertEqual("/tmp/".lastPathComponent, "tmp")
        XCTAssertEqual("scratch///".lastPathComponent, "scratch")
        XCTAssertEqual("/".lastPathComponent, "/")
    }
    
}
