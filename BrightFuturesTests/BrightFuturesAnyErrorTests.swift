//
//  BrightFuturesAnyErrorTests.swift
//  BrightFutures
//
//  Created by Daniel Leping on 12/22/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import XCTest
import Foundation
import Result
import BrightFutures

enum AnyErrorTestError {
    case Recoverable
    case Terrible
    case Fatal
}

extension AnyErrorTestError : ErrorType {
}

class BrightFuturesAnyErrorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
}

extension BrightFuturesAnyErrorTests {
    func recoverableFuture() -> Future<String, AnyError> {
        return future {
            throw AnyErrorTestError.Recoverable
        }
    }
    
    func successfulFuture() -> Future<String, NoError> {
        return future {
            return "success"
        }
    }
    
    func testThrowingFuture() {
        recoverableFuture().onSuccess { s in
            XCTFail("success block should not get called")
        }.onFailure { e in
            switch e {
                case let e as AnyErrorTestError:
                    XCTAssertEqual(e, AnyErrorTestError.Recoverable)
                default:
                    XCTFail("should not catch different error")
            }
        }
    }
    
    func testRecover() {
        recoverableFuture().recover { e in
            switch e {
                case AnyErrorTestError.Recoverable: return "recovered"
                default: throw e
            }
        }.onSuccess { s in
            XCTAssertEqual(s, "recovered")
        }.onFailure { e in
            XCTFail("should have recovered from error")
        }
    }
    
    func testMapFail() {
        successfulFuture().map { s in
            throw AnyErrorTestError.Fatal
        }.onSuccess { s in
            XCTFail("can not succeed after map has failed")
        }.onFailure { e in
            switch e {
                case let e as AnyErrorTestError:
                    XCTAssertEqual(e, AnyErrorTestError.Fatal)
                default:
                    XCTFail("should not catch different error")
            }
        }
    }
}