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

// WGSL port of ffx_fsr2_compute_luminance_pyramid.h: FSR2's SPD callbacks.
// The SDK's blob accessor always selects the 32-bit table for this pass
// (ffx_fsr2_shaderblobs.cpp:274-288), so the FFX_HALF block is never compiled.

var<workgroup> spdCounter: FfxUInt32; // FFX_GROUPSHARED

fn SpdIncreaseAtomicCounter(slice: FfxUInt32)
{
    // WGSL: a workgroup pointer cannot be a function argument; this is the
    // copy-in/copy-out of the SDK's inout argument.
    var spdCounter_inout: FfxUInt32 = spdCounter;
    SPD_IncreaseAtomicCounter(&spdCounter_inout);
    spdCounter = spdCounter_inout;
}

fn SpdGetAtomicCounter() -> FfxUInt32
{
    return spdCounter;
}

fn SpdResetAtomicCounter(slice: FfxUInt32)
{
    SPD_ResetAtomicCounter();
}

#ifndef SPD_PACKED_ONLY
var<workgroup> spdIntermediateR: array<array<FfxFloat32, 16>, 16>; // FFX_GROUPSHARED
var<workgroup> spdIntermediateG: array<array<FfxFloat32, 16>, 16>; // FFX_GROUPSHARED
var<workgroup> spdIntermediateB: array<array<FfxFloat32, 16>, 16>; // FFX_GROUPSHARED
var<workgroup> spdIntermediateA: array<array<FfxFloat32, 16>, 16>; // FFX_GROUPSHARED

// WGSL: SPD calls SpdLoadSourceImage(FfxInt32x2(i0), slice)
// (ffx_spd.h:215-218), and HLSL converts the int2 to this function's
// FfxFloat32x2 tex; here the callback takes the int2 and converts it.
fn SpdLoadSourceImage(tex_: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    let tex: FfxFloat32x2 = FfxFloat32x2(tex_);
    var fUv: FfxFloat32x2 = (tex + 0.5f + Jitter()) / FfxFloat32x2(RenderSize());
    fUv = ClampUv(fUv, RenderSize(), InputColorResourceDimensions());
    var fRgb: FfxFloat32x3 = SampleInputColor(fUv);

    fRgb /= PreExposure();
   
    //compute log luma
    let fLogLuma: FfxFloat32 = log(ffxMax_f32_f32(FSR2_EPSILON, RGBToLuma_f32x3(fRgb)));

    // Make sure out of screen pixels contribute no value to the end result
    let result: FfxFloat32 = select(0.0f, fLogLuma, all(tex < FfxFloat32x2(RenderSize())));

    return FfxFloat32x4(result, 0, 0, 0);
}

fn SpdLoad(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    return SPD_LoadMipmap5(tex);
}

fn SpdStore(pix: FfxInt32x2, outValue: FfxFloat32x4, index: FfxUInt32, slice: FfxUInt32)
{
    // WGSL: HLSL converts LumaMipLevelToUse()'s int to the uint index.
    if (index == FfxUInt32(LumaMipLevelToUse()) || index == 5u)
    {
        SPD_SetMipmap(pix, index, outValue.r);
    }

    if (index == MipCount() - 1u) { //accumulate on 1x1 level

        if (all(pix == FfxInt32x2(0, 0)))
        {
            let prev: FfxFloat32 = SPD_LoadExposureBuffer().y;
            var result: FfxFloat32 = outValue.r;

            if (prev < resetAutoExposureAverageSmoothing) // Compare Lavg, so small or negative values
            {
                let rate: FfxFloat32 = 1.0f;
                result = prev + (result - prev) * (1 - exp(-DeltaTime() * rate));
            }
            let spdOutput: FfxFloat32x2 = FfxFloat32x2(ComputeAutoExposureFromLavg_f32(result), result);
            SPD_SetExposureBuffer(spdOutput);
        }
    }
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
    return (v0 + v1 + v2 + v3) * 0.25f;
}
#endif

// define fetch and store functions Packed
#if FFX_HALF

var<workgroup> spdIntermediateRG: array<array<FfxFloat16x2, 16>, 16>; // FFX_GROUPSHARED
var<workgroup> spdIntermediateBA: array<array<FfxFloat16x2, 16>, 16>; // FFX_GROUPSHARED

// WGSL: SPD passes FfxInt32x2 (ffx_spd.h:652-655), converted as for
// SpdLoadSourceImage; tex is unused.
fn SpdLoadSourceImageH(tex_: FfxInt32x2, slice: FfxUInt32) -> FfxFloat16x4
{
    return FfxFloat16x4(0, 0, 0, 0);
}

fn SpdLoadH(p: FfxInt32x2, slice: FfxUInt32) -> FfxFloat16x4
{
    return FfxFloat16x4(0, 0, 0, 0);
}

fn SpdStoreH(p: FfxInt32x2, value: FfxFloat16x4, mip: FfxUInt32, slice: FfxUInt32)
{
}

fn SpdLoadIntermediateH(x: FfxUInt32, y: FfxUInt32) -> FfxFloat16x4
{
    return FfxFloat16x4(
        spdIntermediateRG[x][y].x,
        spdIntermediateRG[x][y].y,
        spdIntermediateBA[x][y].x,
        spdIntermediateBA[x][y].y);
}

fn SpdStoreIntermediateH(x: FfxUInt32, y: FfxUInt32, value: FfxFloat16x4)
{
    spdIntermediateRG[x][y] = value.xy;
    spdIntermediateBA[x][y] = value.zw;
}

fn SpdReduce4H(v0: FfxFloat16x4, v1: FfxFloat16x4, v2: FfxFloat16x4, v3: FfxFloat16x4) -> FfxFloat16x4
{
    return (v0 + v1 + v2 + v3) * FfxFloat16(0.25);
}
#endif

#include "spd/ffx_spd.wgsl"

fn ComputeAutoExposure(WorkGroupId: FfxUInt32x3, LocalThreadIndex: FfxUInt32)
{
#if FFX_HALF
    SpdDownsampleH_u32x2_u32_u32_u32_u32_u32x2(
        FfxUInt32x2(WorkGroupId.xy),
        FfxUInt32(LocalThreadIndex),
        FfxUInt32(MipCount()),
        FfxUInt32(NumWorkGroups()),
        FfxUInt32(WorkGroupId.z),
        FfxUInt32x2(WorkGroupOffset()));
#else
    SpdDownsample_u32x2_u32_u32_u32_u32_u32x2(
        FfxUInt32x2(WorkGroupId.xy),
        FfxUInt32(LocalThreadIndex),
        FfxUInt32(MipCount()),
        FfxUInt32(NumWorkGroups()),
        FfxUInt32(WorkGroupId.z),
        FfxUInt32x2(WorkGroupOffset()));
#endif
}
