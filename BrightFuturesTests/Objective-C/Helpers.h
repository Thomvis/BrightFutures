//
//  Helpers.h
//  BrightFutures
//
//  Created by Thomas Visser on 29/03/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

#import <Foundation/Foundation.h>
@import XCTest;

extern NSUInteger fibonacci(NSUInteger n);

@interface XCTestCase (SimpleExpectations)

- (XCTestExpectation *)expectation;

@end