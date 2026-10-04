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

// WGSL port of ffx_fsr2_reproject.h. Overloads carry parameter-type suffixes
// (see ffx_core.wgsl); FFX_PARAMETER_OUT parameters are function pointers.
// HLSL's implicit int-to-uint and float-to-half conversions are written out.
//
// The DeclareCustom* invocations are expanded from the templates quoted in
// ffx_fsr2_sample.wgsl, the macro argument named in a comment above each
// expansion; their +0 offsets are written 0 (WGSL has no unary plus).
// FFX_FSR2_GET_LANCZOS_SAMPLER1D(FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE)
// names FFX_FSR2_SAMPLER_1D_<type>: Lanczos2 (0), Lanczos2LUT (1) or
// Lanczos2Approx (2), selected with #if as ffx_fsr2_sample.wgsl describes.

#ifndef FFX_FSR2_REPROJECT_H
#define FFX_FSR2_REPROJECT_H

#ifndef FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE
#define FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE 0 // Reference
#endif

fn WrapHistory_i32x2(iPxSample: FfxInt32x2) -> FfxFloat32x4
{
    return LoadHistory(FfxUInt32x2(iPxSample));
}

#if FFX_HALF
fn WrapHistory_i16x2(iPxSample: FFX_MIN16_I2) -> FFX_MIN16_F4
{
    return FFX_MIN16_F4(LoadHistory(FfxUInt32x2(iPxSample)));
}
#endif


#if FFX_FSR2_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF && FFX_HALF
// DeclareCustomFetchBicubicSamplesMin16(FetchHistorySamples, WrapHistory)
fn FetchHistorySamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBicubicSamplesMin16
{
    var Samples: FetchedBicubicSamplesMin16;

    Samples.fColor00 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, -1), iTextureSize)));
    Samples.fColor10 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, -1), iTextureSize)));
    Samples.fColor20 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, -1), iTextureSize)));
    Samples.fColor30 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, -1), iTextureSize)));

    Samples.fColor01 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 0), iTextureSize)));
    Samples.fColor11 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor21 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor31 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 0), iTextureSize)));

    Samples.fColor02 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 1), iTextureSize)));
    Samples.fColor12 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor22 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    Samples.fColor32 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 1), iTextureSize)));

    Samples.fColor03 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 2), iTextureSize)));
    Samples.fColor13 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 2), iTextureSize)));
    Samples.fColor23 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 2), iTextureSize)));
    Samples.fColor33 = FFX_MIN16_F4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 2), iTextureSize)));

    return Samples;
}
// DeclareCustomTextureSampleMin16(HistorySample, FFX_FSR2_GET_LANCZOS_SAMPLER1D(FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE), FetchHistorySamples)
fn HistorySample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FFX_MIN16_F4
{
    var fPxSample: FfxFloat32x2 = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
    /* Clamp base coords */
    fPxSample.x = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.y), fPxSample.y));
    /* */
    let iPxSample: FfxInt32x2 = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FFX_MIN16_F2 = FFX_MIN16_F2(ffxFract_f32x2(fPxSample));
#if FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 0
    let fColorXY: FFX_MIN16_F4 = FFX_MIN16_F4(Lanczos2_FetchedBicubicSamplesMin16_f16x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 1
    let fColorXY: FFX_MIN16_F4 = FFX_MIN16_F4(Lanczos2LUT_FetchedBicubicSamplesMin16_f16x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#else
    let fColorXY: FFX_MIN16_F4 = FFX_MIN16_F4(Lanczos2Approx_FetchedBicubicSamplesMin16_f16x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#endif
    return fColorXY;
}
#else
// DeclareCustomFetchBicubicSamples(FetchHistorySamples, WrapHistory)
fn FetchHistorySamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBicubicSamples
{
    var Samples: FetchedBicubicSamples;

    Samples.fColor00 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, -1), iTextureSize)));
    Samples.fColor10 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, -1), iTextureSize)));
    Samples.fColor20 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, -1), iTextureSize)));
    Samples.fColor30 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, -1), iTextureSize)));

    Samples.fColor01 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 0), iTextureSize)));
    Samples.fColor11 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor21 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor31 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 0), iTextureSize)));

    Samples.fColor02 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 1), iTextureSize)));
    Samples.fColor12 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor22 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    Samples.fColor32 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 1), iTextureSize)));

    Samples.fColor03 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 2), iTextureSize)));
    Samples.fColor13 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 2), iTextureSize)));
    Samples.fColor23 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 2), iTextureSize)));
    Samples.fColor33 = FfxFloat32x4(WrapHistory_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 2), iTextureSize)));

    return Samples;
}
// DeclareCustomTextureSample(HistorySample, FFX_FSR2_GET_LANCZOS_SAMPLER1D(FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE), FetchHistorySamples)
fn HistorySample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FfxFloat32x4
{
    var fPxSample: FfxFloat32x2 = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
    /* Clamp base coords */
    fPxSample.x = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.y), fPxSample.y));
    /* */
    let iPxSample: FfxInt32x2 = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FfxFloat32x2 = ffxFract_f32x2(fPxSample);
#if FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 0
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Lanczos2_FetchedBicubicSamples_f32x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 1
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Lanczos2LUT_FetchedBicubicSamples_f32x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#else
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Lanczos2Approx_FetchedBicubicSamples_f32x2(FetchHistorySamples(iPxSample, iTextureSize), fPxFrac));
#endif
    return fColorXY;
}
#endif

fn WrapLockStatus_i32x2(iPxSample: FfxInt32x2) -> FfxFloat32x4
{
    let fSample: FfxFloat32x4 = FfxFloat32x4(LoadLockStatus(FfxUInt32x2(iPxSample)), 0.0f, 0.0f);
    return fSample;
}

#if FFX_HALF
fn WrapLockStatus_i16x2(iPxSample: FFX_MIN16_I2) -> FFX_MIN16_F4
{
    let fSample: FFX_MIN16_F4 = FFX_MIN16_F4(FFX_MIN16_F2(LoadLockStatus(FfxUInt32x2(iPxSample))), FFX_MIN16_F(0.0), FFX_MIN16_F(0.0));

    return fSample;
}
#endif

#if 1
#if FFX_FSR2_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF && FFX_HALF
// DeclareCustomFetchBilinearSamplesMin16(FetchLockStatusSamples, WrapLockStatus)
fn FetchLockStatusSamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBilinearSamplesMin16
{
    var Samples: FetchedBilinearSamplesMin16;
    Samples.fColor00 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor10 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor01 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor11 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    return Samples;
}
// DeclareCustomTextureSampleMin16(LockStatusSample, Bilinear, FetchLockStatusSamples)
fn LockStatusSample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FFX_MIN16_F4
{
    var fPxSample: FfxFloat32x2 = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
    /* Clamp base coords */
    fPxSample.x = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.y), fPxSample.y));
    /* */
    let iPxSample: FfxInt32x2 = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FFX_MIN16_F2 = FFX_MIN16_F2(ffxFract_f32x2(fPxSample));
    let fColorXY: FFX_MIN16_F4 = FFX_MIN16_F4(Bilinear_FetchedBilinearSamplesMin16_f16x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
    return fColorXY;
}
#else
// DeclareCustomFetchBilinearSamples(FetchLockStatusSamples, WrapLockStatus)
fn FetchLockStatusSamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBilinearSamples
{
    var Samples: FetchedBilinearSamples;
    Samples.fColor00 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor10 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor01 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor11 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    return Samples;
}
// DeclareCustomTextureSample(LockStatusSample, Bilinear, FetchLockStatusSamples)
fn LockStatusSample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FfxFloat32x4
{
    var fPxSample: FfxFloat32x2 = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
    /* Clamp base coords */
    fPxSample.x = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.y), fPxSample.y));
    /* */
    let iPxSample: FfxInt32x2 = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FfxFloat32x2 = ffxFract_f32x2(fPxSample);
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Bilinear_FetchedBilinearSamples_f32x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
    return fColorXY;
}
#endif
#else
#if FFX_FSR2_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF && FFX_HALF
// DeclareCustomFetchBicubicSamplesMin16(FetchLockStatusSamples, WrapLockStatus)
fn FetchLockStatusSamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBicubicSamplesMin16
{
    var Samples: FetchedBicubicSamplesMin16;

    Samples.fColor00 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, -1), iTextureSize)));
    Samples.fColor10 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, -1), iTextureSize)));
    Samples.fColor20 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, -1), iTextureSize)));
    Samples.fColor30 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, -1), iTextureSize)));

    Samples.fColor01 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 0), iTextureSize)));
    Samples.fColor11 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor21 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor31 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 0), iTextureSize)));

    Samples.fColor02 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 1), iTextureSize)));
    Samples.fColor12 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor22 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    Samples.fColor32 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 1), iTextureSize)));

    Samples.fColor03 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 2), iTextureSize)));
    Samples.fColor13 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 2), iTextureSize)));
    Samples.fColor23 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 2), iTextureSize)));
    Samples.fColor33 = FFX_MIN16_F4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 2), iTextureSize)));

    return Samples;
}
// DeclareCustomTextureSampleMin16(LockStatusSample, FFX_FSR2_GET_LANCZOS_SAMPLER1D(FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE), FetchLockStatusSamples)
fn LockStatusSample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FFX_MIN16_F4
{
    var fPxSample: FfxFloat32x2 = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
    /* Clamp base coords */
    fPxSample.x = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.y), fPxSample.y));
    /* */
    let iPxSample: FfxInt32x2 = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FFX_MIN16_F2 = FFX_MIN16_F2(ffxFract_f32x2(fPxSample));
#if FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 0
    let fColorXY: FFX_MIN16_F4 = FFX_MIN16_F4(Lanczos2_FetchedBicubicSamplesMin16_f16x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 1
    let fColorXY: FFX_MIN16_F4 = FFX_MIN16_F4(Lanczos2LUT_FetchedBicubicSamplesMin16_f16x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
#else
    let fColorXY: FFX_MIN16_F4 = FFX_MIN16_F4(Lanczos2Approx_FetchedBicubicSamplesMin16_f16x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
#endif
    return fColorXY;
}
#else
// DeclareCustomFetchBicubicSamples(FetchLockStatusSamples, WrapLockStatus)
fn FetchLockStatusSamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBicubicSamples
{
    var Samples: FetchedBicubicSamples;

    Samples.fColor00 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, -1), iTextureSize)));
    Samples.fColor10 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, -1), iTextureSize)));
    Samples.fColor20 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, -1), iTextureSize)));
    Samples.fColor30 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, -1), iTextureSize)));

    Samples.fColor01 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 0), iTextureSize)));
    Samples.fColor11 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor21 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor31 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 0), iTextureSize)));

    Samples.fColor02 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 1), iTextureSize)));
    Samples.fColor12 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor22 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    Samples.fColor32 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 1), iTextureSize)));

    Samples.fColor03 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 2), iTextureSize)));
    Samples.fColor13 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 2), iTextureSize)));
    Samples.fColor23 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 2), iTextureSize)));
    Samples.fColor33 = FfxFloat32x4(WrapLockStatus_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 2), iTextureSize)));

    return Samples;
}
// DeclareCustomTextureSample(LockStatusSample, FFX_FSR2_GET_LANCZOS_SAMPLER1D(FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE), FetchLockStatusSamples)
fn LockStatusSample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FfxFloat32x4
{
    var fPxSample: FfxFloat32x2 = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
    /* Clamp base coords */
    fPxSample.x = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.y), fPxSample.y));
    /* */
    let iPxSample: FfxInt32x2 = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FfxFloat32x2 = ffxFract_f32x2(fPxSample);
#if FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 0
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Lanczos2_FetchedBicubicSamples_f32x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
#elif FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE == 1
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Lanczos2LUT_FetchedBicubicSamples_f32x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
#else
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Lanczos2Approx_FetchedBicubicSamples_f32x2(FetchLockStatusSamples(iPxSample, iTextureSize), fPxFrac));
#endif
    return fColorXY;
}
#endif
#endif

fn GetMotionVector(iPxHrPos: FfxInt32x2, fHrUv: FfxFloat32x2) -> FfxFloat32x2
{
#if FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS
    let fDilatedMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(FFX_MIN16_I2(fHrUv * FfxFloat32x2(RenderSize()))));
#else
    let fDilatedMotionVector: FfxFloat32x2 = LoadInputMotionVector(FfxUInt32x2(iPxHrPos));
#endif

    return fDilatedMotionVector;
}

fn IsUvInside(fUv: FfxFloat32x2) -> FfxBoolean
{
    return (fUv.x >= 0.0f && fUv.x <= 1.0f) && (fUv.y >= 0.0f && fUv.y <= 1.0f);
}

fn ComputeReprojectedUVs(params: AccumulationPassCommonParams, fReprojectedHrUv: ptr<function, FfxFloat32x2>, bIsExistingSample: ptr<function, FfxBoolean>)
{
    *fReprojectedHrUv = params.fHrUv + params.fMotionVector;

    *bIsExistingSample = IsUvInside(*fReprojectedHrUv);
}

fn ReprojectHistoryColor(params: AccumulationPassCommonParams, fHistoryColor: ptr<function, FfxFloat32x3>, fTemporalReactiveFactor: ptr<function, FfxFloat32>, bInMotionLastFrame: ptr<function, FfxBoolean>)
{
    let fHistory: FfxFloat32x4 = FfxFloat32x4(HistorySample(params.fReprojectedHrUv, DisplaySize()));

    *fHistoryColor = PrepareRgb(fHistory.rgb, Exposure(), PreviousFramePreExposure());

    *fHistoryColor = RGBToYCoCg_f32x3(*fHistoryColor);

    //Compute temporal reactivity info
    *fTemporalReactiveFactor = ffxSaturate_f32(abs(fHistory.w));
    *bInMotionLastFrame = (fHistory.w < 0.0f);
}

fn ReprojectHistoryLockStatus(params: AccumulationPassCommonParams, fReprojectedLockStatus: ptr<function, FfxFloat32x2>) -> LockState
{
    var state: LockState = LockState(FFX_FALSE, FFX_FALSE);
    let fNewLockIntensity: FfxFloat32 = LoadRwNewLocks(FfxUInt32x2(params.iPxHrPos));
    state.NewLock = fNewLockIntensity > (127.0f / 255.0f);

    let fInPlaceLockLifetime: FfxFloat32 = select(FfxFloat32(0), fNewLockIntensity, state.NewLock);

    *fReprojectedLockStatus = SampleLockStatus(params.fReprojectedHrUv);

    if ((*fReprojectedLockStatus)[LOCK_LIFETIME_REMAINING] != FfxFloat32(0.0f)) {
        state.WasLockedPrevFrame = true;
    }

    return state;
}

#endif //!defined( FFX_FSR2_REPROJECT_H )
