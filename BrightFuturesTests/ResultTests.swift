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

class ResultTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSuccess() {
        let result = Result.Success(Box(3))
        XCTAssert(result.isSuccess)
        XCTAssertFalse(result.isFailure)
        XCTAssertEqual(result.value!, 3)
        XCTAssertNil(result.error)
        
        let result1 = Result(4)
        XCTAssert(result1.isSuccess)
        XCTAssertFalse(result1.isFailure)
        XCTAssertEqual(result1.value!, 4)
        XCTAssertNil(result1.error)
    }
    
    func testFailure() {
        let error = NSError()
        let result = Result<Int>.Failure(error)
        XCTAssert(result.isFailure)
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.error!, error)
        XCTAssertNil(result.value)
    }
    
}
