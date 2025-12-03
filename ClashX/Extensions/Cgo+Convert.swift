//
//  Cgo+Convert.swift
//  ClashX
//
//  Created by yicheng on 2019/10/2.
//  Copyright © 2019 west2online. All rights reserved.
//

extension String {
    func goStringBuffer() -> UnsafeMutablePointer<Int8> {
        if let pointer = (self as NSString).utf8String {
            return UnsafeMutablePointer(mutating: pointer)
        }
        Logger.log("Convert goStringBuffer Fail!!!!", level: .error)
        let p = ("" as NSString).utf8String!
        return UnsafeMutablePointer(mutating: p)
    }
}
