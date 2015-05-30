//
//  Helpers.m
//  BrightFutures
//
//  Created by Thomas Visser on 29/03/15.
//  Copyright (c) 2015 Thomas Visser. All rights reserved.
//

#import "Helpers.h"

NSUInteger fibonacci(NSUInteger n) {
    if (n < 2) {
        return n;
    } else {
        return fibonacci(n-1) + fibonacci(n-2);
    }
}