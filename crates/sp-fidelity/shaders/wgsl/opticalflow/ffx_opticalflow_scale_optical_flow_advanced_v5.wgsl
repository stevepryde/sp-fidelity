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

// WGSL port of ffx_opticalflow_scale_optical_flow_advanced_v5.h.
#ifndef FFX_OPTICALFLOW_SCALE_OPTICAL_FLOW_ADVANCED_V5_H
#define FFX_OPTICALFLOW_SCALE_OPTICAL_FLOW_ADVANCED_V5_H

#define WG_WIDTH FFX_OPTICALFLOW_THREAD_GROUP_WIDTH
#define WG_HEIGHT FFX_OPTICALFLOW_THREAD_GROUP_HEIGHT
#define WG_DEPTH FFX_OPTICALFLOW_THREAD_GROUP_DEPTH
var<workgroup> nearestVectors: array<array<array<FfxInt32x2, WG_WIDTH>, WG_HEIGHT>, 4>;
var<workgroup> localRegion: array<array<array<FfxUInt32, WG_WIDTH>, WG_HEIGHT>, 4>;
var<workgroup> sads: array<array<array<FfxUInt32, WG_WIDTH>, WG_HEIGHT>, 4>;

fn ScaleOpticalFlowAdvanced(iGlobalId: FfxInt32x3, iLocalId: FfxInt32x3)
{
    if (IsSceneChanged())
    {
        // HLSL writes the same value from all four Z lanes.
        if (iLocalId.z == 0) { StoreOpticalFlowNextLevel(iGlobalId.xy, FfxInt32x2(0, 0)); }

        return;
    }

    var xOffset: i32 = (iLocalId.z % 2) - 1 + iGlobalId.x % 2;
    var yOffset: i32 = (iLocalId.z / 2) - 1 + iGlobalId.y % 2;

    var srcOFPos: FfxInt32x2 = FfxInt32x2(
        (iGlobalId.x / 2) + xOffset,
        (iGlobalId.y / 2) + yOffset
    );

    var nearestVector: FfxInt32x2 = LoadOpticalFlow(srcOFPos);
    nearestVectors[iLocalId.z][iLocalId.y][iLocalId.x] = nearestVector * 2;

    var maxY: i32 = 4;
    for (var n: i32 = iLocalId.z; n < maxY; n += WG_DEPTH)
    {
        {
            var lumaPos: FfxInt32x2 = FfxInt32x2((iGlobalId.x) * 4, iGlobalId.y * maxY + n);
            var firstPixel: FfxUInt32 = LoadFirstImagePackedLuma(lumaPos);
            localRegion[n][iLocalId.y][iLocalId.x] = firstPixel;
        }
    }
    workgroupBarrier();

    var sad: u32 = 0;
    for (var n: i32 = 0; n < maxY; n++)
    {
        {
            var lumaPos: FfxInt32x2 = FfxInt32x2((iGlobalId.x) * 4, (iGlobalId.y * maxY + n)) + nearestVector;
            var secondPixel: FfxUInt32 = LoadSecondImagePackedLuma(lumaPos);
            sad += Sad(localRegion[n][iLocalId.y][iLocalId.x], secondPixel);
        }
    }
    sads[iLocalId.z][iLocalId.y][iLocalId.x] = sad;

    workgroupBarrier();

    {
        if (iLocalId.z == 0)
        {
            var bestSad: u32 = 0xffffffff;
            var bestId: u32 = 0;

            for (var n: i32 = 0; n < 4; n++)
            {
                if ((sads[n][iLocalId.y][iLocalId.x]) < bestSad)
                {
                    bestSad = sads[n][iLocalId.y][iLocalId.x];
                    bestId = FfxUInt32(n);
                }
            }

            var outputVector: FfxInt32x2 = nearestVectors[bestId][iLocalId.y][iLocalId.x];

            StoreOpticalFlowNextLevel(iGlobalId.xy, outputVector);
        }
    }
}

#endif // FFX_OPTICALFLOW_SCALE_OPTICAL_FLOW_ADVANCED_V5_H
