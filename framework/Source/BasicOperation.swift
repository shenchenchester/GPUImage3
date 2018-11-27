import Foundation
import Metal

public func defaultVertexFunctionNameForInputs(_ inputCount:UInt) -> String {
    switch inputCount {
    case 1:
        return "oneInputVertex"
    case 2:
        return "twoInputVertex"
    default:
        return "oneInputVertex"
    }
}

open class BasicOperation: ImageProcessingOperation {
    
    public let maximumInputs: UInt
    public var overriddenOutputSize: Size?
    public let targets = TargetContainer()
    public let sources = SourceContainer()
    
    public var activatePassthroughOnNextFrame: Bool = false
    public var uniformSettings = ShaderUniformSettings()
    public var useMetalPerformanceShaders: Bool = false {
        didSet {
            if !sharedMetalRenderingDevice.metalPerformanceShadersAreSupported {
                print("Warning: Metal Performance Shaders are not supported on this device")
                useMetalPerformanceShaders = false
            }
        }
    }

    let renderPipelineState: MTLRenderPipelineState
    let operationName: String
    var inputTextures = [UInt:Texture]()
    let textureInputSemaphore = DispatchSemaphore(value:1)
    var useNormalizedTextureCoordinates = true
    var metalPerformanceShaderPathway: ((MTLCommandBuffer, [UInt:Texture], Texture) -> ())?

    public init(vertexFunctionName: String? = nil,
                fragmentFunctionName: String,
                numberOfInputs: UInt = 1,
                operationName: String = #file) {
        self.maximumInputs = numberOfInputs
        self.operationName = operationName
        
        let concreteVertexFunctionName = vertexFunctionName ?? defaultVertexFunctionNameForInputs(numberOfInputs)
        renderPipelineState = generateRenderPipelineState(device:sharedMetalRenderingDevice, vertexFunctionName:concreteVertexFunctionName, fragmentFunctionName:fragmentFunctionName, operationName:operationName)
    }
    
    public func transmitPreviousImage(to target: ImageConsumer, atIndex: UInt) {
        // TODO: Finish implementation later
    }
    
    public func newTextureAvailable(_ texture: Texture, fromSourceIndex: UInt) {
        let _ = textureInputSemaphore.wait(timeout:DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }
        
        inputTextures[fromSourceIndex] = texture

        guard (!activatePassthroughOnNextFrame) else { // Use this to allow a bootstrap of cyclical processing, like with a low pass filter
            activatePassthroughOnNextFrame = false
            //            updateTargetsWithTexture(outputTexture) // TODO: Fix this
            return
        }
        
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

            let outputTexture = Texture(device:sharedMetalRenderingDevice.device, orientation: .portrait, width: outputWidth, height: outputHeight)
            
            if let alternateRenderingFunction = metalPerformanceShaderPathway, useMetalPerformanceShaders {
                var rotatedInputTextures: [UInt:Texture]
                if (firstInputTexture.orientation.rotationNeeded(for:.portrait) != .noRotation) {
                    let rotationOutputTexture = Texture(device:sharedMetalRenderingDevice.device, orientation: .portrait, width: outputWidth, height: outputHeight)
                    guard let rotationCommandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer() else {return}
                    rotationCommandBuffer.renderQuad(pipelineState: sharedMetalRenderingDevice.passthroughRenderState, uniformSettings: uniformSettings, inputTextures: inputTextures, useNormalizedTextureCoordinates: useNormalizedTextureCoordinates, outputTexture: rotationOutputTexture)
                    rotationCommandBuffer.commit()
                    rotatedInputTextures = inputTextures
                    rotatedInputTextures[0] = rotationOutputTexture
                } else {
                    rotatedInputTextures = inputTextures
                }
                alternateRenderingFunction(commandBuffer, rotatedInputTextures, outputTexture)
            } else {
                commandBuffer.renderQuad(pipelineState: renderPipelineState, uniformSettings: uniformSettings, inputTextures: inputTextures, useNormalizedTextureCoordinates: useNormalizedTextureCoordinates, outputTexture: outputTexture)
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            releaseIncomingTexturesAndUpdateTimestamp(outputTexture)
            updateTargetsWithTexture(outputTexture)
        }
    }
    
    func releaseIncomingTexturesAndUpdateTimestamp(_ outputTexture: Texture) {
        var remainingTextures = [UInt:Texture]()
        // If all inputs are still images, have this output behave as one
        outputTexture.timingStyle = .stillImage
        
        var latestTimestamp:Timestamp?
        for (key, texture) in inputTextures {
            
            // When there are multiple transient input sources, use the latest timestamp as the value to pass along
            if let timestamp = texture.timingStyle.timestamp {
                if !(timestamp < (latestTimestamp ?? timestamp)) {
                    latestTimestamp = timestamp
                    outputTexture.timingStyle = .videoFrame(timestamp:timestamp)
                }
                
            } else {
                remainingTextures[key] = texture
            }
        }
        inputTextures = remainingTextures
    }
}
