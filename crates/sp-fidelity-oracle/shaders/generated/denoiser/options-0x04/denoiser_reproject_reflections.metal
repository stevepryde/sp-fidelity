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

constant float3 _124 = {};
constant float _136 = {};
constant float2 _137 = {};
constant float4 _138 = {};

constant spvUnsafeArray<int2, 4> _125 = spvUnsafeArray<int2, 4>({ int2(0), int2(8, 0), int2(0, 8), int2(8) });

kernel void main0(constant type_cbDenoiserReflections& cbDenoiserReflections [[buffer(0)]], const device type_RWStructuredBuffer_uint& rw_denoiser_tile_list [[buffer(1)]], texture2d<float> r_input_depth_hierarchy [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_normal [[texture(2)]], texture2d<float> r_radiance [[texture(3)]], texture2d<float> r_radiance_history [[texture(4)]], texture2d<float> r_variance [[texture(5)]], texture2d<float> r_sample_count [[texture(6)]], texture2d<float> r_extracted_roughness [[texture(7)]], texture2d<float> r_depth_history [[texture(8)]], texture2d<float> r_normal_history [[texture(9)]], texture2d<float> r_roughness_history [[texture(10)]], texture2d<float, access::write> rw_variance [[texture(11)]], texture2d<float, access::write> rw_sample_count [[texture(12)]], texture2d<float, access::write> rw_average_radiance [[texture(13)]], texture2d<float, access::write> rw_reprojected_radiance [[texture(14)]], sampler s_LinearSampler [[sampler(0)]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_0;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 16>, 16> g_ffx_dnsr_shared_1;
    uint _149 = rw_denoiser_tile_list._m0[gl_WorkGroupID.x];
    int2 _168 = int2(uint2((gl_LocalInvocationIndex & 1u) | ((gl_LocalInvocationIndex >> 2u) & 6u), ((gl_LocalInvocationIndex >> 1u) & 3u) | ((gl_LocalInvocationIndex >> 3u) & 4u)));
    int2 _170 = (((int2(int(_149 & 65535u), int((_149 >> 16u) & 65535u)) + int3(gl_LocalInvocationID).xy) / int2(8)) * int2(8)) + _168;
    int2 _173 = _170 - int2(4);
    spvUnsafeArray<float3, 4> _142;
    for (int _175 = 0; _175 < 4; )
    {
        _142[_175] = sdk_hlsl_load(r_radiance, uint2(int3(_173 + _125[_175], 0).xy), 0).xyz;
        _175++;
        continue;
    }
    for (int _192 = 0; _192 < 4; )
    {
        int2 _199 = _168 + _125[_192];
        int _210 = _199.y;
        int _211 = _199.x;
        g_ffx_dnsr_shared_0[_210][_211] = as_type<uint>(half2(float2(_142[_192].x, 0.0))) | (as_type<uint>(half2(float2(_142[_192].y, 0.0))) << 16u);
        uint _215 = as_type<uint>(half2(float2(_142[_192].z, 0.0)));
        g_ffx_dnsr_shared_1[_210][_211] = _215 | (_215 << 16u);
        _192++;
        continue;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    int2 _219 = _168 + int2(4);
    int _220 = _170.x;
    int _221 = _170.y;
    int2 _223 = int3(_220, _221, 0).xy;
    float4 _225 = sdk_hlsl_load(r_extracted_roughness, uint2(_223), 0);
    float _226 = _225.x;
    bool _229 = cbDenoiserReflections.isRoughnessPerceptual != 0u;
    float _233;
    if (_229)
    {
        _233 = _226 * _226;
    }
    else
    {
        _233 = _226;
    }
    float3 _236 = sdk_hlsl_load(r_radiance, uint2(_223), 0).xyz;
    float3 _955;
    if (_233 < cbDenoiserReflections.roughnessThreshold)
    {
        float2 _884;
        float3 _885;
        float _886;
        do
        {
            float3 _248;
            float3 _251;
            float _253;
            int _255;
            _248 = float3(0.0);
            _251 = float3(0.0);
            _253 = 0.0;
            _255 = -4;
            float3 _249;
            float3 _252;
            float _254;
            for (; _255 <= 4; _248 = _249, _251 = _252, _253 = _254, _255++)
            {
                _249 = _248;
                _252 = _251;
                _254 = _253;
                for (int _265 = -4; _265 <= 4; )
                {
                    int2 _270 = _219 + int2(_265, _255);
                    int _271 = _270.y;
                    int _272 = _270.x;
                    float3 _287 = float4(float2(as_type<half2>(g_ffx_dnsr_shared_0[_271][_272] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[_271][_272] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_271][_272] & 65535u)).x, _136).xyz;
                    float _288 = float(_265);
                    float _292 = float(_255);
                    float _296 = exp((_288 * _288) * (-0.119999997317790985107421875)) * exp((_292 * _292) * (-0.119999997317790985107421875));
                    _249 += ((_287 * _287) * _296);
                    _252 += (_287 * _296);
                    _254 += _296;
                    _265++;
                    continue;
                }
            }
            float3 _300 = float3(_253);
            float3 _301 = _251 / _300;
            float2 _311 = float2(cbDenoiserReflections.renderSize);
            float2 _312 = float2(float(_220) + 0.5, float(_221) + 0.5) / _311;
            float3 _321 = float3(cbDenoiserReflections.normalsUnpackAdd);
            float3 _323 = fast::normalize((sdk_hlsl_load(r_input_normal, uint2(_223), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _321);
            float2 _330 = _312 + (cbDenoiserReflections.motionVectorScale * sdk_hlsl_load(r_input_motion_vectors, uint2(_223), 0).xy);
            float4 _332 = sdk_hlsl_load(r_input_depth_hierarchy, uint2(_223), 0);
            float _333 = _332.x;
            float _334 = _312.x;
            float3 _336 = float3(_334, _312.y, _333);
            float _339 = 1.0 - _312.y;
            _336.y = _339;
            float4 _347 = cbDenoiserReflections.invProjection * float4((_336.xy * 2.0) - float2(1.0), _333, 1.0);
            float3 _352 = (_347.xyz / float3(_347.w)).xyz;
            float _353 = length(_352);
            float4 _371 = cbDenoiserReflections.prevViewProjection * float4((cbDenoiserReflections.invView * float4((_352 / float3(_353)) * (_353 + sdk_hlsl_load(r_radiance, uint2(_223), 0).w), 1.0)).xyz, 1.0);
            float2 _378 = ((_371.xyz / float3(_371.w)).xy * 0.5) + float2(0.5);
            float4 _379 = float4(_378.x, _378.y, _138.z, _138.w);
            float _380 = _378.y;
            float _381 = 1.0 - _380;
            _379.y = _381;
            float3 _391 = fast::normalize((r_normal_history.sample(s_LinearSampler, _330, level(0.0)).xyz * cbDenoiserReflections.normalsUnpackMul) + _321);
            float3 _399 = fast::normalize((r_normal_history.sample(s_LinearSampler, _379.xy, level(0.0)).xyz * cbDenoiserReflections.normalsUnpackMul) + _321);
            float3 _404 = r_radiance_history.sample(s_LinearSampler, _330, level(0.0)).xyz;
            float3 _411 = fast::normalize(_323);
            float _412 = dot(fast::normalize(_399), _411);
            float4 _418 = r_roughness_history.sample(s_LinearSampler, _379.xy, level(0.0));
            float _419 = _418.x;
            float _423;
            if (_229)
            {
                _423 = _419 * _419;
            }
            else
            {
                _423 = _419;
            }
            float4 _427 = r_roughness_history.sample(s_LinearSampler, _330, level(0.0));
            float _428 = _427.x;
            float _432;
            if (_229)
            {
                _432 = _428 * _428;
            }
            else
            {
                _432 = _428;
            }
            bool _438;
            if (_412 > 0.99989998340606689453125)
            {
                _438 = (_412 + 0.001000000047497451305389404296875) > dot(fast::normalize(_391), _411);
            }
            else
            {
                _438 = false;
            }
            bool _447;
            if (_438)
            {
                _447 = abs(_423 - _233) < (abs(_432 - _233) + 0.001000000047497451305389404296875);
            }
            else
            {
                _447 = false;
            }
            float _502;
            if (_447)
            {
                float4 _454 = r_depth_history.sample(s_LinearSampler, _379.xy, level(0.0));
                float _455 = _454.x;
                float3 _457 = float3(_378.x, _381, _455);
                _457.y = _380;
                float4 _465 = cbDenoiserReflections.invProjection * float4((_457.xy * 2.0) - float2(1.0), _455, 1.0);
                _502 = abs((_465.xyz / float3(_465.w)).z);
            }
            else
            {
                float3 _472 = _404 - _301;
                if (!(dot(_472, _472) < (1.5 * length(abs((_248 / _300) - (_301 * _301))))))
                {
                    _884 = _137;
                    _885 = _124;
                    _886 = 0.0;
                    break;
                }
                float4 _482 = r_depth_history.sample(s_LinearSampler, _330, level(0.0));
                float _483 = _482.x;
                float3 _486 = float3(_330, _483);
                _486.y = 1.0 - _330.y;
                float4 _495 = cbDenoiserReflections.invProjection * float4((_486.xy * 2.0) - float2(1.0), _483, 1.0);
                _502 = abs((_495.xyz / float3(_495.w)).z);
            }
            float2 _504 = select(_330, _379.xy, bool2(_447));
            bool3 _505 = bool3(_447);
            float3 _506 = select(_404, r_radiance_history.sample(s_LinearSampler, _379.xy, level(0.0)).xyz, _505);
            float4 _509 = sdk_hlsl_load(r_input_depth_hierarchy, uint2(_223), 0);
            float _510 = _509.x;
            float3 _511 = float3(_334, _312.y, _510);
            _511.y = _339;
            float4 _519 = cbDenoiserReflections.invProjection * float4((_511.xy * 2.0) - float2(1.0), _510, 1.0);
            float _525 = abs((_519.xyz / float3(_519.w)).z);
            float _537 = exp(abs(1.0 - precise::max(0.0, dot(_323, select(_391, _399, _505)))) * (-1.39999997615814208984375)) * exp((-abs(_502 - _525)) / _525);
            if (_537 > 0.89999997615814208984375)
            {
                _884 = _504;
                _885 = _506;
                _886 = _537;
                break;
            }
            float2 _619;
            float3 _620;
            float _621;
            if (_537 < 0.89999997615814208984375)
            {
                float2 _544 = float2(1.0) / _311;
                float2 _546;
                float _549;
                int _551;
                _546 = _504;
                _549 = _537;
                _551 = -1;
                float2 _547;
                float _550;
                for (; _551 <= 1; _546 = _547, _549 = _550, _551++)
                {
                    _547 = _546;
                    _550 = _549;
                    for (int _560 = -1; _560 <= 1; )
                    {
                        float2 _568 = _547 + (float2(float(_560), float(_551)) * _544);
                        float4 _580 = r_depth_history.sample(s_LinearSampler, _568, level(0.0));
                        float _581 = _580.x;
                        float3 _584 = float3(_568, _581);
                        _584.y = 1.0 - _568.y;
                        float4 _593 = cbDenoiserReflections.invProjection * float4((_584.xy * 2.0) - float2(1.0), _581, 1.0);
                        float _611 = exp(abs(1.0 - precise::max(0.0, dot(_323, fast::normalize((r_normal_history.sample(s_LinearSampler, _568, level(0.0)).xyz * cbDenoiserReflections.normalsUnpackMul) + _321)))) * (-1.39999997615814208984375)) * exp((-abs(abs((_593.xyz / float3(_593.w)).z) - _525)) / _525);
                        bool _612 = _611 > _550;
                        _547 = select(_547, _568, bool2(_612));
                        _550 = _612 ? _611 : _550;
                        _560++;
                        continue;
                    }
                }
                _619 = _546;
                _620 = r_radiance_history.sample(s_LinearSampler, _546, level(0.0)).xyz;
                _621 = _549;
            }
            else
            {
                _619 = _504;
                _620 = _506;
                _621 = _537;
            }
            float3 _880;
            float _881;
            if (_621 < 0.89999997615814208984375)
            {
                float _629 = (float(cbDenoiserReflections.renderSize.x) * _619.x) + 0.5;
                float _631 = _629 - floor(_629);
                float _636 = (float(cbDenoiserReflections.renderSize.y) * _619.y) + 0.5;
                float _638 = _636 - floor(_636);
                int2 _641 = int2((_311 * _619) - float2(0.5));
                int2 _645 = int3(_641, 0).xy;
                int2 _653 = int3(_641 + int2(1, 0), 0).xy;
                int2 _661 = int3(_641 + int2(0, 1), 0).xy;
                int2 _669 = int3(_641 + int2(1), 0).xy;
                float3 _678 = fast::normalize((sdk_hlsl_load(r_normal_history, uint2(_645), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _321);
                float3 _684 = fast::normalize((sdk_hlsl_load(r_normal_history, uint2(_653), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _321);
                float3 _690 = fast::normalize((sdk_hlsl_load(r_normal_history, uint2(_661), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _321);
                float3 _696 = fast::normalize((sdk_hlsl_load(r_normal_history, uint2(_669), 0).xyz * cbDenoiserReflections.normalsUnpackMul) + _321);
                float4 _698 = sdk_hlsl_load(r_depth_history, uint2(_645), 0);
                float _699 = _698.x;
                float3 _700 = float3(_619, _699);
                float _701 = 1.0 - _619.y;
                _700.y = _701;
                float4 _709 = cbDenoiserReflections.invProjection * float4((_700.xy * 2.0) - float2(1.0), _699, 1.0);
                float _715 = abs((_709.xyz / float3(_709.w)).z);
                float4 _717 = sdk_hlsl_load(r_depth_history, uint2(_653), 0);
                float _718 = _717.x;
                float3 _719 = float3(_619, _718);
                _719.y = _701;
                float4 _727 = cbDenoiserReflections.invProjection * float4((_719.xy * 2.0) - float2(1.0), _718, 1.0);
                float _733 = abs((_727.xyz / float3(_727.w)).z);
                float4 _735 = sdk_hlsl_load(r_depth_history, uint2(_661), 0);
                float _736 = _735.x;
                float3 _737 = float3(_619, _736);
                _737.y = _701;
                float4 _745 = cbDenoiserReflections.invProjection * float4((_737.xy * 2.0) - float2(1.0), _736, 1.0);
                float _751 = abs((_745.xyz / float3(_745.w)).z);
                float4 _753 = sdk_hlsl_load(r_depth_history, uint2(_669), 0);
                float _754 = _753.x;
                float3 _755 = float3(_619, _754);
                _755.y = _701;
                float4 _763 = cbDenoiserReflections.invProjection * float4((_755.xy * 2.0) - float2(1.0), _754, 1.0);
                float _769 = abs((_763.xyz / float3(_763.w)).z);
                float _826 = 1.0 - _631;
                float _828 = 1.0 - _638;
                float _829 = (float((exp(abs(1.0 - precise::max(0.0, dot(_323, _678))) * (-1.39999997615814208984375)) * exp((-abs(_715 - _525)) / _525)) > 0.449999988079071044921875) * _826) * _828;
                float _831 = (float((exp(abs(1.0 - precise::max(0.0, dot(_323, _684))) * (-1.39999997615814208984375)) * exp((-abs(_733 - _525)) / _525)) > 0.449999988079071044921875) * _631) * _828;
                float _833 = (float((exp(abs(1.0 - precise::max(0.0, dot(_323, _690))) * (-1.39999997615814208984375)) * exp((-abs(_751 - _525)) / _525)) > 0.449999988079071044921875) * _826) * _638;
                float _835 = (float((exp(abs(1.0 - precise::max(0.0, dot(_323, _696))) * (-1.39999997615814208984375)) * exp((-abs(_769 - _525)) / _525)) > 0.449999988079071044921875) * _631) * _638;
                float4 _842 = float4(_829, _831, _833, _835) / float4(precise::max(((_829 + _831) + _833) + _835, 0.001000000047497451305389404296875));
                float _843 = _842.x;
                float _845 = _842.y;
                float _848 = _842.z;
                float _851 = _842.w;
                _880 = (((sdk_hlsl_load(r_radiance_history, uint2(_645), 0).xyz * _843) + (sdk_hlsl_load(r_radiance_history, uint2(_653), 0).xyz * _845)) + (sdk_hlsl_load(r_radiance_history, uint2(_661), 0).xyz * _848)) + (sdk_hlsl_load(r_radiance_history, uint2(_669), 0).xyz * _851);
                _881 = exp(abs(1.0 - precise::max(0.0, dot(_323, (((_678 * _843) + (_684 * _845)) + (_690 * _848)) + (_696 * _851)))) * (-1.39999997615814208984375)) * exp((-abs(((((_715 * _843) + (_733 * _845)) + (_751 * _848)) + (_769 * _851)) - _525)) / _525);
            }
            else
            {
                _880 = _620;
                _881 = _621;
            }
            _884 = _619;
            _885 = _880;
            _886 = (_881 < 0.89999997615814208984375) ? 0.0 : _881;
            break;
        } while(false);
        bool _893;
        if (_884.x > 0.0)
        {
            _893 = _884.y > 0.0;
        }
        else
        {
            _893 = false;
        }
        bool _897;
        if (_893)
        {
            _897 = _884.x < 1.0;
        }
        else
        {
            _897 = false;
        }
        bool _902;
        if (_897)
        {
            _902 = _884.y < 1.0;
        }
        else
        {
            _902 = false;
        }
        float3 _954;
        if (_902)
        {
            float _923 = precise::min(precise::max(8.0, 32.0 * (1.0 - exp(_233 * (-100.0)))), (r_sample_count.sample(s_LinearSampler, _884, level(0.0)).x * _886) + 1.0);
            float _925 = precise::max(dot(_236, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875);
            float _927 = precise::max(dot(_885, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875);
            float _932 = abs(_925 - _927) / precise::max(precise::max(_925, _927), 0.5);
            float3 _949;
            if (_886 < 0.89999997615814208984375)
            {
                uint2 _938 = uint2(_170);
                sdk_hlsl_store(rw_reprojected_radiance, float3(0.0).xyzz, uint2(_938));
                sdk_hlsl_store(rw_variance, float4(1.0), uint2(_938));
                sdk_hlsl_store(rw_sample_count, float4(1.0), uint2(_938));
                _949 = _236;
            }
            else
            {
                uint2 _944 = uint2(_170);
                sdk_hlsl_store(rw_reprojected_radiance, _885.xyzz, uint2(_944));
                sdk_hlsl_store(rw_variance, float4(mix(_932 * _932, r_variance.sample(s_LinearSampler, _884, level(0.0)).x, 1.0 / _923)), uint2(_944));
                sdk_hlsl_store(rw_sample_count, float4(_923), uint2(_944));
                _949 = mix(_236, _885, float3(0.300000011920928955078125));
            }
            _954 = _949;
        }
        else
        {
            uint2 _950 = uint2(_170);
            sdk_hlsl_store(rw_reprojected_radiance, float3(0.0).xyzz, uint2(_950));
            sdk_hlsl_store(rw_variance, float4(1.0), uint2(_950));
            sdk_hlsl_store(rw_sample_count, float4(1.0), uint2(_950));
            _954 = _236;
        }
        _955 = _954;
    }
    else
    {
        _955 = _236;
    }
    float _960 = precise::max(exp(precise::max(dot(_955, float3(0.2989999949932098388671875, 0.58700001239776611328125, 0.114000000059604644775390625)), 0.001000000047497451305389404296875) * (-0.300000011920928955078125)), 0.00999999977648258209228515625);
    float3 _961 = _955 * _960;
    bool _970;
    if (uint(_220) < cbDenoiserReflections.renderSize.x)
    {
        _970 = uint(_221) >= cbDenoiserReflections.renderSize.y;
    }
    else
    {
        _970 = true;
    }
    bool _976;
    if (!_970)
    {
        _976 = any(isinf(_961));
    }
    else
    {
        _976 = true;
    }
    bool _982;
    if (!_976)
    {
        _982 = any(isnan(_961));
    }
    else
    {
        _982 = true;
    }
    bool _987;
    if (!_982)
    {
        _987 = _960 > 1000.0;
    }
    else
    {
        _987 = true;
    }
    float3 _990 = select(_961, float3(0.0), bool3(_987));
    int _1000 = _168.y;
    int _1001 = _168.x;
    g_ffx_dnsr_shared_0[_1000][_1001] = as_type<uint>(half2(float2(_990.x, 0.0))) | (as_type<uint>(half2(float2(_990.y, 0.0))) << 16u);
    g_ffx_dnsr_shared_1[_1000][_1001] = as_type<uint>(half2(float2(_990.z, 0.0))) | (as_type<uint>(half2(float2(_987 ? 0.0 : _960, 0.0))) << 16u);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (int _1011 = 2; _1011 <= 8; _1011 *= 2)
    {
        int _1017 = _1001 * _1011;
        int _1018 = _1000 * _1011;
        int _1019 = _1011 / 2;
        int _1020 = _1017 + _1019;
        int _1021 = _1018 + _1019;
        bool _1026;
        if (_1020 < 8)
        {
            _1026 = _1021 < 8;
        }
        else
        {
            _1026 = false;
        }
        if (_1026)
        {
            uint _1030 = g_ffx_dnsr_shared_0[_1018][_1017];
            uint _1047 = g_ffx_dnsr_shared_0[_1021][_1017];
            uint _1064 = g_ffx_dnsr_shared_0[_1018][_1020];
            uint _1081 = g_ffx_dnsr_shared_0[_1021][_1020];
            float4 _1099 = ((float4(float2(as_type<half2>(_1030 & 65535u)).x, float2(as_type<half2>(_1030 >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1018][_1017] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1018][_1017] >> 16u)).x) + float4(float2(as_type<half2>(_1064 & 65535u)).x, float2(as_type<half2>(_1064 >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1018][_1020] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1018][_1020] >> 16u)).x)) + float4(float2(as_type<half2>(_1047 & 65535u)).x, float2(as_type<half2>(_1047 >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1021][_1017] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1021][_1017] >> 16u)).x)) + float4(float2(as_type<half2>(_1081 & 65535u)).x, float2(as_type<half2>(_1081 >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1021][_1020] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[_1021][_1020] >> 16u)).x);
            g_ffx_dnsr_shared_0[_1018][_1017] = as_type<uint>(half2(float2(_1099.x, 0.0))) | (as_type<uint>(half2(float2(_1099.y, 0.0))) << 16u);
            g_ffx_dnsr_shared_1[_1018][_1017] = as_type<uint>(half2(float2(_1099.z, 0.0))) | (as_type<uint>(half2(float2(_1099.w, 0.0))) << 16u);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    bool _1120;
    if (_1001 == 0)
    {
        _1120 = _1000 == 0;
    }
    else
    {
        _1120 = false;
    }
    if (_1120)
    {
        float2 _1137 = float2(as_type<half2>(g_ffx_dnsr_shared_1[0][0] >> 16u));
        float _1138 = _1137.x;
        sdk_hlsl_store(rw_average_radiance, (float4(float2(as_type<half2>(g_ffx_dnsr_shared_0[0][0] & 65535u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_0[0][0] >> 16u)).x, float2(as_type<half2>(g_ffx_dnsr_shared_1[0][0] & 65535u)).x, _1138).xyz / float3(precise::max(_1138, 0.001000000047497451305389404296875))).xyzz, uint2(uint2(_170 / int2(8))));
    }
}

