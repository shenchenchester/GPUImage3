//
//  SyncOperation.swift
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/22/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

import Foundation
public protocol SynchronizedSource: class, ImageSource {
    var hasNewTexture: Bool { get set }
    var outputTexture: Texture? { get }
}

public protocol SynchronizedConsumer: ImageConsumer {
    var needUpdateTexture: Bool { get set }
}

public class SynchronziedOperation: BasicOperation, SynchronizedConsumer {
    public var needUpdateTexture: Bool = false
    
    override public func newTextureAvailable(_ texture: Texture, fromSourceIndex: UInt) {
        needUpdateTexture = false
        super.newTextureAvailable(texture, fromSourceIndex: fromSourceIndex)
    }
}

extension ImageConsumer {
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

extension ImageSource {
    public func updateTargetsIfNeeded() {
        if let this = self as? SynchronizedSource, let texture = this.outputTexture {
            if this.hasNewTexture {
                this.hasNewTexture = false
                updateTargetsWithTexture(texture)
            } else {
                for (target, index) in targets {
                    if target.downStreamNeedUpdate() {
                        target.newTextureAvailable(texture, fromSourceIndex:index)
                    }
                }
            }
        } else {
            for (target, _) in targets {
                if let target = target as? ImageSource {
                    target.updateTargetsIfNeeded()
                }
            }
        }
    }
}
