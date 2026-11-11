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
fn ComputeDisocclusions(fUv: FfxFloat32x2, fMotionVector_: FfxFloat32x2, fCurrentDepthViewSpace: FfxFloat32) -> FfxFloat32
{
    var fMotionVector: FfxFloat32x2 = fMotionVector_;
    var fNearestDepthInMeters: FfxFloat32 = min(fCurrentDepthViewSpace * ViewSpaceToMetersFactor(), FSR3UPSCALER_FP16_MAX);
    var fReconstructedDeptMvThreshold: FfxFloat32 = ReconstructedDepthMvPxThreshold(fNearestDepthInMeters);

    fMotionVector *= FfxFloat32(Get4KVelocity(fMotionVector) > fReconstructedDeptMvThreshold);

    var fReprojectedUv: FfxFloat32x2 = fUv + fMotionVector;
    let bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fReprojectedUv, RenderSize());

    var fDisocclusion: FfxFloat32 = 0.0f;
    var fWeightSum: FfxFloat32 = 0.0f;
    var bPotentialDisocclusion: FfxBoolean = true;

    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4 && bPotentialDisocclusion; iSampleIndex++)
    {

        var iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        var iSamplePos: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(bilinearInfo.iBasePos, iOffset, FfxInt32x2(RenderSize()));

        if (IsOnScreen_i32x2_i32x2(iSamplePos, RenderSize())) {
            var fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];
            if (fWeight > fReconstructedDepthBilinearWeightThreshold) {

                var fPrevNearestDepthViewSpace: FfxFloat32 = GetViewSpaceDepth(LoadReconstructedPrevDepth(FfxUInt32x2(iSamplePos)));
                var fDepthDifference: FfxFloat32 = fCurrentDepthViewSpace - fPrevNearestDepthViewSpace;
                
                bPotentialDisocclusion = bPotentialDisocclusion && (fDepthDifference > FSR3UPSCALER_FP32_MIN);

                if (bPotentialDisocclusion) {
                    var fHalfViewportWidth: FfxFloat32 = length(FfxFloat32x2(RenderSize()) * 0.5f);
                    var fDepthThreshold: FfxFloat32 = max(fCurrentDepthViewSpace, fPrevNearestDepthViewSpace);

                    var Ksep: FfxFloat32 = 1.37e-05f;
                    var fRequiredDepthSeparation: FfxFloat32 = Ksep * fHalfViewportWidth * fDepthThreshold;

                    fDisocclusion += ffxSaturate_f32(FfxFloat32(fRequiredDepthSeparation / fDepthDifference)) * fWeight;
                    fWeightSum += fWeight;
                }
            }
        }
    }

    fDisocclusion = select(0.0f, ffxSaturate_f32(1.0f - fDisocclusion / fWeightSum), (bPotentialDisocclusion && fWeightSum > 0));

    return fDisocclusion;
}

fn ComputeMotionDivergence(fUv: FfxFloat32x2, fMotionVector: FfxFloat32x2, fCurrentDepthSample: FfxFloat32) -> FfxFloat32
{
    var iPxReprojectedPos: FfxInt32x2 = FfxInt32x2((fUv + fMotionVector) * FfxFloat32x2(RenderSize()));
    var fReprojectedDepth: FfxFloat32 = LoadDilatedDepth(FfxUInt32x2(iPxReprojectedPos));
    var fReprojectedMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(iPxReprojectedPos));

    var fReprojectedVelocity: FfxFloat32 = Get4KVelocity(fReprojectedMotionVector);
    var f4KVelocity: FfxFloat32 = Get4KVelocity(fMotionVector);

    var fMaxLen: FfxFloat32 = max(length(fMotionVector), length(fReprojectedMotionVector));

    var fNucleusDepthInMeters: FfxFloat32 = GetViewSpaceDepthInMeters(fReprojectedDepth);
    var fCurrentDepthInMeters: FfxFloat32 = GetViewSpaceDepthInMeters(fCurrentDepthSample);

    var fDistanceFactor: FfxFloat32 = MinDividedByMax_f32_f32(fNucleusDepthInMeters, fCurrentDepthInMeters);
    var fVelocityFactor: FfxFloat32 = ffxSaturate_f32(f4KVelocity / 10.0f);
    var fMotionVectorFieldConfidence: FfxFloat32 = (1.0f - ffxSaturate_f32(fReprojectedVelocity / f4KVelocity)) * fDistanceFactor * fVelocityFactor;

    return fMotionVectorFieldConfidence;
}

fn DilateReactiveMasks(iPxPos: FfxInt32x2, fUv: FfxFloat32x2) -> FfxFloat32
{
    var fDilatedReactiveMasks: FfxFloat32 = 0.0f;
    
    
    for (var y: FfxInt32 = -1; y <=1; y++)
    {
        
        for (var x: FfxInt32 = -1; x <= 1; x++)
        {
            var sampleCoord: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iPxPos, FfxInt32x2(x, y), FfxInt32x2(RenderSize()));
            fDilatedReactiveMasks = max(fDilatedReactiveMasks, LoadReactiveMask(FfxUInt32x2(sampleCoord)));
        }
    }

    return fDilatedReactiveMasks;
}

fn DilateTransparencyAndCompositionMasks(iPxPos: FfxInt32x2, fUv: FfxFloat32x2) -> FfxFloat32
{
    var fUvTransparencyAndCompositionMask: FfxFloat32x2 = ClampUv(fUv, RenderSize(), GetTransparencyAndCompositionMaskResourceDimensions());
    return SampleTransparencyAndCompositionMask(fUvTransparencyAndCompositionMask);
}

fn ComputeThinFeatureConfidence(iPxPos: FfxInt32x2) -> FfxFloat32
{
    /*
     1 2 3
     4 0 5
     6 7 8
    */

    const iNucleusIndex: FfxInt32 = 0;
    const iSampleCount: FfxInt32 = 9;
    var iSampleOffsets: array<FfxInt32x2, iSampleCount> = array<FfxInt32x2, iSampleCount>(
        FfxInt32x2(0,0),
        FfxInt32x2(-1, -1),
        FfxInt32x2(0, -1),
        FfxInt32x2(1, -1),
        FfxInt32x2(-1,0),
        FfxInt32x2(1,0),
        FfxInt32x2(-1,1),
        FfxInt32x2(0,1),
        FfxInt32x2(1,1),
    );

    var fSamples: array<FfxFloat32, iSampleCount> ;

    var fLumaMin: FfxFloat32 = FSR3UPSCALER_FP32_MAX;
    var fLumaMax: FfxFloat32 = FSR3UPSCALER_FP32_MIN;

    
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < iSampleCount; iSampleIndex++) {
        var iPxSamplePos: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(iPxPos, iSampleOffsets[iSampleIndex], FfxInt32x2(RenderSize()));
        fSamples[iSampleIndex]        = LoadCurrentLuma(FfxUInt32x2(iPxSamplePos)) * Exposure();

        fLumaMin = min(fLumaMin, fSamples[iSampleIndex]);
        fLumaMax = max(fLumaMax, fSamples[iSampleIndex]);
    }

    var fThreshold: FfxFloat32 = 0.9f;
    var fDissimilarLumaMin: FfxFloat32 = FSR3UPSCALER_FP32_MAX;
    var fDissimilarLumaMax: FfxFloat32 = 0;


    var uPatternMask: FfxUInt32 = (1u << FfxUInt32(iNucleusIndex)); // Flag nucleus as similar

    const uNumRejectionMasks: FfxUInt32 = 4;
    var uRejectionMasks: array<FfxUInt32, uNumRejectionMasks> = array<FfxUInt32, uNumRejectionMasks>(
        (1u << FfxUInt32(1)) | (1u << FfxUInt32(2)) | (1u << FfxUInt32(4)) | (1u << FfxUInt32(iNucleusIndex)), // Upper left
        (1u << FfxUInt32(2)) | (1u << FfxUInt32(3)) | (1u << FfxUInt32(5)) | (1u << FfxUInt32(iNucleusIndex)), // Upper right
        (1u << FfxUInt32(4)) | (1u << FfxUInt32(6)) | (1u << FfxUInt32(7)) | (1u << FfxUInt32(iNucleusIndex)), // Lower left
        (1u << FfxUInt32(5)) | (1u << FfxUInt32(7)) | (1u << FfxUInt32(8)) | (1u << FfxUInt32(iNucleusIndex))  // Lower right
    );

    
    
    for (var iSampleIndex: FfxInt32 = 1; iSampleIndex < iSampleCount; iSampleIndex++) {

        var fDifference: FfxFloat32 = abs(fSamples[iSampleIndex] - fSamples[iNucleusIndex]) / (fLumaMax - fLumaMin);

        if (fDifference < fThreshold)
        {
            uPatternMask |= (1u << FfxUInt32(iSampleIndex));
        }
        else
        {
            fDissimilarLumaMin = min(fDissimilarLumaMin, fSamples[iSampleIndex]);
            fDissimilarLumaMax = max(fDissimilarLumaMax, fSamples[iSampleIndex]);
        }
    }

    var bIsRidge: FfxBoolean = fSamples[iNucleusIndex] > fDissimilarLumaMax || fSamples[iNucleusIndex] < fDissimilarLumaMin;

    if (FFX_FALSE == bIsRidge)
    {
        return 0.0f;
    }

    
    for (var i: FfxInt32 = 0; i < FfxInt32(uNumRejectionMasks); i++)
    {
        if ((uPatternMask & uRejectionMasks[i]) == uRejectionMasks[i])
        {
            return 0.0f;
        }
    }

    return 1.0f - fLumaMin / fLumaMax;
}

fn UpdateAccumulation(iPxPos: FfxInt32x2, fUv: FfxFloat32x2, fMotionVector: FfxFloat32x2, fDisocclusion: FfxFloat32, fShadingChange: FfxFloat32) -> FfxFloat32
{
    var fReprojectedUv: FfxFloat32x2 = fUv + fMotionVector;
    var fAccumulation: FfxFloat32 = 0.0f;

    if (IsUvInside(fReprojectedUv)) {
        var fReprojectedUv_HW: FfxFloat32x2 = ClampUv(fReprojectedUv, PreviousFrameRenderSize(), MaxRenderSize());
        fAccumulation                        = ffxSaturate_f32(SampleAccumulation(fReprojectedUv_HW));
    }
    var fAccumulationAddedPerFrame: FfxFloat32 = AccumulationAddedPerFrame(); //default is 0.333

    // Assume at frame N+0 fShadingChange is 1.0, and all subsequent frames fShadingChange is 0.0 and fDisocclusion is 0.0. Then,
    // frame N+0 fAccumulation will be 0.000
    // frame N+2 fAccumulation will be 0.000 + 0.333 * 1 == 0.333
    // frame N+3 fAccumulation will be 0.000 + 0.333 * 2 == 0.666
    // frame N+4 fAccumulation will be 0.000 + 0.333 * 3 == 0.999
    fAccumulation = mix(fAccumulation, 0.0f, fShadingChange);

    var fMinDisocclusionAccumulation: FfxFloat32 = MinDisocclusionAccumulation(); //default is -0.333
    // Assume at frame N+0 fDisocclusion is 1.0, and all subsequent frames fShadingChange is 0.0 and fDisocclusion is 0.0. Then,
    // frame N+0 fAccumulation will be -0.333f (but normalized to store in unorm)
    // frame N+1 fAccumulation will be -0.333f + 0.333 * 1 == 0.000
    // frame N+2 fAccumulation will be -0.333f + 0.333 * 2 == 0.333
    // frame N+3 fAccumulation will be -0.333f + 0.333 * 3 == 0.666
    // frame N+4 fAccumulation will be -0.333f + 0.333 * 4 == 0.999
    fAccumulation = mix(fAccumulation, min(fMinDisocclusionAccumulation, fAccumulation), fDisocclusion);
    
    fAccumulation *= FfxFloat32(round(fAccumulation * 100.0f) > 1.0f);

    // Update for next frame, normalize to store in unorm
    var fAccumulatedFramesToStore: FfxFloat32 = ffxSaturate_f32(fAccumulation + fAccumulationAddedPerFrame);
    StoreAccumulation(FfxUInt32x2(iPxPos), fAccumulatedFramesToStore);

    return fAccumulation;
}

fn ComputeShadingChange(fUv: FfxFloat32x2) -> FfxFloat32
{
    // NOTE: Here we re-apply jitter, will be reverted again when sampled in accumulation pass
    var fShadingChangeUv: FfxFloat32x2 = ClampUv(fUv - Jitter() / FfxFloat32x2(RenderSize()), ShadingChangeRenderSize(), ShadingChangeMaxRenderSize());
    var fShadingChange: FfxFloat32 = ffxSaturate_f32(SampleShadingChange(fShadingChangeUv));

    return fShadingChange;
}

fn PrepareReactivity(iPxPos: FfxInt32x2)
{
    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(RenderSize());
    var fMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(iPxPos));

    // Discard small mvs
    var f4KVelocity: FfxFloat32 = Get4KVelocity(fMotionVector);

    var fDilatedUv: FfxFloat32x2 = fUv + fMotionVector;
    var fDilatedDepth: FfxFloat32 = LoadDilatedDepth(FfxUInt32x2(iPxPos));
    var fDepthInMeters: FfxFloat32 = GetViewSpaceDepthInMeters(fDilatedDepth);

    var fDisocclusion: FfxFloat32 = ComputeDisocclusions(fUv, fMotionVector, GetViewSpaceDepth(fDilatedDepth));
    var fShadingChange: FfxFloat32 = max(DilateReactiveMasks(iPxPos, fUv), ComputeShadingChange(fUv));

    var fMotionDivergence: FfxFloat32 = ComputeMotionDivergence(fUv, fMotionVector, fDilatedDepth);
    var fDilatedTransparencyAndComposition: FfxFloat32 = DilateTransparencyAndCompositionMasks(iPxPos, fUv);
    var fFinalReactiveness: FfxFloat32 = max(fMotionDivergence, fDilatedTransparencyAndComposition);

    var fAccumulation: FfxFloat32 = UpdateAccumulation(iPxPos, fUv, fMotionVector, fDisocclusion, fShadingChange);

    var fOutput: FfxFloat32x4 ;
    fOutput[REACTIVE]       = fFinalReactiveness;
    fOutput[DISOCCLUSION]   = fDisocclusion;
    fOutput[SHADING_CHANGE] = fShadingChange;
    fOutput[ACCUMULAION]    = fAccumulation;

    StoreDilatedReactiveMasks(FfxUInt32x2(iPxPos), fOutput);

    var fLockStrength: FfxFloat32 = ComputeThinFeatureConfidence(iPxPos);
    if (fLockStrength > (1.0f / 100.0f))
    {
        StoreNewLocks(FfxUInt32x2(ComputeHrPosFromLrPos_i32x2(FfxInt32x2(iPxPos))), fLockStrength);
    }
}
