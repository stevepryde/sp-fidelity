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
struct FfxDebugViewport
{
    offset: FfxInt32x2,
    size: FfxInt32x2,
}

// Macro to cull and draw debug viewport

fn getTransformedUv(iPxPos: FfxInt32x2, vp: FfxDebugViewport) -> FfxFloat32x2
{
    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos - vp.offset) + 0.5f) / FfxFloat32x2(vp.size);

    return fUv;
}

fn getMotionVectorColor(fMotionVector: FfxFloat32x2) -> FfxFloat32x3
{
    return FfxFloat32x3(0.5f + fMotionVector * FfxFloat32x2(RenderSize()) * 0.5f, 0.5f);
}

fn getUnusedIndicationColor(iPxPos: FfxInt32x2, vp: FfxDebugViewport) -> FfxFloat32x4
{
    var basePos: FfxInt32x2 = iPxPos - vp.offset;

    var ar: FfxFloat32 = FfxFloat32(vp.size.x) / FfxFloat32(vp.size.y);

    return FfxFloat32x4(FfxFloat32(basePos.x == FfxInt32(FfxFloat32(basePos.y) * ar)), 0, 0, 1);
}

fn drawDilatedMotionVectors(iPxPos: FfxInt32x2, vp: FfxDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fUv_HW: FfxFloat32x2 = ClampUv(fUv, RenderSize(), MaxRenderSize());

    var fMotionVector: FfxFloat32x2 = SampleDilatedMotionVector(fUv_HW);

    StoreUpscaledOutput(FfxUInt32x2(iPxPos), getMotionVectorColor(fMotionVector));
}

fn drawDisocclusionMask(iPxPos: FfxInt32x2, vp: FfxDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fUv_HW: FfxFloat32x2 = ClampUv(fUv, RenderSize(), MaxRenderSize());

    var fDisocclusionFactor: FfxFloat32 = ffxSaturate_f32(SampleDilatedReactiveMasks(fUv_HW)[DISOCCLUSION]);

    StoreUpscaledOutput(FfxUInt32x2(iPxPos), FfxFloat32x3(0, fDisocclusionFactor, 0));
}

fn drawDetailProtectionTakedown(iPxPos: FfxInt32x2, vp: FfxDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fUv_HW: FfxFloat32x2 = ClampUv(fUv, RenderSize(), MaxRenderSize());

    var fProtectionTakedown: FfxFloat32 = ffxSaturate_f32(SampleDilatedReactiveMasks(fUv_HW)[REACTIVE]);

    StoreUpscaledOutput(FfxUInt32x2(iPxPos), FfxFloat32x3(0, fProtectionTakedown, 0));
}

fn drawReactiveness(iPxPos: FfxInt32x2, vp: FfxDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fUv_HW: FfxFloat32x2 = ClampUv(fUv, RenderSize(), MaxRenderSize());

    var fShadingChange: FfxFloat32 = ffxSaturate_f32(SampleDilatedReactiveMasks(fUv_HW)[SHADING_CHANGE]);

    StoreUpscaledOutput(FfxUInt32x2(iPxPos), FfxFloat32x3(0, fShadingChange, 0));
}

fn drawProtectedAreas(iPxPos: FfxInt32x2, vp: FfxDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fProtection: FfxFloat32 = ffxSaturate_f32(SampleHistory(fUv).w - fLockThreshold);

    StoreUpscaledOutput(FfxUInt32x2(iPxPos), FfxFloat32x3(fProtection, 0, 0));
}

fn drawDilatedDepthInMeters(iPxPos: FfxInt32x2, vp: FfxDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fUv_HW: FfxFloat32x2 = ClampUv(fUv, RenderSize(), MaxRenderSize());

    var fDilatedDepth: FfxFloat32 = SampleDilatedDepth(fUv_HW);
    var fDepthInMeters: FfxFloat32 = GetViewSpaceDepthInMeters(fDilatedDepth);

    StoreUpscaledOutput(FfxUInt32x2(iPxPos), FfxFloat32x3(ffxSaturate_f32(fDepthInMeters / 25.0f), 0, 0));
}

fn pointIsInsideViewport(iPxPos: FfxInt32x2, vp: FfxDebugViewport) -> FfxBoolean
{
    var extent: FfxInt32x2 = vp.offset + vp.size;

    return (iPxPos.x >= vp.offset.x && iPxPos.x < extent.x) && (iPxPos.y >= vp.offset.y && iPxPos.y < extent.y);
}

fn DebugView(iPxPos: FfxInt32x2)
{
#define VIEWPORT_GRID_SIZE_X 3
#define VIEWPORT_GRID_SIZE_Y 3

    var fViewportScale: FfxFloat32x2 = FfxFloat32x2(1.0f / VIEWPORT_GRID_SIZE_X, 1.0f / VIEWPORT_GRID_SIZE_Y);
    var iViewportSize: FfxInt32x2 = FfxInt32x2(FfxFloat32x2(UpscaleSize()) * fViewportScale);

    // compute grid [y][x] for easier placement of viewports
    var vp: array<array<FfxDebugViewport, VIEWPORT_GRID_SIZE_X>, VIEWPORT_GRID_SIZE_Y> ;
    for (var y: FfxInt32 = 0; y < VIEWPORT_GRID_SIZE_Y; y++)
    {
        for (var x: FfxInt32 = 0; x < VIEWPORT_GRID_SIZE_X; x++)
        {
            vp[y][x].offset = iViewportSize * FfxInt32x2(x, y);
            vp[y][x].size   = iViewportSize;
        }
    }

    // top row
    if (pointIsInsideViewport(iPxPos, vp[0][0])) { drawDilatedMotionVectors(iPxPos, vp[0][0]); };
    if (pointIsInsideViewport(iPxPos, vp[0][1])) { drawProtectedAreas(iPxPos, vp[0][1]); };
    if (pointIsInsideViewport(iPxPos, vp[0][2])) { drawDilatedDepthInMeters(iPxPos, vp[0][2]); };

    // bottom row
    if (pointIsInsideViewport(iPxPos, vp[2][0])) { drawDisocclusionMask(iPxPos, vp[2][0]); };
    if (pointIsInsideViewport(iPxPos, vp[2][1])) { drawReactiveness(iPxPos, vp[2][1]); };
    if (pointIsInsideViewport(iPxPos, vp[2][2])) { drawDetailProtectionTakedown(iPxPos, vp[2][2]); };
}
