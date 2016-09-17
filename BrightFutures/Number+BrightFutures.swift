//
//  Number+BrightFutures.swift
//  BrightFutures
//
//  Created by Thomas Visser on 13/08/16.
//  Copyright © 2016 Thomas Visser. All rights reserved.
//

import Foundation

public extension Int {
    
    public var seconds: DispatchTimeInterval {
        return DispatchTimeInterval.seconds(self)
    }
    
    public var second: DispatchTimeInterval {
        return seconds
    }
    
    public var milliseconds: DispatchTimeInterval {
        return DispatchTimeInterval.milliseconds(self)
    }
    
    public var millisecond: DispatchTimeInterval {
        return milliseconds
    }
    
}

public extension DispatchTimeInterval {
    public var fromNow: DispatchTime {
        return DispatchTime.now() + self
    }
}
