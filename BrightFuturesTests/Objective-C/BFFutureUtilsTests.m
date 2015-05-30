//
//  BFFutureUtilsTests.m
//  BrightFutures
//
//  Created by Thomas Visser on 29/03/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

#import <XCTest/XCTest.h>
@import BrightFutures;
#import "Helpers.h"

@interface BFFutureUtilsTests : XCTestCase

@end

@implementation BFFutureUtilsTests

- (void)testTraverseSuccess
{
    NSArray *oneToTen = @[@1, @2, @3, @4, @5, @6, @7, @8, @9, @10];
    
    BFFuture *f = [BFFutureUtils traverse:oneToTen fn:^BFFuture *(NSNumber *num) {
        return [BFFuture succeeded:@(fibonacci([num integerValue]))];
    }];
    
    XCTestExpectation *e = [self expectation];
    
    [f onSuccess:^(NSArray *fibonacciSequence) {
        XCTAssertEqual([fibonacciSequence count], [oneToTen count]);
        
        for (NSUInteger i = 0; i < [fibonacciSequence count]; i++) {
            XCTAssertEqual([fibonacciSequence[i] integerValue], fibonacci(i+1));
        }
        
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testTraverseEmpty
{
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils traverse:@[] fn:^BFFuture *(id obj) {
        return nil;
    }] onSuccess:^(NSArray* res) {
        XCTAssertEqual([res count], 0);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testTraverseSingleError
{
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils traverse:@[@2, @4, @6, @8, @9, @10] fn:^BFFuture *(id num) {
        return [self futureWithEvenNumberOrErrorForNumber:[num integerValue]];
    }] onFailure:^(NSError *err) {
        XCTAssertEqual(err.code, 9);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testTraverseMultiplErrors
{
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils traverse:@[@2, @4, @3, @7, @9, @10] fn:^BFFuture *(id num) {
        return [self futureWithEvenNumberOrErrorForNumber:[num integerValue]];
    }] onFailure:^(NSError *err) {
        XCTAssertEqual(err.code, 3);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testTraverseWithExecutionContext
{
    XCTestExpectation *e = [self expectation];
    
    [BFFutureUtils traverse:@[@1] context:[BFExecutionContext mainQueue] fn:^BFFuture *(id num) {
        XCTAssert([NSThread isMainThread]);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFold
{
    NSMutableArray *list = [NSMutableArray new];
    for (NSUInteger i = 1; i < 11; i++) {
        [list addObject:[BFFuture wrap:^id{
            return @(fibonacci(i));
        }]];
    }
    
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils fold:list zero:@0 op:^id(NSNumber*zero, NSNumber*fibSeqElem) {
        return @([zero integerValue] + [fibSeqElem integerValue]);
    }] onSuccess:^(NSNumber *num) {
        XCTAssertEqual([num integerValue], 143);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFoldWithError
{
    NSMutableArray *list = [NSMutableArray new];
    for (NSUInteger i = 1; i < 11; i++) {
        if (i == 3) {
            [list addObject:[BFFuture failed:[NSError errorWithDomain:@"fold-single-error" code:i userInfo:nil]]];
        } else {
            [list addObject:[BFFuture wrap:^id{
                return @(fibonacci(i));
            }]];
        }
    }
    
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils fold:list zero:@0 op:^id(NSNumber*zero, NSNumber*fibSeqElem) {
        return @([zero integerValue] + [fibSeqElem integerValue]);
    }] onFailure:^(NSError *err) {
        XCTAssertEqual(err.code, 3);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFoldEmptyList
{
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils fold:@[] zero:@1 op:^id(NSNumber*zero, NSNumber*fibSeqElem) {
        return @([zero integerValue] + [fibSeqElem integerValue]);
    }] onSuccess:^(NSNumber *num) {
        XCTAssertEqual([num integerValue], 1);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFirstCompleted
{
    NSArray *pendingFutures = @[
                                [BFFuture completeAfter:0.2 withValue:@10],
                                [BFFuture completeAfter:0.3 withValue:@11],
                                [BFFuture completeAfter:0.4 withValue:@12],
                                [BFFuture completeAfter:0.5 withValue:@13],
                                [BFFuture completeAfter:0.1 withValue:@14],
                                [BFFuture completeAfter:0.7 withValue:@15],
                                ];
    
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils firstCompletedOf:pendingFutures] onSuccess:^(NSNumber *num) {
        XCTAssertEqual([num integerValue], 14);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testSequence
{
    NSMutableArray *list = [NSMutableArray new];
    for (NSUInteger i = 1; i < 11; i++) {
        [list addObject:[BFFuture wrap:^id{
            return @(fibonacci(i));
        }]];
    }
    
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils sequence:list] onSuccess:^(NSArray* sequence) {
        for (NSUInteger i = 0; i < [sequence count]; i++) {
            XCTAssertEqual([sequence[i] integerValue], fibonacci(i+1));
        }
        
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testSequenceNil
{
    NSArray *futures = @[[BFFuture succeeded:@1], [BFFuture succeeded:nil]];
    
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils sequence:futures] onSuccess:^(NSArray *res) {
        XCTAssertEqual([res[0] integerValue], 1);
        XCTAssertEqualObjects(res[1], [NSNull new]);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testSequenceEmpty
{
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils sequence:@[]] onSuccess:^(NSArray *array) {
        XCTAssertEqual([array count], 0);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFindSuccess
{
    NSArray *futures = @[[BFFuture succeeded:@1], [BFFuture succeeded:nil]];
    
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils find:futures p:^BOOL(id val) {
        return val == nil;
    }] onSuccess:^(id res) {
        XCTAssertNil(res);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

- (void)testFindNoSuchElement
{
    NSArray *futures = @[[BFFuture succeeded:@1], [BFFuture succeeded:@2]];
    
    XCTestExpectation *e = [self expectation];
    
    [[BFFutureUtils find:futures p:^BOOL(id val) {
        return val == nil;
    }] onFailure:^(NSError *err) {
        XCTAssertEqual(err.code, 1);
        [e fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

#pragma mark - Helpers -

- (BFFuture *)futureWithEvenNumberOrErrorForNumber: (NSUInteger)num
{
    if (num % 2 == 0) {
        return [BFFuture succeeded:@(num)];
    }
    
    return [BFFuture failed:[NSError errorWithDomain:@"traverse-single-error" code:num userInfo:nil]];
}

@end
