//
//  WaylensDewarp.metal
//  GPUImage_iOS
//
//  Created by Chester Shen on 10/30/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

#include <metal_stdlib>
#include "OperationShaderTypes.h"
using namespace metal;

typedef struct {
    float splitMode; // 0: oneside; 1: split; 2: immersive
    float showTimeLabel;
    float immersiveAngle;
} WaylensDewarpUniform;


fragment half4 dewarpFragment(SingleInputVertexIO fragmentInput [[stage_in]],
                                         texture2d<half> inputTexture [[texture(0)]],
                                         constant WaylensDewarpUniform& uniform [[buffer(1)]])
{
    constexpr sampler quadSampler;
    
    
    float2 textureCoordinateToUse;
    float2 textureCoordinate = fragmentInput.textureCoordinate;
    float widthPitch = 1952.0/1984.0;
    int splitMode = uniform.splitMode;
    int showTimeLabel = uniform.showTimeLabel;
    
    if ((splitMode != 2) && (showTimeLabel == 1) && (textureCoordinate.y > 0.5 * 1.94) && (textureCoordinate.x < 0.3)) {
        textureCoordinateToUse = float2(textureCoordinate.x / 1.58, (textureCoordinate.y - 0.5 * 1.94) * 0.36);
    } else
        if (splitMode == 1) {
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
        } else if (splitMode == 0) {
            float radius = 0.5 / 2.0 + textureCoordinate.y / 4.0;
            radius = radius * 0.9 + 0.5 * 0.1;
            radius *= 0.98;
            float angle = (textureCoordinate.x - 0.5) / 0.5 * 3.1416 * 0.30 + uniform.immersiveAngle / 180.0 * 3.1416;
            textureCoordinateToUse = float2((0.5 - sin(angle) * radius) * widthPitch, 0.5 - cos(angle) * radius);
            
        } else {
            if ((showTimeLabel == 1) &&
                (textureCoordinate.y > 0.5 * 2.0 * 0.71) &&
                (textureCoordinate.y < 0.5 * 2.0 * 0.755) &&
                (textureCoordinate.x < 0.5)) {
                textureCoordinateToUse = float2(textureCoordinate.x / 1.58 * 0.6, (textureCoordinate.y - 0.5 * 2.0 * 0.71) * 0.36 * 0.6);
            } else if (textureCoordinate.y < 0.5 * 2.0 * 0.68) {
                float radius = textureCoordinate.y / 2.0/ 0.68;
                float angle = textureCoordinate.x / 0.5 * 3.1416 - 3.1416 / 2.0;
                textureCoordinateToUse = float2((0.5 - sin(angle) * radius) * widthPitch, 0.5 - cos(angle) * radius);
            } else {
                return half4(0.0, 0.0, 0.0, 0.0);
            }
        }
    return inputTexture.sample(quadSampler, textureCoordinateToUse );
}
