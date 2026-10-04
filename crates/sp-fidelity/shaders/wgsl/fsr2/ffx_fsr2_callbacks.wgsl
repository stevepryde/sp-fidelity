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

// WGSL port of ffx_fsr2_callbacks_hlsl.h.
//
// HLSL registers keep their numbers: tN, uN, bN and sN are group 0 bindings at
// the FFX_WGSL_BINDING_OFFSET_* constants (src/shaders.rs) plus the pass
// module's FSR2_BIND_* value.

#include "fsr2/ffx_fsr2_resources.wgsl"

#if defined(FFX_GPU)
#include "ffx_core.wgsl"

// WGSL: FFX_PREFER_WAVE64 (an optional [WaveSize(64)]) has no WGSL form; see
// SDK-P6. The DECLARE_*_REGISTER/FFX_FSR2_DECLARE_* register macros are the
// binding offsets above.

#if defined(FSR2_BIND_CB_FSR2)
    struct cbFSR2_t
    {
        iRenderSize: FfxInt32x2,
        iMaxRenderSize: FfxInt32x2,
        iDisplaySize: FfxInt32x2,
        iInputColorResourceDimensions: FfxInt32x2,
        iLumaMipDimensions: FfxInt32x2,
        iLumaMipLevelToUse: FfxInt32,
        iFrameIndex: FfxInt32,

        fDeviceToViewDepth: FfxFloat32x4,
        fJitter: FfxFloat32x2,
        fMotionVectorScale: FfxFloat32x2,
        fDownscaleFactor: FfxFloat32x2,
        fMotionVectorJitterCancellation: FfxFloat32x2,
        fPreExposure: FfxFloat32,
        fPreviousFramePreExposure: FfxFloat32,
        fTanHalfFOV: FfxFloat32,
        fJitterSequenceLength: FfxFloat32,
        fDeltaTime: FfxFloat32,
        fDynamicResChangeFactor: FfxFloat32,
        fViewSpaceToMetersFactor: FfxFloat32,
        fPadding: FfxFloat32,
    }
    @group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR2_BIND_CB_FSR2) var<uniform> cbFSR2: cbFSR2_t;

#define FFX_FSR2_CONSTANT_BUFFER_1_SIZE 32

/* Define getter functions in the order they are defined in the CB! */
fn RenderSize() -> FfxInt32x2
{
    return cbFSR2.iRenderSize;
}

fn MaxRenderSize() -> FfxInt32x2
{
    return cbFSR2.iMaxRenderSize;
}

fn DisplaySize() -> FfxInt32x2
{
    return cbFSR2.iDisplaySize;
}

fn InputColorResourceDimensions() -> FfxInt32x2
{
    return cbFSR2.iInputColorResourceDimensions;
}

fn LumaMipDimensions() -> FfxInt32x2
{
    return cbFSR2.iLumaMipDimensions;
}

fn LumaMipLevelToUse() -> FfxInt32
{
    return cbFSR2.iLumaMipLevelToUse;
}

fn FrameIndex() -> FfxInt32
{
    return cbFSR2.iFrameIndex;
}

fn Jitter() -> FfxFloat32x2
{
    return cbFSR2.fJitter;
}

fn DeviceToViewSpaceTransformFactors() -> FfxFloat32x4
{
    return cbFSR2.fDeviceToViewDepth;
}

fn MotionVectorScale() -> FfxFloat32x2
{
    return cbFSR2.fMotionVectorScale;
}

fn DownscaleFactor() -> FfxFloat32x2
{
    return cbFSR2.fDownscaleFactor;
}

fn MotionVectorJitterCancellation() -> FfxFloat32x2
{
    return cbFSR2.fMotionVectorJitterCancellation;
}

fn PreExposure() -> FfxFloat32
{
    return cbFSR2.fPreExposure;
}

fn PreviousFramePreExposure() -> FfxFloat32
{
    return cbFSR2.fPreviousFramePreExposure;
}

fn TanHalfFoV() -> FfxFloat32
{
    return cbFSR2.fTanHalfFOV;
}

fn JitterSequenceLength() -> FfxFloat32
{
    return cbFSR2.fJitterSequenceLength;
}

fn DeltaTime() -> FfxFloat32
{
    return cbFSR2.fDeltaTime;
}

fn DynamicResChangeFactor() -> FfxFloat32
{
    return cbFSR2.fDynamicResChangeFactor;
}

fn ViewSpaceToMetersFactor() -> FfxFloat32
{
    return cbFSR2.fViewSpaceToMetersFactor;
}
#endif // #if defined(FSR2_BIND_CB_FSR2)

// WGSL: FFX_FSR2_ROOTSIG, FFX_FSR2_CB2_ROOTSIG, FFX_FSR2_REACTIVE_ROOTSIG and
// the FFX_FSR2_EMBED_*_CONTENT macros are D3D12 root signatures with no WGSL
// form; FFX_FSR2_EMBED_ROOTSIG is never defined for these passes.

#define FFX_FSR2_CONSTANT_BUFFER_2_SIZE 6           // Number of 32-bit values. This must be kept in sync with max( cbRCAS , cbSPD) size.

#define FFX_FSR2_CONSTANT_BUFFER_3_SIZE 4           // Number of 32-bit values. This must be kept in sync with cbGenerateReactive size.

#if defined(FSR2_BIND_CB_AUTOREACTIVE)
struct cbGenerateReactive_t
{
    fTcThreshold: FfxFloat32, // 0.1 is a good starting value, lower will result in more TC pixels
    fTcScale: FfxFloat32,
    fReactiveScale: FfxFloat32,
    fReactiveMax: FfxFloat32,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR2_BIND_CB_AUTOREACTIVE) var<uniform> cbGenerateReactive: cbGenerateReactive_t;

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
#endif // #if defined(FSR2_BIND_CB_AUTOREACTIVE)

#if defined(FSR2_BIND_CB_RCAS)
struct cbRCAS_t
{
    rcasConfig: FfxUInt32x4,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR2_BIND_CB_RCAS) var<uniform> cbRCAS: cbRCAS_t;

fn RCASConfig() -> FfxUInt32x4
{
    return cbRCAS.rcasConfig;
}
#endif // #if defined(FSR2_BIND_CB_RCAS)


#if defined(FSR2_BIND_CB_REACTIVE)
// The SDK names this block cbGenerateReactive too; no pass binds both.
struct cbGenerateReactive_t
{
    gen_reactive_scale: FfxFloat32,
    gen_reactive_threshold: FfxFloat32,
    gen_reactive_binaryValue: FfxFloat32,
    gen_reactive_flags: FfxUInt32,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR2_BIND_CB_REACTIVE) var<uniform> cbGenerateReactive: cbGenerateReactive_t;

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
#endif // #if defined(FSR2_BIND_CB_REACTIVE)

#if defined(FSR2_BIND_CB_SPD)
struct cbSPD_t {

    mips: FfxUInt32,
    numWorkGroups: FfxUInt32,
    workGroupOffset: FfxUInt32x2,
    renderSize: FfxUInt32x2,
}
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_CBV + FSR2_BIND_CB_SPD) var<uniform> cbSPD: cbSPD_t;

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
#endif // #if defined(FSR2_BIND_CB_SPD)

@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SAMPLER + 0) var s_PointClamp: sampler;
@group(0) @binding(FFX_WGSL_BINDING_OFFSET_SAMPLER + 1) var s_LinearClamp: sampler;

    // SRVs
    // WGSL: the unorm qualifier of the SDK's lock status, new locks, luma
    // history and dilated reactive mask SRVs does not change a sampled float
    // texture's reads.
    #if defined FSR2_BIND_SRV_INPUT_COLOR
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_INPUT_COLOR) var r_input_color_jittered: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_INPUT_OPAQUE_ONLY
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_INPUT_OPAQUE_ONLY) var r_input_opaque_only: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_INPUT_MOTION_VECTORS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_INPUT_MOTION_VECTORS) var r_input_motion_vectors: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_INPUT_DEPTH
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_INPUT_DEPTH) var r_input_depth: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_INPUT_EXPOSURE
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_INPUT_EXPOSURE) var r_input_exposure: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_AUTO_EXPOSURE
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_AUTO_EXPOSURE) var r_auto_exposure: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_REACTIVE_MASK
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_REACTIVE_MASK) var r_reactive_mask: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK) var r_transparency_and_composition_mask: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH) var r_reconstructed_previous_nearest_depth: texture_2d<FfxUInt32>;
    #endif
    #if defined FSR2_BIND_SRV_DILATED_MOTION_VECTORS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_DILATED_MOTION_VECTORS) var r_dilated_motion_vectors: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_PREVIOUS_DILATED_MOTION_VECTORS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_PREVIOUS_DILATED_MOTION_VECTORS) var r_previous_dilated_motion_vectors: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_DILATED_DEPTH
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_DILATED_DEPTH) var r_dilatedDepth: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_INTERNAL_UPSCALED
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_INTERNAL_UPSCALED) var r_internal_upscaled_color: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_LOCK_STATUS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_LOCK_STATUS) var r_lock_status: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_LOCK_INPUT_LUMA
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_LOCK_INPUT_LUMA) var r_lock_input_luma: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_NEW_LOCKS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_NEW_LOCKS) var r_new_locks: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_PREPARED_INPUT_COLOR
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_PREPARED_INPUT_COLOR) var r_prepared_input_color: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_LUMA_HISTORY
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_LUMA_HISTORY) var r_luma_history: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_RCAS_INPUT
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_RCAS_INPUT) var r_rcas_input: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_LANCZOS_LUT
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_LANCZOS_LUT) var r_lanczos_lut: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_SCENE_LUMINANCE_MIPS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_SCENE_LUMINANCE_MIPS) var r_imgMips: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_UPSCALE_MAXIMUM_BIAS_LUT
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_UPSCALE_MAXIMUM_BIAS_LUT) var r_upsample_maximum_bias_lut: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_DILATED_REACTIVE_MASKS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FSR2_BIND_SRV_DILATED_REACTIVE_MASKS) var r_dilated_reactive_masks: texture_2d<FfxFloat32>;
    #endif

    // The SDK declares these two at registers t46 and t47 (their resource
    // identifiers), not at their FSR2_BIND_* values.
    #if defined FSR2_BIND_SRV_PREV_PRE_ALPHA_COLOR
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FSR2_RESOURCE_IDENTIFIER_PREV_PRE_ALPHA_COLOR) var r_input_prev_color_pre_alpha: texture_2d<FfxFloat32>;
    #endif
    #if defined FSR2_BIND_SRV_PREV_POST_ALPHA_COLOR
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_SRV + FFX_FSR2_RESOURCE_IDENTIFIER_PREV_POST_ALPHA_COLOR) var r_input_prev_color_post_alpha: texture_2d<FfxFloat32>;
    #endif

    // UAV declarations
    // WGSL: a storage texture declares its texel format and access. Formats are
    // those of the resources ffx_fsr2.cpp creates; textures the SDK only writes
    // are write-only. globallycoherent has no WGSL form for textures (naga's
    // @coherent applies to storage buffers only), and WGSL's only texture
    // atomics are the atomic access mode.
    #if defined FSR2_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH
        // R32_UINT; InterlockedMin/InterlockedMax need the atomic access mode.
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH) var rw_reconstructed_previous_nearest_depth: texture_storage_2d<r32uint, atomic>;
    #endif
    #if defined FSR2_BIND_UAV_DILATED_MOTION_VECTORS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_DILATED_MOTION_VECTORS) var rw_dilated_motion_vectors: texture_storage_2d<rg16float, write>;
    #endif
    #if defined FSR2_BIND_UAV_DILATED_DEPTH
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_DILATED_DEPTH) var rw_dilatedDepth: texture_storage_2d<r32float, write>;
    #endif
    #if defined FSR2_BIND_UAV_INTERNAL_UPSCALED
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_INTERNAL_UPSCALED) var rw_internal_upscaled_color: texture_storage_2d<rgba16float, write>;
    #endif
    #if defined FSR2_BIND_UAV_LOCK_STATUS
        // RWTexture2D<unorm float2> on R16G16_FLOAT; the store converts to the
        // view's format, as DXC's SPIR-V does.
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_LOCK_STATUS) var rw_lock_status: texture_storage_2d<rg16float, write>;
    #endif
    #if defined FSR2_BIND_UAV_LOCK_INPUT_LUMA
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_LOCK_INPUT_LUMA) var rw_lock_input_luma: texture_storage_2d<r16float, write>;
    #endif
    #if defined FSR2_BIND_UAV_NEW_LOCKS
        // Read (LoadRwNewLocks) and written.
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_NEW_LOCKS) var rw_new_locks: texture_storage_2d<r8unorm, read_write>;
    #endif
    #if defined FSR2_BIND_UAV_PREPARED_INPUT_COLOR
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_PREPARED_INPUT_COLOR) var rw_prepared_input_color: texture_storage_2d<rgba16float, write>;
    #endif
    #if defined FSR2_BIND_UAV_LUMA_HISTORY
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_LUMA_HISTORY) var rw_luma_history: texture_storage_2d<rgba8unorm, write>;
    #endif
    #if defined FSR2_BIND_UAV_UPSCALED_OUTPUT
        // WGSL: the application's output accepts any UAV format in HLSL
        // (RWTexture2D<float4>); a WGSL storage texture needs one, so the port
        // requires an R16G16B16A16_FLOAT output.
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_UPSCALED_OUTPUT) var rw_upscaled_output: texture_storage_2d<rgba16float, write>;
    #endif
    #if defined FSR2_BIND_UAV_EXPOSURE_MIP_LUMA_CHANGE
        // globallycoherent in the SDK; mip 4 of FSR2_ExposureMips (R16_FLOAT).
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_EXPOSURE_MIP_LUMA_CHANGE) var rw_img_mip_shading_change: texture_storage_2d<r16float, read_write>;
    #endif
    #if defined FSR2_BIND_UAV_EXPOSURE_MIP_5
        // globallycoherent in the SDK; mip 5 of FSR2_ExposureMips (R16_FLOAT).
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_EXPOSURE_MIP_5) var rw_img_mip_5: texture_storage_2d<r16float, read_write>;
    #endif
    #if defined FSR2_BIND_UAV_DILATED_REACTIVE_MASKS
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_DILATED_REACTIVE_MASKS) var rw_dilated_reactive_masks: texture_storage_2d<rg8unorm, write>;
    #endif
    #if defined FSR2_BIND_UAV_EXPOSURE
        // No SDK pass binds it; R32G32_FLOAT, the SDK's exposure format.
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_EXPOSURE) var rw_exposure: texture_storage_2d<rg32float, write>;
    #endif
    #if defined FSR2_BIND_UAV_AUTO_EXPOSURE
        // FSR2_AutoExposure (R32G32_FLOAT), read (SPD_LoadExposureBuffer) and
        // written (ffx_fsr2_callbacks_hlsl.h:467, :898, :907). WGSL: Metal has
        // no read-write R32G32_FLOAT storage texture; the wgpu backend
        // allocates R32G32_FLOAT UAV resources as RGBA32Float, and the port
        // uses .xy.
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_AUTO_EXPOSURE) var rw_auto_exposure: texture_storage_2d<rgba32float, read_write>;
    #endif
    #if defined FSR2_BIND_UAV_SPD_GLOBAL_ATOMIC
        // FSR2_SpdAtomicCounter, a globallycoherent RWTexture2D<FfxUInt32> on a
        // 1x1 R32_UINT texture (ffx_fsr2_callbacks_hlsl.h:470) whose
        // InterlockedAdd returns the previous value (:949). WGSL: texture
        // atomics return nothing, so it is a one-element storage buffer, which
        // the wgpu backend allocates for a resource any pipeline binds this
        // way. Every access is atomic, which is device-coherent without
        // globallycoherent (@coherent would need MEMORY_DECORATION_COHERENT).
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_SPD_GLOBAL_ATOMIC) var<storage, read_write> rw_spd_global_atomic: array<atomic<FfxUInt32>>;
    #endif

    #if defined FSR2_BIND_UAV_AUTOREACTIVE
        // FSR2_AutoReactive, or the application's reactive mask (R8_UNORM).
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_AUTOREACTIVE) var rw_output_autoreactive: texture_storage_2d<r8unorm, write>;
    #endif
    #if defined FSR2_BIND_UAV_AUTOCOMPOSITION
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_AUTOCOMPOSITION) var rw_output_autocomposition: texture_storage_2d<r8unorm, write>;
    #endif
    #if defined FSR2_BIND_UAV_PREV_PRE_ALPHA_COLOR
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_PREV_PRE_ALPHA_COLOR) var rw_output_prev_color_pre_alpha: texture_storage_2d<rg11b10ufloat, write>;
    #endif
    #if defined FSR2_BIND_UAV_PREV_POST_ALPHA_COLOR
        @group(0) @binding(FFX_WGSL_BINDING_OFFSET_UAV + FSR2_BIND_UAV_PREV_POST_ALPHA_COLOR) var rw_output_prev_color_post_alpha: texture_storage_2d<rg11b10ufloat, write>;
    #endif

// WGSL: HLSL resource indexing returns zero outside the texture (or mip) and
// discards stores outside it; each accessor tests first (SDK-P7). A store
// writes four components; the texture keeps those its format has.

#if defined(FSR2_BIND_SRV_SCENE_LUMINANCE_MIPS)
fn LoadMipLuma(iPxPos: FfxUInt32x2, mipLevel: FfxUInt32) -> FfxFloat32
{
    let mip: FfxInt32 = FfxInt32(mipLevel);
    if (ffxWgslOutsideMip(mip, textureNumLevels(r_imgMips)) || ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_imgMips, mip))) {
        return 0.0f;
    }
    return textureLoad(r_imgMips, iPxPos, mip).x;
}
#endif

#if defined(FSR2_BIND_SRV_SCENE_LUMINANCE_MIPS)
fn SampleMipLuma(fUV: FfxFloat32x2, mipLevel: FfxUInt32) -> FfxFloat32
{
    return textureSampleLevel(r_imgMips, s_LinearClamp, fUV, FfxFloat32(mipLevel)).x;
}
#endif

#if defined(FSR2_BIND_SRV_INPUT_DEPTH)
fn LoadInputDepth(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_depth))) {
        return 0.0f;
    }
    return textureLoad(r_input_depth, iPxPos, 0).x;
}
#endif

#if defined(FSR2_BIND_SRV_INPUT_DEPTH)
fn SampleInputDepth(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_input_depth, s_LinearClamp, fUV, 0.0f).x;
}
#endif

#if defined(FSR2_BIND_SRV_REACTIVE_MASK)
fn LoadReactiveMask(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_reactive_mask))) {
        return 0.0f;
    }
    return textureLoad(r_reactive_mask, iPxPos, 0).x;
}
#endif

#if defined(FSR2_BIND_SRV_TRANSPARENCY_AND_COMPOSITION_MASK)
fn LoadTransparencyAndCompositionMask(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_transparency_and_composition_mask))) {
        return 0.0f;
    }
    return textureLoad(r_transparency_and_composition_mask, iPxPos, 0).x;
}
#endif

#if defined(FSR2_BIND_SRV_INPUT_COLOR)
fn LoadInputColor(iPxPos: FfxUInt32x2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_color_jittered))) {
        return FfxFloat32x3(0.0f);
    }
    return textureLoad(r_input_color_jittered, iPxPos, 0).rgb;
}
#endif

#if defined(FSR2_BIND_SRV_INPUT_COLOR)
fn SampleInputColor(fUV: FfxFloat32x2) -> FfxFloat32x3
{
    return textureSampleLevel(r_input_color_jittered, s_LinearClamp, fUV, 0.0f).rgb;
}
#endif

#if defined(FSR2_BIND_SRV_PREPARED_INPUT_COLOR)
fn LoadPreparedInputColor(iPxPos: FfxUInt32x2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_prepared_input_color))) {
        return FfxFloat32x3(0.0f);
    }
    return textureLoad(r_prepared_input_color, iPxPos, 0).xyz;
}

// LoadPreparedInputColorHalf: Xbox only (__XBOX_SCARLETT), never compiled here.

#endif

#if defined(FSR2_BIND_SRV_INPUT_MOTION_VECTORS)
fn LoadInputMotionVector(iPxDilatedMotionVectorPos: FfxUInt32x2) -> FfxFloat32x2
{
    var fSrcMotionVector: FfxFloat32x2 = FfxFloat32x2(0.0f);
    if (!ffxWgslOutside(FfxInt32x2(iPxDilatedMotionVectorPos), textureDimensions(r_input_motion_vectors))) {
        fSrcMotionVector = textureLoad(r_input_motion_vectors, iPxDilatedMotionVectorPos, 0).xy;
    }

    var fUvMotionVector: FfxFloat32x2 = fSrcMotionVector * MotionVectorScale();

#if FFX_FSR2_OPTION_JITTERED_MOTION_VECTORS
    fUvMotionVector -= MotionVectorJitterCancellation();
#endif

    return fUvMotionVector;
}
#endif

#if defined(FSR2_BIND_SRV_INTERNAL_UPSCALED)
fn LoadHistory(iPxHistory: FfxUInt32x2) -> FfxFloat32x4
{
    if (ffxWgslOutside(FfxInt32x2(iPxHistory), textureDimensions(r_internal_upscaled_color))) {
        return FfxFloat32x4(0.0f);
    }
    return textureLoad(r_internal_upscaled_color, iPxHistory, 0);
}
#endif

#if defined(FSR2_BIND_UAV_LUMA_HISTORY)
fn StoreLumaHistory(iPxPos: FfxUInt32x2, fLumaHistory: FfxFloat32x4)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_luma_history))) {
        return;
    }
    textureStore(rw_luma_history, iPxPos, fLumaHistory);
}
#endif

#if defined(FSR2_BIND_SRV_LUMA_HISTORY)
fn SampleLumaHistory(fUV: FfxFloat32x2) -> FfxFloat32x4
{
    return textureSampleLevel(r_luma_history, s_LinearClamp, fUV, 0.0f);
}
#endif

fn LoadRCAS_Input(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
#if defined(FSR2_BIND_SRV_RCAS_INPUT)
    if (ffxWgslOutside(iPxPos, textureDimensions(r_rcas_input))) {
        return FfxFloat32x4(0.0f);
    }
    return textureLoad(r_rcas_input, iPxPos, 0);
#else
    return FfxFloat32x4(0.0);
#endif
}

#if defined(FSR2_BIND_UAV_INTERNAL_UPSCALED)
fn StoreReprojectedHistory(iPxHistory: FfxUInt32x2, fHistory: FfxFloat32x4)
{
    if (ffxWgslOutside(FfxInt32x2(iPxHistory), textureDimensions(rw_internal_upscaled_color))) {
        return;
    }
    textureStore(rw_internal_upscaled_color, iPxHistory, fHistory);
}
#endif

#if defined(FSR2_BIND_UAV_INTERNAL_UPSCALED)
fn StoreInternalColorAndWeight(iPxPos: FfxUInt32x2, fColorAndWeight: FfxFloat32x4)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_internal_upscaled_color))) {
        return;
    }
    textureStore(rw_internal_upscaled_color, iPxPos, fColorAndWeight);
}
#endif

#if defined(FSR2_BIND_UAV_UPSCALED_OUTPUT)
fn StoreUpscaledOutput(iPxPos: FfxUInt32x2, fColor: FfxFloat32x3)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_upscaled_output))) {
        return;
    }
    textureStore(rw_upscaled_output, iPxPos, FfxFloat32x4(fColor, 1.f));
}
#endif

//LOCK_LIFETIME_REMAINING == 0
//Should make LockInitialLifetime() return a const 1.0f later
#if defined(FSR2_BIND_SRV_LOCK_STATUS)
fn LoadLockStatus(iPxPos: FfxUInt32x2) -> FfxFloat32x2
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_lock_status))) {
        return FfxFloat32x2(0.0f);
    }
    return textureLoad(r_lock_status, iPxPos, 0).xy;
}
#endif

#if defined(FSR2_BIND_UAV_LOCK_STATUS)
fn StoreLockStatus(iPxPos: FfxUInt32x2, fLockStatus: FfxFloat32x2)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_lock_status))) {
        return;
    }
    textureStore(rw_lock_status, iPxPos, FfxFloat32x4(fLockStatus, 0.0f, 0.0f));
}
#endif

#if defined(FSR2_BIND_SRV_LOCK_INPUT_LUMA)
fn LoadLockInputLuma(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_lock_input_luma))) {
        return 0.0f;
    }
    return textureLoad(r_lock_input_luma, iPxPos, 0).x;
}
#endif

#if defined(FSR2_BIND_UAV_LOCK_INPUT_LUMA)
fn StoreLockInputLuma(iPxPos: FfxUInt32x2, fLuma: FfxFloat32)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_lock_input_luma))) {
        return;
    }
    textureStore(rw_lock_input_luma, iPxPos, FfxFloat32x4(fLuma));
}
#endif

#if defined(FSR2_BIND_SRV_NEW_LOCKS)
fn LoadNewLocks(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_new_locks))) {
        return 0.0f;
    }
    return textureLoad(r_new_locks, iPxPos, 0).x;
}
#endif

#if defined(FSR2_BIND_UAV_NEW_LOCKS)
fn LoadRwNewLocks(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_new_locks))) {
        return 0.0f;
    }
    return textureLoad(rw_new_locks, iPxPos).x;
}
#endif

#if defined(FSR2_BIND_UAV_NEW_LOCKS)
fn StoreNewLocks(iPxPos: FfxUInt32x2, newLock: FfxFloat32)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_new_locks))) {
        return;
    }
    textureStore(rw_new_locks, iPxPos, FfxFloat32x4(newLock));
}
#endif

#if defined(FSR2_BIND_UAV_PREPARED_INPUT_COLOR)
fn StorePreparedInputColor(iPxPos: FfxUInt32x2, fTonemapped: FfxFloat32x4)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_prepared_input_color))) {
        return;
    }
    textureStore(rw_prepared_input_color, iPxPos, fTonemapped);
}
#endif

#if defined(FSR2_BIND_SRV_PREPARED_INPUT_COLOR)
fn SampleDepthClip(fUV: FfxFloat32x2) -> FfxFloat32
{
    return textureSampleLevel(r_prepared_input_color, s_LinearClamp, fUV, 0.0f).w;
}
#endif

#if defined(FSR2_BIND_SRV_LOCK_STATUS)
fn SampleLockStatus(fUV: FfxFloat32x2) -> FfxFloat32x2
{
    let fLockStatus: FfxFloat32x2 = textureSampleLevel(r_lock_status, s_LinearClamp, fUV, 0.0f).xy;
    return fLockStatus;
}
#endif

#if defined(FSR2_BIND_SRV_RECONSTRUCTED_PREV_NEAREST_DEPTH)
fn LoadReconstructedPrevDepth(iPxPos: FfxUInt32x2) -> FfxFloat32
{
    var uDepth: FfxUInt32 = 0u;
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_reconstructed_previous_nearest_depth))) {
        uDepth = textureLoad(r_reconstructed_previous_nearest_depth, iPxPos, 0).x;
    }
    return bitcast<FfxFloat32>(uDepth);
}
#endif

#if defined(FSR2_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH)
fn StoreReconstructedDepth(iPxSample: FfxUInt32x2, fDepth: FfxFloat32)
{
    let uDepth: FfxUInt32 = bitcast<FfxUInt32>(fDepth);

    // WGSL: an atomic outside the texture is undefined; HLSL's does nothing.
    if (ffxWgslOutside(FfxInt32x2(iPxSample), textureDimensions(rw_reconstructed_previous_nearest_depth))) {
        return;
    }
    #if FFX_FSR2_OPTION_INVERTED_DEPTH
        textureAtomicMax(rw_reconstructed_previous_nearest_depth, FfxInt32x2(iPxSample), uDepth);
    #else
        textureAtomicMin(rw_reconstructed_previous_nearest_depth, FfxInt32x2(iPxSample), uDepth); // min for standard, max for inverted depth
    #endif
}
#endif

#if defined(FSR2_BIND_UAV_RECONSTRUCTED_PREV_NEAREST_DEPTH)
fn SetReconstructedDepth(iPxSample: FfxUInt32x2, uValue: FfxUInt32)
{
    if (ffxWgslOutside(FfxInt32x2(iPxSample), textureDimensions(rw_reconstructed_previous_nearest_depth))) {
        return;
    }
    textureStore(rw_reconstructed_previous_nearest_depth, iPxSample, FfxUInt32x4(uValue));
}
#endif

#if defined(FSR2_BIND_UAV_DILATED_DEPTH)
fn StoreDilatedDepth(iPxPos: FfxUInt32x2, fDepth: FfxFloat32)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_dilatedDepth))) {
        return;
    }
    textureStore(rw_dilatedDepth, iPxPos, FfxFloat32x4(fDepth));
}
#endif

#if defined(FSR2_BIND_UAV_DILATED_MOTION_VECTORS)
fn StoreDilatedMotionVector(iPxPos: FfxUInt32x2, fMotionVector: FfxFloat32x2)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_dilated_motion_vectors))) {
        return;
    }
    textureStore(rw_dilated_motion_vectors, iPxPos, FfxFloat32x4(fMotionVector, 0.0f, 0.0f));
}
#endif

#if defined(FSR2_BIND_SRV_DILATED_MOTION_VECTORS)
fn LoadDilatedMotionVector(iPxInput: FfxUInt32x2) -> FfxFloat32x2
{
    if (ffxWgslOutside(FfxInt32x2(iPxInput), textureDimensions(r_dilated_motion_vectors))) {
        return FfxFloat32x2(0.0f);
    }
    return textureLoad(r_dilated_motion_vectors, iPxInput, 0).xy;
}
#endif

#if defined(FSR2_BIND_SRV_PREVIOUS_DILATED_MOTION_VECTORS)
fn LoadPreviousDilatedMotionVector(iPxInput: FfxUInt32x2) -> FfxFloat32x2
{
    if (ffxWgslOutside(FfxInt32x2(iPxInput), textureDimensions(r_previous_dilated_motion_vectors))) {
        return FfxFloat32x2(0.0f);
    }
    return textureLoad(r_previous_dilated_motion_vectors, iPxInput, 0).xy;
}

fn SamplePreviousDilatedMotionVector(uv: FfxFloat32x2) -> FfxFloat32x2
{
    return textureSampleLevel(r_previous_dilated_motion_vectors, s_LinearClamp, uv, 0.0f).xy;
}
#endif

#if defined(FSR2_BIND_SRV_DILATED_DEPTH)
fn LoadDilatedDepth(iPxInput: FfxUInt32x2) -> FfxFloat32
{
    if (ffxWgslOutside(FfxInt32x2(iPxInput), textureDimensions(r_dilatedDepth))) {
        return 0.0f;
    }
    return textureLoad(r_dilatedDepth, iPxInput, 0).x;
}
#endif

#if defined(FSR2_BIND_SRV_INPUT_EXPOSURE)
fn Exposure() -> FfxFloat32
{
    var exposure: FfxFloat32 = textureLoad(r_input_exposure, FfxUInt32x2(0, 0), 0).x;

    if (exposure == 0.0f) {
        exposure = 1.0f;
    }

    return exposure;
}
#endif

#if defined(FSR2_BIND_SRV_AUTO_EXPOSURE)
fn AutoExposure() -> FfxFloat32
{
    var exposure: FfxFloat32 = textureLoad(r_auto_exposure, FfxUInt32x2(0, 0), 0).x;

    if (exposure == 0.0f) {
        exposure = 1.0f;
    }

    return exposure;
}
#endif

fn SampleLanczos2Weight(x: FfxFloat32) -> FfxFloat32
{
#if defined(FSR2_BIND_SRV_LANCZOS_LUT)
    return textureSampleLevel(r_lanczos_lut, s_LinearClamp, FfxFloat32x2(x / 2, 0.5f), 0.0f).x;
#else
    return 0.f;
#endif
}

// SampleLanczos2Weight_NoValu, SampleLanczos2Weight_NoValuNoA16: Xbox only
// (__XBOX_SCARLETT), never compiled here.

#if defined(FSR2_BIND_SRV_UPSCALE_MAXIMUM_BIAS_LUT)
fn SampleUpsampleMaximumBias(uv: FfxFloat32x2) -> FfxFloat32
{
    // Stored as a SNORM, so make sure to multiply by 2 to retrieve the actual expected range.
    return FfxFloat32(2.0) * textureSampleLevel(r_upsample_maximum_bias_lut, s_LinearClamp, abs(uv) * 2.0, 0.0f).x;
}
#endif

#if defined(FSR2_BIND_SRV_DILATED_REACTIVE_MASKS)
fn SampleDilatedReactiveMasks(fUV: FfxFloat32x2) -> FfxFloat32x2
{
	return textureSampleLevel(r_dilated_reactive_masks, s_LinearClamp, fUV, 0.0f).xy;
}
#endif

#if defined(FSR2_BIND_SRV_DILATED_REACTIVE_MASKS)
fn LoadDilatedReactiveMasks(iPxPos: FfxUInt32x2) -> FfxFloat32x2
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_dilated_reactive_masks))) {
        return FfxFloat32x2(0.0f);
    }
    return textureLoad(r_dilated_reactive_masks, iPxPos, 0).xy;
}
#endif

#if defined(FSR2_BIND_UAV_DILATED_REACTIVE_MASKS)
fn StoreDilatedReactiveMasks(iPxPos: FfxUInt32x2, fDilatedReactiveMasks: FfxFloat32x2)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_dilated_reactive_masks))) {
        return;
    }
    textureStore(rw_dilated_reactive_masks, iPxPos, FfxFloat32x4(fDilatedReactiveMasks, 0.0f, 0.0f));
}
#endif

#if defined(FSR2_BIND_SRV_INPUT_OPAQUE_ONLY)
fn LoadOpaqueOnly(iPxPos: FFX_MIN16_I2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_opaque_only))) {
        return FfxFloat32x3(0.0f);
    }
    return textureLoad(r_input_opaque_only, iPxPos, 0).xyz;
}
#endif

#if defined(FSR2_BIND_SRV_PREV_PRE_ALPHA_COLOR)
fn LoadPrevPreAlpha(iPxPos: FFX_MIN16_I2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_prev_color_pre_alpha))) {
        return FfxFloat32x3(0.0f);
    }
    return textureLoad(r_input_prev_color_pre_alpha, iPxPos, 0).xyz;
}
#endif

#if defined(FSR2_BIND_SRV_PREV_POST_ALPHA_COLOR)
fn LoadPrevPostAlpha(iPxPos: FFX_MIN16_I2) -> FfxFloat32x3
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(r_input_prev_color_post_alpha))) {
        return FfxFloat32x3(0.0f);
    }
    return textureLoad(r_input_prev_color_post_alpha, iPxPos, 0).xyz;
}
#endif

#if defined(FSR2_BIND_UAV_AUTOREACTIVE)
#if defined(FSR2_BIND_UAV_AUTOCOMPOSITION)
fn StoreAutoReactive(iPxPos: FFX_MIN16_I2, fReactive: FFX_MIN16_F2)
{
    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_autoreactive))) {
        textureStore(rw_output_autoreactive, iPxPos, FfxFloat32x4(FfxFloat32(fReactive.x)));
    }

    if (!ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_autocomposition))) {
        textureStore(rw_output_autocomposition, iPxPos, FfxFloat32x4(FfxFloat32(fReactive.y)));
    }
}
#endif
#endif

#if defined(FSR2_BIND_UAV_PREV_PRE_ALPHA_COLOR)
fn StorePrevPreAlpha(iPxPos: FFX_MIN16_I2, color: FFX_MIN16_F3)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_prev_color_pre_alpha))) {
        return;
    }
    textureStore(rw_output_prev_color_pre_alpha, iPxPos, FfxFloat32x4(FfxFloat32x3(color), 0.0f));

}
#endif

#if defined(FSR2_BIND_UAV_PREV_POST_ALPHA_COLOR)
fn StorePrevPostAlpha(iPxPos: FFX_MIN16_I2, color: FFX_MIN16_F3)
{
    if (ffxWgslOutside(FfxInt32x2(iPxPos), textureDimensions(rw_output_prev_color_post_alpha))) {
        return;
    }
    textureStore(rw_output_prev_color_post_alpha, iPxPos, FfxFloat32x4(FfxFloat32x3(color), 0.0f));
}
#endif

fn SPD_LoadExposureBuffer() -> FfxFloat32x2
{
#if defined FSR2_BIND_UAV_AUTO_EXPOSURE
    return textureLoad(rw_auto_exposure, FfxInt32x2(0, 0)).xy;
#else
    return FfxFloat32x2(0.f, 0.f);
#endif // #if defined FSR2_BIND_UAV_AUTO_EXPOSURE
}

fn SPD_SetExposureBuffer(value: FfxFloat32x2)
{
#if defined FSR2_BIND_UAV_AUTO_EXPOSURE
    textureStore(rw_auto_exposure, FfxInt32x2(0, 0), FfxFloat32x4(value, 0.0f, 0.0f));
#endif // #if defined FSR2_BIND_UAV_AUTO_EXPOSURE
}

fn SPD_LoadMipmap5(iPxPos: FfxInt32x2) -> FfxFloat32x4
{
#if defined FSR2_BIND_UAV_EXPOSURE_MIP_5
    var value: FfxFloat32 = 0.0f;
    if (!ffxWgslOutside(iPxPos, textureDimensions(rw_img_mip_5))) {
        value = textureLoad(rw_img_mip_5, iPxPos).x;
    }
    return FfxFloat32x4(value, 0, 0, 0);
#else
    return FfxFloat32x4(0.f, 0.f, 0.f, 0.f);
#endif // #if defined FSR2_BIND_UAV_EXPOSURE_MIP_5
}

fn SPD_SetMipmap(iPxPos: FfxInt32x2, slice: FfxUInt32, value: FfxFloat32)
{
    switch (slice)
    {
    case FFX_FSR2_SHADING_CHANGE_MIP_LEVEL: {
#if defined FSR2_BIND_UAV_EXPOSURE_MIP_LUMA_CHANGE
        if (!ffxWgslOutside(iPxPos, textureDimensions(rw_img_mip_shading_change))) {
            textureStore(rw_img_mip_shading_change, iPxPos, FfxFloat32x4(value));
        }
#endif // #if defined FSR2_BIND_UAV_EXPOSURE_MIP_LUMA_CHANGE
    }
    case 5u: {
#if defined FSR2_BIND_UAV_EXPOSURE_MIP_5
        if (!ffxWgslOutside(iPxPos, textureDimensions(rw_img_mip_5))) {
            textureStore(rw_img_mip_5, iPxPos, FfxFloat32x4(value));
        }
#endif // #if defined FSR2_BIND_UAV_EXPOSURE_MIP_5
    }
    default: {

        // avoid flattened side effect
#if defined(FSR2_BIND_UAV_EXPOSURE_MIP_LUMA_CHANGE)
        if (!ffxWgslOutside(iPxPos, textureDimensions(rw_img_mip_shading_change))) {
            textureStore(rw_img_mip_shading_change, iPxPos, textureLoad(rw_img_mip_shading_change, iPxPos));
        }
#elif defined(FSR2_BIND_UAV_EXPOSURE_MIP_5)
        if (!ffxWgslOutside(iPxPos, textureDimensions(rw_img_mip_5))) {
            textureStore(rw_img_mip_5, iPxPos, textureLoad(rw_img_mip_5, iPxPos));
        }
#endif // #if defined FSR2_BIND_UAV_EXPOSURE_MIP_5
    }
    }
}

// WGSL: texel (0, 0) of the SDK's 1x1 texture is element 0 of the buffer,
// which wgpu binds with at least one element.
fn SPD_IncreaseAtomicCounter(spdCounter: ptr<function, FfxUInt32>)
{
#if defined FSR2_BIND_UAV_SPD_GLOBAL_ATOMIC
    *spdCounter = atomicAdd(&rw_spd_global_atomic[0], 1u);
#endif // #if defined FSR2_BIND_UAV_SPD_GLOBAL_ATOMIC
}

fn SPD_ResetAtomicCounter()
{
#if defined FSR2_BIND_UAV_SPD_GLOBAL_ATOMIC
    atomicStore(&rw_spd_global_atomic[0], 0u);
#endif // #if defined FSR2_BIND_UAV_SPD_GLOBAL_ATOMIC
}

#endif // #if defined(FFX_GPU)
