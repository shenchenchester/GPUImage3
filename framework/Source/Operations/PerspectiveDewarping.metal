//
//  PerspectiveDewarping.metal
//  GPUImage_iOS
//
//  Created by Chester Shen on 11/22/18.
//  Copyright © 2018 Red Queen Coder, LLC. All rights reserved.
//

#include <metal_stdlib>
#include "OperationShaderTypes.h"
using namespace metal;

#define Pi 3.14159265
#define SQUARE(x) (x)*(x)
typedef struct {
    float longitude;
    float latitude;
    float viewAngleX;
    float viewAngleY;
    float facedown;
} perspectiveDewarpingUniform;

fragment half4 perspectiveDewarpingFragment(SingleInputVertexIO fragmentInput [[stage_in]],
                                            texture2d<half> inputTexture [[texture(0)]],
                                            constant perspectiveDewarpingUniform& uniform [[buffer(1)]])
{
    constexpr sampler quadSampler;
    float si = 1 - uniform.facedown * 2;
    float dx = si * (fragmentInput.textureCoordinate.x * 2 - 1);
    float dy = si * (fragmentInput.textureCoordinate.y * 2 - 1);
    float w = uniform.viewAngleX * Pi / 180.0;
    float h = uniform.viewAngleY * Pi / 180.0;
    float theta = (90 - uniform.latitude) * Pi / 180.0;
    
    float ch = cos(h);
    float sh = sin(h);
    float ct = cos(theta);
    float st = sin(theta);
    float tmpx = dx * ch * tan(w) ;
    float r = acos((ct * ch - dy * st * sh) / sqrt(SQUARE(tmpx) + SQUARE(sh * dy) + SQUARE(ch)));
    float radius = r / Pi * (90.0 / 110.0);
    
    if (radius > 0.5 || radius < 0) {
        return half4(0, 0, 0, 0);
    }
    
    float tmpy = st * ch + dy * ct * sh;
    
    float phi;
    if (tmpy == 0) {
        phi = tmpx > 0 ? Pi * 0.5 : -Pi * 0.5;
    } else {
        phi = atan(tmpx / tmpy);
        if (tmpy < 0) {
            phi += Pi;
        }
    }
    float angle = uniform.longitude * Pi / 180.0 + phi;
    float2 textureCoordinateToUse = float2( 0.5 + sin(angle) * radius, 0.5 + cos(angle) * radius);
    return inputTexture.sample(quadSampler, textureCoordinateToUse);
}


//fragment half4 perspectiveDewarpingFragment(SingleInputVertexIO fragmentInput [[stage_in]],
//                                 texture2d<half> inputTexture [[texture(0)]],
//                                 constant perspectiveDewarpingUniform& uniform [[buffer(1)]])
//{
//    constexpr sampler quadSampler;
//    float si = 1 - uniform.facedown * 2;
//    float deltaY = atan(si * (fragmentInput.textureCoordinate.y * 2 - 1) * tan(uniform.viewAngleY * Pi / 180.0));
//    float deltaX = atan(si * (fragmentInput.textureCoordinate.x * 2 - 1) * tan(uniform.viewAngleX * Pi / 180.0));
//    float theta = (90 - uniform.latitude) * Pi / 180.0;
//    float cosa = cos(deltaY);
//    float sina = sin(deltaY);
//    float cosb = cos(deltaX);
//    float sinb = sin(deltaX);
//    float cost = cos(theta + deltaY);
//    float sint = sin(theta + deltaY);
//
//    float r = acos(cosb * cost / sqrt(cosa * cosa + cosb * cosb * sina * sina)) / Pi * (90.0 / 110.0);
//    //    float radius = -0.596909747 * r * r * r + 0.15990583 * r * r + 1.07184945 * r;
//    float radius = r;
//    if (radius > 0.5 || radius < 0) {
//        return half4(0, 0, 0, 0);
//    }
//    float tmpx = cosa * sinb;
//    float tmpy = -(cosb * sint);
//    float phi = atan( tmpx / tmpy);
//    if (tmpx > 0) {
//        if (tmpy <= 0) {
//            phi = -phi;
//        } else {
//            phi = Pi - phi;
//        }
//    } else {
//        if (tmpy <= 0) {
//            phi = -phi;
//        } else {
//            phi = -Pi - phi;
//        }
//    }
//    float angle = uniform.longitude * Pi / 180.0 + phi;
//    float2 textureCoordinateToUse = float2( 0.5 + sin(angle) * radius, 0.5 + cos(angle) * radius);
//    return inputTexture.sample(quadSampler, textureCoordinateToUse);
//}

