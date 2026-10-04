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

// WGSL port of ffx_fsr2_upsample.h. Overloads carry parameter-type suffixes (see
// ffx_core.wgsl); FFX_PARAMETER_INOUT parameters are function pointers. HLSL's
// implicit int-to-float and int-to-uint conversions are written out.

#ifndef FFX_FSR2_UPSAMPLE_H
#define FFX_FSR2_UPSAMPLE_H

const iLanczos2SampleCount: FfxUInt32 = 16;

fn Deringing_RectificationBox_f32x3(clippingBox: RectificationBox, fColor: ptr<function, FfxFloat32x3>)
{
    *fColor = clamp(*fColor, clippingBox.aabbMin, clippingBox.aabbMax);
}
#if FFX_HALF
fn Deringing_RectificationBoxMin16_f16x3(clippingBox: RectificationBoxMin16, fColor: ptr<function, FFX_MIN16_F3>)
{
    *fColor = clamp(*fColor, clippingBox.aabbMin, clippingBox.aabbMax);
}
#endif

#ifndef FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE
#define FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE 2 // Approximate
#endif

// WGSL: a scalar has no .xx swizzle; the vector constructor splats it.
fn GetUpsampleLanczosWeight_f32x2_f32(fSrcSampleOffset: FfxFloat32x2, fKernelWeight: FfxFloat32) -> FfxFloat32
{
    let fSrcSampleOffsetBiased: FfxFloat32x2 = fSrcSampleOffset * FfxFloat32x2(fKernelWeight);
#if FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 0 // LANCZOS_TYPE_REFERENCE
    let fSampleWeight: FfxFloat32 = Lanczos2_f32(length(fSrcSampleOffsetBiased));
#elif FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 1 // LANCZOS_TYPE_LUT
    let fSampleWeight: FfxFloat32 = Lanczos2_UseLUT_f32(length(fSrcSampleOffsetBiased));
#elif FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 2 // LANCZOS_TYPE_APPROXIMATE
    let fSampleWeight: FfxFloat32 = Lanczos2ApproxSq_f32(dot(fSrcSampleOffsetBiased, fSrcSampleOffsetBiased));
#else
#error "Invalid Lanczos type"
#endif
    return fSampleWeight;
}

#if FFX_HALF
fn GetUpsampleLanczosWeight_f16x2_f16(fSrcSampleOffset: FFX_MIN16_F2, fKernelWeight: FFX_MIN16_F) -> FFX_MIN16_F
{
    let fSrcSampleOffsetBiased: FFX_MIN16_F2 = fSrcSampleOffset * FFX_MIN16_F2(fKernelWeight);
#if FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 0 // LANCZOS_TYPE_REFERENCE
    let fSampleWeight: FFX_MIN16_F = Lanczos2_f16(length(fSrcSampleOffsetBiased));
#elif FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 1 // LANCZOS_TYPE_LUT
    let fSampleWeight: FFX_MIN16_F = Lanczos2_UseLUT_f16(length(fSrcSampleOffsetBiased));
#elif FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 2 // LANCZOS_TYPE_APPROXIMATE
    let fSampleWeight: FFX_MIN16_F = Lanczos2ApproxSq_f16(dot(fSrcSampleOffsetBiased, fSrcSampleOffsetBiased));

    // To Test: Save reciproqual sqrt compute
    // FfxFloat32 fSampleWeight = Lanczos2Sq_UseLUT(dot(fSrcSampleOffsetBiased, fSrcSampleOffsetBiased));
#else
#error "Invalid Lanczos type"
#endif
    return fSampleWeight;
}
#endif

fn ComputeMaxKernelWeight() -> FfxFloat32 {
    let fKernelSizeBias: FfxFloat32 = 1.0f;

    let fKernelWeight: FfxFloat32 = FfxFloat32(1) + (FfxFloat32(1.0f) / FfxFloat32x2(DownscaleFactor()) - FfxFloat32(1)).x * FfxFloat32(fKernelSizeBias);

    return ffxMin_f32_f32(FfxFloat32(1.99f), fKernelWeight);
}


#if FFX_HALF && (FFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 2) && defined(__XBOX_SCARLETT) && defined(__XBATG_EXTRA_16_BIT_OPTIMISATION) && (__XBATG_EXTRA_16_BIT_OPTIMISATION == 1)
#define FFX_FSR2_USE_XBOX_PAIRED_16BIT_MATH_OPTIMIZATIONS 1
#else
#define FFX_FSR2_USE_XBOX_PAIRED_16BIT_MATH_OPTIMIZATIONS 0
#endif

#if FFX_FSR2_USE_XBOX_PAIRED_16BIT_MATH_OPTIMIZATIONS
// Bool2ToFloat16x2, PairedRectificationBoxAndAccumulatedColorAndWeight: Xbox
// only (__XBOX_SCARLETT), never compiled here.
#endif

fn ComputeUpsampledColorAndWeight(params: AccumulationPassCommonParams,
    clippingBox: ptr<function, RectificationBox>, fReactiveFactor: FfxFloat32) -> FfxFloat32x4
{
    // We compute a sliced lanczos filter with 2 lobes (other slices are accumulated temporaly)
    let fDstOutputPos: FfxFloat32x2 = FfxFloat32x2(params.iPxHrPos) + FfxFloat32x2(0.5f);      // Destination resolution output pixel center position
    let fSrcOutputPos: FfxFloat32x2 = fDstOutputPos * DownscaleFactor();                   // Source resolution output pixel center position
    let iSrcInputPos: FfxInt32x2 = FfxInt32x2(floor(fSrcOutputPos));                     // TODO: what about weird upscale factors...

#if FFX_FSR2_USE_XBOX_PAIRED_16BIT_MATH_OPTIMIZATIONS
    // FFX_MIN16_F3 fSamples[iLanczos2SampleCount]: Xbox only, as above.
#else
    var fSamples: array<FfxFloat32x3, iLanczos2SampleCount>;
#endif

    let fSrcUnjitteredPos: FfxFloat32x2 = (FfxFloat32x2(iSrcInputPos) + FfxFloat32x2(0.5f, 0.5f)) - Jitter(); // This is the un-jittered position of the sample at offset 0,0

    var offsetTL: FfxInt32x2;
    offsetTL.x = select(FfxInt32(-1), FfxInt32(-2), (fSrcUnjitteredPos.x > fSrcOutputPos.x));
    offsetTL.y = select(FfxInt32(-1), FfxInt32(-2), (fSrcUnjitteredPos.y > fSrcOutputPos.y));

    //Load samples
    // If fSrcUnjitteredPos.y > fSrcOutputPos.y, indicates offsetTL.y = -2, sample offset Y will be [-2, 1], clipbox will be rows [1, 3].
    // Flip row# for sampling offset in this case, so first 0~2 rows in the sampled array can always be used for computing the clipbox.
    // This reduces branch or cmove on sampled colors, but moving this overhead to sample position / weight calculation time which apply to less values.
    let bFlipRow: FfxBoolean = fSrcUnjitteredPos.y > fSrcOutputPos.y;
    let bFlipCol: FfxBoolean = fSrcUnjitteredPos.x > fSrcOutputPos.x;

#if FFX_FSR2_USE_XBOX_PAIRED_16BIT_MATH_OPTIMIZATIONS
    // The unrolled paired sample loads: Xbox only, as above.
#else
    let fOffsetTL: FfxFloat32x2 = FfxFloat32x2(offsetTL);

    FFX_UNROLL
    for (var row: FfxInt32 = 0; row < 3; row++) {

        FFX_UNROLL
            for (var col: FfxInt32 = 0; col < 3; col++) {
                let iSampleIndex: FfxInt32 = col + (row << 2u);

                let sampleColRow: FfxInt32x2 = FfxInt32x2(select(col, (3 - col), bFlipCol), select(row, (3 - row), bFlipRow));
                let iSrcSamplePos: FfxInt32x2 = FfxInt32x2(iSrcInputPos) + offsetTL + sampleColRow;

                let sampleCoord: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iSrcSamplePos, FfxInt32x2(0, 0), FfxInt32x2(RenderSize()));

                fSamples[iSampleIndex] = LoadPreparedInputColor(FfxUInt32x2(FfxInt32x2(sampleCoord)));
            }
    }
#endif

    var fColorAndWeight: FfxFloat32x4 = FfxFloat32x4(0.0f, 0.0f, 0.0f, 0.0f);

    let fBaseSampleOffset: FfxFloat32x2 = FfxFloat32x2(fSrcUnjitteredPos - fSrcOutputPos);

    // Identify how much of each upsampled color to be used for this frame
    let fKernelReactiveFactor: FfxFloat32 = ffxMax_f32_f32(fReactiveFactor, FfxFloat32(params.bIsNewSample));
    let fKernelBiasMax: FfxFloat32 = ComputeMaxKernelWeight() * (1.0f - fKernelReactiveFactor);

    let fKernelBiasMin: FfxFloat32 = ffxMax_f32_f32(1.0f, ((1.0f + fKernelBiasMax) * 0.3f));
    let fKernelBiasFactor: FfxFloat32 = ffxMax_f32_f32(0.0f, ffxMax_f32_f32(0.25f * params.fDepthClipFactor, fKernelReactiveFactor));
    let fKernelBias: FfxFloat32 = ffxLerp_f32_f32_f32(fKernelBiasMax, fKernelBiasMin, fKernelBiasFactor);

    let fRectificationCurveBias: FfxFloat32 = ffxLerp_f32_f32_f32(-2.0f, -3.0f, ffxSaturate_f32(params.fHrVelocity / 50.0f));

#if FFX_FSR2_USE_XBOX_PAIRED_16BIT_MATH_OPTIMIZATIONS
    // The paired rectification box and weights: Xbox only, as above.
#else
    FFX_UNROLL
    for (var row: FfxInt32 = 0; row < 3; row++) {
        FFX_UNROLL
        for (var col: FfxInt32 = 0; col < 3; col++) {
            let iSampleIndex: FfxInt32 = col + (row << 2u);

            let sampleColRow: FfxInt32x2 = FfxInt32x2(select(col, (3 - col), bFlipCol), select(row, (3 - row), bFlipRow));
            let fOffset: FfxFloat32x2 = fOffsetTL + FfxFloat32x2(sampleColRow);
            let fSrcSampleOffset: FfxFloat32x2 = fBaseSampleOffset + fOffset;

            let iSrcSamplePos: FfxInt32x2 = FfxInt32x2(iSrcInputPos) + FfxInt32x2(offsetTL) + sampleColRow;

            let fOnScreenFactor: FfxFloat32 = FfxFloat32(IsOnScreen_i32x2_i32x2(FfxInt32x2(iSrcSamplePos), FfxInt32x2(RenderSize())));
            let fSampleWeight: FfxFloat32 = fOnScreenFactor * FfxFloat32(GetUpsampleLanczosWeight_f32x2_f32(fSrcSampleOffset, fKernelBias));

            fColorAndWeight += FfxFloat32x4(fSamples[iSampleIndex] * fSampleWeight, fSampleWeight);

            // Update rectification box
            {
                let fSrcSampleOffsetSq: FfxFloat32 = dot(fSrcSampleOffset, fSrcSampleOffset);
                let fBoxSampleWeight: FfxFloat32 = exp(fRectificationCurveBias * fSrcSampleOffsetSq);

                let bInitialSample: FfxBoolean = (row == 0) && (col == 0);
                RectificationBoxAddSample_b_RectificationBox_f32x3_f32(bInitialSample, clippingBox, fSamples[iSampleIndex], fBoxSampleWeight);
            }
        }
    }
#endif

    RectificationBoxComputeVarianceBoxData_RectificationBox(clippingBox);

    fColorAndWeight.w *= FfxFloat32(fColorAndWeight.w > FSR2_EPSILON);

    if (fColorAndWeight.w > FSR2_EPSILON) {
        // Normalize for deringing (we need to compare colors)
        // WGSL: no assignment to a multi-component swizzle (fColorAndWeight.xyz = ...).
        fColorAndWeight = FfxFloat32x4(fColorAndWeight.xyz / fColorAndWeight.w, fColorAndWeight.w);
        fColorAndWeight.w *= fUpsampleLanczosWeightScale;

        // WGSL: a swizzle has no address; Deringing clamps fColorAndWeight.xyz
        // through a local.
        var fColor: FfxFloat32x3 = fColorAndWeight.xyz;
        Deringing_RectificationBox_f32x3(*clippingBox, &fColor);
        fColorAndWeight = FfxFloat32x4(fColor, fColorAndWeight.w);
    }

    return fColorAndWeight;
}

#endif //!defined( FFX_FSR2_UPSAMPLE_H )
