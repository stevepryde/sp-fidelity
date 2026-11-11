// Generated from unchanged AMD SDK 1.1.4 UI composition HLSL.
// Copyright (C) 2024 Advanced Micro Devices, Inc. MIT; see vendor license.
#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct mainVS_out
{
    float4 gl_Position [[position]];
};

vertex mainVS_out mainVS(uint gl_VertexIndex [[vertex_id]])
{
    mainVS_out out = {};
    out.gl_Position = float4(float((int(gl_VertexIndex & 1u) * 4) - 1), float((int(gl_VertexIndex & 2u) * (-2)) + 1), 0.5, 1.0);
    return out;
}

