//
//  WaylensMovieOutput.swift
//  SimpleMovieFilter
//
//  Created by gliu on 9/15/17.
//  Copyright © 2017 Sunset Lake Software LLC. All rights reserved.
//

//import UIKit
//import Foundation
import AVFoundation

public protocol WaylensMovieOutputDelegate: AnyObject {
    func onUpdateTime(Offset sec : Double)
    func onUpdateSubtitle(Text text : String)
}

public class WaylensMovieOutput: ImageConsumer {
    public let sources = SourceContainer()
    public let maximumInputs:UInt = 1
    
//    var widthPitch: Float
    
    let assetWriter:AVAssetWriter
    let assetWriterVideoInput:AVAssetWriterInput
    var assetWriterAudioInput:AVAssetWriterInput?
    
    let assetWriterPixelBufferInput:AVAssetWriterInputPixelBufferAdaptor
    let size:Size
//    var renderPipelineState:MTLRenderPipelineState!
    private var isRecording = false
    private var videoEncodingIsFinished = false
    private var audioEncodingIsFinished = false
    private var startTime:CMTime?
    private var previousFrameTime = CMTime.negativeInfinity
    private var previousAudioTime = CMTime.negativeInfinity
    private var encodingLiveVideo:Bool
    var pixelBuffer:CVPixelBuffer!
    var videoTextureCache: CVMetalTextureCache?
    let outputFrameProcessingQueue = DispatchQueue(
        label: "com.sunsetlakesoftware.GPUImage.outputFrameProcessingQueue",
        attributes: [])
    var renderTexture: Texture!
    public var encodedFrames: Int = 0
    public weak var delegate : WaylensMovieOutputDelegate?

    
    public init(URL:Foundation.URL, size:Size, dele: WaylensMovieOutputDelegate, fileType:AVFileType = .mov, liveVideo:Bool = false, settings:[String:AnyObject]? = nil) throws {
        
//        widthPitch = widthpitch
        self.size = size
        delegate = dele
        assetWriter = try AVAssetWriter(url:URL, fileType:fileType)
        // Set this to make sure that a functional movie is produced, even if the recording is cut off mid-stream. Only the last second should be lost in that case.
        assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, preferredTimescale: 1000)
        
        var localSettings:[String:AnyObject]
        if let settings = settings {
            localSettings = settings
        } else {
            localSettings = [String:AnyObject]()
        }
        
        localSettings[AVVideoWidthKey] = localSettings[AVVideoWidthKey] ?? NSNumber(value:size.width)
        localSettings[AVVideoHeightKey] = localSettings[AVVideoHeightKey] ?? NSNumber(value:size.height)
        localSettings[AVVideoCodecKey] =  localSettings[AVVideoCodecKey] ?? AVVideoCodecH264 as NSString
        let br = 25 * 1024 * 1024 * size.width / 1920
        let bitRate = NSNumber(value: br)
        let compressSettings : Dictionary<String, Any> = [AVVideoMaxKeyFrameIntervalDurationKey : NSNumber(value:2.0),
                                                          AVVideoAverageBitRateKey : bitRate,
                                                          AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel,
                                                          AVVideoAllowFrameReorderingKey : NSNumber(value:true)]
        localSettings[AVVideoCompressionPropertiesKey] = localSettings[AVVideoCompressionPropertiesKey] ?? compressSettings as AnyObject
        assetWriterVideoInput = AVAssetWriterInput(mediaType:.video, outputSettings:localSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = liveVideo
        encodingLiveVideo = liveVideo
        
        // You need to use BGRA for the video in order to get realtime encoding.
        let sourcePixelBufferAttributesDictionary:[String:AnyObject] = [kCVPixelBufferPixelFormatTypeKey as String:NSNumber(value:Int32(kCVPixelFormatType_32BGRA)),
                                                                        kCVPixelBufferWidthKey as String:NSNumber(value:size.width),
                                                                        kCVPixelBufferHeightKey as String:NSNumber(value:size.height)]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:assetWriterVideoInput, sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary)
        assetWriter.add(assetWriterVideoInput)
        
        let _ = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                          nil,
                                          sharedMetalRenderingDevice.device,
                                          nil,
                                          &videoTextureCache)
    }
    
    public func startRecording() {
        startTime = nil
        self.isRecording = self.assetWriter.startWriting()
        
        CVPixelBufferPoolCreatePixelBuffer(nil, self.assetWriterPixelBufferInput.pixelBufferPool!, &self.pixelBuffer)
        
        /* AVAssetWriter will use BT.601 conversion matrix for RGB to YCbCr conversion
         * regardless of the kCVImageBufferYCbCrMatrixKey value.
         * Tagging the resulting video file as BT.601, is the best option right now.
         * Creating a proper BT.709 video is not possible at the moment.
         */
        CVBufferSetAttachment(self.pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(self.pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, .shouldPropagate)
        CVBufferSetAttachment(self.pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        
        var cachedTextureRef: CVMetalTexture? = nil
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoTextureCache!, pixelBuffer, nil, .bgra8Unorm, Int(size.width), Int(size.height), 0, &cachedTextureRef)
        
        let cachedTexture = CVMetalTextureGetTexture(cachedTextureRef!)
        renderTexture = Texture(orientation: .portrait, texture: cachedTexture!)
    }
    
    public func finishRecording(_ completionCallback:(() -> Void)? = nil) {
        outputFrameProcessingQueue.sync {
            
            self.isRecording = false
            
            if (self.assetWriter.status == .completed || self.assetWriter.status == .cancelled || self.assetWriter.status == .unknown) {
//                sharedImageProcessingContext.runOperationAsynchronously{
                    completionCallback?()
//                }
                return
            }
            if ((self.assetWriter.status == .writing) && (!self.videoEncodingIsFinished)) {
                self.videoEncodingIsFinished = true
                self.assetWriterVideoInput.markAsFinished()
            }
            if ((self.assetWriter.status == .writing) && (!self.audioEncodingIsFinished)) {
                self.audioEncodingIsFinished = true
                self.assetWriterAudioInput?.markAsFinished()
            }
            
            // Why can't I use ?? here for the callback?
            if let callback = completionCallback {
                self.assetWriter.finishWriting(completionHandler: callback)
            } else {
                self.assetWriter.finishWriting{}
                
            }
        }
    }
    
    public func newTextureAvailable(_ texture: Texture, fromSourceIndex: UInt) {
        guard isRecording else { return }
        // Ignore still images and other non-video updates (do I still need this?)
        guard let frameTime = texture.timingStyle.timestamp?.asCMTime else { return }
        // If two consecutive times with the same value are added to the movie, it aborts recording, so I bail on that case
        guard (frameTime != previousFrameTime) else { return }
        
        if (startTime == nil) {
            if (assetWriter.status != .writing) {
                assetWriter.startWriting()
            }
            
            assetWriter.startSession(atSourceTime: frameTime)
            startTime = frameTime
        }
        previousFrameTime = frameTime
        outputFrameProcessingQueue.sync {
            if !self.assetWriterVideoInput.isReadyForMoreMediaData {
                if self.encodingLiveVideo {
                    debugPrint("Had to drop a frame at time \(frameTime)")
                    return
                } else {
                    // wait until ready
                    while (!self.assetWriterVideoInput.isReadyForMoreMediaData && self.isRecording) {
                        debugPrint("Waiting for writer to get ready...")
                        usleep(10000)
                    }
                    if !self.isRecording {
                        debugPrint("Output stopped mannually")
                        return
                    }
                }
            }
            
            self.delegate?.onUpdateTime(Offset: self.previousFrameTime.seconds - self.startTime!.seconds)
            
            
            CVPixelBufferLockBaseAddress(self.pixelBuffer, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
            let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer()
            
            commandBuffer?.renderQuad(pipelineState: sharedMetalRenderingDevice.passthroughRenderState, inputTextures: [0:texture], outputTexture: self.renderTexture)
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
            if (!self.assetWriterPixelBufferInput.append(self.pixelBuffer!, withPresentationTime:frameTime)) {
                debugPrint("Problem appending pixel buffer at time: \(frameTime)")
            }
            
            CVPixelBufferUnlockBaseAddress(self.pixelBuffer, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
            self.encodedFrames += 1;
        }
    }
}


public extension Timestamp {
    public init(_ time:CMTime) {
        self.value = time.value
        self.timescale = time.timescale
        self.flags = TimestampFlags(rawValue:time.flags.rawValue)
        self.epoch = time.epoch
    }
    
    public var asCMTime:CMTime {
        get {
            return CMTimeMakeWithEpoch(value: value, timescale: timescale, epoch: epoch)
        }
    }
}
