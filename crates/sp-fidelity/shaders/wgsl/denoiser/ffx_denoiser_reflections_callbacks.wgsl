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

// WGSL port of ffx_denoiser_reflections_callbacks_hlsl.h.
#include "ffx_core_lane_math.wgsl"

#if FFX_HALF
alias FfxFloat = f16;
alias FfxFloat2 = vec2h;
alias FfxFloat3 = vec3h;
alias FfxFloat4 = vec4h;
#else
alias FfxFloat = f32;
alias FfxFloat2 = vec2f;
alias FfxFloat3 = vec3f;
alias FfxFloat4 = vec4f;
#endif

struct DenoiserReflectionsConstants {
    invProjection: mat4x4f,
    invView: mat4x4f,
    prevViewProjection: mat4x4f,
    renderSize: vec2u,
    inverseRenderSize: vec2f,
    motionVectorScale: vec2f,
    normalsUnpackMul: f32,
    normalsUnpackAdd: f32,
    isRoughnessPerceptual: u32,
    temporalStabilityFactor: f32,
    roughnessThreshold: f32,
}

@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + DENOISER_BIND_CB_DENOISER)
var<uniform> cbDenoiserReflections: DenoiserReflectionsConstants;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SAMPLER) var s_LinearSampler: sampler;

fn InvProjection() -> mat4x4f { return cbDenoiserReflections.invProjection; }
fn InvView() -> mat4x4f { return cbDenoiserReflections.invView; }
fn PrevViewProjection() -> mat4x4f { return cbDenoiserReflections.prevViewProjection; }
fn RenderSize() -> vec2u { return cbDenoiserReflections.renderSize; }
fn InverseRenderSize() -> vec2f { return cbDenoiserReflections.inverseRenderSize; }
fn MotionVectorScale() -> vec2f { return cbDenoiserReflections.motionVectorScale; }
fn NormalsUnpackMul() -> f32 { return cbDenoiserReflections.normalsUnpackMul; }
fn NormalsUnpackAdd() -> f32 { return cbDenoiserReflections.normalsUnpackAdd; }
fn IsRoughnessPerceptual() -> bool { return cbDenoiserReflections.isRoughnessPerceptual != 0u; }
fn TemporalStabilityFactor() -> f32 { return cbDenoiserReflections.temporalStabilityFactor; }
fn RoughnessThreshold() -> f32 { return cbDenoiserReflections.roughnessThreshold; }

// Direct3D Texture2D.Load returns zero outside the image, including the
// halo of a partial screen tile. WGSL leaves out-of-bounds access unspecified.
fn LoadDenoiserTexture(image: texture_2d<f32>, pixel: vec2i) -> vec4f {
    if (any(vec2u(pixel) >= textureDimensions(image, 0))) {
        return vec4f(0.0);
    }
    return textureLoad(image, pixel, 0);
}

fn UnpackDenoiserNormal(encoded: vec3f) -> FfxFloat3 {
    return normalize(FfxFloat3(NormalsUnpackMul() * encoded + NormalsUnpackAdd()));
}

fn UnpackDenoiserRoughness(raw: f32) -> FfxFloat {
    let roughness = FfxFloat(raw);
    if (IsRoughnessPerceptual()) {
        return roughness * roughness;
    }
    return roughness;
}

#ifdef DENOISER_BIND_SRV_INPUT_DEPTH_HIERARCHY
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_INPUT_DEPTH_HIERARCHY)
var r_input_depth_hierarchy: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadDepth(pixel: vec2i) -> f32 {
    return LoadDenoiserTexture(r_input_depth_hierarchy, pixel).x;
}
#endif

#ifdef DENOISER_BIND_SRV_INPUT_MOTION_VECTORS
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_INPUT_MOTION_VECTORS)
var r_input_motion_vectors: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadMotionVector(pixel: vec2i) -> vec2f {
    return MotionVectorScale() * LoadDenoiserTexture(r_input_motion_vectors, pixel).xy;
}
#endif

#ifdef DENOISER_BIND_SRV_INPUT_NORMAL
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_INPUT_NORMAL)
var r_input_normal: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadWorldSpaceNormal(pixel: vec2i) -> FfxFloat3 {
    return UnpackDenoiserNormal(LoadDenoiserTexture(r_input_normal, pixel).xyz);
}
#endif

#ifdef DENOISER_BIND_SRV_RADIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_RADIANCE)
var r_radiance: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadRadiance(pixel: vec2i) -> FfxFloat3 {
    return FfxFloat3(LoadDenoiserTexture(r_radiance, pixel).xyz);
}

fn FFX_DNSR_Reflections_LoadRayLength(pixel: vec2i) -> FfxFloat {
    return FfxFloat(LoadDenoiserTexture(r_radiance, pixel).w);
}
#endif

#ifdef DENOISER_BIND_SRV_RADIANCE_HISTORY
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_RADIANCE_HISTORY)
var r_radiance_history: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadRadianceHistory(pixel: vec2i) -> FfxFloat3 {
    return FfxFloat3(LoadDenoiserTexture(r_radiance_history, pixel).xyz);
}

fn FFX_DNSR_Reflections_SampleRadianceHistory(uv: vec2f) -> FfxFloat3 {
    return FfxFloat3(textureSampleLevel(r_radiance_history, s_LinearSampler, uv, 0.0).xyz);
}
#endif

#ifdef DENOISER_BIND_SRV_VARIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_VARIANCE)
var r_variance: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadVariance(pixel: vec2i) -> FfxFloat {
    return FfxFloat(LoadDenoiserTexture(r_variance, pixel).x);
}

fn FFX_DNSR_Reflections_SampleVarianceHistory(uv: vec2f) -> FfxFloat {
    return FfxFloat(textureSampleLevel(r_variance, s_LinearSampler, uv, 0.0).x);
}
#endif

#ifdef DENOISER_BIND_SRV_SAMPLE_COUNT
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_SAMPLE_COUNT)
var r_sample_count: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadNumSamples(pixel: vec2i) -> FfxFloat {
    return FfxFloat(LoadDenoiserTexture(r_sample_count, pixel).x);
}

fn FFX_DNSR_Reflections_SampleNumSamplesHistory(uv: vec2f) -> FfxFloat {
    return FfxFloat(textureSampleLevel(r_sample_count, s_LinearSampler, uv, 0.0).x);
}
#endif

#ifdef DENOISER_BIND_SRV_AVERAGE_RADIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_AVERAGE_RADIANCE)
var r_average_radiance: texture_2d<f32>;

fn FFX_DNSR_Reflections_SampleAverageRadiance(uv: vec2f) -> FfxFloat3 {
    return FfxFloat3(textureSampleLevel(r_average_radiance, s_LinearSampler, uv, 0.0).xyz);
}
#endif

#ifdef DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS)
var r_extracted_roughness: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadRoughness(pixel: vec2i) -> FfxFloat {
    return UnpackDenoiserRoughness(LoadDenoiserTexture(r_extracted_roughness, pixel).x);
}
#endif

#ifdef DENOISER_BIND_SRV_DEPTH_HISTORY
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_DEPTH_HISTORY)
var r_depth_history: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadDepthHistory(pixel: vec2i) -> f32 {
    return LoadDenoiserTexture(r_depth_history, pixel).x;
}

// SampleLevel with linear/clamp at LOD zero. R32Float filtering is optional
// in WebGPU, so use the four texels selected by the SDK sampler.
fn FFX_DNSR_Reflections_SampleDepthHistory(uv: vec2f) -> f32 {
#if FFX_WGSL_DENOISER_MANUAL_DEPTH_FILTER
    let size = vec2i(textureDimensions(r_depth_history, 0));
    let texel = uv * vec2f(size) - 0.5;
    let base = vec2i(floor(texel));
    let weight = fract(texel);
    let lo = clamp(base, vec2i(0), size - 1);
    let hi = clamp(base + 1, vec2i(0), size - 1);
    let top = mix(textureLoad(r_depth_history, lo, 0).x,
                  textureLoad(r_depth_history, vec2i(hi.x, lo.y), 0).x, weight.x);
    let bottom = mix(textureLoad(r_depth_history, vec2i(lo.x, hi.y), 0).x,
                     textureLoad(r_depth_history, hi, 0).x, weight.x);
    return mix(top, bottom, weight.y);
#else
    return textureSampleLevel(r_depth_history, s_LinearSampler, uv, 0.0).x;
#endif
}
#endif

#ifdef DENOISER_BIND_SRV_NORMAL_HISTORY
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_NORMAL_HISTORY)
var r_normal_history: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadWorldSpaceNormalHistory(pixel: vec2i) -> FfxFloat3 {
    return UnpackDenoiserNormal(LoadDenoiserTexture(r_normal_history, pixel).xyz);
}

fn FFX_DNSR_Reflections_SampleWorldSpaceNormalHistory(uv: vec2f) -> FfxFloat3 {
    return UnpackDenoiserNormal(textureSampleLevel(r_normal_history, s_LinearSampler, uv, 0.0).xyz);
}
#endif

#ifdef DENOISER_BIND_SRV_ROUGHNESS_HISTORY
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_ROUGHNESS_HISTORY)
var r_roughness_history: texture_2d<f32>;

fn FFX_DNSR_Reflections_SampleRoughnessHistory(uv: vec2f) -> FfxFloat {
    return UnpackDenoiserRoughness(textureSampleLevel(r_roughness_history, s_LinearSampler, uv, 0.0).x);
}
#endif

#ifdef DENOISER_BIND_SRV_REPROJECTED_RADIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + DENOISER_BIND_SRV_REPROJECTED_RADIANCE)
var r_reprojected_radiance: texture_2d<f32>;

fn FFX_DNSR_Reflections_LoadRadianceReprojected(pixel: vec2i) -> FfxFloat3 {
    return FfxFloat3(LoadDenoiserTexture(r_reprojected_radiance, pixel).xyz);
}
#endif

#ifdef DENOISER_BIND_UAV_VARIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + DENOISER_BIND_UAV_VARIANCE)
#if FFX_WGSL_DENOISER_WIDEN_SCALAR
var rw_variance: texture_storage_2d<rgba16float, write>;
#else
var rw_variance: texture_storage_2d<r16float, write>;
#endif

fn FFX_DNSR_Reflections_StoreVariance(pixel: vec2i, value: FfxFloat) {
    if (all(vec2u(pixel) < textureDimensions(rw_variance))) {
        textureStore(rw_variance, pixel, vec4f(f32(value)));
    }
}
#endif

#ifdef DENOISER_BIND_UAV_SAMPLE_COUNT
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + DENOISER_BIND_UAV_SAMPLE_COUNT)
#if FFX_WGSL_DENOISER_WIDEN_SCALAR
var rw_sample_count: texture_storage_2d<rgba16float, write>;
#else
var rw_sample_count: texture_storage_2d<r16float, write>;
#endif

fn FFX_DNSR_Reflections_StoreNumSamples(pixel: vec2i, value: FfxFloat) {
    if (all(vec2u(pixel) < textureDimensions(rw_sample_count))) {
        textureStore(rw_sample_count, pixel, vec4f(f32(value)));
    }
}
#endif

#ifdef DENOISER_BIND_UAV_AVERAGE_RADIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + DENOISER_BIND_UAV_AVERAGE_RADIANCE)
#if FFX_WGSL_DENOISER_WIDEN_AVERAGE
var rw_average_radiance: texture_storage_2d<rgba16float, write>;
#else
var rw_average_radiance: texture_storage_2d<rg11b10ufloat, write>;
#endif

#if FFX_WGSL_DENOISER_WIDEN_AVERAGE
#include "denoiser/ffx_denoiser_reflections_portable_average.wgsl"
#endif

fn FFX_DNSR_Reflections_StoreAverageRadiance(pixel: vec2i, value: FfxFloat3) {
    if (all(vec2u(pixel) < textureDimensions(rw_average_radiance))) {
#if FFX_WGSL_DENOISER_WIDEN_AVERAGE
        sdk_store_average(pixel, vec3f(value).xyzz);
#else
        textureStore(rw_average_radiance, pixel, vec3f(value).xyzz);
#endif
    }
}
#endif

#ifdef DENOISER_BIND_UAV_REPROJECTED_RADIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + DENOISER_BIND_UAV_REPROJECTED_RADIANCE)
var rw_reprojected_radiance: texture_storage_2d<rgba16float, write>;

fn FFX_DNSR_Reflections_StoreRadianceReprojected(pixel: vec2i, value: FfxFloat3) {
    if (all(vec2u(pixel) < textureDimensions(rw_reprojected_radiance))) {
        textureStore(rw_reprojected_radiance, pixel, vec3f(value).xyzz);
    }
}
#endif

#ifdef DENOISER_BIND_UAV_RADIANCE
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + DENOISER_BIND_UAV_RADIANCE)
var rw_radiance: texture_storage_2d<rgba16float, write>;

fn FFX_DNSR_Reflections_StoreRadiance(pixel: vec2i, value: FfxFloat3) {
    if (all(vec2u(pixel) < textureDimensions(rw_radiance))) {
        textureStore(rw_radiance, pixel, vec3f(value).xyzz);
    }
}

fn FFX_DNSR_Reflections_StoreTemporalAccumulation(pixel: vec2i, radiance: FfxFloat3, variance: FfxFloat) {
    FFX_DNSR_Reflections_StoreRadiance(pixel, radiance);
    FFX_DNSR_Reflections_StoreVariance(pixel, variance);
}

fn FFX_DNSR_Reflections_StorePrefilteredReflections(pixel: vec2i, radiance: FfxFloat3, variance: FfxFloat) {
    FFX_DNSR_Reflections_StoreRadiance(pixel, radiance);
    FFX_DNSR_Reflections_StoreVariance(pixel, variance);
}
#endif

@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + DENOISER_BIND_UAV_DENOISER_TILE_LIST)
var<storage, read_write> rw_denoiser_tile_list: array<u32>;

fn GetDenoiserTile(group_id: u32) -> u32 {
    return rw_denoiser_tile_list[group_id];
}
