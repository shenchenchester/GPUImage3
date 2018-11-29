//
//  SyncOperation.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/22/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

import Foundation
import Metal

public protocol SynchronizedConsumer: ImageConsumer {
    var needUpdateTexture: Bool { get set }
}

public class SynchronziedOperation: BasicOperation, SynchronizedConsumer {
    public var needUpdateTexture: Bool = false
    override public func newTextureAvailable(_ texture: Texture, fromSourceIndex: UInt) {
        needUpdateTexture = false
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }
        
        inputTextures[fromSourceIndex] = texture
        
        if (UInt(inputTextures.count) >= maximumInputs) {
            let outputWidth:Int
            let outputHeight:Int
            
            let firstInputTexture = inputTextures[0]!
            if let outputSize = overriddenOutputSize {
                outputWidth = Int(outputSize.width)
                outputHeight = Int(outputSize.height)
            } else {
                if firstInputTexture.orientation.rotationNeeded(for:.portrait).flipsDimensions() {
                    outputWidth = firstInputTexture.texture.height
                    outputHeight = firstInputTexture.texture.width
                } else {
                    outputWidth = firstInputTexture.texture.width
                    outputHeight = firstInputTexture.texture.height
                }
            }
            
            guard let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer() else {return}
            
            let outputTexture = sharedMetalRenderingDevice.cache.requestTexture(width: outputWidth, height: outputHeight)
            commandBuffer.renderQuad(pipelineState: renderPipelineState, uniformSettings: uniformSettings, inputTextures: inputTextures, useNormalizedTextureCoordinates: useNormalizedTextureCoordinates, outputTexture: outputTexture)
            commandBuffer.commit()
            releaseIncomingTexturesAndUpdateTimestamp(outputTexture)
            updateTargetsWithTexture(outputTexture)
        }
    }
}

public extension ImageConsumer {
    func downStreamNeedUpdate() -> Bool {
        if let this = self as? SynchronizedConsumer, this.needUpdateTexture {
            return true
        } else if let source = self as? ImageSource {
            for (target, _) in source.targets {
                if target.downStreamNeedUpdate() {
                    return true
                }
            }
        }
        return false
    }
}
