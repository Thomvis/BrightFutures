// The MIT License (MIT)
//
// Copyright (c) 2014 Thomas Visser
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Dispatch

/**
 * Queue is a tiny wrapper around a Grand Central Dispatch queue.
 * Queue provides a nice syntax for scheduling (async) execution of blocks. 
 * 
 * ```
 * q.async {
 *  // executes asynchronously
 * }
 * ```
 *
 * It also simplifies executing a block synchronously and getting the 
 * return value from the block:
 *
 * let n = q.sync {
 *  return 42
 * }
 * ```
 *
 */
public struct Queue : ExecutionContext {
    
    /**
     * The queue that is bound to the main thread (`dispatch_get_main_queue()`)
     */
    public static let main = Queue(queue: dispatch_get_main_queue());
    
    /**
     * The global queue with default priority
     */
    public static let global = Queue(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
    
    var queue: dispatch_queue_t
    
    /**
     * Instantiates a new `Queue` with the given queue.
     * If `param` is omitted, a serial queue with identifier "queue" is used.
     */
    public init(queue: dispatch_queue_t = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL)) {
        self.queue = queue
    }
    
    /**
     * Synchronously executes the given block on the queue. 
     * Identical to dispatch_sync(self.queue, block)
     */
    public func sync(block: () -> ()) {
        dispatch_sync(queue, block)
    }
    
    /**
     * Synchronously executes the given block on the queue and returns
     * the return value of the given block.
     * @return the return value from the block
     */
    public func sync<T>(block: () -> T) -> T {
        var res: T? = nil;
        dispatch_sync(queue, {
            res = block();
        });
        
        return res!;
    }
    
    /**
     * Asynchronously executes the given block on the queue.
     * Identical to dispatch_async(self.queue, block)
     */
    public func async(block: dispatch_block_t) {
        dispatch_async(queue, block);
    }
    
    public func async<T>(block: () -> T) -> Future<T> {
        let p = Promise<T>()
        
        dispatch_async(queue, {
            p.success(block())
        })
        
        return p.future
    }
    
    /**
     * Part of the ExecutionContext protocol.
     * Executes the given task asynchronously on the queue.
     */
    public func execute(task: () -> ()) {
        self.async(task)
    }
    
}
