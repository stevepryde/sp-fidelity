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

// WGSL port of ffx_denoiser_reflections_prefilter.h.

var<workgroup> g_ffx_dnsr_shared_0: array<array<u32, 16>, 16>;
var<workgroup> g_ffx_dnsr_shared_1: array<array<u32, 16>, 16>;
var<workgroup> g_ffx_dnsr_shared_2: array<array<u32, 16>, 16>;
var<workgroup> g_ffx_dnsr_shared_3: array<array<u32, 16>, 16>;
var<workgroup> g_ffx_dnsr_shared_depth: array<array<f32, 16>, 16>;

struct FFX_DNSR_Reflections_NeighborhoodSample {
    radiance: FfxFloat3,
    variance: FfxFloat,
    normal: FfxFloat3,
    depth: f32,
}

fn FFX_DNSR_Reflections_LoadFromGroupSharedMemory(idx: vec2i) -> FFX_DNSR_Reflections_NeighborhoodSample {
    let radiance = FFX_DNSR_Reflections_UnpackFloat16_4(vec2u(
        g_ffx_dnsr_shared_0[idx.y][idx.x], g_ffx_dnsr_shared_1[idx.y][idx.x]));
    let normal_variance = FFX_DNSR_Reflections_UnpackFloat16_4(vec2u(
        g_ffx_dnsr_shared_2[idx.y][idx.x], g_ffx_dnsr_shared_3[idx.y][idx.x]));
    return FFX_DNSR_Reflections_NeighborhoodSample(
        radiance.xyz, normal_variance.w, normal_variance.xyz, g_ffx_dnsr_shared_depth[idx.y][idx.x]);
}

fn FFX_DNSR_Reflections_StoreInGroupSharedMemory(idx: vec2i, neighbor: FFX_DNSR_Reflections_NeighborhoodSample) {
    g_ffx_dnsr_shared_0[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(neighbor.radiance.xy);
    g_ffx_dnsr_shared_1[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(neighbor.radiance.zz);
    g_ffx_dnsr_shared_2[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(neighbor.normal.xy);
    g_ffx_dnsr_shared_3[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(FfxFloat2(neighbor.normal.z, neighbor.variance));
    g_ffx_dnsr_shared_depth[idx.y][idx.x] = neighbor.depth;
}

fn FFX_DNSR_Reflections_LoadNeighborhood(pixel_coordinate: vec2i, screen_size: vec2u) -> FFX_DNSR_Reflections_NeighborhoodSample {
    let radiance = FFX_DNSR_Reflections_LoadRadiance(pixel_coordinate);
    let variance = FFX_DNSR_Reflections_LoadVariance(pixel_coordinate);
    let normal = FFX_DNSR_Reflections_LoadWorldSpaceNormal(pixel_coordinate);
    let uv = (vec2f(pixel_coordinate) + 0.5) / vec2f(screen_size);
    let depth = FFX_DNSR_Reflections_GetLinearDepth(uv, FFX_DNSR_Reflections_LoadDepth(pixel_coordinate));
    return FFX_DNSR_Reflections_NeighborhoodSample(radiance, variance, normal, depth);
}

fn FFX_DNSR_Reflections_InitializeGroupSharedMemory(dispatch_thread_id: vec2i, group_thread_id: vec2i, screen_size: vec2u) {
    // Each thread loads four texels of the 16x16 neighborhood into registers before publishing to LDS.
    const offset = array(vec2i(0, 0), vec2i(8, 0), vec2i(0, 8), vec2i(8, 8));
    var neighbors: array<FFX_DNSR_Reflections_NeighborhoodSample, 4>;
    for (var i = 0; i < 4; i++) {
        neighbors[i] = FFX_DNSR_Reflections_LoadNeighborhood(dispatch_thread_id - 4 + offset[i], screen_size);
    }
    for (var j = 0; j < 4; j++) {
        FFX_DNSR_Reflections_StoreInGroupSharedMemory(group_thread_id + offset[j], neighbors[j]);
    }
}

fn FFX_DNSR_Reflections_GetEdgeStoppingNormalWeight(normal_p: FfxFloat3, normal_q: FfxFloat3) -> FfxFloat {
    return pow(max(dot(normal_p, normal_q), 0.0), FfxFloat(FFX_DNSR_REFLECTIONS_PREFILTER_NORMAL_SIGMA));
}

fn FFX_DNSR_Reflections_GetEdgeStoppingDepthWeight(center_depth: f32, neighbor_depth: f32) -> FfxFloat {
    return FfxFloat(exp(-abs(center_depth - neighbor_depth) * center_depth * FFX_DNSR_REFLECTIONS_PREFILTER_DEPTH_SIGMA));
}

fn FFX_DNSR_Reflections_GetRadianceWeight(center_radiance: FfxFloat3, neighbor_radiance: FfxFloat3, variance: FfxFloat) -> FfxFloat {
    let bias = FfxFloat(FFX_DNSR_REFLECTIONS_RADIANCE_WEIGHT_BIAS) + variance * FfxFloat(FFX_DNSR_REFLECTIONS_RADIANCE_WEIGHT_VARIANCE_K);
    return max(exp(-bias * length(center_radiance - neighbor_radiance)), 1.0e-2);
}

fn FFX_DNSR_Reflections_Resolve(group_thread_id: vec2i, avg_radiance: FfxFloat3, center: FFX_DNSR_Reflections_NeighborhoodSample) -> FfxFloat4 {
    // Weighting the center against tile radiance suppresses fireflies.
    var accumulated_weight = FFX_DNSR_Reflections_GetRadianceWeight(avg_radiance, center.radiance, center.variance);
    var accumulated_radiance = center.radiance * accumulated_weight;
    var accumulated_variance = center.variance * accumulated_weight * accumulated_weight;
    // First 15 non-center Halton(2,3) offsets stretched to [-3,3].
    const sample_offsets = array(
        vec2i(0, 1), vec2i(-2, 1), vec2i(2, -3), vec2i(-3, 0), vec2i(1, 2),
        vec2i(-1, -2), vec2i(3, 0), vec2i(-3, 3), vec2i(0, -3), vec2i(-1, -1),
        vec2i(2, 1), vec2i(-2, -2), vec2i(1, 0), vec2i(0, 2), vec2i(3, -1));
    let variance_weight = max(FfxFloat(FFX_DNSR_REFLECTIONS_PREFILTER_VARIANCE_BIAS),
        1.0 - exp(-(center.variance * FfxFloat(FFX_DNSR_REFLECTIONS_PREFILTER_VARIANCE_WEIGHT))));

    for (var i = 0; i < 15; i++) {
        let neighbor = FFX_DNSR_Reflections_LoadFromGroupSharedMemory(group_thread_id + sample_offsets[i]);
        var weight = FFX_DNSR_Reflections_GetEdgeStoppingNormalWeight(center.normal, neighbor.normal);
        weight *= FFX_DNSR_Reflections_GetEdgeStoppingDepthWeight(center.depth, neighbor.depth);
        weight *= FFX_DNSR_Reflections_GetRadianceWeight(avg_radiance, neighbor.radiance, center.variance);
        weight *= variance_weight;

        accumulated_weight += weight;
        accumulated_radiance += weight * neighbor.radiance;
        accumulated_variance += weight * weight * neighbor.variance;
    }
    return FfxFloat4(accumulated_radiance / accumulated_weight, accumulated_variance / (accumulated_weight * accumulated_weight));
}

fn FFX_DNSR_Reflections_Prefilter(dispatch_thread_id: vec2i, group_thread_id: vec2i, screen_size: vec2u) {
    let center_roughness = FFX_DNSR_Reflections_LoadRoughness(dispatch_thread_id);
    FFX_DNSR_Reflections_InitializeGroupSharedMemory(dispatch_thread_id, group_thread_id, screen_size);
    workgroupBarrier();

    let center_id = group_thread_id + 4;
    let center = FFX_DNSR_Reflections_LoadFromGroupSharedMemory(center_id);
    var resolved = FfxFloat4(center.radiance, center.variance);
    if (center.variance > 0.0 && FFX_DNSR_Reflections_IsGlossyReflection(f32(center_roughness))
        && !FFX_DNSR_Reflections_IsMirrorReflection(f32(center_roughness))) {
        let uv8 = (vec2f(dispatch_thread_id) + 0.5) / vec2f(FFX_DNSR_Reflections_RoundUp8(screen_size));
        let avg_radiance = FFX_DNSR_Reflections_SampleAverageRadiance(uv8);
        resolved = FFX_DNSR_Reflections_Resolve(center_id, avg_radiance, center);
    }
    FFX_DNSR_Reflections_StorePrefilteredReflections(dispatch_thread_id, resolved.xyz, resolved.w);
}
