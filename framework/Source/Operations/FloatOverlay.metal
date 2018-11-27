//
//  FloatOverlay.metal
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/23/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

#include <metal_stdlib>
#include "OperationShaderTypes.h"
using namespace metal;

typedef struct {
    float x1;
    float y1;
    float x2;
    float y2;
} FloatOverlayUniform;


fragment half4 floatOverlayFragment(TwoInputVertexIO fragmentInput [[stage_in]],
                                    texture2d<half> inputTexture [[texture(0)]],
                                    texture2d<half> inputTexture2 [[texture(1)]],
                                    constant FloatOverlayUniform& uniform [[ buffer(1)]])
{
    constexpr sampler quadSampler;
    
    float2 textureCoordinate = fragmentInput.textureCoordinate;
    if (textureCoordinate.x >= uniform.x1 && textureCoordinate.x <= uniform.x2 && textureCoordinate.y >= uniform.y1 && textureCoordinate.y <= uniform.y2) {
        float2 textureCoordinateToUse = float2((textureCoordinate.x - uniform.x1)/(uniform.x2 - uniform.x1), (textureCoordinate.y - uniform.y1)/(uniform.y2 - uniform.y1));
//        return half4(1, 1, 1, 1);
        return inputTexture2.sample(quadSampler, textureCoordinateToUse);
    } else {
        return inputTexture.sample(quadSampler, textureCoordinate);
    }
}
