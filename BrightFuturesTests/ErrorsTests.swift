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

enum TestError: ErrorType {
    case JustAnError
}

class ErrorsTests: XCTestCase {
    
    func testExternalError() {
        let externalError = TestError.JustAnError
        let error = BrightFuturesError(external: externalError)
        
        switch error {
        case .External(let err):
            XCTAssertEqual(err, TestError.JustAnError, "Should be same error")
        default:
            XCTFail("Should match with the external case")
        }
    }
    
    func testEqualErrors() {
        XCTAssert(BrightFuturesError<NoError>.NoSuchElement == BrightFuturesError<NoError>.NoSuchElement)
        XCTAssert(BrightFuturesError<NoError>.InvalidationTokenInvalidated == BrightFuturesError<NoError>.InvalidationTokenInvalidated)
        XCTAssertFalse(BrightFuturesError<NoError>.NoSuchElement == BrightFuturesError<NoError>.InvalidationTokenInvalidated)
        
        XCTAssert(BrightFuturesError(external: MainError.A) == BrightFuturesError(external: MainError.A))
        XCTAssertFalse(BrightFuturesError(external: MainError.A) == BrightFuturesError(external: MainError.B))
    }
    
}

enum MainError: Int, ErrorType {
    case A = 1
    case B = 2
}