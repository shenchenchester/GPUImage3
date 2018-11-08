//
//  WaylensMovieInput.swift
//  SimpleMovieFilter
//
//  Created by gliu on 9/18/17.
//  Copyright © 2017 Sunset Lake Software LLC. All rights reserved.
//

import AVFoundation
import UIKit

public protocol WaylensImageConsumer:ImageConsumer {
    func setWidthPitch(_ widthpitch:Float)
}
public protocol WaylensMovieInputProgressDelegate: AnyObject {
    func onConsumeProgress(_ percent:Float)
    func onInputFinished(finished:Bool)
}
public class WaylensMovieInput: ImageSource {
    public let targets = TargetContainer()
    public var runBenchmark = false
    public var width_pitch : Float = 1.0
    public weak var delegate : WaylensMovieInputProgressDelegate?
    
    let inputFrameProcessingQueue = DispatchQueue(
        label: "com.sunsetlakesoftware.GPUImage.inputFrameProcessingQueue",
        attributes: [])
    var videoTextureCache: CVMetalTextureCache?
    
    let asset:AVAsset
    let assetReader:AVAssetReader
    let playAtActualSpeed:Bool
    let loop:Bool
    var videoEncodingIsFinished = false
    var previousFrameTime = CMTime.zero
    var previousActualFrameTime = CFAbsoluteTimeGetCurrent()
    
    public var numberOfFramesCaptured = 0
    public var numberOfFramesRead = 0
    var totalFrameTimeDuringCapture:Double = 0.0
    var isPaused: Bool = false
    
    // TODO: Add movie reader synchronization
    // TODO: Someone will have to add back in the AVPlayerItem logic, because I don't know how that works
    public init(asset:AVAsset, playAtActualSpeed:Bool = false, loop:Bool = false) throws {
        self.asset = asset
        self.playAtActualSpeed = playAtActualSpeed
        self.loop = loop
        assetReader = try AVAssetReader(asset:self.asset)
        
//        let outputSettings:[String:AnyObject] = [(kCVPixelBufferPixelFormatTypeKey as String):NSNumber(value:Int32(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)), (kCVPixelBufferBytesPerRowAlignmentKey as String):NSNumber(value: 64)]
        let outputSettings:[String:AnyObject] = [(kCVPixelBufferPixelFormatTypeKey as String):NSNumber(value:Int32(kCVPixelFormatType_32BGRA)), (kCVPixelBufferBytesPerRowAlignmentKey as String):NSNumber(value: 64)]
        let readerVideoTrackOutput = AVAssetReaderTrackOutput(track:self.asset.tracks(withMediaType: .video)[0], outputSettings:outputSettings)
        readerVideoTrackOutput.alwaysCopiesSampleData = false
        assetReader.add(readerVideoTrackOutput)
        // TODO: Audio here
    }
    
    public convenience init(url:URL, playAtActualSpeed:Bool = false, loop:Bool = false) throws {
        let inputOptions = [AVURLAssetPreferPreciseDurationAndTimingKey:NSNumber(value:true)]
        let inputAsset = AVURLAsset(url:url, options:inputOptions)
        try self.init(asset:inputAsset, playAtActualSpeed:playAtActualSpeed, loop:loop)
    }
    
    // MARK: -
    // MARK: Playback control
    
    public func start() {
        let _ = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                          nil,
                                          sharedMetalRenderingDevice.device,
                                          nil,
                                          &videoTextureCache)
        asset.loadValuesAsynchronously(forKeys:["tracks"], completionHandler:{
            DispatchQueue.global(qos: .default).async {
                guard (self.asset.statusOfValue(forKey: "tracks", error:nil) == .loaded) else { return }
                
                guard self.assetReader.startReading() else {
                    print("Couldn't start reading")
                    return
                }
                
                var readerVideoTrackOutput:AVAssetReaderOutput? = nil;
                
                for output in self.assetReader.outputs {
                    if (output.mediaType == AVMediaType.video) {
                        readerVideoTrackOutput = output;
                    }
                }
                
                while (self.assetReader.status == .reading) {
                    self.readNextVideoFrame(from:readerVideoTrackOutput!)
                }
                if (self.assetReader.status == .completed || self.assetReader.status == .failed) {
                    self.assetReader.cancelReading()
                    if (self.loop) {
                        // TODO: Restart movie processing
                    } else {
                        self.endProcessing()
                    }
                }
            }
        })
    }
    
    public func cancel() {
        assetReader.cancelReading()
        self.endProcessing()
    }
    
    func endProcessing() {
        delegate?.onInputFinished(finished: assetReader.status == .completed)
    }
    
    public func pause() {
        isPaused = true
    }
    
    public func resume() {
        isPaused = false
    }
    
    // MARK: -
    // MARK: Internal processing functions
    
    func readNextVideoFrame(from videoTrackOutput:AVAssetReaderOutput) {
        print("reading next video frame")
        if ((assetReader.status == .reading) && !videoEncodingIsFinished) && !isPaused {
            if let sampleBuffer = videoTrackOutput.copyNextSampleBuffer() {
                if (playAtActualSpeed) {
                    // Do this outside of the video processing queue to not slow that down while waiting
                    let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                    let differenceFromLastFrame = CMTimeSubtract(currentSampleTime, previousFrameTime)
                    let currentActualTime = CFAbsoluteTimeGetCurrent()
                    
                    let frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame)
                    let actualTimeDifference = currentActualTime - previousActualFrameTime
                    
                    if (frameTimeDifference > actualTimeDifference) {
                        usleep(UInt32(round(1000000.0 * (frameTimeDifference - actualTimeDifference))))
                    }
                    
                    previousFrameTime = currentSampleTime
                    previousActualFrameTime = CFAbsoluteTimeGetCurrent()
                }
                numberOfFramesRead += 1
                let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                NSLog("read video frame at time: %f", currentSampleTime.seconds)
                self.delegate?.onConsumeProgress(Float(currentSampleTime.seconds / asset.duration.seconds))
                inputFrameProcessingQueue.sync {
                    self.process(movieFrame:sampleBuffer)
                    CMSampleBufferInvalidate(sampleBuffer)
                }
            } else {
                if (!loop) {
                    videoEncodingIsFinished = true
                }
            }
        }
        //        else if (synchronizedMovieWriter != nil) {
        //            if (assetReader.status == .Completed) {
        //                self.endProcessing()
        //            }
        //        }
        
    }
    
    func process(movieFrame frame:CMSampleBuffer) {
        let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(frame)
        let movieFrame = CMSampleBufferGetImageBuffer(frame)!
        
        //        processingFrameTime = currentSampleTime
        self.process(movieFrame:movieFrame, withSampleTime:currentSampleTime)
    }
    
    func process(movieFrame:CVPixelBuffer, withSampleTime:CMTime) {
        let bufferHeight = CVPixelBufferGetHeight(movieFrame)
        let bufferWidth = CVPixelBufferGetWidth(movieFrame)
//        let bufferPitch = (((bufferWidth) + 63) & ~63)
//        width_pitch = Float(bufferWidth) / Float(bufferPitch)
        let startTime = CFAbsoluteTimeGetCurrent()
        CVPixelBufferLockBaseAddress(movieFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
        var textureRef:CVMetalTexture? = nil
        let _ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                          self.videoTextureCache!,
                                                          movieFrame,
                                                          nil,
                                                          .bgra8Unorm,
                                                          bufferWidth,
                                                          bufferHeight,
                                                          0,
                                                          &textureRef)
        
        if let concreteTexture = textureRef,
            let movieTexture = CVMetalTextureGetTexture(concreteTexture) {
            let texture = Texture(orientation: .portrait, texture: movieTexture)
            texture.timingStyle = .videoFrame(timestamp: Timestamp(withSampleTime))
            self.updateTargetsWithTexture(texture)
        }
        CVPixelBufferUnlockBaseAddress(movieFrame, CVPixelBufferLockFlags(rawValue:CVOptionFlags(0)))
        if self.runBenchmark {
            let currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime)
            self.numberOfFramesCaptured += 1
            self.totalFrameTimeDuringCapture += currentFrameTime
            print("Average frame time : \(1000.0 * self.totalFrameTimeDuringCapture / Double(self.numberOfFramesCaptured)) ms")
            print("Current frame time : \(1000.0 * currentFrameTime) ms")
        }
    }
    
    public func transmitPreviousImage(to target:ImageConsumer, atIndex:UInt) {
        // Not needed for movie inputs
    }
}
