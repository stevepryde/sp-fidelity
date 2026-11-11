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

// WGSL port of ffx_frameinterpolation_compute_game_vector_field_inpainting_pyramid.h.

#ifndef FFX_FRAMEINTERPOLATION_COMPUTE_GAME_VECTOR_FIELD_INPAINTING_PYRAMID_H
#define FFX_FRAMEINTERPOLATION_COMPUTE_GAME_VECTOR_FIELD_INPAINTING_PYRAMID_H

#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"
//--------------------------------------------------------------------------------------
// Buffer definitions - global atomic counter
//--------------------------------------------------------------------------------------

var<workgroup> spdCounter: FfxUInt32;
var<workgroup> spdIntermediateR: array<array<FfxFloat32, 16>, 16>;
var<workgroup> spdIntermediateG: array<array<FfxFloat32, 16>, 16>;
var<workgroup> spdIntermediateB: array<array<FfxFloat32, 16>, 16>;
var<workgroup> spdIntermediateA: array<array<FfxFloat32, 16>, 16>;

fn SpdLoadSourceImage(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    var gameMv: VectorFieldEntry;
    var packedGameFieldMv: FfxUInt32x2 = LoadGameFieldMv(tex);
    UnpackVectorFieldEntries(packedGameFieldMv, &gameMv);

    return FfxFloat32x4(gameMv.fMotionVector, gameMv.uHighPriorityFactor, gameMv.uLowPriorityFactor) * FfxFloat32(DisplaySize().x > 0);
}

fn SpdLoad(tex: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    return RWLoadInpaintingPyramid(tex, 5);
}

fn SpdStore(pix: FfxInt32x2, outValue: FfxFloat32x4, index: FfxUInt32, slice: FfxUInt32)
{
    StoreInpaintingPyramid(pix, outValue, index);
}

fn SpdIncreaseAtomicCounter(slice: FfxUInt32)
{
    var counter: FfxUInt32;
    AtomicIncreaseCounter(COUNTER_SPD, &counter);
    spdCounter = counter;
}

fn SpdGetAtomicCounter() -> FfxUInt32
{
    return spdCounter;
}
fn SpdResetAtomicCounter(slice: FfxUInt32)
{
    StoreCounter(COUNTER_SPD, 0);
}

fn SpdLoadIntermediate(x: FfxUInt32, y: FfxUInt32) -> FfxFloat32x4
{
    return FfxFloat32x4(
        spdIntermediateR[x][y],
        spdIntermediateG[x][y],
        spdIntermediateB[x][y],
        spdIntermediateA[x][y]);
}

fn SpdStoreIntermediate(x: FfxUInt32, y: FfxUInt32, value: FfxFloat32x4)
{
    spdIntermediateR[x][y] = value.x;
    spdIntermediateG[x][y] = value.y;
    spdIntermediateB[x][y] = value.z;
    spdIntermediateA[x][y] = value.w;
}

fn SpdReduce4(v0: FfxFloat32x4, v1: FfxFloat32x4, v2: FfxFloat32x4, v3: FfxFloat32x4) -> FfxFloat32x4
{
    var vec: FfxFloat32x4 = FfxFloat32x4(0,0,0,0);

    var fWeightSum: FfxFloat32 = 0.0f;
    { let weight = FfxFloat32(v0.z > 0.0); vec += v0 * weight; fWeightSum += weight; }
    { let weight = FfxFloat32(v1.z > 0.0); vec += v1 * weight; fWeightSum += weight; }
    { let weight = FfxFloat32(v2.z > 0.0); vec += v2 * weight; fWeightSum += weight; }
    { let weight = FfxFloat32(v3.z > 0.0); vec += v3 * weight; fWeightSum += weight; }
    vec /= select(1.0, fWeightSum, fWeightSum > FFX_FRAMEINTERPOLATION_EPSILON);

    return vec;
}

#include "spd/ffx_spd.wgsl"

fn computeFrameinterpolationGameVectorFieldInpaintingPyramid(iGroupId: FfxInt32x3, iLocalIndex: FfxInt32)
{
    SpdDownsample_u32x2_u32_u32_u32_u32_u32x2(
        FfxUInt32x2(iGroupId.xy),
        FfxUInt32(iLocalIndex),
        FfxUInt32(NumMips()),
        FfxUInt32(NumWorkGroups()),
        FfxUInt32(iGroupId.z),
        FfxUInt32x2(WorkGroupOffset()));
}

#endif // FFX_FRAMEINTERPOLATION_COMPUTE_GAME_VECTOR_FIELD_INPAINTING_PYRAMID_H
