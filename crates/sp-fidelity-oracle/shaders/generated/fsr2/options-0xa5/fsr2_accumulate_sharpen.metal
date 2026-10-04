#pragma clang diagnostic ignored "-Wmissing-prototypes"

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


template <typename ImageT>
void spvImageFence(ImageT img) { img.fence(); }

struct type_cbFSR2
{
    int2 iRenderSize;
    int2 iMaxRenderSize;
    int2 iDisplaySize;
    int2 iInputColorResourceDimensions;
    int2 iLumaMipDimensions;
    int iLumaMipLevelToUse;
    int iFrameIndex;
    float4 fDeviceToViewDepth;
    float2 fJitter;
    float2 fMotionVectorScale;
    float2 fDownscaleFactor;
    float2 fMotionVectorJitterCancellation;
    float fPreExposure;
    float fPreviousFramePreExposure;
    float fTanHalfFOV;
    float fJitterSequenceLength;
    float fDeltaTime;
    float fDynamicResChangeFactor;
    float fViewSpaceToMetersFactor;
    float fPadding;
};

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_exposure [[texture(0)]], texture2d<float> r_dilated_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float> r_lock_status [[texture(3)]], texture2d<float> r_prepared_input_color [[texture(4)]], texture2d<float> r_luma_history [[texture(5)]], texture2d<float> r_lanczos_lut [[texture(6)]], texture2d<float> r_imgMips [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(9)]], texture2d<float, access::write> rw_lock_status [[texture(10)]], texture2d<float, access::read_write> rw_new_locks [[texture(11)]], texture2d<float, access::write> rw_luma_history [[texture(12)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _149 = gl_WorkGroupID.xy;
    _149.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _163 = (_149 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _166 = float2(int2(_163)) + float2(0.5);
    float2 _167 = float2(cbFSR2.iDisplaySize);
    float2 _168 = _166 / _167;
    float2 _173 = float2(cbFSR2.iRenderSize);
    float2 _183 = precise::max(float2(0.5), precise::min((_168 + (cbFSR2.fJitter / _173)) * _173, _173 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _190 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_168 * _173)))), 0u).xy;
    float _192 = length(_190 * _167);
    float2 _193 = _168 + _190;
    float _194 = _193.x;
    bool _199;
    if (_194 >= 0.0)
    {
        _199 = _194 <= 1.0;
    }
    else
    {
        _199 = false;
    }
    bool _208;
    if (_199)
    {
        float _202 = _193.y;
        bool _207;
        if (_202 >= 0.0)
        {
            _207 = _202 <= 1.0;
        }
        else
        {
            _207 = false;
        }
        _208 = _207;
    }
    else
    {
        _208 = false;
    }
    float _214 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _183, level(0.0)).w, 0.0, 1.0);
    float4 _218 = r_dilated_reactive_masks.sample(s_LinearClamp, _183, level(0.0));
    float _219 = _218.x;
    float _220 = _218.y;
    bool _223 = 0 == cbFSR2.iFrameIndex;
    bool _224 = _208 ? _223 : true;
    bool _228;
    if (_208)
    {
        _228 = !_223;
    }
    else
    {
        _228 = false;
    }
    float2 _679;
    float3 _680;
    bool _681;
    bool _682;
    float _683;
    if (_228)
    {
        float2 _232 = (_193 * _167) - float2(0.5);
        float2 _242 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _232.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _232.y)));
        float2 _243 = floor(_242);
        int2 _244 = int2(_243);
        half2 _246 = half2(_242 - _243);
        int2 _247 = _244 + int2(-1);
        int _251 = max(_247.y, 0);
        int2 _252 = int2(max(_247.x, 0), _251);
        _252.y = _251;
        int2 _258 = _244 + int2(0, -1);
        int _261 = max(_258.y, 0);
        int2 _262 = int2(_258.x, _261);
        _262.y = _261;
        int2 _268 = _244 + int2(1, -1);
        int _270 = cbFSR2.iDisplaySize.x - 1;
        int _273 = max(_268.y, 0);
        int2 _274 = int2(min(_268.x, _270), _273);
        _274.y = _273;
        int2 _280 = _244 + int2(2, -1);
        int _284 = max(_280.y, 0);
        int2 _285 = int2(min(_280.x, _270), _284);
        _285.y = _284;
        int2 _291 = _244 + int2(-1, 0);
        int _294 = _291.y;
        int2 _295 = int2(max(_291.x, 0), _294);
        _295.y = _294;
        int2 _302 = _244;
        _302.y = _244.y;
        half4 _306 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_302)), 0u));
        int2 _307 = _244 + int2(1, 0);
        int _310 = _307.y;
        int2 _311 = int2(min(_307.x, _270), _310);
        _311.y = _310;
        half4 _316 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_311)), 0u));
        int2 _317 = _244 + int2(2, 0);
        int _320 = _317.y;
        int2 _321 = int2(min(_317.x, _270), _320);
        _321.y = _320;
        int2 _327 = _244 + int2(-1, 1);
        int _330 = _327.y;
        int2 _331 = int2(max(_327.x, 0), _330);
        int _332 = cbFSR2.iDisplaySize.y - 1;
        _331.y = min(_330, _332);
        int2 _339 = _244 + int2(0, 1);
        _339.y = min(_339.y, _332);
        half4 _346 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_339)), 0u));
        int2 _347 = _244 + int2(1);
        int _350 = _347.y;
        int2 _351 = int2(min(_347.x, _270), _350);
        _351.y = min(_350, _332);
        half4 _357 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_351)), 0u));
        int2 _358 = _244 + int2(2, 1);
        int _361 = _358.y;
        int2 _362 = int2(min(_358.x, _270), _361);
        _362.y = min(_361, _332);
        int2 _369 = _244 + int2(-1, 2);
        int _372 = _369.y;
        int2 _373 = int2(max(_369.x, 0), _372);
        _373.y = min(_372, _332);
        int2 _380 = _244 + int2(0, 2);
        _380.y = min(_380.y, _332);
        int2 _388 = _244 + int2(1, 2);
        int _391 = _388.y;
        int2 _392 = int2(min(_388.x, _270), _391);
        _392.y = min(_391, _332);
        int2 _399 = _244 + int2(2);
        int _402 = _399.y;
        int2 _403 = int2(min(_399.x, _270), _402);
        _403.y = min(_402, _332);
        half _410 = _246.x;
        float2 _417 = float2(float(abs(half(-1.0) - _410)) * 0.5, 0.5);
        half _421 = half(r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0)).x);
        float2 _428 = float2(float(abs(half(-0.0) - _410)) * 0.5, 0.5);
        half _432 = half(r_lanczos_lut.sample(s_LinearClamp, _428, level(0.0)).x);
        float2 _439 = float2(float(abs(half(1.0) - _410)) * 0.5, 0.5);
        half _443 = half(r_lanczos_lut.sample(s_LinearClamp, _439, level(0.0)).x);
        float2 _450 = float2(float(abs(half(2.0) - _410)) * 0.5, 0.5);
        half _454 = half(r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0)).x);
        half _472 = half(r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0)).x);
        half _478 = half(r_lanczos_lut.sample(s_LinearClamp, _428, level(0.0)).x);
        half _484 = half(r_lanczos_lut.sample(s_LinearClamp, _439, level(0.0)).x);
        half _490 = half(r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0)).x);
        half _508 = half(r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0)).x);
        half _514 = half(r_lanczos_lut.sample(s_LinearClamp, _428, level(0.0)).x);
        half _520 = half(r_lanczos_lut.sample(s_LinearClamp, _439, level(0.0)).x);
        half _526 = half(r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0)).x);
        half _544 = half(r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0)).x);
        half _550 = half(r_lanczos_lut.sample(s_LinearClamp, _428, level(0.0)).x);
        half _556 = half(r_lanczos_lut.sample(s_LinearClamp, _439, level(0.0)).x);
        half _562 = half(r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0)).x);
        half _575 = _246.y;
        half _586 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-1.0) - _575)) * 0.5, 0.5), level(0.0)).x);
        half _597 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-0.0) - _575)) * 0.5, 0.5), level(0.0)).x);
        half _608 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(1.0) - _575)) * 0.5, 0.5), level(0.0)).x);
        half _619 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(2.0) - _575)) * 0.5, 0.5), level(0.0)).x);
        half4 _626 = ((((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_252)), 0u)) * _421) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_262)), 0u)) * _432)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_274)), 0u)) * _443)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_285)), 0u)) * _454)) / half4(((_421 + _432) + _443) + _454)) * _586) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_295)), 0u)) * _472) + (_306 * _478)) + (_316 * _484)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_321)), 0u)) * _490)) / half4(((_472 + _478) + _484) + _490)) * _597)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_331)), 0u)) * _508) + (_346 * _514)) + (_357 * _520)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_362)), 0u)) * _526)) / half4(((_508 + _514) + _520) + _526)) * _608)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_373)), 0u)) * _544) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_380)), 0u)) * _550)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_392)), 0u)) * _556)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_403)), 0u)) * _562)) / half4(((_544 + _550) + _556) + _562)) * _619);
        float4 _639 = float4(clamp(_626 / half4(((_586 + _597) + _608) + _619), min(min(min(_306, _316), _346), _357), max(max(max(_306, _316), _346), _357)));
        float4 _642 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _643 = _642.x;
        float3 _651 = fast::clamp((_639.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_643 == 0.0) ? 1.0 : _643), float3(0.0), float3(65504.0));
        float _652 = _651.x;
        float _655 = 0.5 * _651.y;
        float _657 = _651.z;
        float _658 = 0.25 * _657;
        float _666 = _639.w;
        spvImageFence(rw_new_locks);
        _679 = r_lock_status.sample(s_LinearClamp, _193, level(0.0)).xy;
        _680 = float3(((0.25 * _652) + _655) + _658, 0.5 * (_652 - _657), (((-0.25) * _652) + _655) - _658);
        _681 = _666 < 0.0;
        _682 = sdk_hlsl_load(rw_new_locks, uint2(_163)).x > 0.4980392158031463623046875;
        _683 = fast::clamp(abs(_666), 0.0, 1.0);
    }
    else
    {
        _679 = float2(0.0);
        _680 = float3(0.0);
        _681 = false;
        _682 = false;
        _683 = 0.0;
    }
    float2 _695 = float2(int2(_173 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _703 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _704 = _703.x;
    float _716 = powr(((_704 == 0.0) ? 1.0 : _704) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_168 * _695, _695 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _719 = (_679.y == 0.0) ? _716 : _679.y;
    float2 _720 = _679;
    _720.y = _719;
    float _721 = precise::max(_719, _716);
    float _728;
    if (_721 != 0.0)
    {
        _728 = precise::min(_719, _716) / _721;
    }
    else
    {
        _728 = 0.0;
    }
    float _729 = 1.0 - _728;
    float2 _750;
    if (_682)
    {
        _750 = float2((_679.x != 0.0) ? 2.0 : 1.0, _716);
    }
    else
    {
        float2 _745;
        if (_679.x <= 1.0)
        {
            float2 _744 = _720;
            _744.y = mix(_719, _716, 0.5);
            _745 = _744;
        }
        else
        {
            float2 _742;
            if (_729 > 0.100000001490116119384765625)
            {
                _742 = float2(0.0, _719);
            }
            else
            {
                _742 = _720;
            }
            _745 = _742;
        }
        _750 = _745;
    }
    float _754 = precise::max(precise::max(_219, _683), fast::clamp((0.89999997615814208984375 - _728) * 10.0, 0.0, 1.0));
    float _755 = 1.0 - _754;
    float _763 = ((_750.x * _755) * fast::clamp(1.0 - _220, 0.0, 1.0)) * float(_214 < 0.100000001490116119384765625);
    float _767 = precise::max(_750.y, _716);
    float _774;
    if (_767 != 0.0)
    {
        _774 = precise::min(_750.y, _716) / _767;
    }
    else
    {
        _774 = 0.0;
    }
    float2 _782 = _166 * cbFSR2.fDownscaleFactor;
    int2 _784 = int2(floor(_782));
    float2 _787 = (float2(_784) + float2(0.5)) - cbFSR2.fJitter;
    bool _790 = _787.x > _782.x;
    bool _794 = _787.y > _782.y;
    int2 _796 = int2(_790 ? (-2) : (-1), _794 ? (-2) : (-1));
    float2 _797 = float2(_796);
    int _798 = _790 ? 3 : 0;
    int _799 = _794 ? 3 : 0;
    int2 _800 = int2(_798, _799);
    int2 _801 = _784 + _796;
    int2 _802 = _801 + _800;
    int2 _804 = _802;
    _804.y = _802.y;
    float3 _808 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_804)), 0u).xyz;
    int _809 = _790 ? 2 : 1;
    int2 _810 = int2(_809, _799);
    int2 _811 = _801 + _810;
    int2 _813 = _811;
    _813.y = _811.y;
    float3 _817 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_813)), 0u).xyz;
    int _818 = _790 ? 1 : 2;
    int2 _819 = int2(_818, _799);
    int2 _820 = _801 + _819;
    int2 _822 = _820;
    _822.y = _820.y;
    float3 _826 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_822)), 0u).xyz;
    int _827 = _794 ? 2 : 1;
    int2 _828 = int2(_798, _827);
    int2 _829 = _801 + _828;
    int2 _831 = _829;
    _831.y = _829.y;
    float3 _835 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_831)), 0u).xyz;
    int2 _836 = int2(_809, _827);
    int2 _837 = _801 + _836;
    int2 _839 = _837;
    _839.y = _837.y;
    float3 _843 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_839)), 0u).xyz;
    int2 _844 = int2(_818, _827);
    int2 _845 = _801 + _844;
    int2 _847 = _845;
    _847.y = _845.y;
    float3 _851 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_847)), 0u).xyz;
    int _852 = _794 ? 1 : 2;
    int2 _853 = int2(_798, _852);
    int2 _854 = _801 + _853;
    int2 _856 = _854;
    _856.y = _854.y;
    float3 _860 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_856)), 0u).xyz;
    int2 _861 = int2(_809, _852);
    int2 _862 = _801 + _861;
    int2 _864 = _862;
    _864.y = _862.y;
    float3 _868 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_864)), 0u).xyz;
    int2 _869 = int2(_818, _852);
    int2 _870 = _801 + _869;
    int2 _872 = _870;
    _872.y = _870.y;
    float3 _876 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_872)), 0u).xyz;
    float2 _877 = _787 - _782;
    float _879 = precise::max(_754, float(_224));
    float _886 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _879);
    float _896 = mix(-2.0, -3.0, fast::clamp(_192 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _899 = _877 + (_797 + float2(_800));
    uint2 _901 = uint2(cbFSR2.iRenderSize);
    float2 _905 = float2(mix(_886, precise::max(1.0, (1.0 + _886) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _214, _879))));
    float2 _906 = _899 * _905;
    float _908 = precise::min(dot(_906, _906), 4.0);
    float _910 = (0.4000000059604644775390625 * _908) - 1.0;
    float _912 = (0.25 * _908) - 1.0;
    float _918 = float(all(uint2(_802) < _901)) * ((((1.5625 * _910) * _910) - 0.5625) * (_912 * _912));
    float _926 = exp(_896 * dot(_899, _899));
    float3 _927 = _808 * _926;
    float2 _931 = _877 + (_797 + float2(_810));
    float2 _936 = _931 * _905;
    float _938 = precise::min(dot(_936, _936), 4.0);
    float _940 = (0.4000000059604644775390625 * _938) - 1.0;
    float _942 = (0.25 * _938) - 1.0;
    float _948 = float(all(uint2(_811) < _901)) * ((((1.5625 * _940) * _940) - 0.5625) * (_942 * _942));
    float _957 = exp(_896 * dot(_931, _931));
    float3 _960 = _817 * _957;
    float2 _967 = _877 + (_797 + float2(_819));
    float2 _972 = _967 * _905;
    float _974 = precise::min(dot(_972, _972), 4.0);
    float _976 = (0.4000000059604644775390625 * _974) - 1.0;
    float _978 = (0.25 * _974) - 1.0;
    float _984 = float(all(uint2(_820) < _901)) * ((((1.5625 * _976) * _976) - 0.5625) * (_978 * _978));
    float _993 = exp(_896 * dot(_967, _967));
    float3 _996 = _826 * _993;
    float2 _1003 = _877 + (_797 + float2(_828));
    float2 _1008 = _1003 * _905;
    float _1010 = precise::min(dot(_1008, _1008), 4.0);
    float _1012 = (0.4000000059604644775390625 * _1010) - 1.0;
    float _1014 = (0.25 * _1010) - 1.0;
    float _1020 = float(all(uint2(_829) < _901)) * ((((1.5625 * _1012) * _1012) - 0.5625) * (_1014 * _1014));
    float _1029 = exp(_896 * dot(_1003, _1003));
    float3 _1032 = _835 * _1029;
    float2 _1039 = _877 + (_797 + float2(_836));
    float2 _1044 = _1039 * _905;
    float _1046 = precise::min(dot(_1044, _1044), 4.0);
    float _1048 = (0.4000000059604644775390625 * _1046) - 1.0;
    float _1050 = (0.25 * _1046) - 1.0;
    float _1056 = float(all(uint2(_837) < _901)) * ((((1.5625 * _1048) * _1048) - 0.5625) * (_1050 * _1050));
    float _1065 = exp(_896 * dot(_1039, _1039));
    float3 _1068 = _843 * _1065;
    float2 _1075 = _877 + (_797 + float2(_844));
    float2 _1080 = _1075 * _905;
    float _1082 = precise::min(dot(_1080, _1080), 4.0);
    float _1084 = (0.4000000059604644775390625 * _1082) - 1.0;
    float _1086 = (0.25 * _1082) - 1.0;
    float _1092 = float(all(uint2(_845) < _901)) * ((((1.5625 * _1084) * _1084) - 0.5625) * (_1086 * _1086));
    float _1101 = exp(_896 * dot(_1075, _1075));
    float3 _1104 = _851 * _1101;
    float2 _1111 = _877 + (_797 + float2(_853));
    float2 _1116 = _1111 * _905;
    float _1118 = precise::min(dot(_1116, _1116), 4.0);
    float _1120 = (0.4000000059604644775390625 * _1118) - 1.0;
    float _1122 = (0.25 * _1118) - 1.0;
    float _1128 = float(all(uint2(_854) < _901)) * ((((1.5625 * _1120) * _1120) - 0.5625) * (_1122 * _1122));
    float _1137 = exp(_896 * dot(_1111, _1111));
    float3 _1140 = _860 * _1137;
    float2 _1147 = _877 + (_797 + float2(_861));
    float2 _1152 = _1147 * _905;
    float _1154 = precise::min(dot(_1152, _1152), 4.0);
    float _1156 = (0.4000000059604644775390625 * _1154) - 1.0;
    float _1158 = (0.25 * _1154) - 1.0;
    float _1164 = float(all(uint2(_862) < _901)) * ((((1.5625 * _1156) * _1156) - 0.5625) * (_1158 * _1158));
    float _1173 = exp(_896 * dot(_1147, _1147));
    float3 _1176 = _868 * _1173;
    float2 _1183 = _877 + (_797 + float2(_869));
    float2 _1188 = _1183 * _905;
    float _1190 = precise::min(dot(_1188, _1188), 4.0);
    float _1192 = (0.4000000059604644775390625 * _1190) - 1.0;
    float _1194 = (0.25 * _1190) - 1.0;
    float _1200 = float(all(uint2(_870) < _901)) * ((((1.5625 * _1192) * _1192) - 0.5625) * (_1194 * _1194));
    float4 _1206 = (((((((float4(_808 * _918, _918) + float4(_817 * _948, _948)) + float4(_826 * _984, _984)) + float4(_835 * _1020, _1020)) + float4(_843 * _1056, _1056)) + float4(_851 * _1092, _1092)) + float4(_860 * _1128, _1128)) + float4(_868 * _1164, _1164)) + float4(_876 * _1200, _1200);
    float _1209 = exp(_896 * dot(_1183, _1183));
    float3 _1210 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_808, _817), _826), _835), _843), _851), _860), _868), _876);
    float3 _1211 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_808, _817), _826), _835), _843), _851), _860), _868), _876);
    float3 _1212 = _876 * _1209;
    float _1216 = (((((((_926 + _957) + _993) + _1029) + _1065) + _1101) + _1137) + _1173) + _1209;
    float3 _1220 = float3((abs(_1216) > 0.001000000047497451305389404296875) ? _1216 : 1.0);
    float3 _1221 = ((((((((_927 + _960) + _996) + _1032) + _1068) + _1104) + _1140) + _1176) + _1212) / _1220;
    float3 _1226 = sqrt(abs(((((((((((_808 * _927) + (_817 * _960)) + (_826 * _996)) + (_835 * _1032)) + (_843 * _1068)) + (_851 * _1104)) + (_860 * _1140)) + (_868 * _1176)) + (_876 * _1212)) / _1220) - (_1221 * _1221)));
    float _1230 = _1206.w * float(_1206.w > 0.001000000047497451305389404296875);
    float4 _1231 = _1206;
    _1231.w = _1230;
    float4 _1244;
    if (_1230 > 0.001000000047497451305389404296875)
    {
        float3 _1237 = _1231.xyz / float3(_1230);
        float4 _1238 = float4(_1237.x, _1237.y, _1237.z, _1231.w);
        _1238.w = _1230 * 0.083333335816860198974609375;
        float3 _1242 = fast::clamp(_1238.xyz, _1210, _1211);
        _1244 = float4(_1242.x, _1242.y, _1242.z, _1238.w);
    }
    else
    {
        _1244 = _1231;
    }
    float _1248 = rint(_1221.x * 255.0) * 0.0039215688593685626983642578125;
    bool _1255;
    if (precise::max(precise::max(_214, _220), _729) < 0.100000001490116119384765625)
    {
        _1255 = !_224;
    }
    else
    {
        _1255 = false;
    }
    float4 _1263;
    if (_1255)
    {
        _1263 = r_luma_history.sample(s_LinearClamp, _193, level(0.0));
    }
    else
    {
        _1263 = float4(0.0);
    }
    float4 _147 = _1263;
    float _1266 = _1248 - _147.x;
    float _1267 = abs(_1266);
    float _1306;
    if (_1267 >= 0.0039215688593685626983642578125)
    {
        float _1272;
        _1272 = _1267;
        float _1273;
        for (int _1275 = 1; _1275 <= 3; _1272 = _1273, _1275++)
        {
            float _1283 = _1248 - _147[uint(_1275)];
            if (int(sign(_1266)) == int(sign(_1283)))
            {
                _1273 = precise::min(_1272, abs(_1283));
            }
            else
            {
                _1273 = _1272;
            }
        }
        _1306 = float((float(_1272 != _1267) * powr(fast::clamp(_1226.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_220, powr(_754, 0.16666667163372039794921875)));
    }
    else
    {
        _1306 = 0.0;
    }
    _147.w = _147.z;
    _147.z = _147.y;
    _147.y = _147.x;
    _147.x = _1248;
    sdk_hlsl_store(rw_luma_history, _147, uint2(_163));
    float _1323 = (float(_208) * _755) * (1.0 - _214);
    float _1327 = fast::clamp(_192 * 10.0, 0.0, 1.0);
    float _1330 = precise::min(_1323, mix(_1323, _1244.w * 10.0, precise::max(float(_681), _1327)));
    float _1332 = fast::clamp(_192 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1335 = float3(precise::min(_1330, mix(_1330, _1244.w, _1332)));
    float3 _1400;
    if (_224)
    {
        _1400 = float3((_1244.x + _1244.y) - _1244.z, _1244.x + _1244.z, (_1244.x - _1244.y) - _1244.z);
    }
    else
    {
        float3 _1349 = _1226 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_214, precise::max(_220, _1332)));
        float3 _1352 = precise::max(_1210, _1221 - _1349);
        float3 _1353 = precise::min(_1211, _1221 + _1349);
        bool _1361;
        if (!any(_1352 > _680))
        {
            _1361 = any(_680 > _1353);
        }
        else
        {
            _1361 = true;
        }
        float3 _1374;
        float3 _1375;
        if (_1361)
        {
            float3 _1370 = fast::clamp(float3(precise::max(_1306 * float(_147.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_763 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_774, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_219, 0.5)), float3(0.0), float3(1.0));
            _1374 = mix(fast::clamp(_680, _1352, _1353), _680, _1370);
            _1375 = mix(precise::min(_1335, float3(0.100000001490116119384765625)), _1335, _1370);
        }
        else
        {
            _1374 = _680;
            _1375 = _1335;
        }
        float3 _1381 = mix(_1374, _1244.xyz, _1244.www / precise::max(float3(0.001000000047497451305389404296875), _1375 + _1244.www));
        float _1382 = _1381.x;
        float _1383 = _1381.y;
        float _1385 = _1381.z;
        _1400 = float3((_1382 + _1383) - _1385, _1382 + _1385, (_1382 - _1383) - _1385);
    }
    float4 _1402 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1403 = _1402.x;
    float2 _1411 = _168 - _190;
    float _1412 = _1411.x;
    bool _1417;
    if (_1412 >= 0.0)
    {
        _1417 = _1412 <= 1.0;
    }
    else
    {
        _1417 = false;
    }
    bool _1426;
    if (_1417)
    {
        float _1420 = _1411.y;
        bool _1425;
        if (_1420 >= 0.0)
        {
            _1425 = _1420 <= 1.0;
        }
        else
        {
            _1425 = false;
        }
        _1426 = _1425;
    }
    else
    {
        _1426 = false;
    }
    float2 _1439;
    if (!_1426)
    {
        float2 _1438 = _750;
        _1438.x = 0.0;
        _1439 = _1438;
    }
    else
    {
        float2 _1437 = _750;
        _1437.x = precise::max(0.0, _763 - (_1244.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1439 = _1437;
    }
    sdk_hlsl_store(rw_lock_status, _1439.xyyy, uint2(_163));
    float _1441 = precise::min(0.9900000095367431640625, _754);
    float _1444 = precise::max(_1441, mix(_1441, 0.4000000059604644775390625, fast::clamp(_192, 0.0, 1.0)));
    float _1449 = _224 ? 1.0 : precise::max(_1444 * _1444, precise::max(_214 * 0.100000001490116119384765625, _219));
    float _1455;
    if (_1327 >= 1.0)
    {
        _1455 = precise::max(0.001000000047497451305389404296875, _1449) * (-1.0);
    }
    else
    {
        _1455 = _1449;
    }
    sdk_hlsl_store(rw_internal_upscaled_color, float4((_1400 / float3((_1403 == 0.0) ? 1.0 : _1403)) * cbFSR2.fPreExposure, _1455), uint2(_163));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_163));
}

