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
fn ReconstructPrevDepth(iPxPos: FfxInt32x2, fDepth: FfxFloat32, fMotionVector_: FfxFloat32x2)
{
    var fMotionVector: FfxFloat32x2 = fMotionVector_;
    var fNearestDepthInMeters: FfxFloat32 = min(GetViewSpaceDepthInMeters(fDepth), FSR3UPSCALER_FP16_MAX);
    var fReconstructedDeptMvThreshold: FfxFloat32 = ReconstructedDepthMvPxThreshold(fNearestDepthInMeters);

    // Discard small mvs
    fMotionVector *= FfxFloat32(Get4KVelocity(fMotionVector) > fReconstructedDeptMvThreshold);

    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + FfxFloat32(0.5)) / FfxFloat32x2(RenderSize());
    var fReprojectedUv: FfxFloat32x2 = fUv + fMotionVector;
    let bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fReprojectedUv, RenderSize());

    // Project current depth into previous frame locations.
    // Push to all pixels having some contribution if reprojection is using bilinear logic.
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++) {
        
        var iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        var fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];

        if (fWeight > fReconstructedDepthBilinearWeightThreshold) {

            var iStorePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;
            if (IsOnScreen_i32x2_i32x2(iStorePos, RenderSize())) {
                StoreReconstructedDepth(FfxUInt32x2(iStorePos), fDepth);
            }
        }
    }
}

struct DepthExtents
{
    fNearest: FfxFloat32,
    fNearestCoord: FfxInt32x2,
    fFarthest: FfxFloat32,
}

fn FindDepthExtents(iPxPos: FfxInt32x2) -> DepthExtents
{
    var extents: DepthExtents ;
    const iSampleCount: FfxInt32 = 9;
    var iSampleOffsets: array<FfxInt32x2, iSampleCount> = array<FfxInt32x2, iSampleCount>(
        FfxInt32x2(0,0),
        FfxInt32x2(1,0),
        FfxInt32x2(0,1),
        FfxInt32x2(0, -1),
        FfxInt32x2(-1,0),
        FfxInt32x2(-1,1),
        FfxInt32x2(1,1),
        FfxInt32x2(-1, -1),
        FfxInt32x2(1, -1),
    );

    // pull out the depth loads to allow SC to batch them
    var depth: array<FfxFloat32, 9> ;
    var iSampleIndex: FfxInt32 = 0;
    
    for (iSampleIndex = 0; iSampleIndex < iSampleCount; iSampleIndex++) {

        var iPos: FfxInt32x2 = iPxPos + iSampleOffsets[iSampleIndex];
        depth[iSampleIndex] = LoadInputDepth(FfxUInt32x2(iPos));
    }

    // find closest depth
    extents.fNearestCoord   = iPxPos;
    extents.fNearest        = depth[0];
    extents.fFarthest       = depth[0];
    
    for (iSampleIndex = 1; iSampleIndex < iSampleCount; iSampleIndex++) {

        var iPos: FfxInt32x2 = iPxPos + iSampleOffsets[iSampleIndex];
        if (IsOnScreen_i32x2_i32x2(iPos, RenderSize())) {

            var fNdDepth: FfxFloat32 = depth[iSampleIndex];
#if FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH
            let bIsNearer = fNdDepth > extents.fNearest;
#else
            let bIsNearer = fNdDepth < extents.fNearest;
#endif
            if (bIsNearer) {
#if FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH
                extents.fFarthest = min(extents.fFarthest, fNdDepth);
#else
                extents.fFarthest = max(extents.fFarthest, fNdDepth);
#endif
                extents.fNearestCoord   = iPos;
                extents.fNearest        = fNdDepth;
            }
        }
    }

    return extents;
}

fn DilateMotionVector(iPxPos: FfxInt32x2, depthExtents: DepthExtents) -> FfxFloat32x2
{
#if FFX_FSR3UPSCALER_OPTION_LOW_RESOLUTION_MOTION_VECTORS
    var iSamplePos: FfxInt32x2 = iPxPos;
    var iMotionVectorPos: FfxInt32x2 = depthExtents.fNearestCoord;
#else
    var iSamplePos: FfxInt32x2 = ComputeHrPosFromLrPos_i32x2(iPxPos);
    var iMotionVectorPos: FfxInt32x2 = ComputeHrPosFromLrPos_i32x2(depthExtents.fNearestCoord);
#endif

    var fDilatedMotionVector: FfxFloat32x2 = LoadInputMotionVector(FfxUInt32x2(iMotionVectorPos));

    return fDilatedMotionVector;
}

fn GetCurrentFrameLuma(iPxPos: FfxInt32x2) -> FfxFloat32
{
    //We assume linear data. if non-linear input (sRGB, ...),
    //then we should convert to linear first and back to sRGB on output.
    var fRgb: FfxFloat32x3 = max(FfxFloat32x3(0, 0, 0), LoadInputColor(FfxUInt32x2(iPxPos)));
    var fLuma: FfxFloat32 = RGBToLuma_f32x3(fRgb);

    return fLuma;
}

fn PrepareInputs(iPxPos: FfxInt32x2)
{
    var depthExtents: DepthExtents = FindDepthExtents(iPxPos);
    var fDilatedMotionVector: FfxFloat32x2 = DilateMotionVector(iPxPos, depthExtents);

    ReconstructPrevDepth(iPxPos, depthExtents.fNearest, fDilatedMotionVector);

    StoreDilatedMotionVector(FfxUInt32x2(iPxPos), fDilatedMotionVector);
    StoreDilatedDepth(FfxUInt32x2(iPxPos), depthExtents.fNearest);

    var fFarthestDepthInMeters: FfxFloat32 = min(GetViewSpaceDepthInMeters(depthExtents.fFarthest), FSR3UPSCALER_FP16_MAX);
    StoreFarthestDepth(FfxUInt32x2(iPxPos), fFarthestDepthInMeters);

    var fLuma: FfxFloat32 = GetCurrentFrameLuma(iPxPos);
    StoreCurrentLuma(FfxUInt32x2(iPxPos), fLuma);
}
