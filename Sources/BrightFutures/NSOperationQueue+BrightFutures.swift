//
//  NSOperationQueue+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 18/09/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation

public extension OperationQueue {
    /// An execution context that operates on the receiver.
    /// Tasks added to the execution context are executed as operations on the queue.
    var context: ExecutionContext {
        return { [weak self] task in
            self?.addOperation(BlockOperation(block: task))
        }
    }
}
