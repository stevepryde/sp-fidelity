#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

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


template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

struct type_cbDenoiserReflections
{
    float4x4 invProjection;
    float4x4 invView;
    float4x4 prevViewProjection;
    uint2 renderSize;
    float2 inverseRenderSize;
    float2 motionVectorScale;
    float normalsUnpackMul;
    float normalsUnpackAdd;
    uint isRoughnessPerceptual;
    float temporalStabilityFactor;
    float roughnessThreshold;
};

struct type_RWStructuredBuffer_uint
{
    uint _m0[1];
};

constant float _139 = {};

constant spvUnsafeArray<int2, 4> _134 = spvUnsafeArray<int2, 4>({ int2(0), int2(8, 0), int2(0, 8), int2(8) });
constant spvUnsafeArray<int2, 15> _135 = spvUnsafeArray<int2, 15>({ int2(0, 1), int2(-2, 1), int2(2, -3), int2(-3, 0), int2(1, 2), int2(-1, -2), int2(3, 0), int2(-3, 3), int2(0, -3), int2(-1), int2(2, 1), int2(-2), int2(1, 0), int2(0, 2), int2(3, -1) });

kernel void main0(constant type_cbDenoiserReflections& cbDenoiserReflections [[buffer(0)]], const device type_RWStructuredBuffer_uint& rw_denoiser_tile_list [[buffer(1)]], texture2d<float> r_input_depth_hierarchy [[texture(0)]], texture2d<float> r_input_normal [[texture(1)]], texture2d<float> r_radiance [[texture(2)]], texture2d<float> r_variance [[texture(3)]], texture2d<float> r_average_radiance [[texture(4)]], texture2d<float> r_extracted_roughness [[texture(5)]], texture2d<float, access::write> rw_radiance [[texture(6)]], texture2d<float, access::write> rw_variance [[texture(7)]], sampler s_LinearSampler [[sampler(0)]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_0;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_1;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_2;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_3;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> g_ffx_dnsr_shared_depth;
    uint _153 = rw_denoiser_tile_list._m0[gl_WorkGroupID.x];
    int2 _172 = int2(uint2((gl_LocalInvocationIndex & 1u) | ((gl_LocalInvocationIndex >> 2u) & 6u), ((gl_LocalInvocationIndex >> 1u) & 3u) | ((gl_LocalInvocationIndex >> 3u) & 4u)));
    int2 _174 = (((int2(int(_153 & 65535u), int((_153 >> 16u) & 65535u)) + int3(gl_LocalInvocationID).xy) / int2(8)) * int2(8)) + _172;
    float4 _182 = sdk_hlsl_load(r_extracted_roughness, uint2(int3(_174, 0).xy), 0);
    float _183 = _182.x;
    float _190;
    if (cbDenoiserReflections.isRoughnessPerceptual != 0u)
    {
        _190 = _183 * _183;
    }
    else
    {
        _190 = _183;
    }
    int2 _191 = int2(cbDenoiserReflections.renderSize);
    int2 _192 = _174 - int2(4);
    spvUnsafeArray<float3, 4> _143;
    spvUnsafeArray<float, 4> _144;
    spvUnsafeArray<float3, 4> _145;
    spvUnsafeArray<float, 4> _146;
    for (int _194 = 0; _194 < 4; )
    {
        int2 _201 = _192 + _134[_194];
        int2 _209 = int3(_201, 0).xy;
        _143[_194] = sdk_hlsl_load(r_radiance, uint2(_209), 0).xyz;
        _144[_194] = sdk_hlsl_load(r_variance, uint2(_209), 0).x;
        _145[_194] = fast::normalize((sdk_hlsl_load(r_input_normal, uint2(_209), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + float3(cbDenoiserReflections.normalsUnpackAdd));
        float2 _230 = (float2(_201) + float2(0.5)) / float2(_191);
        float4 _232 = sdk_hlsl_load(r_input_depth_hierarchy, uint2(_209), 0);
        float _233 = _232.x;
        float3 _236 = float3(_230, _233);
        _236.y = 1.0 - _230.y;
        float4 _247 = cbDenoiserReflections.invProjection * float4((_236.xy * 2.0) - float2(1.0), _233, 1.0);
        _146[_194] = abs((_247.xyz / float3(_247.w)).z);
        _194++;
        continue;
    }
    for (int _255 = 0; _255 < 4; )
    {
        int2 _262 = _172 + _134[_255];
        int _279 = _262.y;
        int _280 = _262.x;
        g_ffx_dnsr_shared_0[_279][_280] = as_type<uint>(half2(float2(_143[_255].x, 0.0))) | (as_type<uint>(half2(float2(_143[_255].y, 0.0))) << 16u);
        uint _284 = as_type<uint>(half2(float2(_143[_255].z, 0.0)));
        g_ffx_dnsr_shared_1[_279][_280] = _284 | (_284 << 16u);
        g_ffx_dnsr_shared_2[_279][_280] = as_type<uint>(half2(float2(_145[_255].x, 0.0))) | (as_type<uint>(half2(float2(_145[_255].y, 0.0))) << 16u);
        g_ffx_dnsr_shared_3[_279][_280] = as_type<uint>(half2(float2(_145[_255].z, 0.0))) | (as_type<uint>(half2(float2(_144[_255], 0.0))) << 16u);
        g_ffx_dnsr_shared_depth[_279][_280] = _146[_255];
        _255++;
        continue;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    int2 _306 = _172 + int2(4);
    int _307 = _306.y;
    int _308 = _306.x;
    float2 _337 = float2(as_type<half2>(g_ffx_dnsr_shared_3[_307][_308] >> 16u));
    float _338 = _337.x;
    float3 _340 = float4(float2(as_type<half2>(g_ffx_dnsr_shared_0[_307][_308] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_307][_308] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_307][_308] & 65535u)).x, _139).xyz;
    float3 _341 = float4(float2(as_type<half2>(g_ffx_dnsr_shared_2[_307][_308] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_2[_307][_308] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_3[_307][_308] & 65535u)).x, _338).xyz;
    bool _350;
    if (_338 > 0.0)
    {
        _350 = _190 < cbDenoiserReflections.roughnessThreshold;
    }
    else
    {
        _350 = false;
    }
    bool _354;
    if (_350)
    {
        _354 = (isunordered(_190, 9.9999997473787516355514526367188e-05) || _190 >= 9.9999997473787516355514526367188e-05);
    }
    else
    {
        _354 = false;
    }
    float _461;
    float3 _462;
    if (_354)
    {
        float3 _369 = r_average_radiance.sample(s_LinearSampler, ((float2(_174) + float2(0.5)) / float2(select(cbDenoiserReflections.renderSize + uint2(8u), cbDenoiserReflections.renderSize, (cbDenoiserReflections.renderSize & uint2(4294967288u)) == cbDenoiserReflections.renderSize))), level(0.0)).xyz;
        float _371 = (-0.60000002384185791015625) - (_338 * 0.100000001490116119384765625);
        float _376 = precise::max(exp(_371 * length(_369 - _340)), 0.00999999977648258209228515625);
        float _383 = precise::max(0.100000001490116119384765625, 1.0 - exp(_338 * (-4.400000095367431640625)));
        float _385;
        float3 _388;
        float _390;
        _385 = (_338 * _376) * _376;
        _388 = _340 * _376;
        _390 = _376;
        for (int _392 = 0; uint(_392) < 15u; )
        {
            int2 _399 = _306 + _135[_392];
            int _400 = _399.y;
            int _401 = _399.x;
            float2 _430 = float2(as_type<half2>(g_ffx_dnsr_shared_3[_400][_401] >> 16u));
            float _431 = _430.x;
            float3 _433 = float4(float2(as_type<half2>(g_ffx_dnsr_shared_0[_400][_401] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_400][_401] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_400][_401] & 65535u)).x, _139).xyz;
            float _453 = ((powr(precise::max(dot(_341, float4(float2(as_type<half2>(g_ffx_dnsr_shared_2[_400][_401] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_2[_400][_401] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_3[_400][_401] & 65535u)).x, _431).xyz), 0.0), 512.0) * exp(((-abs(g_ffx_dnsr_shared_depth[_307][_308] - g_ffx_dnsr_shared_depth[_400][_401])) * g_ffx_dnsr_shared_depth[_307][_308]) * 4.0)) * precise::max(exp(_371 * length(_369 - _433)), 0.00999999977648258209228515625)) * _383;
            _385 += ((_453 * _453) * _431);
            _388 += (_433 * _453);
            _390 += _453;
            _392++;
            continue;
        }
        _461 = _385 / (_390 * _390);
        _462 = _388 / float3(_390);
    }
    else
    {
        _461 = _338;
        _462 = _340;
    }
    uint2 _464 = uint2(_174);
    sdk_hlsl_store(rw_radiance, _462.xyzz, uint2(_464));
    sdk_hlsl_store(rw_variance, float4(_461), uint2(_464));
}

