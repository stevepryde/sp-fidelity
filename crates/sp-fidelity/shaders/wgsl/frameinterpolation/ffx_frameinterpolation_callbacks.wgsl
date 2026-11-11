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

// WGSL port of ffx_frameinterpolation_callbacks_hlsl.h. Register classes keep
// SDK indices, at the shared SRV/UAV/CBV/sampler group 0 binding offsets.
// Root signatures and wave-size attributes have no WGSL equivalent.

#include "frameinterpolation/ffx_frameinterpolation_resources.wgsl"

#if defined(FFX_GPU)
#include "ffx_core.wgsl"
#endif // #if defined(FFX_GPU)

#if defined(FFX_GPU)

#define COUNTER_SPD                          0
#define COUNTER_FRAME_INDEX_SINCE_LAST_RESET 1

  ///////////////////////////////////////////////
 // declare CBs and CB accessors
///////////////////////////////////////////////
#if defined(FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION)
    struct cbFI_t {
    renderSize: FfxInt32x2,
    displaySize: FfxInt32x2,
    displaySizeRcp: FfxFloat32x2,
    cameraNear: FfxFloat32,
    cameraFar: FfxFloat32,
    upscalerTargetSize: FfxInt32x2,
    Mode: FfxInt32,
    reset: FfxInt32,
    fDeviceToViewDepth: FfxFloat32x4,
    deltaTime: FfxFloat32,
    HUDLessAttachedFactor: FfxInt32,
    distortionFieldSize: FfxInt32x2,
    opticalFlowScale: FfxFloat32x2,
    opticalFlowBlockSize: FfxInt32,
    dispatchFlags: FfxUInt32,
    maxRenderSize: FfxInt32x2,
    opticalFlowHalfResMode: FfxInt32,
    NumInstances: FfxInt32,
    interpolationRectBase: FfxInt32x2,
    interpolationRectSize: FfxInt32x2,
    debugBarColor: FfxFloat32x3,
    backBufferTransferFunction: FfxUInt32,
    minMaxLuminance: FfxFloat32x2,
    fTanHalfFOV: FfxFloat32,
    _pad1: FfxInt32,
    fJitter: FfxFloat32x2,
    fMotionVectorScale: FfxFloat32x2,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION) var<uniform> cbFI: cbFI_t;

fn Jitter() -> FfxFloat32x2
{
        return cbFI.fJitter;
    }

fn MotionVectorScale() -> FfxFloat32x2
{
        return cbFI.fMotionVectorScale;
    }

fn InterpolationRectBase() -> FfxInt32x2
{
        return cbFI.interpolationRectBase;
    }

fn InterpolationRectSize() -> FfxInt32x2
{
        return cbFI.interpolationRectSize;
    }

fn RenderSize() -> FfxInt32x2
{
        return cbFI.renderSize;
    }

fn DisplaySize() -> FfxInt32x2
{
        return cbFI.displaySize;
    }

fn Reset() -> FfxBoolean
{
        return cbFI.reset == 1;
    }

fn DeviceToViewSpaceTransformFactors() -> FfxFloat32x4
{
        return cbFI.fDeviceToViewDepth;
    }

fn GetOpticalFlowSize() -> FfxInt32x2
{
        var iOpticalFlowSize: FfxInt32x2 = FfxInt32x2((1.0f / cbFI.opticalFlowScale) / FfxFloat32x2(f32(cbFI.opticalFlowBlockSize)));

        return iOpticalFlowSize;
    }

fn GetOpticalFlowSize2() -> FfxInt32x2
{
        return GetOpticalFlowSize() * 1;
    }

fn GetOpticalFlowScale() -> FfxFloat32x2
{
        return cbFI.opticalFlowScale;
    }

fn GetOpticalFlowBlockSize() -> FfxInt32
{
        return cbFI.opticalFlowBlockSize;
    }

fn GetHUDLessAttachedFactor() -> FfxInt32
{
        return cbFI.HUDLessAttachedFactor;
    }

fn GetDistortionFieldSize() -> FfxInt32x2
{
        return cbFI.distortionFieldSize;
    }

fn GetDispatchFlags() -> FfxUInt32
{
        return cbFI.dispatchFlags;
    }

fn GetMaxRenderSize() -> FfxInt32x2
{
        return cbFI.maxRenderSize;
    }

fn GetOpticalFlowHalfResMode() -> FfxInt32
{
        return cbFI.opticalFlowHalfResMode;
    }

fn GetDebugBarColor() -> FfxFloat32x3
{
        return cbFI.debugBarColor;
    }

fn TanHalfFoV() -> FfxFloat32
{
        return cbFI.fTanHalfFOV;
    }

fn BackBufferTransferFunction() -> FfxUInt32
{
        return cbFI.backBufferTransferFunction;
    }

fn MinLuminance() -> FfxFloat32
{
        return cbFI.minMaxLuminance[0];
    }

fn MaxLuminance() -> FfxFloat32
{
        return cbFI.minMaxLuminance[1];
    }

#endif // #if defined(FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION)

#if defined(FFX_FRAMEINTERPOLATION_BIND_CB_INPAINTING_PYRAMID)
    struct cbInpaintingPyramid_t {
    mips: FfxUInt32,
    numWorkGroups: FfxUInt32,
    workGroupOffset: FfxUInt32x2,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FFX_FRAMEINTERPOLATION_BIND_CB_INPAINTING_PYRAMID) var<uniform> cbInpaintingPyramid: cbInpaintingPyramid_t;

fn NumMips() -> FfxUInt32
{
        return cbInpaintingPyramid.mips;
    }
fn NumWorkGroups() -> FfxUInt32
{
        return cbInpaintingPyramid.numWorkGroups;
    }
fn WorkGroupOffset() -> FfxUInt32x2
{
        return cbInpaintingPyramid.workGroupOffset;
    }
#endif // #if defined(FFX_FRAMEINTERPOLATION_BIND_CB_INPAINTING_PYRAMID)

// WGSL: the Metal backend restricts image loads by clamping their coordinates.
// HLSL Load returns zero outside the resource; preserve that before every load.
fn FiOutside(pos: FfxInt32x2, dimensions: FfxUInt32x2) -> FfxBoolean
{
    return any(pos < FfxInt32x2(0)) | any(pos >= FfxInt32x2(dimensions));
}

// Return zero for this load only; callers still evaluate their SDK math.
fn FiLoadF32(image: texture_2d<f32>, pos: FfxInt32x2, mip: FfxInt32) -> vec4<f32>
{
    if (mip < 0 || mip >= i32(textureNumLevels(image))) { return vec4<f32>(0); }
    if (FiOutside(pos, textureDimensions(image, mip))) { return vec4<f32>(0); }
    return textureLoad(image, pos, mip);
}

// Return zero for this load only; callers still evaluate their SDK math.
fn FiLoadU32(image: texture_2d<u32>, pos: FfxInt32x2, mip: FfxInt32) -> vec4<u32>
{
    if (mip < 0 || mip >= i32(textureNumLevels(image))) { return vec4<u32>(0); }
    if (FiOutside(pos, textureDimensions(image, mip))) { return vec4<u32>(0); }
    return textureLoad(image, pos, mip);
}

// Return zero for this load only; callers still evaluate their SDK math.
fn FiLoadI32(image: texture_2d<i32>, pos: FfxInt32x2, mip: FfxInt32) -> vec4<i32>
{
    if (mip < 0 || mip >= i32(textureNumLevels(image))) { return vec4<i32>(0); }
    if (FiOutside(pos, textureDimensions(image, mip))) { return vec4<i32>(0); }
    return textureLoad(image, pos, mip);
}

// WGSL: returned InterlockedMax values require storage buffers. Keep the SDK's
// 2D texture allocation stride and its zero/discard behavior outside that allocation.
fn IsGameFieldPositionValid(pos: FfxInt32x2) -> FfxBoolean
{
    return all(pos >= FfxInt32x2(0)) && all(pos < GetMaxRenderSize());
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SAMPLER) var s_LinearClamp: sampler;

///////////////////////////////////////////////
// declare SRVs and SRV accessors
///////////////////////////////////////////////

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_PREVIOUS_INTERPOLATION_SOURCE
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_PREVIOUS_INTERPOLATION_SOURCE) var r_previous_interpolation_source: texture_2d<f32>;

fn LoadPreviousBackbuffer(iPxPos: FfxInt32x2) -> FfxFloat32x3
{
        return FiLoadF32(r_previous_interpolation_source, FfxInt32x2(iPxPos), 0).rgb;
    }
fn SamplePreviousBackbuffer(fUv: FfxFloat32x2) -> FfxFloat32x3
{
        return textureSampleLevel(r_previous_interpolation_source, s_LinearClamp, fUv, 0.0).xyz;
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_CURRENT_INTERPOLATION_SOURCE
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_CURRENT_INTERPOLATION_SOURCE) var r_current_interpolation_source: texture_2d<f32>;

fn LoadCurrentBackbuffer(iPxPos: FfxInt32x2) -> FfxFloat32x3
{
        return FiLoadF32(r_current_interpolation_source, FfxInt32x2(iPxPos), 0).rgb;
    }
fn SampleCurrentBackbuffer(fUv: FfxFloat32x2) -> FfxFloat32x3
{
        return textureSampleLevel(r_current_interpolation_source, s_LinearClamp, fUv, 0.0).xyz;
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_DILATED_MOTION_VECTORS
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_DILATED_MOTION_VECTORS) var r_dilated_motion_vectors: texture_2d<f32>;

fn LoadDilatedMotionVector(iPxPos: FfxInt32x2) -> FfxFloat32x2
{
        return FiLoadF32(r_dilated_motion_vectors, FfxInt32x2(iPxPos), 0).xy;
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_DILATED_DEPTH
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_DILATED_DEPTH) var r_dilated_depth: texture_2d<f32>;

fn LoadDilatedDepth(iPxPos: FfxInt32x2) -> FfxFloat32
{
        return FiLoadF32(r_dilated_depth, FfxInt32x2(iPxPos), 0).x;
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME) var r_reconstructed_depth_previous_frame: texture_2d<u32>;

fn LoadReconstructedDepthPreviousFrame(iPxInput: FfxInt32x2) -> FfxFloat32
{
        return bitcast<f32>(FiLoadU32(r_reconstructed_depth_previous_frame, FfxInt32x2(iPxInput), 0).x);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME) var r_reconstructed_depth_interpolated_frame: texture_2d<u32>;

fn LoadEstimatedInterpolationFrameDepth(iPxInput: FfxInt32x2) -> FfxFloat32
{
        return bitcast<f32>(FiLoadU32(r_reconstructed_depth_interpolated_frame, FfxInt32x2(iPxInput), 0).x);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_DISOCCLUSION_MASK
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_DISOCCLUSION_MASK) var r_disocclusion_mask: texture_2d<f32>;

fn LoadDisocclusionMask(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
        return FiLoadF32(r_disocclusion_mask, FfxInt32x2(iPxPos), 0);
    }
fn SampleDisocclusionMask(fUv: FfxFloat32x2) -> FfxFloat32x4
{
        return textureSampleLevel(r_disocclusion_mask, s_LinearClamp, fUv, 0.0);
    }
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_X) &&      defined(FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_Y)
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_X) var<storage, read> r_game_motion_vector_field_x: array<u32>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_Y) var<storage, read> r_game_motion_vector_field_y: array<u32>;

fn LoadGameFieldMv(iPxSample: FfxInt32x2) -> FfxUInt32x2
{
    if (!IsGameFieldPositionValid(iPxSample)) { return FfxUInt32x2(0); }
        var packedX: FfxUInt32 = r_game_motion_vector_field_x[u32((iPxSample).y * GetMaxRenderSize().x + (iPxSample).x)];
        var packedY: FfxUInt32 = r_game_motion_vector_field_y[u32((iPxSample).y * GetMaxRenderSize().x + (iPxSample).x)];

        return FfxUInt32x2(packedX, packedY);
    }
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X) &&      defined(FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y)
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X) var r_optical_flow_motion_vector_field_x: texture_2d<u32>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y) var r_optical_flow_motion_vector_field_y: texture_2d<u32>;

fn LoadOpticalFlowFieldMv(iPxSample: FfxInt32x2) -> FfxUInt32x2
{
        var packedX: FfxUInt32 = FiLoadU32(r_optical_flow_motion_vector_field_x, FfxInt32x2(iPxSample), 0).x;
        var packedY: FfxUInt32 = FiLoadU32(r_optical_flow_motion_vector_field_y, FfxInt32x2(iPxSample), 0).x;

        return FfxUInt32x2(packedX, packedY);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW) var r_optical_flow: texture_2d<i32>;

    #if defined(FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION)
fn LoadOpticalFlow(iPxPos: FfxInt32x2) -> FfxFloat32x2
{
            return FfxFloat32x2(FiLoadI32(r_optical_flow, FfxInt32x2(iPxPos), 0).xy) * GetOpticalFlowScale();
        }
    #endif
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_UPSAMPLED
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_UPSAMPLED) var r_optical_flow_upsampled: texture_2d<f32>;

fn LoadOpticalFlowUpsampled(iPxPos: FfxInt32x2) -> FfxFloat32x2
{
        return FiLoadF32(r_optical_flow_upsampled, FfxInt32x2(iPxPos), 0).xy;
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_CONFIDENCE
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_CONFIDENCE) var r_optical_flow_confidence: texture_2d<u32>;

fn LoadOpticalFlowConfidence(iPxPos: FfxInt32x2) -> FfxFloat32
{
        return f32(FiLoadU32(r_optical_flow_confidence, FfxInt32x2(iPxPos), 0).y);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_GLOBAL_MOTION
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_GLOBAL_MOTION) var r_optical_flow_global_motion: texture_2d<u32>;

fn LoadOpticalFlowGlobalMotion(iPxPos: FfxInt32x2) -> FfxUInt32
{
        return FiLoadU32(r_optical_flow_global_motion, FfxInt32x2(iPxPos), 0).x;
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_SCENE_CHANGE_DETECTION
    // WGSL: the optical-flow counter returns its old value, so the shared SCD
    // resource is a storage buffer in both effects. Its SDK layout is a 3x1 row.
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_SCENE_CHANGE_DETECTION) var<storage, read> r_optical_flow_scd: array<u32>;

fn LoadOpticalFlowSceneChangeDetection(iPxPos: FfxInt32x2) -> FfxUInt32
{
        return r_optical_flow_scd[u32(iPxPos.x)];
    }

fn HasSceneChanged() -> FfxBoolean
{
        #define SCD_OUTPUT_HISTORY_BITS_SLOT 1
        //if (FrameIndex() <= 5) // threshold according to original OpenCL code
        //{
        //    return 1.0;
        //}
        //else
        {
            // Report that the scene is changed if the change was detected in any of the
            // 4 previous frames (0xfu - covers 4 history bits).
            return (r_optical_flow_scd[SCD_OUTPUT_HISTORY_BITS_SLOT] & 0xfu) != 0;
        }
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_DEBUG
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_DEBUG) var r_optical_flow_debug: texture_2d<f32>;

fn LoadOpticalFlowDebug(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
        return FiLoadF32(r_optical_flow_debug, FfxInt32x2(iPxPos), 0);
    }
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_INPAINTING_MASK) && defined(FFX_FRAMEINTERPOLATION_BIND_SRV_OUTPUT)
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OUTPUT) var r_output: texture_2d<f32>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_INPAINTING_MASK) var r_inpainting_mask: texture_2d<f32>;

fn LoadFrameInterpolationOutput(iPxInput: FfxInt32x2) -> FfxFloat32x4
{
        return FfxFloat32x4(FiLoadF32(r_output, FfxInt32x2(iPxInput), 0).rgb, FiLoadF32(r_inpainting_mask, FfxInt32x2(iPxInput), 0).x);
    }
#elif defined(FFX_FRAMEINTERPOLATION_BIND_SRV_OUTPUT)
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_OUTPUT) var r_output: texture_2d<f32>;
fn LoadFrameInterpolationOutput(iPxInput: FfxInt32x2) -> FfxFloat32x4
{
        return FiLoadF32(r_output, FfxInt32x2(iPxInput), 0);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_INPAINTING_PYRAMID
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_INPAINTING_PYRAMID) var r_inpainting_pyramid: texture_2d<f32>;

fn LoadInpaintingPyramid(mipLevel: FfxInt32, iPxInput: FfxInt32x2) -> FfxFloat32x4
{
        return FiLoadF32(r_inpainting_pyramid, iPxInput, mipLevel);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_PRESENT_BACKBUFFER
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_PRESENT_BACKBUFFER) var r_present_backbuffer: texture_2d<f32>;

fn LoadPresentBackbuffer(iPxInput: FfxInt32x2) -> FfxFloat32x4
{
        return FiLoadF32(r_present_backbuffer, FfxInt32x2(iPxInput), 0);
    }
fn SamplePresentBackbuffer(fUv: FfxFloat32x2) -> FfxFloat32x4
{
        return textureSampleLevel(r_present_backbuffer, s_LinearClamp, fUv, 0.0);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_SRV_COUNTERS
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_COUNTERS) var<storage, read> r_counters: array<u32>;

fn LoadCounter(iPxPos: FfxInt32) -> FfxUInt32
{
        return r_counters[iPxPos];
    }

fn FrameIndexSinceLastReset() -> FfxUInt32
{
        return LoadCounter(COUNTER_FRAME_INDEX_SINCE_LAST_RESET);
    }
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH) var r_input_depth: texture_2d<f32>;
fn LoadInputDepth(iPxPos: FfxInt32x2) -> FfxFloat32
{
    return FiLoadF32(r_input_depth, FfxInt32x2(iPxPos), 0).x;
}
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_INPUT_MOTION_VECTORS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_INPUT_MOTION_VECTORS) var r_input_motion_vectors: texture_2d<f32>;
fn LoadInputMotionVector(iPxDilatedMotionVectorPos: FfxInt32x2) -> FfxFloat32x2
{
    var fSrcMotionVector: FfxFloat32x2 = FiLoadF32(r_input_motion_vectors, FfxInt32x2(iPxDilatedMotionVectorPos), 0).xy;

    var fUvMotionVector: FfxFloat32x2 = fSrcMotionVector * MotionVectorScale();

#if FFX_FRAMEINTERPOLATION_OPTION_JITTERED_MOTION_VECTORS
    fUvMotionVector -= MotionVectorJitterCancellation();
#endif

    return fUvMotionVector;
}
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_DISTORTION_FIELD)
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FRAMEINTERPOLATION_BIND_SRV_DISTORTION_FIELD) var r_input_distortion_field: texture_2d<f32>;
fn SampleDistortionField(fUv: FfxFloat32x2) -> FfxFloat32x2
{
        return textureSampleLevel(r_input_distortion_field, s_LinearClamp, fUv, 0.0).xy;
    }
#endif

///////////////////////////////////////////////
// declare UAVs and UAV accessors
///////////////////////////////////////////////
#if defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_MASK) && defined(FFX_FRAMEINTERPOLATION_BIND_UAV_OUTPUT)
#if FFX_FRAMEINTERPOLATION_OUTPUT_READ
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_OUTPUT) var rw_output: texture_storage_2d<rgba16float, read_write>;
#else
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_OUTPUT) var rw_output: texture_storage_2d<rgba16float, write>;
#endif
#if FFX_FRAMEINTERPOLATION_OUTPUT_READ
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_MASK) var rw_inpainting_mask: texture_storage_2d<r8unorm, read_write>;
#else
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_MASK) var rw_inpainting_mask: texture_storage_2d<r8unorm, write>;
#endif

#if FFX_FRAMEINTERPOLATION_OUTPUT_READ
fn RWLoadFrameinterpolationOutput(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
    var color: FfxFloat32x3 = FfxFloat32x3(0);
    var mask: FfxFloat32 = 0;
    if (!FiOutside(iPxPos, textureDimensions(rw_output))) {
        color = textureLoad(rw_output, iPxPos).rgb;
    }
    if (!FiOutside(iPxPos, textureDimensions(rw_inpainting_mask))) {
        mask = textureLoad(rw_inpainting_mask, iPxPos).x;
    }
    return FfxFloat32x4(color, mask);
}
#endif

fn StoreFrameinterpolationOutput(iPxPos: FfxInt32x2, val: FfxFloat32x4)
{
        textureStore(rw_output, FfxInt32x2(iPxPos), FfxFloat32x4(val.rgb, 0.0));
        textureStore(rw_inpainting_mask, FfxInt32x2(iPxPos), FfxFloat32x4(val.a, 0,0,0));
    }

#elif defined(FFX_FRAMEINTERPOLATION_BIND_UAV_OUTPUT)
#if FFX_FRAMEINTERPOLATION_OUTPUT_READ
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_OUTPUT) var rw_output: texture_storage_2d<rgba16float, read_write>;
#else
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_OUTPUT) var rw_output: texture_storage_2d<rgba16float, write>;
#endif

#if FFX_FRAMEINTERPOLATION_OUTPUT_READ
fn RWLoadFrameinterpolationOutput(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
    if (FiOutside(iPxPos, textureDimensions(rw_output))) { return FfxFloat32x4(0); }
        return textureLoad(rw_output, FfxInt32x2(iPxPos));
    }
#endif

fn StoreFrameinterpolationOutput(iPxPos: FfxInt32x2, val: FfxFloat32x4)
{
        textureStore(rw_output, FfxInt32x2(iPxPos), val);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_UAV_DILATED_MOTION_VECTORS
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_DILATED_MOTION_VECTORS) var rw_dilated_motion_vectors: texture_storage_2d<rg16float, write>;

// WGSL: the SDK UAV read accessor is unused by every pass; this binding
// uses write access so its native format remains supported on Metal.

fn StoreDilatedMotionVectors(iPxPos: FfxInt32x2, val: FfxFloat32x2)
{
        textureStore(rw_dilated_motion_vectors, FfxInt32x2(iPxPos), FfxFloat32x4(val, 0,0));
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_UAV_DILATED_DEPTH
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_DILATED_DEPTH) var rw_dilated_depth: texture_storage_2d<r32float, write>;

// WGSL: the SDK UAV read accessor is unused by every pass; this binding
// uses write access so its native format remains supported on Metal.

fn StoreDilatedDepth(iPxPos: FfxInt32x2, val: FfxFloat32)
{
        textureStore(rw_dilated_depth, FfxInt32x2(iPxPos), FfxFloat32x4(val, 0,0,0));
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_UAV_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME) var rw_reconstructed_depth_previous_frame: texture_storage_2d<r32uint, atomic>;

fn RWLoadReconstructedDepthPreviousFrame(iPxPos: FfxInt32x2) -> FfxFloat32
{
    if (FiOutside(iPxPos, textureDimensions(rw_reconstructed_depth_previous_frame))) { return FfxFloat32(0); }
        return bitcast<f32>(textureLoad(rw_reconstructed_depth_previous_frame, FfxInt32x2(iPxPos)).x);
    }

fn UpdateReconstructedDepthPreviousFrame(iPxSample: FfxInt32x2, fDepth: FfxFloat32)
{
        var uDepth: FfxUInt32 = bitcast<u32>(fDepth);

#if FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
        textureAtomicMax(rw_reconstructed_depth_previous_frame, FfxInt32x2(iPxSample), uDepth);
#else
        textureAtomicMin(rw_reconstructed_depth_previous_frame, FfxInt32x2(iPxSample), uDepth);  // min for standard, max for inverted depth
#endif
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_UAV_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME) var rw_reconstructed_depth_interpolated_frame: texture_storage_2d<r32uint, atomic>;

fn RWLoadReconstructedDepthInterpolatedFrame(iPxPos: FfxInt32x2) -> FfxFloat32
{
    if (FiOutside(iPxPos, textureDimensions(rw_reconstructed_depth_interpolated_frame))) { return FfxFloat32(0); }
        return bitcast<f32>(textureLoad(rw_reconstructed_depth_interpolated_frame, FfxInt32x2(iPxPos)).x);
    }

fn StoreReconstructedDepthInterpolatedFrame(iPxPos: FfxInt32x2, value: FfxFloat32)
{
        var uDepth: FfxUInt32                                  = bitcast<u32>(value);
        textureStore(rw_reconstructed_depth_interpolated_frame, FfxInt32x2(iPxPos), FfxUInt32x4(uDepth, 0,0,0));
    }

fn UpdateReconstructedDepthInterpolatedFrame(iPxSample: FfxInt32x2, fDepth: FfxFloat32)
{
        var uDepth: FfxUInt32 = bitcast<u32>(fDepth);

#if FFX_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
        textureAtomicMax(rw_reconstructed_depth_interpolated_frame, FfxInt32x2(iPxSample), uDepth);
#else
        textureAtomicMin(rw_reconstructed_depth_interpolated_frame, FfxInt32x2(iPxSample), uDepth);  // min for standard, max for inverted depth
#endif
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_UAV_DISOCCLUSION_MASK
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_DISOCCLUSION_MASK) var rw_disocclusion_mask: texture_storage_2d<rg8unorm, write>;

// WGSL: the SDK UAV read accessor is unused by every pass; this binding
// uses write access so its native format remains supported on Metal.

fn StoreDisocclusionMask(iPxPos: FfxInt32x2, val: FfxFloat32x2)
{
        textureStore(rw_disocclusion_mask, FfxInt32x2(iPxPos), FfxFloat32x4(val, 0,0));
    }
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_X) &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_Y)

    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_X) var<storage, read_write> rw_game_motion_vector_field_x: array<atomic<u32>>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_GAME_MOTION_VECTOR_FIELD_Y) var<storage, read_write> rw_game_motion_vector_field_y: array<atomic<u32>>;

fn RWLoadGameMotionVectorFieldX(iPxPos: FfxInt32x2) -> FfxUInt32
{
    if (!IsGameFieldPositionValid(iPxPos)) { return 0u; }
        return atomicLoad(&rw_game_motion_vector_field_x[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)]);
    }

fn StoreGameMotionVectorFieldX(iPxPos: FfxInt32x2, val: FfxUInt32)
{
    if (!IsGameFieldPositionValid(iPxPos)) { return; }
        atomicStore(&rw_game_motion_vector_field_x[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)], val);
    }

fn RWLoadGameMotionVectorFieldY(iPxPos: FfxInt32x2) -> FfxUInt32
{
    if (!IsGameFieldPositionValid(iPxPos)) { return 0u; }
        return atomicLoad(&rw_game_motion_vector_field_y[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)]);
    }

fn StoreGameMotionVectorFieldY(iPxPos: FfxInt32x2, val: FfxUInt32)
{
    if (!IsGameFieldPositionValid(iPxPos)) { return; }
        atomicStore(&rw_game_motion_vector_field_y[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)], val);
    }

fn UpdateGameMotionVectorField(iPxPos: FfxInt32x2, packedVector: FfxUInt32x2)
{
    if (!IsGameFieldPositionValid(iPxPos)) { return; }
        atomicMax(&rw_game_motion_vector_field_x[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)], packedVector.x);
        atomicMax(&rw_game_motion_vector_field_y[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)], packedVector.y);
    }

fn UpdateGameMotionVectorFieldEx(iPxPos: FfxInt32x2, packedVector: FfxUInt32x2) -> FfxUInt32
{
    if (!IsGameFieldPositionValid(iPxPos)) { return 0u; }
        var uPreviousValueX: FfxUInt32 = 0;
        var uPreviousValueY: FfxUInt32 = 0;
        uPreviousValueX = atomicMax(&rw_game_motion_vector_field_x[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)], packedVector.x);
        uPreviousValueY = atomicMax(&rw_game_motion_vector_field_y[u32((iPxPos).y * GetMaxRenderSize().x + (iPxPos).x)], packedVector.y);

        let uExistingVectorFieldEntry: FfxUInt32 = max(uPreviousValueX, uPreviousValueY);

        return uExistingVectorFieldEntry;
    }
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_UAV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X) &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y)

    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X) var rw_optical_flow_motion_vector_field_x: texture_storage_2d<r32uint, atomic>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y) var rw_optical_flow_motion_vector_field_y: texture_storage_2d<r32uint, atomic>;

fn RWLoadOpticalflowMotionVectorFieldX(iPxPos: FfxInt32x2) -> FfxUInt32
{
    if (FiOutside(iPxPos, textureDimensions(rw_optical_flow_motion_vector_field_x))) { return FfxUInt32(0); }
        return textureLoad(rw_optical_flow_motion_vector_field_x, FfxInt32x2(iPxPos)).x;
    }
fn StoreOpticalflowMotionVectorFieldX(iPxPos: FfxInt32x2, val: FfxUInt32)
{
        textureStore(rw_optical_flow_motion_vector_field_x, FfxInt32x2(iPxPos), FfxUInt32x4(val, 0,0,0));
    }
fn RWLoadOpticalflowMotionVectorFieldY(iPxPos: FfxInt32x2) -> FfxUInt32
{
    if (FiOutside(iPxPos, textureDimensions(rw_optical_flow_motion_vector_field_y))) { return FfxUInt32(0); }
        return textureLoad(rw_optical_flow_motion_vector_field_y, FfxInt32x2(iPxPos)).x;
    }
fn StoreOpticalflowMotionVectorFieldY(iPxPos: FfxInt32x2, val: FfxUInt32)
{
        textureStore(rw_optical_flow_motion_vector_field_y, FfxInt32x2(iPxPos), FfxUInt32x4(val, 0,0,0));
    }
fn UpdateOpticalflowMotionVectorField(iPxPos: FfxInt32x2, packedVector: FfxUInt32x2)
{
        textureAtomicMax(rw_optical_flow_motion_vector_field_x, FfxInt32x2(iPxPos), packedVector.x);
        textureAtomicMax(rw_optical_flow_motion_vector_field_y, FfxInt32x2(iPxPos), packedVector.y);
    }
#endif

#ifdef FFX_FRAMEINTERPOLATION_BIND_UAV_COUNTERS
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_COUNTERS) var<storage, read_write> rw_counters: array<atomic<u32>>;

fn RWLoadCounter(iPxPos: FfxInt32) -> FfxUInt32
{
        return atomicLoad(&rw_counters[iPxPos]);
    }

fn StoreCounter(iPxPos: FfxInt32, counter: FfxUInt32)
{
        atomicStore(&rw_counters[iPxPos], counter);
    }
fn AtomicIncreaseCounter(iPxPos: FfxInt32, oldVal: ptr<function, FfxUInt32>)
{
        (*oldVal) = atomicAdd(&rw_counters[iPxPos], 1);
    }
#endif


#if defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_0)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_1)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_2)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_3)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_4)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_5)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_6)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_7)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_8)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_9)    &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_10)   &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_11)   &&      defined(FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_12)

    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_0) var rw_inpainting_pyramid0: texture_storage_2d<rgba16float, write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_1) var rw_inpainting_pyramid1: texture_storage_2d<rgba16float, write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_2) var rw_inpainting_pyramid2: texture_storage_2d<rgba16float, write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_3) var rw_inpainting_pyramid3: texture_storage_2d<rgba16float, write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_4) var rw_inpainting_pyramid4: texture_storage_2d<rgba16float, write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_5) var rw_inpainting_pyramid5: texture_storage_2d<rgba16float, read_write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_6) var rw_inpainting_pyramid6: texture_storage_2d<rgba16float, read_write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_7) var rw_inpainting_pyramid7: texture_storage_2d<rgba16float, read_write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_8) var rw_inpainting_pyramid8: texture_storage_2d<rgba16float, read_write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_9) var rw_inpainting_pyramid9: texture_storage_2d<rgba16float, read_write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_10) var rw_inpainting_pyramid10: texture_storage_2d<rgba16float, read_write>;
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FFX_FRAMEINTERPOLATION_BIND_UAV_INPAINTING_PYRAMID_MIPMAP_11) var rw_inpainting_pyramid11: texture_storage_2d<rgba16float, read_write>;
    // WGSL: SPD stores levels 0..11; DXC removes the SDK mip-12 binding.


// WGSL: SPD only reloads mip 5. The other SDK LOAD macro cases are unused;
// retaining them would require unsupported read/write access to every format.
fn RWLoadInpaintingPyramid(iPxPos: FfxInt32x2, index: FfxUInt32) -> FfxFloat32x4
{
    if (FiOutside(iPxPos, textureDimensions(rw_inpainting_pyramid5))) { return FfxFloat32x4(0); }
    if (index == 5u) { return textureLoad(rw_inpainting_pyramid5, iPxPos); }
    return FfxFloat32x4(0);
}

fn StoreInpaintingPyramid(iPxPos: FfxInt32x2, outValue: FfxFloat32x4, index_in: FfxUInt32)
{
    var index: FfxUInt32 = index_in;
        if (index == 0u) { textureStore(rw_inpainting_pyramid0, iPxPos, outValue); }
        if (index == 1u) { textureStore(rw_inpainting_pyramid1, iPxPos, outValue); }
        if (index == 2u) { textureStore(rw_inpainting_pyramid2, iPxPos, outValue); }
        if (index == 3u) { textureStore(rw_inpainting_pyramid3, iPxPos, outValue); }
        if (index == 4u) { textureStore(rw_inpainting_pyramid4, iPxPos, outValue); }
        if (index == 5u) { textureStore(rw_inpainting_pyramid5, iPxPos, outValue); }
        if (index == 6u) { textureStore(rw_inpainting_pyramid6, iPxPos, outValue); }
        if (index == 7u) { textureStore(rw_inpainting_pyramid7, iPxPos, outValue); }
        if (index == 8u) { textureStore(rw_inpainting_pyramid8, iPxPos, outValue); }
        if (index == 9u) { textureStore(rw_inpainting_pyramid9, iPxPos, outValue); }
        if (index == 10u) { textureStore(rw_inpainting_pyramid10, iPxPos, outValue); }
        if (index == 11u) { textureStore(rw_inpainting_pyramid11, iPxPos, outValue); }

    }
#endif

#endif // #if defined(FFX_GPU)
