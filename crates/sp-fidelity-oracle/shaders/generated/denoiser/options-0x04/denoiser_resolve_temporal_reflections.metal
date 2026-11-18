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

constant float _110 = {};

constant spvUnsafeArray<int2, 4> _106 = spvUnsafeArray<int2, 4>({ int2(0), int2(8, 0), int2(0, 8), int2(8) });

kernel void main0(constant type_cbDenoiserReflections& cbDenoiserReflections [[buffer(0)]], const device type_RWStructuredBuffer_uint& rw_denoiser_tile_list [[buffer(1)]], texture2d<float> r_radiance [[texture(0)]], texture2d<float> r_variance [[texture(1)]], texture2d<float> r_sample_count [[texture(2)]], texture2d<float> r_average_radiance [[texture(3)]], texture2d<float> r_extracted_roughness [[texture(4)]], texture2d<float> r_reprojected_radiance [[texture(5)]], texture2d<float, access::write> rw_radiance [[texture(6)]], texture2d<float, access::write> rw_variance [[texture(7)]], sampler s_LinearSampler [[sampler(0)]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_0;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_1;
    uint _120 = rw_denoiser_tile_list._m0[gl_WorkGroupID.x];
    int2 _139 = int2(uint2((gl_LocalInvocationIndex & 1u) | ((gl_LocalInvocationIndex >> 2u) & 6u), ((gl_LocalInvocationIndex >> 1u) & 3u) | ((gl_LocalInvocationIndex >> 3u) & 4u)));
    int2 _141 = (((int2(int(_120 & 65535u), int((_120 >> 16u) & 65535u)) + int3(gl_LocalInvocationID).xy) / int2(8)) * int2(8)) + _139;
    do
    {
        int2 _148 = _141 - int2(4);
        spvUnsafeArray<float3, 4> _113;
        for (int _150 = 0; _150 < 4; )
        {
            _113[_150] = sdk_hlsl_load(r_radiance, uint2(int3(_148 + _106[_150], 0).xy), 0).xyz;
            _150++;
            continue;
        }
        for (int _167 = 0; _167 < 4; )
        {
            int2 _174 = _139 + _106[_167];
            int _185 = _174.y;
            int _186 = _174.x;
            g_ffx_dnsr_shared_0[_185][_186] = as_type<uint>(half2(float2(_113[_167].x, 0.0))) | (as_type<uint>(half2(float2(_113[_167].y, 0.0))) << 16u);
            uint _190 = as_type<uint>(half2(float2(_113[_167].z, 0.0)));
            g_ffx_dnsr_shared_1[_185][_186] = _190 | (_190 << 16u);
            _167++;
            continue;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        int2 _194 = _139 + int2(4);
        int _195 = _194.y;
        int _196 = _194.x;
        if (((float2(as_type<half2>(g_ffx_dnsr_shared_0[_195][_196] & 65535u)).x + float2(as_type<half2>(g_ffx_dnsr_shared_0[_195][_196] >> 16u)).x) + float2(as_type<half2>(g_ffx_dnsr_shared_1[_195][_196] & 65535u)).x) < 9.9999997473787516355514526367188e-05)
        {
            uint2 _215 = uint2(_141);
            sdk_hlsl_store(rw_radiance, float4(0.0), uint2(_215));
            sdk_hlsl_store(rw_variance, float4(0.0), uint2(_215));
            break;
        }
        float3 _230 = float4(float2(as_type<half2>(g_ffx_dnsr_shared_0[_195][_196] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_195][_196] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_195][_196] & 65535u)).x, _110).xyz;
        int2 _234 = int3(_141, 0).xy;
        float4 _236 = sdk_hlsl_load(r_extracted_roughness, uint2(_234), 0);
        float _237 = _236.x;
        float _244;
        if (cbDenoiserReflections.isRoughnessPerceptual != 0u)
        {
            _244 = _237 * _237;
        }
        else
        {
            _244 = _237;
        }
        float4 _246 = sdk_hlsl_load(r_variance, uint2(_234), 0);
        float _247 = _246.x;
        float _431;
        float3 _432;
        if (_244 < cbDenoiserReflections.roughnessThreshold)
        {
            float4 _254 = sdk_hlsl_load(r_sample_count, uint2(_234), 0);
            float _255 = _254.x;
            float3 _268 = r_average_radiance.sample(s_LinearSampler, ((float2(_141) + float2(0.5)) / float2(select(cbDenoiserReflections.renderSize + uint2(8u), cbDenoiserReflections.renderSize, (cbDenoiserReflections.renderSize & uint2(4294967288u)) == cbDenoiserReflections.renderSize))), level(0.0)).xyz;
            float3 _271 = sdk_hlsl_load(r_reprojected_radiance, uint2(_234), 0).xyz;
            float3 _273;
            float3 _276;
            float _278;
            int _280;
            _273 = float3(0.0);
            _276 = float3(0.0);
            _278 = 0.0;
            _280 = -4;
            float3 _274;
            float3 _277;
            float _279;
            for (; _280 <= 4; _273 = _274, _276 = _277, _278 = _279, _280++)
            {
                _274 = _273;
                _277 = _276;
                _279 = _278;
                for (int _290 = -4; _290 <= 4; )
                {
                    int2 _295 = _194 + int2(_290, _280);
                    int _296 = _295.y;
                    int _297 = _295.x;
                    float3 _312 = float4(float2(as_type<half2>(g_ffx_dnsr_shared_0[_296][_297] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_296][_297] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_296][_297] & 65535u)).x, _110).xyz;
                    float _313 = float(_290);
                    float _317 = float(_280);
                    float _321 = exp((_313 * _313) * (-0.119999997317790985107421875)) * exp((_317 * _317) * (-0.119999997317790985107421875));
                    _274 += ((_312 * _312) * _321);
                    _277 += (_312 * _321);
                    _279 += _321;
                    _290++;
                    continue;
                }
            }
            float3 _325 = float3(_278);
            float3 _326 = _276 / _325;
            float3 _337 = ((sqrt(abs((_273 / _325) - (_326 * _326))) + float3(length(_326 - _268))) * cbDenoiserReflections.temporalStabilityFactor) * 1.39999997615814208984375;
            float3 _338 = mix(_326, _268, float3(0.20000000298023223876953125));
            float3 _339 = _338 - _337;
            float3 _340 = _338 + _337;
            float3 _363;
            do
            {
                float3 _344 = (_340 + _339) * 0.5;
                float3 _348 = _271 - _344;
                float3 _350 = abs(_348 / (((_340 - _339) * 0.5) + float3(0.001000000047497451305389404296875)));
                float _355 = precise::max(precise::max(_350.x, _350.y), _350.z);
                if (_355 > 1.0)
                {
                    _363 = _344 + (_348 / float3(_355));
                    break;
                }
                else
                {
                    _363 = _271;
                    break;
                }
                break; // unreachable workaround
            } while(false);
            float _366 = 1.0 - (1.0 / precise::max(_255, 1.0));
            float3 _371 = mix(_230, _268, float3(1.0 / precise::max(_255 + 1.0, 1.0)));
            float3 _372 = _268 - _337;
            float3 _373 = _268 + _337;
            float3 _396;
            do
            {
                float3 _377 = (_373 + _372) * 0.5;
                float3 _381 = _371 - _377;
                float3 _383 = abs(_381 / (((_373 - _372) * 0.5) + float3(0.001000000047497451305389404296875)));
                float _388 = precise::max(precise::max(_383.x, _383.y), _383.z);
                if (_388 > 1.0)
                {
                    _396 = _377 + (_381 / float3(_388));
                    break;
                }
                else
                {
                    _396 = _371;
                    break;
                }
                break; // unreachable workaround
            } while(false);
            float3 _398 = mix(_396, _363, float3(_366));
            float _400 = precise::max(dot(_398, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875);
            float _402 = precise::max(dot(_363, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875);
            float _407 = abs(_400 - _402) / precise::max(precise::max(_400, _402), 0.5);
            float _409 = mix(_407 * _407, _247, _366);
            bool _417;
            if (!any(isinf(_398)))
            {
                _417 = any(isnan(_398));
            }
            else
            {
                _417 = true;
            }
            bool _422;
            if (!_417)
            {
                _422 = isinf(_409);
            }
            else
            {
                _422 = true;
            }
            bool _427;
            if (!_422)
            {
                _427 = isnan(_409);
            }
            else
            {
                _427 = true;
            }
            _431 = _427 ? 0.0 : _409;
            _432 = select(_398, float3(0.0), bool3(_427));
        }
        else
        {
            _431 = _247;
            _432 = _230;
        }
        uint2 _434 = uint2(_141);
        sdk_hlsl_store(rw_radiance, _432.xyzz, uint2(_434));
        sdk_hlsl_store(rw_variance, float4(_431), uint2(_434));
        break;
    } while(false);
}

