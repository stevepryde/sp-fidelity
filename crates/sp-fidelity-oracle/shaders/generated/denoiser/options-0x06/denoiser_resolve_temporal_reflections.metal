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

constant half _119 = {};
constant float _120 = {};

constant spvUnsafeArray<int2, 4> _116 = spvUnsafeArray<int2, 4>({ int2(0), int2(8, 0), int2(0, 8), int2(8) });

kernel void main0(constant type_cbDenoiserReflections& cbDenoiserReflections [[buffer(0)]], const device type_RWStructuredBuffer_uint& rw_denoiser_tile_list [[buffer(1)]], texture2d<float> r_radiance [[texture(0)]], texture2d<float> r_variance [[texture(1)]], texture2d<float> r_sample_count [[texture(2)]], texture2d<float> r_average_radiance [[texture(3)]], texture2d<float> r_extracted_roughness [[texture(4)]], texture2d<float> r_reprojected_radiance [[texture(5)]], texture2d<float, access::write> rw_radiance [[texture(6)]], texture2d<float, access::write> rw_variance [[texture(7)]], sampler s_LinearSampler [[sampler(0)]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_0;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_1;
    uint _130 = rw_denoiser_tile_list._m0[gl_WorkGroupID.x];
    int2 _149 = int2(uint2((gl_LocalInvocationIndex & 1u) | ((gl_LocalInvocationIndex >> 2u) & 6u), ((gl_LocalInvocationIndex >> 1u) & 3u) | ((gl_LocalInvocationIndex >> 3u) & 4u)));
    int2 _151 = (((int2(int(_130 & 65535u), int((_130 >> 16u) & 65535u)) + int3(gl_LocalInvocationID).xy) / int2(8)) * int2(8)) + _149;
    do
    {
        int2 _158 = _151 - int2(4);
        spvUnsafeArray<half3, 4> _123;
        for (int _160 = 0; _160 < 4; )
        {
            _123[_160] = half3(sdk_hlsl_load(r_radiance, uint2(int3(_158 + _116[_160], 0).xy), 0).xyz);
            _160++;
            continue;
        }
        for (int _178 = 0; _178 < 4; )
        {
            int2 _185 = _149 + _116[_178];
            float2 _189 = float2(_123[_178].xy);
            int _198 = _185.y;
            int _199 = _185.x;
            g_ffx_dnsr_shared_0[_198][_199] = as_type<uint>(half2(float2(_189.x, 0.0))) | (as_type<uint>(half2(float2(_189.y, 0.0))) << 16u);
            float2 _202 = float2(_123[_178].zz);
            g_ffx_dnsr_shared_1[_198][_199] = as_type<uint>(half2(float2(_202.x, 0.0))) | (as_type<uint>(half2(float2(_202.y, 0.0))) << 16u);
            _178++;
            continue;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        int2 _212 = _149 + int2(4);
        int _213 = _212.y;
        int _214 = _212.x;
        half2 _226 = half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_213][_214] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_213][_214] >> 16u)).x));
        if (float((_226.x + _226.y) + half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_213][_214] & 65535u)).x, _120)).x) < 9.9999997473787516355514526367188e-05)
        {
            uint2 _242 = uint2(_151);
            sdk_hlsl_store(rw_radiance, float4(half4(half(0.0))), uint2(_242));
            sdk_hlsl_store(rw_variance, float4(float(half(0.0))), uint2(_242));
            break;
        }
        half3 _265 = half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_213][_214] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_213][_214] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_213][_214] & 65535u)).x, _120)).x, _119).xyz;
        int2 _269 = int3(_151, 0).xy;
        half _273 = half(sdk_hlsl_load(r_extracted_roughness, uint2(_269), 0).x);
        half _280;
        if (cbDenoiserReflections.isRoughnessPerceptual != 0u)
        {
            _280 = _273 * _273;
        }
        else
        {
            _280 = _273;
        }
        half _284 = half(sdk_hlsl_load(r_variance, uint2(_269), 0).x);
        half _499;
        half3 _500;
        if (float(_280) < cbDenoiserReflections.roughnessThreshold)
        {
            half _294 = half(sdk_hlsl_load(r_sample_count, uint2(_269), 0).x);
            half3 _308 = half3(r_average_radiance.sample(s_LinearSampler, ((float2(_151) + float2(0.5)) / float2(select(cbDenoiserReflections.renderSize + uint2(8u), cbDenoiserReflections.renderSize, (cbDenoiserReflections.renderSize & uint2(4294967288u)) == cbDenoiserReflections.renderSize))), level(0.0)).xyz);
            half3 _312 = half3(sdk_hlsl_load(r_reprojected_radiance, uint2(_269), 0).xyz);
            half3 _314;
            half3 _317;
            half _319;
            int _321;
            _314 = half3(half(0.0));
            _317 = half3(half(0.0));
            _319 = half(0.0);
            _321 = -4;
            half3 _315;
            half3 _318;
            half _320;
            for (; _321 <= 4; _314 = _315, _317 = _318, _319 = _320, _321++)
            {
                _315 = _314;
                _318 = _317;
                _320 = _319;
                for (int _331 = -4; _331 <= 4; )
                {
                    int2 _336 = _212 + int2(_331, _321);
                    int _337 = _336.y;
                    int _338 = _336.x;
                    half3 _360 = half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_337][_338] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_337][_338] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_337][_338] & 65535u)).x, _120)).x, _119).xyz;
                    half _362 = half(short(_331));
                    half _365 = half(5.0) * half(5.0);
                    half _369 = half(short(_321));
                    half _374 = exp((half(-3.0) * (_362 * _362)) / _365) * exp((half(-3.0) * (_369 * _369)) / _365);
                    _315 += ((_360 * _360) * _374);
                    _318 += (_360 * _374);
                    _320 += _374;
                    _331++;
                    continue;
                }
            }
            half3 _378 = half3(_319);
            half3 _379 = _317 / _378;
            half3 _392 = half3((float3(sqrt(abs((_314 / _378) - (_379 * _379))) + half3(length(_379 - _308))) * cbDenoiserReflections.temporalStabilityFactor) * 1.39999997615814208984375);
            half3 _393 = mix(_379, _308, half3(half(0.199951171875)));
            half3 _394 = _393 - _392;
            half3 _395 = _393 + _392;
            half3 _424;
            do
            {
                float3 _400 = float3((_395 + _394) * half(0.5));
                float3 _406 = float3(_312) - _400;
                float3 _408 = abs(_406 / float3(((_395 - _394) * half(0.5)) + half3(half(0.00100040435791015625))));
                half _414 = half(precise::max(precise::max(_408.x, _408.y), _408.z));
                if (_414 > half(1.0))
                {
                    _424 = half3(_400 + (_406 / float3(float(_414))));
                    break;
                }
                else
                {
                    _424 = _312;
                    break;
                }
                break; // unreachable workaround
            } while(false);
            half _427 = half(1.0) - (half(1.0) / max(_294, half(1.0)));
            half3 _432 = mix(_265, _308, half3(half(1.0) / max(_294 + half(1.0), half(1.0))));
            half3 _433 = _392 * half3(half(1.0));
            half3 _434 = _308 - _433;
            half3 _435 = _308 + _433;
            half3 _464;
            do
            {
                float3 _440 = float3((_435 + _434) * half(0.5));
                float3 _446 = float3(_432) - _440;
                float3 _448 = abs(_446 / float3(((_435 - _434) * half(0.5)) + half3(half(0.00100040435791015625))));
                half _454 = half(precise::max(precise::max(_448.x, _448.y), _448.z));
                if (_454 > half(1.0))
                {
                    _464 = half3(_440 + (_446 / float3(float(_454))));
                    break;
                }
                else
                {
                    _464 = _432;
                    break;
                }
                break; // unreachable workaround
            } while(false);
            half3 _466 = mix(_464, _424, half3(_427));
            half _468 = max(dot(_466, half3(half(0.299072265625), half(0.5869140625), half(0.114013671875))), half(0.00100040435791015625));
            half _470 = max(dot(_424, half3(half(0.299072265625), half(0.5869140625), half(0.114013671875))), half(0.00100040435791015625));
            half _475 = abs(_468 - _470) / max(max(_468, _470), half(0.5));
            half _477 = mix(_475 * _475, _284, _427);
            bool _485;
            if (!any(isinf(_466)))
            {
                _485 = any(isnan(_466));
            }
            else
            {
                _485 = true;
            }
            bool _490;
            if (!_485)
            {
                _490 = isinf(_477);
            }
            else
            {
                _490 = true;
            }
            bool _495;
            if (!_490)
            {
                _495 = isnan(_477);
            }
            else
            {
                _495 = true;
            }
            _499 = _495 ? half(0.0) : _477;
            _500 = select(_466, half3(half(0.0)), bool3(_495));
        }
        else
        {
            _499 = _284;
            _500 = _265;
        }
        uint2 _503 = uint2(_151);
        sdk_hlsl_store(rw_radiance, float4(_500.xyzz), uint2(_503));
        sdk_hlsl_store(rw_variance, float4(float(_499)), uint2(_503));
        break;
    } while(false);
}

