//
//  FloatOverlay.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/23/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

import CoreGraphics

public class FloatOverlay: SynchronziedOperation {
    public var frame: CGRect = CGRect.zero {
        didSet {
            updateFrame(frame)
        }
    }
    
    func updateFrame(_ frame: CGRect) {
        uniformSettings[0] = Float(frame.minX)
        uniformSettings[1] = Float(frame.minY)
        uniformSettings[2] = Float(frame.maxX)
        uniformSettings[3] = Float(frame.maxY)
    }
    
    public init(frame: CGRect) {
        super.init(fragmentFunctionName: "floatOverlayFragment", numberOfInputs:2)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(0)
        uniformSettings.appendUniform(0)
        self.frame = frame
        updateFrame(frame)
    }
}
