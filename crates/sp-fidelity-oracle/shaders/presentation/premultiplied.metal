// Generated from unchanged AMD SDK 1.1.4 UI composition HLSL.
// Copyright (C) 2024 Advanced Micro Devices, Inc. MIT; see vendor license.
#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct mainPS_out
{
    float4 out_var_SV_Target [[color(0)]];
};

fragment mainPS_out mainPS(texture2d<float> r_currBB [[texture(0)]], texture2d<float> r_uiTexture [[texture(1)]], float4 gl_FragCoord [[position]])
{
    mainPS_out out = {};
    uint2 _23 = uint2(gl_FragCoord.xy);
    float4 _28 = r_uiTexture.read(uint2(_23), 0u);
    out.out_var_SV_Target = float4((r_currBB.read(uint2(_23), 0u).xyz * (1.0 - _28.w)) + _28.xyz, 1.0);
    return out;
}

