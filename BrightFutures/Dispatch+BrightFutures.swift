//
//  Dispatch+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 13/08/16.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import Foundation
import Result

public extension DispatchQueue {
    public var context: ExecutionContext {
        return { task in
            self.async(execute: task)
        }
    }
    
    public func asyncValue<T>(_ execute: @escaping () -> T) -> Future<T, NoError> {
        return Future { completion in
            async {
                completion(.success(execute()))
            }
        }
    }
    
    public func asyncResult<T, E: Error>(_ execute: @escaping () -> Result<T, E>) -> Future<T, E> {
        return Future { completion in
            async {
                completion(execute())
            }
        }
    }
    
    public func asyncValueAfter<T>(_ deadline: DispatchTime, execute: @escaping () -> T) -> Future<T, NoError> {
        return Future { completion in
            asyncAfter(deadline: deadline) {
                completion(.success(execute()))
            }
        }
    }
    
}

public extension DispatchSemaphore {
    public var context: ExecutionContext {
        return { task in
            let _ = self.wait(timeout: DispatchTime.distantFuture)
            task()
            self.signal()
        }
    }
}
