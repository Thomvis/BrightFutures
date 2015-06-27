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
    case JustAnotherError
    
    var nsError: NSError {
        switch self {
        case .JustAnError:
            return NSError(domain: "TestError", code: 1, userInfo: nil)
        case .JustAnotherError:
            return NSError(domain: "AnotherTestError", code: 2, userInfo: nil)
        }
        
    }
}

extension TestError: Equatable {}

class ErrorsTests: XCTestCase {
    
    func testNSError() {
        let error = NSError()
        XCTAssert(error === error.nsError, "nsError should return itself")
    }
    
    func testNoSuchElementError() {
        let error = BrightFuturesError<NoError>.NoSuchElement
        XCTAssertEqual(error.nsError.domain, BrightFuturesErrorDomain)
        XCTAssertEqual(error.nsError.code, 0)
    }
    
    func testInvalidationError() {
        let error = BrightFuturesError<NoError>.InvalidationTokenInvalidated
        XCTAssertEqual(error.nsError.domain, BrightFuturesErrorDomain)
        XCTAssertEqual(error.nsError.code, 1)
    }
    
    func testExternalError() {
        let externalError = TestError.JustAnError
        let error = BrightFuturesError(external: externalError)
        
        switch error {
        case .External(let boxedError):
            XCTAssertEqual(boxedError.value, TestError.JustAnError, "Should be same error")
        default:
            XCTFail("Should match with the external case")
        }
        
        XCTAssertEqual(externalError.nsError, error.nsError)
    }
    
}