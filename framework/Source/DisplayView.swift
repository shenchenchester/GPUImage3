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
            let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer()
            
            let outputTexture = Texture(orientation: .portrait, texture: currentDrawable.texture)
            commandBuffer?.renderQuad(pipelineState: renderPipelineState, inputTextures: [0:texture], outputTexture: outputTexture)
            
            commandBuffer?.present(currentDrawable)
            commandBuffer?.commit()
//            commandBuffer?.waitUntilCompleted()
            currentTexture = nil
        }
    }
}
