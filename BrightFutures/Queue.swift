//
//  Queue.swift
//  TVFutures
//
//  Created by Thomas Visser on 04/06/14.
//
//

import Foundation

struct Queue {
    
    static let main = Queue(queue: dispatch_get_main_queue());
    static let global = Queue(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
    
    var queue: dispatch_queue_t
    
    init(queue: dispatch_queue_t) {
        self.queue = queue
    }
    
    init() {
        self.queue = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL)
    }
    
    func sync(block: () -> ()) {
        dispatch_sync(queue, block)
    }
    
    func sync<T>(block: () -> T) -> T {
        var res: T? = nil;
        dispatch_sync(queue, {
            res = block();
        });
        
        return res!;
    }
    
    func async(block: dispatch_block_t) {
        dispatch_async(queue, block);
    }
}