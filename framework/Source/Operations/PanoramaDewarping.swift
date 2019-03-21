//
//  PanoramaDewarping.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/19/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

public class PanoramaDewarping: SynchronziedOperation, ViewPortOnDome {
    public var longitude:Float = 0 {  // 0 ~ 360. 0: front
        didSet {
            uniformSettings[0] = longitude
            needUpdateTexture = true
        }
    }
    public var latitude:Float = 0 { // -20 ~ 90. 0: horizon
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
    public var facedown: Float  = 0.0 {  // 0 ~ 55
        didSet {
            uniformSettings[4] = facedown
            needUpdateTexture = true
        }
    }
    
    public init() {
        super.init(fragmentFunctionName:"panoramaDewarpingFragment", numberOfInputs:1)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(54)
        uniformSettings.appendUniform(30)
        uniformSettings.appendUniform(0)
    }
}
