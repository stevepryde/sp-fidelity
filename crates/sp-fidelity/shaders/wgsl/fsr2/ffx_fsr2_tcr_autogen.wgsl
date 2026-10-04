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

// WGSL port of ffx_fsr2_tcr_autogen.h.
//
// WGSL: HLSL converts implicitly where this port writes the conversion:
// FFX_MIN16_I2 arguments to the callbacks' FfxUInt32x2, FFX_MIN16_F to and
// from FfxFloat32, and a FFX_MIN16_F operand of a comparison with a float to
// float (DXC compares in float). FFX_MIN16_F is f16 with FFX_HALF and f32
// without, so a call of an overloaded core function names the overload of
// each (#if FFX_HALF). The SDK's scalar cond ? a : b is select(b, a, cond);
// both sides are free of side effects.

#define USE_YCOCG 1

#define fAutogenEpsilon 0.01f

// EXPERIMENTAL

fn ComputeAutoTC_01(uDispatchThreadId: FFX_MIN16_I2, iPrevIdx: FFX_MIN16_I2) -> FFX_MIN16_F
{
    var colorPreAlpha: FfxFloat32x3 = LoadOpaqueOnly(uDispatchThreadId);
    var colorPostAlpha: FfxFloat32x3 = LoadInputColor(FfxUInt32x2(uDispatchThreadId));
    var colorPrevPreAlpha: FfxFloat32x3 = LoadPrevPreAlpha(iPrevIdx);
    var colorPrevPostAlpha: FfxFloat32x3 = LoadPrevPostAlpha(iPrevIdx);

#if USE_YCOCG    
    colorPreAlpha = RGBToYCoCg_f32x3(colorPreAlpha);
    colorPostAlpha = RGBToYCoCg_f32x3(colorPostAlpha);
    colorPrevPreAlpha = RGBToYCoCg_f32x3(colorPrevPreAlpha);
    colorPrevPostAlpha = RGBToYCoCg_f32x3(colorPrevPostAlpha);
#endif

    let colorDeltaCurr: FfxFloat32x3 = colorPostAlpha - colorPreAlpha;
    let colorDeltaPrev: FfxFloat32x3 = colorPrevPostAlpha - colorPrevPreAlpha;
    let hasAlpha: bool = any(abs(colorDeltaCurr) > FfxFloat32x3(fAutogenEpsilon, fAutogenEpsilon, fAutogenEpsilon));
    let hadAlpha: bool = any(abs(colorDeltaPrev) > FfxFloat32x3(fAutogenEpsilon, fAutogenEpsilon, fAutogenEpsilon));

    let X: FfxFloat32x3 = colorPreAlpha;
    let Y: FfxFloat32x3 = colorPostAlpha;
    let Z: FfxFloat32x3 = colorPrevPreAlpha;
    let W: FfxFloat32x3 = colorPrevPostAlpha;

    var retVal: FFX_MIN16_F = FFX_MIN16_F(ffxSaturate_f32(dot(abs(abs(Y - X) - abs(W - Z)), FfxFloat32x3(1, 1, 1))));

    // cleanup very small values
    retVal = select(FFX_MIN16_F(1.f), FFX_MIN16_F(0.0f), (FfxFloat32(retVal) < TcThreshold()));

    return retVal;
}

// works ok: thin edges
fn ComputeAutoTC_02(uDispatchThreadId: FFX_MIN16_I2, iPrevIdx: FFX_MIN16_I2) -> FFX_MIN16_F
{
    var colorPreAlpha: FfxFloat32x3 = LoadOpaqueOnly(uDispatchThreadId);
    var colorPostAlpha: FfxFloat32x3 = LoadInputColor(FfxUInt32x2(uDispatchThreadId));
    var colorPrevPreAlpha: FfxFloat32x3 = LoadPrevPreAlpha(iPrevIdx);
    var colorPrevPostAlpha: FfxFloat32x3 = LoadPrevPostAlpha(iPrevIdx);

#if USE_YCOCG    
    colorPreAlpha = RGBToYCoCg_f32x3(colorPreAlpha);
    colorPostAlpha = RGBToYCoCg_f32x3(colorPostAlpha);
    colorPrevPreAlpha = RGBToYCoCg_f32x3(colorPrevPreAlpha);
    colorPrevPostAlpha = RGBToYCoCg_f32x3(colorPrevPostAlpha);
#endif

    let colorDelta: FfxFloat32x3 = colorPostAlpha - colorPreAlpha;
    let colorPrevDelta: FfxFloat32x3 = colorPrevPostAlpha - colorPrevPreAlpha;
    let hasAlpha: bool = any(abs(colorDelta) > FfxFloat32x3(fAutogenEpsilon, fAutogenEpsilon, fAutogenEpsilon));
    let hadAlpha: bool = any(abs(colorPrevDelta) > FfxFloat32x3(fAutogenEpsilon, fAutogenEpsilon, fAutogenEpsilon));

    let delta: FfxFloat32x3 = colorPostAlpha - colorPreAlpha;              //prev+1*d = post   => d = color, alpha =
    let deltaPrev: FfxFloat32x3 = colorPrevPostAlpha - colorPrevPreAlpha;

    let X: FfxFloat32x3 = colorPrevPreAlpha;
    let N: FfxFloat32x3 = colorPreAlpha - colorPrevPreAlpha;
    let YAminusXA: FfxFloat32x3 = colorPrevPostAlpha - colorPrevPreAlpha;
    let NminusNA: FfxFloat32x3 = colorPostAlpha - colorPrevPostAlpha;

    let A: FfxFloat32x3 = select(FfxFloat32x3(0, 0, 0), NminusNA / max(FfxFloat32x3(fAutogenEpsilon, fAutogenEpsilon, fAutogenEpsilon), N), (hasAlpha || hadAlpha));

    var retVal: FFX_MIN16_F = FFX_MIN16_F( max(max(A.x, A.y), A.z) );

    // only pixels that have significantly changed in color shuold be considered
#if FFX_HALF
    retVal = ffxSaturate_f16(retVal * FFX_MIN16_F(length(colorPostAlpha - colorPrevPostAlpha)) );
#else
    retVal = ffxSaturate_f32(retVal * FFX_MIN16_F(length(colorPostAlpha - colorPrevPostAlpha)) );
#endif

    return retVal;
}

// This function computes the TransparencyAndComposition mask:
// This mask indicates pixels that should discard locks and apply color clamping.
// 
// Typically this is the case for translucent pixels (that don't write depth values) or pixels where the correctness of 
// the MVs can not be guaranteed (e.g. procedutal movement or vegetation that does not have MVs to reduce the cost during rasterization)
// Also, large changes in color due to changed lighting should be marked to remove locks on pixels with "old" lighting.
//
// This function takes a opaque only and a final texture and uses internal copies of those textures from the last frame.
// The function tries to determine where the color changes between opaque only and final image to determine the pixels that use transparency.
// Also it uses the previous frames and detects where the use of transparency changed to mark those pixels.
// Additionally it marks pixels where the color changed significantly in the opaque only image, e.g. due to lighting or texture animation.
// 
// In the final step it stores the current textures in internal textures for the next frame

fn ComputeTransparencyAndComposition(uDispatchThreadId: FFX_MIN16_I2, iPrevIdx: FFX_MIN16_I2) -> FFX_MIN16_F
{
    var retVal: FFX_MIN16_F = ComputeAutoTC_02(uDispatchThreadId, iPrevIdx);

    // [branch]
    if (retVal > FFX_MIN16_F(0.01f))
    {
        retVal = ComputeAutoTC_01(uDispatchThreadId, iPrevIdx);
    }
    return retVal;
}

fn computeSolidEdge(curPos: FFX_MIN16_I2, prevPos: FFX_MIN16_I2) -> f32
{
    var lum: array<f32, 9>;
    var i: i32 = 0;
    for (var y: i32 = -1; y < 2; y++)
    {
        for (var x: i32 = -1; x < 2; x++)
        {
            let curCol: FfxFloat32x3  = LoadOpaqueOnly(curPos + FFX_MIN16_I2(x, y)).rgb;
            let prevCol: FfxFloat32x3 = LoadPrevPreAlpha(prevPos + FFX_MIN16_I2(x, y)).rgb;
            // WGSL: lum[i++] = ...; has no post-increment expression.
            lum[i] = length(curCol - prevCol);
            i++;
        }
    }

    //float gradX = abs(lum[3] - lum[4]) + abs(lum[5] - lum[4]);
    //float gradY = abs(lum[1] - lum[4]) + abs(lum[7] - lum[4]);

    //return sqrt(gradX * gradX + gradY * gradY);

    let gradX: f32 = abs(lum[3] - lum[4]) * abs(lum[5] - lum[4]);
    let gradY: f32 = abs(lum[1] - lum[4]) * abs(lum[7] - lum[4]);

    return sqrt(sqrt(gradX * gradY));
}

fn computeAlphaEdge(curPos: FFX_MIN16_I2, prevPos: FFX_MIN16_I2) -> f32
{
    var lum: array<f32, 9>;
    var i: i32 = 0;
    for (var y: i32 = -1; y < 2; y++)
    {
        for (var x: i32 = -1; x < 2; x++)
        {
            let curCol: FfxFloat32x3  = abs(LoadInputColor(FfxUInt32x2(curPos + FFX_MIN16_I2(x, y))).rgb - LoadOpaqueOnly(curPos + FFX_MIN16_I2(x, y)).rgb);
            let prevCol: FfxFloat32x3 = abs(LoadPrevPostAlpha(prevPos + FFX_MIN16_I2(x, y)).rgb - LoadPrevPreAlpha(prevPos + FFX_MIN16_I2(x, y)).rgb);
            // WGSL: lum[i++] = ...; has no post-increment expression.
            lum[i] = length(curCol - prevCol);
            i++;
        }
    }

    //float gradX = abs(lum[3] - lum[4]) + abs(lum[5] - lum[4]);
    //float gradY = abs(lum[1] - lum[4]) + abs(lum[7] - lum[4]);

    //return sqrt(gradX * gradX + gradY * gradY);

    let gradX: f32 = abs(lum[3] - lum[4]) * abs(lum[5] - lum[4]);
    let gradY: f32 = abs(lum[1] - lum[4]) * abs(lum[7] - lum[4]);

    return sqrt(sqrt(gradX * gradY));
}

fn ComputeAabbOverlap(uDispatchThreadId: FFX_MIN16_I2, iPrevIdx: FFX_MIN16_I2) -> FFX_MIN16_F
{
    var retVal: FFX_MIN16_F = FFX_MIN16_F(0.f);

    let fMotionVector: FfxFloat32x2 = LoadInputMotionVector(FfxUInt32x2(uDispatchThreadId));
    var colorPreAlpha: FfxFloat32x3 = LoadOpaqueOnly(uDispatchThreadId);
    var colorPostAlpha: FfxFloat32x3 = LoadInputColor(FfxUInt32x2(uDispatchThreadId));
    var colorPrevPreAlpha: FfxFloat32x3 = LoadPrevPreAlpha(iPrevIdx);
    var colorPrevPostAlpha: FfxFloat32x3 = LoadPrevPostAlpha(iPrevIdx);

#if USE_YCOCG    
    colorPreAlpha = RGBToYCoCg_f32x3(colorPreAlpha);
    colorPostAlpha = RGBToYCoCg_f32x3(colorPostAlpha);
    colorPrevPreAlpha = RGBToYCoCg_f32x3(colorPrevPreAlpha);
    colorPrevPostAlpha = RGBToYCoCg_f32x3(colorPrevPostAlpha);
#endif
    // WGSL: no unary plus (+1000.f).
    var minPrev: FfxFloat32x3 = FfxFloat32x3(FFX_MIN16_F3(FfxFloat32x3(1000.f, 1000.f, 1000.f)));
    var maxPrev: FfxFloat32x3 = FfxFloat32x3(FFX_MIN16_F3(FfxFloat32x3(-1000.f, -1000.f, -1000.f)));
    for (var y: i32 = -1; y < 2; y++)
    {
        for (var x: i32 = -1; x < 2; x++)
        {
            var W: FfxFloat32x3 = LoadPrevPostAlpha(iPrevIdx + FFX_MIN16_I2(x, y));

#if USE_YCOCG
            W = RGBToYCoCg_f32x3(W);
#endif
            minPrev = min(minPrev, W);
            maxPrev = max(maxPrev, W);
        }
    }
    // instead of computing the overlap: simply count how many samples are outside
    // set reactive based on that
    var count: FFX_MIN16_F = FFX_MIN16_F(0.f);
    for (var y: i32 = -1; y < 2; y++)
    {
        for (var x: i32 = -1; x < 2; x++)
        {
            var Y: FfxFloat32x3 = LoadInputColor(FfxUInt32x2(uDispatchThreadId + FFX_MIN16_I2(x, y)));

#if USE_YCOCG
            Y = RGBToYCoCg_f32x3(Y);
#endif
            count += select(FFX_MIN16_F(0.f), FFX_MIN16_F(1.f), ((Y.x < minPrev.x) || (Y.x > maxPrev.x)));
            count += select(FFX_MIN16_F(0.f), FFX_MIN16_F(1.f), ((Y.y < minPrev.y) || (Y.y > maxPrev.y)));
            count += select(FFX_MIN16_F(0.f), FFX_MIN16_F(1.f), ((Y.z < minPrev.z) || (Y.z > maxPrev.z)));
        }
    }
    retVal = count / FFX_MIN16_F(27.f);

    return retVal;
}


// This function computes the Reactive mask:
// We want pixels marked where the alpha portion of the frame changes a lot between neighbours
// Those pixels are expected to change quickly between frames, too. (e.g. small particles, reflections on curved surfaces...)
// As a result history would not be trustworthy.
// On the other hand we don't want pixels marked where pre-alpha has a large differnce, since those would profit from accumulation
// For mirrors we may assume the pre-alpha is pretty uniform color.
// 
// This works well generally, but also marks edge pixels
fn ComputeReactive(uDispatchThreadId: FFX_MIN16_I2, iPrevIdx: FFX_MIN16_I2) -> FFX_MIN16_F
{
    // we only get here if alpha has a significant contribution and has changed since last frame.
    var retVal: FFX_MIN16_F = FFX_MIN16_F(0.f);

    // mark pixels with huge variance in alpha as reactive
    let alphaEdge: FFX_MIN16_F = FFX_MIN16_F(computeAlphaEdge(uDispatchThreadId, iPrevIdx));
    let opaqueEdge: FFX_MIN16_F = FFX_MIN16_F(computeSolidEdge(uDispatchThreadId, iPrevIdx));
#if FFX_HALF
    retVal = ffxSaturate_f16(alphaEdge - opaqueEdge);
#else
    retVal = ffxSaturate_f32(alphaEdge - opaqueEdge);
#endif

    // the above also marks edge pixels due to jitter, so we need to cancel those out


    return retVal;
}
