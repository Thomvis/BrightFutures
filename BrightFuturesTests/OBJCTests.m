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
    XCTestExpectation *e = [self expectation];
    
    [[[BFFuture wrap:^id{
        return @([self fibonacci:10]);
    }] map:^id(NSNumber *num) {
        return @([num integerValue] / 5);
    }] onSuccess:^(NSNumber *num) {
        XCTAssertEqualObjects(num, @(11));
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testMapSuccess
{
    XCTestExpectation *e = [self expectation];
    
    [[[[BFFuture wrap:^id{
        return @([self fibonacci:10]);
    }] map:^id(NSNumber *num) {
        if ([num integerValue] > 5) {
            return @"large";
        }
        return @"small";
    }] map:^id(NSString *string) {
        return @([string isEqualToString:@"large"]);
    }] onSuccess:^(NSNumber *num) {
        XCTAssert([num boolValue]);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testMapFailure
{
    XCTestExpectation *e = [self expectation];
    
    [[[[BFFuture wrapResult:^BFResult *{
        return [BFResult failure:[NSError errorWithDomain:@"Tests" code:123 userInfo:nil]];
    }] map:^id(id val) {
        XCTFail(@"shouldn't get called with failed result");
        return nil;
    }] map:^id(id val) {
        XCTFail(@"shouldn't get called with failed result");
        return nil;
    }] onFailure:^(NSError *error) {
        XCTAssertEqualObjects(error.domain, @"Tests");
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testSkippedRecover
{
    XCTestExpectation *e = [self expectation];
    
    [[[BFFuture wrap:^id{
        return @(3);
    }] recover:^id(NSError *err) {
        return @(5);
    }] onSuccess:^(id val) {
        XCTAssertEqualObjects(val, @3);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void) testRecoverWith
{
    XCTestExpectation *e = [self expectation];
    
    [[[BFFuture wrapResult:^BFResult *{
        return [BFResult failure:[NSError errorWithDomain:@"NaN" code:0 userInfo:nil]];
    }] recoverAsync:^BFFuture *(NSError *err) {
        XCTAssertEqualObjects(err.domain, @"NaN");
        return [BFFuture wrap:^id {
            return @([self fibonacci:5]);
        }];
    }] onSuccess:^(id val) {
        XCTAssertEqualObjects(val, @(5));
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testZip
{
    BFFuture *f1 = [BFFuture succeeded:@1];
    BFFuture *f2 = [BFFuture succeeded:@2];
    
    XCTestExpectation *e = [self expectation];
    
    [[f1 zip:f2] onSuccess:^(NSArray *tuple) {
        XCTAssert([tuple isKindOfClass:[NSArray class]]);
        XCTAssert([tuple count] == 2);
        XCTAssertEqualObjects([tuple firstObject], @1);
        XCTAssertEqualObjects([tuple lastObject], @2);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testZipThisFails
{
    BFFuture *f1 = [BFFuture wrapResult:^BFResult *{
        sleep(1);
        return [BFResult failure:[NSError errorWithDomain:@"test" code:2 userInfo:nil]];
    }];
    
    BFFuture *f2 = [BFFuture succeeded:@2];
    
    XCTestExpectation *e = [self expectation];
    
    [[f1 zip:f2] onFailure:^(NSError *err) {
        XCTAssertEqualObjects(err.domain, @"test");
        XCTAssertEqual(err.code, 2);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testZipThatFails
{
    BFFuture *f1 = [BFFuture wrapResult:^BFResult *{
        sleep(1);
        return [BFResult failure:[NSError errorWithDomain:@"test" code:2 userInfo:nil]];
    }];
    
    BFFuture *f2 = [BFFuture succeeded:@2];
    
    XCTestExpectation *e = [self expectation];
    
    [[f2 zip:f1] onFailure:^(NSError *err) {
        XCTAssertEqualObjects(err.domain, @"test");
        XCTAssertEqual(err.code, 2);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testZipBothFail
{
    BFFuture *f1 = [BFFuture wrapResult:^BFResult *{
        sleep(1);
        return [BFResult failure:[NSError errorWithDomain:@"f1-error" code:3 userInfo:nil]];
    }];
    
    BFFuture *f2 = [BFFuture wrapResult:^BFResult *{
        sleep(1);
        return [BFResult failure:[NSError errorWithDomain:@"f2-error" code:4 userInfo:nil]];
    }];

    
    XCTestExpectation *e = [self expectation];
    
    [[f1 zip:f2] onFailure:^(NSError *err) {
        XCTAssertEqualObjects(err.domain, @"f1-error");
        XCTAssertEqual(err.code, 3);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

// Objective-C exclusive
- (void)testZipWithNil
{
    XCTestExpectation *e = [self expectation];
    
    [[[BFFuture succeeded:nil] zip:[BFFuture succeeded:@1]] onSuccess:^(NSArray *arr) {
        XCTAssert([arr count] == 2);
        XCTAssertEqualObjects([arr firstObject], [NSNull null]);
        XCTAssertEqualObjects([arr lastObject], @1);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFilterNoSuchElement
{
    XCTestExpectation *e = [self expectation];
    [[[BFFuture succeeded:@3] filter:^BOOL(NSNumber *num) {
        return [num integerValue] > 5;
    }] onComplete:^(BFResult *res) {
        XCTAssert(res.isFailure);
        XCTAssertEqual(res.error.code, 0);
        XCTAssertEqualObjects(res.error.domain, @"nl.thomvis.BrightFutures");
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFilterPasses
{
    XCTestExpectation *e = [self expectation];
    
    [[[BFFuture succeeded:@"BrightFutures"] filter:^BOOL(NSString *str) {
        return [str hasPrefix:@"Br"];
    }] onComplete:^(BFResult *res) {
        XCTAssert(res.isSuccess);
        XCTAssertEqualObjects(res.value, @"BrightFutures");
        
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testForcedFuture
{
    BFResult *res = [[BFFuture wrap:^id{
        [NSThread sleepForTimeInterval:0.5];
        return @3;
    }] forced];
    
    XCTAssert(res.isSuccess);
    XCTAssertEqualObjects(res.value, @3);
}

- (void)testForcedFutureWithTimeout
{
    BFFuture *f = [BFFuture wrap:^id{
        [NSThread sleepForTimeInterval:0.5];
        return nil;
    }];
    
    XCTAssertNil([f forced: 0.1]);
    XCTAssert([[f forced:0.5] isSuccess]);
}

- (void)testPerformance1
{
    [self measureBlock:^{
        BFFuture *f = [BFFuture succeeded:@3];
        XCTestExpectation *e = [self expectation];
        
        [[[[f filter:^BOOL(NSNumber *num) {
            return true;
        }] map:^id(NSNumber *num) {
            return @(2 * [num integerValue]);
        }] mapWithContext:[BFExecutionContext globalQueue] f:^id(NSNumber*num) {
            return @(3 * [num integerValue] + 1);
        }] onSuccess:^(NSNumber *res) {
            XCTAssertEqualObjects(res, @(19));
            [e fulfill];
        }];
        
        [self waitForExpectationsWithTimeout:2 handler:nil];
    }];
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
