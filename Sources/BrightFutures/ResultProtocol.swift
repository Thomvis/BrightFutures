//
//  ResultProtocol.swift
//  BrightFutures-iOS
//
//  Created by Kim de Vos on 26/03/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

/// A protocol that can be used to constrain associated types as `Result`.
public protocol ResultProtocol {
    associatedtype Value
    associatedtype Error: Swift.Error

    init(value: Value)
    init(error: Error)

    var result: Result<Value, Error> { get }
}

extension Result: ResultProtocol {
    /// Constructs a success wrapping a `value`.
    public init(value: Success) {
        self = .success(value)
    }

    /// Constructs a failure wrapping an `error`.
    public init(error: Failure) {
        self = .failure(error)
    }

    public var result: Result<Success, Failure> {
        return self
    }

    public var value: Success? {
        switch self {
        case .success(let value): return value
        case .failure: return nil
        }
    }

    public var error: Failure? {
        switch self {
        case .success: return nil
        case .failure(let error): return error
        }
    }
}
