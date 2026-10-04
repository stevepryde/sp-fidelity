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
    uint2 _47 = (gl_WorkGroupID.xy * uint2(8u)) + gl_LocalInvocationID.xy;
    float4 _49 = sdk_hlsl_load(r_input_opaque_only, uint2(_47), 0u);
    float3 _50 = _49.xyz;
    float4 _52 = sdk_hlsl_load(r_input_color_jittered, uint2(_47), 0u);
    float3 _53 = _52.xyz;
    float3 _78;
    float3 _79;
    if ((cbGenerateReactive.gen_reactive_flags & 1u) != 0u)
    {
        _78 = _53 / float3(precise::max(precise::max(0.0, _52.x), precise::max(_52.y, _52.z)) + 1.0);
        _79 = _50 / float3(precise::max(precise::max(0.0, _49.x), precise::max(_49.y, _49.z)) + 1.0);
    }
    else
    {
        _78 = _53;
        _79 = _50;
    }
    float3 _102;
    float3 _103;
    if ((cbGenerateReactive.gen_reactive_flags & 2u) != 0u)
    {
        _102 = _79 / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_79.x, precise::max(_79.y, _79.z))));
        _103 = _78 / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_78.x, precise::max(_78.y, _78.z))));
    }
    else
    {
        _102 = _79;
        _103 = _78;
    }
    float3 _105 = abs(_103 - _102);
    float _117;
    if ((cbGenerateReactive.gen_reactive_flags & 8u) != 0u)
    {
        _117 = precise::max(_105.x, precise::max(_105.y, _105.z));
    }
    else
    {
        _117 = length(_105);
    }
    float _120 = _117 * cbGenerateReactive.gen_reactive_scale;
    float _135;
    if ((cbGenerateReactive.gen_reactive_flags & 4u) != 0u)
    {
        float _134;
        if (_120 < cbGenerateReactive.gen_reactive_threshold)
        {
            _134 = 0.0;
        }
        else
        {
            _134 = cbGenerateReactive.gen_reactive_binaryValue;
        }
        _135 = _134;
    }
    else
    {
        _135 = _120;
    }
    sdk_hlsl_store(rw_output_autoreactive, float4(_135), uint2(_47));
}

