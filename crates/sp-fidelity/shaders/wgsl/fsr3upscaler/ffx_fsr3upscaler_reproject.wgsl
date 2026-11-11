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
#ifndef FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE
#define FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE 0 // Reference
#endif

fn WrapHistory(iPxSample: FfxInt32x2) -> FfxFloat32x4
{
    return LoadHistory(FfxUInt32x2(iPxSample));
}

// Expanded upstream DeclareCustomFetchBicubicSamples macro.
fn FetchHistorySamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBicubicSamples
{
    var Samples: FetchedBicubicSamples;
    Samples.fColor00 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, -1), iTextureSize)));
    Samples.fColor10 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, -1), iTextureSize)));
    Samples.fColor20 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, -1), iTextureSize)));
    Samples.fColor30 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, -1), iTextureSize)));
    Samples.fColor01 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 0), iTextureSize)));
    Samples.fColor11 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor21 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor31 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 0), iTextureSize)));
    Samples.fColor02 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 1), iTextureSize)));
    Samples.fColor12 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor22 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    Samples.fColor32 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 1), iTextureSize)));
    Samples.fColor03 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 2), iTextureSize)));
    Samples.fColor13 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 2), iTextureSize)));
    Samples.fColor23 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 2), iTextureSize)));
    Samples.fColor33 = FfxFloat32x4(WrapHistory(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 2), iTextureSize)));
    return Samples;
}
fn HistorySample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FfxFloat32x4
{
    var fPxSample: FfxFloat32x2 = fUvSample * FfxFloat32x2(iTextureSize) - FfxFloat32x2(0.5f);
    let fPxFrac: FfxFloat32x2 = FfxFloat32x2(fract(fPxSample));
    fPxSample.x = max(0.0f, min(FfxFloat32(iTextureSize.x - 1), fPxSample.x));
    fPxSample.y = max(0.0f, min(FfxFloat32(iTextureSize.y - 1), fPxSample.y));
    let iPxSample = FfxInt32x2(floor(fPxSample));
#if FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE == 0
    let fColorXY = FfxFloat32x4(Lanczos2_FetchedBicubicSamples_f32x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE == 1
    let fColorXY = FfxFloat32x4(Lanczos2LUT_FetchedBicubicSamples_f32x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE == 2
    let fColorXY = FfxFloat32x4(Lanczos2Approx_FetchedBicubicSamples_f32x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#endif
    return fColorXY;
}


#if FFX_HALF
fn WrapHistory16(iPxSample: FfxInt32x2) -> FFX_MIN16_F4
{
    return FFX_MIN16_F4(LoadHistory(FfxUInt32x2(iPxSample)));
}

// Expanded upstream DeclareCustomFetchBicubicSamplesMin16 macro.
fn FetchHistorySamples16(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBicubicSamplesMin16
{
    var Samples: FetchedBicubicSamplesMin16;
    Samples.fColor00 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, -1), iTextureSize)));
    Samples.fColor10 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, -1), iTextureSize)));
    Samples.fColor20 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, -1), iTextureSize)));
    Samples.fColor30 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, -1), iTextureSize)));
    Samples.fColor01 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 0), iTextureSize)));
    Samples.fColor11 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor21 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor31 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 0), iTextureSize)));
    Samples.fColor02 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 1), iTextureSize)));
    Samples.fColor12 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor22 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    Samples.fColor32 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 1), iTextureSize)));
    Samples.fColor03 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 2), iTextureSize)));
    Samples.fColor13 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 2), iTextureSize)));
    Samples.fColor23 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 2), iTextureSize)));
    Samples.fColor33 = FFX_MIN16_F4(WrapHistory16(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 2), iTextureSize)));
    return Samples;
}
fn HistorySample16(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FFX_MIN16_F4
{
    var fPxSample: FfxFloat32x2 = fUvSample * FfxFloat32x2(iTextureSize) - FfxFloat32x2(0.5f);
    let fPxFrac: FFX_MIN16_F2 = FFX_MIN16_F2(fract(fPxSample));
    fPxSample.x = max(0.0f, min(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = max(0.0f, min(FfxFloat32(iTextureSize.y), fPxSample.y));
    let iPxSample = FfxInt32x2(floor(fPxSample));
#if FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE == 0
    let fColorXY = FFX_MIN16_F4(Lanczos2_FetchedBicubicSamplesMin16_f16x2(FetchHistorySamples16(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE == 1
    let fColorXY = FFX_MIN16_F4(Lanczos2LUT_FetchedBicubicSamplesMin16_f16x2(FetchHistorySamples16(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE == 2
    let fColorXY = FFX_MIN16_F4(Lanczos2Approx_FetchedBicubicSamplesMin16_f16x2(FetchHistorySamples16(iPxSample, iTextureSize), fPxFrac));
#endif
    return fColorXY;
}

#endif

fn GetMotionVector(iPxHrPos: FfxInt32x2, fHrUv: FfxFloat32x2) -> FfxFloat32x2
{
#if FFX_FSR3UPSCALER_OPTION_LOW_RESOLUTION_MOTION_VECTORS
    var fDilatedMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(FFX_MIN16_I2(fHrUv * FfxFloat32x2(RenderSize()))));
#else
    var fDilatedMotionVector: FfxFloat32x2 = LoadInputMotionVector(FfxUInt32x2(iPxHrPos));
#endif

    return fDilatedMotionVector;
}

fn ComputeReprojectedUVs(params: ptr<function, AccumulationPassCommonParams>)
{
    (*params).fReprojectedHrUv = (*params).fHrUv + (*params).fMotionVector;

    (*params).bIsExistingSample = IsUvInside((*params).fReprojectedHrUv);
}

fn ReprojectHistoryColor(params: AccumulationPassCommonParams, data: ptr<function, AccumulationPassData>)
{
#if FFX_HALF && FFX_FSR3UPSCALER_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF
    var fReprojectedHistory: FfxFloat32x4 = FfxFloat32x4(HistorySample16(params.fReprojectedHrUv, UpscaleSize()));
#else
    var fReprojectedHistory: FfxFloat32x4 = HistorySample(params.fReprojectedHrUv, PreviousFrameUpscaleSize());
#endif

    (*data).fHistoryColor = fReprojectedHistory.rgb;
    (*data).fHistoryColor *= DeltaPreExposure();
    (*data).fHistoryColor *= Exposure();

    (*data).fHistoryColor = RGBToYCoCg_f32x3((*data).fHistoryColor);

    (*data).fLock = fReprojectedHistory.w;
}
