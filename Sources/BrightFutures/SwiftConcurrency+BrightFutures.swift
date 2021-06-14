//
//  SwiftConcurrency+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 14/06/2021.
//  Copyright © 2021 Thomas Visser. All rights reserved.
//

import Foundation

#if swift(>=5.5)
@available(iOS 15.0, *)
public extension Async {
    @_disfavoredOverload
    func get() async -> Value {
        await withCheckedContinuation { continuation in
            onComplete { result in
                continuation.resume(returning: result)
            }
        }
    }
}

@available(iOS 15.0, *)
public extension Async where Value: ResultProtocol {
    @_disfavoredOverload
    func get() async throws -> Value.Value {
        try await withCheckedThrowingContinuation { continuation in
            onComplete { result in
                continuation.resume(with: result.result)
            }
        }
    }
}

@available(iOS 15.0, *)
public extension Async where Value: ResultProtocol, Value.Error == Never {
    func get() async -> Value.Value {
        await withCheckedContinuation { continuation in
            onComplete { result in
                continuation.resume(with: result.result)
            }
        }
    }
}
#endif
