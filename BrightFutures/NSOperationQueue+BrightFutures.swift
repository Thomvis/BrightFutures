//
//  NSOperationQueue+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 18/09/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public extension NSOperationQueue {
    public var context: ExecutionContext {
        return { [weak self] task in
            self?.addOperation(NSBlockOperation(block: task))
        }
    }
}