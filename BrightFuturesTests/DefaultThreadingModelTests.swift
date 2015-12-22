//
//  DefaultThreadingModelTests.swift
//  BrightFutures
//
//  Created by Matthew Healy on 22/12/2015.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import XCTest
@testable import BrightFutures

class DefaultThreadingModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        resetDefaultThreadingModel()
    }
    
    override func tearDown() {
        resetDefaultThreadingModel()
        super.tearDown()
    }
    
    private func resetDefaultThreadingModel() {
        DefaultThreadingModel = .AsynchronousOnCurrentThread
    }

    func test_Synchronous_ContextIsImmediateExecution() {
        let testee = StandardThreadingModel.Synchronous
        let context = testee.context
        var taskRun = false
        context({ taskRun = true })
        XCTAssertTrue(taskRun)
    }
    
    func test_AsynchronousOnCurrentThread_ContextIsAsyncExecution() {
        let testee = StandardThreadingModel.AsynchronousOnCurrentThread
        let context = testee.context
        var taskRun = false
        let isCalledExpectation = expectationWithDescription("Task was run")
        context({
            taskRun = true
            isCalledExpectation.fulfill()
        })
        XCTAssertFalse(taskRun, "Task was not run asynchronously")
        waitForExpectationsWithTimeout(2000, handler: nil)
    }
    
    func test_DefaultThreadingModel_IsAsynchronousOnCurrentThreadByDefault() {
        let testee = BrightFutures.DefaultThreadingModel
        XCTAssertEqual(testee, StandardThreadingModel.AsynchronousOnCurrentThread)
    }
    
    func test_DefaultThreadingModel_CanBeSetToSynchronous() {
        DefaultThreadingModel = .Synchronous
        XCTAssertEqual(DefaultThreadingModel, StandardThreadingModel.Synchronous)
    }

}
