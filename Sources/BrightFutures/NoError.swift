//
//  NoError.swift
//  BrightFutures-iOS
//
//  Created by Kim de Vos on 26/03/2019.
//  Copyright © 2019 Thomas Visser. All rights reserved.
//

import Foundation

/// An “error” that is impossible to construct.
///
/// This can be used to describe `Result`s where failures will never
/// be generated. For example, `Result<Int, NoError>` describes a result that
/// contains an `Int`eger and is guaranteed never to be a `failure`.
public enum NoError: Swift.Error, Equatable {
    public static func ==(lhs: NoError, rhs: NoError) -> Bool {
        return true
    }
}
