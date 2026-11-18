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

// WGSL port of FidelityFX SDK v1.1.4 ffx_denoiser_reflections_reproject.h.
// Both SDK permutations pack the workgroup cache into pairs of binary16 values.
var<workgroup> g_ffx_dnsr_shared_0: array<array<u32, 16>, 16>;
var<workgroup> g_ffx_dnsr_shared_1: array<array<u32, 16>, 16>;

fn FFX_DNSR_Reflections_LoadFromGroupSharedMemoryRaw(idx: vec2<i32>) -> FfxFloat4 {
    let packed = vec2<u32>(g_ffx_dnsr_shared_0[idx.y][idx.x], g_ffx_dnsr_shared_1[idx.y][idx.x]);
    return FFX_DNSR_Reflections_UnpackFloat16_4(packed);
}

fn FFX_DNSR_Reflections_StoreInGroupSharedMemory(idx: vec2<i32>, sample: FfxFloat4) {
    g_ffx_dnsr_shared_0[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(sample.xy);
    g_ffx_dnsr_shared_1[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(sample.zw);
}

fn FFX_DNSR_Reflections_InitializeGroupSharedMemory(dispatch_thread_id: vec2<i32>, group_thread_id: vec2<i32>) {
    // Each 8x8 group fills its 16x16 neighborhood. Cache all four loads in
    // registers before transferring them to workgroup memory, as in the SDK.
    let offset = array(vec2<i32>(0, 0), vec2<i32>(8, 0), vec2<i32>(0, 8), vec2<i32>(8, 8));
    let top_left = dispatch_thread_id - vec2<i32>(4);
    var radiance: array<FfxFloat3, 4>;
    for (var i = 0; i < 4; i++) {
        radiance[i] = FFX_DNSR_Reflections_LoadRadiance(top_left + offset[i]);
    }
    for (var i = 0; i < 4; i++) {
        FFX_DNSR_Reflections_StoreInGroupSharedMemory(group_thread_id + offset[i], radiance[i].xyzz);
    }
}

fn FFX_DNSR_Reflections_GetLuminanceWeight(radiance: FfxFloat3) -> FfxFloat {
    let luma = FFX_DNSR_Reflections_Luminance(radiance);
    return max(exp(-luma * FfxFloat(FFX_DNSR_REFLECTIONS_AVG_RADIANCE_LUMINANCE_WEIGHT)), FfxFloat(1.0e-2));
}

fn FFX_DNSR_Reflections_GetHitPositionReprojection(dispatch_thread_id: vec2<i32>, uv: vec2<f32>, reflected_ray_length: f32) -> vec2<f32> {
    let z = FFX_DNSR_Reflections_LoadDepth(dispatch_thread_id);
    var view_space_ray = FFX_DNSR_Reflections_ScreenSpaceToViewSpace(vec3<f32>(uv, z));
    let surface_depth = length(view_space_ray);
    let ray_length = surface_depth + reflected_ray_length;
    // Project the tip of a ray of the same length passing straight through the reflector.
    view_space_ray /= surface_depth;
    view_space_ray *= ray_length;
    let world_hit_position = FFX_DNSR_Reflections_ViewSpaceToWorldSpace(vec4<f32>(view_space_ray, 1.0));
    return FFX_DNSR_Reflections_WorldSpaceToScreenSpacePrevious(world_hit_position).xy;
}

fn FFX_DNSR_Reflections_GetDisocclusionFactor(normal: FfxFloat3, history_normal: FfxFloat3, linear_depth: f32, history_linear_depth: f32) -> FfxFloat {
    let normal_similarity = max(FfxFloat(0.0), dot(normal, history_normal));
    return FfxFloat(
        exp(-abs(1.0 - f32(normal_similarity)) * f32(FFX_DNSR_REFLECTIONS_DISOCCLUSION_NORMAL_WEIGHT)) *
        exp(-abs(history_linear_depth - linear_depth) / linear_depth * f32(FFX_DNSR_REFLECTIONS_DISOCCLUSION_DEPTH_WEIGHT))
    );
}

struct FFX_DNSR_Reflections_Moments {
    mean: FfxFloat3,
    variance: FfxFloat3,
}

fn FFX_DNSR_Reflections_EstimateLocalNeighborhoodInGroup(group_thread_id: vec2<i32>) -> FFX_DNSR_Reflections_Moments {
    var estimate: FFX_DNSR_Reflections_Moments;
    var accumulated_weight = FfxFloat(0.0);
    let radius = i32(FFX_DNSR_REFLECTIONS_LOCAL_NEIGHBORHOOD_RADIUS);
    for (var j = -radius; j <= radius; j++) {
        for (var i = -radius; i <= radius; i++) {
            let radiance = FFX_DNSR_Reflections_LoadFromGroupSharedMemoryRaw(group_thread_id + vec2<i32>(i, j)).xyz;
            let weight = FFX_DNSR_Reflections_LocalNeighborhoodKernelWeight(FfxFloat(i)) *
                         FFX_DNSR_Reflections_LocalNeighborhoodKernelWeight(FfxFloat(j));
            accumulated_weight += weight;
            estimate.mean += radiance * weight;
            estimate.variance += radiance * radiance * weight;
        }
    }
    estimate.mean /= accumulated_weight;
    estimate.variance /= accumulated_weight;
    estimate.variance = abs(estimate.variance - estimate.mean * estimate.mean);
    return estimate;
}

struct FFX_DNSR_Reflections_Reprojection {
    disocclusion_factor: FfxFloat,
    uv: vec2<f32>,
    radiance: FfxFloat3,
}

fn FFX_DNSR_Reflections_PickReprojection(
    dispatch_thread_id: vec2<i32>, group_thread_id: vec2<i32>, screen_size: vec2<u32>,
    roughness: FfxFloat, ray_length: FfxFloat,
) -> FFX_DNSR_Reflections_Reprojection {
    var result: FFX_DNSR_Reflections_Reprojection;
    let neighborhood = FFX_DNSR_Reflections_EstimateLocalNeighborhoodInGroup(group_thread_id);
    let uv = (vec2<f32>(dispatch_thread_id) + vec2<f32>(0.5)) / vec2<f32>(screen_size);
    let normal = FFX_DNSR_Reflections_LoadWorldSpaceNormal(dispatch_thread_id);
    var history_normal: FfxFloat3;
    var history_linear_depth: f32;

    let motion_vector = FFX_DNSR_Reflections_LoadMotionVector(dispatch_thread_id);
    let surface_uv = uv + motion_vector;
    let hit_uv = FFX_DNSR_Reflections_GetHitPositionReprojection(dispatch_thread_id, uv, f32(ray_length));
    let surface_normal = FFX_DNSR_Reflections_SampleWorldSpaceNormalHistory(surface_uv);
    let hit_normal = FFX_DNSR_Reflections_SampleWorldSpaceNormalHistory(hit_uv);
    let surface_history = FFX_DNSR_Reflections_SampleRadianceHistory(surface_uv);
    let hit_history = FFX_DNSR_Reflections_SampleRadianceHistory(hit_uv);
    let hit_normal_similarity = dot(normalize(vec3<f32>(hit_normal)), normalize(vec3<f32>(normal)));
    let surface_normal_similarity = dot(normalize(vec3<f32>(surface_normal)), normalize(vec3<f32>(normal)));
    let hit_roughness = FFX_DNSR_Reflections_SampleRoughnessHistory(hit_uv);
    let surface_roughness = FFX_DNSR_Reflections_SampleRoughnessHistory(surface_uv);

    // Choose the hit reprojection for mirror parallax, otherwise test the
    // surface reprojection against the first two local radiance moments.
    if (hit_normal_similarity > f32(FFX_DNSR_REFLECTIONS_REPROJECTION_NORMAL_SIMILARITY_THRESHOLD) &&
        hit_normal_similarity + 1.0e-3 > surface_normal_similarity &&
        abs(hit_roughness - roughness) < abs(surface_roughness - roughness) + FfxFloat(1.0e-3)) {
        history_normal = hit_normal;
        history_linear_depth = FFX_DNSR_Reflections_GetLinearDepth(hit_uv, FFX_DNSR_Reflections_SampleDepthHistory(hit_uv));
        result.uv = hit_uv;
        result.radiance = hit_history;
    } else {
        let delta = vec3<f32>(surface_history - neighborhood.mean);
        if (dot(delta, delta) < f32(FfxFloat(FFX_DNSR_REFLECTIONS_REPROJECT_SURFACE_DISCARD_VARIANCE_WEIGHT) * length(neighborhood.variance))) {
            history_normal = surface_normal;
            history_linear_depth = FFX_DNSR_Reflections_GetLinearDepth(surface_uv, FFX_DNSR_Reflections_SampleDepthHistory(surface_uv));
            result.uv = surface_uv;
            result.radiance = surface_history;
        } else {
            return result;
        }
    }

    let depth = FFX_DNSR_Reflections_LoadDepth(dispatch_thread_id);
    let linear_depth = FFX_DNSR_Reflections_GetLinearDepth(uv, depth);
    result.disocclusion_factor = FFX_DNSR_Reflections_GetDisocclusionFactor(normal, history_normal, linear_depth, history_linear_depth);
    let threshold = FfxFloat(FFX_DNSR_REFLECTIONS_DISOCCLUSION_THRESHOLD);
    if (result.disocclusion_factor > threshold) {
        return result;
    }

    if (result.disocclusion_factor < threshold) {
        let dudv = 1.0 / vec2<f32>(screen_size);
        const search_radius = 1;
        for (var y = -search_radius; y <= search_radius; y++) {
            for (var x = -search_radius; x <= search_radius; x++) {
                // The SDK advances the search center on each improvement.
                let candidate_uv = result.uv + vec2<f32>(f32(x), f32(y)) * dudv;
                let candidate_normal = FFX_DNSR_Reflections_SampleWorldSpaceNormalHistory(candidate_uv);
                let candidate_depth = FFX_DNSR_Reflections_SampleDepthHistory(candidate_uv);
                let candidate_linear_depth = FFX_DNSR_Reflections_GetLinearDepth(candidate_uv, candidate_depth);
                let weight = FFX_DNSR_Reflections_GetDisocclusionFactor(normal, candidate_normal, linear_depth, candidate_linear_depth);
                if (weight > result.disocclusion_factor) {
                    result.disocclusion_factor = weight;
                    result.uv = candidate_uv;
                }
            }
        }
        result.radiance = FFX_DNSR_Reflections_SampleRadianceHistory(result.uv);
    }

    // Reconstruct the bilinear sample from only the non-occluded neighbors.
    if (result.disocclusion_factor < threshold) {
        let pixel = vec2<f32>(screen_size) * result.uv;
        let fraction = fract(pixel + vec2<f32>(0.5));
        // The HLSL int cast truncates toward zero even at the negative edge.
        let texel = vec2<i32>(pixel - vec2<f32>(0.5));
        let offsets = array(vec2<i32>(0, 0), vec2<i32>(1, 0), vec2<i32>(0, 1), vec2<i32>(1, 1));
        var samples: array<FfxFloat3, 4>;
        var normals: array<FfxFloat3, 4>;
        var depths: array<f32, 4>;
        var w: FfxFloat4;
        for (var i = 0; i < 4; i++) {
            let coord = texel + offsets[i];
            samples[i] = FFX_DNSR_Reflections_LoadRadianceHistory(coord);
            normals[i] = FFX_DNSR_Reflections_LoadWorldSpaceNormalHistory(coord);
            depths[i] = FFX_DNSR_Reflections_GetLinearDepth(result.uv, FFX_DNSR_Reflections_LoadDepthHistory(coord));
            let occlusion = FFX_DNSR_Reflections_GetDisocclusionFactor(normal, normals[i], linear_depth, depths[i]);
            w[i] = select(FfxFloat(0.0), FfxFloat(1.0), f32(occlusion) > f32(FFX_DNSR_REFLECTIONS_DISOCCLUSION_THRESHOLD) / 2.0);
        }
        w.x = FfxFloat(f32(w.x) * (1.0 - fraction.x) * (1.0 - fraction.y));
        w.y = FfxFloat(f32(w.y) * fraction.x * (1.0 - fraction.y));
        w.z = FfxFloat(f32(w.z) * (1.0 - fraction.x) * fraction.y);
        w.w = FfxFloat(f32(w.w) * fraction.x * fraction.y);
        w /= max(w.x + w.y + w.z + w.w, FfxFloat(1.0e-3));

        result.radiance = samples[0] * w.x + samples[1] * w.y + samples[2] * w.z + samples[3] * w.w;
        history_linear_depth = depths[0] * f32(w.x) + depths[1] * f32(w.y) + depths[2] * f32(w.z) + depths[3] * f32(w.w);
        history_normal = normals[0] * w.x + normals[1] * w.y + normals[2] * w.z + normals[3] * w.w;
        result.disocclusion_factor = FFX_DNSR_Reflections_GetDisocclusionFactor(normal, history_normal, linear_depth, history_linear_depth);
    }
    if (result.disocclusion_factor < threshold) {
        result.disocclusion_factor = FfxFloat(0.0);
    }
    return result;
}

fn FFX_DNSR_Reflections_Reproject(
    dispatch_thread_id: vec2<i32>, group_thread_id: vec2<i32>, screen_size: vec2<u32>,
    temporal_stability_factor: f32, max_samples: i32,
) {
    FFX_DNSR_Reflections_InitializeGroupSharedMemory(dispatch_thread_id, group_thread_id);
    workgroupBarrier();

    let roughness = FFX_DNSR_Reflections_LoadRoughness(dispatch_thread_id);
    var radiance = FFX_DNSR_Reflections_LoadRadiance(dispatch_thread_id);
    let ray_length = FFX_DNSR_Reflections_LoadRayLength(dispatch_thread_id);

    if (FFX_DNSR_Reflections_IsGlossyReflection(f32(roughness))) {
        let reprojected = FFX_DNSR_Reflections_PickReprojection(
            dispatch_thread_id, group_thread_id + vec2<i32>(4), screen_size, roughness, ray_length
        );
        var stored_radiance = FfxFloat3(0.0);
        var stored_variance = FfxFloat(1.0);
        var stored_num_samples = FfxFloat(1.0);
        if (all(reprojected.uv > vec2<f32>(0.0)) && all(reprojected.uv < vec2<f32>(1.0))) {
            let prev_variance = FFX_DNSR_Reflections_SampleVarianceHistory(reprojected.uv);
            var num_samples = FFX_DNSR_Reflections_SampleNumSamplesHistory(reprojected.uv) * reprojected.disocclusion_factor;
            let s_max_samples = max(FfxFloat(8.0), FfxFloat(max_samples) * FFX_DNSR_REFLECTIONS_SAMPLES_FOR_ROUGHNESS(roughness));
            num_samples = min(s_max_samples, num_samples + FfxFloat(1.0));
            let new_variance = FFX_DNSR_Reflections_ComputeTemporalVariance(radiance, reprojected.radiance);
            if (!(reprojected.disocclusion_factor < FfxFloat(FFX_DNSR_REFLECTIONS_DISOCCLUSION_THRESHOLD))) {
                stored_radiance = reprojected.radiance;
                stored_variance = mix(new_variance, prev_variance, FfxFloat(1.0 / f32(num_samples)));
                stored_num_samples = num_samples;
                radiance = mix(radiance, reprojected.radiance, FfxFloat(0.3));
            }
        }
        FFX_DNSR_Reflections_StoreRadianceReprojected(dispatch_thread_id, stored_radiance);
        FFX_DNSR_Reflections_StoreVariance(dispatch_thread_id, stored_variance);
        FFX_DNSR_Reflections_StoreNumSamples(dispatch_thread_id, stored_num_samples);
    }

    // All subgroups must finish reading their neighborhoods before the same
    // storage is reused for the SDK's weighted 8x8 -> 1 average radiance.
    workgroupBarrier();
    var weight = FFX_DNSR_Reflections_GetLuminanceWeight(radiance);
    radiance *= weight;
    if (any(vec2<u32>(dispatch_thread_id) >= screen_size) ||
        any(isinf_f32x3(vec3<f32>(radiance))) || any(isnan_f32x3(vec3<f32>(radiance))) ||
        weight > FfxFloat(1.0e3)) {
        radiance = FfxFloat3(0.0);
        weight = FfxFloat(0.0);
    }
    FFX_DNSR_Reflections_StoreInGroupSharedMemory(group_thread_id, FfxFloat4(radiance, weight));
    workgroupBarrier();

    for (var i = 2; i <= 8; i *= 2) {
        let origin = group_thread_id * i;
        let opposite = origin + vec2<i32>(i / 2);
        if (all(opposite < vec2<i32>(8))) {
            let rad_weight00 = FFX_DNSR_Reflections_LoadFromGroupSharedMemoryRaw(origin);
            let rad_weight10 = FFX_DNSR_Reflections_LoadFromGroupSharedMemoryRaw(vec2<i32>(origin.x, opposite.y));
            let rad_weight01 = FFX_DNSR_Reflections_LoadFromGroupSharedMemoryRaw(vec2<i32>(opposite.x, origin.y));
            let rad_weight11 = FFX_DNSR_Reflections_LoadFromGroupSharedMemoryRaw(opposite);
            let sum = rad_weight00 + rad_weight01 + rad_weight10 + rad_weight11;
            FFX_DNSR_Reflections_StoreInGroupSharedMemory(origin, sum);
        }
        workgroupBarrier();
    }
    if (all(group_thread_id == vec2<i32>(0))) {
        let sum = FFX_DNSR_Reflections_LoadFromGroupSharedMemoryRaw(vec2<i32>(0));
        let average = sum.xyz / max(sum.w, FfxFloat(1.0e-3));
        FFX_DNSR_Reflections_StoreAverageRadiance(dispatch_thread_id / 8, average);
    }
}

fn Reproject(group_index: u32, group_id: u32, group_thread_id: vec2<u32>) {
    let packed_coords = GetDenoiserTile(group_id);
    let tile = vec2<u32>(packed_coords & 0xffffu, (packed_coords >> 16u) & 0xffffu);
    let dispatch_group_id = (vec2<i32>(tile) + vec2<i32>(group_thread_id)) / 8;
    let remapped_group_thread_id = vec2<i32>(ffxRemapForWaveReduction(group_index));
    let remapped_dispatch_thread_id = dispatch_group_id * 8 + remapped_group_thread_id;
    FFX_DNSR_Reflections_Reproject(remapped_dispatch_thread_id, remapped_group_thread_id, RenderSize(), TemporalStabilityFactor(), 32);
}
