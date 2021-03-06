import Foundation
import Metal

public enum TextureTimingStyle {
    case stillImage
    case videoFrame(timestamp:Timestamp)
    
    func isTransient() -> Bool {
        switch self {
        case .stillImage: return false
        case .videoFrame: return true
        }
    }
    
    var timestamp:Timestamp? {
        get {
            switch self {
            case .stillImage: return nil
            case let .videoFrame(timestamp): return timestamp
            }
        }
    }
}

public class Texture {
    public var timingStyle: TextureTimingStyle = .stillImage
    public var orientation: ImageOrientation
    
    public let texture: MTLTexture
    weak var cache: TextureCache? = nil
    var hash: Int64
//    var retainCount: Int = 1
    public init(orientation: ImageOrientation, texture: MTLTexture) {
        self.orientation = orientation
        self.texture = texture
        self.hash = hashForTexture(width: texture.width, height: texture.height, pixelFormat: texture.pixelFormat, mipmapped: texture.mipmapLevelCount != 1)
    }
    
    public init(device:MTLDevice, orientation: ImageOrientation, pixelFormat: MTLPixelFormat = .bgra8Unorm, width: Int, height: Int, mipmapped:Bool = false) {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                         width: width,
                                                                         height: height,
                                                                         mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        
        guard let newTexture = sharedMetalRenderingDevice.device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Could not create texture of size: (\(width), \(height))")
        }

        self.orientation = orientation
        self.texture = newTexture
        self.hash = hashForTexture(width: width, height: height, pixelFormat: pixelFormat, mipmapped: mipmapped)
    }
    
    deinit {
        if let cache = cache {
            let newTexture = Texture(orientation: orientation, texture: texture)
            newTexture.cache = cache
            cache.returnToCache(newTexture)
        }
    }
}

extension Texture {
    public func textureCoordinates(for outputOrientation:ImageOrientation, normalized:Bool) -> [Float] {
        let inputRotation = self.orientation.rotationNeeded(for:outputOrientation)

        let xLimit:Float
        let yLimit:Float
        if normalized {
            xLimit = 1.0
            yLimit = 1.0
        } else {
            xLimit = Float(self.texture.width)
            yLimit = Float(self.texture.height)
        }
        
        switch inputRotation {
        case .noRotation: return [0.0, 0.0, xLimit, 0.0, 0.0, yLimit, xLimit, yLimit]
        case .rotateCounterclockwise: return [0.0, yLimit, 0.0, 0.0, xLimit, yLimit, xLimit, 0.0]
        case .rotateClockwise: return [xLimit, 0.0, xLimit, yLimit, 0.0, 0.0, 0.0, yLimit]
        case .rotate180: return [xLimit, yLimit, 0.0, yLimit, xLimit, 0.0, 0.0, 0.0]
        case .flipHorizontally: return [xLimit, 0.0, 0.0, 0.0, xLimit, yLimit, 0.0, yLimit]
        case .flipVertically: return [0.0, yLimit, xLimit, yLimit, 0.0, 0.0, xLimit, 0.0]
        case .rotateClockwiseAndFlipVertically: return [0.0, 0.0, 0.0, yLimit, xLimit, 0.0, xLimit, yLimit]
        case .rotateClockwiseAndFlipHorizontally: return [xLimit, yLimit, xLimit, 0.0, 0.0, yLimit, 0.0, 0.0]
        }
    }
    
//    func croppedTextureCoordinates(offsetFromOrigin:Position, cropSize:Size) -> [Float] {
//        let minX = offsetFromOrigin.x
//        let minY = offsetFromOrigin.y
//        let maxX = offsetFromOrigin.x + cropSize.width
//        let maxY = offsetFromOrigin.y + cropSize.height
//
//        switch self {
//        case .noRotation: return [minX, minY, maxX, minY, minX, maxY, maxX, maxY]
//        case .rotateCounterclockwise: return [minX, maxY, minX, minY, maxX, maxY, maxX, minY]
//        case .rotateClockwise: return [maxX, minY, maxX, maxY, minX, minY, minX, maxY]
//        case .rotate180: return [maxX, maxY, minX, maxY, maxX, minY, minX, minY]
//        case .flipHorizontally: return [maxX, minY, minX, minY, maxX, maxY, minX, maxY]
//        case .flipVertically: return [minX, maxY, maxX, maxY, minX, minY, maxX, minY]
//        case .rotateClockwiseAndFlipVertically: return [minX, minY, minX, maxY, maxX, minY, maxX, maxY]
//        case .rotateClockwiseAndFlipHorizontally: return [maxX, maxY, maxX, minY, minX, maxY, minX, minY]
//        }
//    }
}
