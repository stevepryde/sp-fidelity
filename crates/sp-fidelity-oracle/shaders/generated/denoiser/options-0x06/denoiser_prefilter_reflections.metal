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

constant half _148 = {};
constant float _149 = {};

constant spvUnsafeArray<int2, 4> _145 = spvUnsafeArray<int2, 4>({ int2(0), int2(8, 0), int2(0, 8), int2(8) });
constant spvUnsafeArray<int2, 15> _146 = spvUnsafeArray<int2, 15>({ int2(0, 1), int2(-2, 1), int2(2, -3), int2(-3, 0), int2(1, 2), int2(-1, -2), int2(3, 0), int2(-3, 3), int2(0, -3), int2(-1), int2(2, 1), int2(-2), int2(1, 0), int2(0, 2), int2(3, -1) });

kernel void main0(constant type_cbDenoiserReflections& cbDenoiserReflections [[buffer(0)]], const device type_RWStructuredBuffer_uint& rw_denoiser_tile_list [[buffer(1)]], texture2d<float> r_input_depth_hierarchy [[texture(0)]], texture2d<float> r_input_normal [[texture(1)]], texture2d<float> r_radiance [[texture(2)]], texture2d<float> r_variance [[texture(3)]], texture2d<float> r_average_radiance [[texture(4)]], texture2d<float> r_extracted_roughness [[texture(5)]], texture2d<float, access::write> rw_radiance [[texture(6)]], texture2d<float, access::write> rw_variance [[texture(7)]], sampler s_LinearSampler [[sampler(0)]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_0;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_1;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_2;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_3;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> g_ffx_dnsr_shared_depth;
    uint _163 = rw_denoiser_tile_list._m0[gl_WorkGroupID.x];
    int2 _182 = int2(uint2((gl_LocalInvocationIndex & 1u) | ((gl_LocalInvocationIndex >> 2u) & 6u), ((gl_LocalInvocationIndex >> 1u) & 3u) | ((gl_LocalInvocationIndex >> 3u) & 4u)));
    int2 _184 = (((int2(int(_163 & 65535u), int((_163 >> 16u) & 65535u)) + int3(gl_LocalInvocationID).xy) / int2(8)) * int2(8)) + _182;
    half _194 = half(sdk_hlsl_load(r_extracted_roughness, uint2(int3(_184, 0).xy), 0).x);
    half _201;
    if (cbDenoiserReflections.isRoughnessPerceptual != 0u)
    {
        _201 = _194 * _194;
    }
    else
    {
        _201 = _194;
    }
    int2 _202 = int2(cbDenoiserReflections.renderSize);
    int2 _203 = _184 - int2(4);
    spvUnsafeArray<half3, 4> _153;
    spvUnsafeArray<half, 4> _154;
    spvUnsafeArray<half3, 4> _155;
    spvUnsafeArray<float, 4> _156;
    for (int _205 = 0; _205 < 4; )
    {
        int2 _212 = _203 + _145[_205];
        int2 _220 = int3(_212, 0).xy;
        _153[_205] = half3(sdk_hlsl_load(r_radiance, uint2(_220), 0).xyz);
        _154[_205] = half(sdk_hlsl_load(r_variance, uint2(_220), 0).x);
        _155[_205] = normalize(half3((sdk_hlsl_load(r_input_normal, uint2(_220), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + float3(cbDenoiserReflections.normalsUnpackAdd)));
        float2 _244 = (float2(_212) + float2(0.5)) / float2(_202);
        float4 _246 = sdk_hlsl_load(r_input_depth_hierarchy, uint2(_220), 0);
        float _247 = _246.x;
        float3 _250 = float3(_244, _247);
        _250.y = 1.0 - _244.y;
        float4 _261 = cbDenoiserReflections.invProjection * float4((_250.xy * 2.0) - float2(1.0), _247, 1.0);
        _156[_205] = abs((_261.xyz / float3(_261.w)).z);
        _205++;
        continue;
    }
    for (int _269 = 0; _269 < 4; )
    {
        int2 _276 = _182 + _145[_269];
        float2 _286 = float2(_153[_269].xy);
        int _295 = _276.y;
        int _296 = _276.x;
        g_ffx_dnsr_shared_0[_295][_296] = as_type<uint>(half2(float2(_286.x, 0.0))) | (as_type<uint>(half2(float2(_286.y, 0.0))) << 16u);
        float2 _299 = float2(_153[_269].zz);
        g_ffx_dnsr_shared_1[_295][_296] = as_type<uint>(half2(float2(_299.x, 0.0))) | (as_type<uint>(half2(float2(_299.y, 0.0))) << 16u);
        float2 _310 = float2(_155[_269].xy);
        g_ffx_dnsr_shared_2[_295][_296] = as_type<uint>(half2(float2(_310.x, 0.0))) | (as_type<uint>(half2(float2(_310.y, 0.0))) << 16u);
        float2 _322 = float2(half2(_155[_269].z, _154[_269]));
        g_ffx_dnsr_shared_3[_295][_296] = as_type<uint>(half2(float2(_322.x, 0.0))) | (as_type<uint>(half2(float2(_322.y, 0.0))) << 16u);
        g_ffx_dnsr_shared_depth[_295][_296] = _156[_269];
        _269++;
        continue;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    int2 _333 = _182 + int2(4);
    int _334 = _333.y;
    int _335 = _333.x;
    half2 _376 = half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_3[_334][_335] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_3[_334][_335] >> 16u)).x));
    half _380 = _376.y;
    half3 _382 = half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_334][_335] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_334][_335] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_334][_335] & 65535u)).x, _149)).x, _148).xyz;
    half3 _383 = half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_2[_334][_335] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_2[_334][_335] >> 16u)).x)), _376.x, _380).xyz;
    bool _393;
    if (_380 > half(0.0))
    {
        _393 = float(_201) < cbDenoiserReflections.roughnessThreshold;
    }
    else
    {
        _393 = false;
    }
    bool _398;
    if (_393)
    {
        float _396 = float(_201);
        _398 = (isunordered(_396, 9.9999997473787516355514526367188e-05) || _396 >= 9.9999997473787516355514526367188e-05);
    }
    else
    {
        _398 = false;
    }
    half _525;
    half3 _526;
    if (_398)
    {
        half3 _414 = half3(r_average_radiance.sample(s_LinearSampler, ((float2(_184) + float2(0.5)) / float2(select(cbDenoiserReflections.renderSize + uint2(8u), cbDenoiserReflections.renderSize, (cbDenoiserReflections.renderSize & uint2(4294967288u)) == cbDenoiserReflections.renderSize))), level(0.0)).xyz);
        half _417 = -(half(0.60009765625) + (_380 * half(0.0999755859375)));
        half _422 = max(exp(_417 * length(_414 - _382)), half(0.01000213623046875));
        half _430 = max(half(0.0999755859375), half(1.0) - exp(-(_380 * half(4.3984375))));
        half _432;
        half3 _435;
        half _437;
        _432 = (_380 * _422) * _422;
        _435 = _382 * _422;
        _437 = _422;
        for (int _439 = 0; uint(_439) < 15u; )
        {
            int2 _446 = _333 + _146[_439];
            int _447 = _446.y;
            int _448 = _446.x;
            half2 _489 = half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_3[_447][_448] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_3[_447][_448] >> 16u)).x));
            half3 _495 = half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_447][_448] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_447][_448] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_447][_448] & 65535u)).x, _149)).x, _148).xyz;
            half _517 = (((half(1.0) * powr(max(dot(_383, half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_2[_447][_448] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_2[_447][_448] >> 16u)).x)), _489).xyz), half(0.0)), half(512.0))) * half(exp(((-abs(g_ffx_dnsr_shared_depth[_334][_335] - g_ffx_dnsr_shared_depth[_447][_448])) * g_ffx_dnsr_shared_depth[_334][_335]) * 4.0))) * max(exp(_417 * length(_414 - _495)), half(0.01000213623046875))) * _430;
            _432 += ((_517 * _517) * _489.y);
            _435 += (_495 * _517);
            _437 += _517;
            _439++;
            continue;
        }
        _525 = _432 / (_437 * _437);
        _526 = _435 / half3(_437);
    }
    else
    {
        _525 = _380;
        _526 = _382;
    }
    uint2 _529 = uint2(_184);
    sdk_hlsl_store(rw_radiance, float4(_526.xyzz), uint2(_529));
    sdk_hlsl_store(rw_variance, float4(float(_525)), uint2(_529));
}

