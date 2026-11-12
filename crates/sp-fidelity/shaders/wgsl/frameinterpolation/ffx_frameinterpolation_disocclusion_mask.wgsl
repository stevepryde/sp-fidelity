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

// WGSL port of ffx_frameinterpolation_disocclusion_mask.h.

#ifndef FFX_FRAMEINTERPOLATION_DISOCCLUSION_MASK_H
#define FFX_FRAMEINTERPOLATION_DISOCCLUSION_MASK_H

const DepthClipBaseScale: FfxFloat32 = 1.0f;

fn ComputeSampleDepthClip(iPxSamplePos: FfxInt32x2, fPreviousDepth: FfxFloat32, fPreviousDepthBilinearWeight: FfxFloat32, fCurrentDepthViewSpace: FfxFloat32) -> FfxFloat32
{
    var fPrevNearestDepthViewSpace: FfxFloat32 = ConvertFromDeviceDepthToViewSpace(fPreviousDepth);

    // Depth separation logic ref: See "Minimum Triangle Separation for Correct Z-Buffer Occlusion"
    // Intention: worst case of formula in Figure4 combined with Ksep factor in Section 4
    let fHalfViewportWidth: FfxFloat32 = FfxFloat32(RenderSize().x) * 0.5f;
    var fDepthThreshold: FfxFloat32    = max(fCurrentDepthViewSpace, fPrevNearestDepthViewSpace);

    // WARNING: Ksep only works with reversed-z with infinite projection.
    let Ksep: FfxFloat32 = 1.37e-05f;
    var fRequiredDepthSeparation: FfxFloat32 = Ksep * fDepthThreshold * TanHalfFoV() * fHalfViewportWidth;
    var fDepthDiff: FfxFloat32               = fCurrentDepthViewSpace - fPrevNearestDepthViewSpace;

    var fDepthClipFactor: FfxFloat32 = select(1.0, ffxSaturate_f32(fRequiredDepthSeparation / fDepthDiff), fDepthDiff > 0.0);

    return fPreviousDepthBilinearWeight * fDepthClipFactor * mix(1.0f, DepthClipBaseScale, ffxSaturate_f32(fDepthDiff * fDepthDiff));
}

fn LoadEstimatedDepth(estimatedIndex_in: FfxUInt32, iSamplePos: FfxInt32x2) -> FfxFloat32
{
    var estimatedIndex: FfxUInt32 = estimatedIndex_in;
    let fUv: FfxFloat32x2 = FfxFloat32x2(FfxFloat32x2(iSamplePos) + 0.5f) / FfxFloat32x2(RenderSize());
    let fDistortionFieldUv: FfxFloat32x2 = SampleDistortionField(fUv);
    var iDistortionPixelOffset: FfxInt32x2 = FfxInt32x2(fDistortionFieldUv.xy * FfxFloat32x2(RenderSize()));

    if (estimatedIndex == 0)
    {
        return LoadReconstructedDepthPreviousFrame(iSamplePos + iDistortionPixelOffset);
    }
    else if (estimatedIndex == 1)
    {
        return LoadDilatedDepth(iSamplePos + iDistortionPixelOffset);
    }

    return 0;
}

fn ComputeDepthClip(estimatedIndex: FfxUInt32, fUvSample: FfxFloat32x2, fCurrentDepthSample: FfxFloat32) -> FfxFloat32
{
    var fCurrentDepthViewSpace: FfxFloat32 = ConvertFromDeviceDepthToViewSpace(fCurrentDepthSample);
    var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fUvSample, RenderSize());

    var fDilatedSum: FfxFloat32 = 0.0f;
    var fDepth: FfxFloat32 = 0.0f;
    var fWeightSum: FfxFloat32 = 0.0f;
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++) {

        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

        if (IsOnScreen(iSamplePos, RenderSize())) {
            let fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];
            if (fWeight > fReconstructedDepthBilinearWeightThreshold) {

                let fPrevDepthSample: FfxFloat32 = LoadEstimatedDepth(estimatedIndex, iSamplePos);
                let fPrevNearestDepthViewSpace: FfxFloat32 = ConvertFromDeviceDepthToViewSpace(fPrevDepthSample);

                let fDepthDiff: FfxFloat32 = fCurrentDepthViewSpace - fPrevNearestDepthViewSpace;

                if (fDepthDiff > 0.0f) {

#if FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
                    let fPlaneDepth: FfxFloat32 = min(fPrevDepthSample, fCurrentDepthSample);
#else
                    let fPlaneDepth: FfxFloat32 = max(fPrevDepthSample, fCurrentDepthSample);
#endif

                    let fCenter: FfxFloat32x3 = GetViewSpacePosition(FfxInt32x2(FfxFloat32x2(RenderSize()) * 0.5f), RenderSize(), fPlaneDepth);
                    let fCorner: FfxFloat32x3 = GetViewSpacePosition(FfxInt32x2(0, 0), RenderSize(), fPlaneDepth);

                    let fHalfViewportWidth: FfxFloat32 = length(FfxFloat32x2(RenderSize()));
                    let fDepthThreshold: FfxFloat32 = min(fCurrentDepthViewSpace, fPrevNearestDepthViewSpace);

                    let Ksep: FfxFloat32 = 1.37e-05f;
                    let Kfov: FfxFloat32 = length(fCorner) / length(fCenter);
                    let fRequiredDepthSeparation: FfxFloat32 = Ksep * Kfov * fHalfViewportWidth * fDepthThreshold;

                    let fResolutionFactor: FfxFloat32 = ffxSaturate_f32(length(FfxFloat32x2(RenderSize())) / length(FfxFloat32x2(1920.0f, 1080.0f)));
                    let fPower: FfxFloat32 = mix(1.0f, 3.0f, fResolutionFactor);

                    fDepth += FfxFloat32((fRequiredDepthSeparation / fDepthDiff) >= 1.0f) * fWeight;
                    fWeightSum += fWeight;
                }
            }
        }
    }

    return select(0.0, ffxSaturate_f32(1.0f - fDepth / fWeightSum), fWeightSum > 0.0);
}

fn computeDisocclusionMask(iPxPos: FfxInt32x2)
{
    var fDilatedDepth: FfxFloat32 = LoadEstimatedInterpolationFrameDepth(iPxPos);

    var fDepthUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(RenderSize());
    var fCurrentDepthViewSpace: FfxFloat32 = ConvertFromDeviceDepthToViewSpace(fDilatedDepth);

    var gameMv: VectorFieldEntry;
    LoadInpaintedGameFieldMv(fDepthUv, &gameMv);

    let fDepthClipInterpolatedToPrevious: FfxFloat32 = 1.0f - ComputeDepthClip(0, fDepthUv + gameMv.fMotionVector, fDilatedDepth);
    let fDepthClipInterpolatedToCurrent: FfxFloat32 = 1.0f - ComputeDepthClip(1, fDepthUv - gameMv.fMotionVector, fDilatedDepth);
    var fDisocclusionMask: FfxFloat32x2 = FfxFloat32x2(fDepthClipInterpolatedToPrevious, fDepthClipInterpolatedToCurrent);

    fDisocclusionMask = FfxFloat32x2((fDisocclusionMask >=  FfxFloat32x2(FFX_FRAMEINTERPOLATION_EPSILON)));

    // Avoid false disocclusion if primary game vector pointer outside screen area
    let fSrcMotionVector: FfxFloat32x2 = gameMv.fMotionVector * 2.0f;
    let iSamplePosPrevious: FfxInt32x2 = FfxInt32x2((fDepthUv + fSrcMotionVector) * FfxFloat32x2(RenderSize()));
    fDisocclusionMask.x = ffxSaturate_f32(fDisocclusionMask.x + FfxFloat32(!IsOnScreen(iSamplePosPrevious, RenderSize())));

    let iSamplePosCurrent: FfxInt32x2 = FfxInt32x2((fDepthUv - fSrcMotionVector) * FfxFloat32x2(RenderSize()));
    fDisocclusionMask.y = ffxSaturate_f32(fDisocclusionMask.y + FfxFloat32(!IsOnScreen(iSamplePosCurrent, RenderSize())));

#if defined(FFX_FRAMEINTERPOLATION_EDGE_VISIBILITY)
    // Camera-supported extension only clears visibility; the unchanged SDK
    // pass and dynamic current-primary decisions remain authoritative otherwise.
    fDisocclusionMask.x *= EdgePreviousVisibility(fDepthUv, gameMv, fDilatedDepth);
#endif
    StoreDisocclusionMask(iPxPos, fDisocclusionMask);

}

#endif // FFX_FRAMEINTERPOLATION_DISOCCLUSION_MASK_H
