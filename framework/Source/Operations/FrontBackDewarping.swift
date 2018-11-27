//
//  FrontBackDewarping.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/22/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

public class FrontBackDewarping: SynchronziedOperation {
    public init() {
        super.init(fragmentFunctionName:"frontbackDewarpingFragment", numberOfInputs:1)
    }
}
