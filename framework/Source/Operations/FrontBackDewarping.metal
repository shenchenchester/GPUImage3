//
//  FrontBackDewarping.metal
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/22/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

#include <metal_stdlib>
#include "OperationShaderTypes.h"
using namespace metal;

typedef struct {
    float longitude;
    float latitude;
    float viewAngleX;
    float viewAngleY;
    float lensRotate;
} perspectiveDewarpingUniform;

fragment half4 frontbackDewarpingFragment(SingleInputVertexIO fragmentInput [[stage_in]],
                            texture2d<half> inputTexture [[texture(0)]],
                            constant perspectiveDewarpingUniform& uniform [[buffer(1)]])
{
    constexpr sampler quadSampler;
    
    
    float2 textureCoordinateToUse;
    float2 textureCoordinate = fragmentInput.textureCoordinate;
    float widthPitch = 1.0;

    if (uniform.lensRotate == 0.0) {
        if (textureCoordinate.y > 0.5)
        {
            /* bottom */
            float radius = textureCoordinate.y / 2.0;
            radius *= 0.98;
            float angle = (textureCoordinate.x - 0.5) / 0.5 * 3.1416 * 0.55;
            textureCoordinateToUse = float2((0.5 + sin(angle) * radius) * widthPitch, 0.5 + cos(angle) * radius);
        }
        else
        {
            /* top */
            float radius = 0.5 / 2.0 + textureCoordinate.y / 2.0;
            radius = radius * 0.85 + 0.5 * 0.15;
            radius *= 0.98;
            float angle = (textureCoordinate.x - 0.5) / 0.5 * 3.1416 * 0.48;
            textureCoordinateToUse = float2((0.5 - sin(angle) * radius) * widthPitch, 0.5 - cos(angle) * radius);
            
        }
    } else {
        if (textureCoordinate.y > 0.5)
        {
            /* bottom */
            float angle = - (textureCoordinate.x - 0.5) / 0.5 * 3.1416 * 0.55;
            float radius = 0.75 - (0.5 / 2.0 + (textureCoordinate.y - 0.5) / 2.0 * cos(angle/1.5));
            radius *= 0.98;
            textureCoordinateToUse = float2((0.5 + sin(angle) * radius) * widthPitch, 0.5 + cos(angle) * radius);
        }
        else
        {
            /* top */
            float angle = - (textureCoordinate.x - 0.5) / 0.5 * 3.1416 * 0.48;
            float radius = 0.75 - (0.5 / 2.0 + textureCoordinate.y / 2.0 * cos(angle/1.5));
            radius = radius * 0.85 + 0.5 * 0.15;
            radius *= 0.98;
            textureCoordinateToUse = float2((0.5 - sin(angle) * radius) * widthPitch, 0.5 - cos(angle) * radius);
            
        }
    }
    return inputTexture.sample(quadSampler, textureCoordinateToUse );
}
