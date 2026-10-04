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

// WGSL port of ffx_fsr2_common.h. Overloads carry parameter-type suffixes (see
// ffx_core.wgsl); FFX_PARAMETER_OUT/INOUT parameters are function pointers.
// HLSL's implicit int-to-float and float-to-half conversions are written out.
// Literals the SDK writes with an f suffix stay f32 and are converted, as DXC
// rounds them to float before narrowing to half.

#if !defined(FFX_FSR2_COMMON_H)
#define FFX_FSR2_COMMON_H

#if defined(FFX_CPU) || defined(FFX_GPU)
//Locks
#define LOCK_LIFETIME_REMAINING 0
#define LOCK_TEMPORAL_LUMA 1
#endif // #if defined(FFX_CPU) || defined(FFX_GPU)

#if defined(FFX_GPU)
const FSR2_FP16_MIN: FfxFloat32 = 6.10e-05f;
const FSR2_FP16_MAX: FfxFloat32 = 65504.0f;
const FSR2_EPSILON: FfxFloat32 = 1e-03f;
const FSR2_TONEMAP_EPSILON: FfxFloat32 = 1.0f / FSR2_FP16_MAX;
const FSR2_FLT_MAX: FfxFloat32 = 3.402823466e+38f;
const FSR2_FLT_MIN: FfxFloat32 = 1.175494351e-38f;

// #pragma warning directives: HLSL only.

// Reconstructed depth usage
const fReconstructedDepthBilinearWeightThreshold: FfxFloat32 = 0.01f;

// Accumulation
const fUpsampleLanczosWeightScale: FfxFloat32 = 1.0f / 12.0f;
const fMaxAccumulationLanczosWeight: FfxFloat32 = 1.0f;
const fAverageLanczosWeightPerFrame: FfxFloat32 = 0.74f * fUpsampleLanczosWeightScale; // Average lanczos weight for jitter accumulated samples
const fAccumulationMaxOnMotion: FfxFloat32 = 3.0f * fUpsampleLanczosWeightScale;

// Auto exposure
const resetAutoExposureAverageSmoothing: FfxFloat32 = 1e8f;

struct AccumulationPassCommonParams
{
    iPxHrPos: FfxInt32x2,
    fHrUv: FfxFloat32x2,
    fLrUv_HwSampler: FfxFloat32x2,
    fMotionVector: FfxFloat32x2,
    fReprojectedHrUv: FfxFloat32x2,
    fHrVelocity: FfxFloat32,
    fDepthClipFactor: FfxFloat32,
    fDilatedReactiveFactor: FfxFloat32,
    fAccumulationMask: FfxFloat32,

    bIsResetFrame: FfxBoolean,
    bIsExistingSample: FfxBoolean,
    bIsNewSample: FfxBoolean,
}

struct LockState
{
    NewLock: FfxBoolean, //Set for both unique new and re-locked new
    WasLockedPrevFrame: FfxBoolean, //Set to identify if the pixel was already locked (relock)
}

fn InitializeNewLockSample_f32x2(fLockStatus: ptr<function, FfxFloat32x2>)
{
    *fLockStatus = FfxFloat32x2(0, 0);
}

#if FFX_HALF
fn InitializeNewLockSample_f16x2(fLockStatus: ptr<function, FFX_MIN16_F2>)
{
    *fLockStatus = FFX_MIN16_F2(0, 0);
}
#endif


fn KillLock_f32x2(fLockStatus: ptr<function, FfxFloat32x2>)
{
    (*fLockStatus)[LOCK_LIFETIME_REMAINING] = 0;
}

#if FFX_HALF
fn KillLock_f16x2(fLockStatus: ptr<function, FFX_MIN16_F2>)
{
    (*fLockStatus)[LOCK_LIFETIME_REMAINING] = FFX_MIN16_F(0);
}
#endif

struct RectificationBox
{
    boxCenter: FfxFloat32x3,
    boxVec: FfxFloat32x3,
    aabbMin: FfxFloat32x3,
    aabbMax: FfxFloat32x3,
    fBoxCenterWeight: FfxFloat32,
}
#if FFX_HALF
struct RectificationBoxMin16
{
    boxCenter: FFX_MIN16_F3,
    boxVec: FFX_MIN16_F3,
    aabbMin: FFX_MIN16_F3,
    aabbMax: FFX_MIN16_F3,
    fBoxCenterWeight: FFX_MIN16_F,
}
#endif

fn RectificationBoxReset_RectificationBox(rectificationBox: ptr<function, RectificationBox>)
{
    (*rectificationBox).fBoxCenterWeight = FfxFloat32(0);

    (*rectificationBox).boxCenter = FfxFloat32x3(0, 0, 0);
    (*rectificationBox).boxVec = FfxFloat32x3(0, 0, 0);
    (*rectificationBox).aabbMin = FfxFloat32x3(FSR2_FLT_MAX, FSR2_FLT_MAX, FSR2_FLT_MAX);
    (*rectificationBox).aabbMax = -FfxFloat32x3(FSR2_FLT_MAX, FSR2_FLT_MAX, FSR2_FLT_MAX);
}
#if FFX_HALF
fn RectificationBoxReset_RectificationBoxMin16(rectificationBox: ptr<function, RectificationBoxMin16>)
{
    (*rectificationBox).fBoxCenterWeight = FFX_MIN16_F(0);

    (*rectificationBox).boxCenter = FFX_MIN16_F3(0, 0, 0);
    (*rectificationBox).boxVec = FFX_MIN16_F3(0, 0, 0);
    (*rectificationBox).aabbMin = FFX_MIN16_F3(FFX_MIN16_F(FSR2_FP16_MAX), FFX_MIN16_F(FSR2_FP16_MAX), FFX_MIN16_F(FSR2_FP16_MAX));
    (*rectificationBox).aabbMax = -FFX_MIN16_F3(FFX_MIN16_F(FSR2_FP16_MAX), FFX_MIN16_F(FSR2_FP16_MAX), FFX_MIN16_F(FSR2_FP16_MAX));
}
#endif

fn RectificationBoxAddInitialSample_RectificationBox_f32x3_f32(rectificationBox: ptr<function, RectificationBox>, colorSample: FfxFloat32x3, fSampleWeight: FfxFloat32)
{
    (*rectificationBox).aabbMin = colorSample;
    (*rectificationBox).aabbMax = colorSample;

    let weightedSample: FfxFloat32x3 = colorSample * fSampleWeight;
    (*rectificationBox).boxCenter = weightedSample;
    (*rectificationBox).boxVec = colorSample * weightedSample;
    (*rectificationBox).fBoxCenterWeight = fSampleWeight;
}

fn RectificationBoxAddSample_b_RectificationBox_f32x3_f32(bInitialSample: FfxBoolean, rectificationBox: ptr<function, RectificationBox>, colorSample: FfxFloat32x3, fSampleWeight: FfxFloat32)
{
    if (bInitialSample) {
        RectificationBoxAddInitialSample_RectificationBox_f32x3_f32(rectificationBox, colorSample, fSampleWeight);
    } else {
        (*rectificationBox).aabbMin = ffxMin_f32x3_f32x3((*rectificationBox).aabbMin, colorSample);
        (*rectificationBox).aabbMax = ffxMax_f32x3_f32x3((*rectificationBox).aabbMax, colorSample);

        let weightedSample: FfxFloat32x3 = colorSample * fSampleWeight;
        (*rectificationBox).boxCenter += weightedSample;
        (*rectificationBox).boxVec += colorSample * weightedSample;
        (*rectificationBox).fBoxCenterWeight += fSampleWeight;
    }
}
#if FFX_HALF
fn RectificationBoxAddInitialSample_RectificationBoxMin16_f16x3_f16(rectificationBox: ptr<function, RectificationBoxMin16>, colorSample: FFX_MIN16_F3, fSampleWeight: FFX_MIN16_F)
{
    (*rectificationBox).aabbMin = colorSample;
    (*rectificationBox).aabbMax = colorSample;

    let weightedSample: FFX_MIN16_F3 = colorSample * fSampleWeight;
    (*rectificationBox).boxCenter = weightedSample;
    (*rectificationBox).boxVec = colorSample * weightedSample;
    (*rectificationBox).fBoxCenterWeight = fSampleWeight;
}

fn RectificationBoxAddSample_b_RectificationBoxMin16_f16x3_f16(bInitialSample: FfxBoolean, rectificationBox: ptr<function, RectificationBoxMin16>, colorSample: FFX_MIN16_F3, fSampleWeight: FFX_MIN16_F)
{
    if (bInitialSample) {
        RectificationBoxAddInitialSample_RectificationBoxMin16_f16x3_f16(rectificationBox, colorSample, fSampleWeight);
    } else {
        (*rectificationBox).aabbMin = ffxMin_f16x3_f16x3((*rectificationBox).aabbMin, colorSample);
        (*rectificationBox).aabbMax = ffxMax_f16x3_f16x3((*rectificationBox).aabbMax, colorSample);

        let weightedSample: FFX_MIN16_F3 = colorSample * fSampleWeight;
        (*rectificationBox).boxCenter += weightedSample;
        (*rectificationBox).boxVec += colorSample * weightedSample;
        (*rectificationBox).fBoxCenterWeight += fSampleWeight;
    }
}
#endif

fn RectificationBoxComputeVarianceBoxData_RectificationBox(rectificationBox: ptr<function, RectificationBox>)
{
    (*rectificationBox).fBoxCenterWeight = select(FfxFloat32(1.f), (*rectificationBox).fBoxCenterWeight, abs((*rectificationBox).fBoxCenterWeight) > FfxFloat32(FSR2_EPSILON));
    (*rectificationBox).boxCenter /= (*rectificationBox).fBoxCenterWeight;
    (*rectificationBox).boxVec /= (*rectificationBox).fBoxCenterWeight;
    let stdDev: FfxFloat32x3 = sqrt(abs((*rectificationBox).boxVec - (*rectificationBox).boxCenter * (*rectificationBox).boxCenter));
    (*rectificationBox).boxVec = stdDev;
}
#if FFX_HALF
fn RectificationBoxComputeVarianceBoxData_RectificationBoxMin16(rectificationBox: ptr<function, RectificationBoxMin16>)
{
    (*rectificationBox).fBoxCenterWeight = select(FFX_MIN16_F(1.f), (*rectificationBox).fBoxCenterWeight, abs((*rectificationBox).fBoxCenterWeight) > FFX_MIN16_F(FSR2_EPSILON));
    (*rectificationBox).boxCenter /= (*rectificationBox).fBoxCenterWeight;
    (*rectificationBox).boxVec /= (*rectificationBox).fBoxCenterWeight;
    let stdDev: FFX_MIN16_F3 = sqrt(abs((*rectificationBox).boxVec - (*rectificationBox).boxCenter * (*rectificationBox).boxCenter));
    (*rectificationBox).boxVec = stdDev;
}
#endif

fn SafeRcp3_f32x3(v: FfxFloat32x3) -> FfxFloat32x3
{
    return select(FfxFloat32x3(0, 0, 0), (FfxFloat32x3(1, 1, 1) / v), (all(v != FfxFloat32x3(0, 0, 0))));
}
#if FFX_HALF
fn SafeRcp3_f16x3(v: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    return select(FFX_MIN16_F3(0, 0, 0), (FFX_MIN16_F3(1, 1, 1) / v), (all(v != FFX_MIN16_F3(0, 0, 0))));
}
#endif

fn MinDividedByMax_f32_f32(v0: FfxFloat32, v1: FfxFloat32) -> FfxFloat32
{
    let m: FfxFloat32 = ffxMax_f32_f32(v0, v1);
    return select(0, ffxMin_f32_f32(v0, v1) / m, m != 0);
}

#if FFX_HALF
fn MinDividedByMax_f16_f16(v0: FFX_MIN16_F, v1: FFX_MIN16_F) -> FFX_MIN16_F
{
    let m: FFX_MIN16_F = ffxMax_f16_f16(v0, v1);
    return select(FFX_MIN16_F(0), ffxMin_f16_f16(v0, v1) / m, m != FFX_MIN16_F(0));
}
#endif

fn YCoCgToRGB_f32x3(fYCoCg: FfxFloat32x3) -> FfxFloat32x3
{
    var fRgb: FfxFloat32x3;

    fRgb = FfxFloat32x3(
        fYCoCg.x + fYCoCg.y - fYCoCg.z,
        fYCoCg.x + fYCoCg.z,
        fYCoCg.x - fYCoCg.y - fYCoCg.z);

    return fRgb;
}
#if FFX_HALF
fn YCoCgToRGB_f16x3(fYCoCg: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    var fRgb: FFX_MIN16_F3;

    fRgb = FFX_MIN16_F3(
        fYCoCg.x + fYCoCg.y - fYCoCg.z,
        fYCoCg.x + fYCoCg.z,
        fYCoCg.x - fYCoCg.y - fYCoCg.z);

    return fRgb;
}
#endif

fn RGBToYCoCg_f32x3(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    var fYCoCg: FfxFloat32x3;

    fYCoCg = FfxFloat32x3(
        0.25f * fRgb.r + 0.5f * fRgb.g + 0.25f * fRgb.b,
        0.5f * fRgb.r - 0.5f * fRgb.b,
        -0.25f * fRgb.r + 0.5f * fRgb.g - 0.25f * fRgb.b);

    return fYCoCg;
}
#if FFX_HALF
fn RGBToYCoCg_f16x3(fRgb: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    var fYCoCg: FFX_MIN16_F3;

    fYCoCg = FFX_MIN16_F3(
        0.25 * fRgb.r + 0.5 * fRgb.g + 0.25 * fRgb.b,
        0.5 * fRgb.r - 0.5 * fRgb.b,
        -0.25 * fRgb.r + 0.5 * fRgb.g - 0.25 * fRgb.b);

    return fYCoCg;
}
#endif

fn RGBToLuma_f32x3(fLinearRgb: FfxFloat32x3) -> FfxFloat32
{
    return dot(fLinearRgb, FfxFloat32x3(0.2126f, 0.7152f, 0.0722f));
}
#if FFX_HALF
fn RGBToLuma_f16x3(fLinearRgb: FFX_MIN16_F3) -> FFX_MIN16_F
{
    return dot(fLinearRgb, FFX_MIN16_F3(FfxFloat32x3(0.2126f, 0.7152f, 0.0722f)));
}
#endif

fn RGBToPerceivedLuma_f32x3(fLinearRgb: FfxFloat32x3) -> FfxFloat32
{
    let fLuminance: FfxFloat32 = RGBToLuma_f32x3(fLinearRgb);

    var fPercievedLuminance: FfxFloat32 = 0;
    if (fLuminance <= 216.0f / 24389.0f) {
        fPercievedLuminance = fLuminance * (24389.0f / 27.0f);
    }
    else {
        fPercievedLuminance = ffxPow_f32_f32(fLuminance, 1.0f / 3.0f) * 116.0f - 16.0f;
    }

    return fPercievedLuminance * 0.01f;
}
#if FFX_HALF
fn RGBToPerceivedLuma_f16x3(fLinearRgb: FFX_MIN16_F3) -> FFX_MIN16_F
{
    let fLuminance: FFX_MIN16_F = RGBToLuma_f16x3(fLinearRgb);

    var fPercievedLuminance: FFX_MIN16_F = FFX_MIN16_F(0);
    if (fLuminance <= FFX_MIN16_F(216.0f / 24389.0f)) {
        fPercievedLuminance = fLuminance * FFX_MIN16_F(24389.0f / 27.0f);
    }
    else {
        fPercievedLuminance = ffxPow_f16_f16(fLuminance, FFX_MIN16_F(1.0f / 3.0f)) * FFX_MIN16_F(116.0f) - FFX_MIN16_F(16.0f);
    }

    return fPercievedLuminance * FFX_MIN16_F(0.01f);
}
#endif

// WGSL: a scalar has no .xxx swizzle; the vector constructor splats it.
fn Tonemap_f32x3(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    return fRgb / FfxFloat32x3(ffxMax_f32_f32(ffxMax_f32_f32(0.f, fRgb.r), ffxMax_f32_f32(fRgb.g, fRgb.b)) + 1.f);
}

fn InverseTonemap_f32x3(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    return fRgb / FfxFloat32x3(ffxMax_f32_f32(FSR2_TONEMAP_EPSILON, 1.f - ffxMax_f32_f32(fRgb.r, ffxMax_f32_f32(fRgb.g, fRgb.b))));
}

#if FFX_HALF
fn Tonemap_f16x3(fRgb: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    return fRgb / FFX_MIN16_F3(ffxMax_f16_f16(ffxMax_f16_f16(FFX_MIN16_F(0.f), fRgb.r), ffxMax_f16_f16(fRgb.g, fRgb.b)) + FFX_MIN16_F(1.f));
}

fn InverseTonemap_f16x3(fRgb: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    return fRgb / FFX_MIN16_F3(ffxMax_f16_f16(FFX_MIN16_F(FSR2_TONEMAP_EPSILON), FFX_MIN16_F(1.f) - ffxMax_f16_f16(fRgb.r, ffxMax_f16_f16(fRgb.g, fRgb.b))));
}
#endif

fn ClampLoad_i32x2_i32x2_i32x2(iPxSample: FfxInt32x2, iPxOffset: FfxInt32x2, iTextureSize: FfxInt32x2) -> FfxInt32x2
{
    var result: FfxInt32x2 = iPxSample + iPxOffset;
    result.x = select(result.x, ffxMax_i32_i32(result.x, 0), (iPxOffset.x < 0));
    result.x = select(result.x, ffxMin_i32_i32(result.x, iTextureSize.x - 1), (iPxOffset.x > 0));
    result.y = select(result.y, ffxMax_i32_i32(result.y, 0), (iPxOffset.y < 0));
    result.y = select(result.y, ffxMin_i32_i32(result.y, iTextureSize.y - 1), (iPxOffset.y > 0));
    return result;

    // return ffxMed3(iPxSample + iPxOffset, FfxInt32x2(0, 0), iTextureSize - FfxInt32x2(1, 1));
}
#if FFX_HALF
fn ClampLoad_i16x2_i16x2_i16x2(iPxSample: FFX_MIN16_I2, iPxOffset: FFX_MIN16_I2, iTextureSize: FFX_MIN16_I2) -> FFX_MIN16_I2
{
    var result: FFX_MIN16_I2 = iPxSample + iPxOffset;
    result.x = select(result.x, ffxMax_i16_i16(result.x, FFX_MIN16_I(0)), (iPxOffset.x < 0));
    result.x = select(result.x, ffxMin_i16_i16(result.x, iTextureSize.x - FFX_MIN16_I(1)), (iPxOffset.x > 0));
    result.y = select(result.y, ffxMax_i16_i16(result.y, FFX_MIN16_I(0)), (iPxOffset.y < 0));
    result.y = select(result.y, ffxMin_i16_i16(result.y, iTextureSize.y - FFX_MIN16_I(1)), (iPxOffset.y > 0));
    return result;

    // return ffxMed3Half(iPxSample + iPxOffset, FFX_MIN16_I2(0, 0), iTextureSize - FFX_MIN16_I2(1, 1));
}
#endif

fn ClampUv(fUv: FfxFloat32x2, iTextureSize: FfxInt32x2, iResourceSize: FfxInt32x2) -> FfxFloat32x2
{
    let fSampleLocation: FfxFloat32x2 = fUv * FfxFloat32x2(iTextureSize);
    let fClampedLocation: FfxFloat32x2 = ffxMax_f32x2_f32x2(FfxFloat32x2(0.5f, 0.5f), ffxMin_f32x2_f32x2(fSampleLocation, FfxFloat32x2(iTextureSize) - FfxFloat32x2(0.5f, 0.5f)));
    let fClampedUv: FfxFloat32x2 = fClampedLocation / FfxFloat32x2(iResourceSize);

    return fClampedUv;
}

fn IsOnScreen_i32x2_i32x2(pos: FfxInt32x2, size: FfxInt32x2) -> FfxBoolean
{
    return all(FfxUInt32x2(pos) < FfxUInt32x2(size));
}
#if FFX_HALF
fn IsOnScreen_i16x2_i16x2(pos: FFX_MIN16_I2, size: FFX_MIN16_I2) -> FfxBoolean
{
    return all(FFX_MIN16_U2(pos) < FFX_MIN16_U2(size));
}
#endif

fn ComputeAutoExposureFromLavg_f32(Lavg_: FfxFloat32) -> FfxFloat32
{
    var Lavg: FfxFloat32 = Lavg_;
    Lavg = exp(Lavg);

    let S: FfxFloat32 = 100.0f; //ISO arithmetic speed
    let K: FfxFloat32 = 12.5f;
    let ExposureISO100: FfxFloat32 = log2((Lavg * S) / K);

    let q: FfxFloat32 = 0.65f;
    let Lmax: FfxFloat32 = (78.0f / (q * S)) * ffxPow_f32_f32(2.0f, ExposureISO100);

    return 1 / Lmax;
}
#if FFX_HALF
fn ComputeAutoExposureFromLavg_f16(Lavg_: FFX_MIN16_F) -> FFX_MIN16_F
{
    var Lavg: FFX_MIN16_F = Lavg_;
    Lavg = exp(Lavg);

    let S: FFX_MIN16_F = FFX_MIN16_F(100.0f); //ISO arithmetic speed
    let K: FFX_MIN16_F = FFX_MIN16_F(12.5f);
    let ExposureISO100: FFX_MIN16_F = log2((Lavg * S) / K);

    let q: FFX_MIN16_F = FFX_MIN16_F(0.65f);
    let Lmax: FFX_MIN16_F = (FFX_MIN16_F(78.0f) / (q * S)) * ffxPow_f16_f16(FFX_MIN16_F(2.0f), ExposureISO100);

    return FFX_MIN16_F(1) / Lmax;
}
#endif

fn ComputeHrPosFromLrPos_i32x2(iPxLrPos: FfxInt32x2) -> FfxInt32x2
{
    let fSrcJitteredPos: FfxFloat32x2 = FfxFloat32x2(iPxLrPos) + 0.5f - Jitter();
    let fLrPosInHr: FfxFloat32x2 = (fSrcJitteredPos / FfxFloat32x2(RenderSize())) * FfxFloat32x2(DisplaySize());
    let iPxHrPos: FfxInt32x2 = FfxInt32x2(floor(fLrPosInHr));
    return iPxHrPos;
}
#if FFX_HALF
fn ComputeHrPosFromLrPos_i16x2(iPxLrPos: FFX_MIN16_I2) -> FFX_MIN16_I2
{
    let fSrcJitteredPos: FFX_MIN16_F2 = FFX_MIN16_F2(iPxLrPos) + FFX_MIN16_F(0.5f) - FFX_MIN16_F2(Jitter());
    let fLrPosInHr: FFX_MIN16_F2 = (fSrcJitteredPos / FFX_MIN16_F2(RenderSize())) * FFX_MIN16_F2(DisplaySize());
    let iPxHrPos: FFX_MIN16_I2 = FFX_MIN16_I2(floor(fLrPosInHr));
    return iPxHrPos;
}
#endif

fn ComputeNdc(fPxPos: FfxFloat32x2, iSize: FfxInt32x2) -> FfxFloat32x2
{
    return fPxPos / FfxFloat32x2(iSize) * FfxFloat32x2(2.0f, -2.0f) + FfxFloat32x2(-1.0f, 1.0f);
}

fn GetViewSpaceDepth(fDeviceDepth: FfxFloat32) -> FfxFloat32
{
    let fDeviceToViewDepth: FfxFloat32x4 = DeviceToViewSpaceTransformFactors();

    // fDeviceToViewDepth details found in ffx_fsr2.cpp
    return (fDeviceToViewDepth[1] / (fDeviceDepth - fDeviceToViewDepth[0]));
}

fn GetViewSpaceDepthInMeters(fDeviceDepth: FfxFloat32) -> FfxFloat32
{
    return GetViewSpaceDepth(fDeviceDepth) * ViewSpaceToMetersFactor();
}

fn GetViewSpacePosition(iViewportPos: FfxInt32x2, iViewportSize: FfxInt32x2, fDeviceDepth: FfxFloat32) -> FfxFloat32x3
{
    let fDeviceToViewDepth: FfxFloat32x4 = DeviceToViewSpaceTransformFactors();

    let Z: FfxFloat32 = GetViewSpaceDepth(fDeviceDepth);

    let fNdcPos: FfxFloat32x2 = ComputeNdc(FfxFloat32x2(iViewportPos), iViewportSize);
    let X: FfxFloat32 = fDeviceToViewDepth[2] * fNdcPos.x * Z;
    let Y: FfxFloat32 = fDeviceToViewDepth[3] * fNdcPos.y * Z;

    return FfxFloat32x3(X, Y, Z);
}

fn GetViewSpacePositionInMeters(iViewportPos: FfxInt32x2, iViewportSize: FfxInt32x2, fDeviceDepth: FfxFloat32) -> FfxFloat32x3
{
    return GetViewSpacePosition(iViewportPos, iViewportSize, fDeviceDepth) * ViewSpaceToMetersFactor();
}

fn GetMaxDistanceInMeters() -> FfxFloat32
{
#if FFX_FSR2_OPTION_INVERTED_DEPTH
    return GetViewSpaceDepth(0.0f) * ViewSpaceToMetersFactor();
#else
    return GetViewSpaceDepth(1.0f) * ViewSpaceToMetersFactor();
#endif
}

fn PrepareRgb(fRgb_: FfxFloat32x3, fExposure: FfxFloat32, fPreExposure: FfxFloat32) -> FfxFloat32x3
{
    var fRgb: FfxFloat32x3 = fRgb_;
    fRgb /= fPreExposure;
    fRgb *= fExposure;

    fRgb = clamp(fRgb, FfxFloat32x3(0.0f), FfxFloat32x3(FSR2_FP16_MAX));

    return fRgb;
}

fn UnprepareRgb(fRgb_: FfxFloat32x3, fExposure: FfxFloat32) -> FfxFloat32x3
{
    var fRgb: FfxFloat32x3 = fRgb_;
    fRgb /= fExposure;
    fRgb *= PreExposure();

    return fRgb;
}

// PrepareRgbPaired, UnprepareRgbPaired: Xbox only (__XBOX_SCARLETT), never
// compiled here.


struct BilinearSamplingData
{
    iOffsets: array<FfxInt32x2, 4>,
    fWeights: array<FfxFloat32, 4>,
    iBasePos: FfxInt32x2,
}

fn GetBilinearSamplingData(fUv: FfxFloat32x2, iSize: FfxInt32x2) -> BilinearSamplingData
{
    var data: BilinearSamplingData;

    let fPxSample: FfxFloat32x2 = (fUv * FfxFloat32x2(iSize)) - FfxFloat32x2(0.5f, 0.5f);
    data.iBasePos = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FfxFloat32x2 = ffxFract_f32x2(fPxSample);

    data.iOffsets[0] = FfxInt32x2(0, 0);
    data.iOffsets[1] = FfxInt32x2(1, 0);
    data.iOffsets[2] = FfxInt32x2(0, 1);
    data.iOffsets[3] = FfxInt32x2(1, 1);

    data.fWeights[0] = (1 - fPxFrac.x) * (1 - fPxFrac.y);
    data.fWeights[1] = (fPxFrac.x) * (1 - fPxFrac.y);
    data.fWeights[2] = (1 - fPxFrac.x) * (fPxFrac.y);
    data.fWeights[3] = (fPxFrac.x) * (fPxFrac.y);

    return data;
}

struct PlaneData
{
    fNormal: FfxFloat32x3,
    fDistanceFromOrigin: FfxFloat32,
}

fn GetPlaneFromPoints(fP0: FfxFloat32x3, fP1: FfxFloat32x3, fP2: FfxFloat32x3) -> PlaneData
{
    var plane: PlaneData;

    let v0: FfxFloat32x3 = fP0 - fP1;
    let v1: FfxFloat32x3 = fP0 - fP2;
    plane.fNormal = normalize(cross(v0, v1));
    plane.fDistanceFromOrigin = -dot(fP0, plane.fNormal);

    return plane;
}

fn PointToPlaneDistance(plane: PlaneData, fPoint: FfxFloat32x3) -> FfxFloat32
{
    return abs(dot(plane.fNormal, fPoint) + plane.fDistanceFromOrigin);
}

#endif // #if defined(FFX_GPU)

#endif //!defined(FFX_FSR2_COMMON_H)
