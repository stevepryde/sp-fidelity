//! Port of `sdk/include/FidelityFX/host/ffx_types.h` (FidelityFX SDK 1.1.4).
//!
//! Only the declarations used by the ported effects and their backend
//! interface are ported. C enums used as values become Rust enums with
//! the `FFX_<TYPE>_` prefix removed; C enums used as bit sets keep the SDK
//! constant names over the SDK integer type. `void*` handles (`FfxDevice`,
//! `FfxCommandList`, …) are opaque backend-defined `usize` values where `0` is
//! `NULL`; `wchar_t` names are `String`/`&'static str`.

pub const FFX_SDK_DEFAULT_CONTEXT_SIZE: u32 = 1024 * 128;
pub const FFX_MAX_NUM_SRVS: usize = 64;
pub const FFX_MAX_NUM_UAVS: usize = 64;
pub const FFX_MAX_NUM_CONST_BUFFERS: usize = 3;
pub const FFX_RESOURCE_NAME_SIZE: usize = 64;

pub type FfxVersionNumber = u32;
pub type FfxBoolean = bool;
pub type FfxUInt8 = u8;
pub type FfxUInt16 = u16;
pub type FfxUInt32 = u32;
pub type FfxUInt64 = u64;
pub type FfxInt8 = i8;
pub type FfxInt16 = i16;
pub type FfxInt32 = i32;
pub type FfxInt64 = i64;
pub type FfxFloat32 = f32;
pub type FfxFloat32x2 = [f32; 2];
pub type FfxFloat32x3 = [f32; 3];
pub type FfxFloat32x4 = [f32; 4];
pub type FfxFloat32x4x4 = [f32; 16];
pub type FfxUInt32x2 = [u32; 2];
pub type FfxUInt32x3 = [u32; 3];
pub type FfxUInt32x4 = [u32; 4];
pub type FfxInt32x2 = [i32; 2];
pub type FfxInt32x3 = [i32; 3];
pub type FfxInt32x4 = [i32; 4];

/// `FfxSurfaceFormat`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum FfxSurfaceFormat {
    #[default]
    Unknown,
    R32G32B32A32Typeless,
    R32G32B32A32Uint,
    R32G32B32A32Float,
    R16G16B16A16Float,
    R32G32B32Float,
    R32G32Float,
    R8Uint,
    R32Uint,
    R8G8B8A8Typeless,
    R8G8B8A8Unorm,
    R8G8B8A8Snorm,
    R8G8B8A8Srgb,
    B8G8R8A8Typeless,
    B8G8R8A8Unorm,
    B8G8R8A8Srgb,
    R11G11B10Float,
    R10G10B10A2Unorm,
    R16G16Float,
    R16G16Uint,
    R16G16Sint,
    R16Float,
    R16Uint,
    R16Unorm,
    R16Snorm,
    R8Unorm,
    R8G8Unorm,
    R8G8Uint,
    R32Float,
    R9G9B9E5Sharedexp,
    R16G16B16A16Typeless,
    R32G32Typeless,
    R10G10B10A2Typeless,
    R16G16Typeless,
    R16Typeless,
    R8Typeless,
    R8G8Typeless,
    R32Typeless,
}

/// `FfxResourceUsage` bit set.
pub type FfxResourceUsage = u32;
pub const FFX_RESOURCE_USAGE_READ_ONLY: FfxResourceUsage = 0;
pub const FFX_RESOURCE_USAGE_RENDERTARGET: FfxResourceUsage = 1 << 0;
pub const FFX_RESOURCE_USAGE_UAV: FfxResourceUsage = 1 << 1;
pub const FFX_RESOURCE_USAGE_DEPTHTARGET: FfxResourceUsage = 1 << 2;
pub const FFX_RESOURCE_USAGE_INDIRECT: FfxResourceUsage = 1 << 3;
pub const FFX_RESOURCE_USAGE_ARRAYVIEW: FfxResourceUsage = 1 << 4;
pub const FFX_RESOURCE_USAGE_STENCILTARGET: FfxResourceUsage = 1 << 5;
pub const FFX_RESOURCE_USAGE_DCC_RENDERTARGET: FfxResourceUsage = 1 << 15;

/// `FfxResourceStates` bit set.
pub type FfxResourceStates = u32;
pub const FFX_RESOURCE_STATE_COMMON: FfxResourceStates = 1 << 0;
pub const FFX_RESOURCE_STATE_UNORDERED_ACCESS: FfxResourceStates = 1 << 1;
pub const FFX_RESOURCE_STATE_COMPUTE_READ: FfxResourceStates = 1 << 2;
pub const FFX_RESOURCE_STATE_PIXEL_READ: FfxResourceStates = 1 << 3;
pub const FFX_RESOURCE_STATE_PIXEL_COMPUTE_READ: FfxResourceStates =
    FFX_RESOURCE_STATE_PIXEL_READ | FFX_RESOURCE_STATE_COMPUTE_READ;
pub const FFX_RESOURCE_STATE_COPY_SRC: FfxResourceStates = 1 << 4;
pub const FFX_RESOURCE_STATE_COPY_DEST: FfxResourceStates = 1 << 5;
pub const FFX_RESOURCE_STATE_GENERIC_READ: FfxResourceStates =
    FFX_RESOURCE_STATE_COPY_SRC | FFX_RESOURCE_STATE_COMPUTE_READ;
pub const FFX_RESOURCE_STATE_INDIRECT_ARGUMENT: FfxResourceStates = 1 << 6;
pub const FFX_RESOURCE_STATE_PRESENT: FfxResourceStates = 1 << 7;
pub const FFX_RESOURCE_STATE_RENDER_TARGET: FfxResourceStates = 1 << 8;
pub const FFX_RESOURCE_STATE_DEPTH_ATTACHEMENT: FfxResourceStates = 1 << 9;

/// `FfxResourceFlags` bit set.
pub type FfxResourceFlags = u32;
pub const FFX_RESOURCE_FLAGS_NONE: FfxResourceFlags = 0;
pub const FFX_RESOURCE_FLAGS_ALIASABLE: FfxResourceFlags = 1 << 0;
pub const FFX_RESOURCE_FLAGS_UNDEFINED: FfxResourceFlags = 1 << 1;

/// `FfxFilterType`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum FfxFilterType {
    #[default]
    MinMagMipPoint,
    MinMagMipLinear,
    MinMagLinearMipPoint,
}

/// `FfxAddressMode`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum FfxAddressMode {
    #[default]
    Wrap,
    Mirror,
    Clamp,
    Border,
    MirrorOnce,
}

/// `FfxShaderModel`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum FfxShaderModel {
    #[default]
    ShaderModel5_1,
    ShaderModel6_0,
    ShaderModel6_1,
    ShaderModel6_2,
    ShaderModel6_3,
    ShaderModel6_4,
    ShaderModel6_5,
    ShaderModel6_6,
    ShaderModel6_7,
}

/// `FfxResourceType`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum FfxResourceType {
    #[default]
    Buffer,
    Texture1D,
    Texture2D,
    TextureCube,
    Texture3D,
}

/// `FfxHeapType`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum FfxHeapType {
    #[default]
    Default = 0,
    Upload,
    Readback,
}

/// `FfxGpuJobType`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxGpuJobType {
    ClearFloat = 0,
    Copy = 1,
    Compute = 2,
    Barrier = 3,
    Discard = 4,
}

/// `FfxBindStage` bit set.
pub type FfxBindStage = u32;
pub const FFX_BIND_PIXEL_SHADER_STAGE: FfxBindStage = 1 << 0;
pub const FFX_BIND_VERTEX_SHADER_STAGE: FfxBindStage = 1 << 1;
pub const FFX_BIND_COMPUTE_SHADER_STAGE: FfxBindStage = 1 << 2;

/// `ffxMessageCallback`: receives a message's `FfxMsgType` and text.
pub type FfxMessageCallback = fn(message_type: u32, message: &str);

/// `FfxMsgType`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxMsgType {
    Error = 0,
    Warning = 1,
    Count,
}

/// `FfxEffect`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FfxEffect {
    Fsr2 = 0,
    Fsr1,
    Spd,
    Blur,
    Breadcrumbs,
    Brixelizer,
    BrixelizerGi,
    Cacao,
    Cas,
    Denoiser,
    Lens,
    ParallelSort,
    Sssr,
    VariableShading,
    Lpm,
    Dof,
    Classifier,
    Fsr3Upscaler,
    FrameInterpolation,
    OpticalFlow,
    SharedResources = 127,
    SharedApiBackend = 128,
}

/// `FfxDevice` (`void*`): opaque backend handle, `0` is `NULL`.
pub type FfxDevice = usize;
/// `FfxCommandList` (`void*`): opaque backend handle, `0` is `NULL`.
pub type FfxCommandList = usize;
/// `FfxRootSignature` (`void*`): opaque backend handle, `0` is `NULL`.
pub type FfxRootSignature = usize;
/// `FfxCommandSignature` (`void*`): opaque backend handle, `0` is `NULL`.
pub type FfxCommandSignature = usize;
/// `FfxPipeline` (`void*`): opaque backend handle, `0` is `NULL`.
pub type FfxPipeline = usize;

/// `FfxEffectBindlessConfig`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxEffectBindlessConfig {
    pub max_texture_srvs: u32,
    pub max_buffer_srvs: u32,
    pub max_texture_uavs: u32,
    pub max_buffer_uavs: u32,
}

/// `FfxDeviceCapabilities`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxDeviceCapabilities {
    pub maximum_supported_shader_model: FfxShaderModel,
    pub wave_lane_count_min: u32,
    pub wave_lane_count_max: u32,
    pub fp16_supported: bool,
    pub raytracing_supported: bool,
    pub device_coherent_memory_supported: bool,
    pub dedicated_allocation_supported: bool,
    pub buffer_marker_supported: bool,
    pub extended_synchronization_supported: bool,
    pub shader_storage_buffer_array_non_uniform_indexing: bool,
}

/// `FfxDimensions2D`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxDimensions2D {
    pub width: u32,
    pub height: u32,
}

/// `FfxFloatCoords2D`.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct FfxFloatCoords2D {
    pub x: f32,
    pub y: f32,
}

/// `FfxResourceDescription`. The C unions are kept under their texture
/// names: `width` is a buffer's `size`, `height` its `stride` and `depth` its
/// `alignment`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxResourceDescription {
    pub r#type: FfxResourceType,
    pub format: FfxSurfaceFormat,
    pub width: u32,
    pub height: u32,
    pub depth: u32,
    pub mip_count: u32,
    pub flags: FfxResourceFlags,
    pub usage: FfxResourceUsage,
}

/// `FfxResource`. `resource` is the backend's opaque `void*` handle.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct FfxResource {
    pub resource: usize,
    pub description: FfxResourceDescription,
    pub state: FfxResourceStates,
    pub name: String,
}

/// `FfxResourceInternal`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct FfxResourceInternal {
    pub internal_index: i32,
}

/// `FfxResourceInitDataType`.
#[repr(u32)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub enum FfxResourceInitDataType {
    #[default]
    Invalid = 0,
    Uninitialized,
    Buffer,
    Value,
}

/// `FfxResourceInitData`. The C union of `buffer` and `value` is kept as two
/// fields; `buffer` is empty where C holds `NULL`. Like the C pointer, the
/// buffer only needs to outlive the call that receives it.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxResourceInitData<'a> {
    pub r#type: FfxResourceInitDataType,
    pub size: usize,
    pub buffer: &'a [u8],
    pub value: u8,
}

impl<'a> FfxResourceInitData<'a> {
    /// `FfxResourceInitData::FfxResourceInitValue`.
    pub fn ffx_resource_init_value(data_size: usize, init_val: u8) -> Self {
        Self {
            r#type: FfxResourceInitDataType::Value,
            size: data_size,
            buffer: &[],
            value: init_val,
        }
    }

    /// `FfxResourceInitData::FfxResourceInitBuffer`.
    pub fn ffx_resource_init_buffer(data_size: usize, init_data: &'a [u8]) -> Self {
        Self {
            r#type: FfxResourceInitDataType::Buffer,
            size: data_size,
            buffer: init_data,
            value: 0,
        }
    }
}

/// `FfxInternalResourceDescription`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FfxInternalResourceDescription<'a> {
    pub id: u32,
    pub name: &'static str,
    pub r#type: FfxResourceType,
    pub usage: FfxResourceUsage,
    pub format: FfxSurfaceFormat,
    pub width: u32,
    pub height: u32,
    pub mip_count: u32,
    pub flags: FfxResourceFlags,
    pub init_data: FfxResourceInitData<'a>,
}

/// `FfxResourceBinding`.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct FfxResourceBinding {
    pub slot_index: u32,
    pub array_index: u32,
    pub resource_identifier: u32,
    pub name: String,
}

/// `FfxPipelineState`. The fixed binding arrays and their counts become
/// vectors (`srvTextureCount` is `srv_texture_bindings.len()`, …).
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct FfxPipelineState {
    pub root_signature: FfxRootSignature,
    pub pass_id: u32,
    pub cmd_signature: FfxCommandSignature,
    pub pipeline: FfxPipeline,
    pub static_texture_srv_count: u32,
    pub static_buffer_srv_count: u32,
    pub static_texture_uav_count: u32,
    pub static_buffer_uav_count: u32,
    pub uav_texture_bindings: Vec<FfxResourceBinding>,
    pub srv_texture_bindings: Vec<FfxResourceBinding>,
    pub srv_buffer_bindings: Vec<FfxResourceBinding>,
    pub uav_buffer_bindings: Vec<FfxResourceBinding>,
    pub constant_buffer_bindings: Vec<FfxResourceBinding>,
    pub name: String,
}

/// `FfxCreateResourceDescription`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FfxCreateResourceDescription<'a> {
    pub heap_type: FfxHeapType,
    pub resource_description: FfxResourceDescription,
    pub initial_state: FfxResourceStates,
    pub name: &'static str,
    pub id: u32,
    pub init_data: FfxResourceInitData<'a>,
}

/// `FfxSamplerDescription`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FfxSamplerDescription {
    pub filter: FfxFilterType,
    pub address_mode_u: FfxAddressMode,
    pub address_mode_v: FfxAddressMode,
    pub address_mode_w: FfxAddressMode,
    pub stage: FfxBindStage,
}

/// `FfxRootConstantDescription`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct FfxRootConstantDescription {
    pub size: u32,
    pub stage: FfxBindStage,
}

/// `FfxPipelineDescription`. The `samplers`/`samplerCount` and
/// `rootConstants`/`rootConstantBufferCount` pointer pairs are slices.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FfxPipelineDescription<'a> {
    pub context_flags: u32,
    pub samplers: &'a [FfxSamplerDescription],
    pub root_constants: &'a [FfxRootConstantDescription],
    pub name: String,
    pub stage: FfxBindStage,
    pub indirect_workload: u32,
    pub backbuffer_format: FfxSurfaceFormat,
}

/// `FfxConstantBuffer`. `data` holds the staged 32-bit words that C points to.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct FfxConstantBuffer {
    pub num_32bit_entries: u32,
    pub data: Vec<u32>,
}

/// `FfxTextureSRV` (the `FFX_DEBUG` name is not ported).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxTextureSRV {
    pub resource: FfxResourceInternal,
}

/// `FfxBufferSRV` (the `FFX_DEBUG` name is not ported).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxBufferSRV {
    pub offset: u32,
    pub size: u32,
    pub stride: u32,
    pub resource: FfxResourceInternal,
}

/// `FfxTextureUAV` (the `FFX_DEBUG` name is not ported).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxTextureUAV {
    pub mip: u32,
    pub resource: FfxResourceInternal,
}

/// `FfxBufferUAV` (the `FFX_DEBUG` name is not ported).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxBufferUAV {
    pub offset: u32,
    pub size: u32,
    pub stride: u32,
    pub resource: FfxResourceInternal,
}

/// `FfxClearFloatJobDescription`.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct FfxClearFloatJobDescription {
    pub color: [f32; 4],
    pub target: FfxResourceInternal,
}

/// `FfxComputeJobDescription`. The fixed resource arrays become vectors sized
/// by the pipeline's binding counts.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct FfxComputeJobDescription {
    pub pipeline: FfxPipelineState,
    pub dimensions: [u32; 3],
    pub cmd_argument: FfxResourceInternal,
    pub cmd_argument_offset: u32,
    pub srv_textures: Vec<FfxTextureSRV>,
    pub srv_buffers: Vec<FfxBufferSRV>,
    pub uav_textures: Vec<FfxTextureUAV>,
    pub uav_buffers: Vec<FfxBufferUAV>,
    pub cbs: Vec<FfxConstantBuffer>,
}

/// `FfxCopyJobDescription`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxCopyJobDescription {
    pub src: FfxResourceInternal,
    pub src_offset: u32,
    pub dst: FfxResourceInternal,
    pub dst_offset: u32,
    pub size: u32,
}

/// The union in `FfxGpuJobDescription`, tagged by `jobType`. Only the clear,
/// copy and compute jobs are ported.
#[derive(Clone, Debug, PartialEq)]
pub enum FfxGpuJobDescriptor {
    ClearFloat(FfxClearFloatJobDescription),
    Copy(FfxCopyJobDescription),
    Compute(Box<FfxComputeJobDescription>),
}

/// `FfxGpuJobDescription`.
#[derive(Clone, Debug, PartialEq)]
pub struct FfxGpuJobDescription {
    pub job_label: String,
    pub descriptor: FfxGpuJobDescriptor,
}

impl FfxGpuJobDescription {
    /// `jobType`.
    pub fn job_type(&self) -> FfxGpuJobType {
        match self.descriptor {
            FfxGpuJobDescriptor::ClearFloat(_) => FfxGpuJobType::ClearFloat,
            FfxGpuJobDescriptor::Copy(_) => FfxGpuJobType::Copy,
            FfxGpuJobDescriptor::Compute(_) => FfxGpuJobType::Compute,
        }
    }
}

/// One entry of an `FfxShaderBlob` binding table: the parallel
/// `bound*Names`, `bound*`, `bound*Counts` and `bound*Spaces` arrays.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct FfxShaderBlobBinding {
    pub name: &'static str,
    pub binding: u32,
    pub count: u32,
    pub space: u32,
}

/// The permutation a blob accessor selected from the SDK permutation flags:
/// its `isWave64`/`is16bit` table and the pass `PermutationKey`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct FfxShaderPermutation {
    pub wave64: bool,
    pub fp16: bool,
    /// `PermutationKey::index`: bit `i` is the value of `key_options[i]`.
    pub key_index: u32,
    /// The `PermutationKey` bit fields in order: the effect's
    /// `FFX_<EFFECT>_OPTION_*` compile defines.
    pub key_options: &'static [&'static str],
}

/// `FfxShaderBlob`. The SDK's `data`/`size` bytecode is replaced by the
/// selected pass and permutation; the WGSL source for
/// (`shader_name`, `permutation`) is `shaders::ffx_get_wgsl_source`.
/// `Default` is the SDK's empty (`memset` zero) blob.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxShaderBlob {
    /// SDK pass shader stem, e.g. `ffx_fsr2_rcas_pass`.
    pub shader_name: &'static str,
    pub permutation: FfxShaderPermutation,
    pub bound_constant_buffers: &'static [FfxShaderBlobBinding],
    pub bound_srv_textures: &'static [FfxShaderBlobBinding],
    pub bound_uav_textures: &'static [FfxShaderBlobBinding],
    pub bound_srv_buffers: &'static [FfxShaderBlobBinding],
    pub bound_uav_buffers: &'static [FfxShaderBlobBinding],
    pub bound_samplers: &'static [FfxShaderBlobBinding],
}

/// `FfxEffectMemoryUsage`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct FfxEffectMemoryUsage {
    pub total_usage_in_bytes: u64,
    pub aliasable_usage_in_bytes: u64,
}
