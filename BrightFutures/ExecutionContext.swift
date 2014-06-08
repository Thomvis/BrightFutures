//
//  ExecutionContext.swift
//  TVFutures
//
//  Created by Thomas Visser on 03/06/14.
//
//

import Foundation

let defaultExecutionContext : ExecutionContext = QueueExecutionContext()
let mainExecutionContext : ExecutionContext = QueueExecutionContext(targetQueue: Queue.main)

protocol ExecutionContext {
    
    func execute(task: () -> ());

}

class QueueExecutionContext : ExecutionContext {
    
    let queue: Queue = Queue();
    
    init(targetQueue: Queue? = nil) {
        if let unwrappedTargetQueue = targetQueue {
            dispatch_set_target_queue(self.queue.queue, unwrappedTargetQueue.queue)
        }
    }
    
    func execute(task: () -> ()) {
        self.queue.async(task)
    }
}

class ImmediateExecutionContext : ExecutionContext {
    
    func execute(task: () -> ())  {
        task()
    }
}