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

// WGSL port of ffx_fsr2_depth_clip.h.
//
// WGSL: HLSL converts int2 arguments to the callbacks' FfxUInt32x2 and int2 to
// float2 in mixed arithmetic implicitly; here the conversions are written. The
// SDK's scalar cond ? a : b is select(b, a, cond); both sides are free of
// side effects.

#ifndef FFX_FSR2_DEPTH_CLIP_H
#define FFX_FSR2_DEPTH_CLIP_H

const DepthClipBaseScale: FfxFloat32 = 4.0f;

fn ComputeDepthClip(fUvSample: FfxFloat32x2, fCurrentDepthSample: FfxFloat32) -> FfxFloat32
{
    let fCurrentDepthViewSpace: FfxFloat32 = GetViewSpaceDepth(fCurrentDepthSample);
    let bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fUvSample, RenderSize());

    var fDilatedSum: FfxFloat32 = 0.0f;
    var fDepth: FfxFloat32 = 0.0f;
    var fWeightSum: FfxFloat32 = 0.0f;
    // WGSL: FFX_UNROLL, which the SDK leaves to the compiler here, saves
    // 0.07 ms at 1920x1080 on Apple M5 (SDK-P26).
    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++) {

        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

        if (IsOnScreen_i32x2_i32x2(iSamplePos, RenderSize())) {
            let fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];
            if (fWeight > fReconstructedDepthBilinearWeightThreshold) {

                let fPrevDepthSample: FfxFloat32 = LoadReconstructedPrevDepth(FfxUInt32x2(iSamplePos));
                let fPrevNearestDepthViewSpace: FfxFloat32 = GetViewSpaceDepth(fPrevDepthSample);

                let fDepthDiff: FfxFloat32 = fCurrentDepthViewSpace - fPrevNearestDepthViewSpace;

                if (fDepthDiff > 0.0f) {

#if FFX_FSR2_OPTION_INVERTED_DEPTH
                    let fPlaneDepth: FfxFloat32 = ffxMin_f32_f32(fPrevDepthSample, fCurrentDepthSample);
#else
                    let fPlaneDepth: FfxFloat32 = ffxMax_f32_f32(fPrevDepthSample, fCurrentDepthSample);
#endif
                    
                    let fCenter: FfxFloat32x3 = GetViewSpacePosition(FfxInt32x2(FfxFloat32x2(RenderSize()) * 0.5f), RenderSize(), fPlaneDepth);
                    let fCorner: FfxFloat32x3 = GetViewSpacePosition(FfxInt32x2(0, 0), RenderSize(), fPlaneDepth);

                    let fHalfViewportWidth: FfxFloat32 = length(FfxFloat32x2(RenderSize()));
                    let fDepthThreshold: FfxFloat32 = ffxMax_f32_f32(fCurrentDepthViewSpace, fPrevNearestDepthViewSpace);

                    let Ksep: FfxFloat32 = 1.37e-05f;
                    let Kfov: FfxFloat32 = length(fCorner) / length(fCenter);
                    let fRequiredDepthSeparation: FfxFloat32 = Ksep * Kfov * fHalfViewportWidth * fDepthThreshold;

                    let fResolutionFactor: FfxFloat32 = ffxSaturate_f32(length(FfxFloat32x2(RenderSize())) / length(FfxFloat32x2(1920.0f, 1080.0f)));
                    let fPower: FfxFloat32 = ffxLerp_f32_f32_f32(1.0f, 3.0f, fResolutionFactor);
                    fDepth += ffxPow_f32_f32(ffxSaturate_f32(FfxFloat32(fRequiredDepthSeparation / fDepthDiff)), fPower) * fWeight;
                    fWeightSum += fWeight;
                }
            }
        }
    }

    return select(0.0f, ffxSaturate_f32(1.0f - fDepth / fWeightSum), (fWeightSum > 0));
}

fn ComputeMotionDivergence(iPxPos: FfxInt32x2, iPxInputMotionVectorSize: FfxInt32x2) -> FfxFloat32
{
    var minconvergence: FfxFloat32 = 1.0f;

    let fMotionVectorNucleus: FfxFloat32x2 = LoadInputMotionVector(FfxUInt32x2(iPxPos));
    let fNucleusVelocityLr: FfxFloat32 = length(fMotionVectorNucleus * FfxFloat32x2(RenderSize()));
    var fMaxVelocityUv: FfxFloat32 = length(fMotionVectorNucleus);

    let MotionVectorVelocityEpsilon: FfxFloat32 = 1e-02f;

    if (fNucleusVelocityLr > MotionVectorVelocityEpsilon) {
        // WGSL: FFX_UNROLL, which the SDK leaves to the compiler here, saves
        // 0.35 ms at 1920x1080 on Apple M5 (SDK-P26).
        FFX_UNROLL
        for (var y: FfxInt32 = -1; y <= 1; y++) {
            FFX_UNROLL
            for (var x: FfxInt32 = -1; x <= 1; x++) {

                let sp: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iPxPos, FfxInt32x2(x, y), iPxInputMotionVectorSize);

                let fMotionVector: FfxFloat32x2 = LoadInputMotionVector(FfxUInt32x2(sp));
                var fVelocityUv: FfxFloat32 = length(fMotionVector);

                fMaxVelocityUv = ffxMax_f32_f32(fVelocityUv, fMaxVelocityUv);
                fVelocityUv = ffxMax_f32_f32(fVelocityUv, fMaxVelocityUv);
                minconvergence = ffxMin_f32_f32(minconvergence, dot(fMotionVector / fVelocityUv, fMotionVectorNucleus / fVelocityUv));
            }
        }
    }

    return ffxSaturate_f32(1.0f - minconvergence) * ffxSaturate_f32(fMaxVelocityUv / 0.01f);
}

fn ComputeDepthDivergence(iPxPos: FfxInt32x2) -> FfxFloat32
{
    let fMaxDistInMeters: FfxFloat32 = GetMaxDistanceInMeters();
    var fDepthMax: FfxFloat32 = 0.0f;
    var fDepthMin: FfxFloat32 = fMaxDistInMeters;

    var iMaxDistFound: FfxInt32 = 0;

    // WGSL: FFX_UNROLL, which the SDK leaves to the compiler here, saves
    // 0.30 ms at 1920x1080 on Apple M5 (SDK-P26).
    FFX_UNROLL
    for (var y: FfxInt32 = -1; y < 2; y++) {
        FFX_UNROLL
        for (var x: FfxInt32 = -1; x < 2; x++) {

            let iOffset: FfxInt32x2 = FfxInt32x2(x, y);
            let iSamplePos: FfxInt32x2 = iPxPos + iOffset;

            let fOnScreenFactor: FfxFloat32 = select(0.0f, 1.0f, IsOnScreen_i32x2_i32x2(iSamplePos, RenderSize()));
            let fDepth: FfxFloat32 = GetViewSpaceDepthInMeters(LoadDilatedDepth(FfxUInt32x2(iSamplePos))) * fOnScreenFactor;

            iMaxDistFound |= FfxInt32(fMaxDistInMeters == fDepth);

            fDepthMin = ffxMin_f32_f32(fDepthMin, fDepth);
            fDepthMax = ffxMax_f32_f32(fDepthMax, fDepth);
        }
    }

    return (1.0f - fDepthMin / fDepthMax) * select(1.0f, 0.0f, FfxBoolean(iMaxDistFound));
}

fn ComputeTemporalMotionDivergence(iPxPos: FfxInt32x2) -> FfxFloat32
{
    let fUv: FfxFloat32x2 = FfxFloat32x2(FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(RenderSize());

    let fMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(iPxPos));
    var fReprojectedUv: FfxFloat32x2 = fUv + fMotionVector;
    fReprojectedUv = ClampUv(fReprojectedUv, RenderSize(), MaxRenderSize());
    let fPrevMotionVector: FfxFloat32x2 = SamplePreviousDilatedMotionVector(fReprojectedUv);

    let fPxDistance: f32 = length(fMotionVector * FfxFloat32x2(DisplaySize()));
    return select(FfxFloat32(0), ffxLerp_f32_f32_f32(0.0f, 1.0f - ffxSaturate_f32(length(fPrevMotionVector) / length(fMotionVector)), ffxSaturate_f32(ffxPow_f32_f32(fPxDistance / 20.0f, 3.0f))), fPxDistance > 1.0f);
}

fn PreProcessReactiveMasks(iPxLrPos: FfxInt32x2, fMotionDivergence: FfxFloat32)
{
    // Compensate for bilinear sampling in accumulation pass

    let fReferenceColor: FfxFloat32x3 = LoadInputColor(FfxUInt32x2(iPxLrPos)).xyz;
    var fReactiveFactor: FfxFloat32x2 = FfxFloat32x2(0.0f, fMotionDivergence);

    var fMasksSum: f32 = 0.0f;

    var fColorSamples: array<FfxFloat32x3, 9>;
    var fReactiveSamples: array<FfxFloat32, 9>;
    var fTransparencyAndCompositionSamples: array<FfxFloat32, 9>;

    FFX_UNROLL
    for (var y: FfxInt32 = -1; y < 2; y++) {
        FFX_UNROLL
        for (var x: FfxInt32 = -1; x < 2; x++) {

            let sampleCoord: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iPxLrPos, FfxInt32x2(x, y), FfxInt32x2(RenderSize()));

            let sampleIdx: FfxInt32 = (y + 1) * 3 + x + 1;

            let fColorSample: FfxFloat32x3 = LoadInputColor(FfxUInt32x2(sampleCoord)).xyz;
            let fReactiveSample: FfxFloat32 = LoadReactiveMask(FfxUInt32x2(sampleCoord));
            let fTransparencyAndCompositionSample: FfxFloat32 = LoadTransparencyAndCompositionMask(FfxUInt32x2(sampleCoord));

            fColorSamples[sampleIdx] = fColorSample;
            fReactiveSamples[sampleIdx] = fReactiveSample;
            fTransparencyAndCompositionSamples[sampleIdx] = fTransparencyAndCompositionSample;

            fMasksSum += (fReactiveSample + fTransparencyAndCompositionSample);
        }
    }

    if (fMasksSum > 0)
    {
        for (var sampleIdx: FfxInt32 = 0; sampleIdx < 9; sampleIdx++)
        {
            let fColorSample: FfxFloat32x3 = fColorSamples[sampleIdx];
            let fReactiveSample: FfxFloat32 = fReactiveSamples[sampleIdx];
            let fTransparencyAndCompositionSample: FfxFloat32 = fTransparencyAndCompositionSamples[sampleIdx];

            let fMaxLenSq: FfxFloat32 = ffxMax_f32_f32(dot(fReferenceColor, fReferenceColor), dot(fColorSample, fColorSample));
            let fSimilarity: FfxFloat32 = dot(fReferenceColor, fColorSample) / fMaxLenSq;

            // Increase power for non-similar samples
            let fPowerBiasMax: FfxFloat32 = 6.0f;
            let fSimilarityPower: FfxFloat32 = 1.0f + (fPowerBiasMax - fSimilarity * fPowerBiasMax);
            let fWeightedReactiveSample: FfxFloat32 = ffxPow_f32_f32(fReactiveSample, fSimilarityPower);
            let fWeightedTransparencyAndCompositionSample: FfxFloat32 = ffxPow_f32_f32(fTransparencyAndCompositionSample, fSimilarityPower);

            fReactiveFactor = ffxMax_f32x2_f32x2(fReactiveFactor, FfxFloat32x2(fWeightedReactiveSample, fWeightedTransparencyAndCompositionSample));
        }
    }

    StoreDilatedReactiveMasks(FfxUInt32x2(iPxLrPos), fReactiveFactor);
}

fn ComputePreparedInputColor(iPxLrPos: FfxInt32x2) -> FfxFloat32x3
{
    //We assume linear data. if non-linear input (sRGB, ...),
    //then we should convert to linear first and back to sRGB on output.
    var fRgb: FfxFloat32x3 = ffxMax_f32x3_f32x3(FfxFloat32x3(0, 0, 0), LoadInputColor(FfxUInt32x2(iPxLrPos)));

    fRgb = PrepareRgb(fRgb, Exposure(), PreExposure());

    let fPreparedYCoCg: FfxFloat32x3 = RGBToYCoCg_f32x3(fRgb);

    return fPreparedYCoCg;
}

fn EvaluateSurface(iPxPos: FfxInt32x2, fMotionVector: FfxFloat32x2) -> FfxFloat32
{
    let d0: FfxFloat32 = GetViewSpaceDepth(LoadReconstructedPrevDepth(FfxUInt32x2(iPxPos + FfxInt32x2(0, -1))));
    let d1: FfxFloat32 = GetViewSpaceDepth(LoadReconstructedPrevDepth(FfxUInt32x2(iPxPos + FfxInt32x2(0, 0))));
    let d2: FfxFloat32 = GetViewSpaceDepth(LoadReconstructedPrevDepth(FfxUInt32x2(iPxPos + FfxInt32x2(0, 1))));

    return 1.0f - FfxFloat32(((d0 - d1) > (d1 * 0.01f)) && ((d1 - d2) > (d2 * 0.01f)));
}

fn DepthClip(iPxPos: FfxInt32x2)
{
    let fDepthUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(RenderSize());
    var fMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(iPxPos));

    // Discard tiny mvs
    fMotionVector *= FfxFloat32(length(fMotionVector * FfxFloat32x2(DisplaySize())) > 0.01f);

    let fDilatedUv: FfxFloat32x2 = fDepthUv + fMotionVector;
    let fDilatedDepth: FfxFloat32 = LoadDilatedDepth(FfxUInt32x2(iPxPos));
    // WGSL: the SDK's unused fCurrentDepthViewSpace =
    // GetViewSpaceDepth(LoadInputDepth(iPxPos)) (ffx_fsr2_depth_clip.h:239) is
    // omitted. DXC eliminates it, so the pass's DXC reflection, which the
    // SDK's generated binding tables and this port's blob accessor reproduce,
    // does not bind r_input_depth (t8), and a WGSL read of it would need a
    // binding the SDK host never provides.

    // Compute prepared input color and depth clip
    let fDepthClip: FfxFloat32 = ComputeDepthClip(fDilatedUv, fDilatedDepth) * EvaluateSurface(iPxPos, fMotionVector);
    let fPreparedYCoCg: FfxFloat32x3 = ComputePreparedInputColor(iPxPos);
    StorePreparedInputColor(FfxUInt32x2(iPxPos), FfxFloat32x4(fPreparedYCoCg, fDepthClip));

    // Compute dilated reactive mask
#if FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS
    let iSamplePos: FfxInt32x2 = iPxPos;
#else
    let iSamplePos: FfxInt32x2 = ComputeHrPosFromLrPos_i32x2(iPxPos);
#endif

    let fMotionDivergence: FfxFloat32 = ComputeMotionDivergence(iSamplePos, RenderSize());
    let fTemporalMotionDifference: FfxFloat32 = ffxSaturate_f32(ComputeTemporalMotionDivergence(iPxPos) - ComputeDepthDivergence(iPxPos));

    PreProcessReactiveMasks(iPxPos, ffxMax_f32_f32(fTemporalMotionDifference, fMotionDivergence));
}

#endif //!defined( FFX_FSR2_DEPTH_CLIPH )
