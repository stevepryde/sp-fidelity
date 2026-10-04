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

// WGSL port of ffx_fsr2_accumulate.h. Overloads carry parameter-type suffixes
// (see ffx_core.wgsl); FFX_PARAMETER_OUT/INOUT parameters are function
// pointers. HLSL's implicit int-to-uint, int-to-float and float-to-half
// conversions are written out; a scalar's .xxx/.www splat is the vector
// constructor.

#ifndef FFX_FSR2_ACCUMULATE_H
#define FFX_FSR2_ACCUMULATE_H

fn GetPxHrVelocity_f32x2(fMotionVector: FfxFloat32x2) -> FfxFloat32
{
    return length(fMotionVector * FfxFloat32x2(DisplaySize()));
}
#if FFX_HALF
fn GetPxHrVelocity_f16x2(fMotionVector: FFX_MIN16_F2) -> FFX_MIN16_F
{
    return length(fMotionVector * FFX_MIN16_F2(DisplaySize()));
}
#endif

// WGSL: parameters are immutable; the SDK assigns its by-value fAccumulation
// and fUpsampledColorAndWeight, so they are locals initialized from the
// parameters fAccumulation_ and fUpsampledColorAndWeight_.
fn Accumulate_AccumulationPassCommonParams_f32x3_f32x3_f32x4(params: AccumulationPassCommonParams, fHistoryColor: ptr<function, FfxFloat32x3>, fAccumulation_: FfxFloat32x3, fUpsampledColorAndWeight_: FfxFloat32x4)
{
    var fAccumulation: FfxFloat32x3 = fAccumulation_;
    var fUpsampledColorAndWeight: FfxFloat32x4 = fUpsampledColorAndWeight_;

    // Avoid invalid values when accumulation and upsampled weight is 0
    fAccumulation = ffxMax_f32x3_f32x3(FfxFloat32x3(FSR2_EPSILON), fAccumulation + FfxFloat32x3(fUpsampledColorAndWeight.w));

#if FFX_FSR2_OPTION_HDR_COLOR_INPUT
    //YCoCg -> RGB -> Tonemap -> YCoCg (Use RGB tonemapper to avoid color desaturation)
    // WGSL: no assignment to a multi-component swizzle (fUpsampledColorAndWeight.xyz = ...).
    fUpsampledColorAndWeight = FfxFloat32x4(RGBToYCoCg_f32x3(Tonemap_f32x3(YCoCgToRGB_f32x3(fUpsampledColorAndWeight.xyz))), fUpsampledColorAndWeight.w);
    *fHistoryColor = RGBToYCoCg_f32x3(Tonemap_f32x3(YCoCgToRGB_f32x3(*fHistoryColor)));
#endif

    let fAlpha: FfxFloat32x3 = FfxFloat32x3(fUpsampledColorAndWeight.w) / fAccumulation;
    *fHistoryColor = ffxLerp_f32x3_f32x3_f32x3(*fHistoryColor, fUpsampledColorAndWeight.xyz, fAlpha);

    *fHistoryColor = YCoCgToRGB_f32x3(*fHistoryColor);

#if FFX_FSR2_OPTION_HDR_COLOR_INPUT
    *fHistoryColor = InverseTonemap_f32x3(*fHistoryColor);
#endif
}

fn RectifyHistory(
    params: AccumulationPassCommonParams,
    clippingBox: RectificationBox,
    fHistoryColor: ptr<function, FfxFloat32x3>,
    fAccumulation: ptr<function, FfxFloat32x3>,
    fLockContributionThisFrame: FfxFloat32,
    fTemporalReactiveFactor: FfxFloat32,
    fLumaInstabilityFactor: FfxFloat32)
{
    let fScaleFactorInfluence: FfxFloat32 = ffxMin_f32_f32(20.0f, ffxPow_f32_f32(FfxFloat32(1.0f / length(DownscaleFactor().x * DownscaleFactor().y)), 3.0f));

    let fHrVelocityFactor: FfxFloat32 = ffxSaturate_f32(params.fHrVelocity / 20.0f);
    let fBoxScaleT: FfxFloat32 = ffxMax_f32_f32(params.fDepthClipFactor, ffxMax_f32_f32(params.fAccumulationMask, fHrVelocityFactor));
    let fBoxScale: FfxFloat32 = ffxLerp_f32_f32_f32(fScaleFactorInfluence, 1.0f, fBoxScaleT);

    let fScaledBoxVec: FfxFloat32x3 = clippingBox.boxVec * fBoxScale;
    var boxMin: FfxFloat32x3 = clippingBox.boxCenter - fScaledBoxVec;
    var boxMax: FfxFloat32x3 = clippingBox.boxCenter + fScaledBoxVec;
    let boxCenter: FfxFloat32x3 = clippingBox.boxCenter;
    let boxVecSize: FfxFloat32 = length(clippingBox.boxVec);

    boxMin = ffxMax_f32x3_f32x3(clippingBox.aabbMin, boxMin);
    boxMax = ffxMin_f32x3_f32x3(clippingBox.aabbMax, boxMax);

    if (any(boxMin > *fHistoryColor) || any(*fHistoryColor > boxMax)) {

        let fClampedHistoryColor: FfxFloat32x3 = clamp(*fHistoryColor, boxMin, boxMax);

        var fHistoryContribution: FfxFloat32x3 = FfxFloat32x3(ffxMax_f32_f32(fLumaInstabilityFactor, fLockContributionThisFrame));

        let fReactiveFactor: FfxFloat32 = params.fDilatedReactiveFactor;
        let fReactiveContribution: FfxFloat32 = 1.0f - ffxPow_f32_f32(fReactiveFactor, 1.0f / 2.0f);
        fHistoryContribution *= fReactiveContribution;

        // Scale history color using rectification info, also using accumulation mask to avoid potential invalid color protection
        *fHistoryColor = ffxLerp_f32x3_f32x3_f32x3(fClampedHistoryColor, *fHistoryColor, ffxSaturate_f32x3(fHistoryContribution));

        // Scale accumulation using rectification info
        let fAccumulationMin: FfxFloat32x3 = ffxMin_f32x3_f32x3(*fAccumulation, FfxFloat32x3(0.1f));
        *fAccumulation = ffxLerp_f32x3_f32x3_f32x3(fAccumulationMin, *fAccumulation, ffxSaturate_f32x3(fHistoryContribution));
    }
}

fn WriteUpscaledOutput(iPxHrPos: FfxInt32x2, fUpscaledColor: FfxFloat32x3)
{
    StoreUpscaledOutput(FfxUInt32x2(iPxHrPos), fUpscaledColor);
}

// WGSL: parameters are immutable; the SDK assigns its by-value fLockStatus, so
// it is a local initialized from the parameter fLockStatus_.
fn FinalizeLockStatus(params: AccumulationPassCommonParams, fLockStatus_: FfxFloat32x2, fUpsampledWeight: FfxFloat32)
{
    var fLockStatus: FfxFloat32x2 = fLockStatus_;

    // we expect similar motion for next frame
    // kill lock if that location is outside screen, avoid locks to be clamped to screen borders
    let fEstimatedUvNextFrame: FfxFloat32x2 = params.fHrUv - params.fMotionVector;
    if (IsUvInside(fEstimatedUvNextFrame) == false) {
        KillLock_f32x2(&fLockStatus);
    }
    else {
        // Decrease lock lifetime
        let fLifetimeDecreaseLanczosMax: FfxFloat32 = FfxFloat32(JitterSequenceLength()) * FfxFloat32(fAverageLanczosWeightPerFrame);
        let fLifetimeDecrease: FfxFloat32 = FfxFloat32(fUpsampledWeight / fLifetimeDecreaseLanczosMax);
        fLockStatus[LOCK_LIFETIME_REMAINING] = ffxMax_f32_f32(FfxFloat32(0), fLockStatus[LOCK_LIFETIME_REMAINING] - fLifetimeDecrease);
    }

    StoreLockStatus(FfxUInt32x2(params.iPxHrPos), fLockStatus);
}


fn ComputeBaseAccumulationWeight(params: AccumulationPassCommonParams, fThisFrameReactiveFactor: FfxFloat32, bInMotionLastFrame: FfxBoolean, fUpsampledWeight: FfxFloat32, lockState: LockState) -> FfxFloat32x3
{
    // Always assume max accumulation was reached
    var fBaseAccumulation: FfxFloat32 = fMaxAccumulationLanczosWeight * FfxFloat32(params.bIsExistingSample) * (1.0f - fThisFrameReactiveFactor) * (1.0f - params.fDepthClipFactor);

    fBaseAccumulation = ffxMin_f32_f32(fBaseAccumulation, ffxLerp_f32_f32_f32(fBaseAccumulation, fUpsampledWeight * 10.0f, ffxMax_f32_f32(FfxFloat32(bInMotionLastFrame), ffxSaturate_f32(params.fHrVelocity * FfxFloat32(10)))));

    fBaseAccumulation = ffxMin_f32_f32(fBaseAccumulation, ffxLerp_f32_f32_f32(fBaseAccumulation, fUpsampledWeight, ffxSaturate_f32(params.fHrVelocity / FfxFloat32(20))));

    return FfxFloat32x3(fBaseAccumulation);
}

fn ComputeLumaInstabilityFactor(params: AccumulationPassCommonParams, clippingBox: RectificationBox, fThisFrameReactiveFactor: FfxFloat32, fLuminanceDiff: FfxFloat32) -> FfxFloat32
{
    let fUnormThreshold: FfxFloat32 = 1.0f / 255.0f;
    let N_MINUS_1: FfxInt32 = 0;
    let N_MINUS_2: FfxInt32 = 1;
    let N_MINUS_3: FfxInt32 = 2;
    let N_MINUS_4: FfxInt32 = 3;

    var fCurrentFrameLuma: FfxFloat32 = clippingBox.boxCenter.x;

#if FFX_FSR2_OPTION_HDR_COLOR_INPUT
    fCurrentFrameLuma = fCurrentFrameLuma / (1.0f + ffxMax_f32_f32(0.0f, fCurrentFrameLuma));
#endif

    fCurrentFrameLuma = round(fCurrentFrameLuma * 255.0f) / 255.0f;

    let bSampleLumaHistory: FfxBoolean = (ffxMax_f32_f32(ffxMax_f32_f32(params.fDepthClipFactor, params.fAccumulationMask), fLuminanceDiff) < 0.1f) && (params.bIsNewSample == false);
    // WGSL: select evaluates both operands (HLSL 2021's ?: only the chosen
    // one); SampleLumaHistory has no side effects.
    var fCurrentFrameLumaHistory: FfxFloat32x4 = select(FfxFloat32x4(0.0f), SampleLumaHistory(params.fReprojectedHrUv), bSampleLumaHistory);

    var fLumaInstability: FfxFloat32 = 0.0f;
    let fDiffs0: FfxFloat32 = (fCurrentFrameLuma - fCurrentFrameLumaHistory[N_MINUS_1]);

    var fMin: FfxFloat32 = abs(fDiffs0);

    if (fMin >= fUnormThreshold) {
        // WGSL: FFX_UNROLL, which the SDK leaves to the compiler here, saves
        // 0.05 ms at 1920x1080 on Apple M5 (SDK-P26).
        FFX_UNROLL
        for (var i: FfxInt32 = N_MINUS_2; i <= N_MINUS_4; i++) {
            let fDiffs1: FfxFloat32 = (fCurrentFrameLuma - fCurrentFrameLumaHistory[i]);

            // WGSL: sign returns the operand's float type, HLSL's an int; the
            // comparison is the same for every non-NaN operand.
            if (sign(fDiffs0) == sign(fDiffs1)) {

                // Scale difference to protect historically similar values
                let fMinBias: FfxFloat32 = 1.0f;
                fMin = ffxMin_f32_f32(fMin, abs(fDiffs1) * fMinBias);
            }
        }

        let fBoxSize: FfxFloat32       = clippingBox.boxVec.x;
        let fBoxSizeFactor: FfxFloat32 = ffxPow_f32_f32(ffxSaturate_f32(fBoxSize / 0.1f), 6.0f);

        fLumaInstability = FfxFloat32(fMin != abs(fDiffs0)) * fBoxSizeFactor;
        fLumaInstability = FfxFloat32(fLumaInstability > fUnormThreshold);

        fLumaInstability *= 1.0f - ffxMax_f32_f32(params.fAccumulationMask, ffxPow_f32_f32(fThisFrameReactiveFactor, 1.0f / 6.0f));
    }

    //shift history
    fCurrentFrameLumaHistory[N_MINUS_4] = fCurrentFrameLumaHistory[N_MINUS_3];
    fCurrentFrameLumaHistory[N_MINUS_3] = fCurrentFrameLumaHistory[N_MINUS_2];
    fCurrentFrameLumaHistory[N_MINUS_2] = fCurrentFrameLumaHistory[N_MINUS_1];
    fCurrentFrameLumaHistory[N_MINUS_1] = fCurrentFrameLuma;

    StoreLumaHistory(FfxUInt32x2(params.iPxHrPos), fCurrentFrameLumaHistory);

    return fLumaInstability * FfxFloat32(fCurrentFrameLumaHistory[N_MINUS_4] != 0);
}

fn ComputeTemporalReactiveFactor(params: AccumulationPassCommonParams, fTemporalReactiveFactor: FfxFloat32) -> FfxFloat32
{
    var fNewFactor: FfxFloat32 = ffxMin_f32_f32(0.99f, fTemporalReactiveFactor);

    fNewFactor = ffxMax_f32_f32(fNewFactor, ffxLerp_f32_f32_f32(fNewFactor, 0.4f, ffxSaturate_f32(params.fHrVelocity)));

    fNewFactor = ffxMax_f32_f32(fNewFactor * fNewFactor, ffxMax_f32_f32(params.fDepthClipFactor * 0.1f, params.fDilatedReactiveFactor));

    // Force reactive factor for new samples
    fNewFactor = select(fNewFactor, 1.0f, params.bIsNewSample);

    if (ffxSaturate_f32(params.fHrVelocity * 10.0f) >= 1.0f) {
        fNewFactor = ffxMax_f32_f32(FSR2_EPSILON, fNewFactor) * -1.0f;
    }

    return fNewFactor;
}

fn InitParams(iPxHrPos: FfxInt32x2) -> AccumulationPassCommonParams
{
    var params: AccumulationPassCommonParams;

    params.iPxHrPos = iPxHrPos;
    let fHrUv: FfxFloat32x2 = (FfxFloat32x2(iPxHrPos) + 0.5f) / FfxFloat32x2(DisplaySize());
    params.fHrUv = fHrUv;

    let fLrUvJittered: FfxFloat32x2 = fHrUv + Jitter() / FfxFloat32x2(RenderSize());
    params.fLrUv_HwSampler = ClampUv(fLrUvJittered, RenderSize(), MaxRenderSize());

    params.fMotionVector = GetMotionVector(iPxHrPos, fHrUv);
    params.fHrVelocity = GetPxHrVelocity_f32x2(params.fMotionVector);

    ComputeReprojectedUVs(params, &params.fReprojectedHrUv, &params.bIsExistingSample);

    params.fDepthClipFactor = ffxSaturate_f32(SampleDepthClip(params.fLrUv_HwSampler));

    let fDilatedReactiveMasks: FfxFloat32x2 = SampleDilatedReactiveMasks(params.fLrUv_HwSampler);
    params.fDilatedReactiveFactor = fDilatedReactiveMasks.x;
    params.fAccumulationMask = fDilatedReactiveMasks.y;
    params.bIsResetFrame = (0 == FrameIndex());

    params.bIsNewSample = (params.bIsExistingSample == false || params.bIsResetFrame);

    return params;
}

fn Accumulate_i32x2(iPxHrPos: FfxInt32x2)
{
    let params: AccumulationPassCommonParams = InitParams(iPxHrPos);

    var fHistoryColor: FfxFloat32x3 = FfxFloat32x3(0, 0, 0);
    var fLockStatus: FfxFloat32x2;
    InitializeNewLockSample_f32x2(&fLockStatus);

    var fTemporalReactiveFactor: FfxFloat32 = 0.0f;
    var bInMotionLastFrame: FfxBoolean = FFX_FALSE;
    var lockState: LockState = LockState(FFX_FALSE, FFX_FALSE);
    if (params.bIsExistingSample && !params.bIsResetFrame) {
        ReprojectHistoryColor(params, &fHistoryColor, &fTemporalReactiveFactor, &bInMotionLastFrame);
        lockState = ReprojectHistoryLockStatus(params, &fLockStatus);
    }

    var fThisFrameReactiveFactor: FfxFloat32 = ffxMax_f32_f32(params.fDilatedReactiveFactor, fTemporalReactiveFactor);

    var fLuminanceDiff: FfxFloat32 = 0.0f;
    var fLockContributionThisFrame: FfxFloat32 = 0.0f;
    UpdateLockStatus(params, &fThisFrameReactiveFactor, lockState, &fLockStatus, &fLockContributionThisFrame, &fLuminanceDiff);

    // Load upsampled input color
    var clippingBox: RectificationBox;
    let fUpsampledColorAndWeight: FfxFloat32x4 = ComputeUpsampledColorAndWeight(params, &clippingBox, fThisFrameReactiveFactor);

    let fLumaInstabilityFactor: FfxFloat32 = ComputeLumaInstabilityFactor(params, clippingBox, fThisFrameReactiveFactor, fLuminanceDiff);


    var fAccumulation: FfxFloat32x3 = ComputeBaseAccumulationWeight(params, fThisFrameReactiveFactor, bInMotionLastFrame, fUpsampledColorAndWeight.w, lockState);

    if (params.bIsNewSample) {
        fHistoryColor = YCoCgToRGB_f32x3(fUpsampledColorAndWeight.xyz);
    }
    else {
        RectifyHistory(params, clippingBox, &fHistoryColor, &fAccumulation, fLockContributionThisFrame, fThisFrameReactiveFactor, fLumaInstabilityFactor);

        Accumulate_AccumulationPassCommonParams_f32x3_f32x3_f32x4(params, &fHistoryColor, fAccumulation, fUpsampledColorAndWeight);
    }

    fHistoryColor = UnprepareRgb(fHistoryColor, Exposure());

    FinalizeLockStatus(params, fLockStatus, fUpsampledColorAndWeight.w);

    // Get new temporal reactive factor
    fTemporalReactiveFactor = ComputeTemporalReactiveFactor(params, fThisFrameReactiveFactor);

    StoreInternalColorAndWeight(FfxUInt32x2(iPxHrPos), FfxFloat32x4(fHistoryColor, fTemporalReactiveFactor));

    // Output final color when RCAS is disabled
#if FFX_FSR2_OPTION_APPLY_SHARPENING == 0
    WriteUpscaledOutput(iPxHrPos, fHistoryColor);
#endif
    StoreNewLocks(FfxUInt32x2(iPxHrPos), 0);
}

#endif // FFX_FSR2_ACCUMULATE_H
