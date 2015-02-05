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

- (void)testCompletedFuture
{
    BFFuture *f = [BFFuture succeeded:@(2)];
    
    XCTestExpectation *e1 = [self expectation];
    
    [f onComplete:^(BFResult *res) {
        XCTAssert(res.isSuccess);
        XCTAssertFalse(res.isFailure);
        XCTAssertEqualObjects(res.value, @(2));
        XCTAssertNil(res.error);
        [e1 fulfill];
    }];
    
    XCTestExpectation *e2 = [self expectation];
    
    [f onSuccess:^(id res) {
        XCTAssertEqualObjects(res, @(2));
        [e2 fulfill];
    }];
    
    [f onFailure:^(NSError *error) {
        XCTFail(@"shouldn't get called");
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testFailedFuture
{
    NSError *error = [NSError errorWithDomain:@"test" code:0 userInfo:nil];
    BFFuture *f = [BFFuture failed:error];
    
    XCTestExpectation *e1 = [self expectation];
    [f onComplete:^(BFResult *res) {
        XCTAssert(res.isFailure);
        XCTAssertFalse(res.isSuccess);
        XCTAssertEqualObjects(res.error, error);
        XCTAssertNil(res.value);
        
        [e1 fulfill];
    }];
    
    XCTestExpectation *e2 = [self expectation];
    [f onFailure:^(NSError *err) {
        XCTAssertEqualObjects(err, error);
        [e2 fulfill];
    }];
    
    [f onSuccess:^(id val) {
        XCTFail(@"shouldn't get called");
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

// this is inherently impossible to test, but we'll give it a try
- (void) testNeverCompletingFuture
{
    BFFuture *f = [BFFuture never];
    XCTAssertFalse(f.isCompleted);
    
    sleep(arc4random_uniform(100)/100.0);
    
    XCTAssertFalse(f.isCompleted);
}

- (void) testControlFlowSyntax
{
    // not in Objective-C
    BFFuture *f = [BFFuture wrap:^id{
        XCTAssertFalse([NSThread isMainThread]);
        return @([self fibonacci:10]);
    }];
    
    XCTestExpectation *e = [self expectation];
    
    [f onSuccess:^(NSNumber *num) {
        XCTAssertEqualObjects(num, @(55));
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testControlFlowSyntaxWithError
{
    BFFuture *f = [BFFuture wrapResult:^BFResult *{
        return [BFResult failure:[NSError errorWithDomain:@"NaN" code:0 userInfo:nil]];
    }];
    
    XCTestExpectation *e = [self expectation];
    
    [f onFailure:^(NSError *error) {
        XCTAssertEqualObjects(error.domain, @"NaN");
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testAutoClosure
{
    // not in Objectice-C
}

- (void) testPromise
{
    BFPromise *p = [BFPromise new];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [p success:@([self fibonacci:10])];
    });
    
    XCTestExpectation *e = [self expectation];
    
    [p.future onComplete:^(BFResult *res) {
        XCTAssertEqualObjects(res.value, @(55));
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testCustomExecutionContext
{
    BFFuture *f = [BFFuture wrapWithContext:[BFExecutionContext immediate] block:^id{
        XCTAssert([NSThread isMainThread]);
        return @([self fibonacci:10]);
    }];
    
    XCTAssertEqualObjects(f.result.value, @(55));
    
    XCTestExpectation *e = [self expectation];
    
    [f onSuccess:^(id n) {
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:0 handler:nil];
}

- (void) testMainExecutionContext
{
    XCTestExpectation *e = [self expectation];
    
    [[BFFuture wrap:^id{
        XCTAssertFalse([NSThread isMainThread]);
        return @(1);
    }] onSuccessWithContext:[BFExecutionContext mainQueue] callback:^(id res) {
        XCTAssert([NSThread isMainThread]);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testDefaultCallbackExecutionContextFromMain
{
    BFFuture *f = [BFFuture succeeded:@1];
    XCTestExpectation *e = [self expectation];
    [f onSuccess:^(id val) {
        XCTAssert([NSThread isMainThread]);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testDefaultCallbackExecutionContextFromBackground
{
    BFFuture *f = [BFFuture succeeded:@1];
    XCTestExpectation *e = [self expectation];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [f onSuccess:^(id val) {
            XCTAssertFalse([NSThread isMainThread]);
            [e fulfill];
        }];
    });
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

#pragma mark - Functional Composition -
- (void) testAndThen
{
    __block NSInteger answer = 10;
    XCTestExpectation *e = [self expectation];
    
    BFFuture *f = [BFFuture succeeded:@4];
    BFFuture *f1 = [f andThen:^(BFResult *result) {
        answer *= [result.value integerValue];
    }];
    
    BFFuture *f2 = [f1 andThen:^(BFResult *result) {
        answer += 2;
    }];
    
    [f onSuccess:^(id fval) {
        [f1 onSuccess:^(id f1val) {
            [f2 onSuccess:^(id f2val) {
                XCTAssertEqualObjects(fval, f1val);
                XCTAssertEqualObjects(f1val, f2val);
                [e fulfill];
            }];
        }];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
    
    XCTAssertEqual(answer, 42);
}

- (void) testSimpleMap
{
    // TODO
}

- (void) testMapSuccess
{
    // TODO
}

- (void) testMapFailure
{
    // TODO
}

- (void) testSkippedRecover
{
    // TODO
}

- (void) testRecoverWith
{
    // TODO
}

- (void)testZip
{
    // TODO
}

- (void)testZipThisFails
{
    // TODO
}

- (void)testZipThatFails
{
    // TODO
}

- (void)testZipBothFail
{
    // TODO
}

- (void)testFilterNoSuchElement
{
    // TODO
}

- (void)testFilterPasses
{
    // TODO
}

- (void)testForcedFuture
{
    // TODO
}

#pragma mark - Helpers -

- (XCTestExpectation *) expectation
{
    return [self expectationWithDescription:@""];
}

- (NSUInteger) fibonacci:(NSUInteger)n
{
    if (n <= 1) {
        return n;
    } else {
        return [self fibonacci:n-1] + [self fibonacci:n-2];
    }
}

@end
