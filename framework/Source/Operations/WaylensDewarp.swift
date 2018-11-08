//
//  WaylensDewarp.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 10/30/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

public class WaylensDewarp: BasicOperation {
    public var splitMode:Float = 0 { didSet { uniformSettings[0] = splitMode } }  // 1: split; 0: oneside; 2: immersive;
    public var showTimeLabel:Float = 0 { didSet { uniformSettings[1] = showTimeLabel } }  // 1: show; 0: no
    public var immersiveAngle:Float = 0 { didSet { uniformSettings[2] = immersiveAngle } } // 0-360. 0: towards front
    
    public init() {
        super.init(fragmentFunctionName:"dewarpFragment", numberOfInputs:1)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(0.0)
    }
}
