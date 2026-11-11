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

// WGSL port of ffx_frameinterpolation_reconstruct_dilated_velocity_and_previous_depth.h.

#ifndef FFX_FRAMEINTERPOLATION_RECONSTRUCT_DILATED_VELOCITY_AND_PREVIOUS_DEPTH_H
#define FFX_FRAMEINTERPOLATION_RECONSTRUCT_DILATED_VELOCITY_AND_PREVIOUS_DEPTH_H

fn ReconstructPrevDepth(iPxPos: FfxInt32x2, fDepth: FfxFloat32, fMotionVector_in: FfxFloat32x2, iPxDepthSize: FfxInt32x2)
{
    var fMotionVector: FfxFloat32x2 = fMotionVector_in;
    fMotionVector *= FfxFloat32(length(fMotionVector * FfxFloat32x2(DisplaySize())) > 0.1f);

    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + FfxFloat32(0.5)) / FfxFloat32x2(iPxDepthSize);
    var fReprojectedUv: FfxFloat32x2 = fUv + fMotionVector;

    var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fReprojectedUv, RenderSize());

    // Project current depth into previous frame locations.
    // Push to all pixels having some contribution if reprojection is using bilinear logic.
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++) {

        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        var fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];

        if (fWeight > fReconstructedDepthBilinearWeightThreshold) {

            var iStorePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;
            if (IsOnScreen(iStorePos, iPxDepthSize)) {
                UpdateReconstructedDepthPreviousFrame(iStorePos, fDepth);
            }
        }
    }
}

fn FindNearestDepth(iPxPos: FfxInt32x2, iPxSize: FfxInt32x2, fNearestDepth: ptr<function, FfxFloat32>, fNearestDepthCoord: ptr<function, FfxInt32x2>)
{
    const iSampleCount: FfxInt32 = 9;
    let iSampleOffsets: array<FfxInt32x2, iSampleCount> = array<FfxInt32x2, iSampleCount>(
        FfxInt32x2(0, 0),
        FfxInt32x2(1, 0),
        FfxInt32x2(0, 1),
        FfxInt32x2(0, -1),
        FfxInt32x2(-1, 0),
        FfxInt32x2(-1, 1),
        FfxInt32x2(1, 1),
        FfxInt32x2(-1, -1),
        FfxInt32x2(1, -1),
    );

    // pull out the depth loads to allow SC to batch them
    var depth: array<FfxFloat32, 9>;
    var iSampleIndex: FfxInt32 = 0;
    FFX_UNROLL
    for (iSampleIndex = 0; iSampleIndex < iSampleCount; iSampleIndex++) {

        var iPos: FfxInt32x2 = iPxPos + iSampleOffsets[iSampleIndex];
        depth[iSampleIndex] = LoadInputDepth(iPos);
    }

    // find closest depth
    (*fNearestDepthCoord) = iPxPos;
    (*fNearestDepth) = depth[0];
    FFX_UNROLL
    for (iSampleIndex = 1; iSampleIndex < iSampleCount; iSampleIndex++) {

        var iPos: FfxInt32x2 = iPxPos + iSampleOffsets[iSampleIndex];
        if (IsOnScreen(iPos, iPxSize)) {

            var fNdDepth: FfxFloat32 = depth[iSampleIndex];
#if FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
            if (fNdDepth > (*fNearestDepth)) {
#else
            if (fNdDepth < (*fNearestDepth)) {
#endif
                (*fNearestDepthCoord) = iPos;
                (*fNearestDepth) = fNdDepth;
            }
        }
    }
}

fn ReconstructAndDilate(iPxLrPos: FfxInt32x2)
{
    var fDilatedDepth: FfxFloat32;
    var iNearestDepthCoord: FfxInt32x2;

    FindNearestDepth(iPxLrPos, RenderSize(), &fDilatedDepth, &iNearestDepthCoord);

#if FFX_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS
    var iSamplePos: FfxInt32x2 = iPxLrPos;
    var iMotionVectorPos: FfxInt32x2 = iNearestDepthCoord;
#else
    var iSamplePos: FfxInt32x2 = ComputeHrPosFromLrPos(iPxLrPos);
    var iMotionVectorPos: FfxInt32x2 = ComputeHrPosFromLrPos(iNearestDepthCoord);
#endif

    var fDilatedMotionVector: FfxFloat32x2 = LoadInputMotionVector(iMotionVectorPos);

    StoreDilatedDepth(iPxLrPos, fDilatedDepth);
    StoreDilatedMotionVectors(iPxLrPos, fDilatedMotionVector);

    ReconstructPrevDepth(iPxLrPos, fDilatedDepth, fDilatedMotionVector, RenderSize());
}


#endif //!defined( FFX_FRAMEINTERPOLATION_RECONSTRUCT_DILATED_VELOCITY_AND_PREVIOUS_DEPTH_H )
