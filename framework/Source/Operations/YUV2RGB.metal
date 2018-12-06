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
    
    const float3x3 ycbcrToRGBTransform_BT709 = float3x3(
        float3(1.164, 1.164, 1.164),
        float3(0, -0.213, 2.112),
        float3(1.793, -0.533, 0)
    );
//    const float3x3 ycbcrToRGBTransform_BT601 = float3x3(
//        float3(+1.1644f, +1.1644f, +1.1644f),
//        float3(+0.0000f, -0.3918f, +2.0172f),
//        float3(+1.5960f, -0.8130f, +0.0000f)
//    );
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float3 ycbcr = float3(textureY.sample(colorSampler, in.textureCoordinate).r - 16.0 / 255.0,
                          textureCbCr.sample(colorSampler, in.textureCoordinate).rg - 128.0 / 255.0);
    
    
    // Return converted RGB color
    return float4(ycbcrToRGBTransform_BT709 * ycbcr, 1.0);
}
