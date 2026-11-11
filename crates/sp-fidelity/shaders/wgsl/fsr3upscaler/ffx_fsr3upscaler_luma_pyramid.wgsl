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
var<workgroup> spdCounter: FfxUInt32 ;

fn SpdIncreaseAtomicCounter(slice: FfxUInt32)
{
    var counter: FfxUInt32 = spdCounter;
    SPD_IncreaseAtomicCounter(&counter);
    spdCounter = counter;
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
var<workgroup> spdIntermediateR: array<array<FfxFloat32, 16>, 16> ;
var<workgroup> spdIntermediateG: array<array<FfxFloat32, 16>, 16> ;
var<workgroup> spdIntermediateB: array<array<FfxFloat32, 16>, 16> ;
var<workgroup> spdIntermediateA: array<array<FfxFloat32, 16>, 16> ;

const LOG_LUMA: FfxInt32 = 0;
const LUMA: FfxInt32 = 1;
const DEPTH_IN_METERS: FfxInt32 = 2;

fn SpdLoadSourceImage(iPxPos_: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    let iPxPos = FfxFloat32x2(iPxPos_);
    //We assume linear data. if non-linear input (sRGB, ...),
    //then we should convert to linear first and back to sRGB on output.
    var iPxSamplePos: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(FfxInt32x2(iPxPos), FfxInt32x2(0, 0), FfxInt32x2(RenderSize()));

    var fLuma: FfxFloat32 = LoadCurrentLuma(FfxUInt32x2(iPxSamplePos));
    var fLogLuma: FfxFloat32 = max(FSR3UPSCALER_EPSILON, log(fLuma));
    var fFarthestDepthInMeters: FfxFloat32 = LoadFarthestDepth(FfxUInt32x2(iPxSamplePos));

    var fOutput: FfxFloat32x4 = FfxFloat32x4(0.0f, 0.0f, 0.0f, 0.0f);
    fOutput[LOG_LUMA]           = fLogLuma;
    fOutput[LUMA]               = fLuma;
    fOutput[DEPTH_IN_METERS]    = fFarthestDepthInMeters;

    return fOutput;
}

fn SpdLoad(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    // WGSL does not fold resource switches across calls as DXC does. This
    // pass only accesses mip 5; keep its reachable bindings equal to the SDK.
    if (ffxWgslOutside(tex, textureDimensions(rw_spd_mip5))) {
        return FfxFloat32x4(0);
    }
    return FfxFloat32x4(textureLoad(rw_spd_mip5, tex).xy, 0, 0);
}

fn SpdReduce4(v0: FfxFloat32x4, v1: FfxFloat32x4, v2: FfxFloat32x4, v3: FfxFloat32x4) -> FfxFloat32x4
{
    return (v0 + v1 + v2 + v3) * 0.25f;
}

fn SpdStore(pix: FfxInt32x2, outValue: FfxFloat32x4, index_: FfxUInt32, slice: FfxUInt32)
{
    var index: FfxUInt32 = index_;
    if (index == 5)
    {
        if (!ffxWgslOutside(pix, textureDimensions(rw_spd_mip5))) {
            textureStore(rw_spd_mip5, pix, FfxFloat32x4(outValue.xy, 0, 0));
        }
    }
    else if (index == 0) {
        StoreFarthestDepthMip1(FfxUInt32x2(pix), outValue[DEPTH_IN_METERS]);
    }

    if (index == MipCount() - 1) { //accumulate on 1x1 level

        if (all(pix == FfxInt32x2(0, 0)))
        {
            var frameInfo: FfxFloat32x4 = LoadFrameInfo();
            var fSceneAvgLuma: FfxFloat32 = outValue[LUMA];
            var fPrevLogLuma: FfxFloat32 = frameInfo[FRAME_INFO_LOG_LUMA];
            var fLogLuma: FfxFloat32 = outValue[LOG_LUMA];

            if (fPrevLogLuma < resetAutoExposureAverageSmoothing) // Compare Lavg, so small or negative values
            {
                fLogLuma = fPrevLogLuma + (fLogLuma - fPrevLogLuma) * (1.0f - exp(-DeltaTime()));
                fLogLuma = max(0.0f, fLogLuma);
            }

            frameInfo[FRAME_INFO_EXPOSURE]             = ComputeAutoExposureFromLavg_f32(fLogLuma);
            frameInfo[FRAME_INFO_LOG_LUMA]             = fLogLuma;
            frameInfo[FRAME_INFO_SCENE_AVERAGE_LUMA]   = fSceneAvgLuma;

            StoreFrameInfo(frameInfo);
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

#endif

// define fetch and store functions Packed
#if FFX_HALF

var<workgroup> spdIntermediateRG: array<array<FfxFloat16x2, 16>, 16> ;
var<workgroup> spdIntermediateBA: array<array<FfxFloat16x2, 16>, 16> ;

fn SpdLoadSourceImageH(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat16x4
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
