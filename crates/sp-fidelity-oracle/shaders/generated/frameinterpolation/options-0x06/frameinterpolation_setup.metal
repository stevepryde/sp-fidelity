#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

template<typename T, access A>
void sdk_hlsl_store(texture2d<T, A> tex, vec<T, 4> value, uint2 p) {
    if (p.x >= tex.get_width() || p.y >= tex.get_height()) return;
    tex.write(value, p);
}
template<typename T>
vec<T, 4> sdk_hlsl_load(texture2d<T, access::sample> tex, uint2 p, uint mip = 0u) {
    if (mip >= tex.get_num_mip_levels()) return vec<T, 4>(T(0));
    if (p.x >= tex.get_width(mip) || p.y >= tex.get_height(mip)) return vec<T, 4>(T(0));
    return tex.read(p, mip);
}
template<typename T>
vec<T, 4> sdk_hlsl_load(texture2d<T, access::read_write> tex, uint2 p) {
    if (p.x >= tex.get_width() || p.y >= tex.get_height()) return vec<T, 4>(T(0));
    return tex.read(p);
}


struct type_cbFI
{
    int2 renderSize;
    int2 displaySize;
    float2 displaySizeRcp;
    float cameraNear;
    float cameraFar;
    int2 upscalerTargetSize;
    int Mode;
    int reset;
    float4 fDeviceToViewDepth;
    float deltaTime;
    int HUDLessAttachedFactor;
    int2 distortionFieldSize;
    float2 opticalFlowScale;
    int opticalFlowBlockSize;
    uint dispatchFlags;
    int2 maxRenderSize;
    int opticalFlowHalfResMode;
    int NumInstances;
    int2 interpolationRectBase;
    int2 interpolationRectSize;
    packed_float3 debugBarColor;
    uint backBufferTransferFunction;
    float2 minMaxLuminance;
    float fTanHalfFOV;
    int _pad1;
    float2 fJitter;
    float2 fMotionVectorScale;
};

struct type_RWStructuredBuffer_uint
{
    uint _m0[1];
};

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], volatile device type_RWStructuredBuffer_uint& rw_counters [[buffer(1)]], texture2d<uint> r_optical_flow_scd [[texture(0)]], texture2d<float, access::write> rw_disocclusion_mask [[texture(1)]], texture2d<uint, access::write> rw_game_motion_vector_field_x [[texture(2)]], texture2d<uint, access::write> rw_game_motion_vector_field_y [[texture(3)]], texture2d<uint, access::write> rw_optical_flow_motion_vector_field_x [[texture(4)]], texture2d<uint, access::write> rw_optical_flow_motion_vector_field_y [[texture(5)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    rw_counters._m0[0u] = 0u;
    if (all(int3(gl_GlobalInvocationID).xy == int2(0)))
    {
        bool _68;
        if (cbFI.reset != 1)
        {
            _68 = (sdk_hlsl_load(r_optical_flow_scd, uint2(uint2(1u, 0u)), 0u).x & 15u) != 0u;
        }
        else
        {
            _68 = true;
        }
        if (_68)
        {
            rw_counters._m0[1u] = 0u;
        }
        else
        {
            rw_counters._m0[1u]++;
        }
    }
    uint2 _76 = uint2(int3(gl_GlobalInvocationID).xy);
    sdk_hlsl_store(rw_game_motion_vector_field_x, uint4(0u), uint2(_76));
    sdk_hlsl_store(rw_game_motion_vector_field_y, uint4(0u), uint2(_76));
    sdk_hlsl_store(rw_optical_flow_motion_vector_field_x, uint4(0u), uint2(_76));
    sdk_hlsl_store(rw_optical_flow_motion_vector_field_y, uint4(0u), uint2(_76));
    sdk_hlsl_store(rw_disocclusion_mask, float2(0.0).xyyy, uint2(_76));
}

