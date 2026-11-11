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

// WGSL port of ffx_frameinterpolation.h.

#ifndef FFX_FRAMEINTERPOLATION_H
#define FFX_FRAMEINTERPOLATION_H

struct InterpolationSourceColor
{
    fRaw: FfxFloat32x3,
    fLinear: FfxFloat32x3,
    fBilinearWeightSum: FfxFloat32,
}

fn NewInterpolationSourceColor() -> InterpolationSourceColor
{
    var c: InterpolationSourceColor;
    c.fRaw = FfxFloat32x3(0.0, 0.0, 0.0);
    c.fLinear = FfxFloat32x3(0.0, 0.0, 0.0);
    c.fBilinearWeightSum = 0.0;
    return c;
}

fn SampleTextureBilinear(isCurrent: FfxBoolean, fUv: FfxFloat32x2, fMotionVector: FfxFloat32x2, texSize: FfxInt32x2) -> InterpolationSourceColor
{
    var result: InterpolationSourceColor = NewInterpolationSourceColor();

    var fReprojectedUv: FfxFloat32x2 = fUv + fMotionVector;
    var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fReprojectedUv, texSize);

    var fColor: FfxFloat32x3 = FfxFloat32x3(0.0, 0.0, 0.0);
    var fWeightSum: FfxFloat32 = 0.0f;
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++) {

        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

        if (IsInRect(iSamplePos, InterpolationRectBase(), InterpolationRectSize()))
        {
            var fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];

            if (isCurrent) {
                fColor += LoadCurrentBackbuffer(iSamplePos).rgb * fWeight;
            } else {
                fColor += LoadPreviousBackbuffer(iSamplePos).rgb * fWeight;
            }
            fWeightSum += fWeight;
        }
    }

    //normalize colors
    fColor = select(FfxFloat32x3(0.0), fColor / fWeightSum, fWeightSum != 0.0);

    result.fRaw               = fColor;
    result.fLinear            = RawRGBToLinear(fColor);
    result.fBilinearWeightSum = fWeightSum;

    return result;
}

fn updateInPaintingWeight(fInPaintingWeight: ptr<function, FfxFloat32>, fFactor: FfxFloat32)
{
    (*fInPaintingWeight) = ffxSaturate_f32(max((*fInPaintingWeight), fFactor));
}

fn computeInterpolatedColor(iPxPos: FfxUInt32x2, fInterpolatedColor: ptr<function, FfxFloat32x3>, fInPaintingWeight: ptr<function, FfxFloat32>)
{
    let fUvInInterpolationRect: FfxFloat32x2 = (FfxFloat32x2(FfxInt32x2(iPxPos) - InterpolationRectBase()) + 0.5f) / FfxFloat32x2(InterpolationRectSize());
    let fUvInScreenSpace: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(DisplaySize());
    let fLrUvInInterpolationRect: FfxFloat32x2 = fUvInInterpolationRect * (FfxFloat32x2(RenderSize()) / FfxFloat32x2(GetMaxRenderSize()));

    let fUvLetterBoxScale: FfxFloat32x2 = FfxFloat32x2(InterpolationRectSize()) / FfxFloat32x2(DisplaySize());

    // game MV are top left aligned, the function scales them to render res UV
    var gameMv: VectorFieldEntry;
    LoadInpaintedGameFieldMv(fUvInInterpolationRect, &gameMv);

    // OF is done on the back buffers which already have black bars
    var ofMv: VectorFieldEntry;
    SampleOpticalFlowMotionVectorField(fUvInScreenSpace, &ofMv);

    // Binarize disucclusion factor
    var fDisocclusionFactor: FfxFloat32x2 = FfxFloat32x2((ffxSaturate_f32x2(SampleDisocclusionMask(fLrUvInInterpolationRect).xy) ==  FfxFloat32x2(1.0, 1.0)));

    var fPrevColorGame: InterpolationSourceColor = SampleTextureBilinear(false, fUvInScreenSpace, gameMv.fMotionVector * fUvLetterBoxScale, DisplaySize()); // Get in previous frame buffer, the color of interpolated pixel
    var fCurrColorGame: InterpolationSourceColor = SampleTextureBilinear(true, fUvInScreenSpace, -gameMv.fMotionVector * fUvLetterBoxScale, DisplaySize()); // Get color in current framebuffer, of color of interpolated pixel

    var fPrevColorOF: InterpolationSourceColor = SampleTextureBilinear(false, fUvInScreenSpace, ofMv.fMotionVector * fUvLetterBoxScale, DisplaySize());
    var fCurrColorOF: InterpolationSourceColor = SampleTextureBilinear(true, fUvInScreenSpace, -ofMv.fMotionVector * fUvLetterBoxScale, DisplaySize());

    var fDisoccludedFactor: FfxFloat32 = 0.0f;

    // Disocclusion logic
    {
        fDisocclusionFactor.x *= FfxFloat32(!gameMv.bPosOutside); // fDisocclusionFactor.x of 1 means the pos of interpolated pixel is within bounds of previous frame.
        fDisocclusionFactor.y *= FfxFloat32(!gameMv.bNegOutside); // fDisocclusionFactor.y of 1 means the pos of interpolated pixel is within bounds of current frame

        // Inpaint in bi-directional disocclusion areas
        updateInPaintingWeight(fInPaintingWeight, FfxFloat32(length(fDisocclusionFactor) <= FFX_FRAMEINTERPOLATION_EPSILON));

        var t: FfxFloat32 = 0.5f;
        t += 0.5f * (1 - (fDisocclusionFactor.x));
        t -= 0.5f * (1 - (fDisocclusionFactor.y));
        // Say if fDisocclusionFactor.x is 1 and fDisocclusionFactor.y = 0, then t will be 0. (*fInterpolatedColor) will be entirely from fPrevColorGame
        (*fInterpolatedColor) = mix(fPrevColorGame.fRaw, fCurrColorGame.fRaw, ffxSaturate_f32(t));
        fDisoccludedFactor = ffxSaturate_f32(1 - min(fDisocclusionFactor.x, fDisocclusionFactor.y));

        if (fPrevColorGame.fBilinearWeightSum == 0.0f)
        {
            (*fInterpolatedColor) = fCurrColorGame.fRaw;
        }
        else if (fCurrColorGame.fBilinearWeightSum == 0.0f)
        {
            (*fInterpolatedColor) = fPrevColorGame.fRaw;
        }
        if (fPrevColorGame.fBilinearWeightSum == 0 && fCurrColorGame.fBilinearWeightSum == 0)
        {
            (*fInPaintingWeight) = 1.0f;
        }
    }

    {

        var ofT: FfxFloat32 = 0.5f;

        if (fPrevColorOF.fBilinearWeightSum > 0 && fCurrColorOF.fBilinearWeightSum > 0)
        {
            ofT = 0.5f;
        }
        else if (fPrevColorOF.fBilinearWeightSum > 0)
        {
            ofT = 0;
        } else {
            ofT = 1;
        }

        let ofColor: FfxFloat32x3 = mix(fPrevColorOF.fRaw, fCurrColorOF.fRaw, ofT);

        var fOF_Sim: FfxFloat32 = NormalizedDot3(fPrevColorOF.fRaw, fCurrColorOF.fRaw);
        var fGame_Sim: FfxFloat32 = NormalizedDot3(fPrevColorGame.fRaw, fCurrColorGame.fRaw);

        fGame_Sim = mix(max(FFX_FRAMEINTERPOLATION_EPSILON, fGame_Sim), 1.0f, ffxSaturate_f32(fDisoccludedFactor));
        var fGameMvBias: FfxFloat32 = pow(ffxSaturate_f32(fGame_Sim / max(FFX_FRAMEINTERPOLATION_EPSILON, fOF_Sim)), 1.0f);

        let fFrameIndexFactor: FfxFloat32 = FfxFloat32(FrameIndexSinceLastReset() < 10);
        fGameMvBias = mix(fGameMvBias, 1.0f, fFrameIndexFactor);

        (*fInterpolatedColor) = mix(ofColor, (*fInterpolatedColor), ffxSaturate_f32(fGameMvBias));
    }
}

fn computeFrameinterpolation(iPxPos: FfxInt32x2)
{
    var fColor: FfxFloat32x3            = FfxFloat32x3(0, 0, 0);
    var fInPaintingWeight: FfxFloat32 = 0.0f;

    if (IsInRect(iPxPos, InterpolationRectBase(), InterpolationRectSize()) == false || FrameIndexSinceLastReset() == 0)
    {
        // if we just reset or we are out of the interpolation rect, copy the current back buffer and don't interpolate
        fColor = LoadCurrentBackbuffer(iPxPos);
    }
    else
    {
        computeInterpolatedColor(FfxUInt32x2(iPxPos), &fColor, &fInPaintingWeight);
    }

    StoreFrameinterpolationOutput(FfxInt32x2(iPxPos), FfxFloat32x4(fColor, fInPaintingWeight));
}

#endif  // FFX_FRAMEINTERPOLATION_H
