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

// WGSL port of ffx_fsr2_lock.h.
//
// WGSL: HLSL converts int2 arguments to the callbacks' FfxUInt32x2
// implicitly; here the conversions are written.

#ifndef FFX_FSR2_LOCK_H
#define FFX_FSR2_LOCK_H

fn ClearResourcesForNextFrame(iPxHrPos: FfxInt32x2)
{
    if (all(iPxHrPos < FfxInt32x2(RenderSize())))
    {
#if FFX_FSR2_OPTION_INVERTED_DEPTH
        let farZ: FfxUInt32 = 0x0u;
#else
        let farZ: FfxUInt32 = 0x3f800000u;
#endif
        SetReconstructedDepth(FfxUInt32x2(iPxHrPos), farZ);
    }
}

fn ComputeThinFeatureConfidence(pos: FfxInt32x2) -> FfxBoolean
{
    const RADIUS: FfxInt32 = 1;

    let fNucleus: FfxFloat32 = LoadLockInputLuma(FfxUInt32x2(pos));

    let similar_threshold: FfxFloat32 = 1.05f;
    var dissimilarLumaMin: FfxFloat32 = FSR2_FLT_MAX;
    var dissimilarLumaMax: FfxFloat32 = 0;

    /*
     0 1 2
     3 4 5
     6 7 8
    */

    // #define SETBIT(x) (1U << x)
    // WGSL: the function-like macro is expanded in place; a shift amount is
    // a u32.

    var mask: FfxUInt32 = (1u << 4u); //flag fNucleus as similar

    const uNumRejectionMasks: FfxUInt32 = 4;
    const uRejectionMasks: array<FfxUInt32, uNumRejectionMasks> = array<FfxUInt32, uNumRejectionMasks>(
        (1u << 0u) | (1u << 1u) | (1u << 3u) | (1u << 4u), //Upper left
        (1u << 1u) | (1u << 2u) | (1u << 4u) | (1u << 5u), //Upper right
        (1u << 3u) | (1u << 4u) | (1u << 6u) | (1u << 7u), //Lower left
        (1u << 4u) | (1u << 5u) | (1u << 7u) | (1u << 8u), //Lower right
    );

    var idx: FfxInt32 = 0;
    FFX_UNROLL
    for (var y: FfxInt32 = -RADIUS; y <= RADIUS; y++) {
        // WGSL: a for statement's update is one statement, and an unrolled
        // loop has no continue (SDK-P26). The SDK's
        // for (x = -RADIUS; x <= RADIUS; x++, idx++), whose
        // if (x == 0 && y == 0) continue; skips to both increments, samples
        // off the nucleus only and increments idx at the end of the body.
        FFX_UNROLL
        for (var x: FfxInt32 = -RADIUS; x <= RADIUS; x++) {
            if !(x == 0 && y == 0) {

                let samplePos: FfxInt32x2 = ClampLoad_i32x2_i32x2_i32x2(pos, FfxInt32x2(x, y), FfxInt32x2(RenderSize()));

                let sampleLuma: FfxFloat32 = LoadLockInputLuma(FfxUInt32x2(samplePos));
                let difference: FfxFloat32 = ffxMax_f32_f32(sampleLuma, fNucleus) / ffxMin_f32_f32(sampleLuma, fNucleus);

                if (difference > 0 && (difference < similar_threshold)) {
                    mask |= (1u << FfxUInt32(idx));
                } else {
                    dissimilarLumaMin = ffxMin_f32_f32(dissimilarLumaMin, sampleLuma);
                    dissimilarLumaMax = ffxMax_f32_f32(dissimilarLumaMax, sampleLuma);
                }
            }
            idx++;
        }
    }

    let isRidge: FfxBoolean = fNucleus > dissimilarLumaMax || fNucleus < dissimilarLumaMin;

    if (FFX_FALSE == isRidge) {

        return false;
    }

    FFX_UNROLL
    for (var i: FfxInt32 = 0; i < 4; i++) {

        if ((mask & uRejectionMasks[i]) == uRejectionMasks[i]) {
            return false;
        }
    }
    
    return true;
}

fn ComputeLock(iPxLrPos: FfxInt32x2)
{
    if (ComputeThinFeatureConfidence(iPxLrPos))
    {
        StoreNewLocks(FfxUInt32x2(ComputeHrPosFromLrPos_i32x2(iPxLrPos)), 1.f);
    }

    ClearResourcesForNextFrame(iPxLrPos);
}

#endif // FFX_FSR2_LOCK_H
