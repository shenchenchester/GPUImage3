//
//  YUV2RGB.metal
//
//  Created by Chester Shen on 11/9/18.
//  Copyright © 2018 Waylens. All rights reserved.
//

#include <metal_stdlib>
#include "OperationShaderTypes.h"
using namespace metal;

// Captured image fragment function
fragment float4 YUV2RGBFragment(SingleInputVertexIO in [[stage_in]],
                                            texture2d<float, access::sample> textureY [[ texture(0) ]],
                                            texture2d<float, access::sample> textureCbCr [[ texture(1) ]]) {
    
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    const float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float4 ycbcr = float4(textureY.sample(colorSampler, in.textureCoordinate).r,
                          textureCbCr.sample(colorSampler, in.textureCoordinate).rg, 1.0);
    
    // Return converted RGB color
    return ycbcrToRGBTransform * ycbcr;
}
