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

// WGSL port of ffx_frameinterpolation_game_motion_vector_field.h.

#ifndef FFX_FRAMEINTERPOLATION_GAME_MOTION_VECTOR_FIELD_H
#define FFX_FRAMEINTERPOLATION_GAME_MOTION_VECTOR_FIELD_H

fn getPriorityFactorFromViewSpaceDepth(fViewSpaceDepthInMeters_in: FfxFloat32) -> FfxUInt32
{
    var fViewSpaceDepthInMeters: FfxFloat32 = fViewSpaceDepthInMeters_in;
    fViewSpaceDepthInMeters = pow(fViewSpaceDepthInMeters, 0.33f);

    var uPriorityFactor: FfxUInt32 = FfxUInt32(FfxFloat32(1 - (fViewSpaceDepthInMeters * (1.0f / (1.0f + fViewSpaceDepthInMeters)))) * FfxFloat32(PRIORITY_HIGH_MAX));

    return max(1, uPriorityFactor);
}

fn computeGameFieldMvs(iPxPos: FfxInt32x2)
{
    let fUvInScreenSpace: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(RenderSize());

    let fDistortionFieldUv: FfxFloat32x2 = SampleDistortionField(fUvInScreenSpace);
    var iDistortionPixelOffset: FfxInt32x2              = FfxInt32x2(fDistortionFieldUv.xy * FfxFloat32x2(RenderSize()));

    let fUvInInterpolationRectStart: FfxFloat32x2 = FfxFloat32x2(InterpolationRectBase()) / FfxFloat32x2(DisplaySize());
    let fUvLetterBoxScale: FfxFloat32x2 = FfxFloat32x2(InterpolationRectSize()) / FfxFloat32x2(DisplaySize());
    let fUvInInterpolationRect: FfxFloat32x2 = fUvInInterpolationRectStart + fUvInScreenSpace * fUvLetterBoxScale;

    let fDepthSample: FfxFloat32 = LoadDilatedDepth(iPxPos + iDistortionPixelOffset);
    let fGameMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(iPxPos + iDistortionPixelOffset);
    let fMotionVectorHalf: FfxFloat32x2 = fGameMotionVector * 0.5f;
    let fInterpolatedLocationUv: FfxFloat32x2 = fUvInScreenSpace + fMotionVectorHalf;

    let fViewSpaceDepth: FfxFloat32 = ConvertFromDeviceDepthToViewSpace(fDepthSample);
    let uHighPriorityFactorPrimary: FfxUInt32 = getPriorityFactorFromViewSpaceDepth(fViewSpaceDepth);

    // pixel position in current frame + Game Motion Vector -> pixel position in previous frame
    var prevBackbufferCol: FfxFloat32x3 = SamplePreviousBackbuffer(fUvInInterpolationRect+ fGameMotionVector * fUvLetterBoxScale).xyz; //returns color of current frame's pixel in previous frame buffer
    var curBackbufferCol: FfxFloat32x3  = SampleCurrentBackbuffer(fUvInInterpolationRect).xyz; // returns color of current frame's pixel in current frame buffer
    var prevLuma: FfxFloat32          = 0.001f + RawRGBToLuminance(prevBackbufferCol);
    var currLuma: FfxFloat32          = 0.001f + RawRGBToLuminance(curBackbufferCol);

    var uLowPriorityFactor: FfxUInt32 = FfxUInt32(round(pow(MinDividedByMax(prevLuma, currLuma), 1.0f / 1.0f) * FfxFloat32(PRIORITY_LOW_MAX)))
    * FfxUInt32(IsUvInside(fUvInInterpolationRect + fGameMotionVector * fUvLetterBoxScale));

    // Update primary motion vectors
    {
        let packedVectorPrimary: FfxUInt32x2 = PackVectorFieldEntries(true, uHighPriorityFactorPrimary, uLowPriorityFactor, fMotionVectorHalf);

        var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fInterpolatedLocationUv, RenderSize());
        for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++)
        {
            let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
            let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

            if (IsOnScreen(iSamplePos, RenderSize()))
            {
                UpdateGameMotionVectorField(iSamplePos, packedVectorPrimary);
            }
        }
    }

    // Update secondary vectors
    // Main purpose of secondary vectors is to improve quality of inpainted vectors
    let bWriteSecondaryVectors: FfxBoolean = length(fMotionVectorHalf * FfxFloat32x2(RenderSize())) > FFX_FRAMEINTERPOLATION_EPSILON;
    if (bWriteSecondaryVectors)
    {
        var bWriteSecondary: FfxBoolean = true;
        var uNumPrimaryHits: FfxUInt32 = 0;
        let fSecondaryStepScale: FfxFloat32 = length(1.0f / FfxFloat32x2(RenderSize()));
        let fStepMv: FfxFloat32x2 = normalize(fGameMotionVector);
        let fBreakDist: FfxFloat32 = min(length(fMotionVectorHalf), length(FfxFloat32x2(0.5f, 0.5f)));

        for (var fMvScale: FfxFloat32 = fSecondaryStepScale; fMvScale <= fBreakDist && bWriteSecondary; fMvScale += fSecondaryStepScale)
        {
            let fSecondaryLocationUv: FfxFloat32x2 = fInterpolatedLocationUv - fStepMv * fMvScale;
            var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fSecondaryLocationUv, RenderSize());

            // Reverse depth prio for secondary vectors
            var uHighPriorityFactorSecondary: FfxUInt32 = max(1, PRIORITY_HIGH_MAX - uHighPriorityFactorPrimary);

            let fToCenter: FfxFloat32x2 = normalize(FfxFloat32x2(0.5f, 0.5f) - fSecondaryLocationUv);
            uLowPriorityFactor = FfxUInt32(max(0.0f, dot(fToCenter, fStepMv)) * FfxFloat32(PRIORITY_LOW_MAX));
            let packedVectorSecondary: FfxUInt32x2 = PackVectorFieldEntries(false, uHighPriorityFactorSecondary, uLowPriorityFactor, fMotionVectorHalf);

            // Only write secondary mvs to single bilinear location
            for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 1; iSampleIndex++)
            {
                let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
                let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

                bWriteSecondary = bWriteSecondary && IsOnScreen(iSamplePos, RenderSize());

                if (bWriteSecondary)
                {
                    let uExistingVectorFieldEntry: FfxUInt32 = UpdateGameMotionVectorFieldEx(iSamplePos, packedVectorSecondary);

                    uNumPrimaryHits += FfxUInt32(PackedVectorFieldEntryIsPrimary(uExistingVectorFieldEntry));
                    bWriteSecondary = bWriteSecondary && (uNumPrimaryHits <= 3);
                }
            }
        }
    }
}

#endif // FFX_FRAMEINTERPOLATION_GAME_MOTION_VECTOR_FIELD_H
