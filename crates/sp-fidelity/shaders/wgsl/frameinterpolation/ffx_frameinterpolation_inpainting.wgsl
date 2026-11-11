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

// WGSL port of ffx_frameinterpolation_inpainting.h.

#ifndef FFX_FRAMEINTERPOLATION_INPAINTING_H
#define FFX_FRAMEINTERPOLATION_INPAINTING_H

fn ComputeInpaintingLevel(fUv: FfxFloat32x2, iMipLevel: FfxInt32, iTexSize: FfxInt32x2) -> FfxFloat32x4
{
    var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fUv, iTexSize);

    var fColor: FfxFloat32x4 = FfxFloat32x4(0.0, 0.0, 0.0, 0.0);

    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++) {

        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

        if (IsOnScreen(iSamplePos, iTexSize)) {

            var fSample: FfxFloat32x4 = LoadInpaintingPyramid(iMipLevel, iSamplePos);

            let fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex] * FfxFloat32(fSample.w > 0.0f);

            fColor += FfxFloat32x4(fSample.rgb * fWeight, fWeight);
        }
    }

    return fColor;
}

fn ComputeInpainting(iPxPos: FfxInt32x2) -> FfxFloat32x3
{
    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(DisplaySize());

    var fColor: FfxFloat32x4 = FfxFloat32x4(0.0, 0.0, 0.0, 0.0);
    var fWeightSum: FfxFloat32 = 0.0f;
    var iTexSize: FfxInt32x2 = DisplaySize();

    for (var iMipLevel: FfxInt32 = 0; iMipLevel < 10; iMipLevel++) {

        iTexSize /= 2;

        var fMipColor: FfxFloat32x4 = ComputeInpaintingLevel(fUv, iMipLevel, iTexSize);

        if (fMipColor.w > 0.0f) {
            let fNormalizedMipColor: FfxFloat32x3 = fMipColor.rgb / fMipColor.w;
            let fMipWeight: FfxFloat32 = pow(1.0f - FfxFloat32(iMipLevel) / 10.0f, 3.0f) * fMipColor.w;

            fColor += FfxFloat32x4(fNormalizedMipColor, 1.0f) * fMipWeight;
        }
    }

    return fColor.rgb / fColor.w;
}

fn drawDebugTearLines(iPxPos: FfxInt32x2, fColor: ptr<function, FfxFloat32x3>, bWriteColor: ptr<function, FfxBoolean>)
{
    if (iPxPos.x < 16)
    {
        (*fColor).g = 1.f;
        (*bWriteColor) = true;
    }
    else if (iPxPos.x > DisplaySize().x - 16)
    {
        (*fColor) += GetDebugBarColor();
        (*bWriteColor) = true;
    }

}

fn drawDebugResetIndicators(iPxPos: FfxInt32x2, fColor: ptr<function, FfxFloat32x3>, bWriteColor: ptr<function, FfxBoolean>)
{
    if (iPxPos.y < 32 && Reset())
    {
        (*fColor).r    = 1.f;
        (*bWriteColor) = true;
    }
    else if (iPxPos.y > 32 && iPxPos.y < 64 && HasSceneChanged())
    {
        (*fColor).b    = 1.f;
        (*bWriteColor) = true;
    }
}

fn computeInpainting(iPxPos: FfxInt32x2)
{
    var bWriteColor: FfxBoolean = false;
    var fInterpolatedColor: FfxFloat32x4    = RWLoadFrameinterpolationOutput(iPxPos);

    let fInPaintingWeight: FfxFloat32 = fInterpolatedColor.w;
    if (fInPaintingWeight > FFX_FRAMEINTERPOLATION_EPSILON)
    {
        fInterpolatedColor = FfxFloat32x4(mix(fInterpolatedColor.rgb, ComputeInpainting(iPxPos) * FfxFloat32(DisplaySize().x > 0), fInPaintingWeight), fInterpolatedColor.w);
        bWriteColor = true;
    }

    if (GetHUDLessAttachedFactor() == 1)
    {
        let fCurrentInterpolationSource: FfxFloat32x3 = LoadCurrentBackbuffer(iPxPos).rgb;
        let fPresentColor: FfxFloat32x3 = LoadPresentBackbuffer(iPxPos).rgb;

        if (any((abs(fCurrentInterpolationSource - fPresentColor) >  FfxFloat32x3(0.0, 0.0, 0.0))))
        {
            let fStaticFactor: FfxFloat32 = CalculateStaticContentFactor(RawRGBToLinear(fCurrentInterpolationSource), RawRGBToLinear(fPresentColor));

            if (fStaticFactor > FFX_FRAMEINTERPOLATION_EPSILON)
            {
                fInterpolatedColor = FfxFloat32x4(mix(fInterpolatedColor.rgb, fPresentColor, fStaticFactor), fInterpolatedColor.w);
                bWriteColor = true;
            }
        }
    }

    if ((GetDispatchFlags() & FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_TEAR_LINES) != 0)
    {
        var debugColor: FfxFloat32x3 = fInterpolatedColor.rgb;
        drawDebugTearLines(iPxPos, &debugColor, &bWriteColor);
        fInterpolatedColor = FfxFloat32x4(debugColor, fInterpolatedColor.w);
    }

    if ((GetDispatchFlags() & FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_RESET_INDICATORS) != 0)
    {
        var debugColor: FfxFloat32x3 = fInterpolatedColor.rgb;
        drawDebugResetIndicators(iPxPos, &debugColor, &bWriteColor);
        fInterpolatedColor = FfxFloat32x4(debugColor, fInterpolatedColor.w);
    }

    if (bWriteColor)
    {
        StoreFrameinterpolationOutput(iPxPos, FfxFloat32x4(fInterpolatedColor.rgb, 1.0f));
    }

}

#endif  // FFX_FRAMEINTERPOLATION_INPAINTING_H
