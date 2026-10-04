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

// WGSL port of ffx_fsr2_autogen_reactive_pass.hlsl. SDK 1.1.4 never schedules
// this pass: ffxFsr2ContextGenerateReactiveMask builds its job but leaves the
// fpScheduleGpuJob call commented out (ffx_fsr2.cpp:1569).

#define FSR2_BIND_SRV_INPUT_OPAQUE_ONLY                     0
#define FSR2_BIND_SRV_INPUT_COLOR                           1

#define FSR2_BIND_UAV_AUTOREACTIVE                          0

#define FSR2_BIND_CB_FSR2                                   0
#define FSR2_BIND_CB_REACTIVE                               1

#include "fsr2/ffx_fsr2_callbacks.wgsl"
#include "fsr2/ffx_fsr2_common.wgsl"

#ifndef FFX_FSR2_THREAD_GROUP_WIDTH
#define FFX_FSR2_THREAD_GROUP_WIDTH 8
#endif // #ifndef FFX_FSR2_THREAD_GROUP_WIDTH
#ifndef FFX_FSR2_THREAD_GROUP_HEIGHT
#define FFX_FSR2_THREAD_GROUP_HEIGHT 8
#endif // FFX_FSR2_THREAD_GROUP_HEIGHT
#ifndef FFX_FSR2_THREAD_GROUP_DEPTH
#define FFX_FSR2_THREAD_GROUP_DEPTH 1
#endif // #ifndef FFX_FSR2_THREAD_GROUP_DEPTH
// FFX_FSR2_NUM_THREADS [numthreads(...)], FFX_PREFER_WAVE64 and
// FFX_FSR2_EMBED_ROOTSIG_REACTIVE_CONTENT. WGSL: @workgroup_size; the optional
// [WaveSize(64)] and the D3D12 root signature have no WGSL form.
//
// WGSL: a flag test is compared with zero where HLSL converts the uint to
// bool, and the SDK's scalar cond ? a : b is select(b, a, cond).
@compute @workgroup_size(FFX_FSR2_THREAD_GROUP_WIDTH, FFX_FSR2_THREAD_GROUP_HEIGHT, FFX_FSR2_THREAD_GROUP_DEPTH)
fn CS(@builtin(workgroup_id) uGroupId: FfxUInt32x3, @builtin(local_invocation_id) uGroupThreadId: FfxUInt32x3)
{
    let uDispatchThreadId: FfxUInt32x2 = uGroupId.xy * FfxUInt32x2(FFX_FSR2_THREAD_GROUP_WIDTH, FFX_FSR2_THREAD_GROUP_HEIGHT) + uGroupThreadId.xy;

    var ColorPreAlpha: FfxFloat32x3    = LoadOpaqueOnly( FFX_MIN16_I2(uDispatchThreadId) ).rgb;
    var ColorPostAlpha: FfxFloat32x3   = LoadInputColor(uDispatchThreadId).rgb;
    
    if ((GenReactiveFlags() & FFX_FSR2_AUTOREACTIVEFLAGS_APPLY_TONEMAP) != 0u)
    {
        ColorPreAlpha = Tonemap_f32x3(ColorPreAlpha);
        ColorPostAlpha = Tonemap_f32x3(ColorPostAlpha);
    }

    if ((GenReactiveFlags() & FFX_FSR2_AUTOREACTIVEFLAGS_APPLY_INVERSETONEMAP) != 0u)
    {
        ColorPreAlpha = InverseTonemap_f32x3(ColorPreAlpha);
        ColorPostAlpha = InverseTonemap_f32x3(ColorPostAlpha);
    }

    var out_reactive_value: f32 = 0.f;
    let delta: FfxFloat32x3 = abs(ColorPostAlpha - ColorPreAlpha);
    
    out_reactive_value = select(length(delta), max(delta.x, max(delta.y, delta.z)), (GenReactiveFlags() & FFX_FSR2_AUTOREACTIVEFLAGS_USE_COMPONENTS_MAX) != 0u);
    out_reactive_value *= GenReactiveScale();

    out_reactive_value = select(out_reactive_value, select(GenReactiveBinaryValue(), 0.0f, out_reactive_value < GenReactiveThreshold()), (GenReactiveFlags() & FFX_FSR2_AUTOREACTIVEFLAGS_APPLY_THRESHOLD) != 0u);

    // rw_output_autoreactive[uDispatchThreadId] = out_reactive_value;
    // WGSL: HLSL discards a store outside the texture (SDK-P7).
    if (!ffxWgslOutside(FfxInt32x2(uDispatchThreadId), textureDimensions(rw_output_autoreactive))) {
        textureStore(rw_output_autoreactive, uDispatchThreadId, FfxFloat32x4(out_reactive_value));
    }
}
