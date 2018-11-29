//
//  TextureCache.swift
//  GPUImage
//
//  Created by Chester Shen on 11/28/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

import Foundation
import Metal

public class TextureCache {
    var cache = [Int64: [Texture]]()
    let queue = DispatchQueue(label: "com.waylens.GPUImage.textureCacheQueue")
    public func requestTexture(width: Int, height: Int, orientation: ImageOrientation = .portrait, pixelFormat: MTLPixelFormat = .bgra8Unorm, mipmapped:Bool = false) -> Texture {
        let hash = hashForTexture(width: width, height: height, pixelFormat: pixelFormat, mipmapped: mipmapped)
        var texture: Texture?
        queue.sync {
            if (cache[hash]?.count ?? 0) > 0 {
                texture = cache[hash]!.removeLast()
                texture?.orientation = orientation
            } else {
                texture = Texture(device:sharedMetalRenderingDevice.device, orientation: orientation, pixelFormat: pixelFormat, width: width, height: height, mipmapped: mipmapped)
                texture?.cache = self
            }
        }
        return texture!
    }
    
    public func purgeAll() {
        queue.async {
            self.cache.removeAll()
        }
    }
    
    func returnToCache(_ texture: Texture) {
        queue.async {
            if self.cache[texture.hash] != nil {
                self.cache[texture.hash]?.append(texture)
            } else {
                self.cache[texture.hash] = [texture]
            }
        }
    }
}

func hashForTexture(width: Int, height: Int, pixelFormat: MTLPixelFormat, mipmapped:Bool) -> Int64 {
    let prime: Int64 = 31
    var hash: Int64 = 1
    hash = hash * prime + Int64(width)
    hash = hash * prime + Int64(height)
    hash = hash * prime + Int64(pixelFormat.rawValue)
    hash = hash * prime + (mipmapped ? 1231: 1237)
    return hash
}
