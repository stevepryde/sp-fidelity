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

// WGSL port of ffx_frameinterpolation_debug_view.h.

#ifndef FFX_FRAMEINTERPOLATION_DEBUG_VIEW_H
#define FFX_FRAMEINTERPOLATION_DEBUG_VIEW_H

struct FfxFrameInterpolationDebugViewport
{
    offset: FfxInt32x2,
    size: FfxInt32x2,
}

fn getTransformedUv(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport) -> FfxFloat32x2
{
    var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos - vp.offset) + 0.5f) / FfxFloat32x2(vp.size);

    return fUv;
}

fn getMotionVectorColor(fMotionVector: FfxFloat32x2) -> FfxFloat32x4
{
    return FfxFloat32x4(0.5f + fMotionVector * FfxFloat32x2(DisplaySize()) * 0.1f, 0.5f, 1.0f);
}

fn getUnusedIndicationColor(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport) -> FfxFloat32x4
{
    var basePos: FfxInt32x2 = iPxPos - vp.offset;

    var ar: FfxFloat32 = FfxFloat32(vp.size.x) / FfxFloat32(vp.size.y);

    return FfxFloat32x4(FfxFloat32(basePos.x == FfxInt32(FfxFloat32(basePos.y) * ar)), 0, 0, 1);
}

fn drawGameMotionVectorFieldVectors(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var gameMv: VectorFieldEntry;
    LoadInpaintedGameFieldMv(fUv, &gameMv);

    StoreFrameinterpolationOutput(iPxPos, getMotionVectorColor(gameMv.fMotionVector));
}

fn drawGameMotionVectorFieldDepthPriority(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var gameMv: VectorFieldEntry;
    LoadInpaintedGameFieldMv(fUv, &gameMv);

    StoreFrameinterpolationOutput(iPxPos, FfxFloat32x4(0, gameMv.uHighPriorityFactor, 0, 1));
}

fn drawOpticalFlowMotionVectorField(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var ofMv: VectorFieldEntry;
    SampleOpticalFlowMotionVectorField(fUv, &ofMv);

    StoreFrameinterpolationOutput(iPxPos, getMotionVectorColor(ofMv.fMotionVector));
}

fn drawDisocclusionMask(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fLrUv: FfxFloat32x2 = fUv * (FfxFloat32x2(RenderSize()) / FfxFloat32x2(GetMaxRenderSize()));

    var fDisocclusionFactor: FfxFloat32x2 = ffxSaturate_f32x2(SampleDisocclusionMask(fLrUv).xy);

    StoreFrameinterpolationOutput(iPxPos, FfxFloat32x4(fDisocclusionFactor, 0, 1));
}

fn getDistortionField(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport) -> FfxFloat32x4
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fDistortionFieldUv: FfxFloat32x2 = abs(SampleDistortionField(fUv).xy);

    return FfxFloat32x4(fDistortionFieldUv * 10.0f, 0.0f, 1.0f);
}

fn drawPresentBackbuffer(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fPresentColor: FfxFloat32x4 = getDistortionField(iPxPos, vp);

    if (GetHUDLessAttachedFactor() == 1)
    {
        fPresentColor = SamplePresentBackbuffer(fUv);
    }

    StoreFrameinterpolationOutput(iPxPos, fPresentColor);
}

fn drawCurrentInterpolationSource(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport)
{
    var fUv: FfxFloat32x2 = getTransformedUv(iPxPos, vp);

    var fCurrentBackBuffer: FfxFloat32x4 = FfxFloat32x4(SampleCurrentBackbuffer(fUv), 1.0f);

    StoreFrameinterpolationOutput(iPxPos, fCurrentBackBuffer);
}

fn pointIsInsideViewport(iPxPos: FfxInt32x2, vp: FfxFrameInterpolationDebugViewport) -> FfxBoolean
{
    var extent: FfxInt32x2 = vp.offset + vp.size;

    return (iPxPos.x >= vp.offset.x && iPxPos.x < extent.x) && (iPxPos.y >= vp.offset.y && iPxPos.y < extent.y);
}

fn computeDebugView(iPxPos: FfxInt32x2)
{
#define VIEWPORT_GRID_SIZE_X 3
#define VIEWPORT_GRID_SIZE_Y 3

    var fViewportScale: FfxFloat32x2 = FfxFloat32x2(1.0f / VIEWPORT_GRID_SIZE_X, 1.0f / VIEWPORT_GRID_SIZE_Y);
    var iViewportSize: FfxInt32x2  = FfxInt32x2(FfxFloat32x2(DisplaySize()) * fViewportScale);

    // compute grid [y][x] for easier placement of viewports
    var vp: array<array<FfxFrameInterpolationDebugViewport, VIEWPORT_GRID_SIZE_X>, VIEWPORT_GRID_SIZE_Y>;
    for (var y: FfxInt32 = 0; y < VIEWPORT_GRID_SIZE_Y; y++)
    {
        for (var x: FfxInt32 = 0; x < VIEWPORT_GRID_SIZE_X; x++)
        {
            vp[y][x].offset = iViewportSize * FfxInt32x2(x, y);
            vp[y][x].size   = iViewportSize;
        }
    }

    // top row
    if (pointIsInsideViewport(iPxPos, vp[0][0])) { drawGameMotionVectorFieldVectors(iPxPos, vp[0][0]); }
    if (pointIsInsideViewport(iPxPos, vp[0][1])) { drawGameMotionVectorFieldDepthPriority(iPxPos, vp[0][1]); }
    if (pointIsInsideViewport(iPxPos, vp[0][2])) { drawOpticalFlowMotionVectorField(iPxPos, vp[0][2]); }

    // bottom row
    if (pointIsInsideViewport(iPxPos, vp[2][0])) { drawDisocclusionMask(iPxPos, vp[2][0]); }
    if (pointIsInsideViewport(iPxPos, vp[2][1])) { drawCurrentInterpolationSource(iPxPos, vp[2][1]); }
    if (pointIsInsideViewport(iPxPos, vp[2][2])) { drawPresentBackbuffer(iPxPos, vp[2][2]); }
}

#endif  // FFX_FRAMEINTERPOLATION_DEBUG_VIEW_H
