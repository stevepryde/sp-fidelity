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

// WGSL port of ffx_denoiser_reflections_resolve_temporal.h.

const RADIANCE_THRESHOLD = 0.0001;
var<workgroup> g_ffx_dnsr_shared_0: array<array<u32, 16>, 16>;
var<workgroup> g_ffx_dnsr_shared_1: array<array<u32, 16>, 16>;

fn FFX_DNSR_Reflections_LoadFromGroupSharedMemory(idx: vec2i) -> FfxFloat3 {
    let packed_radiance = vec2u(g_ffx_dnsr_shared_0[idx.y][idx.x], g_ffx_dnsr_shared_1[idx.y][idx.x]);
    return FFX_DNSR_Reflections_UnpackFloat16_4(packed_radiance).xyz;
}

struct FFX_DNSR_Reflections_Moments {
    mean: FfxFloat3,
    variance: FfxFloat3,
}

fn FFX_DNSR_Reflections_EstimateLocalNeighborhoodInGroup(group_thread_id: vec2i) -> FFX_DNSR_Reflections_Moments {
    var estimate: FFX_DNSR_Reflections_Moments;
    var accumulated_weight = FfxFloat(0);
    const radius = FFX_DNSR_REFLECTIONS_LOCAL_NEIGHBORHOOD_RADIUS;
    for (var j = -radius; j <= radius; j++) {
#if !FFX_HALF
        // The Metal reference folds the nine inner-axis FP32 kernel weights
        // while evaluating the outer-axis weight at execution time.
        FFX_UNROLL
#endif
        for (var i = -radius; i <= radius; i++) {
            let radiance = FFX_DNSR_Reflections_LoadFromGroupSharedMemory(group_thread_id + vec2i(i, j));
            let weight = FFX_DNSR_Reflections_LocalNeighborhoodKernelWeight(FfxFloat(i))
                * FFX_DNSR_Reflections_LocalNeighborhoodKernelWeight(FfxFloat(j));
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

fn FFX_DNSR_Reflections_StoreInGroupSharedMemory(idx: vec2i, radiance: FfxFloat3) {
    g_ffx_dnsr_shared_0[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(radiance.xy);
    g_ffx_dnsr_shared_1[idx.y][idx.x] = FFX_DNSR_Reflections_PackFloat16(radiance.zz);
}

fn FFX_DNSR_Reflections_InitializeGroupSharedMemory(dispatch_thread_id: vec2i, group_thread_id: vec2i) {
    // Each thread loads four texels of the 16x16 neighborhood into registers before publishing to LDS.
    const offset = array(vec2i(0, 0), vec2i(8, 0), vec2i(0, 8), vec2i(8, 8));
    var radiance: array<FfxFloat3, 4>;
    for (var i = 0; i < 4; i++) {
        radiance[i] = FFX_DNSR_Reflections_LoadRadiance(dispatch_thread_id - 4 + offset[i]);
    }
    for (var j = 0; j < 4; j++) {
        FFX_DNSR_Reflections_StoreInGroupSharedMemory(group_thread_id + offset[j], radiance[j]);
    }
}

fn FFX_DNSR_Reflections_ResolveTemporal(dispatch_thread_id: vec2i, group_thread_id: vec2i, screen_size: vec2u,
                                         inv_screen_size: vec2f, history_clip_weight: f32) {
    FFX_DNSR_Reflections_InitializeGroupSharedMemory(dispatch_thread_id, group_thread_id);
    workgroupBarrier();

    let center_id = group_thread_id + 4;
    var new_signal = FFX_DNSR_Reflections_LoadFromGroupSharedMemory(center_id);
    let radiance_sum = f32(new_signal.x + new_signal.y + new_signal.z);
    if (radiance_sum < RADIANCE_THRESHOLD) {
        FFX_DNSR_Reflections_StoreTemporalAccumulation(dispatch_thread_id, FfxFloat3(0), FfxFloat(0));
        return;
    }

    let roughness = FFX_DNSR_Reflections_LoadRoughness(dispatch_thread_id);
    var new_variance = FFX_DNSR_Reflections_LoadVariance(dispatch_thread_id);
    if (FFX_DNSR_Reflections_IsGlossyReflection(f32(roughness))) {
        let num_samples = FFX_DNSR_Reflections_LoadNumSamples(dispatch_thread_id);
        let uv8 = (vec2f(dispatch_thread_id) + 0.5) / vec2f(FFX_DNSR_Reflections_RoundUp8(screen_size));
        let avg_radiance = FFX_DNSR_Reflections_SampleAverageRadiance(uv8);
        let old_signal = FFX_DNSR_Reflections_LoadRadianceReprojected(dispatch_thread_id);
        let local_neighborhood = FFX_DNSR_Reflections_EstimateLocalNeighborhoodInGroup(center_id);

        // Clip history to the current local statistics.
        let deviation = sqrt(local_neighborhood.variance) + length(local_neighborhood.mean - avg_radiance);
        let color_std = FfxFloat3(vec3f(deviation) * history_clip_weight * 1.4);
        let mean = mix(local_neighborhood.mean, avg_radiance, FfxFloat(0.2));
        let clipped_old_signal = FFX_DNSR_Reflections_ClipAABB(mean - color_std, mean + color_std, old_signal);
        let accumulation_speed = FfxFloat(1.0) / max(num_samples, 1.0);
        let weight = 1.0 - accumulation_speed;

        // Low sample counts blend toward the tile average before outlier clipping.
        new_signal = mix(new_signal, avg_radiance, FfxFloat(1.0) / max(num_samples + 1.0, 1.0));
        new_signal = FFX_DNSR_Reflections_ClipAABB(avg_radiance - color_std, avg_radiance + color_std, new_signal);
        new_signal = mix(new_signal, clipped_old_signal, weight);
        new_variance = mix(FFX_DNSR_Reflections_ComputeTemporalVariance(new_signal, clipped_old_signal), new_variance, weight);
        if (any(isinf_f32x3(vec3f(new_signal))) || any(isnan_f32x3(vec3f(new_signal)))
            || isinf_f32(f32(new_variance)) || isnan_f32(f32(new_variance))) {
            new_signal = FfxFloat3(0);
            new_variance = FfxFloat(0);
        }
    }
    FFX_DNSR_Reflections_StoreTemporalAccumulation(dispatch_thread_id, new_signal, new_variance);
}
