//
//  Result+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 30/08/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

extension ResultProtocol {

    /// Case analysis for Result.
    ///
    /// Returns the value produced by applying `ifFailure` to `failure` Results, or `ifSuccess` to `success` Results.
    func analysis<Result>(ifSuccess: (Value) -> Result, ifFailure: (Error) -> Result) -> Result {
        return self.result.analysis(ifSuccess: ifSuccess, ifFailure: ifFailure)
    }

}

extension ResultProtocol {
    /// Enables the chaining of two failable operations where the second operation is asynchronous and
    /// represented by a future.
    /// Like map, the given closure (that performs the second operation) is only executed
    /// if the first operation result is a .success
    /// If a regular `map` was used, the result would be `Result<Future<U>>`.
    /// The implementation of this function uses `map`, but then flattens the result before returning it.
    public func flatMap<U>(_ f: (Value) -> Future<U, Error>) -> Future<U, Error> {
        return analysis(ifSuccess: {
            return f($0)
        }, ifFailure: {
            return Future<U, Error>(error: $0)
        })
    }
}

extension ResultProtocol where Value: ResultProtocol, Error == Value.Error {
    
    /// Returns a .failure with the error from the outer or inner result if either of the two failed
    /// or a .success with the success value from the inner Result
    public func flatten() -> Result<Value.Value,Value.Error> {
        return analysis(ifSuccess: { innerRes in
            return innerRes.analysis(ifSuccess: {
                return .success($0)
            }, ifFailure: {
                return .failure($0)
            })
        }, ifFailure: {
            return .failure($0)
        })
    }
}

extension ResultProtocol where Value: AsyncType, Value.Value: ResultProtocol, Error == Value.Value.Error {
    /// Returns the inner future if the outer result succeeded or a failed future
    /// with the error from the outer result otherwise
    public func flatten() -> Future<Value.Value.Value, Value.Value.Error> {
        return Future { complete in
            analysis(ifSuccess: { innerFuture -> () in
                innerFuture.onComplete(ImmediateExecutionContext) { res in
                    complete(res.analysis(ifSuccess: {
                        return .success($0)
                    }, ifFailure: {
                        return .failure($0)
                    }))
                }
            }, ifFailure: {
                complete(.failure($0))
            })
        }
    }
}
