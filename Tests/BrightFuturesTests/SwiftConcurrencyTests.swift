//
//  SwiftConcurrencyTests.swift
//  BrightFutures
//
//  Created by Thomas Visser on 14/06/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation
import XCTest
import BrightFutures

#if swift(>=5.5)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
class SwiftConcurrencyTests: XCTestCase {
    func testAsyncResult() async {
        let a = Async(result: 1)
        let result = await a.get()
        XCTAssertEqual(result, 1)
    }

    func testFutureValueWithoutError() async {
        let f = Future<Int, Never> { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
                completion(.success(1))
            }
        }

        let value = await f.get()
        XCTAssertEqual(value, 1)
    }

    func testFutureValue() async throws {
        let f = Future<Int, Error> { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
                completion(.success(1))
            }
        }

        let value = try await f.get()
        XCTAssertEqual(value, 1)
    }

    func testFutureValueThrows() async {
        let f = Future<Int, LocalError> { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(1)) {
                completion(.failure(LocalError.one))
            }
        }
        do {
            _ = try await f.get()
            XCTFail()
        } catch {
            XCTAssertEqual(error as? LocalError, LocalError.one)
        }
    }
}

fileprivate enum LocalError: Error, Equatable {
    case one
}

#endif
