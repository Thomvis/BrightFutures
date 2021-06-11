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

import XCTest
import BrightFutures

class Counter {
    var i: Int = 0
}

class ExecutionContextTests: XCTestCase {
    
    func testImmediateOnMainThreadContextOnMainThread() {
        let counter = Counter()
        
        counter.i = 1
        
        immediateOnMainExecutionContext {
            XCTAssert(Thread.isMainThread)
            counter.i = 2
        }
        
        XCTAssertEqual(counter.i, 2)
    }
    
    func testImmediateOnMainThreadContextOnBackgroundThread() {
        let e = self.expectation()
        DispatchQueue.global().async {
            immediateOnMainExecutionContext {
                XCTAssert(Thread.isMainThread)
                e.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testDispatchQueueToContext() {
        let key = DispatchSpecificKey<String>()
        let value1 = "abc"
        
        let queue1 = DispatchQueue(label: "test1", qos: DispatchQoS.default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        queue1.setSpecific(key: key, value: value1)
        
        let e1 = self.expectation()
        queue1.context {
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), value1)
            e1.fulfill()
        }
        
        let value2 = "def"
        
        let queue2 = DispatchQueue(label: "test2", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
        queue2.setSpecific(key: key, value: value2)
        
        let e2 = self.expectation()
        queue2.context {
            XCTAssertEqual(DispatchQueue.getSpecific(key: key), value2)
            e2.fulfill()
        }
        
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
}
