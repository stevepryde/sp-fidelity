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

// WGSL port of ffx_frameinterpolation_reconstruct_previous_depth.h.

#ifndef FFX_FRAMEINTERPOLATION_RECONSTRUCT_PREVIOUS_DEPTH_H
#define FFX_FRAMEINTERPOLATION_RECONSTRUCT_PREVIOUS_DEPTH_H

fn ReconstructPrevDepth(iPxPos: FfxInt32x2, depthTarget: FfxUInt32, fDepth: FfxFloat32, fMotionVector: FfxFloat32x2, iPxDepthSize: FfxInt32x2)
{
    let fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + FfxFloat32(0.5)) / FfxFloat32x2(iPxDepthSize);

    // Project current depth into previous frame locations.
    // Push to all pixels having some contribution if reprojection is using bilinear logic.
    var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fUv + fMotionVector, RenderSize());
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++)
    {
        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;
        let fSampleWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];

        if (fSampleWeight > fReconstructedDepthBilinearWeightThreshold)
        {
            if (IsOnScreen(iSamplePos, RenderSize()))
            {
                if (depthTarget != 0) {
                    UpdateReconstructedDepthInterpolatedFrame(iSamplePos, fDepth);
                }
            }
        }
    }
}

fn reconstructPreviousDepth(iPxPos: FfxInt32x2)
{
    let fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + FfxFloat32(0.5f)) / FfxFloat32x2(RenderSize());
    let fDistortionFieldUv: FfxFloat32x2 = SampleDistortionField(fUv);
    var iDistortionPixelOffset: FfxInt32x2 = FfxInt32x2(fDistortionFieldUv.xy * FfxFloat32x2(RenderSize()));

    var fMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(iPxPos + iDistortionPixelOffset);
    var fDilatedDepth: FfxFloat32 = LoadDilatedDepth(iPxPos + iDistortionPixelOffset);

    ReconstructPrevDepth(iPxPos, 1, fDilatedDepth, fMotionVector * 0.5f, RenderSize());
}

#endif // FFX_FRAMEINTERPOLATION_RECONSTRUCT_PREVIOUS_DEPTH_H
