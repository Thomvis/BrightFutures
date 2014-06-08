//
//  Promise.swift
//  TVFutures
//
//  Created by Thomas Visser on 03/06/14.
//
//

import Foundation

class Promise<T: AnyObject> {

    let future: Future<T> = Future<T>()
    
    func complete(result: TaskResult<T>) {
        self.future.complete(result)
    }
    
    func tryComplete(result: TaskResult<T>) -> Bool {
        return self.future.tryComplete(result)
    }
    
    func success(value: T?) {
        self.future.success(value)
    }
    
    func trySuccess(value: T?) -> Bool {
        return self.future.trySuccess(value)
    }
    
    func error(error: NSError) {
        self.future.error(error)
    }
    
    func tryError(error: NSError) -> Bool {
        return self.future.tryError(error)
    }
    
}