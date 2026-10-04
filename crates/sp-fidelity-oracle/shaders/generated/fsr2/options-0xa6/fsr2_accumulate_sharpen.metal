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

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_exposure [[texture(0)]], texture2d<float> r_dilated_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float> r_lock_status [[texture(3)]], texture2d<float> r_prepared_input_color [[texture(4)]], texture2d<float> r_luma_history [[texture(5)]], texture2d<float> r_imgMips [[texture(6)]], texture2d<float> r_dilated_reactive_masks [[texture(7)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(8)]], texture2d<float, access::write> rw_lock_status [[texture(9)]], texture2d<float, access::read_write> rw_new_locks [[texture(10)]], texture2d<float, access::write> rw_luma_history [[texture(11)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _152 = gl_WorkGroupID.xy;
    _152.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _166 = (_152 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _169 = float2(int2(_166)) + float2(0.5);
    float2 _170 = float2(cbFSR2.iDisplaySize);
    float2 _171 = _169 / _170;
    float2 _176 = float2(cbFSR2.iRenderSize);
    float2 _186 = precise::max(float2(0.5), precise::min((_171 + (cbFSR2.fJitter / _176)) * _176, _176 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _193 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_171 * _176)))), 0u).xy;
    float _195 = length(_193 * _170);
    float2 _196 = _171 + _193;
    float _197 = _196.x;
    bool _202;
    if (_197 >= 0.0)
    {
        _202 = _197 <= 1.0;
    }
    else
    {
        _202 = false;
    }
    bool _211;
    if (_202)
    {
        float _205 = _196.y;
        bool _210;
        if (_205 >= 0.0)
        {
            _210 = _205 <= 1.0;
        }
        else
        {
            _210 = false;
        }
        _211 = _210;
    }
    else
    {
        _211 = false;
    }
    float _217 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _186, level(0.0)).w, 0.0, 1.0);
    float4 _221 = r_dilated_reactive_masks.sample(s_LinearClamp, _186, level(0.0));
    float _222 = _221.x;
    float _223 = _221.y;
    bool _226 = 0 == cbFSR2.iFrameIndex;
    bool _227 = _211 ? _226 : true;
    bool _231;
    if (_211)
    {
        _231 = !_226;
    }
    else
    {
        _231 = false;
    }
    float2 _810;
    float3 _811;
    bool _812;
    bool _813;
    float _814;
    if (_231)
    {
        float2 _235 = (_196 * _170) - float2(0.5);
        float2 _245 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _235.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _235.y)));
        float2 _246 = floor(_245);
        int2 _247 = int2(_246);
        half2 _249 = half2(_245 - _246);
        int2 _250 = _247 + int2(-1);
        int _254 = max(_250.y, 0);
        int2 _255 = int2(max(_250.x, 0), _254);
        _255.y = _254;
        int2 _261 = _247 + int2(0, -1);
        int _264 = max(_261.y, 0);
        int2 _265 = int2(_261.x, _264);
        _265.y = _264;
        int2 _271 = _247 + int2(1, -1);
        int _273 = cbFSR2.iDisplaySize.x - 1;
        int _276 = max(_271.y, 0);
        int2 _277 = int2(min(_271.x, _273), _276);
        _277.y = _276;
        int2 _283 = _247 + int2(2, -1);
        int _287 = max(_283.y, 0);
        int2 _288 = int2(min(_283.x, _273), _287);
        _288.y = _287;
        int2 _294 = _247 + int2(-1, 0);
        int _297 = _294.y;
        int2 _298 = int2(max(_294.x, 0), _297);
        _298.y = _297;
        int2 _305 = _247;
        _305.y = _247.y;
        half4 _309 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_305)), 0u));
        int2 _310 = _247 + int2(1, 0);
        int _313 = _310.y;
        int2 _314 = int2(min(_310.x, _273), _313);
        _314.y = _313;
        half4 _319 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_314)), 0u));
        int2 _320 = _247 + int2(2, 0);
        int _323 = _320.y;
        int2 _324 = int2(min(_320.x, _273), _323);
        _324.y = _323;
        int2 _330 = _247 + int2(-1, 1);
        int _333 = _330.y;
        int2 _334 = int2(max(_330.x, 0), _333);
        int _335 = cbFSR2.iDisplaySize.y - 1;
        _334.y = min(_333, _335);
        int2 _342 = _247 + int2(0, 1);
        _342.y = min(_342.y, _335);
        half4 _349 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_342)), 0u));
        int2 _350 = _247 + int2(1);
        int _353 = _350.y;
        int2 _354 = int2(min(_350.x, _273), _353);
        _354.y = min(_353, _335);
        half4 _360 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_354)), 0u));
        int2 _361 = _247 + int2(2, 1);
        int _364 = _361.y;
        int2 _365 = int2(min(_361.x, _273), _364);
        _365.y = min(_364, _335);
        int2 _372 = _247 + int2(-1, 2);
        int _375 = _372.y;
        int2 _376 = int2(max(_372.x, 0), _375);
        _376.y = min(_375, _335);
        int2 _383 = _247 + int2(0, 2);
        _383.y = min(_383.y, _335);
        int2 _391 = _247 + int2(1, 2);
        int _394 = _391.y;
        int2 _395 = int2(min(_391.x, _273), _394);
        _395.y = min(_394, _335);
        int2 _402 = _247 + int2(2);
        int _405 = _402.y;
        int2 _406 = int2(min(_402.x, _273), _405);
        _406.y = min(_405, _335);
        half _413 = _249.x;
        float _417 = float(min(abs(half(-1.0) - _413), half(2.0)));
        bool _419 = abs(_417) < 0.001000000047497451305389404296875;
        float _430;
        if (_419)
        {
            _430 = 1.0;
        }
        else
        {
            float _423 = 3.1415927410125732421875 * _417;
            float _426 = 1.57079637050628662109375 * _417;
            _430 = (sin(_423) / _423) * (sin(_426) / _426);
        }
        half _431 = half(_430);
        float _435 = float(min(abs(half(-0.0) - _413), half(2.0)));
        bool _437 = abs(_435) < 0.001000000047497451305389404296875;
        float _448;
        if (_437)
        {
            _448 = 1.0;
        }
        else
        {
            float _441 = 3.1415927410125732421875 * _435;
            float _444 = 1.57079637050628662109375 * _435;
            _448 = (sin(_441) / _441) * (sin(_444) / _444);
        }
        half _449 = half(_448);
        float _453 = float(min(abs(half(1.0) - _413), half(2.0)));
        bool _455 = abs(_453) < 0.001000000047497451305389404296875;
        float _466;
        if (_455)
        {
            _466 = 1.0;
        }
        else
        {
            float _459 = 3.1415927410125732421875 * _453;
            float _462 = 1.57079637050628662109375 * _453;
            _466 = (sin(_459) / _459) * (sin(_462) / _462);
        }
        half _467 = half(_466);
        float _471 = float(min(abs(half(2.0) - _413), half(2.0)));
        bool _473 = abs(_471) < 0.001000000047497451305389404296875;
        float _484;
        if (_473)
        {
            _484 = 1.0;
        }
        else
        {
            float _477 = 3.1415927410125732421875 * _471;
            float _480 = 1.57079637050628662109375 * _471;
            _484 = (sin(_477) / _477) * (sin(_480) / _480);
        }
        half _485 = half(_484);
        float _508;
        if (_419)
        {
            _508 = 1.0;
        }
        else
        {
            float _501 = 3.1415927410125732421875 * _417;
            float _504 = 1.57079637050628662109375 * _417;
            _508 = (sin(_501) / _501) * (sin(_504) / _504);
        }
        half _509 = half(_508);
        float _520;
        if (_437)
        {
            _520 = 1.0;
        }
        else
        {
            float _513 = 3.1415927410125732421875 * _435;
            float _516 = 1.57079637050628662109375 * _435;
            _520 = (sin(_513) / _513) * (sin(_516) / _516);
        }
        half _521 = half(_520);
        float _532;
        if (_455)
        {
            _532 = 1.0;
        }
        else
        {
            float _525 = 3.1415927410125732421875 * _453;
            float _528 = 1.57079637050628662109375 * _453;
            _532 = (sin(_525) / _525) * (sin(_528) / _528);
        }
        half _533 = half(_532);
        float _544;
        if (_473)
        {
            _544 = 1.0;
        }
        else
        {
            float _537 = 3.1415927410125732421875 * _471;
            float _540 = 1.57079637050628662109375 * _471;
            _544 = (sin(_537) / _537) * (sin(_540) / _540);
        }
        half _545 = half(_544);
        float _568;
        if (_419)
        {
            _568 = 1.0;
        }
        else
        {
            float _561 = 3.1415927410125732421875 * _417;
            float _564 = 1.57079637050628662109375 * _417;
            _568 = (sin(_561) / _561) * (sin(_564) / _564);
        }
        half _569 = half(_568);
        float _580;
        if (_437)
        {
            _580 = 1.0;
        }
        else
        {
            float _573 = 3.1415927410125732421875 * _435;
            float _576 = 1.57079637050628662109375 * _435;
            _580 = (sin(_573) / _573) * (sin(_576) / _576);
        }
        half _581 = half(_580);
        float _592;
        if (_455)
        {
            _592 = 1.0;
        }
        else
        {
            float _585 = 3.1415927410125732421875 * _453;
            float _588 = 1.57079637050628662109375 * _453;
            _592 = (sin(_585) / _585) * (sin(_588) / _588);
        }
        half _593 = half(_592);
        float _604;
        if (_473)
        {
            _604 = 1.0;
        }
        else
        {
            float _597 = 3.1415927410125732421875 * _471;
            float _600 = 1.57079637050628662109375 * _471;
            _604 = (sin(_597) / _597) * (sin(_600) / _600);
        }
        half _605 = half(_604);
        float _628;
        if (_419)
        {
            _628 = 1.0;
        }
        else
        {
            float _621 = 3.1415927410125732421875 * _417;
            float _624 = 1.57079637050628662109375 * _417;
            _628 = (sin(_621) / _621) * (sin(_624) / _624);
        }
        half _629 = half(_628);
        float _640;
        if (_437)
        {
            _640 = 1.0;
        }
        else
        {
            float _633 = 3.1415927410125732421875 * _435;
            float _636 = 1.57079637050628662109375 * _435;
            _640 = (sin(_633) / _633) * (sin(_636) / _636);
        }
        half _641 = half(_640);
        float _652;
        if (_455)
        {
            _652 = 1.0;
        }
        else
        {
            float _645 = 3.1415927410125732421875 * _453;
            float _648 = 1.57079637050628662109375 * _453;
            _652 = (sin(_645) / _645) * (sin(_648) / _648);
        }
        half _653 = half(_652);
        float _664;
        if (_473)
        {
            _664 = 1.0;
        }
        else
        {
            float _657 = 3.1415927410125732421875 * _471;
            float _660 = 1.57079637050628662109375 * _471;
            _664 = (sin(_657) / _657) * (sin(_660) / _660);
        }
        half _665 = half(_664);
        half _678 = _249.y;
        float _682 = float(min(abs(half(-1.0) - _678), half(2.0)));
        float _695;
        if (abs(_682) < 0.001000000047497451305389404296875)
        {
            _695 = 1.0;
        }
        else
        {
            float _688 = 3.1415927410125732421875 * _682;
            float _691 = 1.57079637050628662109375 * _682;
            _695 = (sin(_688) / _688) * (sin(_691) / _691);
        }
        half _696 = half(_695);
        float _700 = float(min(abs(half(-0.0) - _678), half(2.0)));
        float _713;
        if (abs(_700) < 0.001000000047497451305389404296875)
        {
            _713 = 1.0;
        }
        else
        {
            float _706 = 3.1415927410125732421875 * _700;
            float _709 = 1.57079637050628662109375 * _700;
            _713 = (sin(_706) / _706) * (sin(_709) / _709);
        }
        half _714 = half(_713);
        float _718 = float(min(abs(half(1.0) - _678), half(2.0)));
        float _731;
        if (abs(_718) < 0.001000000047497451305389404296875)
        {
            _731 = 1.0;
        }
        else
        {
            float _724 = 3.1415927410125732421875 * _718;
            float _727 = 1.57079637050628662109375 * _718;
            _731 = (sin(_724) / _724) * (sin(_727) / _727);
        }
        half _732 = half(_731);
        float _736 = float(min(abs(half(2.0) - _678), half(2.0)));
        float _749;
        if (abs(_736) < 0.001000000047497451305389404296875)
        {
            _749 = 1.0;
        }
        else
        {
            float _742 = 3.1415927410125732421875 * _736;
            float _745 = 1.57079637050628662109375 * _736;
            _749 = (sin(_742) / _742) * (sin(_745) / _745);
        }
        half _750 = half(_749);
        half4 _757 = ((((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_255)), 0u)) * _431) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_265)), 0u)) * _449)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_277)), 0u)) * _467)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_288)), 0u)) * _485)) / half4(((_431 + _449) + _467) + _485)) * _696) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_298)), 0u)) * _509) + (_309 * _521)) + (_319 * _533)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_324)), 0u)) * _545)) / half4(((_509 + _521) + _533) + _545)) * _714)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_334)), 0u)) * _569) + (_349 * _581)) + (_360 * _593)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_365)), 0u)) * _605)) / half4(((_569 + _581) + _593) + _605)) * _732)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_376)), 0u)) * _629) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_383)), 0u)) * _641)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_395)), 0u)) * _653)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_406)), 0u)) * _665)) / half4(((_629 + _641) + _653) + _665)) * _750);
        float4 _770 = float4(clamp(_757 / half4(((_696 + _714) + _732) + _750), min(min(min(_309, _319), _349), _360), max(max(max(_309, _319), _349), _360)));
        float4 _773 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _774 = _773.x;
        float3 _782 = fast::clamp((_770.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_774 == 0.0) ? 1.0 : _774), float3(0.0), float3(65504.0));
        float _783 = _782.x;
        float _786 = 0.5 * _782.y;
        float _788 = _782.z;
        float _789 = 0.25 * _788;
        float _797 = _770.w;
        spvImageFence(rw_new_locks);
        _810 = r_lock_status.sample(s_LinearClamp, _196, level(0.0)).xy;
        _811 = float3(((0.25 * _783) + _786) + _789, 0.5 * (_783 - _788), (((-0.25) * _783) + _786) - _789);
        _812 = _797 < 0.0;
        _813 = sdk_hlsl_load(rw_new_locks, uint2(_166)).x > 0.4980392158031463623046875;
        _814 = fast::clamp(abs(_797), 0.0, 1.0);
    }
    else
    {
        _810 = float2(0.0);
        _811 = float3(0.0);
        _812 = false;
        _813 = false;
        _814 = 0.0;
    }
    float2 _826 = float2(int2(_176 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _834 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _835 = _834.x;
    float _847 = powr(((_835 == 0.0) ? 1.0 : _835) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_171 * _826, _826 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _850 = (_810.y == 0.0) ? _847 : _810.y;
    float2 _851 = _810;
    _851.y = _850;
    float _852 = precise::max(_850, _847);
    float _859;
    if (_852 != 0.0)
    {
        _859 = precise::min(_850, _847) / _852;
    }
    else
    {
        _859 = 0.0;
    }
    float _860 = 1.0 - _859;
    float2 _881;
    if (_813)
    {
        _881 = float2((_810.x != 0.0) ? 2.0 : 1.0, _847);
    }
    else
    {
        float2 _876;
        if (_810.x <= 1.0)
        {
            float2 _875 = _851;
            _875.y = mix(_850, _847, 0.5);
            _876 = _875;
        }
        else
        {
            float2 _873;
            if (_860 > 0.100000001490116119384765625)
            {
                _873 = float2(0.0, _850);
            }
            else
            {
                _873 = _851;
            }
            _876 = _873;
        }
        _881 = _876;
    }
    float _885 = precise::max(precise::max(_222, _814), fast::clamp((0.89999997615814208984375 - _859) * 10.0, 0.0, 1.0));
    float _886 = 1.0 - _885;
    float _894 = ((_881.x * _886) * fast::clamp(1.0 - _223, 0.0, 1.0)) * float(_217 < 0.100000001490116119384765625);
    float _898 = precise::max(_881.y, _847);
    float _905;
    if (_898 != 0.0)
    {
        _905 = precise::min(_881.y, _847) / _898;
    }
    else
    {
        _905 = 0.0;
    }
    float2 _913 = _169 * cbFSR2.fDownscaleFactor;
    int2 _915 = int2(floor(_913));
    float2 _918 = (float2(_915) + float2(0.5)) - cbFSR2.fJitter;
    bool _921 = _918.x > _913.x;
    bool _925 = _918.y > _913.y;
    int2 _927 = int2(_921 ? (-2) : (-1), _925 ? (-2) : (-1));
    float2 _928 = float2(_927);
    int _929 = _921 ? 3 : 0;
    int _930 = _925 ? 3 : 0;
    int2 _931 = int2(_929, _930);
    int2 _932 = _915 + _927;
    int2 _933 = _932 + _931;
    int2 _935 = _933;
    _935.y = _933.y;
    float3 _939 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_935)), 0u).xyz;
    int _940 = _921 ? 2 : 1;
    int2 _941 = int2(_940, _930);
    int2 _942 = _932 + _941;
    int2 _944 = _942;
    _944.y = _942.y;
    float3 _948 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_944)), 0u).xyz;
    int _949 = _921 ? 1 : 2;
    int2 _950 = int2(_949, _930);
    int2 _951 = _932 + _950;
    int2 _953 = _951;
    _953.y = _951.y;
    float3 _957 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_953)), 0u).xyz;
    int _958 = _925 ? 2 : 1;
    int2 _959 = int2(_929, _958);
    int2 _960 = _932 + _959;
    int2 _962 = _960;
    _962.y = _960.y;
    float3 _966 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_962)), 0u).xyz;
    int2 _967 = int2(_940, _958);
    int2 _968 = _932 + _967;
    int2 _970 = _968;
    _970.y = _968.y;
    float3 _974 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_970)), 0u).xyz;
    int2 _975 = int2(_949, _958);
    int2 _976 = _932 + _975;
    int2 _978 = _976;
    _978.y = _976.y;
    float3 _982 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_978)), 0u).xyz;
    int _983 = _925 ? 1 : 2;
    int2 _984 = int2(_929, _983);
    int2 _985 = _932 + _984;
    int2 _987 = _985;
    _987.y = _985.y;
    float3 _991 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_987)), 0u).xyz;
    int2 _992 = int2(_940, _983);
    int2 _993 = _932 + _992;
    int2 _995 = _993;
    _995.y = _993.y;
    float3 _999 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_995)), 0u).xyz;
    int2 _1000 = int2(_949, _983);
    int2 _1001 = _932 + _1000;
    int2 _1003 = _1001;
    _1003.y = _1001.y;
    float3 _1007 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_1003)), 0u).xyz;
    float2 _1008 = _918 - _913;
    float _1010 = precise::max(_885, float(_227));
    float _1017 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _1010);
    float _1027 = mix(-2.0, -3.0, fast::clamp(_195 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _1030 = _1008 + (_928 + float2(_931));
    uint2 _1032 = uint2(cbFSR2.iRenderSize);
    float2 _1036 = float2(mix(_1017, precise::max(1.0, (1.0 + _1017) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _217, _1010))));
    float2 _1037 = _1030 * _1036;
    float _1039 = precise::min(dot(_1037, _1037), 4.0);
    float _1041 = (0.4000000059604644775390625 * _1039) - 1.0;
    float _1043 = (0.25 * _1039) - 1.0;
    float _1049 = float(all(uint2(_933) < _1032)) * ((((1.5625 * _1041) * _1041) - 0.5625) * (_1043 * _1043));
    float _1057 = exp(_1027 * dot(_1030, _1030));
    float3 _1058 = _939 * _1057;
    float2 _1062 = _1008 + (_928 + float2(_941));
    float2 _1067 = _1062 * _1036;
    float _1069 = precise::min(dot(_1067, _1067), 4.0);
    float _1071 = (0.4000000059604644775390625 * _1069) - 1.0;
    float _1073 = (0.25 * _1069) - 1.0;
    float _1079 = float(all(uint2(_942) < _1032)) * ((((1.5625 * _1071) * _1071) - 0.5625) * (_1073 * _1073));
    float _1088 = exp(_1027 * dot(_1062, _1062));
    float3 _1091 = _948 * _1088;
    float2 _1098 = _1008 + (_928 + float2(_950));
    float2 _1103 = _1098 * _1036;
    float _1105 = precise::min(dot(_1103, _1103), 4.0);
    float _1107 = (0.4000000059604644775390625 * _1105) - 1.0;
    float _1109 = (0.25 * _1105) - 1.0;
    float _1115 = float(all(uint2(_951) < _1032)) * ((((1.5625 * _1107) * _1107) - 0.5625) * (_1109 * _1109));
    float _1124 = exp(_1027 * dot(_1098, _1098));
    float3 _1127 = _957 * _1124;
    float2 _1134 = _1008 + (_928 + float2(_959));
    float2 _1139 = _1134 * _1036;
    float _1141 = precise::min(dot(_1139, _1139), 4.0);
    float _1143 = (0.4000000059604644775390625 * _1141) - 1.0;
    float _1145 = (0.25 * _1141) - 1.0;
    float _1151 = float(all(uint2(_960) < _1032)) * ((((1.5625 * _1143) * _1143) - 0.5625) * (_1145 * _1145));
    float _1160 = exp(_1027 * dot(_1134, _1134));
    float3 _1163 = _966 * _1160;
    float2 _1170 = _1008 + (_928 + float2(_967));
    float2 _1175 = _1170 * _1036;
    float _1177 = precise::min(dot(_1175, _1175), 4.0);
    float _1179 = (0.4000000059604644775390625 * _1177) - 1.0;
    float _1181 = (0.25 * _1177) - 1.0;
    float _1187 = float(all(uint2(_968) < _1032)) * ((((1.5625 * _1179) * _1179) - 0.5625) * (_1181 * _1181));
    float _1196 = exp(_1027 * dot(_1170, _1170));
    float3 _1199 = _974 * _1196;
    float2 _1206 = _1008 + (_928 + float2(_975));
    float2 _1211 = _1206 * _1036;
    float _1213 = precise::min(dot(_1211, _1211), 4.0);
    float _1215 = (0.4000000059604644775390625 * _1213) - 1.0;
    float _1217 = (0.25 * _1213) - 1.0;
    float _1223 = float(all(uint2(_976) < _1032)) * ((((1.5625 * _1215) * _1215) - 0.5625) * (_1217 * _1217));
    float _1232 = exp(_1027 * dot(_1206, _1206));
    float3 _1235 = _982 * _1232;
    float2 _1242 = _1008 + (_928 + float2(_984));
    float2 _1247 = _1242 * _1036;
    float _1249 = precise::min(dot(_1247, _1247), 4.0);
    float _1251 = (0.4000000059604644775390625 * _1249) - 1.0;
    float _1253 = (0.25 * _1249) - 1.0;
    float _1259 = float(all(uint2(_985) < _1032)) * ((((1.5625 * _1251) * _1251) - 0.5625) * (_1253 * _1253));
    float _1268 = exp(_1027 * dot(_1242, _1242));
    float3 _1271 = _991 * _1268;
    float2 _1278 = _1008 + (_928 + float2(_992));
    float2 _1283 = _1278 * _1036;
    float _1285 = precise::min(dot(_1283, _1283), 4.0);
    float _1287 = (0.4000000059604644775390625 * _1285) - 1.0;
    float _1289 = (0.25 * _1285) - 1.0;
    float _1295 = float(all(uint2(_993) < _1032)) * ((((1.5625 * _1287) * _1287) - 0.5625) * (_1289 * _1289));
    float _1304 = exp(_1027 * dot(_1278, _1278));
    float3 _1307 = _999 * _1304;
    float2 _1314 = _1008 + (_928 + float2(_1000));
    float2 _1319 = _1314 * _1036;
    float _1321 = precise::min(dot(_1319, _1319), 4.0);
    float _1323 = (0.4000000059604644775390625 * _1321) - 1.0;
    float _1325 = (0.25 * _1321) - 1.0;
    float _1331 = float(all(uint2(_1001) < _1032)) * ((((1.5625 * _1323) * _1323) - 0.5625) * (_1325 * _1325));
    float4 _1337 = (((((((float4(_939 * _1049, _1049) + float4(_948 * _1079, _1079)) + float4(_957 * _1115, _1115)) + float4(_966 * _1151, _1151)) + float4(_974 * _1187, _1187)) + float4(_982 * _1223, _1223)) + float4(_991 * _1259, _1259)) + float4(_999 * _1295, _1295)) + float4(_1007 * _1331, _1331);
    float _1340 = exp(_1027 * dot(_1314, _1314));
    float3 _1341 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_939, _948), _957), _966), _974), _982), _991), _999), _1007);
    float3 _1342 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_939, _948), _957), _966), _974), _982), _991), _999), _1007);
    float3 _1343 = _1007 * _1340;
    float _1347 = (((((((_1057 + _1088) + _1124) + _1160) + _1196) + _1232) + _1268) + _1304) + _1340;
    float3 _1351 = float3((abs(_1347) > 0.001000000047497451305389404296875) ? _1347 : 1.0);
    float3 _1352 = ((((((((_1058 + _1091) + _1127) + _1163) + _1199) + _1235) + _1271) + _1307) + _1343) / _1351;
    float3 _1357 = sqrt(abs(((((((((((_939 * _1058) + (_948 * _1091)) + (_957 * _1127)) + (_966 * _1163)) + (_974 * _1199)) + (_982 * _1235)) + (_991 * _1271)) + (_999 * _1307)) + (_1007 * _1343)) / _1351) - (_1352 * _1352)));
    float _1361 = _1337.w * float(_1337.w > 0.001000000047497451305389404296875);
    float4 _1362 = _1337;
    _1362.w = _1361;
    float4 _1375;
    if (_1361 > 0.001000000047497451305389404296875)
    {
        float3 _1368 = _1362.xyz / float3(_1361);
        float4 _1369 = float4(_1368.x, _1368.y, _1368.z, _1362.w);
        _1369.w = _1361 * 0.083333335816860198974609375;
        float3 _1373 = fast::clamp(_1369.xyz, _1341, _1342);
        _1375 = float4(_1373.x, _1373.y, _1373.z, _1369.w);
    }
    else
    {
        _1375 = _1362;
    }
    float _1376 = _1352.x;
    float _1382 = rint((_1376 / (1.0 + precise::max(0.0, _1376))) * 255.0) * 0.0039215688593685626983642578125;
    bool _1389;
    if (precise::max(precise::max(_217, _223), _860) < 0.100000001490116119384765625)
    {
        _1389 = !_227;
    }
    else
    {
        _1389 = false;
    }
    float4 _1397;
    if (_1389)
    {
        _1397 = r_luma_history.sample(s_LinearClamp, _196, level(0.0));
    }
    else
    {
        _1397 = float4(0.0);
    }
    float4 _150 = _1397;
    float _1400 = _1382 - _150.x;
    float _1401 = abs(_1400);
    float _1440;
    if (_1401 >= 0.0039215688593685626983642578125)
    {
        float _1406;
        _1406 = _1401;
        float _1407;
        for (int _1409 = 1; _1409 <= 3; _1406 = _1407, _1409++)
        {
            float _1417 = _1382 - _150[uint(_1409)];
            if (int(sign(_1400)) == int(sign(_1417)))
            {
                _1407 = precise::min(_1406, abs(_1417));
            }
            else
            {
                _1407 = _1406;
            }
        }
        _1440 = float((float(_1406 != _1401) * powr(fast::clamp(_1357.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_223, powr(_885, 0.16666667163372039794921875)));
    }
    else
    {
        _1440 = 0.0;
    }
    _150.w = _150.z;
    _150.z = _150.y;
    _150.y = _150.x;
    _150.x = _1382;
    sdk_hlsl_store(rw_luma_history, _150, uint2(_166));
    float _1457 = (float(_211) * _886) * (1.0 - _217);
    float _1461 = fast::clamp(_195 * 10.0, 0.0, 1.0);
    float _1464 = precise::min(_1457, mix(_1457, _1375.w * 10.0, precise::max(float(_812), _1461)));
    float _1466 = fast::clamp(_195 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1469 = float3(precise::min(_1464, mix(_1464, _1375.w, _1466)));
    float3 _1599;
    if (_227)
    {
        _1599 = float3((_1375.x + _1375.y) - _1375.z, _1375.x + _1375.z, (_1375.x - _1375.y) - _1375.z);
    }
    else
    {
        float3 _1483 = _1357 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_217, precise::max(_223, _1466)));
        float3 _1486 = precise::max(_1341, _1352 - _1483);
        float3 _1487 = precise::min(_1342, _1352 + _1483);
        bool _1495;
        if (!any(_1486 > _811))
        {
            _1495 = any(_811 > _1487);
        }
        else
        {
            _1495 = true;
        }
        float3 _1508;
        float3 _1509;
        if (_1495)
        {
            float3 _1504 = fast::clamp(float3(precise::max(_1440 * float(_150.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_894 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_905, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_222, 0.5)), float3(0.0), float3(1.0));
            _1508 = mix(fast::clamp(_811, _1486, _1487), _811, _1504);
            _1509 = mix(precise::min(_1469, float3(0.100000001490116119384765625)), _1469, _1504);
        }
        else
        {
            _1508 = _811;
            _1509 = _1469;
        }
        float _1517 = (_1375.x + _1375.y) - _1375.z;
        float _1518 = _1375.x + _1375.z;
        float _1520 = (_1375.x - _1375.y) - _1375.z;
        float3 _1527 = float3(_1517, _1518, _1520) / float3(precise::max(precise::max(0.0, _1517), precise::max(_1518, _1520)) + 1.0);
        float _1528 = _1527.x;
        float _1531 = 0.5 * _1527.y;
        float _1533 = _1527.z;
        float _1534 = 0.25 * _1533;
        float _1546 = (_1508.x + _1508.y) - _1508.z;
        float _1547 = _1508.x + _1508.z;
        float _1549 = (_1508.x - _1508.y) - _1508.z;
        float3 _1556 = float3(_1546, _1547, _1549) / float3(precise::max(precise::max(0.0, _1546), precise::max(_1547, _1549)) + 1.0);
        float _1557 = _1556.x;
        float _1560 = 0.5 * _1556.y;
        float _1562 = _1556.z;
        float _1563 = 0.25 * _1562;
        float3 _1574 = mix(float3(((0.25 * _1557) + _1560) + _1563, 0.5 * (_1557 - _1562), (((-0.25) * _1557) + _1560) - _1563), float3(((0.25 * _1528) + _1531) + _1534, 0.5 * (_1528 - _1533), (((-0.25) * _1528) + _1531) - _1534).xyz, _1375.www / precise::max(float3(0.001000000047497451305389404296875), _1509 + _1375.www));
        float _1579 = (_1574.x + _1574.y) - _1574.z;
        float _1580 = _1574.x + _1574.z;
        float _1582 = (_1574.x - _1574.y) - _1574.z;
        _1599 = float3(_1579, _1580, _1582) / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_1579, precise::max(_1580, _1582))));
    }
    float4 _1601 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1602 = _1601.x;
    float2 _1610 = _171 - _193;
    float _1611 = _1610.x;
    bool _1616;
    if (_1611 >= 0.0)
    {
        _1616 = _1611 <= 1.0;
    }
    else
    {
        _1616 = false;
    }
    bool _1625;
    if (_1616)
    {
        float _1619 = _1610.y;
        bool _1624;
        if (_1619 >= 0.0)
        {
            _1624 = _1619 <= 1.0;
        }
        else
        {
            _1624 = false;
        }
        _1625 = _1624;
    }
    else
    {
        _1625 = false;
    }
    float2 _1638;
    if (!_1625)
    {
        float2 _1637 = _881;
        _1637.x = 0.0;
        _1638 = _1637;
    }
    else
    {
        float2 _1636 = _881;
        _1636.x = precise::max(0.0, _894 - (_1375.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1638 = _1636;
    }
    sdk_hlsl_store(rw_lock_status, _1638.xyyy, uint2(_166));
    float _1640 = precise::min(0.9900000095367431640625, _885);
    float _1643 = precise::max(_1640, mix(_1640, 0.4000000059604644775390625, fast::clamp(_195, 0.0, 1.0)));
    float _1648 = _227 ? 1.0 : precise::max(_1643 * _1643, precise::max(_217 * 0.100000001490116119384765625, _222));
    float _1654;
    if (_1461 >= 1.0)
    {
        _1654 = precise::max(0.001000000047497451305389404296875, _1648) * (-1.0);
    }
    else
    {
        _1654 = _1648;
    }
    sdk_hlsl_store(rw_internal_upscaled_color, float4((_1599 / float3((_1602 == 0.0) ? 1.0 : _1602)) * cbFSR2.fPreExposure, _1654), uint2(_166));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_166));
}

