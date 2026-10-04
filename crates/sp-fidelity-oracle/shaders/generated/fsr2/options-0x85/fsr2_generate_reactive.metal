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


struct type_cbGenerateReactive
{
    float gen_reactive_scale;
    float gen_reactive_threshold;
    float gen_reactive_binaryValue;
    uint gen_reactive_flags;
};

kernel void main0(constant type_cbGenerateReactive& cbGenerateReactive [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_opaque_only [[texture(1)]], texture2d<float, access::write> rw_output_autoreactive [[texture(2)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _52 = (gl_WorkGroupID.xy * uint2(8u)) + gl_LocalInvocationID.xy;
    float4 _58 = sdk_hlsl_load(r_input_opaque_only, uint2(uint2(int2(short2(ushort2(_52))))), 0u);
    float3 _59 = _58.xyz;
    float4 _61 = sdk_hlsl_load(r_input_color_jittered, uint2(_52), 0u);
    float3 _62 = _61.xyz;
    float3 _87;
    float3 _88;
    if ((cbGenerateReactive.gen_reactive_flags & 1u) != 0u)
    {
        _87 = _62 / float3(precise::max(precise::max(0.0, _61.x), precise::max(_61.y, _61.z)) + 1.0);
        _88 = _59 / float3(precise::max(precise::max(0.0, _58.x), precise::max(_58.y, _58.z)) + 1.0);
    }
    else
    {
        _87 = _62;
        _88 = _59;
    }
    float3 _111;
    float3 _112;
    if ((cbGenerateReactive.gen_reactive_flags & 2u) != 0u)
    {
        _111 = _88 / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_88.x, precise::max(_88.y, _88.z))));
        _112 = _87 / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_87.x, precise::max(_87.y, _87.z))));
    }
    else
    {
        _111 = _88;
        _112 = _87;
    }
    float3 _114 = abs(_112 - _111);
    float _126;
    if ((cbGenerateReactive.gen_reactive_flags & 8u) != 0u)
    {
        _126 = precise::max(_114.x, precise::max(_114.y, _114.z));
    }
    else
    {
        _126 = length(_114);
    }
    float _129 = _126 * cbGenerateReactive.gen_reactive_scale;
    float _144;
    if ((cbGenerateReactive.gen_reactive_flags & 4u) != 0u)
    {
        float _143;
        if (_129 < cbGenerateReactive.gen_reactive_threshold)
        {
            _143 = 0.0;
        }
        else
        {
            _143 = cbGenerateReactive.gen_reactive_binaryValue;
        }
        _144 = _143;
    }
    else
    {
        _144 = _129;
    }
    sdk_hlsl_store(rw_output_autoreactive, float4(_144), uint2(_52));
}

