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

// WGSL port of ffx_opticalflow_prepare_luma.h.
#ifndef FFX_OPTICALFLOW_PREPARE_LUMA_H
#define FFX_OPTICALFLOW_PREPARE_LUMA_H

fn LuminanceToPerceivedLuminance(fLuminance: FfxFloat32) -> FfxFloat32
{
    var fPercievedLuminance: FfxFloat32 = 0;
    if (fLuminance <= 216.0f / 24389.0f) {
        fPercievedLuminance = fLuminance * (24389.0f / 27.0f);
    }
    else {
        fPercievedLuminance = pow(fLuminance, 1.0f / 3.0f) * 116.0f - 16.0f;
    }

    return fPercievedLuminance * 0.01f;
}

fn LinearLdrToLuminance(linearRec709RGB: FfxFloat32x3) -> FfxFloat32
{
    var fY: FfxFloat32 = 0.2126 * linearRec709RGB.x + 0.7152 * linearRec709RGB.y + 0.0722 * linearRec709RGB.z;
    return fY;
}

fn LinearRec2020ToLuminance(linearRec2020RGB: FfxFloat32x3) -> FfxFloat32
{
    var fY: FfxFloat32 = 0.2627 * linearRec2020RGB.x + 0.678 * linearRec2020RGB.y + 0.0593 * linearRec2020RGB.z;
    return fY;
}

fn PQCorrectedHdrToLuminance(pq: FfxFloat32x3, maxLuminance: FfxFloat32) -> FfxFloat32
{
    var fY: FfxFloat32 = LinearRec2020ToLuminance(ffxLinearFromPQ_f32x3(pq) * (10000.0f / maxLuminance));
    return fY;
}

fn ffxscRGBToLinear(value: FfxFloat32x3, minLuminance: FfxFloat32, maxLuminance: FfxFloat32) -> FfxFloat32x3
{
    var p: FfxFloat32x3 = value - FfxFloat32x3(minLuminance / 80.0f);
    return p / FfxFloat32x3((maxLuminance - minLuminance) / 80.0f);
}

fn SCRGBCorrectedHdrToLuminance(scRGB: FfxFloat32x3, minLuminance: FfxFloat32, maxLuminance: FfxFloat32) -> FfxFloat32
{
    var fY: FfxFloat32 = LinearLdrToLuminance(ffxscRGBToLinear(scRGB, minLuminance, maxLuminance));
    return fY;
}

fn PrepareLuma(iGlobalId: FfxInt32x2, iLocalIndex: FfxInt32)
{
#define PixelsPerThreadX 2
#define PixelsPerThreadY 2
    for (var y: FfxInt32 = 0; y < PixelsPerThreadY; y++)
    {
        for (var x: FfxInt32 = 0; x < PixelsPerThreadX; x++)
        {
            var pos: FfxInt32x2 = iGlobalId * FfxInt32x2(PixelsPerThreadX, PixelsPerThreadY) + FfxInt32x2(x, y);
            var iPxHrPos: FfxInt32x2 = pos;
            var fY: FfxFloat32 = 0.0;

            var inputColor: FfxFloat32x3 = LoadInputColor(iPxHrPos).rgb;

            var backbufferTransferFunction: FfxUInt32 = BackbufferTransferFunction();
            if (backbufferTransferFunction == 0)
            {
                fY = LinearLdrToLuminance(inputColor);
            }
            else if (backbufferTransferFunction == 1)
            {
                fY = PQCorrectedHdrToLuminance(inputColor, MinMaxLuminance()[1]);
                fY = LuminanceToPerceivedLuminance(fY);
            }
            else if (backbufferTransferFunction == 2)
            {
                fY = SCRGBCorrectedHdrToLuminance(inputColor, MinMaxLuminance()[0], MinMaxLuminance()[1]);
                fY = LuminanceToPerceivedLuminance(fY);
            }

            StoreOpticalFlowInput(pos, FfxUInt32(fY * 255));
        }
    }
}

#endif // FFX_OPTICALFLOW_PREPARE_LUMA_H
