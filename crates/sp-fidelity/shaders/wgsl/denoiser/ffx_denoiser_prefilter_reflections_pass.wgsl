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

// WGSL port of ffx_denoiser_prefilter_reflections_pass.hlsl.
#define DENOISER_BIND_SRV_INPUT_DEPTH_HIERARCHY    2
#define DENOISER_BIND_SRV_INPUT_NORMAL             4
#define DENOISER_BIND_SRV_RADIANCE                 7
#define DENOISER_BIND_SRV_VARIANCE                 9
#define DENOISER_BIND_SRV_AVERAGE_RADIANCE         11
#define DENOISER_BIND_SRV_EXTRACTED_ROUGHNESS      12
#define DENOISER_BIND_UAV_RADIANCE            0
#define DENOISER_BIND_UAV_VARIANCE            1
#define DENOISER_BIND_UAV_DENOISER_TILE_LIST  5
#define DENOISER_BIND_CB_DENOISER   0

#include "denoiser/ffx_denoiser_reflections_callbacks.wgsl"
#include "denoiser/ffx_denoiser_reflections_common.wgsl"
#include "denoiser/ffx_denoiser_reflections_prefilter.wgsl"

@compute @workgroup_size(8, 8, 1)
fn CS(@builtin(local_invocation_index) lane: u32, @builtin(workgroup_id) group_id: vec3u,
      @builtin(local_invocation_id) local_id: vec3u) {
    let packed = GetDenoiserTile(group_id.x);
    let tile_origin = vec2i(i32(packed & 0xffffu), i32(packed >> 16u));
    let group = (tile_origin + vec2i(local_id.xy)) / 8;
    let remapped = vec2i(ffxRemapForWaveReduction(lane));
    let pixel = group * 8 + remapped;
    FFX_DNSR_Reflections_Prefilter(pixel, remapped, RenderSize());
}
