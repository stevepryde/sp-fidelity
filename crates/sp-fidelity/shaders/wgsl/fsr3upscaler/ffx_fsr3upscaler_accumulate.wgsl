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
fn Accumulate_AccumulationPassCommonParams_AccumulationPassData(params: AccumulationPassCommonParams, data: ptr<function, AccumulationPassData>)
{
    // Avoid invalid values when accumulation and upsampled weight is 0
    (*data).fHistoryWeight *= FfxFloat32((*data).fHistoryWeight > FSR3UPSCALER_FP16_MIN);
    (*data).fHistoryWeight = max(FSR3UPSCALER_EPSILON, (*data).fHistoryWeight + (*data).fUpsampledWeight);

#if FFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT
    //YCoCg -> RGB -> Tonemap_f32x3 -> YCoCg (Use RGB tonemapper to avoid color desaturation)
    (*data).fUpsampledColor    = RGBToYCoCg_f32x3(Tonemap_f32x3(YCoCgToRGB_f32x3((*data).fUpsampledColor)));
    (*data).fHistoryColor      = RGBToYCoCg_f32x3(Tonemap_f32x3(YCoCgToRGB_f32x3((*data).fHistoryColor)));
#endif

    var fAlpha: FfxFloat32 = ffxSaturate_f32((*data).fUpsampledWeight / (*data).fHistoryWeight);
    (*data).fHistoryColor      = mix((*data).fHistoryColor, (*data).fUpsampledColor, fAlpha);
    (*data).fHistoryColor      = YCoCgToRGB_f32x3((*data).fHistoryColor);

#if FFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT
    (*data).fHistoryColor      = InverseTonemap_f32x3((*data).fHistoryColor);
#endif
}

fn RectifyHistory(params: AccumulationPassCommonParams, data: ptr<function, AccumulationPassData>)
{
    var f4kVelocityFactor: FfxFloat32 = ffxSaturate_f32(params.f4KVelocity / 20.0f);
    var fDistanceFactor: FfxFloat32 = ffxSaturate_f32(0.75f - params.fFarthestDepthInMeters / 20.0f);
    var fAccumulationFactor: FfxFloat32 = 1.0f - params.fAccumulation;
    var fReactiveFactor: FfxFloat32 = pow(params.fReactiveMask, 1.0f / 2.0f);
    var fShadingChangeFactor: FfxFloat32 = params.fShadingChange;
    var fBoxScaleT: FfxFloat32 = max(f4kVelocityFactor, max(fDistanceFactor, max(fAccumulationFactor, max(fReactiveFactor, fShadingChangeFactor))));
    
    var fBoxScale: FfxFloat32 = mix(3.0f, 1.0f, fBoxScaleT);
    var fScaledBoxVec: FfxFloat32x3 = (*data).clippingBox.boxVec * FfxFloat32x3(1.7f, 1.0f, 1.0f) * fBoxScale;

    var fClampedScaledBoxVec: FfxFloat32x3 = max(fScaledBoxVec, FfxFloat32x3(1.193e-7f, 1.193e-7f, 1.193e-7f));
    var fTransformedHistoryColor: FfxFloat32x3 = ((*data).fHistoryColor - (*data).clippingBox.boxCenter) / fClampedScaledBoxVec;

    if (length(fTransformedHistoryColor)>1.0f) {
        var fClampedHistoryColor: FfxFloat32x3 = normalize(fTransformedHistoryColor);
        var fFinalClampedHistoryColor: FfxFloat32x3 = (fClampedHistoryColor * fScaledBoxVec) + (*data).clippingBox.boxCenter;

        // Scale history color using rectification info, also using accumulation mask to avoid potential invalid color protection
        var fHistoryContribution: FfxFloat32 = max(params.fLumaInstabilityFactor, (*data).fLockContributionThisFrame) * params.fAccumulation * (1 - params.fDisocclusion);
        (*data).fHistoryColor = mix(fFinalClampedHistoryColor, (*data).fHistoryColor, ffxSaturate_f32(fHistoryContribution));
    }
}

fn UpdateLockStatus(params: AccumulationPassCommonParams, data: ptr<function, AccumulationPassData>)
{
    (*data).fLock *= FfxFloat32(params.bIsNewSample == false);

    var fLifetimeDecreaseFactor: FfxFloat32 = max(ffxSaturate_f32(params.fShadingChange), max(params.fReactiveMask, params.fDisocclusion));
    (*data).fLock = max(0.0f, (*data).fLock - fLifetimeDecreaseFactor * fLockMax);

    // Compute this frame lock contribution
    (*data).fLockContributionThisFrame = ffxSaturate_f32(ffxSaturate_f32((*data).fLock - fLockThreshold) * (fLockMax - fLockThreshold));

    var fNewLockIntensity: FfxFloat32 = LoadRwNewLocks(FfxUInt32x2(params.iPxHrPos)) * (1.0f - max(params.fShadingChange * 0, params.fReactiveMask));
    (*data).fLock = max(0.0f, min((*data).fLock + fNewLockIntensity, fLockMax));

    // Preparing for next frame
    var fLifetimeDecrease: FfxFloat32 = (0.1f / JitterSequenceLength()) * (1.0f - fLifetimeDecreaseFactor);
    (*data).fLock = max(0.0f, (*data).fLock - fLifetimeDecrease);

    // we expect similar motion for next frame
    // kill lock if that location is outside screen, avoid locks to be clamped to screen borders
    var fEstimatedUvNextFrame: FfxFloat32x2 = params.fHrUv - params.fMotionVector;
    (*data).fLock *= FfxFloat32(IsUvInside(fEstimatedUvNextFrame) == true);
}

fn ComputeBaseAccumulationWeight(params: AccumulationPassCommonParams, data: ptr<function, AccumulationPassData>)
{
    var fBaseAccumulation: FfxFloat32 = params.fAccumulation;

    fBaseAccumulation = min(fBaseAccumulation, mix(fBaseAccumulation, 0.15f, ffxSaturate_f32(max(0.0f, (params.f4KVelocity * VelocityFactor()) / 0.5f))));

    (*data).fHistoryWeight = fBaseAccumulation;
}

fn InitPassData(iPxHrPos: FfxInt32x2, params: ptr<function, AccumulationPassCommonParams>, data: ptr<function, AccumulationPassData>)
{
    // Init constant (*params)
    (*params).iPxHrPos                     = iPxHrPos;
    var fHrUv: FfxFloat32x2 = (FfxFloat32x2(iPxHrPos) + 0.5f) / FfxFloat32x2(UpscaleSize());
    (*params).fHrUv                        = fHrUv;
    (*params).fLrUvJittered                = fHrUv + Jitter() / FfxFloat32x2(RenderSize());
    (*params).fLrUv_HwSampler              = ClampUv((*params).fLrUvJittered, RenderSize(), MaxRenderSize());

    (*params).fMotionVector                = GetMotionVector(iPxHrPos, fHrUv);
    (*params).f4KVelocity                  = Get4KVelocity((*params).fMotionVector);

    ComputeReprojectedUVs(params);

    var fLumaInstabilityUv_HW: FfxFloat32x2 = ClampUv(fHrUv, RenderSize(), MaxRenderSize());
    (*params).fLumaInstabilityFactor       = SampleLumaInstability(fLumaInstabilityUv_HW);

    var fFarthestDepthUv: FfxFloat32x2 = ClampUv((*params).fLrUvJittered, RenderSize() / 2, GetFarthestDepthMip1ResourceDimensions());
    (*params).fFarthestDepthInMeters       = SampleFarthestDepthMip1(fFarthestDepthUv);
    (*params).bIsNewSample                 = ((*params).bIsExistingSample == false || 0 == FrameIndex());

    var fDilatedReactiveMasks: FfxFloat32x4 = SampleDilatedReactiveMasks((*params).fLrUv_HwSampler);
    (*params).fReactiveMask                = ffxSaturate_f32(fDilatedReactiveMasks[REACTIVE]);
    (*params).fDisocclusion                = ffxSaturate_f32(fDilatedReactiveMasks[DISOCCLUSION]);
    (*params).fShadingChange               = ffxSaturate_f32(fDilatedReactiveMasks[SHADING_CHANGE]);
    (*params).fAccumulation                = ffxSaturate_f32(fDilatedReactiveMasks[ACCUMULAION]);
    (*params).fAccumulation *= FfxFloat32(round((*params).fAccumulation * 100.0f) > 1.0f);

    // Init variable (*data)
    (*data).fUpsampledColor                = FfxFloat32x3(0.0f, 0.0f, 0.0f);
    (*data).fHistoryColor                  = FfxFloat32x3(0.0f, 0.0f, 0.0f);
    (*data).fHistoryWeight                 = 1.0f;
    (*data).fUpsampledWeight               = 0.0f;
    (*data).fLock                          = 0.0f;
    (*data).fLockContributionThisFrame     = 0.0f;
}

fn Accumulate_i32x2(iPxHrPos: FfxInt32x2)
{
    var params: AccumulationPassCommonParams ;
    var data: AccumulationPassData ;
    InitPassData(iPxHrPos, &(params), &(data));

    if (params.bIsExistingSample && !params.bIsNewSample) {
        ReprojectHistoryColor(params, &(data));
    }
    
    UpdateLockStatus(params, &(data));

    ComputeBaseAccumulationWeight(params, &(data));

    ComputeUpsampledColorAndWeight(params, &(data));

    RectifyHistory(params, &(data));

    Accumulate_AccumulationPassCommonParams_AccumulationPassData(params, &data);

    data.fHistoryColor /= Exposure();

    data.fHistoryColor = max(data.fHistoryColor, FfxFloat32x3(0.0f, 0.0f, 0.0f));

    StoreInternalColorAndWeight(FfxUInt32x2(iPxHrPos), FfxFloat32x4(data.fHistoryColor, data.fLock));

    // Output final color when RCAS is disabled
#if FFX_FSR3UPSCALER_OPTION_APPLY_SHARPENING == 0
    StoreUpscaledOutput(FfxUInt32x2(iPxHrPos), data.fHistoryColor);
#endif
    StoreNewLocks(FfxUInt32x2(iPxHrPos), 0);
}
