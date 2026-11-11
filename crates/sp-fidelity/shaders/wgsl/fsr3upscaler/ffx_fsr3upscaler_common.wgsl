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

// WGSL port of ffx_fsr3upscaler_common.h. Overloads retain the existing
// parameter-type suffix convention; inout parameters use function pointers.
// WGSL requires explicit integer-to-float conversions and vector splats.

#if !defined(FFX_FSR3UPSCALER_COMMON_H)
#define FFX_FSR3UPSCALER_COMMON_H
#if defined(FFX_GPU)
const FSR3UPSCALER_FP16_MIN: FfxFloat32 = 6.10e-05f;
const FSR3UPSCALER_FP16_MAX: FfxFloat32 = 65504.0f;
const FSR3UPSCALER_EPSILON: FfxFloat32 = FSR3UPSCALER_FP16_MIN;
const FSR3UPSCALER_TONEMAP_EPSILON: FfxFloat32 = FSR3UPSCALER_FP16_MIN;
const FSR3UPSCALER_FP32_MAX: FfxFloat32 = 3.402823466e+38f;
const FSR3UPSCALER_FP32_MIN: FfxFloat32 = 1.175494351e-38f;

// Reconstructed depth usage
const fReconstructedDepthBilinearWeightThreshold: FfxFloat32 = FSR3UPSCALER_EPSILON * 10;


// Accumulation
const fUpsampleLanczosWeightScale: FfxFloat32 = 1.0f / 16.0f;
const fAverageLanczosWeightPerFrame: FfxFloat32 = 0.74f * fUpsampleLanczosWeightScale; // Average lanczos weight for jitter accumulated samples
const fAccumulationMaxOnMotion: FfxFloat32 = 3.0f * fUpsampleLanczosWeightScale;

#define SHADING_CHANGE_SET_SIZE 5
const iShadingChangeMipStart: FfxInt32 = 0;
const fShadingChangeSamplePow: FfxFloat32 = 1.0f / 1.0f;


const fLockThreshold: FfxFloat32 = 1.0f;
const fLockMax: FfxFloat32 = 2.0f;

const REACTIVE: FfxInt32 = 0;
const DISOCCLUSION: FfxInt32 = 1;
const SHADING_CHANGE: FfxInt32 = 2;
const ACCUMULAION: FfxInt32 = 3;

const FRAME_INFO_EXPOSURE: FfxInt32 = 0;
const FRAME_INFO_LOG_LUMA: FfxInt32 = 1;
const FRAME_INFO_SCENE_AVERAGE_LUMA: FfxInt32 = 2;


fn ReconstructedDepthMvPxThreshold(fNearestDepthInMeters: FfxFloat32) -> FfxFloat32
{
    return mix(0.25f, 0.75f, clamp(fNearestDepthInMeters / 100.0f, 0.0f, 1.0f));
}
fn TonemapFirstFrame() -> FfxBoolean
{
    let bEnabled: FfxBoolean = true;
    return FrameIndex() == 0 && bEnabled;
}
fn AverageLanczosWeightPerFrame() -> FfxFloat32 { return 0.74f; }
fn ShadingChangeRenderSize() -> FfxInt32x2 { return FfxInt32x2(FfxFloat32x2(RenderSize()) * 0.5f); }
fn ShadingChangeMaxRenderSize() -> FfxInt32x2 { return FfxInt32x2(FfxFloat32x2(MaxRenderSize()) * 0.5f); }
fn PreviousFrameShadingChangeRenderSize() -> FfxInt32x2 { return FfxInt32x2(FfxFloat32x2(PreviousFrameRenderSize()) * 0.5f); }
#if defined(FSR3UPSCALER_BIND_SRV_FRAME_INFO)
fn SceneAverageLuma() -> FfxFloat32 { return FrameInfo()[FRAME_INFO_SCENE_AVERAGE_LUMA]; }
#endif
const resetAutoExposureAverageSmoothing: FfxFloat32 = 1e4f;
struct AccumulationPassCommonParams
{
    iPxHrPos: FfxInt32x2,
    fHrUv: FfxFloat32x2,
    fLrUvJittered: FfxFloat32x2,
    fLrUv_HwSampler: FfxFloat32x2,
    fMotionVector: FfxFloat32x2,
    fReprojectedHrUv: FfxFloat32x2,
    f4KVelocity: FfxFloat32,
    fDisocclusion: FfxFloat32,
    fReactiveMask: FfxFloat32,
    fShadingChange: FfxFloat32,
    fAccumulation: FfxFloat32,
    fLumaInstabilityFactor: FfxFloat32,
    fFarthestDepthInMeters: FfxFloat32,

    bIsExistingSample: FfxBoolean,
    bIsNewSample: FfxBoolean,
}
fn Get4KVelocity(fMotionVector: FfxFloat32x2) -> FfxFloat32
{
    return length(fMotionVector * FfxFloat32x2(3840.0f, 2160.0f));
}
struct RectificationBox
{
    boxCenter: FfxFloat32x3,
    boxVec: FfxFloat32x3,
    aabbMin: FfxFloat32x3,
    aabbMax: FfxFloat32x3,
    fBoxCenterWeight: FfxFloat32,
}
struct AccumulationPassData
{
    clippingBox: RectificationBox,
    fUpsampledColor: FfxFloat32x3,
    fUpsampledWeight: FfxFloat32,
    fHistoryColor: FfxFloat32x3,
    fHistoryWeight: FfxFloat32,
    fLock: FfxFloat32,
    fLockContributionThisFrame: FfxFloat32,
}

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

fn RectificationBoxComputeVarianceBoxData_RectificationBox(rectificationBox: ptr<function, RectificationBox>)
{
    (*rectificationBox).fBoxCenterWeight = select(FfxFloat32(1.f), (*rectificationBox).fBoxCenterWeight, abs((*rectificationBox).fBoxCenterWeight) > FfxFloat32(FSR3UPSCALER_FP32_MIN));
    (*rectificationBox).boxCenter /= (*rectificationBox).fBoxCenterWeight;
    (*rectificationBox).boxVec /= (*rectificationBox).fBoxCenterWeight;
    let stdDev: FfxFloat32x3 = sqrt(abs((*rectificationBox).boxVec - (*rectificationBox).boxCenter * (*rectificationBox).boxCenter));
    (*rectificationBox).boxVec = stdDev;
}

fn SafeRcp3_f32x3(v: FfxFloat32x3) -> FfxFloat32x3
{
    return select(FfxFloat32x3(0, 0, 0), (FfxFloat32x3(1, 1, 1) / v), (all(v != FfxFloat32x3(0, 0, 0))));
}

fn MinDividedByMax_f32_f32(v0: FfxFloat32, v1: FfxFloat32) -> FfxFloat32
{
    let m: FfxFloat32 = ffxMax_f32_f32(v0, v1);
    return select(0, ffxMin_f32_f32(v0, v1) / m, m != 0);
}

fn YCoCgToRGB_f32x3(fYCoCg: FfxFloat32x3) -> FfxFloat32x3
{
    var fRgb: FfxFloat32x3;

    fRgb = FfxFloat32x3(
        fYCoCg.x + fYCoCg.y - fYCoCg.z,
        fYCoCg.x + fYCoCg.z,
        fYCoCg.x - fYCoCg.y - fYCoCg.z);

    return fRgb;
}

fn RGBToYCoCg_f32x3(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    var fYCoCg: FfxFloat32x3;

    fYCoCg = FfxFloat32x3(
        0.25f * fRgb.r + 0.5f * fRgb.g + 0.25f * fRgb.b,
        0.5f * fRgb.r - 0.5f * fRgb.b,
        -0.25f * fRgb.r + 0.5f * fRgb.g - 0.25f * fRgb.b);

    return fYCoCg;
}

fn RGBToLuma_f32x3(fLinearRgb: FfxFloat32x3) -> FfxFloat32
{
    return dot(fLinearRgb, FfxFloat32x3(0.2126f, 0.7152f, 0.0722f));
}

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

fn Tonemap_f32x3(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    return fRgb / FfxFloat32x3(ffxMax_f32_f32(ffxMax_f32_f32(0.f, fRgb.r), ffxMax_f32_f32(fRgb.g, fRgb.b)) + 1.f);
}

fn InverseTonemap_f32x3(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    return fRgb / FfxFloat32x3(ffxMax_f32_f32(FSR3UPSCALER_TONEMAP_EPSILON, 1.f - ffxMax_f32_f32(fRgb.r, ffxMax_f32_f32(fRgb.g, fRgb.b))));
}

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

fn ComputeHrPosFromLrPos_i32x2(iPxLrPos: FfxInt32x2) -> FfxInt32x2
{
    let fSrcJitteredPos: FfxFloat32x2 = FfxFloat32x2(iPxLrPos) + 0.5f - Jitter();
    let fLrPosInHr: FfxFloat32x2 = (fSrcJitteredPos / FfxFloat32x2(RenderSize())) * FfxFloat32x2(UpscaleSize());
    let iPxHrPos: FfxInt32x2 = FfxInt32x2(floor(fLrPosInHr));
    return iPxHrPos;
}

fn ComputeNdc(fPxPos: FfxFloat32x2, iSize: FfxInt32x2) -> FfxFloat32x2
{
    return fPxPos / FfxFloat32x2(iSize) * FfxFloat32x2(2.0f, -2.0f) + FfxFloat32x2(-1.0f, 1.0f);
}

fn GetViewSpaceDepth(fDeviceDepth: FfxFloat32) -> FfxFloat32
{
    let fDeviceToViewDepth: FfxFloat32x4 = DeviceToViewSpaceTransformFactors();

    // fDeviceToViewDepth details found in ffx_fsr3upscaler.cpp
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
#if FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH
    return GetViewSpaceDepth(0.0f) * ViewSpaceToMetersFactor();
#else
    return GetViewSpaceDepth(1.0f) * ViewSpaceToMetersFactor();
#endif
}

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

fn MinDividedByMax_f32_f32_f32(v0: FfxFloat32, v1: FfxFloat32, fOnZeroReturnValue: FfxFloat32) -> FfxFloat32
{
    let m: FfxFloat32 = max(v0, v1);
    return select(fOnZeroReturnValue, min(v0, v1) / m, m != 0);
}
fn IsUvInside(fUv: FfxFloat32x2) -> FfxBoolean
{
    return (fUv.x >= 0.0f && fUv.x <= 1.0f) && (fUv.y >= 0.0f && fUv.y <= 1.0f);
}
fn ClampLoad_i32x2_i32x2_i32x2(iPxSample: FfxInt32x2, iPxOffset: FfxInt32x2, iTextureSize: FfxInt32x2) -> FfxInt32x2
{
    var result: FfxInt32x2 = iPxSample + iPxOffset;
    result.x = max(0, min(result.x, iTextureSize.x - 1));
    result.y = max(0, min(result.y, iTextureSize.y - 1));
    return result;
}
#endif // FFX_GPU
#endif // FFX_FSR3UPSCALER_COMMON_H
