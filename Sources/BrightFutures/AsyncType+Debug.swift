//
//  AsyncType+Debug.swift
//  BrightFutures
//
//  Created by Oleksii on 23/09/2016.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import Foundation
import Result

public protocol LoggerType {
    func log(message: String)
    func message<Value>(for value: Value, with identifier: String?, file: String, line: UInt, function: String) -> String
}

public extension LoggerType {
    func message<Value>(for value: Value, with identifier: String?, file: String, line: UInt, function: String) -> String {
        let messageBody: String
        
        if let identifier = identifier {
            messageBody = "Future \(identifier)"
        } else {
            let fileName = (file as NSString).lastPathComponent
            messageBody = "\(fileName) at line \(line), func: \(function) - future"
        }
        
        return "\(messageBody) completed"
    }
}

public struct Logger: LoggerType {
    public init() {
    }
    
    public func log(message: String) {
        print(message)
    }
}

public extension AsyncType {
    public func debug(_ identifier: String? = nil, logger: LoggerType = Logger(), file: String = #file, line: UInt = #line, function: String = #function, context c: @escaping ExecutionContext = DefaultThreadingModel()) -> Self {
        return andThen(context: c, callback: { result in
            let message = logger.message(for: result, with: identifier, file: file, line: line, function: function)
            logger.log(message: message)
        })
    }
}
