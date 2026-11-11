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
fn Deringing(clippingBox: RectificationBox, fColor: ptr<function, FfxFloat32x3>)
{
    (*fColor) = clamp((*fColor), clippingBox.aabbMin, clippingBox.aabbMax);
}

#ifndef FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE
#define FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE 2 // Approximate
#endif

fn GetUpsampleLanczosWeight_f32x2_f32(fSrcSampleOffset: FfxFloat32x2, fKernelWeight: FfxFloat32) -> FfxFloat32
{
    var fSrcSampleOffsetBiased: FfxFloat32x2 = fSrcSampleOffset * FfxFloat32x2(fKernelWeight);
#if FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 0 // LANCZOS_TYPE_REFERENCE
    var fSampleWeight: FfxFloat32 = Lanczos2_f32(length(fSrcSampleOffsetBiased));
#elif FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 1 // LANCZOS_TYPE_LUT
    var fSampleWeight: FfxFloat32 = Lanczos2_UseLUT_f32(length(fSrcSampleOffsetBiased));
#elif FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 2 // LANCZOS_TYPE_APPROXIMATE
    var fSampleWeight: FfxFloat32 = Lanczos2ApproxSq_f32(dot(fSrcSampleOffsetBiased, fSrcSampleOffsetBiased));
#else
#error "Invalid Lanczos type"
#endif
    return fSampleWeight;
}

#if FFX_HALF
fn GetUpsampleLanczosWeight_f16x2_f16(fSrcSampleOffset: FFX_MIN16_F2, fKernelWeight: FFX_MIN16_F) -> FFX_MIN16_F
{
    var fSrcSampleOffsetBiased: FFX_MIN16_F2 = fSrcSampleOffset * FFX_MIN16_F2(fKernelWeight);
#if FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 0 // LANCZOS_TYPE_REFERENCE
    var fSampleWeight: FFX_MIN16_F = Lanczos2_f16(length(fSrcSampleOffsetBiased));
#elif FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 1 // LANCZOS_TYPE_LUT
    var fSampleWeight: FFX_MIN16_F = Lanczos2_UseLUT_f16(length(fSrcSampleOffsetBiased));
#elif FFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE == 2 // LANCZOS_TYPE_APPROXIMATE
    var fSampleWeight: FFX_MIN16_F = Lanczos2ApproxSq_f16(dot(fSrcSampleOffsetBiased, fSrcSampleOffsetBiased));

    // To Test: Save reciproqual sqrt compute
    // var fSampleWeight: FfxFloat32 = Lanczos2Sq_UseLUT(dot(fSrcSampleOffsetBiased, fSrcSampleOffsetBiased));
#else
#error "Invalid Lanczos type"
#endif
    return fSampleWeight;
}
#endif

fn ComputeMaxKernelWeight(params: AccumulationPassCommonParams, data: ptr<function, AccumulationPassData>) -> FfxFloat32
{

    var fKernelSizeBias: FfxFloat32 = 1.0f + (1.0f / FfxFloat32x2(DownscaleFactor()) - 1.0f).x;

    return min(FfxFloat32(1.99f), fKernelSizeBias);
}

fn LoadPreparedColor(iSamplePos: FfxInt32x2) -> FfxFloat32x3
{
    var fRgb: FfxFloat32x3 = max(FfxFloat32x3(0, 0, 0), LoadInputColor(FfxUInt32x2(iSamplePos))) * Exposure();
    var fPreparedYCoCg: FfxFloat32x3 = RGBToYCoCg_f32x3(fRgb);

    return fPreparedYCoCg;
}

// Xbox paired ISA optimizations have no WGSL target; portable SDK path below.
fn ComputeUpsampledColorAndWeight(params: AccumulationPassCommonParams, data: ptr<function, AccumulationPassData>)
{
    // We compute a sliced lanczos filter with 2 lobes (other slices are accumulated temporaly)
    var fDstOutputPos: FfxFloat32x2 = FfxFloat32x2(params.iPxHrPos) + FfxFloat32x2(0.5f);
    var fSrcOutputPos: FfxFloat32x2 = fDstOutputPos * DownscaleFactor();
    var iSrcInputPos: FfxInt32x2 = FfxInt32x2(floor(fSrcOutputPos));
    var fSrcUnjitteredPos: FfxFloat32x2 = (FfxFloat32x2(iSrcInputPos) + FfxFloat32x2(0.5f, 0.5f)) - Jitter(); // This is the un-jittered position of the sample at offset 0,0
    var fBaseSampleOffset: FfxFloat32x2 = FfxFloat32x2(fSrcUnjitteredPos - fSrcOutputPos);

    var offsetTL: FfxInt32x2 ;
    offsetTL.x = select(FfxInt32(-1), FfxInt32(-2), (fSrcUnjitteredPos.x > fSrcOutputPos.x));
    offsetTL.y = select(FfxInt32(-1), FfxInt32(-2), (fSrcUnjitteredPos.y > fSrcOutputPos.y));

    //Load samples
    // If fSrcUnjitteredPos.y > fSrcOutputPos.y, indicates offsetTL.y = -2, sample offset Y will be [-2, 1], clipbox will be rows [1, 3].
    // Flip row# for sampling offset in this case, so first 0~2 rows in the sampled array can always be used for computing the clipbox.
    // This reduces branch or cmove on sampled colors, but moving this overhead to sample position / weight calculation time which apply to less values.
    var bFlipRow: FfxBoolean = fSrcUnjitteredPos.y > fSrcOutputPos.y;
    var bFlipCol: FfxBoolean = fSrcUnjitteredPos.x > fSrcOutputPos.x;
    var fOffsetTL: FfxFloat32x2 = FfxFloat32x2(offsetTL);

    var bIsInitialSample: FfxBoolean = (params.fAccumulation == 0.0f);

    var fSamples: array<FfxFloat32x3, 9> ;
    var iSampleIndex: FfxInt32 = 0;

    
    for (var row: FfxInt32 = 0; row < 3; row++) {
        
        for (var col: FfxInt32 = 0; col < 3; col++) {
            var iSampleColRow: FfxInt32x2 = FfxInt32x2(select(col, (3 - col), bFlipCol), select(row, (3 - row), bFlipRow));
            var iSrcSamplePos: FfxInt32x2 = FfxInt32x2(iSrcInputPos) + offsetTL + iSampleColRow;
            var iSampleCoord: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iSrcSamplePos, FfxInt32x2(0, 0), FfxInt32x2(RenderSize()));

            fSamples[iSampleIndex] = LoadPreparedColor(iSampleCoord);

            iSampleIndex++;
        }
    }

#if FFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT
    if (bIsInitialSample)
    {
        for (iSampleIndex = 0; iSampleIndex < 9; iSampleIndex++)
        {
            //YCoCg -> RGB -> Tonemap_f32x3 -> YCoCg (Use RGB tonemapper to avoid color desaturation)
            fSamples[iSampleIndex] = RGBToYCoCg_f32x3(Tonemap_f32x3(YCoCgToRGB_f32x3(fSamples[iSampleIndex])));
        }
    }
#endif


    // Identify how much of each upsampled color to be used for this frame
    var fKernelBiasMax: FfxFloat32 = ComputeMaxKernelWeight(params, data);
    var fKernelBiasMin: FfxFloat32 = max(1.0f, ((1.0f + fKernelBiasMax) * 0.3f));

    var fKernelBiasWeight: FfxFloat32 =
        min(1.0f - params.fDisocclusion * 0.5f,
        min(1.0f - params.fShadingChange,
        ffxSaturate_f32((*data).fHistoryWeight * 5.0f)
        ));

    var fKernelBias: FfxFloat32 = mix(fKernelBiasMin, fKernelBiasMax, fKernelBiasWeight);
    

    iSampleIndex = 0;

    
    for (var row: FfxInt32 = 0; row < 3; row++)
    {
        
        for (var col: FfxInt32 = 0; col < 3; col++)
        {
            var sampleColRow: FfxInt32x2 = FfxInt32x2(select(col, (3 - col), bFlipCol), select(row, (3 - row), bFlipRow));
            var fOffset: FfxFloat32x2 = fOffsetTL + FfxFloat32x2(sampleColRow);
            var fSrcSampleOffset: FfxFloat32x2 = fBaseSampleOffset + fOffset;

            var iSrcSamplePos: FfxInt32x2 = FfxInt32x2(iSrcInputPos) + FfxInt32x2(offsetTL) + sampleColRow;
            var fOnScreenFactor: FfxFloat32 = FfxFloat32(IsOnScreen_i32x2_i32x2(FfxInt32x2(iSrcSamplePos), FfxInt32x2(RenderSize())));

            if (!bIsInitialSample)
            {
                var fSampleWeight: FfxFloat32 = fOnScreenFactor * FfxFloat32(GetUpsampleLanczosWeight_f32x2_f32(fSrcSampleOffset, fKernelBias));

                (*data).fUpsampledColor += fSamples[iSampleIndex] * fSampleWeight;
                (*data).fUpsampledWeight += fSampleWeight;
            }

            // Update rectification box
            {
                var fRectificationCurveBias: FfxFloat32 = -2.3f;
                var fSrcSampleOffsetSq: FfxFloat32 = dot(fSrcSampleOffset, fSrcSampleOffset);
                var fBoxSampleWeight: FfxFloat32 = exp(fRectificationCurveBias * fSrcSampleOffsetSq) * fOnScreenFactor;

                var bInitialSample: FfxBoolean = (row == 0) && (col == 0);
                RectificationBoxAddSample_b_RectificationBox_f32x3_f32(bInitialSample, &((*data).clippingBox), fSamples[iSampleIndex], fBoxSampleWeight);
            }
            iSampleIndex++;
        }
    }
	

    RectificationBoxComputeVarianceBoxData_RectificationBox(&((*data).clippingBox));

    (*data).fUpsampledWeight *= FfxFloat32((*data).fUpsampledWeight > FSR3UPSCALER_EPSILON);

    if ((*data).fUpsampledWeight > FSR3UPSCALER_EPSILON) {
        // Normalize for deringing (we need to compare colors)
        (*data).fUpsampledColor = (*data).fUpsampledColor / (*data).fUpsampledWeight;
        (*data).fUpsampledWeight *= fAverageLanczosWeightPerFrame;

        // Metal stores vec3 structure fields packed; pass a function-local
        // vector so the translated inout reference has its required alignment.
        var fDeringedColor: FfxFloat32x3 = (*data).fUpsampledColor;
        Deringing((*data).clippingBox, &fDeringedColor);
        (*data).fUpsampledColor = fDeringedColor;
    }

    // Initial samples using tonemapped upsampling
    if (bIsInitialSample) {
#if FFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT
        (*data).fUpsampledColor  = RGBToYCoCg_f32x3(InverseTonemap_f32x3(YCoCgToRGB_f32x3((*data).clippingBox.boxCenter)));
#else
        (*data).fUpsampledColor  = (*data).clippingBox.boxCenter;
#endif
        (*data).fUpsampledWeight = 1.0f;
        (*data).fHistoryWeight   = 0.0f;
    }
}
