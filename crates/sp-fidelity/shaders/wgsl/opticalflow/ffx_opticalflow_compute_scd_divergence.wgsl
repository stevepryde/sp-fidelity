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

// WGSL port of ffx_opticalflow_compute_scd_divergence.h.
#ifndef FFX_OPTICALFLOW_COMPUTE_SCD_DIVERGENCE_H
#define FFX_OPTICALFLOW_COMPUTE_SCD_DIVERGENCE_H

var<workgroup> sourceHistogram: array<FfxFloat32, 256>;
var<workgroup> filteredHistogram: array<FfxFloat32, 256>;
var<workgroup> tempBuffer: array<FfxFloat32, 256>;
var<workgroup> tempBuffer2: array<FfxFloat32x2, 256>;

fn ComputeSCDHistogramsDivergence(iGlobalId: FfxInt32x3, iLocalId: FfxInt32x2, iLocalIndex: FfxInt32, iGroupId: FfxInt32x2, iGroupSize: FfxInt32x2)
{
    let Factor: FfxFloat32 = 1000000.0;
    let WhereToStop: FfxInt32 = 3*9 - 1;
    let HistogramCount: FfxInt32 = 3 * 3;

    let Kernel = array<FfxFloat32, 6>(
        0.0088122291, 0.027143577, 0.065114059, 0.12164907, 0.17699835, 0.20056541
    );

    sourceHistogram[iLocalIndex] = FfxFloat32(LoadRwSCDHistogram(iGlobalId.x));
    workgroupBarrier();

    let kernelShift: FfxInt32 = -5;
    let indexToRead: FfxInt32 = iLocalIndex + kernelShift;

    var val: FfxFloat32 = 0.0;
    val += Kernel[0] * sourceHistogram[clamp(indexToRead + 0, 0, 255)];
    val += Kernel[1] * sourceHistogram[clamp(indexToRead + 1, 0, 255)];
    val += Kernel[2] * sourceHistogram[clamp(indexToRead + 2, 0, 255)];
    val += Kernel[3] * sourceHistogram[clamp(indexToRead + 3, 0, 255)];
    val += Kernel[4] * sourceHistogram[clamp(indexToRead + 4, 0, 255)];
    val += Kernel[5] * sourceHistogram[clamp(indexToRead + 5, 0, 255)];
    val += Kernel[4] * sourceHistogram[clamp(indexToRead + 6, 0, 255)];
    val += Kernel[3] * sourceHistogram[clamp(indexToRead + 7, 0, 255)];
    val += Kernel[2] * sourceHistogram[clamp(indexToRead + 8, 0, 255)];
    val += Kernel[1] * sourceHistogram[clamp(indexToRead + 9, 0, 255)];
    val += Kernel[0] * sourceHistogram[clamp(indexToRead + 10, 0, 255)];

    val += 1.0;

    if (iGlobalId.y == 0)
    {
        if (iLocalIndex == 0) {
            filteredHistogram[255] = 1.0;
        } else {
            filteredHistogram[iLocalIndex - 1] = val;
        }
    }
    else if (iGlobalId.y == 1)
    {
        filteredHistogram[iLocalIndex] = val;
    }
    else if (iGlobalId.y == 2)
    {
        if (iLocalIndex == 255) {
            filteredHistogram[0] = 1.0;
        } else {
            filteredHistogram[iLocalIndex + 1] = val;
        }
    }
    workgroupBarrier();

    tempBuffer[iLocalIndex] = filteredHistogram[iLocalIndex];
    workgroupBarrier();

    if (iLocalIndex < 128) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 128]; }
    workgroupBarrier();

    if (iLocalIndex < 64) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 64]; }
    workgroupBarrier();

    // HLSL assumes wave lockstep below 64 lanes. Preserve its exact
    // floating-point reduction tree with explicit workgroup barriers.
    if (iLocalIndex < 32) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 32]; }
    workgroupBarrier();
    if (iLocalIndex < 16) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 16]; }
    workgroupBarrier();
    if (iLocalIndex < 8 ) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 8]; }
    workgroupBarrier();
    if (iLocalIndex < 4 ) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 4]; }
    workgroupBarrier();
    if (iLocalIndex < 2 ) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 2]; }
    workgroupBarrier();
    if (iLocalIndex < 1 ) { tempBuffer[iLocalIndex] += tempBuffer[iLocalIndex + 1]; }
    workgroupBarrier();

    filteredHistogram[iLocalIndex] /= tempBuffer[0];

    var currentFilteredHistogramsValue: FfxFloat32 = filteredHistogram[iLocalIndex];
    var previousHistogramsValue: FfxFloat32 = LoadRwSCDPreviousHistogram(iGlobalId.x);

    tempBuffer2[iLocalIndex] = FfxFloat32x2(
        currentFilteredHistogramsValue * log(currentFilteredHistogramsValue / previousHistogramsValue),
        previousHistogramsValue * log(previousHistogramsValue / currentFilteredHistogramsValue)
    );
    workgroupBarrier();

    if (iLocalIndex < 128) { tempBuffer2[iLocalIndex] += tempBuffer2[iLocalIndex + 128]; }
    workgroupBarrier();

    if (iLocalIndex < 64) { tempBuffer2[iLocalIndex] += tempBuffer2[iLocalIndex + 64]; }
    workgroupBarrier();

    if (iLocalIndex < 32) { tempBuffer2[iLocalIndex] += tempBuffer2[iLocalIndex + 32]; }
    workgroupBarrier();
    if (iLocalIndex < 16) { tempBuffer2[iLocalIndex] += tempBuffer2[iLocalIndex + 16]; }
    workgroupBarrier();
    if (iLocalIndex < 8 ) { tempBuffer2[iLocalIndex] += tempBuffer2[iLocalIndex + 8]; }
    workgroupBarrier();
    if (iLocalIndex < 4 ) { tempBuffer2[iLocalIndex] += tempBuffer2[iLocalIndex + 4]; }
    workgroupBarrier();
    if (iLocalIndex < 2 ) { tempBuffer2[iLocalIndex] += tempBuffer2[iLocalIndex + 2]; }
    workgroupBarrier();

    if (iLocalIndex == 0)
    {
        var sum: FfxFloat32x2 = tempBuffer2[0] + tempBuffer2[1];

        var resFloat: FfxFloat32 = 1 - exp(-(abs(sum.x) + abs(sum.y)));
        var resUInt: FfxUInt32 = FfxUInt32((resFloat / FfxFloat32(HistogramCount)) * Factor);
        AtomicIncrementSCDTemp(iGlobalId.y, resUInt);

        var oldFinishedGroupCount: FfxUInt32 = AtomicIncrementSCDOutput(SCD_OUTPUT_COMPLETED_WORKGROUPS_SLOT, 1);
        if (oldFinishedGroupCount == FfxUInt32(WhereToStop))
        {
            var res0: FfxUInt32 = LoadRwSCDTemp(0);
            var res1: FfxUInt32 = LoadRwSCDTemp(1);
            var res2: FfxUInt32 = LoadRwSCDTemp(2);
            var sceneChangeValue: FfxFloat32 = FfxFloat32(min(res0, min(res1, res2))) / Factor;

            var history: FfxUInt32 = LoadRwSCDOutput(SCD_OUTPUT_HISTORY_BITS_SLOT) << 1;
            if (CrossedSceneChangeThreshold(sceneChangeValue))
            {
                history |= 1;
            }
            StoreSCDOutput(SCD_OUTPUT_SCENE_CHANGE_SLOT, bitcast<u32>(sceneChangeValue));
            StoreSCDOutput(SCD_OUTPUT_HISTORY_BITS_SLOT, history);
            StoreSCDOutput(SCD_OUTPUT_COMPLETED_WORKGROUPS_SLOT, 0);

            ResetSCDTemp();
        }
    }

    if (iGlobalId.y == 1)
    {
        StoreSCDPreviousHistogram(iGlobalId.x, currentFilteredHistogramsValue);

        StoreSCDHistogram(iGlobalId.x, 0);
    }
}

#endif // FFX_OPTICALFLOW_COMPUTE_SCD_DIVERGENCE_H
