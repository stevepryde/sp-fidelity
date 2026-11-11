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

// WGSL port of ffx_opticalflow_callbacks_hlsl.h.
// HLSL t/u/b register numbers use the shared WGSL binding offsets. Texture
// reads outside a resource return zero; stores and atomics outside are ignored.
// SCD output uses a storage buffer because WGSL texture atomics have no result.
// SCD histogram/temp use the same coherent buffer adapter: Metal can omit
// native-texture hazard tracking when bounded atomic coordinates eliminate
// the compiler workaround's dead ordinary store. Logical R32Uint texels stay
// packed one word per texel; every SDK access is in row zero.
#ifndef FFX_OPTICALFLOW_CALLBACKS_HLSL_H
#define FFX_OPTICALFLOW_CALLBACKS_HLSL_H
#include "ffx_core.wgsl"
#include "opticalflow/ffx_opticalflow_resources.wgsl"
#define FFX_OPTICALFLOW_USE_MSAD4_INSTRUCTION 0
#define FFX_OPTICALFLOW_FIX_TOP_LEFT_BIAS 1
#define FFX_OPTICALFLOW_USE_HEURISTICS 1
#define FFX_OPTICALFLOW_BLOCK_SIZE 8
#define FFX_LOCAL_SEARCH_FALLBACK 1
#include "opticalflow/ffx_opticalflow_common.wgsl"
#define SCD_OUTPUT_SCENE_CHANGE_SLOT 0
#define SCD_OUTPUT_HISTORY_BITS_SLOT 1
#define SCD_OUTPUT_COMPLETED_WORKGROUPS_SLOT 2
#if defined(FFX_OPTICALFLOW_BIND_CB_COMMON)
struct cbOF_t {
    iInputLumaResolution: vec2<i32>,
    uOpticalFlowPyramidLevel: u32,
    uOpticalFlowPyramidLevelCount: u32,
    iFrameIndex: u32,
    backbufferTransferFunction: u32,
    minMaxLuminance: vec2<f32>,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FFX_OPTICALFLOW_BIND_CB_COMMON) var<uniform> cbOF: cbOF_t;
#define FFX_OPTICALFLOW_CONSTANT_BUFFER_1_SIZE 8
fn DisplaySize() -> vec2<i32> { return cbOF.iInputLumaResolution; }
fn FrameIndex() -> u32 { return cbOF.iFrameIndex; }
fn BackbufferTransferFunction() -> u32 { return cbOF.backbufferTransferFunction; }
fn MinMaxLuminance() -> vec2<f32> { return cbOF.minMaxLuminance; }
fn OpticalFlowPyramidLevel() -> u32 { return cbOF.uOpticalFlowPyramidLevel; }
fn OpticalFlowPyramidLevelCount() -> u32 { return cbOF.uOpticalFlowPyramidLevelCount; }
fn OpticalFlowHistogramMaxVelocity() -> vec2<i32> {
    let searchRadius = 8;
    let scale = 1i << (OpticalFlowPyramidLevelCount() - 1u - OpticalFlowPyramidLevel());
    return vec2<i32>(searchRadius * scale);
}
#endif
fn CrossedSceneChangeThreshold(sceneChangeValue: f32) -> bool { return sceneChangeValue > 0.45; }
#if defined(FFX_OPTICALFLOW_BIND_CB_SPD)
struct cbOF_SPD_t {
    mips: u32,
    numWorkGroups: u32,
    workGroupOffset: vec2<u32>,
    numWorkGroupOpticalFlowInputPyramid: u32,
    pad0_: u32,
    pad1_: u32,
    pad2_: u32,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FFX_OPTICALFLOW_BIND_CB_SPD) var<uniform> cbOF_SPD: cbOF_SPD_t;
fn NumWorkGroups() -> u32 { return cbOF_SPD.numWorkGroupOpticalFlowInputPyramid; }
#endif
#define FFX_OPTICALFLOW_CONSTANT_BUFFER_2_SIZE 8
#if defined(FFX_OPTICALFLOW_BIND_SRV_INPUT_COLOR)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_INPUT_COLOR) var r_input_color: texture_2d<f32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_INPUT_MOTION_VECTORS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_INPUT_MOTION_VECTORS) var r_input_motion_vectors: texture_2d<f32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_INPUT)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_INPUT) var r_optical_flow_input: texture_2d<u32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_PREVIOUS_INPUT)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_PREVIOUS_INPUT) var r_optical_flow_previous_input: texture_2d<u32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW) var r_optical_flow: texture_2d<i32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_PREVIOUS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_PREVIOUS) var r_optical_flow_previous: texture_2d<i32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_ADDITIONAL_INFO)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_ADDITIONAL_INFO) var r_optical_flow_additional_info: texture_2d<u32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_ADDITIONAL_INFO_PREVIOUS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_ADDITIONAL_INFO_PREVIOUS) var r_optical_flow_additional_info_previous: texture_2d<u32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_HISTOGRAM)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_HISTOGRAM) var r_optical_flow_histogram: texture_2d<u32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_GLOBAL_MOTION_SEARCH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_GLOBAL_MOTION_SEARCH) var r_optical_flow_global_motion_search: texture_2d<u32>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT) var rw_optical_flow_input: texture_storage_2d<r8uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_1)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_1) var rw_optical_flow_input_level_1: texture_storage_2d<r8uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_2)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_2) var rw_optical_flow_input_level_2: texture_storage_2d<r8uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_3)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_3) var rw_optical_flow_input_level_3: texture_storage_2d<r8uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_4)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_4) var rw_optical_flow_input_level_4: texture_storage_2d<r8uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_5)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_5) var rw_optical_flow_input_level_5: texture_storage_2d<r8uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_6)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_6) var rw_optical_flow_input_level_6: texture_storage_2d<r8uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW)
#if defined(FFX_OPTICALFLOW_BUFFER_OPTICAL_FLOW)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW) var<storage, read_write> rw_optical_flow: array<u32>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW) var rw_optical_flow: texture_storage_2d<rg16sint, write>;
#endif
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_NEXT_LEVEL)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_NEXT_LEVEL) var rw_optical_flow_next_level: texture_storage_2d<rg16sint, write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_ADDITIONAL_INFO)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_ADDITIONAL_INFO) var rw_optical_flow_additional_info: texture_storage_2d<rg32uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_ADDITIONAL_INFO_NEXT_LEVEL)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_ADDITIONAL_INFO_NEXT_LEVEL) var rw_optical_flow_additional_info_next_level: texture_storage_2d<rg32uint, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_HISTOGRAM)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_HISTOGRAM) var rw_optical_flow_histogram: texture_storage_2d<r32uint, atomic>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_GLOBAL_MOTION_SEARCH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_GLOBAL_MOTION_SEARCH) var<storage, read_write> rw_optical_flow_global_motion_search: array<atomic<u32>>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_HISTOGRAM)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_HISTOGRAM) var<storage, read_write> rw_optical_flow_scd_histogram: array<atomic<u32>>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_PREVIOUS_HISTOGRAM)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_PREVIOUS_HISTOGRAM) var rw_optical_flow_scd_previous_histogram: texture_storage_2d<r32float, read_write>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_TEMP)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_TEMP) var<storage, read_write> rw_optical_flow_scd_temp: array<atomic<u32>>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_OUTPUT)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_OUTPUT) var<storage, read_write> rw_optical_flow_scd_output: array<atomic<u32>>;
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_INPUT_COLOR)
fn LoadInputColor(pos: vec2<i32>) -> vec4<f32> {
    if (ffxWgslOutside(pos, textureDimensions(r_input_color))) { return vec4<f32>(0); }
    return textureLoad(r_input_color, pos, 0);
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_INPUT)
fn LoadOpticalFlowInput(pos: vec2<i32>) -> u32 {
    if (ffxWgslOutside(pos, textureDimensions(r_optical_flow_input))) { return u32(0); }
    return textureLoad(r_optical_flow_input, pos, 0).x;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT)
fn LoadRwOpticalFlowInput(pos: vec2<i32>) -> u32 {
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input))) { return u32(0); }
    return textureLoad(rw_optical_flow_input, pos).x;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_PREVIOUS_INPUT)
fn LoadOpticalFlowPreviousInput(pos: vec2<i32>) -> u32 {
    if (ffxWgslOutside(pos, textureDimensions(r_optical_flow_previous_input))) { return u32(0); }
    return textureLoad(r_optical_flow_previous_input, pos, 0).x;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW)
fn LoadOpticalFlow(pos: vec2<i32>) -> vec2<i32> {
    if (ffxWgslOutside(pos, textureDimensions(r_optical_flow))) { return vec2<i32>(0); }
    return textureLoad(r_optical_flow, pos, 0).xy;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW) && defined(FFX_OPTICALFLOW_BUFFER_OPTICAL_FLOW)
// Metal cannot read/write rg16sint storage textures. The backend transfers
// packed signed16 XY texels to/from this buffer around the search dispatch.
// The SDK allocates ceil(ceil(DisplaySize / 8) / 2^level) vector texels.
fn OpticalFlowVectorTextureSize() -> vec2<u32> {
    let blockSize = 8u << OpticalFlowPyramidLevel();
    return (vec2<u32>(DisplaySize()) + vec2<u32>(blockSize - 1u)) / blockSize;
}
fn LoadRwOpticalFlow(pos: vec2<i32>) -> vec2<i32> {
    let size = OpticalFlowVectorTextureSize();
    if (ffxWgslOutside(pos, size)) { return vec2<i32>(0); }
    let word = rw_optical_flow[u32(pos.y) * size.x + u32(pos.x)];
    return vec2<i32>(bitcast<i32>(word << 16u) >> 16u, bitcast<i32>(word) >> 16u);
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_PREVIOUS)
fn LoadPreviousOpticalFlow(pos: vec2<i32>) -> vec2<i32> {
    if (ffxWgslOutside(pos, textureDimensions(r_optical_flow_previous))) { return vec2<i32>(0); }
    return textureLoad(r_optical_flow_previous, pos, 0).xy;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_ADDITIONAL_INFO)
fn LoadOpticalFlowAdditionalInfo(pos: vec2<i32>) -> vec2<u32> {
    if (ffxWgslOutside(pos, textureDimensions(r_optical_flow_additional_info))) { return vec2<u32>(0); }
    return textureLoad(r_optical_flow_additional_info, pos, 0).xy;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_ADDITIONAL_INFO)
fn LoadRwOpticalFlowAdditionalInfo(pos: vec2<i32>) -> vec2<u32> {
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow_additional_info))) { return vec2<u32>(0); }
    return textureLoad(rw_optical_flow_additional_info, pos).xy;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_ADDITIONAL_INFO_PREVIOUS)
fn LoadPreviousOpticalFlowAdditionalInfo(pos: vec2<i32>) -> vec2<u32> {
    if (ffxWgslOutside(pos, textureDimensions(r_optical_flow_additional_info_previous))) { return vec2<u32>(0); }
    return textureLoad(r_optical_flow_additional_info_previous, pos, 0).xy;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_HISTOGRAM)
fn LoadOpticalFlowHistogram(pos: vec2<i32>) -> u32 {
    if (ffxWgslOutside(pos, textureDimensions(r_optical_flow_histogram))) { return u32(0); }
    return textureLoad(r_optical_flow_histogram, pos, 0).x;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT)
fn StoreOpticalFlowInput(pos: vec2<i32>, value: u32) {
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input))) { return; }
    textureStore(rw_optical_flow_input, pos, vec4<u32>(value));
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW)
fn StoreOpticalFlow(pos: vec2<i32>, value: vec2<i32>) {
#if defined(FFX_OPTICALFLOW_BUFFER_OPTICAL_FLOW)
    let size = OpticalFlowVectorTextureSize();
    if (ffxWgslOutside(pos, size)) { return; }
    rw_optical_flow[u32(pos.y) * size.x + u32(pos.x)] = (u32(value.x) & 0xffffu) | (u32(value.y) << 16u);
#else
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow))) { return; }
    textureStore(rw_optical_flow, pos, vec4<i32>(value, 0, 0));
#endif
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_NEXT_LEVEL)
fn StoreOpticalFlowNextLevel(pos: vec2<i32>, value: vec2<i32>) {
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow_next_level))) { return; }
    textureStore(rw_optical_flow_next_level, pos, vec4<i32>(value, 0, 0));
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_ADDITIONAL_INFO)
fn StoreOpticalFlowAdditionalInfo(pos: vec2<i32>, value: vec2<u32>) {
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow_additional_info))) { return; }
    textureStore(rw_optical_flow_additional_info, pos, vec4<u32>(value, 0, 0));
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_ADDITIONAL_INFO_NEXT_LEVEL)
fn StoreOpticalFlowNextLevelAdditionalInfo(pos: vec2<i32>, value: vec2<u32>) {
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow_additional_info_next_level))) { return; }
    textureStore(rw_optical_flow_additional_info_next_level, pos, vec4<u32>(value, 0, 0));
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_HISTOGRAM)
fn LoadRwSCDHistogram(i: i32) -> u32 {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_histogram)) { return u32(0); }
    return atomicLoad(&rw_optical_flow_scd_histogram[i]);
}
fn StoreSCDHistogram(i: i32, value: u32) {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_histogram)) { return; }
    atomicStore(&rw_optical_flow_scd_histogram[i], value);
}
fn AtomicIncrementSCDHistogram(i: i32, value: u32) {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_histogram)) { return; }
    atomicAdd(&rw_optical_flow_scd_histogram[i], value);
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_PREVIOUS_HISTOGRAM)
fn LoadRwSCDPreviousHistogram(i: i32) -> f32 {
    if (ffxWgslOutside(vec2<i32>(i, 0), textureDimensions(rw_optical_flow_scd_previous_histogram))) { return f32(0); }
    return textureLoad(rw_optical_flow_scd_previous_histogram, vec2<i32>(i, 0)).x;
}
fn StoreSCDPreviousHistogram(i: i32, value: f32) {
    if (ffxWgslOutside(vec2<i32>(i, 0), textureDimensions(rw_optical_flow_scd_previous_histogram))) { return; }
    textureStore(rw_optical_flow_scd_previous_histogram, vec2<i32>(i, 0), vec4<f32>(value));
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_TEMP)
fn LoadRwSCDTemp(i: i32) -> u32 {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_temp)) { return u32(0); }
    return atomicLoad(&rw_optical_flow_scd_temp[i]);
}
fn AtomicIncrementSCDTemp(i: i32, value: u32) {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_temp)) { return; }
    atomicAdd(&rw_optical_flow_scd_temp[i], value);
}
fn ResetSCDTemp() {
    if (arrayLength(&rw_optical_flow_scd_temp) > 0u) { atomicStore(&rw_optical_flow_scd_temp[0], 0u); }
    if (arrayLength(&rw_optical_flow_scd_temp) > 1u) { atomicStore(&rw_optical_flow_scd_temp[1], 0u); }
    if (arrayLength(&rw_optical_flow_scd_temp) > 2u) { atomicStore(&rw_optical_flow_scd_temp[2], 0u); }
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_OUTPUT)
fn LoadRwSCDOutput(i: i32) -> u32 {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_output)) { return u32(0); }
    return atomicLoad(&rw_optical_flow_scd_output[i]);
}
fn StoreSCDOutput(i: i32, value: u32) {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_output)) { return; }
    atomicStore(&rw_optical_flow_scd_output[i], value);
}
fn AtomicIncrementSCDOutput(i: i32, value: u32) -> u32 {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_scd_output)) { return 0u; }
    return atomicAdd(&rw_optical_flow_scd_output[i], value);
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_SCD_OUTPUT)
fn GetSceneChangeValue() -> f32 {
    if (FrameIndex() <= 5u) { return 1.0; }
    return bitcast<f32>(LoadRwSCDOutput(SCD_OUTPUT_SCENE_CHANGE_SLOT));
}
var<workgroup> ofSceneChanged: u32;
fn InitOpticalFlowSceneChange(localIndex: u32) {
    if (localIndex == 0u) {
        ofSceneChanged = u32(FrameIndex() <= 5u || (LoadRwSCDOutput(SCD_OUTPUT_HISTORY_BITS_SLOT) & 0xfu) != 0u);
    }
}
fn IsSceneChanged() -> bool {
    // The frame and SCD history are common to the entire dispatched workgroup.
    return workgroupUniformLoad(&ofSceneChanged) != 0u;
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_INPUT)
fn LoadFirstImagePackedLuma(pos: vec2<i32>) -> u32 {
    let width = DisplaySize().x >> OpticalFlowPyramidLevel();
    let height = DisplaySize().y >> OpticalFlowPyramidLevel();
    // Preserve the SDK ffxClamp macro order, including width < 4 on
    // coarse pyramid levels. WGSL clamp has undefined behavior if min > max.
    let adjustedPos = vec2<i32>(max(0, min(width - 4, pos.x)), max(0, min(height - 1, pos.y)));
    let luma0 = LoadOpticalFlowInput(adjustedPos + vec2<i32>(0, 0));
    let luma1 = LoadOpticalFlowInput(adjustedPos + vec2<i32>(1, 0));
    let luma2 = LoadOpticalFlowInput(adjustedPos + vec2<i32>(2, 0));
    let luma3 = LoadOpticalFlowInput(adjustedPos + vec2<i32>(3, 0));
    return GetPackedLuma(width, pos.x, luma0, luma1, luma2, luma3);
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_PREVIOUS_INPUT)
fn LoadSecondImagePackedLuma(pos: vec2<i32>) -> u32 {
    let width = DisplaySize().x >> OpticalFlowPyramidLevel();
    let height = DisplaySize().y >> OpticalFlowPyramidLevel();
    // Preserve the SDK ffxClamp macro order, including width < 4 on
    // coarse pyramid levels. WGSL clamp has undefined behavior if min > max.
    let adjustedPos = vec2<i32>(max(0, min(width - 4, pos.x)), max(0, min(height - 1, pos.y)));
    let luma0 = LoadOpticalFlowPreviousInput(adjustedPos + vec2<i32>(0, 0));
    let luma1 = LoadOpticalFlowPreviousInput(adjustedPos + vec2<i32>(1, 0));
    let luma2 = LoadOpticalFlowPreviousInput(adjustedPos + vec2<i32>(2, 0));
    let luma3 = LoadOpticalFlowPreviousInput(adjustedPos + vec2<i32>(3, 0));
    return GetPackedLuma(width, pos.x, luma0, luma1, luma2, luma3);
}
#endif
fn SPD_SetMipmap(pos: vec2<i32>, index: u32, value: f32) {
    switch index {
        case 0u: {
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_1)
            if (!ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input_level_1))) {
                textureStore(rw_optical_flow_input_level_1, pos, vec4<u32>(u32(value)));
            }
#endif
        }
        case 1u: {
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_2)
            if (!ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input_level_2))) {
                textureStore(rw_optical_flow_input_level_2, pos, vec4<u32>(u32(value)));
            }
#endif
        }
        case 2u: {
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_3)
            if (!ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input_level_3))) {
                textureStore(rw_optical_flow_input_level_3, pos, vec4<u32>(u32(value)));
            }
#endif
        }
        case 3u: {
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_4)
            if (!ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input_level_4))) {
                textureStore(rw_optical_flow_input_level_4, pos, vec4<u32>(u32(value)));
            }
#endif
        }
        case 4u: {
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_5)
            if (!ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input_level_5))) {
                textureStore(rw_optical_flow_input_level_5, pos, vec4<u32>(u32(value)));
            }
#endif
        }
        case 5u: {
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_INPUT_LEVEL_6)
            if (!ffxWgslOutside(pos, textureDimensions(rw_optical_flow_input_level_6))) {
                textureStore(rw_optical_flow_input_level_6, pos, vec4<u32>(u32(value)));
            }
#endif
        }
        default: {}
    }
}

#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_HISTOGRAM)
fn AtomicIncrementOpticalFlowHistogram(pos: vec2<i32>) {
    if (ffxWgslOutside(pos, textureDimensions(rw_optical_flow_histogram))) { return; }
    textureAtomicAdd(rw_optical_flow_histogram, pos, 1u);
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_SRV_OPTICAL_FLOW_GLOBAL_MOTION_SEARCH)
fn LoadGlobalMotionVector() -> vec2<i32> {
    var value = vec2<u32>(0);
    if (!ffxWgslOutside(vec2<i32>(0, 0), textureDimensions(r_optical_flow_global_motion_search))) {
        value.x = textureLoad(r_optical_flow_global_motion_search, vec2<i32>(0, 0), 0).x;
    }
    if (!ffxWgslOutside(vec2<i32>(1, 0), textureDimensions(r_optical_flow_global_motion_search))) {
        value.y = textureLoad(r_optical_flow_global_motion_search, vec2<i32>(1, 0), 0).x;
    }
    return vec2<i32>(value);
}
#endif
#if defined(FFX_OPTICALFLOW_BIND_UAV_OPTICAL_FLOW_GLOBAL_MOTION_SEARCH)
fn LoadGlobalMotionValue(i: i32) -> u32 {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_global_motion_search)) { return 0u; }
    return atomicLoad(&rw_optical_flow_global_motion_search[i]);
}
fn LoadRwGlobalMotionVector() -> vec2<i32> {
    return vec2<i32>(i32(LoadGlobalMotionValue(0)), i32(LoadGlobalMotionValue(1)));
}
fn StoreGlobalMotionValue(i: i32, value: u32) {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_global_motion_search)) { return; }
    atomicStore(&rw_optical_flow_global_motion_search[i], value);
}
fn AtomicIncrementGlobalMotionValue(i: i32) -> u32 {
    if (i < 0 || u32(i) >= arrayLength(&rw_optical_flow_global_motion_search)) { return 0u; }
    return atomicAdd(&rw_optical_flow_global_motion_search[i], 1u);
}
#endif
#endif
