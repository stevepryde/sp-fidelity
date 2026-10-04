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

// WGSL port of ffx_fsr2_sample.h. Overloads carry parameter-type suffixes (see
// ffx_core.wgsl). The Declare* macros at the end generate functions from a
// load callback; WGSL has no macros, so the headers that invoke them expand
// them by hand from the templates quoted there.

#ifndef FFX_FSR2_SAMPLE_H
#define FFX_FSR2_SAMPLE_H

// suppress warnings
// #pragma warning(disable: 4008): HLSL only.

struct FetchedBilinearSamples {

    fColor00: FfxFloat32x4,
    fColor10: FfxFloat32x4,

    fColor01: FfxFloat32x4,
    fColor11: FfxFloat32x4,
}

struct FetchedBicubicSamples {

    fColor00: FfxFloat32x4,
    fColor10: FfxFloat32x4,
    fColor20: FfxFloat32x4,
    fColor30: FfxFloat32x4,

    fColor01: FfxFloat32x4,
    fColor11: FfxFloat32x4,
    fColor21: FfxFloat32x4,
    fColor31: FfxFloat32x4,

    fColor02: FfxFloat32x4,
    fColor12: FfxFloat32x4,
    fColor22: FfxFloat32x4,
    fColor32: FfxFloat32x4,

    fColor03: FfxFloat32x4,
    fColor13: FfxFloat32x4,
    fColor23: FfxFloat32x4,
    fColor33: FfxFloat32x4,
}

#if FFX_HALF
struct FetchedBilinearSamplesMin16 {

    fColor00: FFX_MIN16_F4,
    fColor10: FFX_MIN16_F4,

    fColor01: FFX_MIN16_F4,
    fColor11: FFX_MIN16_F4,
}

struct FetchedBicubicSamplesMin16 {

    fColor00: FFX_MIN16_F4,
    fColor10: FFX_MIN16_F4,
    fColor20: FFX_MIN16_F4,
    fColor30: FFX_MIN16_F4,

    fColor01: FFX_MIN16_F4,
    fColor11: FFX_MIN16_F4,
    fColor21: FFX_MIN16_F4,
    fColor31: FFX_MIN16_F4,

    fColor02: FFX_MIN16_F4,
    fColor12: FFX_MIN16_F4,
    fColor22: FFX_MIN16_F4,
    fColor32: FFX_MIN16_F4,

    fColor03: FFX_MIN16_F4,
    fColor13: FFX_MIN16_F4,
    fColor23: FFX_MIN16_F4,
    fColor33: FFX_MIN16_F4,
}
#else //FFX_HALF
// #define FetchedBicubicSamplesMin16 FetchedBicubicSamples
// #define FetchedBilinearSamplesMin16 FetchedBilinearSamples
alias FetchedBicubicSamplesMin16 = FetchedBicubicSamples;
alias FetchedBilinearSamplesMin16 = FetchedBilinearSamples;
#endif //FFX_HALF

fn Linear_f32x4_f32x4_f32(A: FfxFloat32x4, B: FfxFloat32x4, t: FfxFloat32) -> FfxFloat32x4
{
    return A + (B - A) * t;
}

fn Bilinear_FetchedBilinearSamples_f32x2(BilinearSamples: FetchedBilinearSamples, fPxFrac: FfxFloat32x2) -> FfxFloat32x4
{
    let fColorX0: FfxFloat32x4 = Linear_f32x4_f32x4_f32(BilinearSamples.fColor00, BilinearSamples.fColor10, fPxFrac.x);
    let fColorX1: FfxFloat32x4 = Linear_f32x4_f32x4_f32(BilinearSamples.fColor01, BilinearSamples.fColor11, fPxFrac.x);
    let fColorXY: FfxFloat32x4 = Linear_f32x4_f32x4_f32(fColorX0, fColorX1, fPxFrac.y);
    return fColorXY;
}

#if FFX_HALF
fn Linear_f16x4_f16x4_f16(A: FFX_MIN16_F4, B: FFX_MIN16_F4, t: FFX_MIN16_F) -> FFX_MIN16_F4
{
    return A + (B - A) * t;
}

fn Bilinear_FetchedBilinearSamplesMin16_f16x2(BilinearSamples: FetchedBilinearSamplesMin16, fPxFrac: FFX_MIN16_F2) -> FFX_MIN16_F4
{
    let fColorX0: FFX_MIN16_F4 = Linear_f16x4_f16x4_f16(BilinearSamples.fColor00, BilinearSamples.fColor10, fPxFrac.x);
    let fColorX1: FFX_MIN16_F4 = Linear_f16x4_f16x4_f16(BilinearSamples.fColor01, BilinearSamples.fColor11, fPxFrac.x);
    let fColorXY: FFX_MIN16_F4 = Linear_f16x4_f16x4_f16(fColorX0, fColorX1, fPxFrac.y);
    return fColorXY;
}
#endif

fn Lanczos2NoClamp(x: FfxFloat32) -> FfxFloat32
{
    let PI: FfxFloat32 = 3.141592653589793f; // TODO: share SDK constants
    return select((sin(PI * x) / (PI * x)) * (sin(0.5f * PI * x) / (0.5f * PI * x)), 1.f, abs(x) < FSR2_EPSILON);
}

fn Lanczos2_f32(x_: FfxFloat32) -> FfxFloat32
{
    var x: FfxFloat32 = x_;
    x = ffxMin_f32_f32(abs(x), 2.0f);
    return Lanczos2NoClamp(x);
}

#if FFX_HALF

fn Lanczos2_f16(x_: FFX_MIN16_F) -> FFX_MIN16_F
{
    var x: FFX_MIN16_F = x_;
    x = ffxMin_f16_f16(abs(x), FFX_MIN16_F(2.0f));
    return FFX_MIN16_F(Lanczos2NoClamp(FfxFloat32(x)));
}
#endif //FFX_HALF

// FSR1 lanczos approximation. Input is x*x and must be <= 4.
fn Lanczos2ApproxSqNoClamp_f32(x2: FfxFloat32) -> FfxFloat32
{
    let a: FfxFloat32 = (2.0f / 5.0f) * x2 - 1;
    let b: FfxFloat32 = (1.0f / 4.0f) * x2 - 1;
    return ((25.0f / 16.0f) * a * a - (25.0f / 16.0f - 1)) * (b * b);
}

#if FFX_HALF
fn Lanczos2ApproxSqNoClamp_f16(x2: FFX_MIN16_F) -> FFX_MIN16_F
{
    let a: FFX_MIN16_F = FFX_MIN16_F(2.0f / 5.0f) * x2 - FFX_MIN16_F(1);
    let b: FFX_MIN16_F = FFX_MIN16_F(1.0f / 4.0f) * x2 - FFX_MIN16_F(1);
    return (FFX_MIN16_F(25.0f / 16.0f) * a * a - FFX_MIN16_F(25.0f / 16.0f - 1)) * (b * b);
}

// PairedLanczos2ApproxSqNoClamp: Xbox only (__XBOX_SCARLETT), never compiled
// here.

#endif //FFX_HALF

fn Lanczos2ApproxSq_f32(x2_: FfxFloat32) -> FfxFloat32
{
    var x2: FfxFloat32 = x2_;
    x2 = ffxMin_f32_f32(x2, 4.0f);
    return Lanczos2ApproxSqNoClamp_f32(x2);
}

#if FFX_HALF
fn Lanczos2ApproxSq_f16(x2_: FFX_MIN16_F) -> FFX_MIN16_F
{
    var x2: FFX_MIN16_F = x2_;
    x2 = ffxMin_f16_f16(x2, FFX_MIN16_F(4.0f));
    return Lanczos2ApproxSqNoClamp_f16(x2);
}

// PairedLanczos2ApproxSq: Xbox only (__XBOX_SCARLETT), never compiled here.

#endif //FFX_HALF

fn Lanczos2ApproxNoClamp_f32(x: FfxFloat32) -> FfxFloat32
{
    return Lanczos2ApproxSqNoClamp_f32(x * x);
}

#if FFX_HALF
fn Lanczos2ApproxNoClamp_f16(x: FFX_MIN16_F) -> FFX_MIN16_F
{
    return Lanczos2ApproxSqNoClamp_f16(x * x);
}
#endif //FFX_HALF

fn Lanczos2Approx_f32(x: FfxFloat32) -> FfxFloat32
{
    return Lanczos2ApproxSq_f32(x * x);
}

#if FFX_HALF
fn Lanczos2Approx_f16(x: FFX_MIN16_F) -> FFX_MIN16_F
{
    return Lanczos2ApproxSq_f16(x * x);
}
#endif //FFX_HALF

fn Lanczos2_UseLUT_f32(x: FfxFloat32) -> FfxFloat32
{
    return SampleLanczos2Weight(abs(x));
}

#if FFX_HALF
fn Lanczos2_UseLUT_f16(x: FFX_MIN16_F) -> FFX_MIN16_F
{
    return FFX_MIN16_F(SampleLanczos2Weight(FfxFloat32(abs(x))));
}

// Lanczos2_UseLUTNoAbs, Lanczos2_UseLUTNoAbsNoA16: Xbox only
// (__XBOX_SCARLETT), never compiled here.

#endif //FFX_HALF

fn Lanczos2_UseLUT_f32x4_f32x4_f32x4_f32x4_f32(fColor0: FfxFloat32x4, fColor1: FfxFloat32x4, fColor2: FfxFloat32x4, fColor3: FfxFloat32x4, t: FfxFloat32) -> FfxFloat32x4
{
    let fWeight0: FfxFloat32 = Lanczos2_UseLUT_f32(-1.f - t);
    let fWeight1: FfxFloat32 = Lanczos2_UseLUT_f32(-0.f - t);
    let fWeight2: FfxFloat32 = Lanczos2_UseLUT_f32(1.f - t);
    let fWeight3: FfxFloat32 = Lanczos2_UseLUT_f32(2.f - t);
    return (fWeight0 * fColor0 + fWeight1 * fColor1 + fWeight2 * fColor2 + fWeight3 * fColor3) / (fWeight0 + fWeight1 + fWeight2 + fWeight3);
}
#if FFX_HALF
fn Lanczos2_UseLUT_f16x4_f16x4_f16x4_f16x4_f16(fColor0: FFX_MIN16_F4, fColor1: FFX_MIN16_F4, fColor2: FFX_MIN16_F4, fColor3: FFX_MIN16_F4, t: FFX_MIN16_F) -> FFX_MIN16_F4
{
    let fWeight0: FFX_MIN16_F = Lanczos2_UseLUT_f16(FFX_MIN16_F(-1.f) - t);
    let fWeight1: FFX_MIN16_F = Lanczos2_UseLUT_f16(FFX_MIN16_F(-0.f) - t);
    let fWeight2: FFX_MIN16_F = Lanczos2_UseLUT_f16(FFX_MIN16_F(1.f) - t);
    let fWeight3: FFX_MIN16_F = Lanczos2_UseLUT_f16(FFX_MIN16_F(2.f) - t);
    return (fWeight0 * fColor0 + fWeight1 * fColor1 + fWeight2 * fColor2 + fWeight3 * fColor3) / (fWeight0 + fWeight1 + fWeight2 + fWeight3);
}
#endif

fn Lanczos2_f32x4_f32x4_f32x4_f32x4_f32(fColor0: FfxFloat32x4, fColor1: FfxFloat32x4, fColor2: FfxFloat32x4, fColor3: FfxFloat32x4, t: FfxFloat32) -> FfxFloat32x4
{
    let fWeight0: FfxFloat32 = Lanczos2_f32(-1.f - t);
    let fWeight1: FfxFloat32 = Lanczos2_f32(-0.f - t);
    let fWeight2: FfxFloat32 = Lanczos2_f32(1.f - t);
    let fWeight3: FfxFloat32 = Lanczos2_f32(2.f - t);
    return (fWeight0 * fColor0 + fWeight1 * fColor1 + fWeight2 * fColor2 + fWeight3 * fColor3) / (fWeight0 + fWeight1 + fWeight2 + fWeight3);
}

fn Lanczos2_FetchedBicubicSamples_f32x2(Samples: FetchedBicubicSamples, fPxFrac: FfxFloat32x2) -> FfxFloat32x4
{
    let fColorX0: FfxFloat32x4 = Lanczos2_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor00, Samples.fColor10, Samples.fColor20, Samples.fColor30, fPxFrac.x);
    let fColorX1: FfxFloat32x4 = Lanczos2_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor01, Samples.fColor11, Samples.fColor21, Samples.fColor31, fPxFrac.x);
    let fColorX2: FfxFloat32x4 = Lanczos2_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor02, Samples.fColor12, Samples.fColor22, Samples.fColor32, fPxFrac.x);
    let fColorX3: FfxFloat32x4 = Lanczos2_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor03, Samples.fColor13, Samples.fColor23, Samples.fColor33, fPxFrac.x);
    var fColorXY: FfxFloat32x4 = Lanczos2_f32x4_f32x4_f32x4_f32x4_f32(fColorX0, fColorX1, fColorX2, fColorX3, fPxFrac.y);

    // Deringing

    // TODO: only use 4 by checking jitter
    let iDeringingSampleCount: FfxInt32 = 4;
    let fDeringingSamples: array<FfxFloat32x4, 4> = array<FfxFloat32x4, 4>(
        Samples.fColor11,
        Samples.fColor21,
        Samples.fColor12,
        Samples.fColor22,
    );

    var fDeringingMin: FfxFloat32x4 = fDeringingSamples[0];
    var fDeringingMax: FfxFloat32x4 = fDeringingSamples[0];

    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 1; iSampleIndex < iDeringingSampleCount; iSampleIndex++) {

        fDeringingMin = ffxMin_f32x4_f32x4(fDeringingMin, fDeringingSamples[iSampleIndex]);
        fDeringingMax = ffxMax_f32x4_f32x4(fDeringingMax, fDeringingSamples[iSampleIndex]);
    }

    fColorXY = clamp(fColorXY, fDeringingMin, fDeringingMax);

    return fColorXY;
}

#if FFX_HALF
fn Lanczos2_f16x4_f16x4_f16x4_f16x4_f16(fColor0: FFX_MIN16_F4, fColor1: FFX_MIN16_F4, fColor2: FFX_MIN16_F4, fColor3: FFX_MIN16_F4, t: FFX_MIN16_F) -> FFX_MIN16_F4
{
    let fWeight0: FFX_MIN16_F = Lanczos2_f16(FFX_MIN16_F(-1.f) - t);
    let fWeight1: FFX_MIN16_F = Lanczos2_f16(FFX_MIN16_F(-0.f) - t);
    let fWeight2: FFX_MIN16_F = Lanczos2_f16(FFX_MIN16_F(1.f) - t);
    let fWeight3: FFX_MIN16_F = Lanczos2_f16(FFX_MIN16_F(2.f) - t);
    return (fWeight0 * fColor0 + fWeight1 * fColor1 + fWeight2 * fColor2 + fWeight3 * fColor3) / (fWeight0 + fWeight1 + fWeight2 + fWeight3);
}

fn Lanczos2_FetchedBicubicSamplesMin16_f16x2(Samples: FetchedBicubicSamplesMin16, fPxFrac: FFX_MIN16_F2) -> FFX_MIN16_F4
{
    let fColorX0: FFX_MIN16_F4 = Lanczos2_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor00, Samples.fColor10, Samples.fColor20, Samples.fColor30, fPxFrac.x);
    let fColorX1: FFX_MIN16_F4 = Lanczos2_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor01, Samples.fColor11, Samples.fColor21, Samples.fColor31, fPxFrac.x);
    let fColorX2: FFX_MIN16_F4 = Lanczos2_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor02, Samples.fColor12, Samples.fColor22, Samples.fColor32, fPxFrac.x);
    let fColorX3: FFX_MIN16_F4 = Lanczos2_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor03, Samples.fColor13, Samples.fColor23, Samples.fColor33, fPxFrac.x);
    var fColorXY: FFX_MIN16_F4 = Lanczos2_f16x4_f16x4_f16x4_f16x4_f16(fColorX0, fColorX1, fColorX2, fColorX3, fPxFrac.y);

    // Deringing

    // TODO: only use 4 by checking jitter
    let iDeringingSampleCount: FfxInt32 = 4;
    let fDeringingSamples: array<FFX_MIN16_F4, 4> = array<FFX_MIN16_F4, 4>(
        Samples.fColor11,
        Samples.fColor21,
        Samples.fColor12,
        Samples.fColor22,
    );

    var fDeringingMin: FFX_MIN16_F4 = fDeringingSamples[0];
    var fDeringingMax: FFX_MIN16_F4 = fDeringingSamples[0];

    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 1; iSampleIndex < iDeringingSampleCount; iSampleIndex++)
    {
        fDeringingMin = ffxMin_f16x4_f16x4(fDeringingMin, fDeringingSamples[iSampleIndex]);
        fDeringingMax = ffxMax_f16x4_f16x4(fDeringingMax, fDeringingSamples[iSampleIndex]);
    }

    fColorXY = clamp(fColorXY, fDeringingMin, fDeringingMax);

    return fColorXY;
}
#endif //FFX_HALF


fn Lanczos2LUT_FetchedBicubicSamples_f32x2(Samples: FetchedBicubicSamples, fPxFrac: FfxFloat32x2) -> FfxFloat32x4
{
    let fColorX0: FfxFloat32x4 = Lanczos2_UseLUT_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor00, Samples.fColor10, Samples.fColor20, Samples.fColor30, fPxFrac.x);
    let fColorX1: FfxFloat32x4 = Lanczos2_UseLUT_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor01, Samples.fColor11, Samples.fColor21, Samples.fColor31, fPxFrac.x);
    let fColorX2: FfxFloat32x4 = Lanczos2_UseLUT_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor02, Samples.fColor12, Samples.fColor22, Samples.fColor32, fPxFrac.x);
    let fColorX3: FfxFloat32x4 = Lanczos2_UseLUT_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor03, Samples.fColor13, Samples.fColor23, Samples.fColor33, fPxFrac.x);
    var fColorXY: FfxFloat32x4 = Lanczos2_UseLUT_f32x4_f32x4_f32x4_f32x4_f32(fColorX0, fColorX1, fColorX2, fColorX3, fPxFrac.y);

    // Deringing

    // TODO: only use 4 by checking jitter
    let iDeringingSampleCount: FfxInt32 = 4;
    let fDeringingSamples: array<FfxFloat32x4, 4> = array<FfxFloat32x4, 4>(
        Samples.fColor11,
        Samples.fColor21,
        Samples.fColor12,
        Samples.fColor22,
    );

    var fDeringingMin: FfxFloat32x4 = fDeringingSamples[0];
    var fDeringingMax: FfxFloat32x4 = fDeringingSamples[0];

    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 1; iSampleIndex < iDeringingSampleCount; iSampleIndex++) {

        fDeringingMin = ffxMin_f32x4_f32x4(fDeringingMin, fDeringingSamples[iSampleIndex]);
        fDeringingMax = ffxMax_f32x4_f32x4(fDeringingMax, fDeringingSamples[iSampleIndex]);
    }

    fColorXY = clamp(fColorXY, fDeringingMin, fDeringingMax);

    return fColorXY;
}

#if FFX_HALF

// Lanczos2ApplyWeightX, Lanczos2ApplyWeightY: Xbox only (__XBOX_SCARLETT),
// never compiled here.

fn Lanczos2LUT_FetchedBicubicSamplesMin16_f16x2(Samples: FetchedBicubicSamplesMin16, fPxFrac: FFX_MIN16_F2) -> FFX_MIN16_F4
{
    let fColorX0: FFX_MIN16_F4 = Lanczos2_UseLUT_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor00, Samples.fColor10, Samples.fColor20, Samples.fColor30, fPxFrac.x);
    let fColorX1: FFX_MIN16_F4 = Lanczos2_UseLUT_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor01, Samples.fColor11, Samples.fColor21, Samples.fColor31, fPxFrac.x);
    let fColorX2: FFX_MIN16_F4 = Lanczos2_UseLUT_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor02, Samples.fColor12, Samples.fColor22, Samples.fColor32, fPxFrac.x);
    let fColorX3: FFX_MIN16_F4 = Lanczos2_UseLUT_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor03, Samples.fColor13, Samples.fColor23, Samples.fColor33, fPxFrac.x);
    var fColorXY: FFX_MIN16_F4 = Lanczos2_UseLUT_f16x4_f16x4_f16x4_f16x4_f16(fColorX0, fColorX1, fColorX2, fColorX3, fPxFrac.y);

    // Deringing

    // TODO: only use 4 by checking jitter
    let iDeringingSampleCount: FfxInt32 = 4;
    let fDeringingSamples: array<FFX_MIN16_F4, 4> = array<FFX_MIN16_F4, 4>(
        Samples.fColor11,
        Samples.fColor21,
        Samples.fColor12,
        Samples.fColor22,
    );

    var fDeringingMin: FFX_MIN16_F4 = fDeringingSamples[0];
    var fDeringingMax: FFX_MIN16_F4 = fDeringingSamples[0];

    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 1; iSampleIndex < iDeringingSampleCount; iSampleIndex++)
    {
        fDeringingMin = ffxMin_f16x4_f16x4(fDeringingMin, fDeringingSamples[iSampleIndex]);
        fDeringingMax = ffxMax_f16x4_f16x4(fDeringingMax, fDeringingSamples[iSampleIndex]);
    }

    fColorXY = clamp(fColorXY, fDeringingMin, fDeringingMax);

    return fColorXY;
}
#endif //FFX_HALF



fn Lanczos2Approx_f32x4_f32x4_f32x4_f32x4_f32(fColor0: FfxFloat32x4, fColor1: FfxFloat32x4, fColor2: FfxFloat32x4, fColor3: FfxFloat32x4, t: FfxFloat32) -> FfxFloat32x4
{
    let fWeight0: FfxFloat32 = Lanczos2ApproxNoClamp_f32(-1.f - t);
    let fWeight1: FfxFloat32 = Lanczos2ApproxNoClamp_f32(-0.f - t);
    let fWeight2: FfxFloat32 = Lanczos2ApproxNoClamp_f32(1.f - t);
    let fWeight3: FfxFloat32 = Lanczos2ApproxNoClamp_f32(2.f - t);
    return (fWeight0 * fColor0 + fWeight1 * fColor1 + fWeight2 * fColor2 + fWeight3 * fColor3) / (fWeight0 + fWeight1 + fWeight2 + fWeight3);
}

#if FFX_HALF
fn Lanczos2Approx_f16x4_f16x4_f16x4_f16x4_f16(fColor0: FFX_MIN16_F4, fColor1: FFX_MIN16_F4, fColor2: FFX_MIN16_F4, fColor3: FFX_MIN16_F4, t: FFX_MIN16_F) -> FFX_MIN16_F4
{
    let fWeight0: FFX_MIN16_F = Lanczos2ApproxNoClamp_f16(FFX_MIN16_F(-1.f) - t);
    let fWeight1: FFX_MIN16_F = Lanczos2ApproxNoClamp_f16(FFX_MIN16_F(-0.f) - t);
    let fWeight2: FFX_MIN16_F = Lanczos2ApproxNoClamp_f16(FFX_MIN16_F(1.f) - t);
    let fWeight3: FFX_MIN16_F = Lanczos2ApproxNoClamp_f16(FFX_MIN16_F(2.f) - t);
    return (fWeight0 * fColor0 + fWeight1 * fColor1 + fWeight2 * fColor2 + fWeight3 * fColor3) / (fWeight0 + fWeight1 + fWeight2 + fWeight3);
}
#endif //FFX_HALF

fn Lanczos2Approx_FetchedBicubicSamples_f32x2(Samples: FetchedBicubicSamples, fPxFrac: FfxFloat32x2) -> FfxFloat32x4
{
    let fColorX0: FfxFloat32x4 = Lanczos2Approx_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor00, Samples.fColor10, Samples.fColor20, Samples.fColor30, fPxFrac.x);
    let fColorX1: FfxFloat32x4 = Lanczos2Approx_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor01, Samples.fColor11, Samples.fColor21, Samples.fColor31, fPxFrac.x);
    let fColorX2: FfxFloat32x4 = Lanczos2Approx_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor02, Samples.fColor12, Samples.fColor22, Samples.fColor32, fPxFrac.x);
    let fColorX3: FfxFloat32x4 = Lanczos2Approx_f32x4_f32x4_f32x4_f32x4_f32(Samples.fColor03, Samples.fColor13, Samples.fColor23, Samples.fColor33, fPxFrac.x);
    var fColorXY: FfxFloat32x4 = Lanczos2Approx_f32x4_f32x4_f32x4_f32x4_f32(fColorX0, fColorX1, fColorX2, fColorX3, fPxFrac.y);

    // Deringing

    // TODO: only use 4 by checking jitter
    let iDeringingSampleCount: FfxInt32 = 4;
    let fDeringingSamples: array<FfxFloat32x4, 4> = array<FfxFloat32x4, 4>(
        Samples.fColor11,
        Samples.fColor21,
        Samples.fColor12,
        Samples.fColor22,
    );

    var fDeringingMin: FfxFloat32x4 = fDeringingSamples[0];
    var fDeringingMax: FfxFloat32x4 = fDeringingSamples[0];

    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 1; iSampleIndex < iDeringingSampleCount; iSampleIndex++)
    {
        fDeringingMin = ffxMin_f32x4_f32x4(fDeringingMin, fDeringingSamples[iSampleIndex]);
        fDeringingMax = ffxMax_f32x4_f32x4(fDeringingMax, fDeringingSamples[iSampleIndex]);
    }

    fColorXY = clamp(fColorXY, fDeringingMin, fDeringingMax);

    return fColorXY;
}

#if FFX_HALF
fn Lanczos2Approx_FetchedBicubicSamplesMin16_f16x2(Samples: FetchedBicubicSamplesMin16, fPxFrac: FFX_MIN16_F2) -> FFX_MIN16_F4
{
    let fColorX0: FFX_MIN16_F4 = Lanczos2Approx_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor00, Samples.fColor10, Samples.fColor20, Samples.fColor30, fPxFrac.x);
    let fColorX1: FFX_MIN16_F4 = Lanczos2Approx_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor01, Samples.fColor11, Samples.fColor21, Samples.fColor31, fPxFrac.x);
    let fColorX2: FFX_MIN16_F4 = Lanczos2Approx_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor02, Samples.fColor12, Samples.fColor22, Samples.fColor32, fPxFrac.x);
    let fColorX3: FFX_MIN16_F4 = Lanczos2Approx_f16x4_f16x4_f16x4_f16x4_f16(Samples.fColor03, Samples.fColor13, Samples.fColor23, Samples.fColor33, fPxFrac.x);
    var fColorXY: FFX_MIN16_F4 = Lanczos2Approx_f16x4_f16x4_f16x4_f16x4_f16(fColorX0, fColorX1, fColorX2, fColorX3, fPxFrac.y);

    // Deringing

    // TODO: only use 4 by checking jitter
    let iDeringingSampleCount: FfxInt32 = 4;
    let fDeringingSamples: array<FFX_MIN16_F4, 4> = array<FFX_MIN16_F4, 4>(
        Samples.fColor11,
        Samples.fColor21,
        Samples.fColor12,
        Samples.fColor22,
    );

    var fDeringingMin: FFX_MIN16_F4 = fDeringingSamples[0];
    var fDeringingMax: FFX_MIN16_F4 = fDeringingSamples[0];

    FFX_UNROLL
    for (var iSampleIndex: FfxInt32 = 1; iSampleIndex < iDeringingSampleCount; iSampleIndex++)
    {
        fDeringingMin = ffxMin_f16x4_f16x4(fDeringingMin, fDeringingSamples[iSampleIndex]);
        fDeringingMax = ffxMax_f16x4_f16x4(fDeringingMax, fDeringingSamples[iSampleIndex]);
    }

    fColorXY = clamp(fColorXY, fDeringingMin, fDeringingMax);

    return fColorXY;
}
#endif

// Clamp by offset direction. Assuming iPxSample is already in range and iPxOffset is compile time constant.
fn ClampCoord_i32x2_i32x2_i32x2(iPxSample: FfxInt32x2, iPxOffset: FfxInt32x2, iTextureSize: FfxInt32x2) -> FfxInt32x2
{
    var result: FfxInt32x2 = iPxSample + iPxOffset;
    result.x = select(result.x, ffxMax_i32_i32(result.x, 0), (iPxOffset.x < 0));
    result.x = select(result.x, ffxMin_i32_i32(result.x, iTextureSize.x - 1), (iPxOffset.x > 0));
    result.y = select(result.y, ffxMax_i32_i32(result.y, 0), (iPxOffset.y < 0));
    result.y = select(result.y, ffxMin_i32_i32(result.y, iTextureSize.y - 1), (iPxOffset.y > 0));
    return result;
}
#if FFX_HALF
fn ClampCoord_i16x2_i16x2_i16x2(iPxSample: FFX_MIN16_I2, iPxOffset: FFX_MIN16_I2, iTextureSize: FFX_MIN16_I2) -> FFX_MIN16_I2
{
    var result: FFX_MIN16_I2 = iPxSample + iPxOffset;
    result.x = select(result.x, ffxMax_i16_i16(result.x, FFX_MIN16_I(0)), (iPxOffset.x < FFX_MIN16_I(0)));
    result.x = select(result.x, ffxMin_i16_i16(result.x, iTextureSize.x - FFX_MIN16_I(1)), (iPxOffset.x > FFX_MIN16_I(0)));
    result.y = select(result.y, ffxMax_i16_i16(result.y, FFX_MIN16_I(0)), (iPxOffset.y < FFX_MIN16_I(0)));
    result.y = select(result.y, ffxMin_i16_i16(result.y, iTextureSize.y - FFX_MIN16_I(1)), (iPxOffset.y > FFX_MIN16_I(0)));
    return result;
}
#endif //FFX_HALF

// WGSL: the SDK's function-generating macros have no WGSL form. A header that
// invokes one writes out the generated function, named as the invocation
// names it, with the WGSL names of the macro arguments:
//
// DeclareCustomFetchBicubicSamplesWithType(SampleType, TextureType, AddrType, Name, LoadTexture)
//     SampleType Name(AddrType iPxSample, AddrType iTextureSize): each of the
//     16 fColorXY members, X and Y in -1..+2 in the declaration order above, is
//     TextureType(LoadTexture(ClampCoord(iPxSample, AddrType(X, Y), iTextureSize))).
// DeclareCustomFetchBicubicSamples(Name, LoadTexture): SampleType
//     FetchedBicubicSamples, TextureType FfxFloat32x4, AddrType FfxInt32x2.
// DeclareCustomFetchBicubicSamplesMin16(Name, LoadTexture): SampleType
//     FetchedBicubicSamplesMin16, TextureType FFX_MIN16_F4, AddrType FfxInt32x2.
// DeclareCustomFetchBilinearSamplesWithType(SampleType, TextureType, AddrType, Name, LoadTexture)
//     As above with fColor00, fColor10, fColor01 and fColor11 at offsets
//     (+0, +0), (+1, +0), (+0, +1) and (+1, +1).
// DeclareCustomFetchBilinearSamples(Name, LoadTexture) and
// DeclareCustomFetchBilinearSamplesMin16(Name, LoadTexture): as the bicubic ones.
// DeclareCustomTextureSample(Name, InterpolateSamples, FetchSamples)
//     FfxFloat32x4 Name(FfxFloat32x2 fUvSample, FfxInt32x2 iTextureSize)
//     {
//         FfxFloat32x2 fPxSample = (fUvSample * FfxFloat32x2(iTextureSize)) - FfxFloat32x2(0.5f, 0.5f);
//         /* Clamp base coords */
//         fPxSample.x = ffxMax(0.0f, ffxMin(FfxFloat32(iTextureSize.x), fPxSample.x));
//         fPxSample.y = ffxMax(0.0f, ffxMin(FfxFloat32(iTextureSize.y), fPxSample.y));
//         /* */
//         FfxInt32x2 iPxSample = FfxInt32x2(floor(fPxSample));
//         FfxFloat32x2 fPxFrac = ffxFract(fPxSample);
//         FfxFloat32x4 fColorXY = FfxFloat32x4(InterpolateSamples(FetchSamples(iPxSample, iTextureSize), fPxFrac));
//         return fColorXY;
//     }
// DeclareCustomTextureSampleMin16(Name, InterpolateSamples, FetchSamples)
//     As above, returning FFX_MIN16_F4, with FFX_MIN16_F2 fPxFrac =
//     FFX_MIN16_F2(ffxFract(fPxSample)) and FFX_MIN16_F4 fColorXY =
//     FFX_MIN16_F4(InterpolateSamples(FetchSamples(iPxSample, iTextureSize), fPxFrac)).
//
// #define FFX_FSR2_CONCAT_ID(x, y) x ## y
// #define FFX_FSR2_CONCAT(x, y) FFX_FSR2_CONCAT_ID(x, y)
// #define FFX_FSR2_SAMPLER_1D_0 Lanczos2
// #define FFX_FSR2_SAMPLER_1D_1 Lanczos2LUT
// #define FFX_FSR2_SAMPLER_1D_2 Lanczos2Approx
// #define FFX_FSR2_GET_LANCZOS_SAMPLER1D(x) FFX_FSR2_CONCAT(FFX_FSR2_SAMPLER_1D_, x)
// WGSL: the invoking header selects among the three with
// #if <option> == 0 / #elif <option> == 1 / #else.

#endif //!defined( FFX_FSR2_SAMPLE_H )
