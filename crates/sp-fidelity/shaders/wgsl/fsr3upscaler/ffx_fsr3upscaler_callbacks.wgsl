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

// WGSL port of ffx_fsr3upscaler_callbacks_hlsl.h.
// HLSL registers retain their numbers: group 0 bindings use the corresponding
// FFX_WGSL_BINDING_OFFSET_* plus the pass's FSR3UPSCALER_BIND_* value.
// WGSL has no D3D root signatures, wave-size attributes or globallycoherent
// texture qualifier. Storage formats match the SDK-created resources.
// Bounds checks preserve HLSL's zero out-of-range loads and discarded stores;
// WGSL's robust access may otherwise select an in-range texel.
#include "fsr3upscaler/ffx_fsr3upscaler_resources.wgsl"
#if defined(FFX_GPU)
#include "ffx_core.wgsl"
#if defined(FFX_WGSL_CORE_FORMATS)
#include "ffx_core_storage.wgsl"
#endif
#if defined(FSR3UPSCALER_BIND_CB_FSR3UPSCALER)
struct cbFSR3Upscaler_t
{
    iRenderSize: FfxInt32x2,
    iPreviousFrameRenderSize: FfxInt32x2,

    iUpscaleSize: FfxInt32x2,
    iPreviousFrameUpscaleSize: FfxInt32x2,

    iMaxRenderSize: FfxInt32x2,
    iMaxUpscaleSize: FfxInt32x2,

    fDeviceToViewDepth: FfxFloat32x4,

    fJitter: FfxFloat32x2,
    fPreviousFrameJitter: FfxFloat32x2,

    fMotionVectorScale: FfxFloat32x2,
    fDownscaleFactor: FfxFloat32x2,

    fMotionVectorJitterCancellation: FfxFloat32x2,
    fTanHalfFOV: FfxFloat32,
    fJitterSequenceLength: FfxFloat32,

    fDeltaTime: FfxFloat32,
    fDeltaPreExposure: FfxFloat32,
    fViewSpaceToMetersFactor: FfxFloat32,
    fFrameIndex: FfxFloat32,

    fVelocityFactor: FfxFloat32,
    fReactivenessScale: FfxFloat32,
    fShadingChangeScale: FfxFloat32,
    fAccumulationAddedPerFrame: FfxFloat32,
    fMinDisocclusionAccumulation: FfxFloat32,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR3UPSCALER_BIND_CB_FSR3UPSCALER) var<uniform> cbFSR3Upscaler: cbFSR3Upscaler_t;

#define FFX_FSR3UPSCALER_CONSTANT_BUFFER_1_SIZE 37  // Number of 32-bit values. This must be kept in sync with the cbFSR3Upscaler size.

/* Define getter functions in the order they are defined in the CB! */
fn RenderSize() -> FfxInt32x2
{
    return cbFSR3Upscaler.iRenderSize;
}

fn PreviousFrameRenderSize() -> FfxInt32x2
{
    return cbFSR3Upscaler.iPreviousFrameRenderSize;
}

fn MaxRenderSize() -> FfxInt32x2
{
    return cbFSR3Upscaler.iMaxRenderSize;
}

fn UpscaleSize() -> FfxInt32x2
{
    return cbFSR3Upscaler.iUpscaleSize;
}

fn PreviousFrameUpscaleSize() -> FfxInt32x2
{
    return cbFSR3Upscaler.iPreviousFrameUpscaleSize;
}

fn MaxUpscaleSize() -> FfxInt32x2
{
    return cbFSR3Upscaler.iMaxUpscaleSize;
}

fn Jitter() -> FfxFloat32x2
{
    return cbFSR3Upscaler.fJitter;
}

fn PreviousFrameJitter() -> FfxFloat32x2
{
    return cbFSR3Upscaler.fPreviousFrameJitter;
}

fn DeviceToViewSpaceTransformFactors() -> FfxFloat32x4
{
    return cbFSR3Upscaler.fDeviceToViewDepth;
}

fn MotionVectorScale() -> FfxFloat32x2
{
    return cbFSR3Upscaler.fMotionVectorScale;
}

fn DownscaleFactor() -> FfxFloat32x2
{
    return cbFSR3Upscaler.fDownscaleFactor;
}

fn MotionVectorJitterCancellation() -> FfxFloat32x2
{
    return cbFSR3Upscaler.fMotionVectorJitterCancellation;
}

fn TanHalfFoV() -> FfxFloat32
{
    return cbFSR3Upscaler.fTanHalfFOV;
}

fn JitterSequenceLength() -> FfxFloat32
{
    return cbFSR3Upscaler.fJitterSequenceLength;
}

fn DeltaTime() -> FfxFloat32
{
    return cbFSR3Upscaler.fDeltaTime;
}

fn DeltaPreExposure() -> FfxFloat32
{
    return cbFSR3Upscaler.fDeltaPreExposure;
}

fn ViewSpaceToMetersFactor() -> FfxFloat32
{
    return cbFSR3Upscaler.fViewSpaceToMetersFactor;
}

fn FrameIndex() -> FfxFloat32
{
    return cbFSR3Upscaler.fFrameIndex;
}

fn VelocityFactor() -> FfxFloat32
{
    return cbFSR3Upscaler.fVelocityFactor;
}

fn AccumulationAddedPerFrame() -> FfxFloat32
{
    return cbFSR3Upscaler.fAccumulationAddedPerFrame;
}

fn MinDisocclusionAccumulation() -> FfxFloat32
{
    return cbFSR3Upscaler.fMinDisocclusionAccumulation;
}

#endif // #if defined(FSR3UPSCALER_BIND_CB_FSR3UPSCALER)

// WGSL: D3D root signatures are represented by explicit resource bindings.
#define FFX_FSR3UPSCALER_CONSTANT_BUFFER_2_SIZE 6

#if defined(FSR3UPSCALER_BIND_CB_AUTOREACTIVE)
struct cbGenerateReactive_t
{
    fTcThreshold: FfxFloat32, // 0.1 is a good starting value, lower will result in more TC pixels
    fTcScale: FfxFloat32,
    fReactiveScale: FfxFloat32,
    fReactiveMax: FfxFloat32,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR3UPSCALER_BIND_CB_AUTOREACTIVE) var<uniform> cbGenerateReactive: cbGenerateReactive_t;

fn TcThreshold() -> FfxFloat32
{
    return cbGenerateReactive.fTcThreshold;
}

fn TcScale() -> FfxFloat32
{
    return cbGenerateReactive.fTcScale;
}

fn ReactiveScale() -> FfxFloat32
{
    return cbGenerateReactive.fReactiveScale;
}

fn ReactiveMax() -> FfxFloat32
{
    return cbGenerateReactive.fReactiveMax;
}
#endif // #if defined(FSR3UPSCALER_BIND_CB_AUTOREACTIVE)

#if defined(FSR3UPSCALER_BIND_CB_RCAS)
struct cbRCAS_t
{
    rcasConfig: FfxUInt32x4,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR3UPSCALER_BIND_CB_RCAS) var<uniform> cbRCAS: cbRCAS_t;

fn RCASConfig() -> FfxUInt32x4
{
    return cbRCAS.rcasConfig;
}
#endif // #if defined(FSR3UPSCALER_BIND_CB_RCAS)


#if defined(FSR3UPSCALER_BIND_CB_REACTIVE)
struct cbGenerateReactive_t
{
    gen_reactive_scale: FfxFloat32,
    gen_reactive_threshold: FfxFloat32,
    gen_reactive_binaryValue: FfxFloat32,
    gen_reactive_flags: FfxUInt32,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR3UPSCALER_BIND_CB_REACTIVE) var<uniform> cbGenerateReactive: cbGenerateReactive_t;

fn GenReactiveScale() -> FfxFloat32
{
    return cbGenerateReactive.gen_reactive_scale;
}

fn GenReactiveThreshold() -> FfxFloat32
{
    return cbGenerateReactive.gen_reactive_threshold;
}

fn GenReactiveBinaryValue() -> FfxFloat32
{
    return cbGenerateReactive.gen_reactive_binaryValue;
}

fn GenReactiveFlags() -> FfxUInt32
{
    return cbGenerateReactive.gen_reactive_flags;
}
#endif // #if defined(FSR3UPSCALER_BIND_CB_REACTIVE)

#if defined(FSR3UPSCALER_BIND_CB_SPD)
struct cbSPD_t
{

    mips: FfxUInt32,
    numWorkGroups: FfxUInt32,
    workGroupOffset: FfxUInt32x2,
    renderSize: FfxUInt32x2,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR3UPSCALER_BIND_CB_SPD) var<uniform> cbSPD: cbSPD_t;

fn MipCount() -> FfxUInt32
{
    return cbSPD.mips;
}

fn NumWorkGroups() -> FfxUInt32
{
    return cbSPD.numWorkGroups;
}

fn WorkGroupOffset() -> FfxUInt32x2
{
    return cbSPD.workGroupOffset;
}

fn SPD_RenderSize() -> FfxUInt32x2
{
    return cbSPD.renderSize;
}
#endif // #if defined(FSR3UPSCALER_BIND_CB_SPD)

@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SAMPLER + 0) var s_PointClamp: sampler;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SAMPLER + 1) var s_LinearClamp: sampler;

#if defined(FSR3UPSCALER_BIND_SRV_SPD_MIPS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_SPD_MIPS) var r_spd_mips: texture_2d<FfxFloat32>;

fn GetSPDMipDimensions(uMipLevel: FfxUInt32) -> FfxInt32x2
{
    return FfxInt32x2(textureDimensions(r_spd_mips, uMipLevel));
}

fn SampleSPDMipLevel(fUV: FfxFloat32x2, mipLevel: FfxUInt32) -> FfxFloat32x2
{
    return textureSampleLevel(r_spd_mips, s_LinearClamp, fUV, FfxFloat32(mipLevel)).xy;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_DEPTH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_INPUT_DEPTH) var r_input_depth: texture_2d<FfxFloat32>;

fn LoadInputDepth(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_depth))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_input_depth, iPxPos, 0).x;
}

fn SampleInputDepth(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_input_depth, s_LinearClamp, fUV, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_REACTIVE_MASK)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_REACTIVE_MASK) var r_reactive_mask: texture_2d<FfxFloat32>;

fn LoadReactiveMask(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_reactive_mask))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_reactive_mask, iPxPos, 0).x * cbFSR3Upscaler.fReactivenessScale;
}

fn GetReactiveMaskResourceDimensions() -> FfxInt32x2
{
    return FfxInt32x2(textureDimensions(r_reactive_mask));
}

fn SampleReactiveMask(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_reactive_mask, s_LinearClamp, fUV, 0).x * cbFSR3Upscaler.fReactivenessScale;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK) var r_transparency_and_composition_mask: texture_2d<FfxFloat32>;

fn LoadTransparencyAndCompositionMask(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_transparency_and_composition_mask))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_transparency_and_composition_mask, iPxPos, 0).x;
}

fn GetTransparencyAndCompositionMaskResourceDimensions() -> FfxInt32x2
{
    return FfxInt32x2(textureDimensions(r_transparency_and_composition_mask));
}

fn SampleTransparencyAndCompositionMask(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_transparency_and_composition_mask, s_LinearClamp, fUV, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_COLOR)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_INPUT_COLOR) var r_input_color_jittered: texture_2d<FfxFloat32>;

fn LoadInputColor(iPxPos: FfxUInt32x2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_color_jittered))) {
        return FfxFloat32x3(0);
    }
    return textureLoad(r_input_color_jittered, iPxPos, 0).rgb;
}

fn SampleInputColor(fUV: FfxFloat32x2) -> FfxFloat32x3
{
    return textureSampleLevel(r_input_color_jittered, s_LinearClamp, fUV, 0).rgb;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_MOTION_VECTORS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_INPUT_MOTION_VECTORS) var r_input_motion_vectors: texture_2d<FfxFloat32>;

fn LoadInputMotionVector(iPxDilatedMotionVectorPos: FfxUInt32x2) -> FfxFloat32x2
{
    var fSrcMotionVector: FfxFloat32x2 = FfxFloat32x2(0);
    if (!ffxWgslOutside(FfxInt32x2(iPxDilatedMotionVectorPos), textureDimensions(r_input_motion_vectors))) {
        fSrcMotionVector = textureLoad(r_input_motion_vectors, iPxDilatedMotionVectorPos, 0).xy;
    }

    var fUvMotionVector: FfxFloat32x2 = fSrcMotionVector * MotionVectorScale();

#if FFX_FSR3UPSCALER_OPTION_JITTERED_MOTION_VECTORS
    fUvMotionVector -= MotionVectorJitterCancellation();
#endif

    return fUvMotionVector;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INTERNAL_UPSCALED)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_INTERNAL_UPSCALED) var r_internal_upscaled_color: texture_2d<FfxFloat32>;

fn LoadHistory(iPxHistory: FfxUInt32x2) -> FfxFloat32x4
{
    if (ffxWgslOutside(FfxInt32x2(iPxHistory), textureDimensions(r_internal_upscaled_color))) {
        return FfxFloat32x4(0);
    }
    return textureLoad(r_internal_upscaled_color, iPxHistory, 0);
}

fn SampleHistory(fUV: FfxFloat32x2) -> FfxFloat32x4
{
    return textureSampleLevel(r_internal_upscaled_color, s_LinearClamp, fUV, 0);
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_LUMA_HISTORY)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_LUMA_HISTORY) var rw_luma_history: texture_storage_2d<rgba16float, write>;

fn StoreLumaHistory(iPxPos: FfxUInt32x2, fLumaHistory: FfxFloat32x4)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_luma_history))) {
        textureStore(rw_luma_history, iPxPos, FfxFloat32x4(fLumaHistory));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_LUMA_HISTORY)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_LUMA_HISTORY) var r_luma_history: texture_2d<FfxFloat32>;

fn LoadLumaHistory(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_luma_history))) {
        return FfxFloat32x4(0);
    }
    return textureLoad(r_luma_history, iPxPos, 0);
}

fn SampleLumaHistory(fUV: FfxFloat32x2) -> FfxFloat32x4
{
    return textureSampleLevel(r_luma_history, s_LinearClamp, fUV, 0);
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_RCAS_INPUT) 
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_RCAS_INPUT) var r_rcas_input: texture_2d<FfxFloat32>;

fn LoadRCAS_Input(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_rcas_input))) {
        return FfxFloat32x4(0);
    }
    return textureLoad(r_rcas_input, iPxPos, 0);
}

fn SampleRCAS_Input(fUV: FfxFloat32x2) -> FfxFloat32x3
{
    return textureSampleLevel(r_rcas_input, s_LinearClamp, fUV, 0).rgb;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_INTERNAL_UPSCALED)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_INTERNAL_UPSCALED) var rw_internal_upscaled_color: texture_storage_2d<rgba16float, write>;

fn StoreReprojectedHistory(iPxHistory: FfxUInt32x2, fHistory: FfxFloat32x4)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxHistory), textureDimensions(rw_internal_upscaled_color))) {
        textureStore(rw_internal_upscaled_color, iPxHistory, FfxFloat32x4(fHistory));
    }
}

fn StoreInternalColorAndWeight(iPxPos: FfxUInt32x2, fColorAndWeight: FfxFloat32x4)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_internal_upscaled_color))) {
        textureStore(rw_internal_upscaled_color, iPxPos, FfxFloat32x4(fColorAndWeight));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_UPSCALED_OUTPUT)
// WGSL requires a concrete storage texel format for the application's output.
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_UPSCALED_OUTPUT) var rw_upscaled_output: texture_storage_2d<rgba16float, write>;

fn StoreUpscaledOutput(iPxPos: FfxUInt32x2, fColor: FfxFloat32x3)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_upscaled_output))) {
        textureStore(rw_upscaled_output, iPxPos, FfxFloat32x4(fColor, 1.f));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_ACCUMULATION)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_ACCUMULATION) var r_accumulation: texture_2d<FfxFloat32>;

fn SampleAccumulation(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_accumulation, s_LinearClamp, fUV, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_ACCUMULATION)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_ACCUMULATION) var rw_accumulation: texture_storage_2d<r8unorm, write>;

fn StoreAccumulation(iPxPos: FfxUInt32x2, fAccumulation: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_accumulation))) {
        textureStore(rw_accumulation, iPxPos, FfxFloat32x4(fAccumulation));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_SHADING_CHANGE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_SHADING_CHANGE) var r_shading_change: texture_2d<FfxFloat32>;

fn LoadShadingChange(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_shading_change))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_shading_change, iPxPos, 0).x * cbFSR3Upscaler.fShadingChangeScale;
}

fn SampleShadingChange(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_shading_change, s_LinearClamp, fUV, 0).x * cbFSR3Upscaler.fShadingChangeScale;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_SHADING_CHANGE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SHADING_CHANGE) var rw_shading_change: texture_storage_2d<r8unorm, write>;

fn StoreShadingChange(iPxPos: FfxUInt32x2, fShadingChange: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_shading_change))) {
        textureStore(rw_shading_change, iPxPos, FfxFloat32x4(fShadingChange));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH) var r_farthest_depth: texture_2d<FfxFloat32>;

fn GetFarthestDepthResourceDimensions() -> FfxInt32x2
{
    return FfxInt32x2(textureDimensions(r_farthest_depth));
}

fn LoadFarthestDepth(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_farthest_depth))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_farthest_depth, iPxPos, 0).x;
}

fn SampleFarthestDepth(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_farthest_depth, s_LinearClamp, fUV, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH) var rw_farthest_depth: texture_storage_2d<r16float, write>;

fn StoreFarthestDepth(iPxPos: FfxUInt32x2, fDepth: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_farthest_depth))) {
        textureStore(rw_farthest_depth, iPxPos, FfxFloat32x4(fDepth));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH_MIP1)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_FARTHEST_DEPTH_MIP1) var r_farthest_depth_mip1: texture_2d<FfxFloat32>;

fn GetFarthestDepthMip1ResourceDimensions() -> FfxInt32x2
{
    return FfxInt32x2(textureDimensions(r_farthest_depth_mip1));
}

fn LoadFarthestDepthMip1(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_farthest_depth_mip1))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_farthest_depth_mip1, iPxPos, 0).x;
}

fn SampleFarthestDepthMip1(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_farthest_depth_mip1, s_LinearClamp, fUV, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH_MIP1)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_FARTHEST_DEPTH_MIP1) var rw_farthest_depth_mip1: texture_storage_2d<r16float, write>;

fn StoreFarthestDepthMip1(iPxPos: FfxUInt32x2, fDepth: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_farthest_depth_mip1))) {
        textureStore(rw_farthest_depth_mip1, iPxPos, FfxFloat32x4(fDepth));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_CURRENT_LUMA)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_CURRENT_LUMA) var r_current_luma: texture_2d<FfxFloat32>;

fn LoadCurrentLuma(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_current_luma))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_current_luma, iPxPos, 0).x;
}

fn SampleCurrentLuma(uv: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_current_luma, s_LinearClamp, uv, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_CURRENT_LUMA)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_CURRENT_LUMA) var rw_current_luma: texture_storage_2d<r16float, write>;

fn StoreCurrentLuma(iPxPos: FfxUInt32x2, fLuma: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_current_luma))) {
        textureStore(rw_current_luma, iPxPos, FfxFloat32x4(fLuma));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_LUMA_INSTABILITY)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_LUMA_INSTABILITY) var r_luma_instability: texture_2d<FfxFloat32>;

fn SampleLumaInstability(uv: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_luma_instability, s_LinearClamp, uv, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_LUMA_INSTABILITY)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_LUMA_INSTABILITY) var rw_luma_instability: texture_storage_2d<r16float, write>;

fn StoreLumaInstability(iPxPos: FfxUInt32x2, fLumaInstability: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_luma_instability))) {
        textureStore(rw_luma_instability, iPxPos, FfxFloat32x4(fLumaInstability));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_PREVIOUS_LUMA)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_PREVIOUS_LUMA) var r_previous_luma: texture_2d<FfxFloat32>;

fn LoadPreviousLuma(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_previous_luma))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_previous_luma, iPxPos, 0).x;
}

fn SamplePreviousLuma(uv: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_previous_luma, s_LinearClamp, uv, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_NEW_LOCKS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_NEW_LOCKS) var r_new_locks: texture_2d<FfxFloat32>;

fn LoadNewLocks(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_new_locks))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_new_locks, iPxPos, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_NEW_LOCKS)
#if defined(FFX_WGSL_CORE_FORMATS)
// WebGPU's core read-write formats are 32-bit: r32float holds the value the
// R8_UNORM texel would return (StoreNewLocks).
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_NEW_LOCKS) var rw_new_locks: texture_storage_2d<r32float, read_write>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_NEW_LOCKS) var rw_new_locks: texture_storage_2d<r8unorm, read_write>;
#endif

fn LoadRwNewLocks(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_new_locks))) {
        return FfxFloat32(0);
    }
    return textureLoad(rw_new_locks, iPxPos).x;
}

fn StoreNewLocks(iPxPos: FfxUInt32x2, newLock: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_new_locks))) {
#if defined(FFX_WGSL_CORE_FORMATS)
        textureStore(rw_new_locks, iPxPos, FfxFloat32x4(ffxWgslUnorm8(newLock)));
#else
        textureStore(rw_new_locks, iPxPos, FfxFloat32x4(newLock));
#endif
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH) var r_reconstructed_previous_nearest_depth: texture_2d<FfxUInt32>;

fn LoadReconstructedPrevDepth(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_reconstructed_previous_nearest_depth))) {
        return FfxFloat32(0);
    }
    return bitcast<FfxFloat32>(textureLoad(r_reconstructed_previous_nearest_depth, iPxPos, 0).x);
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH)
#if defined(FFX_WGSL_BUFFER_ATOMICS)
// WGSL without texture atomics: the texture's words as a storage buffer, one
// a texel in rows of the maximum render width, the width of the texture
// ffxFsr3UpscalerGetSharedResourceDescriptions describes. The backend
// transfers the texture into it before the pass and back after.
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH) var<storage, read_write> rw_reconstructed_previous_nearest_depth: array<atomic<FfxUInt32>>;

fn StoreReconstructedDepth(iPxSample: FfxUInt32x2, fDepth: FfxFloat32)
{
    let uDepth: FfxUInt32 = bitcast<FfxUInt32>(fDepth);

    // WGSL: the buffer has no rows; a position outside the texture would
    // land on another texel's word.
    if (ffxWgslOutside(FfxInt32x2(iPxSample), FfxUInt32x2(MaxRenderSize()))) {
        return;
    }
    let uTexel: FfxUInt32 = iPxSample.y * FfxUInt32(MaxRenderSize().x) + iPxSample.x;
    #if FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH
        atomicMax(&rw_reconstructed_previous_nearest_depth[uTexel], uDepth);
    #else
        atomicMin(&rw_reconstructed_previous_nearest_depth[uTexel], uDepth); // min for standard, max for inverted depth
    #endif
}

fn SetReconstructedDepth(iPxSample: FfxUInt32x2, uValue: FfxUInt32)
{
    if (ffxWgslOutside(FfxInt32x2(iPxSample), FfxUInt32x2(MaxRenderSize()))) {
        return;
    }
    atomicStore(&rw_reconstructed_previous_nearest_depth[iPxSample.y * FfxUInt32(MaxRenderSize().x) + iPxSample.x], uValue);
}
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH) var rw_reconstructed_previous_nearest_depth: texture_storage_2d<r32uint, atomic>;

fn StoreReconstructedDepth(iPxSample: FfxUInt32x2, fDepth: FfxFloat32)
{
    let uDepth: FfxUInt32 = bitcast<FfxUInt32>(fDepth);

    // WGSL: an atomic outside the texture is undefined; HLSL's does nothing.
    if (ffxWgslOutside(FfxInt32x2(iPxSample), textureDimensions(rw_reconstructed_previous_nearest_depth))) {
        return;
    }
    #if FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH
        textureAtomicMax(rw_reconstructed_previous_nearest_depth, FfxInt32x2(iPxSample), uDepth);
    #else
        textureAtomicMin(rw_reconstructed_previous_nearest_depth, FfxInt32x2(iPxSample), uDepth); // min for standard, max for inverted depth
    #endif
}

fn SetReconstructedDepth(iPxSample: FfxUInt32x2, uValue: FfxUInt32)
{
    if (ffxWgslOutside(FfxInt32x2(iPxSample), textureDimensions(rw_reconstructed_previous_nearest_depth))) {
        return;
    }
    textureStore(rw_reconstructed_previous_nearest_depth, iPxSample, FfxUInt32x4(uValue));
}
#endif
#endif

#if defined(FSR3UPSCALER_BIND_UAV_DILATED_DEPTH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_DILATED_DEPTH) var rw_dilated_depth: texture_storage_2d<r32float, write>;

fn StoreDilatedDepth(iPxPos: FfxUInt32x2, fDepth: FfxFloat32)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_dilated_depth))) {
        textureStore(rw_dilated_depth, iPxPos, FfxFloat32x4(fDepth));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_DILATED_MOTION_VECTORS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_DILATED_MOTION_VECTORS) var rw_dilated_motion_vectors: texture_storage_2d<rg16float, write>;

fn StoreDilatedMotionVector(iPxPos: FfxUInt32x2, fMotionVector: FfxFloat32x2)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_dilated_motion_vectors))) {
        textureStore(rw_dilated_motion_vectors, iPxPos, FfxFloat32x4(fMotionVector, 0.0f, 0.0f));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_DILATED_MOTION_VECTORS) var r_dilated_motion_vectors: texture_2d<FfxFloat32>;

fn LoadDilatedMotionVector(iPxInput: FfxUInt32x2) -> FfxFloat32x2
{
    if (ffxWgslOutside(FfxInt32x2(iPxInput), textureDimensions(r_dilated_motion_vectors))) {
        return FfxFloat32x2(0);
    }
    return textureLoad(r_dilated_motion_vectors, iPxInput, 0).xy;
}

fn SampleDilatedMotionVector(fUV: FfxFloat32x2) -> FfxFloat32x2
{
    return textureSampleLevel(r_dilated_motion_vectors, s_LinearClamp, fUV, 0).xy;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_DILATED_DEPTH)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_DILATED_DEPTH) var r_dilated_depth: texture_2d<FfxFloat32>;

fn LoadDilatedDepth(iPxInput: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxInput), textureDimensions(r_dilated_depth))) {
        return FfxFloat32(0);
    }
    return textureLoad(r_dilated_depth, iPxInput, 0).x;
}

fn SampleDilatedDepth(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_dilated_depth, s_LinearClamp, fUV, 0).x;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_INPUT_EXPOSURE) var r_input_exposure: texture_2d<FfxFloat32>;

fn Exposure() -> FfxFloat32
{
    var exposure: FfxFloat32 = textureLoad(r_input_exposure, FfxUInt32x2(0, 0), 0).x;

#if defined(__XBOX_SCARLETT)
    if (exposure < 0.000030517578/** 2^-15 */) {
        exposure = 1.0f;
    }
#else
    if (exposure == 0.0f) {
        exposure = 1.0f;
    }
#endif // #if defined(__XBOX_SCARLETT)

    return exposure;
}
#endif

// BEGIN: FSR3UPSCALER_BIND_SRV_LANCZOS_LUT
#if defined(FSR3UPSCALER_BIND_SRV_LANCZOS_LUT)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_LANCZOS_LUT) var r_lanczos_lut: texture_2d<FfxFloat32>;
#endif

fn SampleLanczos2Weight(x: FfxFloat32) -> FfxFloat32
{
#if defined(FSR3UPSCALER_BIND_SRV_LANCZOS_LUT)
    return textureSampleLevel(r_lanczos_lut, s_LinearClamp, FfxFloat32x2(x / 2, 0.5f), 0).x;
#else
    return 0.f;
#endif
}
// END: FSR3UPSCALER_BIND_SRV_LANCZOS_LUT

#if defined(FSR3UPSCALER_BIND_SRV_DILATED_REACTIVE_MASKS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_DILATED_REACTIVE_MASKS) var r_dilated_reactive_masks: texture_2d<FfxFloat32>;

fn SampleDilatedReactiveMasks(fUV: FfxFloat32x2) -> FfxFloat32x4
{
    return textureSampleLevel(r_dilated_reactive_masks, s_LinearClamp, fUV, 0);
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_DILATED_REACTIVE_MASKS)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_DILATED_REACTIVE_MASKS) var rw_dilated_reactive_masks: texture_storage_2d<rgba8unorm, write>;

fn StoreDilatedReactiveMasks(iPxPos: FfxUInt32x2, fDilatedReactiveMasks: FfxFloat32x4)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_dilated_reactive_masks))) {
        textureStore(rw_dilated_reactive_masks, iPxPos, FfxFloat32x4(fDilatedReactiveMasks));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_INPUT_OPAQUE_ONLY)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_INPUT_OPAQUE_ONLY) var r_input_opaque_only: texture_2d<FfxFloat32>;

fn LoadOpaqueOnly(iPxPos: FFX_MIN16_I2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_opaque_only))) {
        return FfxFloat32x3(0);
    }
    return textureLoad(r_input_opaque_only, iPxPos, 0).xyz;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_PREV_PRE_ALPHA_COLOR)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR) var r_input_prev_color_pre_alpha: texture_2d<FfxFloat32>;

fn LoadPrevPreAlpha(iPxPos: FFX_MIN16_I2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_prev_color_pre_alpha))) {
        return FfxFloat32x3(0);
    }
    return textureLoad(r_input_prev_color_pre_alpha, iPxPos, 0).xyz;
}
#endif

#if defined(FSR3UPSCALER_BIND_SRV_PREV_POST_ALPHA_COLOR)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FSR3UPSCALER_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR) var r_input_prev_color_post_alpha: texture_2d<FfxFloat32>;

fn LoadPrevPostAlpha(iPxPos: FFX_MIN16_I2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_prev_color_post_alpha))) {
        return FfxFloat32x3(0);
    }
    return textureLoad(r_input_prev_color_post_alpha, iPxPos, 0).xyz;
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_AUTOREACTIVE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_AUTOREACTIVE) var rw_output_autoreactive: texture_storage_2d<r8unorm, write>;
#if defined(FSR3UPSCALER_BIND_UAV_AUTOCOMPOSITION)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_AUTOCOMPOSITION) var rw_output_autocomposition: texture_storage_2d<r8unorm, write>;

fn StoreAutoReactive(iPxPos: FFX_MIN16_I2, fReactive: FFX_MIN16_F2)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_autoreactive))) {
        textureStore(rw_output_autoreactive, iPxPos, FfxFloat32x4(FfxFloat32(fReactive.x)));
    }

    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_autocomposition))) {
        textureStore(rw_output_autocomposition, iPxPos, FfxFloat32x4(FfxFloat32(fReactive.y)));
    }
}
#else
// WGSL: the reactive pass's direct RWTexture assignment uses this callback.
fn StoreAutoReactive(iPxPos: FfxInt32x2, fReactive: FfxFloat32)
{
    if (!ffxWgslOutside(iPxPos, textureDimensions(rw_output_autoreactive))) {
        textureStore(rw_output_autoreactive, iPxPos, FfxFloat32x4(fReactive));
    }
}
#endif
#endif

#if defined(FSR3UPSCALER_BIND_UAV_PREV_PRE_ALPHA_COLOR)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_PREV_PRE_ALPHA_COLOR) var rw_output_prev_color_pre_alpha: texture_storage_2d<r11g11b10ufloat, write>;

fn StorePrevPreAlpha(iPxPos: FFX_MIN16_I2, color: FFX_MIN16_F3)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_prev_color_pre_alpha))) {
        textureStore(rw_output_prev_color_pre_alpha, iPxPos, FfxFloat32x4(FfxFloat32x3(color), 0.0f));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_PREV_POST_ALPHA_COLOR)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_PREV_POST_ALPHA_COLOR) var rw_output_prev_color_post_alpha: texture_storage_2d<r11g11b10ufloat, write>;

fn StorePrevPostAlpha(iPxPos: FFX_MIN16_I2, color: FFX_MIN16_F3)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_prev_color_post_alpha))) {
        textureStore(rw_output_prev_color_post_alpha, iPxPos, FfxFloat32x4(FfxFloat32x3(color), 0.0f));
    }
}
#endif

#if defined(FSR3UPSCALER_BIND_UAV_FRAME_INFO)
#if defined(FFX_WGSL_CORE_FORMATS)
// WebGPU's core read-write formats have one component: the backend allocates
// the 1x1 texture as r32float 4x1, a texel a component.
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_FRAME_INFO) var rw_frame_info: texture_storage_2d<r32float, read_write>;

fn LoadFrameInfo() -> FfxFloat32x4
{
    return FfxFloat32x4(textureLoad(rw_frame_info, FfxInt32x2(0, 0)).x, textureLoad(rw_frame_info, FfxInt32x2(1, 0)).x,
                        textureLoad(rw_frame_info, FfxInt32x2(2, 0)).x, textureLoad(rw_frame_info, FfxInt32x2(3, 0)).x);
}

fn StoreFrameInfo(fInfo: FfxFloat32x4)
{
    textureStore(rw_frame_info, FfxInt32x2(0, 0), FfxFloat32x4(fInfo.x));
    textureStore(rw_frame_info, FfxInt32x2(1, 0), FfxFloat32x4(fInfo.y));
    textureStore(rw_frame_info, FfxInt32x2(2, 0), FfxFloat32x4(fInfo.z));
    textureStore(rw_frame_info, FfxInt32x2(3, 0), FfxFloat32x4(fInfo.w));
}
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_FRAME_INFO) var rw_frame_info: texture_storage_2d<rgba32float, read_write>;

fn LoadFrameInfo() -> FfxFloat32x4
{
    return textureLoad(rw_frame_info, FfxInt32x2(0, 0));
}

fn StoreFrameInfo(fInfo: FfxFloat32x4)
{
    textureStore(rw_frame_info, FfxInt32x2(0, 0), fInfo);
}
#endif
#endif

#if defined(FSR3UPSCALER_BIND_SRV_FRAME_INFO)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR3UPSCALER_BIND_SRV_FRAME_INFO) var r_frame_info: texture_2d<FfxFloat32>;

fn FrameInfo() -> FfxFloat32x4
{
#if defined(FFX_WGSL_CORE_FORMATS)
    return FfxFloat32x4(textureLoad(r_frame_info, FfxInt32x2(0, 0), 0).x, textureLoad(r_frame_info, FfxInt32x2(1, 0), 0).x,
                        textureLoad(r_frame_info, FfxInt32x2(2, 0), 0).x, textureLoad(r_frame_info, FfxInt32x2(3, 0), 0).x);
#else
    return textureLoad(r_frame_info, FfxInt32x2(0, 0), 0);
#endif
}
#endif


// WGSL: each mip is an explicitly bound view. All can be read by RWLoadPyramid.
// A split SPD (FFX_WGSL_SPD_PHASE) writes mips 0 to 5 in its first dispatch
// and reads mip 5, the only one SpdLoad reads, in its second, so no mip needs
// a read-write texture.
#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0)
#if defined(FFX_WGSL_SPD_PHASE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0) var rw_spd_mip0: texture_storage_2d<rg16float, write>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0) var rw_spd_mip0: texture_storage_2d<rg16float, read_write>;
#endif
#endif
#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_1)
#if defined(FFX_WGSL_SPD_PHASE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_1) var rw_spd_mip1: texture_storage_2d<rg16float, write>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_1) var rw_spd_mip1: texture_storage_2d<rg16float, read_write>;
#endif
#endif
#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_2)
#if defined(FFX_WGSL_SPD_PHASE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_2) var rw_spd_mip2: texture_storage_2d<rg16float, write>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_2) var rw_spd_mip2: texture_storage_2d<rg16float, read_write>;
#endif
#endif
#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_3)
#if defined(FFX_WGSL_SPD_PHASE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_3) var rw_spd_mip3: texture_storage_2d<rg16float, write>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_3) var rw_spd_mip3: texture_storage_2d<rg16float, read_write>;
#endif
#endif
#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_4)
#if defined(FFX_WGSL_SPD_PHASE)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_4) var rw_spd_mip4: texture_storage_2d<rg16float, write>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_4) var rw_spd_mip4: texture_storage_2d<rg16float, read_write>;
#endif
#endif
#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5)
#if FFX_WGSL_SPD_PHASE == 1
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5) var rw_spd_mip5: texture_storage_2d<rg16float, write>;
#elif FFX_WGSL_SPD_PHASE == 2
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5) var rw_spd_mip5: texture_storage_2d<rg16float, read>;
#else
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5) var rw_spd_mip5: texture_storage_2d<rg16float, read_write>;
#endif
#endif
#if defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_0) && defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_1) && defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_2) && defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_3) && defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_4) && defined(FSR3UPSCALER_BIND_UAV_SPD_MIPS_LEVEL_5)
#if FFX_WGSL_SPD_PHASE == 1
// SPD loads mip 5 in its second dispatch only (SpdDownsampleMips_6_7).
fn RWLoadPyramid(iPxPos: FfxInt32x2, index: FfxUInt32) -> FfxFloat32x2
{
    return FfxFloat32x2(0);
}
#elif FFX_WGSL_SPD_PHASE == 2
// SpdLoad reads mip 5 only.
fn RWLoadPyramid(iPxPos: FfxInt32x2, index: FfxUInt32) -> FfxFloat32x2
{
    if (index != 5u || ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip5))) { return FfxFloat32x2(0); }
    return textureLoad(rw_spd_mip5, iPxPos).xy;
}
#else
fn RWLoadPyramid(iPxPos: FfxInt32x2, index: FfxUInt32) -> FfxFloat32x2
{
    switch index {
        case 0u: {
            if (ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip0))) { return FfxFloat32x2(0); }
            return textureLoad(rw_spd_mip0, iPxPos).xy;
        }
        case 1u: {
            if (ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip1))) { return FfxFloat32x2(0); }
            return textureLoad(rw_spd_mip1, iPxPos).xy;
        }
        case 2u: {
            if (ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip2))) { return FfxFloat32x2(0); }
            return textureLoad(rw_spd_mip2, iPxPos).xy;
        }
        case 3u: {
            if (ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip3))) { return FfxFloat32x2(0); }
            return textureLoad(rw_spd_mip3, iPxPos).xy;
        }
        case 4u: {
            if (ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip4))) { return FfxFloat32x2(0); }
            return textureLoad(rw_spd_mip4, iPxPos).xy;
        }
        case 5u: {
            if (ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip5))) { return FfxFloat32x2(0); }
            return textureLoad(rw_spd_mip5, iPxPos).xy;
        }
        default: { return FfxFloat32x2(0); }
    }
}
#endif
#if FFX_WGSL_SPD_PHASE == 2
// SPD stores mips 0 to 5 in its first dispatch only: the second begins at
// mip 6, which StorePyramid drops.
fn StorePyramid(iPxPos: FfxInt32x2, outValue: FfxFloat32x2, index: FfxUInt32)
{
}
#else
fn StorePyramid(iPxPos: FfxInt32x2, outValue: FfxFloat32x2, index: FfxUInt32)
{
    switch index {
        case 0u: {
            if (!ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip0))) { textureStore(rw_spd_mip0, iPxPos, FfxFloat32x4(outValue, 0, 0)); }
        }
        case 1u: {
            if (!ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip1))) { textureStore(rw_spd_mip1, iPxPos, FfxFloat32x4(outValue, 0, 0)); }
        }
        case 2u: {
            if (!ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip2))) { textureStore(rw_spd_mip2, iPxPos, FfxFloat32x4(outValue, 0, 0)); }
        }
        case 3u: {
            if (!ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip3))) { textureStore(rw_spd_mip3, iPxPos, FfxFloat32x4(outValue, 0, 0)); }
        }
        case 4u: {
            if (!ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip4))) { textureStore(rw_spd_mip4, iPxPos, FfxFloat32x4(outValue, 0, 0)); }
        }
        case 5u: {
            if (!ffxWgslOutside(iPxPos, textureDimensions(rw_spd_mip5))) { textureStore(rw_spd_mip5, iPxPos, FfxFloat32x4(outValue, 0, 0)); }
        }
        default: {}
    }
}
#endif
#endif
// WGSL texture atomics discard their result. The SDK needs InterlockedAdd's
// original value, so texel (0, 0) is element zero of a coherent storage buffer.
#if defined(FSR3UPSCALER_BIND_UAV_SPD_GLOBAL_ATOMIC)
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR3UPSCALER_BIND_UAV_SPD_GLOBAL_ATOMIC) var<storage, read_write> rw_spd_global_atomic: array<atomic<FfxUInt32>>;
fn SPD_IncreaseAtomicCounter(spdCounter: ptr<function, FfxUInt32>)
{
    *spdCounter = atomicAdd(&rw_spd_global_atomic[0], 1u);
}
fn SPD_ResetAtomicCounter()
{
    atomicStore(&rw_spd_global_atomic[0], 0u);
}
#endif
#endif // FFX_GPU
