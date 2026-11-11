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
struct LumaInstabilityFactorData
{
    fLumaHistory: FfxFloat32x4,
    fLumaInstabilityFactor: FfxFloat32,
}

fn ComputeLumaInstabilityFactor(data_: LumaInstabilityFactorData, fCurrentFrameLuma: FfxFloat32, fFarthestDepthInMeters: FfxFloat32) -> LumaInstabilityFactorData
{
    var data: LumaInstabilityFactorData = data_;
    var N_MINUS_1: FfxInt32 = 0;
    var N_MINUS_2: FfxInt32 = 1;
    var N_MINUS_3: FfxInt32 = 2;
    var N_MINUS_4: FfxInt32 = 3;

    var fLumaInstability: FfxFloat32 = 0.0f;
    var fDiffs0: FfxFloat32 = (fCurrentFrameLuma - data.fLumaHistory[N_MINUS_1]);
    var fSimilarity0: FfxFloat32 = MinDividedByMax_f32_f32_f32(fCurrentFrameLuma, data.fLumaHistory[N_MINUS_1], 1.0f);

    var fMaxSimilarity: FfxFloat32 = fSimilarity0;

    if (fSimilarity0 < 1.0f) {
        for (var i: FfxInt32 = N_MINUS_2; i <= N_MINUS_4; i++) {
            var fDiffs1: FfxFloat32 = (fCurrentFrameLuma - data.fLumaHistory[i]);
            var fSimilarity1: FfxFloat32 = MinDividedByMax_f32_f32(fCurrentFrameLuma, data.fLumaHistory[i]);

            if (sign(fDiffs0) == sign(fDiffs1)) {

                fMaxSimilarity = max(fMaxSimilarity, fSimilarity1);
            }
        }

        fLumaInstability = FfxFloat32(fMaxSimilarity > fSimilarity0);
    }

    // Shift history
    data.fLumaHistory[N_MINUS_4] = data.fLumaHistory[N_MINUS_3];
    data.fLumaHistory[N_MINUS_3] = data.fLumaHistory[N_MINUS_2];
    data.fLumaHistory[N_MINUS_2] = data.fLumaHistory[N_MINUS_1];
    data.fLumaHistory[N_MINUS_1] = fCurrentFrameLuma;

    data.fLumaHistory /= Exposure();

    data.fLumaInstabilityFactor = fLumaInstability * FfxFloat32(data.fLumaHistory[N_MINUS_4] != 0);

    return data;
}

fn LumaInstability(iPxPos: FfxInt32x2)
{
    var data: LumaInstabilityFactorData ;
    data.fLumaInstabilityFactor = 0.0f;
    data.fLumaHistory = FfxFloat32x4(0.0f, 0.0f, 0.0f, 0.0f);

    var fDilatedMotionVector: FfxFloat32x2 = LoadDilatedMotionVector(FfxUInt32x2(iPxPos));
    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(RenderSize());
    var fUvCurrFrameJittered: FfxFloat32x2 = fUv + Jitter() / FfxFloat32x2(RenderSize());
    var fUvPrevFrameJittered: FfxFloat32x2 = fUv + PreviousFrameJitter() / FfxFloat32x2(PreviousFrameRenderSize());
    var fReprojectedUv: FfxFloat32x2 = fUvPrevFrameJittered + fDilatedMotionVector;

    if (IsUvInside(fReprojectedUv))
    {
        var fUvReactive_HW: FfxFloat32x2 = ClampUv(fUvCurrFrameJittered, RenderSize(), MaxRenderSize());

        var fDilatedReactiveMasks: FfxFloat32x4 = SampleDilatedReactiveMasks(fUvReactive_HW);
        var fReactiveMask: FfxFloat32 = ffxSaturate_f32(fDilatedReactiveMasks[REACTIVE]);
        var fDisocclusion: FfxFloat32 = ffxSaturate_f32(fDilatedReactiveMasks[DISOCCLUSION]);
        var fShadingChange: FfxFloat32 = ffxSaturate_f32(fDilatedReactiveMasks[SHADING_CHANGE]);
        var fAccumulation: FfxFloat32 = ffxSaturate_f32(fDilatedReactiveMasks[ACCUMULAION]);

        var bAccumulationFactor: FfxBoolean = fAccumulation > 0.9f;

        var bComputeInstability: FfxBoolean = bAccumulationFactor;

        if (bComputeInstability) {

            var fUv_HW: FfxFloat32x2 = ClampUv(fUvCurrFrameJittered, RenderSize(), MaxRenderSize());
            var fCurrentFrameLuma: FfxFloat32 = SampleCurrentLuma(fUv_HW) * Exposure();

            var fReprojectedUv_HW: FfxFloat32x2 = ClampUv(fReprojectedUv, PreviousFrameRenderSize(), MaxRenderSize());
            data.fLumaHistory                    = SampleLumaHistory(fReprojectedUv_HW) * DeltaPreExposure() * Exposure();

            // The SDK helper never reads its depth parameter. DXC removes
            // that texture read and binding; WGSL must omit the read explicitly.
            data = ComputeLumaInstabilityFactor(data, fCurrentFrameLuma, 0.0f);

            var fVelocityWeight: FfxFloat32 = 1.0f - ffxSaturate_f32(Get4KVelocity(fDilatedMotionVector) / 20.0f);
            data.fLumaInstabilityFactor *= fVelocityWeight * (1.0f - fDisocclusion) * (1.0f - fReactiveMask) * (1.0f - fShadingChange);
        }
    }

    StoreLumaHistory(FfxUInt32x2(iPxPos), data.fLumaHistory);
    StoreLumaInstability(FfxUInt32x2(iPxPos), data.fLumaInstabilityFactor);
}
