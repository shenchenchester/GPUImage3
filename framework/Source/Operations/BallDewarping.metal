//
//  BallDewarping.metal
//  GPUImage_iOS
//
//  Created by Chester Shen on 1/3/19.
//  Copyright © 2019 Red Queen Coder, LLC. All rights reserved.
//

#include <metal_stdlib>
#include "OperationShaderTypes.h"
using namespace metal;

#define Pi 3.14159265

typedef struct {
    float longitude;
    float latitude;
    float viewAngleX;
    float viewAngleY;
    float facedown;
} BallDewarpingUniform;


fragment half4 ballDewarpingFragment(SingleInputVertexIO fragmentInput [[stage_in]],
                                         texture2d<half> inputTexture [[texture(0)]],
                                         constant BallDewarpingUniform& uniform [[buffer(1)]])
{
    constexpr sampler quadSampler;
    float si = 1 - uniform.facedown * 2;
    float scaleZ = si * uniform.viewAngleY / 180.0;
    float scaleY = si * uniform.viewAngleX / 180.0;
    float z = (1 - fragmentInput.textureCoordinate.y * 2) * scaleZ;
    float x = (fragmentInput.textureCoordinate.x * 2 - 1) * scaleY;
    float latRadian = uniform.latitude / 180.0 * Pi;
    float tmp = 1 - x * x - z * z;
    if (tmp < 0) {
        return half4(0, 0, 0, 0);
    }
    float sint = sin(latRadian) * sqrt(tmp) + z * cos(latRadian);
//    if (sint > 1 || sint < -1) {
//        return half4(0, 0, 0, 0);
//    }
    float theta = asin(sint);
    float sa = x / cos(theta);
    float ca = (cos(latRadian) * sin(theta) - z) / (sin(latRadian) * cos(theta));
    sa = max(-1.0, min(sa, 1.0));
    float angle = asin(sa);
    if (sa > 0 && ca < 0) {
        angle = Pi - angle;
    } else if (sa < 0 && ca < 0) {
        angle = -Pi - angle;
    }
    angle += uniform.longitude / 180.0 * Pi;
    float radius = (1 - theta / (0.5 * Pi)) * (90.0 / 110.0) / 2;
    if (radius > 0.5) {
        return half4(0, 0, 0, 0);
    }
    float2 textureCoordinateToUse = float2( 0.5 + sin(angle) * radius, 0.5 + cos(angle) * radius);
    return inputTexture.sample(quadSampler, textureCoordinateToUse);
}
