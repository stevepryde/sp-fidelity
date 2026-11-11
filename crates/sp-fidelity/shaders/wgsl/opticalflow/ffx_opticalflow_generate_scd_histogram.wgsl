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

// WGSL port of ffx_opticalflow_generate_scd_histogram.h.
#ifndef FFX_OPTICALFLOW_GENERATE_SCD_HISTOGRAM_H
#define FFX_OPTICALFLOW_GENERATE_SCD_HISTOGRAM_H

#define LBASE 10

var<workgroup> scdBuffer: array<atomic<FfxUInt32>, 256 * LBASE>;

fn GenerateSceneChangeDetectionHistogram(iGlobalId: FfxInt32x3, iLocalId: FfxInt32x2, iLocalIndex: FfxInt32, iGroupId: FfxInt32x2, iGroupSize: FfxInt32x2)
{
    let HistogramsPerDim: FfxUInt32 = 3;

    var divX: FfxUInt32 = FfxUInt32(DisplaySize().x) / HistogramsPerDim;
    var divY: FfxUInt32 = FfxUInt32(DisplaySize().y) / HistogramsPerDim;

    var nx: FfxUInt32 = FfxUInt32(iGlobalId.z) % HistogramsPerDim;
    var ny: FfxUInt32 = FfxUInt32(iGlobalId.z) / HistogramsPerDim;
    var startX: FfxUInt32 = divX * nx;
    var startY: FfxUInt32 = divY * ny;
    var stopX: FfxUInt32 = startX + divX;
    var stopY: FfxUInt32 = startY + divY;

    let bufferOffset: FfxUInt32 = FfxUInt32(iLocalIndex) * LBASE;

    for (var i: FfxInt32 = 0; i < LBASE; i++)
    {
        atomicStore(&scdBuffer[bufferOffset + FfxUInt32(i)], 0u);
    }
    workgroupBarrier();

    var coord: FfxInt32x2 = FfxInt32x2(FfxInt32(startX) + (4 * iGlobalId.x), FfxInt32(startY) + iGlobalId.y);
    if (coord.x < FfxInt32(stopX))
    {
        for (; coord.y < FfxInt32(stopY); coord.y += 128)
        {
            var color: FfxUInt32x4 = FfxUInt32x4(
                LoadOpticalFlowInput(coord + FfxInt32x2(0, 0)),
                LoadOpticalFlowInput(coord + FfxInt32x2(1, 0)),
                LoadOpticalFlowInput(coord + FfxInt32x2(2, 0)),
                LoadOpticalFlowInput(coord + FfxInt32x2(3, 0))
            );
            color *= LBASE;

            var scramblingOffset: FfxUInt32 = FfxUInt32(iLocalIndex) % LBASE;

            atomicAdd(&scdBuffer[color.x + scramblingOffset], 1u);
            atomicAdd(&scdBuffer[color.y + scramblingOffset], 1u);
            atomicAdd(&scdBuffer[color.z + scramblingOffset], 1u);
            atomicAdd(&scdBuffer[color.w + scramblingOffset], 1u);

        }
    }
    workgroupBarrier();

    var value: FfxUInt32 = 0;
    for (var i: FfxInt32 = 0; i < LBASE; i++)
    {
        value += atomicLoad(&scdBuffer[bufferOffset + FfxUInt32(i)]);
    }

    var histogramStart: FfxUInt32 = FfxUInt32((iGroupSize.x * iGroupSize.y) * iGlobalId.z);
    AtomicIncrementSCDHistogram(FfxInt32(histogramStart + FfxUInt32(iLocalIndex)), value);
}

#endif // FFX_OPTICALFLOW_GENERATE_SCD_HISTOGRAM_H
