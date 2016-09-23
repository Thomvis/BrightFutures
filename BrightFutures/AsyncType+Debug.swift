//
//  AsyncType+Debug.swift
//  BrightFutures
//
//  Created by Oleksii on 23/09/2016.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import Result

public protocol LoggerType {
    func log(message: String)
}

struct Logger: LoggerType {
    func log(message: String) {
        print(message)
    }
}

public extension AsyncType where Value: ResultProtocol {
    public func debug(logger: LoggerType = Logger(), context c: @escaping ExecutionContext = DefaultThreadingModel(), messageBlock: @escaping (Self.Value) -> String) -> Self {
        return andThen(context: c, callback: { result in
            logger.log(message: messageBlock(result))
        })
    }
    
    public func debug(_ identifer: String? = nil, logger: LoggerType = Logger(), file: String = #file, line: UInt = #line, function: String = #function, context c: @escaping ExecutionContext = DefaultThreadingModel()) -> Self {
        return debug(logger: logger, context: c, messageBlock: { result -> String in
            let messageBody: String
            let resultString = result.analysis(ifSuccess: { _ in "succeeded" } , ifFailure: { _ in "failed" })
            
            if let identifer = identifer {
                messageBody = "Future \(identifer)"
            } else {
                messageBody = "\(file.lastPathComponent) at line \(line), func: \(function) - future"
            }
            
            return "\(messageBody) \(resultString)"
        })
    }
}

extension String {
    var lastPathComponent: String {
        return characters.split(separator: "/").lazy.last.flatMap({ String($0) }) ?? self
    }
}
