//
//  NSOperationQueue+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 18/09/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public extension NSOperationQueue {
    /// An execution context that operates on the receiver.
    /// Tasks added to the execution context are executed as operations on the queue.
    public var context: ExecutionContext {
        return { [weak self] task in
            self?.addOperation(NSBlockOperation(block: task))
        }
    }
}