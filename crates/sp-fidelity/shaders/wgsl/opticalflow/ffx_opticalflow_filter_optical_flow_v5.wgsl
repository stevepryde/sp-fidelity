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

// WGSL port of ffx_opticalflow_filter_optical_flow_v5.h.
#ifndef FFX_OPTICALFLOW_FILTER_OPTICAL_FLOW_V5_H
#define FFX_OPTICALFLOW_FILTER_OPTICAL_FLOW_V5_H

fn FilterOpticalFlow(iGlobalId: FfxInt32x2, iLocalId: FfxInt32x2, iGroupId: FfxInt32x2, iLocalIndex: FfxInt32)
{
    var tmpMV: array<FfxInt32x2, 9>;
    var idx: FfxInt32 = 0;
    for (var xx: FfxInt32 = -1; xx < 2; xx++)
    {
        for (var yy: FfxInt32 = -1; yy < 2; yy++)
        {

            tmpMV[idx] = LoadPreviousOpticalFlow(iGlobalId + FfxInt32x2(xx, yy));
            idx++;
        }
    }

    var ret: FfxUInt32 = 0xFFFFFFFF;
    for (var i: FfxInt32 = 0; i < 9; i++)
    {
        var tmp: FfxUInt32 = 0;
        for (var j: FfxInt32 = 0; j < 9; j++)
        {
            var delta: FfxInt32x2 = tmpMV[i] - tmpMV[j];
            tmp = FfxUInt32(delta.x * delta.x + delta.y * delta.y) + tmp;
        }

        ret = min(((tmp) << 4u) | FfxUInt32(i), ret);
    }

    var minIdx: FfxUInt32 = ret & 0xF;

    StoreOpticalFlow(iGlobalId, tmpMV[minIdx]);
}

#endif // FFX_OPTICALFLOW_FILTER_OPTICAL_FLOW_V5_H
