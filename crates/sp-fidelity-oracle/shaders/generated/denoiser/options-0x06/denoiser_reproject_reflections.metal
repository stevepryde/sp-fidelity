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

constant half3 _136 = {};
constant half _145 = {};
constant float2 _146 = {};
constant float _147 = {};
constant float4 _148 = {};

constant spvUnsafeArray<int2, 4> _137 = spvUnsafeArray<int2, 4>({ int2(0), int2(8, 0), int2(0, 8), int2(8) });

kernel void main0(constant type_cbDenoiserReflections& cbDenoiserReflections [[buffer(0)]], const device type_RWStructuredBuffer_uint& rw_denoiser_tile_list [[buffer(1)]], texture2d<float> r_input_depth_hierarchy [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_normal [[texture(2)]], texture2d<float> r_radiance [[texture(3)]], texture2d<float> r_radiance_history [[texture(4)]], texture2d<float> r_variance [[texture(5)]], texture2d<float> r_sample_count [[texture(6)]], texture2d<float> r_extracted_roughness [[texture(7)]], texture2d<float> r_depth_history [[texture(8)]], texture2d<float> r_normal_history [[texture(9)]], texture2d<float> r_roughness_history [[texture(10)]], texture2d<float, access::write> rw_variance [[texture(11)]], texture2d<float, access::write> rw_sample_count [[texture(12)]], texture2d<float, access::write> rw_average_radiance [[texture(13)]], texture2d<float, access::write> rw_reprojected_radiance [[texture(14)]], sampler s_LinearSampler [[sampler(0)]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_0;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_1;
    uint _159 = rw_denoiser_tile_list._m0[gl_WorkGroupID.x];
    int2 _178 = int2(uint2((gl_LocalInvocationIndex & 1u) | ((gl_LocalInvocationIndex >> 2u) & 6u), ((gl_LocalInvocationIndex >> 1u) & 3u) | ((gl_LocalInvocationIndex >> 3u) & 4u)));
    int2 _180 = (((int2(int(_159 & 65535u), int((_159 >> 16u) & 65535u)) + int3(gl_LocalInvocationID).xy) / int2(8)) * int2(8)) + _178;
    int2 _183 = _180 - int2(4);
    spvUnsafeArray<half3, 4> _152;
    for (int _185 = 0; _185 < 4; )
    {
        _152[_185] = half3(sdk_hlsl_load(r_radiance, uint2(int3(_183 + _137[_185], 0).xy), 0).xyz);
        _185++;
        continue;
    }
    for (int _203 = 0; _203 < 4; )
    {
        int2 _210 = _178 + _137[_203];
        float2 _214 = float2(_152[_203].xy);
        int _223 = _210.y;
        int _224 = _210.x;
        g_ffx_dnsr_shared_0[_223][_224] = as_type<uint>(half2(float2(_214.x, 0.0))) | (as_type<uint>(half2(float2(_214.y, 0.0))) << 16u);
        float2 _227 = float2(_152[_203].zz);
        g_ffx_dnsr_shared_1[_223][_224] = as_type<uint>(half2(float2(_227.x, 0.0))) | (as_type<uint>(half2(float2(_227.y, 0.0))) << 16u);
        _203++;
        continue;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    int2 _237 = _178 + int2(4);
    int _238 = _180.x;
    int _239 = _180.y;
    int2 _241 = int3(_238, _239, 0).xy;
    half _245 = half(sdk_hlsl_load(r_extracted_roughness, uint2(_241), 0).x);
    bool _248 = cbDenoiserReflections.isRoughnessPerceptual != 0u;
    half _252;
    if (_248)
    {
        _252 = _245 * _245;
    }
    else
    {
        _252 = _245;
    }
    half3 _256 = half3(sdk_hlsl_load(r_radiance, uint2(_241), 0).xyz);
    half3 _1056;
    if (float(_252) < cbDenoiserReflections.roughnessThreshold)
    {
        float2 _971;
        half3 _972;
        half _973;
        do
        {
            half3 _270;
            half3 _273;
            half _275;
            int _277;
            _270 = half3(half(0.0));
            _273 = half3(half(0.0));
            _275 = half(0.0);
            _277 = -4;
            half3 _271;
            half3 _274;
            half _276;
            for (; _277 <= 4; _270 = _271, _273 = _274, _275 = _276, _277++)
            {
                _271 = _270;
                _274 = _273;
                _276 = _275;
                for (int _287 = -4; _287 <= 4; )
                {
                    int2 _292 = _237 + int2(_287, _277);
                    int _293 = _292.y;
                    int _294 = _292.x;
                    half3 _316 = half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_293][_294] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_293][_294] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_293][_294] & 65535u)).x, _147)).x, _145).xyz;
                    half _318 = half(short(_287));
                    half _321 = half(5.0) * half(5.0);
                    half _325 = half(short(_277));
                    half _330 = exp((half(-3.0) * (_318 * _318)) / _321) * exp((half(-3.0) * (_325 * _325)) / _321);
                    _271 += ((_316 * _316) * _330);
                    _274 += (_316 * _330);
                    _276 += _330;
                    _287++;
                    continue;
                }
            }
            half3 _334 = half3(_275);
            half3 _335 = _273 / _334;
            float2 _345 = float2(cbDenoiserReflections.renderSize);
            float2 _346 = float2(float(_238) + 0.5, float(_239) + 0.5) / _345;
            float3 _355 = float3(cbDenoiserReflections.normalsUnpackAdd);
            half3 _358 = normalize(half3((sdk_hlsl_load(r_input_normal, uint2(_241), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _355));
            float2 _365 = _346 + (cbDenoiserReflections.motionVectorScale * sdk_hlsl_load(r_input_motion_vectors, uint2(_241), 0).xy);
            float4 _368 = sdk_hlsl_load(r_input_depth_hierarchy, uint2(_241), 0);
            float _369 = _368.x;
            float _370 = _346.x;
            float3 _372 = float3(_370, _346.y, _369);
            float _375 = 1.0 - _346.y;
            _372.y = _375;
            float4 _383 = cbDenoiserReflections.invProjection * float4((_372.xy * 2.0) - float2(1.0), _369, 1.0);
            float3 _388 = (_383.xyz / float3(_383.w)).xyz;
            float _389 = length(_388);
            float4 _400 = cbDenoiserReflections.invView * float4((_388 / float3(_389)) * (_389 + float(half(sdk_hlsl_load(r_radiance, uint2(_241), 0).w))), 1.0);
            float4 _407 = cbDenoiserReflections.prevViewProjection * float4(_400.xyz, 1.0);
            float2 _414 = ((_407.xyz / float3(_407.w)).xy * 0.5) + float2(0.5);
            float4 _415 = float4(_414.x, _414.y, _148.z, _148.w);
            float _416 = _414.y;
            float _417 = 1.0 - _416;
            _415.y = _417;
            half3 _428 = normalize(half3((r_normal_history.sample(s_LinearSampler, _365, level(0.0)).xyz * cbDenoiserReflections.normalsUnpackMul) + _355));
            half3 _437 = normalize(half3((r_normal_history.sample(s_LinearSampler, _415.xy, level(0.0)).xyz * cbDenoiserReflections.normalsUnpackMul) + _355));
            half3 _443 = half3(r_radiance_history.sample(s_LinearSampler, _365, level(0.0)).xyz);
            float3 _453 = fast::normalize(float3(_358));
            float _454 = dot(fast::normalize(float3(_437)), _453);
            half _463 = half(r_roughness_history.sample(s_LinearSampler, _415.xy, level(0.0)).x);
            half _467;
            if (_248)
            {
                _467 = _463 * _463;
            }
            else
            {
                _467 = _463;
            }
            half _473 = half(r_roughness_history.sample(s_LinearSampler, _365, level(0.0)).x);
            half _477;
            if (_248)
            {
                _477 = _473 * _473;
            }
            else
            {
                _477 = _473;
            }
            bool _483;
            if (_454 > 0.99989998340606689453125)
            {
                _483 = (_454 + 0.001000000047497451305389404296875) > dot(fast::normalize(float3(_428)), _453);
            }
            else
            {
                _483 = false;
            }
            bool _492;
            if (_483)
            {
                _492 = abs(_467 - _252) < (abs(_477 - _252) + half(0.00100040435791015625));
            }
            else
            {
                _492 = false;
            }
            float _549;
            if (_492)
            {
                float4 _499 = r_depth_history.sample(s_LinearSampler, _415.xy, level(0.0));
                float _500 = _499.x;
                float3 _502 = float3(_414.x, _417, _500);
                _502.y = _416;
                float4 _510 = cbDenoiserReflections.invProjection * float4((_502.xy * 2.0) - float2(1.0), _500, 1.0);
                _549 = abs((_510.xyz / float3(_510.w)).z);
            }
            else
            {
                float3 _518 = float3(_443 - _335);
                if (!(dot(_518, _518) < float(half(1.5) * length(abs((_270 / _334) - (_335 * _335))))))
                {
                    _971 = _146;
                    _972 = _136;
                    _973 = half(0.0);
                    break;
                }
                float4 _529 = r_depth_history.sample(s_LinearSampler, _365, level(0.0));
                float _530 = _529.x;
                float3 _533 = float3(_365, _530);
                _533.y = 1.0 - _365.y;
                float4 _542 = cbDenoiserReflections.invProjection * float4((_533.xy * 2.0) - float2(1.0), _530, 1.0);
                _549 = abs((_542.xyz / float3(_542.w)).z);
            }
            float2 _551 = select(_365, _415.xy, bool2(_492));
            bool3 _552 = bool3(_492);
            half3 _553 = select(_443, half3(r_radiance_history.sample(s_LinearSampler, _415.xy, level(0.0)).xyz), _552);
            float4 _556 = sdk_hlsl_load(r_input_depth_hierarchy, uint2(_241), 0);
            float _557 = _556.x;
            float3 _558 = float3(_370, _346.y, _557);
            _558.y = _375;
            float4 _566 = cbDenoiserReflections.invProjection * float4((_558.xy * 2.0) - float2(1.0), _557, 1.0);
            float _572 = abs((_566.xyz / float3(_566.w)).z);
            half _586 = half(exp(abs(1.0 - float(max(half(0.0), dot(_358, select(_428, _437, _552))))) * (-1.39999997615814208984375)) * exp((-abs(_549 - _572)) / _572));
            if (_586 > half(0.89990234375))
            {
                _971 = _551;
                _972 = _553;
                _973 = _586;
                break;
            }
            float2 _672;
            half3 _673;
            half _674;
            if (_586 < half(0.89990234375))
            {
                float2 _593 = float2(1.0) / _345;
                float2 _595;
                half _598;
                int _600;
                _595 = _551;
                _598 = _586;
                _600 = -1;
                float2 _596;
                half _599;
                for (; _600 <= 1; _595 = _596, _598 = _599, _600++)
                {
                    _596 = _595;
                    _599 = _598;
                    for (int _609 = -1; _609 <= 1; )
                    {
                        float2 _617 = _596 + (float2(float(_609), float(_600)) * _593);
                        float4 _630 = r_depth_history.sample(s_LinearSampler, _617, level(0.0));
                        float _631 = _630.x;
                        float3 _634 = float3(_617, _631);
                        _634.y = 1.0 - _617.y;
                        float4 _643 = cbDenoiserReflections.invProjection * float4((_634.xy * 2.0) - float2(1.0), _631, 1.0);
                        half _663 = half(exp(abs(1.0 - float(max(half(0.0), dot(_358, normalize(half3((r_normal_history.sample(s_LinearSampler, _617, level(0.0)).xyz * cbDenoiserReflections.normalsUnpackMul) + _355)))))) * (-1.39999997615814208984375)) * exp((-abs(abs((_643.xyz / float3(_643.w)).z) - _572)) / _572));
                        bool _664 = _663 > _599;
                        _596 = select(_596, _617, bool2(_664));
                        _599 = _664 ? _663 : _599;
                        _609++;
                        continue;
                    }
                }
                _672 = _595;
                _673 = half3(r_radiance_history.sample(s_LinearSampler, _595, level(0.0)).xyz);
                _674 = _598;
            }
            else
            {
                _672 = _551;
                _673 = _553;
                _674 = _586;
            }
            half3 _967;
            half _968;
            if (_674 < half(0.89990234375))
            {
                float _682 = (float(cbDenoiserReflections.renderSize.x) * _672.x) + 0.5;
                float _684 = _682 - floor(_682);
                float _689 = (float(cbDenoiserReflections.renderSize.y) * _672.y) + 0.5;
                float _691 = _689 - floor(_689);
                int2 _694 = int2((_345 * _672) - float2(0.5));
                int2 _698 = int3(_694, 0).xy;
                int2 _707 = int3(_694 + int2(1, 0), 0).xy;
                int2 _716 = int3(_694 + int2(0, 1), 0).xy;
                int2 _725 = int3(_694 + int2(1), 0).xy;
                half3 _736 = normalize(half3((sdk_hlsl_load(r_normal_history, uint2(_698), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _355));
                half3 _743 = normalize(half3((sdk_hlsl_load(r_normal_history, uint2(_707), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _355));
                half3 _750 = normalize(half3((sdk_hlsl_load(r_normal_history, uint2(_716), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _355));
                half3 _757 = normalize(half3((sdk_hlsl_load(r_normal_history, uint2(_725), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _355));
                float4 _759 = sdk_hlsl_load(r_depth_history, uint2(_698), 0);
                float _760 = _759.x;
                float3 _761 = float3(_672, _760);
                float _762 = 1.0 - _672.y;
                _761.y = _762;
                float4 _770 = cbDenoiserReflections.invProjection * float4((_761.xy * 2.0) - float2(1.0), _760, 1.0);
                float _776 = abs((_770.xyz / float3(_770.w)).z);
                float4 _778 = sdk_hlsl_load(r_depth_history, uint2(_707), 0);
                float _779 = _778.x;
                float3 _780 = float3(_672, _779);
                _780.y = _762;
                float4 _788 = cbDenoiserReflections.invProjection * float4((_780.xy * 2.0) - float2(1.0), _779, 1.0);
                float _794 = abs((_788.xyz / float3(_788.w)).z);
                float4 _796 = sdk_hlsl_load(r_depth_history, uint2(_716), 0);
                float _797 = _796.x;
                float3 _798 = float3(_672, _797);
                _798.y = _762;
                float4 _806 = cbDenoiserReflections.invProjection * float4((_798.xy * 2.0) - float2(1.0), _797, 1.0);
                float _812 = abs((_806.xyz / float3(_806.w)).z);
                float4 _814 = sdk_hlsl_load(r_depth_history, uint2(_725), 0);
                float _815 = _814.x;
                float3 _816 = float3(_672, _815);
                _816.y = _762;
                float4 _824 = cbDenoiserReflections.invProjection * float4((_816.xy * 2.0) - float2(1.0), _815, 1.0);
                float _830 = abs((_824.xyz / float3(_824.w)).z);
                float _900 = 1.0 - _684;
                float _902 = 1.0 - _691;
                half _904 = half((float(half(float(half(exp(abs(1.0 - float(max(half(0.0), dot(_358, _736)))) * (-1.39999997615814208984375)) * exp((-abs(_776 - _572)) / _572))) > 0.449999988079071044921875)) * _900) * _902);
                half _908 = half((float(half(float(half(exp(abs(1.0 - float(max(half(0.0), dot(_358, _743)))) * (-1.39999997615814208984375)) * exp((-abs(_794 - _572)) / _572))) > 0.449999988079071044921875)) * _684) * _902);
                half _912 = half((float(half(float(half(exp(abs(1.0 - float(max(half(0.0), dot(_358, _750)))) * (-1.39999997615814208984375)) * exp((-abs(_812 - _572)) / _572))) > 0.449999988079071044921875)) * _900) * _691);
                half _916 = half((float(half(float(half(exp(abs(1.0 - float(max(half(0.0), dot(_358, _757)))) * (-1.39999997615814208984375)) * exp((-abs(_830 - _572)) / _572))) > 0.449999988079071044921875)) * _684) * _691);
                half4 _923 = half4(_904, _908, _912, _916) / half4(max(((_904 + _908) + _912) + _916, half(0.00100040435791015625)));
                half _924 = _923.x;
                half _926 = _923.y;
                half _929 = _923.z;
                half _932 = _923.w;
                _967 = (((half3(sdk_hlsl_load(r_radiance_history, uint2(_698), 0).xyz) * _924) + (half3(sdk_hlsl_load(r_radiance_history, uint2(_707), 0).xyz) * _926)) + (half3(sdk_hlsl_load(r_radiance_history, uint2(_716), 0).xyz) * _929)) + (half3(sdk_hlsl_load(r_radiance_history, uint2(_725), 0).xyz) * _932);
                _968 = half(exp(abs(1.0 - float(max(half(0.0), dot(_358, (((_736 * _924) + (_743 * _926)) + (_750 * _929)) + (_757 * _932))))) * (-1.39999997615814208984375)) * exp((-abs(((((_776 * float(_924)) + (_794 * float(_926))) + (_812 * float(_929))) + (_830 * float(_932))) - _572)) / _572));
            }
            else
            {
                _967 = _673;
                _968 = _674;
            }
            _971 = _672;
            _972 = _967;
            _973 = (_968 < half(0.89990234375)) ? half(0.0) : _968;
            break;
        } while(false);
        bool _980;
        if (_971.x > 0.0)
        {
            _980 = _971.y > 0.0;
        }
        else
        {
            _980 = false;
        }
        bool _984;
        if (_980)
        {
            _984 = _971.x < 1.0;
        }
        else
        {
            _984 = false;
        }
        bool _989;
        if (_984)
        {
            _989 = _971.y < 1.0;
        }
        else
        {
            _989 = false;
        }
        half3 _1055;
        if (_989)
        {
            half _1018 = max(dot(_256, half3(half(0.299072265625), half(0.5869140625), half(0.114013671875))), half(0.00100040435791015625));
            half _1020 = max(dot(_972, half3(half(0.299072265625), half(0.5869140625), half(0.114013671875))), half(0.00100040435791015625));
            half _1025 = abs(_1018 - _1020) / max(max(_1018, _1020), half(0.5));
            half3 _1048;
            if (_973 < half(0.89990234375))
            {
                uint2 _1032 = uint2(_180);
                sdk_hlsl_store(rw_reprojected_radiance, float3(half3(half(0.0))).xyzz, uint2(_1032));
                float _1034 = float(half(1.0));
                sdk_hlsl_store(rw_variance, float4(_1034), uint2(_1032));
                sdk_hlsl_store(rw_sample_count, float4(_1034), uint2(_1032));
                _1048 = _256;
            }
            else
            {
                float _1037 = float(min(half(precise::max(8.0, float(half(short(32)) * (half(1.0) - exp((-_252) * half(100.0)))))), (half(r_sample_count.sample(s_LinearSampler, _971, level(0.0)).x) * _973) + half(1.0)));
                uint2 _1042 = uint2(_180);
                sdk_hlsl_store(rw_reprojected_radiance, float3(_972).xyzz, uint2(_1042));
                sdk_hlsl_store(rw_variance, float4(float(mix(_1025 * _1025, half(r_variance.sample(s_LinearSampler, _971, level(0.0)).x), half(1.0 / _1037)))), uint2(_1042));
                sdk_hlsl_store(rw_sample_count, float4(_1037), uint2(_1042));
                _1048 = mix(_256, _972, half3(half(0.300048828125)));
            }
            _1055 = _1048;
        }
        else
        {
            uint2 _1050 = uint2(_180);
            sdk_hlsl_store(rw_reprojected_radiance, float3(half3(half(0.0))).xyzz, uint2(_1050));
            float _1052 = float(half(1.0));
            sdk_hlsl_store(rw_variance, float4(_1052), uint2(_1050));
            sdk_hlsl_store(rw_sample_count, float4(_1052), uint2(_1050));
            _1055 = _256;
        }
        _1056 = _1055;
    }
    else
    {
        _1056 = _256;
    }
    half _1062 = max(exp((-max(dot(_1056, half3(half(0.299072265625), half(0.5869140625), half(0.114013671875))), half(0.00100040435791015625))) * half(0.300048828125)), half(0.01000213623046875));
    half3 _1063 = _1056 * _1062;
    bool _1072;
    if (uint(_238) < cbDenoiserReflections.renderSize.x)
    {
        _1072 = uint(_239) >= cbDenoiserReflections.renderSize.y;
    }
    else
    {
        _1072 = true;
    }
    bool _1078;
    if (!_1072)
    {
        _1078 = any(isinf(_1063));
    }
    else
    {
        _1078 = true;
    }
    bool _1084;
    if (!_1078)
    {
        _1084 = any(isnan(_1063));
    }
    else
    {
        _1084 = true;
    }
    bool _1089;
    if (!_1084)
    {
        _1089 = _1062 > half(1000.0);
    }
    else
    {
        _1089 = true;
    }
    half4 _1096 = half4(select(_1063, half3(half(0.0)), bool3(_1089)), _1089 ? half(0.0) : _1062);
    float2 _1098 = float2(_1096.xy);
    int _1107 = _178.y;
    int _1108 = _178.x;
    g_ffx_dnsr_shared_0[_1107][_1108] = as_type<uint>(half2(float2(_1098.x, 0.0))) | (as_type<uint>(half2(float2(_1098.y, 0.0))) << 16u);
    float2 _1111 = float2(_1096.zw);
    g_ffx_dnsr_shared_1[_1107][_1108] = as_type<uint>(half2(float2(_1111.x, 0.0))) | (as_type<uint>(half2(float2(_1111.y, 0.0))) << 16u);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (int _1122 = 2; _1122 <= 8; _1122 *= 2)
    {
        int _1128 = _1108 * _1122;
        int _1129 = _1107 * _1122;
        int _1130 = _1122 / 2;
        int _1131 = _1128 + _1130;
        int _1132 = _1129 + _1130;
        bool _1137;
        if (_1131 < 8)
        {
            _1137 = _1132 < 8;
        }
        else
        {
            _1137 = false;
        }
        if (_1137)
        {
            uint _1216 = g_ffx_dnsr_shared_0[_1132][_1131];
            half4 _1242 = ((half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_1129][_1128] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_1129][_1128] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_1129][_1128] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1129][_1128] >> 16u)).x))) + half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_1129][_1131] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_1129][_1131] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_1129][_1131] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1129][_1131] >> 16u)).x)))) + half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[_1132][_1128] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_1132][_1128] >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_1132][_1128] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1132][_1128] >> 16u)).x)))) + half4(half2(float2(float2(as_type<half2>(_1216 & 65535u)).x, float2(as_type<half2>(_1216 >> 16u)).x)), half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[_1132][_1131] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1132][_1131] >> 16u)).x)));
            float2 _1244 = float2(_1242.xy);
            g_ffx_dnsr_shared_0[_1129][_1128] = as_type<uint>(half2(float2(_1244.x, 0.0))) | (as_type<uint>(half2(float2(_1244.y, 0.0))) << 16u);
            float2 _1254 = float2(_1242.zw);
            g_ffx_dnsr_shared_1[_1129][_1128] = as_type<uint>(half2(float2(_1254.x, 0.0))) | (as_type<uint>(half2(float2(_1254.y, 0.0))) << 16u);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    bool _1267;
    if (_1108 == 0)
    {
        _1267 = _1107 == 0;
    }
    else
    {
        _1267 = false;
    }
    if (_1267)
    {
        half2 _1289 = half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_1[0][0] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[0][0] >> 16u)).x));
        sdk_hlsl_store(rw_average_radiance, float3(half3(float3(half4(half2(float2(float2(as_type<half2>(g_ffx_dnsr_shared_0[0][0] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[0][0] >> 16u)).x)), _1289).xyz / half3(max(_1289.y, half(0.00100040435791015625)))))).xyzz, uint2(uint2(_180 / int2(8))));
    }
}

