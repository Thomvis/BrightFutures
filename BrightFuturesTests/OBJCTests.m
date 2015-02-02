//
//  OBJCTests.m
//  BrightFutures
//
//  Created by Thomas Visser on 29/01/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

#import <XCTest/XCTest.h>
@import BrightFutures;

@interface OBJCTests : XCTestCase

@end

@implementation OBJCTests

- (void) testSucceededFuture
{
    BFFuture *f = [BFFuture succeeded:@(1)];
    XCTAssertEqualObjects(f.result.value, @(1));
    XCTAssertEqualObjects(f.value, @(1));
    XCTAssert(f.result.isSuccess);
}

- (void) testOnComplete
{
    BFFuture *f = [BFFuture succeeded:@(2)];
    
    XCTestExpectation *e = [self expectation];
    [f onComplete:^(BFResult *res) {
        XCTAssertEqualObjects(res.value, @(2));
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testOnCompleteWithContext
{
    BFFuture *f = [BFFuture succeeded:@(1)];
    
    XCTestExpectation *e = [self expectation];
    [f onCompleteWithContext:[BFExecutionContext mainQueue] callback:^(BFResult *res) {
        XCTAssertEqualObjects(res.value, @(1));
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (XCTestExpectation *) expectation
{
    return [self expectationWithDescription:@""];
}

@end
