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

import Foundation

public struct Queue : ExecutionContext {
    
    public static let main = Queue(queue: dispatch_get_main_queue());
    public static let global = Queue(queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
    
    var queue: dispatch_queue_t
    
    init(queue: dispatch_queue_t = dispatch_queue_create("queue", DISPATCH_QUEUE_SERIAL)) {
        self.queue = queue
    }
    
    public func sync(block: () -> ()) {
        dispatch_sync(queue, block)
    }
    
    public func sync<T>(block: () -> T) -> T {
        var res: T? = nil;
        dispatch_sync(queue, {
            res = block();
        });
        
        return res!;
    }
    
    public func async(block: dispatch_block_t) {
        dispatch_async(queue, block);
    }
    
    public func execute(task: () -> ()) {
        self.async(task)
    }
    
}