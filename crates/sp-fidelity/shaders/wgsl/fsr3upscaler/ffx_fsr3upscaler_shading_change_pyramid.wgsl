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

const DIFFERENCE: FfxInt32 = 0;
const SIGN_SUM: FfxInt32 = 1;
const MIP0_INDICATOR: FfxInt32 = 2;

fn Sort2(v: FfxFloat32x2) -> FfxFloat32x2
{
    return FfxFloat32x2(min(v.x, v.y), max(v.x, v.y));
}

struct SampleSet
{
    fSamples: array<FfxFloat32, SHADING_CHANGE_SET_SIZE>,
}


#if SHADING_CHANGE_SET_SIZE == 5
const iSampleOffsets: array<FfxInt32x2, 5> = array<FfxInt32x2, 5>(FfxInt32x2(0,0), FfxInt32x2(-1,0), FfxInt32x2(1,0), FfxInt32x2(0, -1), FfxInt32x2(0,1));

fn SortSet(fSet: ptr<function, SampleSet>)
{
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[0], (*fSet).fSamples[3]); (*fSet).fSamples[3] = max((*fSet).fSamples[0], (*fSet).fSamples[3]); (*fSet).fSamples[0] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[1], (*fSet).fSamples[4]); (*fSet).fSamples[4] = max((*fSet).fSamples[1], (*fSet).fSamples[4]); (*fSet).fSamples[1] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[0], (*fSet).fSamples[2]); (*fSet).fSamples[2] = max((*fSet).fSamples[0], (*fSet).fSamples[2]); (*fSet).fSamples[0] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[1], (*fSet).fSamples[3]); (*fSet).fSamples[3] = max((*fSet).fSamples[1], (*fSet).fSamples[3]); (*fSet).fSamples[1] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[0], (*fSet).fSamples[1]); (*fSet).fSamples[1] = max((*fSet).fSamples[0], (*fSet).fSamples[1]); (*fSet).fSamples[0] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[2], (*fSet).fSamples[4]); (*fSet).fSamples[4] = max((*fSet).fSamples[2], (*fSet).fSamples[4]); (*fSet).fSamples[2] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[1], (*fSet).fSamples[2]); (*fSet).fSamples[2] = max((*fSet).fSamples[1], (*fSet).fSamples[2]); (*fSet).fSamples[1] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[3], (*fSet).fSamples[4]); (*fSet).fSamples[4] = max((*fSet).fSamples[3], (*fSet).fSamples[4]); (*fSet).fSamples[3] = fTmp; };
    { var fTmp: FfxFloat32 = min((*fSet).fSamples[2], (*fSet).fSamples[3]); (*fSet).fSamples[3] = max((*fSet).fSamples[2], (*fSet).fSamples[3]); (*fSet).fSamples[2] = fTmp; };
}
#endif

fn ComputeMinimumDifference(iPxPos: FfxInt32x2, fSet0_: SampleSet, fSet1_: SampleSet) -> FfxFloat32
{
    var fSet0 = fSet0_;
    var fSet1 = fSet1_;
    var fMinDiff: FfxFloat32 = FSR3UPSCALER_FP16_MAX - 1;
    var a: FfxInt32 = 0;
    var b: FfxInt32 = 0;

    SortSet(&(fSet0));
    SortSet(&(fSet1));

    var fMax: FfxFloat32 = min(fSet0.fSamples[SHADING_CHANGE_SET_SIZE-1], fSet1.fSamples[SHADING_CHANGE_SET_SIZE-1]);

    if (fMax > FSR3UPSCALER_FP32_MIN) {

        
        for (var i: FfxInt32 = 0; i < SHADING_CHANGE_SET_SIZE && (fMinDiff < FSR3UPSCALER_FP16_MAX); i++) {

            var fDiff: FfxFloat32 = fSet0.fSamples[a] - fSet1.fSamples[b];

            if (abs(fDiff) > FSR3UPSCALER_FP16_MIN) {

                fDiff = sign(fDiff) * (1.0f - MinDividedByMax_f32_f32(fSet0.fSamples[a], fSet1.fSamples[b]));

                fMinDiff = select(fMinDiff, fDiff, (abs(fDiff) < abs(fMinDiff)));

                a += FfxInt32(fSet0.fSamples[a] < fSet1.fSamples[b]);
                b += FfxInt32(fSet0.fSamples[a] >= fSet1.fSamples[b]);
            }
            else
            {
                fMinDiff = FSR3UPSCALER_FP16_MAX;
            }
        }
    }

    return fMinDiff * FfxFloat32(fMinDiff < (FSR3UPSCALER_FP16_MAX - 1));
}

fn GetCurrentLumaBilinearSamples(fUv: FfxFloat32x2) -> SampleSet
{
    var fUvJittered: FfxFloat32x2 = fUv + Jitter() / FfxFloat32x2(RenderSize());
    var iBasePos: FfxInt32x2 = FfxInt32x2(floor(fUvJittered * FfxFloat32x2(RenderSize())));

    var fSet: SampleSet ;

    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < SHADING_CHANGE_SET_SIZE; iSampleIndex++) {
        var iSamplePos: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iBasePos, iSampleOffsets[iSampleIndex], RenderSize());
        fSet.fSamples[iSampleIndex] = LoadCurrentLuma(FfxUInt32x2(iSamplePos)) * Exposure();
        fSet.fSamples[iSampleIndex] = pow(fSet.fSamples[iSampleIndex], fShadingChangeSamplePow);
        fSet.fSamples[iSampleIndex] = max(fSet.fSamples[iSampleIndex], FSR3UPSCALER_EPSILON);
    }

    return fSet;
}

struct PreviousLumaBilinearSamplesData
{
    fSet: SampleSet,
    bIsExistingSample: FfxBoolean,
}

fn GetPreviousLumaBilinearSamples(fUv: FfxFloat32x2, fMotionVector: FfxFloat32x2) -> PreviousLumaBilinearSamplesData
{
    var data: PreviousLumaBilinearSamplesData ;

    var fUvJittered: FfxFloat32x2 = fUv + PreviousFrameJitter() / FfxFloat32x2(PreviousFrameRenderSize());
    var fReprojectedUv: FfxFloat32x2 = fUvJittered + fMotionVector;

    data.bIsExistingSample = IsUvInside(fReprojectedUv);

    if (data.bIsExistingSample) {

        var iBasePos: FfxInt32x2 = FfxInt32x2(floor(fReprojectedUv * FfxFloat32x2(PreviousFrameRenderSize())));

        for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < SHADING_CHANGE_SET_SIZE; iSampleIndex++) {

            var iSamplePos: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iBasePos, iSampleOffsets[iSampleIndex], PreviousFrameRenderSize());
            data.fSet.fSamples[iSampleIndex] = LoadPreviousLuma(FfxUInt32x2(iSamplePos)) * DeltaPreExposure() * Exposure();
            data.fSet.fSamples[iSampleIndex] = pow(data.fSet.fSamples[iSampleIndex], fShadingChangeSamplePow);
            data.fSet.fSamples[iSampleIndex] = max(data.fSet.fSamples[iSampleIndex], FSR3UPSCALER_EPSILON);
        }
    }

    return data;
}

fn ComputeDiff(iPxPos: FfxInt32x2, fUv: FfxFloat32x2, fMotionVector: FfxFloat32x2) -> FfxFloat32
{
    var fMinDiff: FfxFloat32 = 0.0f;

    var fCurrentSamples: SampleSet = GetCurrentLumaBilinearSamples(fUv);
    var previousData: PreviousLumaBilinearSamplesData = GetPreviousLumaBilinearSamples(fUv, fMotionVector);

    if (previousData.bIsExistingSample) {
        fMinDiff = ComputeMinimumDifference(iPxPos, fCurrentSamples, previousData.fSet);
    }

    return fMinDiff;
}

fn SpdLoadSourceImage(iPxPos_: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    let iPxPos = FfxFloat32x2(iPxPos_);
    var iPxSamplePos: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(FfxInt32x2(iPxPos), FfxInt32x2(0, 0), FfxInt32x2(RenderSize()));
    var fDilatedMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(iPxSamplePos));
    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxSamplePos) + 0.5f) / FfxFloat32x2(RenderSize());

    var fScaledAndSignedLumaDiff: FfxFloat32 = ComputeDiff(iPxSamplePos, fUv, fDilatedMotionVector);

    var fOutput: FfxFloat32x4 = FfxFloat32x4(0.0f, 0.0f, 0.0f, 0.0f);
    fOutput[DIFFERENCE]     = fScaledAndSignedLumaDiff;
    fOutput[SIGN_SUM]       = select(0.0f, sign(fScaledAndSignedLumaDiff), (fScaledAndSignedLumaDiff != 0.0f));
    fOutput[MIP0_INDICATOR] = 1.0f;

    return fOutput;
}

fn SpdLoad(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    return FfxFloat32x4(RWLoadPyramid(tex, 5), 0, 0);
}

fn SpdReduce4(v0: FfxFloat32x4, v1: FfxFloat32x4, v2: FfxFloat32x4, v3: FfxFloat32x4) -> FfxFloat32x4
{
    return (v0 + v1 + v2 + v3) * 0.25f;
}

fn SpdStore(pix: FfxInt32x2, outValue: FfxFloat32x4, index: FfxUInt32, slice: FfxUInt32)
{
    if (index >= FfxUInt32(iShadingChangeMipStart))
    {
        StorePyramid(pix, outValue.xy, index);
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

fn ComputeShadingChangePyramid(WorkGroupId: FfxUInt32x3, LocalThreadIndex: FfxUInt32)
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
