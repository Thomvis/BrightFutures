//
//  Dispatch+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 13/08/16.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import Foundation

public extension DispatchQueue {
    var context: ExecutionContext {
        return { task in
            self.async(execute: task)
        }
    }
    
    func asyncValue<T>(_ execute: @escaping () -> T) -> Future<T, Never> {
        return Future { completion in
            async {
                completion(.success(execute()))
            }
        }
    }
    
    func asyncResult<T, E>(_ execute: @escaping () -> Result<T, E>) -> Future<T, E> {
        return Future { completion in
            async {
                completion(execute())
            }
        }
    }
    
    func asyncValueAfter<T>(_ deadline: DispatchTime, execute: @escaping () -> T) -> Future<T, Never> {
        return Future { completion in
            asyncAfter(deadline: deadline) {
                completion(.success(execute()))
            }
        }
    }
    
}

public extension DispatchSemaphore {
    var context: ExecutionContext {
        return { task in
            let _ = self.wait(timeout: DispatchTime.distantFuture)
            task()
            self.signal()
        }
    }
}
