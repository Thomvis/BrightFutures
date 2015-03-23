//
//  BFInvalidationTokenTests.m
//  BrightFutures
//
//  Created by Thomas Visser on 23/03/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

@import Foundation;
#import <XCTest/XCTest.h>
#import "BrightFuturesTests-Swift.h"
@import BrightFutures;

@interface BFInvalidationTokenTests : XCTestCase
@property (nonatomic) NSUInteger counter;
@end

@implementation BFInvalidationTokenTests

- (void)testInvalidationTokenInit
{
    BFInvalidationToken *token = [BFInvalidationToken new];
    XCTAssertFalse(token.isInvalid, "a token is valid by default");
}

- (void)testInvalidateToken
{
    BFInvalidationToken *token = [BFInvalidationToken new];
    [token invalidate];
    XCTAssert(token.isInvalid, @"a token should become invalid after invalidating");
}

- (void)testInvalidationTokenFuture
{
    BFInvalidationToken *token = [BFInvalidationToken new];
    XCTAssertNotNil(token.future, @"token should have a future");
    XCTAssertFalse(token.future.isCompleted, @"token should have a future and not be complete");
    [token invalidate];
    
    // why do we need an onFailure block here but not in Swift?
    XCTestExpectation *e = [self expectation];
    [token.future onFailure:^(NSError *error) {
        XCTAssertNotNil(error, @"future should have an error");
        XCTAssertEqualObjects(error.domain, @"nl.thomvis.BrightFutures");
        XCTAssertEqual(error.code, 2);
        
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testCompletionAfterInvalidation
{
    BFInvalidationToken *token = [BFInvalidationToken new];
    
    BFPromise *p = [BFPromise new];
    
    [[p.future onSuccessWithToken:token callback:^(id res) {
        XCTAssertFalse(@"onSuccess should not get called");
    }] onFailureWithToken:token callback:^(NSError *err) {
        XCTAssertFalse(@"onFailure should not get called");
    }];
    
    XCTestExpectation *e = [self expectation];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [token invalidate];
        [p success:@2];
        [NSThread sleepForTimeInterval:0.2f];
        [e fulfill];
    });
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testStress
{
    self.counter = 0;
    
    BFInvalidationToken *token;
    for (NSUInteger i = 0; i < 100; i++) {
        token = [BFInvalidationToken new];
        NSUInteger currentI = self.counter;
        XCTestExpectation *e = [self expectation];
        
        [[[BFFuture wrap:^id{
            [NSThread sleepForTimeInterval:(NSTimeInterval)(arc4random()%100) / 100000.0f];
            return @YES;
        }] onSuccessWithContext:[BFExecutionContext globalQueue] token:token callback:^(id res) {
            XCTAssertFalse(token.isInvalid);
            XCTAssertEqual(currentI, self.counter, @"onSuccess should only get called if the counter did not increment");
        }] onCompleteWithContext:[BFExecutionContext globalQueue] callback:^(BFResult *res) {
            [NSThread sleepForTimeInterval:0.0001];
            [e fulfill];
        }];
        
        [NSThread sleepForTimeInterval:0.0005];
        
        [token.context execute:^{
            self.counter++;
            [token invalidate];
        }];
    }
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

@end
