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

// WGSL port of ffx_opticalflow_compute_optical_flow_v5.h.
// The SDK reduces 64 threads using wave64 or two wave32 operations. The same
// unsigned sum/min is reduced across the fixed 64-thread workgroup here, so
// its result is independent of the implementation's subgroup width.
#ifndef FFX_OPTICALFLOW_COMPUTE_OPTICAL_FLOW_V5_H
#define FFX_OPTICALFLOW_COMPUTE_OPTICAL_FLOW_V5_H
#define CompareSize 8
#define BlockSizeY 8
#define BlockSizeX 8
#define ThreadCount 64
#define SearchRadiusX 8
#define SearchRadiusY 8
#define BlockCount 2
#define SearchBufferSizeX 6
#define SearchBufferSizeY 24
#define bankBreaker 1
var<workgroup> pixels: array<array<u32, 2>, 8>;
var<workgroup> searchBuffer: array<array<u32, 144>, 1>;
var<workgroup> sadMapBuffer: array<array<array<u32, 5>, 16>, 4>;
var<workgroup> ofReduction: array<u32, 64>;
fn BlockSad64(blockSadSum: u32, iLocalIndex: i32, iLaneToBlockId: i32, block: i32) -> u32 {
    ofReduction[iLocalIndex] = select(0u, blockSadSum, iLaneToBlockId == block);
    workgroupBarrier();
    for (var stride = 32i; stride > 0; stride /= 2) {
        if (iLocalIndex < stride) { ofReduction[iLocalIndex] += ofReduction[iLocalIndex + stride]; }
        workgroupBarrier();
    }
    let result = workgroupUniformLoad(&ofReduction[0]);
    workgroupBarrier();
    return result;
}
fn SadMapMinReduction256(iSearchId: vec2<i32>, iLocalIndex: i32) -> u32 {
    let min01 = min(sadMapBuffer[0][iSearchId.y][iSearchId.x], sadMapBuffer[1][iSearchId.y][iSearchId.x]);
    let min23 = min(sadMapBuffer[2][iSearchId.y][iSearchId.x], sadMapBuffer[3][iSearchId.y][iSearchId.x]);
    ofReduction[iLocalIndex] = min(min01, min23);
    workgroupBarrier();
    for (var stride = 32i; stride > 0; stride /= 2) {
        if (iLocalIndex < stride) { ofReduction[iLocalIndex] = min(ofReduction[iLocalIndex], ofReduction[iLocalIndex + stride]); }
        workgroupBarrier();
    }
    let result = workgroupUniformLoad(&ofReduction[0]);
    workgroupBarrier();
    return result;
}
fn LoadSearchBuffer(iLocalIndex: i32, iPxPosShifted: vec2<i32>) {
    let baseX = iPxPosShifted.x - SearchRadiusX;
    let baseY = iPxPosShifted.y - SearchRadiusY;
    for (var id = iLocalIndex; id < SearchBufferSizeX * SearchBufferSizeY; id += ThreadCount) {
        let idx = id % SearchBufferSizeX;
        let idy = id / SearchBufferSizeX;
        let x = baseX + idx * 4;
        let y = baseY + idy;
        searchBuffer[0][id] = LoadSecondImagePackedLuma(vec2<i32>(x, y));
    }
    workgroupBarrier();
}
fn CalculateQSads2(iSearchId: vec2<i32>) -> vec4<u32> {
    var sad = vec4<u32>(0);
    for (var dy = 0i; dy < CompareSize; dy++) {
        let rowOffset = (iSearchId.y + dy) * SearchBufferSizeX;
        let a0 = searchBuffer[0][rowOffset + iSearchId.x];
        let a1 = searchBuffer[0][rowOffset + iSearchId.x + 1];
        let a2 = searchBuffer[0][rowOffset + iSearchId.x + 2];
        sad += QSad(a0, a1, pixels[dy][0]);
        sad += QSad(a1, a2, pixels[dy][1]);
    }
    return sad;
}
fn abs_2(val: vec2<i32>) -> vec2<u32> {
    let mask = val >> vec2<u32>(31);
    return vec2<u32>((val + mask) ^ mask);
}
fn EncodeSearchCoord(coord: vec2<i32>) -> u32 {
#if FFX_OPTICALFLOW_FIX_TOP_LEFT_BIAS == 1
    let absCoord = abs_2(coord - vec2<i32>(8));
    return (absCoord.y << 12u) | (absCoord.x << 8u) | u32(coord.y << 4u) | u32(coord.x);
#else
    return u32(coord.y << 8u) | u32(coord.x);
#endif
}
fn DecodeSearchCoord(bits: u32) -> vec2<i32> {
#if FFX_OPTICALFLOW_FIX_TOP_LEFT_BIAS == 1
    return vec2<i32>(i32(bits & 0xfu) - SearchRadiusX, i32((bits >> 4u) & 0xfu) - SearchRadiusY);
#else
    return vec2<i32>(i32(bits & 0xffu) - SearchRadiusX, i32((bits >> 8u) & 0xffu) - SearchRadiusY);
#endif
}
fn PrepareSadMap(iSearchId: vec2<i32>, qsad: vec4<u32>) {
    sadMapBuffer[0][iSearchId.y][iSearchId.x] = (qsad.x << 16u) | EncodeSearchCoord(vec2<i32>(iSearchId.x * 4 + 0, iSearchId.y));
    sadMapBuffer[1][iSearchId.y][iSearchId.x] = (qsad.y << 16u) | EncodeSearchCoord(vec2<i32>(iSearchId.x * 4 + 1, iSearchId.y));
    sadMapBuffer[2][iSearchId.y][iSearchId.x] = (qsad.z << 16u) | EncodeSearchCoord(vec2<i32>(iSearchId.x * 4 + 2, iSearchId.y));
    sadMapBuffer[3][iSearchId.y][iSearchId.x] = (qsad.w << 16u) | EncodeSearchCoord(vec2<i32>(iSearchId.x * 4 + 3, iSearchId.y));
    workgroupBarrier();
}
fn ABfe(src: u32, off: u32, bits: u32) -> u32 { let mask = (1u << bits) - 1u; return (src >> off) & mask; }
fn ABfi(src: u32, ins: u32, mask: u32) -> u32 { return (ins & mask) | (src & (~mask)); }
fn ABfiM(src: u32, ins: u32, bits: u32) -> u32 { let mask = (1u << bits) - 1u; return (ins & mask) | (src & (~mask)); }
// WGSL returns the SDK's three out parameters as a struct.
struct OpticalFlowThreadMapping { iSearchId: vec2<i32>, iPxPos: vec2<i32>, iLaneToBlockId: i32, }
fn MapThreads(iGroupId: vec2<i32>, iLocalIndex: i32) -> OpticalFlowThreadMapping {
    let search = vec2<i32>(i32(ABfe(u32(iLocalIndex), 0u, 2u)), i32(ABfe(u32(iLocalIndex), 2u, 4u)));
    let block = i32(ABfe(u32(iLocalIndex), 1u, 1u) | (ABfe(u32(iLocalIndex), 5u, 1u) << 1u));
    return OpticalFlowThreadMapping(search, (iGroupId << vec2<u32>(4)) + search * vec2<i32>(4, 1), block);
}
fn ComputeOpticalFlowAdvanced(iGlobalId: vec2<i32>, iLocalId: vec2<i32>, iGroupId: vec2<i32>, iLocalIndex: i32) {
    let mapping = MapThreads(iGroupId, iLocalIndex);
    let iSearchId = mapping.iSearchId;
    let iPxPos = mapping.iPxPos;
    let iLaneToBlockId = mapping.iLaneToBlockId;
    let currentOFPos = iPxPos >> vec2<u32>(3);
    if (IsSceneChanged()) {
        if ((iSearchId.y & 0x7) == 0 && (iSearchId.x & 0x1) == 0) {
            StoreOpticalFlow(currentOFPos, vec2<i32>(0));
        }
        return;
    }
    let bUsePredictionFromPreviousLevel = OpticalFlowPyramidLevel() != OpticalFlowPyramidLevelCount() - 1u;
    let packedLuma_4blocks = LoadFirstImagePackedLuma(iPxPos);
#if FFX_LOCAL_SEARCH_FALLBACK == 1
    let prevPackedLuma_4blocks = LoadSecondImagePackedLuma(iPxPos);
    let sad_4blocks = Sad(packedLuma_4blocks, prevPackedLuma_4blocks);
#endif
    let ofGroupOffset = iGroupId << vec2<u32>(1);
    let pixelGroupOffset = iGroupId << vec2<u32>(4);
    for (var blockY = 0i; blockY < BlockCount; blockY++) {
        for (var blockX = 0i; blockX < BlockCount; blockX++) {
            let blockId = vec2<i32>(blockX, blockY);
            var currentVector = LoadRwOpticalFlow(ofGroupOffset + blockId);
            if (!bUsePredictionFromPreviousLevel) { currentVector = vec2<i32>(0); }
            if (iLaneToBlockId == blockId.y * 2 + blockId.x) {
                pixels[iSearchId.y & 0x7][iSearchId.x & 0x1] = packedLuma_4blocks;
            }
            LoadSearchBuffer(iLocalIndex, pixelGroupOffset + blockId * 8 + currentVector);
            let qsad = CalculateQSads2(iSearchId);
            PrepareSadMap(iSearchId, qsad);
            let minSad = SadMapMinReduction256(iSearchId, iLocalIndex);
            let minSadCoord = DecodeSearchCoord(minSad);
            var newVector = currentVector + minSadCoord;
#if FFX_LOCAL_SEARCH_FALLBACK == 1
            let blockSadSum = BlockSad64(sad_4blocks, iLocalIndex, iLaneToBlockId, blockId.x + blockId.y * 2);
            if (OpticalFlowPyramidLevel() == 0u && blockSadSum <= (minSad >> 16u)) { newVector = vec2<i32>(0); }
#endif
            // HLSL writes the same result from every lane; one writer avoids a
            // WGSL data race without changing the resulting texture value.
            if (iLocalIndex == 0) { StoreOpticalFlow(ofGroupOffset + blockId, newVector); }
        }
    }
}
#endif
