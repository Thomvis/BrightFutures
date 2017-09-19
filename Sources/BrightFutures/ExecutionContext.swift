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

/// The context in which something can be executed
/// By default, an execution context can be assumed to be asynchronous unless stated otherwise
public typealias ExecutionContext = (@escaping () -> Void) -> Void

/// Immediately executes the given task. No threading, no semaphores.
public let immediateExecutionContext: ExecutionContext = { task in
    task()
}

/// Runs immediately if on the main thread, otherwise asynchronously on the main thread
public let immediateOnMainExecutionContext: ExecutionContext = { task in
    if Thread.isMainThread {
        task()
    } else {
        DispatchQueue.main.async(execute: task)
    }
}

/// From https://github.com/BoltsFramework/Bolts-Swift/blob/5fe4df7acb384a93ad93e8595d42e2b431fdc266/Sources/BoltsSwift/Executor.swift#L56
public let maxStackDepthExecutionContext: ExecutionContext = { task in
    struct Static {
        static let taskDepthKey = "nl.thomvis.BrightFutures"
        static let maxTaskDepth = 20
    }
    
    let localThreadDictionary = Thread.current.threadDictionary
    
    var previousDepth: Int
    if let depth = localThreadDictionary[Static.taskDepthKey] as? Int {
        previousDepth = depth
    } else {
        previousDepth = 0
    }
    
    if previousDepth > 20 {
        DispatchQueue.global().async(execute: task)
    } else {
        localThreadDictionary[Static.taskDepthKey] = previousDepth + 1
        task()
        localThreadDictionary[Static.taskDepthKey] = previousDepth
    }
}

/// Defines BrightFutures' default threading behavior:
/// - if on the main thread, `DispatchQueue.main.context` is returned
/// - if off the main thread, `DispatchQueue.global().context` is returned
public func defaultContext() -> ExecutionContext {
    return (Thread.isMainThread ? DispatchQueue.main : DispatchQueue.global()).context
}
