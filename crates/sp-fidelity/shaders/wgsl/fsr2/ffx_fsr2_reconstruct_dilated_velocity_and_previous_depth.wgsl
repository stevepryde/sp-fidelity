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

// WGSL port of ffx_fsr2_reconstruct_dilated_velocity_and_previous_depth.h.
//
// WGSL: HLSL converts int2 arguments to the callbacks' FfxUInt32x2 and int2 to
// float2 in mixed arithmetic implicitly; here the conversions are written.

#ifndef FFX_FSR2_RECONSTRUCT_DILATED_VELOCITY_AND_PREVIOUS_DEPTH_H
#define FFX_FSR2_RECONSTRUCT_DILATED_VELOCITY_AND_PREVIOUS_DEPTH_H

fn ReconstructPrevDepth(iPxPos: FfxInt32x2, fDepth: FfxFloat32, fMotionVector_: FfxFloat32x2, iPxDepthSize: FfxInt32x2)
{
    var fMotionVector: FfxFloat32x2 = fMotionVector_;
    fMotionVector *= FfxFloat32(length(fMotionVector * FfxFloat32x2(DisplaySize())) > 0.1f);

    let fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + FfxFloat32(0.5)) / FfxFloat32x2(iPxDepthSize);
    let fReprojectedUv: FfxFloat32x2 = fUv + fMotionVector;

    let bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fReprojectedUv, RenderSize());

    // Project current depth into previous frame locations.
    // Push to all pixels having some contribution if reprojection is using bilinear logic.
    // WGSL: FFX_UNROLL, which the SDK leaves to the compiler here, saves
    // 0.03 ms at 1920x1080 on Apple M5 (SDK-P26).
    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++) {

        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];

        if (fWeight > fReconstructedDepthBilinearWeightThreshold) {

            let iStorePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;
            if (IsOnScreen_i32x2_i32x2(iStorePos, iPxDepthSize)) {
                StoreReconstructedDepth(FfxUInt32x2(iStorePos), fDepth);
            }
        }
    }
}

fn FindNearestDepth(iPxPos: FfxInt32x2, iPxSize: FfxInt32x2, fNearestDepth: ptr<function, FfxFloat32>, fNearestDepthCoord: ptr<function, FfxInt32x2>)
{
    const iSampleCount: FfxInt32 = 9;
    // WGSL: no unary plus (the SDK writes +0 and +1).
    const iSampleOffsets: array<FfxInt32x2, iSampleCount> = array<FfxInt32x2, iSampleCount>(
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

        let iPos: FfxInt32x2 = iPxPos + iSampleOffsets[iSampleIndex];
        depth[iSampleIndex] = LoadInputDepth(FfxUInt32x2(iPos));
    }

    // find closest depth
    *fNearestDepthCoord = iPxPos;
    *fNearestDepth = depth[0];
    FFX_UNROLL
    for (iSampleIndex = 1; iSampleIndex < iSampleCount; iSampleIndex++) {

        let iPos: FfxInt32x2 = iPxPos + iSampleOffsets[iSampleIndex];
        if (IsOnScreen_i32x2_i32x2(iPos, iPxSize)) {

            let fNdDepth: FfxFloat32 = depth[iSampleIndex];
#if FFX_FSR2_OPTION_INVERTED_DEPTH
            if (fNdDepth > *fNearestDepth) {
#else
            if (fNdDepth < *fNearestDepth) {
#endif
                *fNearestDepthCoord = iPos;
                *fNearestDepth = fNdDepth;
            }
        }
    }
}

fn ComputeLockInputLuma(iPxLrPos: FfxInt32x2) -> FfxFloat32
{
    //We assume linear data. if non-linear input (sRGB, ...),
    //then we should convert to linear first and back to sRGB on output.
    var fRgb: FfxFloat32x3 = ffxMax_f32x3_f32x3(FfxFloat32x3(0, 0, 0), LoadInputColor(FfxUInt32x2(iPxLrPos)));

    // Use internal auto exposure for locking logic
    fRgb /= PreExposure();
    fRgb *= Exposure();

#if FFX_FSR2_OPTION_HDR_COLOR_INPUT
    fRgb = Tonemap_f32x3(fRgb);
#endif

    //compute luma used to lock pixels, if used elsewhere the ffxPow must be moved!
    let fLockInputLuma: FfxFloat32 = ffxPow_f32_f32(RGBToPerceivedLuma_f32x3(fRgb), FfxFloat32(1.0 / 6.0));

    return fLockInputLuma;
}

fn ReconstructAndDilate(iPxLrPos: FfxInt32x2)
{
    var fDilatedDepth: FfxFloat32;
    var iNearestDepthCoord: FfxInt32x2;

    FindNearestDepth(iPxLrPos, RenderSize(), &fDilatedDepth, &iNearestDepthCoord);

#if FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS
    let iSamplePos: FfxInt32x2 = iPxLrPos;
    let iMotionVectorPos: FfxInt32x2 = iNearestDepthCoord;
#else
    let iSamplePos: FfxInt32x2 = ComputeHrPosFromLrPos_i32x2(iPxLrPos);
    let iMotionVectorPos: FfxInt32x2 = ComputeHrPosFromLrPos_i32x2(iNearestDepthCoord);
#endif

    let fDilatedMotionVector: FfxFloat32x2 = LoadInputMotionVector(FfxUInt32x2(iMotionVectorPos));

    StoreDilatedDepth(FfxUInt32x2(iPxLrPos), fDilatedDepth);
    StoreDilatedMotionVector(FfxUInt32x2(iPxLrPos), fDilatedMotionVector);

    ReconstructPrevDepth(iPxLrPos, fDilatedDepth, fDilatedMotionVector, RenderSize());

    let fLockInputLuma: FfxFloat32 = ComputeLockInputLuma(iPxLrPos);
    StoreLockInputLuma(FfxUInt32x2(iPxLrPos), fLockInputLuma);
}


#endif //!defined( FFX_FSR2_RECONSTRUCT_DILATED_VELOCITY_AND_PREVIOUS_DEPTH_H )
