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

// WGSL port of ffx_fsr2_postprocess_lock_status.h. Overloads carry
// parameter-type suffixes (see ffx_core.wgsl); FFX_PARAMETER_OUT/INOUT
// parameters are function pointers. HLSL's implicit int-to-uint, int-to-float
// and float-to-half conversions are written out. The DeclareCustom*
// invocations are expanded from the templates quoted in ffx_fsr2_sample.wgsl,
// the macro argument named in a comment above each expansion; their +0 offsets
// are written 0 (WGSL has no unary plus).

#ifndef FFX_FSR2_POSTPROCESS_LOCK_STATUS_H
#define FFX_FSR2_POSTPROCESS_LOCK_STATUS_H

fn WrapShadingChangeLuma_i32x2(iPxSample: FfxInt32x2) -> FfxFloat32x4
{
    return FfxFloat32x4(LoadMipLuma(FfxUInt32x2(iPxSample), FfxUInt32(LumaMipLevelToUse())), 0, 0, 0);
}

#if FFX_HALF
fn WrapShadingChangeLuma_i16x2(iPxSample: FFX_MIN16_I2) -> FFX_MIN16_F4
{
    return FFX_MIN16_F4(FFX_MIN16_F(LoadMipLuma(FfxUInt32x2(iPxSample), FfxUInt32(LumaMipLevelToUse()))), 0, 0, 0);
}
#endif

#if FFX_FSR2_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF && FFX_HALF
// DeclareCustomFetchBilinearSamplesMin16(FetchShadingChangeLumaSamples, WrapShadingChangeLuma)
fn FetchShadingChangeLumaSamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBilinearSamplesMin16
{
    var Samples: FetchedBilinearSamplesMin16;
    Samples.fColor00 = FFX_MIN16_F4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor10 = FFX_MIN16_F4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor01 = FFX_MIN16_F4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor11 = FFX_MIN16_F4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    return Samples;
}
#else
// DeclareCustomFetchBicubicSamples(FetchShadingChangeLumaSamples, WrapShadingChangeLuma)
fn FetchShadingChangeLumaSamples(iPxSample: FfxInt32x2, iTextureSize: FfxInt32x2) -> FetchedBicubicSamples
{
    var Samples: FetchedBicubicSamples;

    Samples.fColor00 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, -1), iTextureSize)));
    Samples.fColor10 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, -1), iTextureSize)));
    Samples.fColor20 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, -1), iTextureSize)));
    Samples.fColor30 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, -1), iTextureSize)));

    Samples.fColor01 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 0), iTextureSize)));
    Samples.fColor11 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 0), iTextureSize)));
    Samples.fColor21 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 0), iTextureSize)));
    Samples.fColor31 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 0), iTextureSize)));

    Samples.fColor02 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 1), iTextureSize)));
    Samples.fColor12 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 1), iTextureSize)));
    Samples.fColor22 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 1), iTextureSize)));
    Samples.fColor32 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 1), iTextureSize)));

    Samples.fColor03 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(-1, 2), iTextureSize)));
    Samples.fColor13 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(0, 2), iTextureSize)));
    Samples.fColor23 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(1, 2), iTextureSize)));
    Samples.fColor33 = FfxFloat32x4(WrapShadingChangeLuma_i32x2(ClampCoord_i32x2_i32x2_i32x2(iPxSample, FfxInt32x2(2, 2), iTextureSize)));

    return Samples;
}
#endif
// DeclareCustomTextureSample(ShadingChangeLumaSample, Lanczos2, FetchShadingChangeLumaSamples)
fn ShadingChangeLumaSample(fUvSample: FfxFloat32x2, iTextureSize: FfxInt32x2) -> FfxFloat32x4
{
    var fPxSample: FfxFloat32x2 = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
    /* Clamp base coords */
    fPxSample.x = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.x), fPxSample.x));
    fPxSample.y = ffxMax_f32_f32(0.0f, ffxMin_f32_f32(FfxFloat32(iTextureSize.y), fPxSample.y));
    /* */
    let iPxSample: FfxInt32x2 = FfxInt32x2(floor(fPxSample));
    let fPxFrac: FfxFloat32x2 = ffxFract_f32x2(fPxSample);
    let fColorXY: FfxFloat32x4 = FfxFloat32x4(Lanczos2_FetchedBicubicSamples_f32x2(FetchShadingChangeLumaSamples(iPxSample, iTextureSize), fPxFrac));
    return fColorXY;
}

// WGSL: parameters are immutable; the SDK assigns fUvCoord, so it is a local
// initialized from the parameter fUvCoord_.
fn GetShadingChangeLuma(iPxHrPos: FfxInt32x2, fUvCoord_: FfxFloat32x2) -> FfxFloat32
{
    var fUvCoord: FfxFloat32x2 = fUvCoord_;
    var fShadingChangeLuma: FfxFloat32 = 0;

#if 0
    fShadingChangeLuma = Exposure() * exp(ShadingChangeLumaSample(fUvCoord, LumaMipDimensions()).x);
#else

    let fDiv: FfxFloat32 = FfxFloat32(2 << FfxUInt32(LumaMipLevelToUse()));
    let iMipRenderSize: FfxInt32x2 = FfxInt32x2(FfxFloat32x2(RenderSize()) / fDiv);

    fUvCoord = ClampUv(fUvCoord, iMipRenderSize, LumaMipDimensions());
    fShadingChangeLuma = Exposure() * exp(FfxFloat32(SampleMipLuma(fUvCoord, FfxUInt32(LumaMipLevelToUse()))));
#endif

    fShadingChangeLuma = ffxPow_f32_f32(fShadingChangeLuma, 1.0f / 6.0f);

    return fShadingChangeLuma;
}

fn UpdateLockStatus(params: AccumulationPassCommonParams,
    fReactiveFactor: ptr<function, FfxFloat32>, state: LockState,
    fLockStatus: ptr<function, FfxFloat32x2>,
    fLockContributionThisFrame: ptr<function, FfxFloat32>,
    fLuminanceDiff: ptr<function, FfxFloat32>) {

    let fShadingChangeLuma: FfxFloat32 = GetShadingChangeLuma(params.iPxHrPos, params.fHrUv);

    //init temporal shading change factor, init to -1 or so in reproject to know if "true new"?
    (*fLockStatus)[LOCK_TEMPORAL_LUMA] = select((*fLockStatus)[LOCK_TEMPORAL_LUMA], fShadingChangeLuma, ((*fLockStatus)[LOCK_TEMPORAL_LUMA] == FfxFloat32(0.0f)));

    let fPreviousShadingChangeLuma: FfxFloat32 = (*fLockStatus)[LOCK_TEMPORAL_LUMA];

    *fLuminanceDiff = 1.0f - MinDividedByMax_f32_f32(fPreviousShadingChangeLuma, fShadingChangeLuma);

    if (state.NewLock) {
        (*fLockStatus)[LOCK_TEMPORAL_LUMA] = fShadingChangeLuma;

        (*fLockStatus)[LOCK_LIFETIME_REMAINING] = select(1.0f, 2.0f, ((*fLockStatus)[LOCK_LIFETIME_REMAINING] != 0.0f));
    }
    else if((*fLockStatus)[LOCK_LIFETIME_REMAINING] <= 1.0f) {
        (*fLockStatus)[LOCK_TEMPORAL_LUMA] = ffxLerp_f32_f32_f32((*fLockStatus)[LOCK_TEMPORAL_LUMA], FfxFloat32(fShadingChangeLuma), 0.5f);
    }
    else {
        if (*fLuminanceDiff > 0.1f) {
            KillLock_f32x2(fLockStatus);
        }
    }

    *fReactiveFactor = ffxMax_f32_f32(*fReactiveFactor, ffxSaturate_f32((*fLuminanceDiff - 0.1f) * 10.0f));
    (*fLockStatus)[LOCK_LIFETIME_REMAINING] *= (1.0f - *fReactiveFactor);

    (*fLockStatus)[LOCK_LIFETIME_REMAINING] *= ffxSaturate_f32(1.0f - params.fAccumulationMask);
    (*fLockStatus)[LOCK_LIFETIME_REMAINING] *= FfxFloat32(params.fDepthClipFactor < 0.1f);

    // Compute this frame lock contribution
    let fLifetimeContribution: FfxFloat32 = ffxSaturate_f32((*fLockStatus)[LOCK_LIFETIME_REMAINING] - 1.0f);
    let fShadingChangeContribution: FfxFloat32 = ffxSaturate_f32(MinDividedByMax_f32_f32((*fLockStatus)[LOCK_TEMPORAL_LUMA], fShadingChangeLuma));

    *fLockContributionThisFrame = ffxSaturate_f32(ffxSaturate_f32(fLifetimeContribution * 4.0f) * fShadingChangeContribution);
}

#endif //!defined( FFX_FSR2_POSTPROCESS_LOCK_STATUS_H )
