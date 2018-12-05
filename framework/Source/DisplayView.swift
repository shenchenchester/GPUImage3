//
//  DisplayView.swift
//  SC360
//
//  Created by Chester Shen on 11/9/18.
//  Copyright © 2018 Waylens. All rights reserved.
//

import Foundation
import MetalKit

public class DisplayView: MTKView, ImageConsumer {
    
    public let sources = SourceContainer()
    public let maximumInputs: UInt = 1
    var currentTexture: Texture?
    var renderPipelineState:MTLRenderPipelineState!
    var startTime: TimeInterval = 0
    var renderCount: Int = 0
    var lastDrawableId: Int = -1
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: sharedMetalRenderingDevice.device)
        
        commonInit()
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    private func commonInit() {
        framebufferOnly = false
        autoResizeDrawable = true
        
        self.device = sharedMetalRenderingDevice.device
        
        renderPipelineState = generateRenderPipelineState(device:sharedMetalRenderingDevice, vertexFunctionName:"oneInputVertex", fragmentFunctionName:"passthroughFragment", operationName:"RenderView")
        
        enableSetNeedsDisplay = false
        isPaused = true
    }
    
    public func newTextureAvailable(_ texture:Texture, fromSourceIndex:UInt) {
        currentTexture = texture
        draw()
    }
    
    public override func draw(_ rect: CGRect) {
        if let currentDrawable = self.currentDrawable, let texture = currentTexture {
            if CFAbsoluteTimeGetCurrent() - startTime > 5 {
                startTime = CFAbsoluteTimeGetCurrent()
                renderCount = 0
            } else {
                renderCount += 1
                let fps = Double(renderCount) / (CFAbsoluteTimeGetCurrent() - startTime)
                print("Display FPS \(fps)")
            }
            if #available(iOS 10.3, *) {
                
                if currentDrawable.drawableID <= lastDrawableId {
                    print("Duplicated drawable id", currentDrawable.drawableID)
                }
                lastDrawableId = currentDrawable.drawableID
            } else {
                // Fallback on earlier versions
            }
            let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer()
            
            let outputTexture = Texture(orientation: .portrait, texture: currentDrawable.texture)
            commandBuffer?.renderQuad(pipelineState: renderPipelineState, inputTextures: [0:texture], outputTexture: outputTexture)
            
            commandBuffer?.present(currentDrawable)
            commandBuffer?.commit()
//            commandBuffer?.waitUntilCompleted()
//            if let error = commandBuffer?.error {
//                print(error)
//            }
            currentTexture = nil
        }
    }
}
