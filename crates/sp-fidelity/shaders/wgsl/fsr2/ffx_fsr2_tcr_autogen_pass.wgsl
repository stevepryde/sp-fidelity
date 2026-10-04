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

// WGSL port of ffx_fsr2_tcr_autogen_pass.hlsl.

#define FSR2_BIND_SRV_INPUT_OPAQUE_ONLY                     0
#define FSR2_BIND_SRV_INPUT_COLOR                           1
#define FSR2_BIND_SRV_INPUT_MOTION_VECTORS                  2
#define FSR2_BIND_SRV_PREV_PRE_ALPHA_COLOR                  3
#define FSR2_BIND_SRV_PREV_POST_ALPHA_COLOR                 4
#define FSR2_BIND_SRV_REACTIVE_MASK                         4
#define FSR2_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK     5

#define FSR2_BIND_UAV_AUTOREACTIVE                          0
#define FSR2_BIND_UAV_AUTOCOMPOSITION                       1
#define FSR2_BIND_UAV_PREV_PRE_ALPHA_COLOR                  2
#define FSR2_BIND_UAV_PREV_POST_ALPHA_COLOR                 3

#define FSR2_BIND_CB_FSR2                                   0
#define FSR2_BIND_CB_AUTOREACTIVE                           1

#include "fsr2/ffx_fsr2_callbacks.wgsl"
#include "fsr2/ffx_fsr2_common.wgsl"
#include "fsr2/ffx_fsr2_tcr_autogen.wgsl"

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
// WGSL: conversions HLSL makes implicitly are written, as in
// ffx_fsr2_tcr_autogen.wgsl. FFX_MIN16_F2(0.5f, 0.5f) converts float
// constants; fPrevUV * FFX_MIN16_F2(RenderSize()) - 0.5f is computed in float
// (DXC promotes the FFX_MIN16_F2 operand for the float constant).
@compute @workgroup_size(FFX_FSR2_THREAD_GROUP_WIDTH, FFX_FSR2_THREAD_GROUP_HEIGHT, FFX_FSR2_THREAD_GROUP_DEPTH)
fn CS(@builtin(workgroup_id) uGroupId: FfxUInt32x3, @builtin(local_invocation_id) uGroupThreadId: FfxUInt32x3)
{
    let uDispatchThreadId: FFX_MIN16_I2 = FFX_MIN16_I2(uGroupId.xy * FfxUInt32x2(FFX_FSR2_THREAD_GROUP_WIDTH, FFX_FSR2_THREAD_GROUP_HEIGHT) + uGroupThreadId.xy);

    // ToDo: take into account jitter (i.e. add delta of previous jitter and current jitter to previous UV
    // fetch pre- and post-alpha color values
    let fUv: FFX_MIN16_F2 = ( FFX_MIN16_F2(uDispatchThreadId) + FFX_MIN16_F2(FfxFloat32x2(0.5f, 0.5f)) ) / FFX_MIN16_F2( RenderSize() );
    let fPrevUV: FFX_MIN16_F2 = fUv + FFX_MIN16_F2( LoadInputMotionVector(FfxUInt32x2(uDispatchThreadId)) );
    let iPrevIdx: FFX_MIN16_I2 = FFX_MIN16_I2(FfxFloat32x2(fPrevUV * FFX_MIN16_F2(RenderSize())) - 0.5f);

    let colorPreAlpha: FFX_MIN16_F3  = FFX_MIN16_F3( LoadOpaqueOnly(  uDispatchThreadId ) );
    let colorPostAlpha: FFX_MIN16_F3 = FFX_MIN16_F3( LoadInputColor( FfxUInt32x2(uDispatchThreadId) ) );

    var outReactiveMask: FFX_MIN16_F2 = FFX_MIN16_F2(0);
    
    outReactiveMask.y = ComputeTransparencyAndComposition(uDispatchThreadId, iPrevIdx);

    if (FfxFloat32(outReactiveMask.y) > 0.5f)
    {
        outReactiveMask.x = ComputeReactive(uDispatchThreadId, iPrevIdx);
        outReactiveMask.x *= FFX_MIN16_F(ReactiveScale());
        outReactiveMask.x = select(FFX_MIN16_F(ReactiveMax()), outReactiveMask.x, FfxFloat32(outReactiveMask.x) < ReactiveMax());
    }

    outReactiveMask.y *= FFX_MIN16_F( TcScale() );

    outReactiveMask.x = max( outReactiveMask.x, FFX_MIN16_F( LoadReactiveMask(FfxUInt32x2(uDispatchThreadId)) ) );
    outReactiveMask.y = max( outReactiveMask.y, FFX_MIN16_F( LoadTransparencyAndCompositionMask(FfxUInt32x2(uDispatchThreadId)) ) );

    StoreAutoReactive(uDispatchThreadId, outReactiveMask);

    StorePrevPreAlpha(uDispatchThreadId, colorPreAlpha);
    StorePrevPostAlpha(uDispatchThreadId, colorPostAlpha);
}
