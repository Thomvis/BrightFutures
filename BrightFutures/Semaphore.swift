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

/// Represents a TimeInterval. The interval is either ending 
/// (e.g. `.In(2)` means 2 seconds)
/// or never ending (e.g. `.Forever`)
public enum TimeInterval {
    case Forever
    case In(NSTimeInterval)
    
    /// Returns the `dispatch_time_t` representation of this interval
    public var dispatchTime: dispatch_time_t {
        switch self {
        case .Forever:
            return DISPATCH_TIME_FOREVER
        case .In(let interval):
            return dispatch_time(DISPATCH_TIME_NOW, Int64(interval * NSTimeInterval(NSEC_PER_SEC)))
        }
    }
}

/// A tiny wrapper around dispatch_semaphore
public class Semaphore {

    /// The underlying `dispatch_semaphore_t`
    private(set) public var underlyingSemaphore: dispatch_semaphore_t
    
    /// Creates a new semaphore with the given initial value
    /// See `dispatch_semaphore_create(value: Int) -> dispatch_semaphore_t!`
    public init(value: Int) {
        self.underlyingSemaphore = dispatch_semaphore_create(value)
    }
    
    /// Creates a new semaphore with initial value 1
    /// This kind of semaphores is useful to protect a critical section
    public convenience init() {
        self.init(value: 1)
    }
    
    /// Performs the wait operation on this semaphore
    public func wait() {
        self.wait(.Forever)
    }
    
    /// Performs the wait operation on this semaphore until the timeout
    /// Returns 0 if the semaphore was signalled before the timeout occurred
    /// or non-zero if the timeout occurred.
    public func wait(timeout: TimeInterval) -> Int {
        return dispatch_semaphore_wait(self.underlyingSemaphore, timeout.dispatchTime)
    }
    
    /// Performs the signal operation on this semaphore
    public func signal() -> Int {
        return dispatch_semaphore_signal(self.underlyingSemaphore)
    }

    /// Executes the given closure between a `self.wait()` and `self.signal()`
    public func execute(@noescape task: () -> ()) {
        self.wait()
        task()
        self.signal()
    }
}