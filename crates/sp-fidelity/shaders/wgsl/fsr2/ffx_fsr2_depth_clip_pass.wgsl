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

// WGSL port of ffx_fsr2_depth_clip_pass.hlsl.

#define FSR2_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH      0
#define FSR2_BIND_SRV_DILATED_MOTION_VECTORS                1
#define FSR2_BIND_SRV_DILATED_DEPTH                         2
#define FSR2_BIND_SRV_REACTIVE_MASK                         3
#define FSR2_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK     4
#define FSR2_BIND_SRV_PREVIOUS_DILATED_MOTION_VECTORS       5
#define FSR2_BIND_SRV_INPUT_MOTION_VECTORS                  6
#define FSR2_BIND_SRV_INPUT_COLOR                           7
#define FSR2_BIND_SRV_INPUT_DEPTH                           8
#define FSR2_BIND_SRV_INPUT_EXPOSURE                        9

#define FSR2_BIND_UAV_DILATED_REACTIVE_MASKS                0
#define FSR2_BIND_UAV_PREPARED_INPUT_COLOR                  1

#define FSR2_BIND_CB_FSR2                                   0

#include "fsr2/ffx_fsr2_callbacks.wgsl"
#include "fsr2/ffx_fsr2_common.wgsl"
#include "fsr2/ffx_fsr2_sample.wgsl"
#include "fsr2/ffx_fsr2_depth_clip.wgsl"

#ifndef FFX_FSR2_THREAD_GROUP_WIDTH
#define FFX_FSR2_THREAD_GROUP_WIDTH 8
#endif // #ifndef FFX_FSR2_THREAD_GROUP_WIDTH
#ifndef FFX_FSR2_THREAD_GROUP_HEIGHT
#define FFX_FSR2_THREAD_GROUP_HEIGHT 8
#endif // #ifndef FFX_FSR2_THREAD_GROUP_HEIGHT
#ifndef FFX_FSR2_THREAD_GROUP_DEPTH
#define FFX_FSR2_THREAD_GROUP_DEPTH 1
#endif // #ifndef FFX_FSR2_THREAD_GROUP_DEPTH
// FFX_FSR2_NUM_THREADS [numthreads(...)], FFX_PREFER_WAVE64 and
// FFX_FSR2_EMBED_ROOTSIG_CONTENT. WGSL: @workgroup_size; the optional
// [WaveSize(64)] and the D3D12 root signature have no WGSL form.
// WGSL: the int2 SV_GroupID, SV_DispatchThreadID and SV_GroupThreadID and the
// int SV_GroupIndex are u32 builtins, converted as HLSL converts them.
@compute @workgroup_size(FFX_FSR2_THREAD_GROUP_WIDTH, FFX_FSR2_THREAD_GROUP_HEIGHT, FFX_FSR2_THREAD_GROUP_DEPTH)
fn CS(
    @builtin(workgroup_id) iGroupId: FfxUInt32x3,
    @builtin(global_invocation_id) iDispatchThreadId: FfxUInt32x3,
    @builtin(local_invocation_id) iGroupThreadId: FfxUInt32x3,
    @builtin(local_invocation_index) iGroupIndex: FfxUInt32)
{
    DepthClip(FfxInt32x2(iDispatchThreadId.xy));
}
