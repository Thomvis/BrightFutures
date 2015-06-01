//
//  Helpers.swift
//  BrightFutures
//
//  Created by Thomas Visser on 23/03/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

import XCTest
import BrightFutures

/**
* This extension contains utility methods
*/
extension XCTestCase {
    func expectation() -> XCTestExpectation {
        return self.expectationWithDescription("no description")
    }
    
    func failingFuture<U>() -> Future<U> {
        return future { error in
            usleep(arc4random_uniform(100))
            return .Failure(NSError(domain: "failedFuture", code: 0, userInfo: nil))
        }
    }
    
    func succeedingFuture<U>(val: U) -> Future<U> {
        return future { _ in
            usleep(arc4random_uniform(100))
            return .Success(Box(val))
        }
    }
}

