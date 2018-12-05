//
//  SyncOperation.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/22/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

import Foundation
import Metal

public protocol CachedImageSource: ImageSource {
    var outputTexture: Texture? { get }
}

public class SynchronziedOperation: BasicOperation {
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
            commandBuffer.waitUntilCompleted()
            updateTargetsWithTexture(outputTexture)
        }
    }
    
    override func releaseIncomingTexturesAndUpdateTimestamp(_ outputTexture: Texture) {
        // If all inputs are still images, have this output behave as one
        outputTexture.timingStyle = .stillImage
        
        var latestTimestamp:Timestamp?
        for (_, texture) in inputTextures {
            // When there are multiple transient input sources, use the latest timestamp as the value to pass along
            if let timestamp = texture.timingStyle.timestamp {
                if !(timestamp < (latestTimestamp ?? timestamp)) {
                    latestTimestamp = timestamp
                    outputTexture.timingStyle = .videoFrame(timestamp:timestamp)
                }
            }
        }
        autoreleasepool {
            inputTextures = [UInt:Texture]()
        }
    }
}

public enum TextureUpdateResult {
    case notNeed
    case needUpdate
    case updated
}

public class CachedImageRelay: ImageRelay, CachedImageSource {
    public var outputTexture: Texture?
   
    public override func newTextureAvailable(_ texture: Texture, fromSourceIndex: UInt) {
        outputTexture = texture
        super.newTextureAvailable(texture, fromSourceIndex: fromSourceIndex)
    }
}

public extension ImageSource {
    func updateTargetIfNeeded() -> Bool {
        if let this = self as? SynchronziedOperation, this.needUpdateTexture {
            return true
        }
        var texture: Texture? = nil
        if let this = self as? CachedImageSource {
            texture = this.outputTexture
        }
        for (target, index) in targets {
            if let sourceTarget = target as? ImageProcessingOperation, sourceTarget.updateTargetIfNeeded() {
                if let texture = texture {
                    sourceTarget.newTextureAvailable(texture, fromSourceIndex: index)
                } else {
                    return true
                }
            }
        }
        return false
    }
}
