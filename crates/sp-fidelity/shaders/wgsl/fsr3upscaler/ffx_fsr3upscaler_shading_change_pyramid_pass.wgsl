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

// WGSL port of the corresponding FidelityFX SDK 1.1.4 FSR3 upscaler source.
// Out/inout parameters use function pointers; numeric conversions are explicit.
#define FSR3UPSCALER_BIND_SRV_CURRENT_LUMA                          0
#define FSR3UPSCALER_BIND_SRV_PREVIOUS_LUMA                         1
#define FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS                2
#define FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE                        3


#define FSR3UPSCALER_BIND_UAV_SPD_GLOBAL_ATOMIC                     0
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0                      1
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_1                      2
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_2                      3
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_3                      4
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_4                      5
#define FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5                      6


#define FSR3UPSCALER_BIND_CB_FSR3UPSCALER                           0
#define FSR3UPSCALER_BIND_CB_SPD                                    1

#include "fsr3upscaler/ffx_fsr3upscaler_callbacks.wgsl"
#include "fsr3upscaler/ffx_fsr3upscaler_common.wgsl"
#include "fsr3upscaler/ffx_fsr3upscaler_shading_change_pyramid.wgsl"

#ifndef FFX_FSR3UPSCALER_THREAD_GROUP_WIDTH
#define FFX_FSR3UPSCALER_THREAD_GROUP_WIDTH 256
#endif // #ifndef FFX_FSR3UPSCALER_THREAD_GROUP_WIDTH
#ifndef FFX_FSR3UPSCALER_THREAD_GROUP_HEIGHT
#define FFX_FSR3UPSCALER_THREAD_GROUP_HEIGHT 1
#endif // #ifndef FFX_FSR3UPSCALER_THREAD_GROUP_HEIGHT
#ifndef FFX_FSR3UPSCALER_THREAD_GROUP_DEPTH
#define FFX_FSR3UPSCALER_THREAD_GROUP_DEPTH 1
#endif // #ifndef FFX_FSR3UPSCALER_THREAD_GROUP_DEPTH
// D3D root signatures and wave-size preferences have no WGSL equivalent.
@compute @workgroup_size(FFX_FSR3UPSCALER_THREAD_GROUP_WIDTH, FFX_FSR3UPSCALER_THREAD_GROUP_HEIGHT, FFX_FSR3UPSCALER_THREAD_GROUP_DEPTH)
fn CS(@builtin(workgroup_id) WorkGroupId_: FfxUInt32x3, @builtin(local_invocation_index) LocalThreadIndex_: FfxUInt32)
{
    let WorkGroupId: FfxUInt32x3 = FfxUInt32x3(WorkGroupId_.xyz);
    let LocalThreadIndex: FfxUInt32 = LocalThreadIndex_;
    ComputeShadingChangePyramid(WorkGroupId, LocalThreadIndex);

}
