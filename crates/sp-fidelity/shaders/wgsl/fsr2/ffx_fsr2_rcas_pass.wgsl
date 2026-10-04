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

// WGSL port of ffx_fsr2_rcas_pass.hlsl.

#define FSR2_BIND_SRV_INPUT_EXPOSURE        0
#define FSR2_BIND_SRV_RCAS_INPUT            1

#define FSR2_BIND_UAV_UPSCALED_OUTPUT       0

#define FSR2_BIND_CB_FSR2                   0
#define FSR2_BIND_CB_RCAS                   1

#include "fsr2/ffx_fsr2_callbacks.wgsl"
#include "fsr2/ffx_fsr2_common.wgsl"
#include "fsr2/ffx_fsr2_rcas.wgsl"

#ifndef FFX_FSR2_THREAD_GROUP_WIDTH
#define FFX_FSR2_THREAD_GROUP_WIDTH 64
#endif // #ifndef FFX_FSR2_THREAD_GROUP_WIDTH
#ifndef FFX_FSR2_THREAD_GROUP_HEIGHT
#define FFX_FSR2_THREAD_GROUP_HEIGHT 1
#endif // #ifndef FFX_FSR2_THREAD_GROUP_HEIGHT
#ifndef FFX_FSR2_THREAD_GROUP_DEPTH
#define FFX_FSR2_THREAD_GROUP_DEPTH 1
#endif // #ifndef FFX_FSR2_THREAD_GROUP_DEPTH
// FFX_FSR2_NUM_THREADS [numthreads(...)], FFX_PREFER_WAVE64 and
// FFX_FSR2_EMBED_CB2_ROOTSIG_CONTENT. WGSL: @workgroup_size; the optional
// [WaveSize(64)] and the D3D12 root signature have no WGSL form.
@compute @workgroup_size(FFX_FSR2_THREAD_GROUP_WIDTH, FFX_FSR2_THREAD_GROUP_HEIGHT, FFX_FSR2_THREAD_GROUP_DEPTH)
fn CS(@builtin(local_invocation_id) LocalThreadId: FfxUInt32x3, @builtin(workgroup_id) WorkGroupId: FfxUInt32x3, @builtin(global_invocation_id) Dtid: FfxUInt32x3)
{
    RCAS(LocalThreadId, WorkGroupId, Dtid);
}
