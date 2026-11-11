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

// WGSL port of ffx_opticalflow_compute_luminance_pyramid.h.
#ifndef FFX_OPTICALFLOW_COMPUTE_LUMINANCE_PYRAMID_H
#define FFX_OPTICALFLOW_COMPUTE_LUMINANCE_PYRAMID_H

var<workgroup> spdIntermediateR: array<array<FfxFloat32, 16>, 16>;
var<workgroup> spdIntermediateG: array<array<FfxFloat32, 16>, 16>;
var<workgroup> spdIntermediateB: array<array<FfxFloat32, 16>, 16>;
var<workgroup> spdIntermediateA: array<array<FfxFloat32, 16>, 16>;

// These empty callbacks and zero loads are present verbatim in the SDK.
// The optical-flow pyramid stops after six mips, before SPD global reduction.
fn SPD_IncreaseAtomicCounter(spdCounter: FfxUInt32)
{
}

fn SPD_ResetAtomicCounter()
{
}

fn SpdLoadSourceImage(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    var luma: FfxFloat32 = FfxFloat32(LoadRwOpticalFlowInput(FfxInt32x2(tex)));
    return FfxFloat32x4(luma, 0, 0, 0);
}

fn SpdLoad(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    return FfxFloat32x4(0, 0, 0, 0);
}

fn SpdStore(pix: FfxInt32x2, outValue: FfxFloat32x4, index: FfxUInt32, slice: FfxUInt32)
{
    SPD_SetMipmap(pix, index, outValue.r);
}

fn SpdIncreaseAtomicCounter(slice: FfxUInt32)
{
}

fn SpdGetAtomicCounter() -> FfxUInt32
{
    return 0;
}

fn SpdResetAtomicCounter(slice: FfxUInt32)
{
    SPD_ResetAtomicCounter();
}

fn SpdLoadIntermediate(x: FfxUInt32, y: FfxUInt32) -> FfxFloat32x4
{
    return FfxFloat32x4(
        spdIntermediateR[x][y],
        spdIntermediateG[x][y],
        spdIntermediateB[x][y],
        spdIntermediateA[x][y]);
}
fn SpdStoreIntermediate(x: FfxUInt32, y: FfxUInt32, value: FfxFloat32x4)
{
    spdIntermediateR[x][y] = value.x;
    spdIntermediateG[x][y] = value.y;
    spdIntermediateB[x][y] = value.z;
    spdIntermediateA[x][y] = value.w;
}
fn SpdReduce4(v0: FfxFloat32x4, v1: FfxFloat32x4, v2: FfxFloat32x4, v3: FfxFloat32x4) -> FfxFloat32x4
{
    return (v0 + v1 + v2 + v3) * 0.25;
}

// As in the SDK, this pyramid always selects the FP32 SPD implementation.
#ifdef FFX_HALF
#undef FFX_HALF
#endif

// https://github.com/GPUOpen-Effects/FidelityFX-SPD/blob/master/docs/FidelityFX_SPD.pdf
#include "spd/ffx_spd.wgsl"

fn ComputeOpticalFlowInputPyramid(iGroupId: FfxInt32x2, iLocalIndex: FfxInt32)
{
    SpdDownsample_u32x2_u32_u32_u32_u32(
        FfxUInt32x2(iGroupId.xy),
        FfxUInt32(iLocalIndex),
        6, // mip levels to generate
        // SPD returns after mip 5, before reading numWorkGroups. DXC
        // eliminates the SDK NumWorkGroups() argument and its cbSPD binding;
        // WGSL evaluates function arguments eagerly, so pass its unused value
        // directly to retain that compiled resource interface.
        0u,
        1 // single slice
    );
}

#endif // FFX_OPTICALFLOW_COMPUTE_LUMINANCE_PYRAMID_H
