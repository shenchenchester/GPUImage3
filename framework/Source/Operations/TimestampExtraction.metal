//
//  TimestampExtraction.metal
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/23/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

#include <metal_stdlib>
#include "OperationShaderTypes.h"
using namespace metal;

fragment half4 timestampExtractionFragment(SingleInputVertexIO fragmentInput [[stage_in]],
                                          texture2d<half> inputTexture [[texture(0)]])
{
    constexpr sampler quadSampler;
    
    float2 textureCoordinateToUse;
    float2 textureCoordinate = fragmentInput.textureCoordinate;
    
    textureCoordinateToUse = float2(textureCoordinate.x * 0.19057, textureCoordinate.y * 0.01025);
    half4 color = inputTexture.sample(quadSampler, textureCoordinateToUse);
    if (color.r < 0.3 || color.g < 0.3 || color.b < 0.3) {
        return half4(0, 0, 0, 1);
    } else {
        return color;
    }
}


