//
//  FutureType.swift
//  BrightFutures
//
//  Created by Thomas Visser on 26/07/15.
//  Copyright © 2015 Thomas Visser. All rights reserved.
//

import Foundation
import Result

public protocol FutureType: AsyncType {
    typealias Value: ResultType
}