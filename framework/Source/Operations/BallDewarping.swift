//
//  BallDewarping.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 1/3/19.
//  Copyright © 2019 Red Queen Coder, LLC. All rights reserved.
//

import UIKit

public class BallDewarping: SynchronziedOperation, ViewPortOnDome {
    public var longitude:Float = 0 {  // 0 ~ 360. 0: front
        didSet {
            uniformSettings[0] = longitude
            needUpdateTexture = true
        }
    }
    public var latitude:Float = 90 { // -20 ~ 90. 0: horizon
        didSet {
            uniformSettings[1] = latitude
            needUpdateTexture = true
        }
    }
    public var viewAngleX: Float = 54.0 {   // 0 ~ 180
        didSet {
            uniformSettings[2] = viewAngleX
            needUpdateTexture = true
        }
    }
    public var viewAngleY: Float  = 30.0 {  // 0 ~ 55
        didSet {
            uniformSettings[3] = viewAngleY
            needUpdateTexture = true
        }
    }
    public init() {
        super.init(fragmentFunctionName:"ballDewarpingFragment", numberOfInputs:1)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(90)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(0)
    }
}
