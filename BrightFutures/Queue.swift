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

/// Queue is a tiny wrapper around a Grand Central Dispatch queue.
/// Queue provides a nice syntax for scheduling (async) execution of closures.
///
/// q.async {
///     // executes asynchronously
/// }
///
///
/// It also simplifies executing a closure synchronously and getting the
/// return value from the closure:
///
/// let n = q.sync {
///     return 42
/// }
///
public struct Queue {
    
    /// The queue that is bound to the main thread (`dispatch_get_main_queue()`)
    public static let main = Queue(queue: dispatch_get_main_queue());
    
    /// The global queue with default priority
    public static let global = Queue(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
    
    /// The underlying `dispatch_queue_t`
    private(set) public var underlyingQueue: dispatch_queue_t
    
    /// Returns an execution context that asynchronously performs tasks on this queue
    public var context: ExecutionContext {
        return { task in
            self.async(task)
        }
    }
    
    /// Instantiates a new `Queue` with the given queue.
    /// If `queue` is omitted, a serial queue with identifier "queue" is used.
    public init(queue: dispatch_queue_t = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL)) {
        self.underlyingQueue = queue
    }
    
    /// Synchronously executes the given closure on this queue.
    /// Analogous to dispatch_sync(self.underlyingQueue, block)
    public func sync(block: () -> ()) {
        dispatch_sync(underlyingQueue, block)
    }
    
    /// Synchronously executes the given closure on this queue and returns
    /// the return value of the given closure.
    public func sync<T>(block: () -> T) -> T {
        var res: T? = nil

        sync {
            res = block()
        }
        
        return res!;
    }
    
    /// Asynchronously executes the given closure on this queue.
    /// Analogous to dispatch_async(self.underlyingQueue, block)
    public func async(block: () -> ()) {
        dispatch_async(underlyingQueue, block)
    }
    
    /// Asynchronously executes the given closure on this queue and
    /// returns a future that will succeed with the result of the closure.
    public func async<T>(block: () -> T) -> Future<T> {
        let p = Promise<T>()

        async {
            p.success(block())
        }
        
        return p.future
    }
    
    /// Asynchronously executes the given closure on the queue after a delay
    /// Identical to dispatch_after(dispatch_time, self.underlyingQueue, block)
    public func after(delay: TimeInterval, block: () -> ()) {
        dispatch_after(delay.dispatchTime, underlyingQueue, block)
    }
    
    /// Asynchronously executes the given closure on the queue after a delay
    /// and returns a future that will succeed with the result of the closure.
    /// Identical to dispatch_after(dispatch_time, self.underlyingQueue, block)
    public func after<T>(delay: TimeInterval, block: () -> T) -> Future<T> {
        let p = Promise<T>()
        
        after(delay) {
            p.success(block())
        }
        
        return p.future
    }
}
