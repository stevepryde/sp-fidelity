// This file is part of the FidelityFX SDK.
//
// Copyright (C) 2024 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// WGSL port of ffx_denoiser_reflections_common.h.
#include "denoiser/ffx_denoiser_reflections_config.wgsl"

fn FFX_DNSR_Reflections_IsGlossyReflection(roughness: f32) -> bool {
    return roughness < RoughnessThreshold();
}

fn FFX_DNSR_Reflections_IsMirrorReflection(roughness: f32) -> bool {
    return roughness < 0.0001;
}

fn ProjectPosition(origin: vec3f, mat: mat4x4f) -> vec3f {
    let projected = mat * vec4f(origin, 1.0);
    let ndc = projected.xyz / projected.w;
    let uv = 0.5 * ndc.xy + 0.5;
    return vec3f(uv.x, 1.0 - uv.y, ndc.z);
}

fn FFX_DNSR_InvProjectPosition(coord: vec3f, mat: mat4x4f) -> vec3f {
    let ndc = vec2f(coord.x, 1.0 - coord.y) * 2.0 - 1.0;
    let projected = mat * vec4f(ndc, coord.z, 1.0);
    return projected.xyz / projected.w;
}

fn FFX_DNSR_Reflections_GetLinearDepth(uv: vec2f, depth: f32) -> f32 {
    return abs(FFX_DNSR_InvProjectPosition(vec3f(uv, depth), InvProjection()).z);
}

fn FFX_DNSR_Reflections_ScreenSpaceToViewSpace(screen_uv_coord: vec3f) -> vec3f {
    return FFX_DNSR_InvProjectPosition(screen_uv_coord, InvProjection());
}

fn FFX_DNSR_Reflections_WorldSpaceToScreenSpacePrevious(world_space_pos: vec3f) -> vec3f {
    return ProjectPosition(world_space_pos, PrevViewProjection());
}

fn FFX_DNSR_Reflections_ViewSpaceToWorldSpace(view_space_coord: vec4f) -> vec3f {
    return (InvView() * view_space_coord).xyz;
}

fn FFX_DNSR_Reflections_RoundUp8(value: vec2u) -> vec2u {
    // The SDK selects value + 8 for nonmultiples (not round_down + 8).
    let round_down = value & vec2u(~7u);
    return select(value + 8u, value, round_down == value);
}

fn FFX_DNSR_Reflections_Luminance(color: FfxFloat3) -> FfxFloat {
    return max(dot(color, FfxFloat3(0.299, 0.587, 0.114)), FfxFloat(0.001));
}

fn FFX_DNSR_Reflections_ComputeTemporalVariance(history: FfxFloat3, radiance: FfxFloat3) -> FfxFloat {
    let previous = FFX_DNSR_Reflections_Luminance(history);
    let current = FFX_DNSR_Reflections_Luminance(radiance);
    let diff = abs(previous - current) / max(max(previous, current), FfxFloat(0.5));
    return diff * diff;
}

fn FFX_DNSR_Reflections_PackFloat16(v: FfxFloat2) -> u32 {
    return pack2x16float(vec2f(v));
}

fn FFX_DNSR_Reflections_UnpackFloat16(a: u32) -> FfxFloat2 {
    return FfxFloat2(unpack2x16float(a));
}

fn FFX_DNSR_Reflections_PackFloat16_4(v: FfxFloat4) -> vec2u {
    return vec2u(FFX_DNSR_Reflections_PackFloat16(v.xy), FFX_DNSR_Reflections_PackFloat16(v.zw));
}

fn FFX_DNSR_Reflections_UnpackFloat16_4(a: vec2u) -> FfxFloat4 {
    return FfxFloat4(FFX_DNSR_Reflections_UnpackFloat16(a.x), FFX_DNSR_Reflections_UnpackFloat16(a.y));
}

// From "Temporal Reprojection Anti-Aliasing"
// https://github.com/playdeadgames/temporal
/**********************************************************************
Copyright (c) [2015] [Playdead]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
********************************************************************/
fn FFX_DNSR_Reflections_ClipAABB(aabb_min: FfxFloat3, aabb_max: FfxFloat3, prev_sample: FfxFloat3) -> FfxFloat3 {
    let center = vec3f(0.5 * (aabb_max + aabb_min));
    let extent = vec3f(0.5 * (aabb_max - aabb_min) + FfxFloat3(0.001));
    let color_vector = vec3f(prev_sample) - center;
    let clip = abs(color_vector / extent);
    let max_abs_unit = FfxFloat(max(max(clip.x, clip.y), clip.z));
    if (max_abs_unit > 1.0) {
        return FfxFloat3(center + color_vector / f32(max_abs_unit));
    }
    return prev_sample;
}

#define FFX_DNSR_REFLECTIONS_LOCAL_NEIGHBORHOOD_RADIUS 4

fn FFX_DNSR_Reflections_LocalNeighborhoodKernelWeight(i: FfxFloat) -> FfxFloat {
#if FFX_HALF
    let radius = FfxFloat(FFX_DNSR_REFLECTIONS_LOCAL_NEIGHBORHOOD_RADIUS + 1);
    return exp(-FfxFloat(FFX_DNSR_REFLECTIONS_GAUSSIAN_K) * (i * i) / (radius * radius));
#else
    // DXC folds the FP32 coefficient before multiplying by the squared offset.
    const radius = f32(FFX_DNSR_REFLECTIONS_LOCAL_NEIGHBORHOOD_RADIUS + 1);
    const coefficient = -f32(FFX_DNSR_REFLECTIONS_GAUSSIAN_K) / (radius * radius);
    return exp((i * i) * coefficient);
#endif
}
