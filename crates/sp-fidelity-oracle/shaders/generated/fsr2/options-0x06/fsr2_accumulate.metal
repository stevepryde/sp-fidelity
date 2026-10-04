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

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_exposure [[texture(0)]], texture2d<float> r_dilated_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float> r_lock_status [[texture(3)]], texture2d<float> r_prepared_input_color [[texture(4)]], texture2d<float> r_luma_history [[texture(5)]], texture2d<float> r_imgMips [[texture(6)]], texture2d<float> r_dilated_reactive_masks [[texture(7)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(8)]], texture2d<float, access::write> rw_lock_status [[texture(9)]], texture2d<float, access::read_write> rw_new_locks [[texture(10)]], texture2d<float, access::write> rw_luma_history [[texture(11)]], texture2d<float, access::write> rw_upscaled_output [[texture(12)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _146 = gl_WorkGroupID.xy;
    _146.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _160 = (_146 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _163 = float2(int2(_160)) + float2(0.5);
    float2 _164 = float2(cbFSR2.iDisplaySize);
    float2 _165 = _163 / _164;
    float2 _170 = float2(cbFSR2.iRenderSize);
    float2 _180 = precise::max(float2(0.5), precise::min((_165 + (cbFSR2.fJitter / _170)) * _170, _170 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _186 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_165 * _170))), 0u).xy;
    float _188 = length(_186 * _164);
    float2 _189 = _165 + _186;
    float _190 = _189.x;
    bool _195;
    if (_190 >= 0.0)
    {
        _195 = _190 <= 1.0;
    }
    else
    {
        _195 = false;
    }
    bool _204;
    if (_195)
    {
        float _198 = _189.y;
        bool _203;
        if (_198 >= 0.0)
        {
            _203 = _198 <= 1.0;
        }
        else
        {
            _203 = false;
        }
        _204 = _203;
    }
    else
    {
        _204 = false;
    }
    float _210 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _180, level(0.0)).w, 0.0, 1.0);
    float4 _214 = r_dilated_reactive_masks.sample(s_LinearClamp, _180, level(0.0));
    float _215 = _214.x;
    float _216 = _214.y;
    bool _219 = 0 == cbFSR2.iFrameIndex;
    bool _220 = _204 ? _219 : true;
    bool _224;
    if (_204)
    {
        _224 = !_219;
    }
    else
    {
        _224 = false;
    }
    float2 _757;
    float3 _758;
    bool _759;
    bool _760;
    float _761;
    if (_224)
    {
        float2 _228 = (_189 * _164) - float2(0.5);
        float2 _238 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _228.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _228.y)));
        float2 _239 = floor(_238);
        int2 _240 = int2(_239);
        float2 _241 = _238 - _239;
        int2 _242 = _240 + int2(-1);
        int _246 = max(_242.y, 0);
        int2 _247 = int2(max(_242.x, 0), _246);
        _247.y = _246;
        int2 _252 = _240 + int2(0, -1);
        int _255 = max(_252.y, 0);
        int2 _256 = int2(_252.x, _255);
        _256.y = _255;
        int2 _261 = _240 + int2(1, -1);
        int _263 = cbFSR2.iDisplaySize.x - 1;
        int _266 = max(_261.y, 0);
        int2 _267 = int2(min(_261.x, _263), _266);
        _267.y = _266;
        int2 _272 = _240 + int2(2, -1);
        int _276 = max(_272.y, 0);
        int2 _277 = int2(min(_272.x, _263), _276);
        _277.y = _276;
        int2 _282 = _240 + int2(-1, 0);
        int _285 = _282.y;
        int2 _286 = int2(max(_282.x, 0), _285);
        _286.y = _285;
        int2 _292 = _240;
        _292.y = _240.y;
        float4 _295 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_292)), 0u);
        int2 _296 = _240 + int2(1, 0);
        int _299 = _296.y;
        int2 _300 = int2(min(_296.x, _263), _299);
        _300.y = _299;
        float4 _304 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_300)), 0u);
        int2 _305 = _240 + int2(2, 0);
        int _308 = _305.y;
        int2 _309 = int2(min(_305.x, _263), _308);
        _309.y = _308;
        int2 _314 = _240 + int2(-1, 1);
        int _317 = _314.y;
        int2 _318 = int2(max(_314.x, 0), _317);
        int _319 = cbFSR2.iDisplaySize.y - 1;
        _318.y = min(_317, _319);
        int2 _325 = _240 + int2(0, 1);
        _325.y = min(_325.y, _319);
        float4 _331 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_325)), 0u);
        int2 _332 = _240 + int2(1);
        int _335 = _332.y;
        int2 _336 = int2(min(_332.x, _263), _335);
        _336.y = min(_335, _319);
        float4 _341 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_336)), 0u);
        int2 _342 = _240 + int2(2, 1);
        int _345 = _342.y;
        int2 _346 = int2(min(_342.x, _263), _345);
        _346.y = min(_345, _319);
        int2 _352 = _240 + int2(-1, 2);
        int _355 = _352.y;
        int2 _356 = int2(max(_352.x, 0), _355);
        _356.y = min(_355, _319);
        int2 _362 = _240 + int2(0, 2);
        _362.y = min(_362.y, _319);
        int2 _369 = _240 + int2(1, 2);
        int _372 = _369.y;
        int2 _373 = int2(min(_369.x, _263), _372);
        _373.y = min(_372, _319);
        int2 _379 = _240 + int2(2);
        int _382 = _379.y;
        int2 _383 = int2(min(_379.x, _263), _382);
        _383.y = min(_382, _319);
        float _389 = _241.x;
        float _392 = precise::min(abs((-1.0) - _389), 2.0);
        bool _394 = abs(_392) < 0.001000000047497451305389404296875;
        float _405;
        if (_394)
        {
            _405 = 1.0;
        }
        else
        {
            float _398 = 3.1415927410125732421875 * _392;
            float _401 = 1.57079637050628662109375 * _392;
            _405 = (sin(_398) / _398) * (sin(_401) / _401);
        }
        float _408 = precise::min(abs(-_389), 2.0);
        bool _410 = abs(_408) < 0.001000000047497451305389404296875;
        float _421;
        if (_410)
        {
            _421 = 1.0;
        }
        else
        {
            float _414 = 3.1415927410125732421875 * _408;
            float _417 = 1.57079637050628662109375 * _408;
            _421 = (sin(_414) / _414) * (sin(_417) / _417);
        }
        float _424 = precise::min(abs(1.0 - _389), 2.0);
        bool _426 = abs(_424) < 0.001000000047497451305389404296875;
        float _437;
        if (_426)
        {
            _437 = 1.0;
        }
        else
        {
            float _430 = 3.1415927410125732421875 * _424;
            float _433 = 1.57079637050628662109375 * _424;
            _437 = (sin(_430) / _430) * (sin(_433) / _433);
        }
        float _440 = precise::min(abs(2.0 - _389), 2.0);
        bool _442 = abs(_440) < 0.001000000047497451305389404296875;
        float _453;
        if (_442)
        {
            _453 = 1.0;
        }
        else
        {
            float _446 = 3.1415927410125732421875 * _440;
            float _449 = 1.57079637050628662109375 * _440;
            _453 = (sin(_446) / _446) * (sin(_449) / _449);
        }
        float _476;
        if (_394)
        {
            _476 = 1.0;
        }
        else
        {
            float _469 = 3.1415927410125732421875 * _392;
            float _472 = 1.57079637050628662109375 * _392;
            _476 = (sin(_469) / _469) * (sin(_472) / _472);
        }
        float _487;
        if (_410)
        {
            _487 = 1.0;
        }
        else
        {
            float _480 = 3.1415927410125732421875 * _408;
            float _483 = 1.57079637050628662109375 * _408;
            _487 = (sin(_480) / _480) * (sin(_483) / _483);
        }
        float _498;
        if (_426)
        {
            _498 = 1.0;
        }
        else
        {
            float _491 = 3.1415927410125732421875 * _424;
            float _494 = 1.57079637050628662109375 * _424;
            _498 = (sin(_491) / _491) * (sin(_494) / _494);
        }
        float _509;
        if (_442)
        {
            _509 = 1.0;
        }
        else
        {
            float _502 = 3.1415927410125732421875 * _440;
            float _505 = 1.57079637050628662109375 * _440;
            _509 = (sin(_502) / _502) * (sin(_505) / _505);
        }
        float _532;
        if (_394)
        {
            _532 = 1.0;
        }
        else
        {
            float _525 = 3.1415927410125732421875 * _392;
            float _528 = 1.57079637050628662109375 * _392;
            _532 = (sin(_525) / _525) * (sin(_528) / _528);
        }
        float _543;
        if (_410)
        {
            _543 = 1.0;
        }
        else
        {
            float _536 = 3.1415927410125732421875 * _408;
            float _539 = 1.57079637050628662109375 * _408;
            _543 = (sin(_536) / _536) * (sin(_539) / _539);
        }
        float _554;
        if (_426)
        {
            _554 = 1.0;
        }
        else
        {
            float _547 = 3.1415927410125732421875 * _424;
            float _550 = 1.57079637050628662109375 * _424;
            _554 = (sin(_547) / _547) * (sin(_550) / _550);
        }
        float _565;
        if (_442)
        {
            _565 = 1.0;
        }
        else
        {
            float _558 = 3.1415927410125732421875 * _440;
            float _561 = 1.57079637050628662109375 * _440;
            _565 = (sin(_558) / _558) * (sin(_561) / _561);
        }
        float _588;
        if (_394)
        {
            _588 = 1.0;
        }
        else
        {
            float _581 = 3.1415927410125732421875 * _392;
            float _584 = 1.57079637050628662109375 * _392;
            _588 = (sin(_581) / _581) * (sin(_584) / _584);
        }
        float _599;
        if (_410)
        {
            _599 = 1.0;
        }
        else
        {
            float _592 = 3.1415927410125732421875 * _408;
            float _595 = 1.57079637050628662109375 * _408;
            _599 = (sin(_592) / _592) * (sin(_595) / _595);
        }
        float _610;
        if (_426)
        {
            _610 = 1.0;
        }
        else
        {
            float _603 = 3.1415927410125732421875 * _424;
            float _606 = 1.57079637050628662109375 * _424;
            _610 = (sin(_603) / _603) * (sin(_606) / _606);
        }
        float _621;
        if (_442)
        {
            _621 = 1.0;
        }
        else
        {
            float _614 = 3.1415927410125732421875 * _440;
            float _617 = 1.57079637050628662109375 * _440;
            _621 = (sin(_614) / _614) * (sin(_617) / _617);
        }
        float _634 = _241.y;
        float _637 = precise::min(abs((-1.0) - _634), 2.0);
        float _650;
        if (abs(_637) < 0.001000000047497451305389404296875)
        {
            _650 = 1.0;
        }
        else
        {
            float _643 = 3.1415927410125732421875 * _637;
            float _646 = 1.57079637050628662109375 * _637;
            _650 = (sin(_643) / _643) * (sin(_646) / _646);
        }
        float _653 = precise::min(abs(-_634), 2.0);
        float _666;
        if (abs(_653) < 0.001000000047497451305389404296875)
        {
            _666 = 1.0;
        }
        else
        {
            float _659 = 3.1415927410125732421875 * _653;
            float _662 = 1.57079637050628662109375 * _653;
            _666 = (sin(_659) / _659) * (sin(_662) / _662);
        }
        float _669 = precise::min(abs(1.0 - _634), 2.0);
        float _682;
        if (abs(_669) < 0.001000000047497451305389404296875)
        {
            _682 = 1.0;
        }
        else
        {
            float _675 = 3.1415927410125732421875 * _669;
            float _678 = 1.57079637050628662109375 * _669;
            _682 = (sin(_675) / _675) * (sin(_678) / _678);
        }
        float _685 = precise::min(abs(2.0 - _634), 2.0);
        float _698;
        if (abs(_685) < 0.001000000047497451305389404296875)
        {
            _698 = 1.0;
        }
        else
        {
            float _691 = 3.1415927410125732421875 * _685;
            float _694 = 1.57079637050628662109375 * _685;
            _698 = (sin(_691) / _691) * (sin(_694) / _694);
        }
        float4 _705 = ((((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_247)), 0u) * _405) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_256)), 0u) * _421)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_267)), 0u) * _437)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_277)), 0u) * _453)) / float4(((_405 + _421) + _437) + _453)) * _650) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_286)), 0u) * _476) + (_295 * _487)) + (_304 * _498)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_309)), 0u) * _509)) / float4(((_476 + _487) + _498) + _509)) * _666)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_318)), 0u) * _532) + (_331 * _543)) + (_341 * _554)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_346)), 0u) * _565)) / float4(((_532 + _543) + _554) + _565)) * _682)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_356)), 0u) * _588) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_362)), 0u) * _599)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_373)), 0u) * _610)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_383)), 0u) * _621)) / float4(((_588 + _599) + _610) + _621)) * _698);
        float4 _717 = fast::clamp(_705 / float4(((_650 + _666) + _682) + _698), precise::min(precise::min(precise::min(_295, _304), _331), _341), precise::max(precise::max(precise::max(_295, _304), _331), _341));
        float4 _720 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _721 = _720.x;
        float3 _729 = fast::clamp((_717.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_721 == 0.0) ? 1.0 : _721), float3(0.0), float3(65504.0));
        float _730 = _729.x;
        float _733 = 0.5 * _729.y;
        float _735 = _729.z;
        float _736 = 0.25 * _735;
        float _744 = _717.w;
        spvImageFence(rw_new_locks);
        _757 = r_lock_status.sample(s_LinearClamp, _189, level(0.0)).xy;
        _758 = float3(((0.25 * _730) + _733) + _736, 0.5 * (_730 - _735), (((-0.25) * _730) + _733) - _736);
        _759 = _744 < 0.0;
        _760 = sdk_hlsl_load(rw_new_locks, uint2(_160)).x > 0.4980392158031463623046875;
        _761 = fast::clamp(abs(_744), 0.0, 1.0);
    }
    else
    {
        _757 = float2(0.0);
        _758 = float3(0.0);
        _759 = false;
        _760 = false;
        _761 = 0.0;
    }
    float2 _773 = float2(int2(_170 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _781 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _782 = _781.x;
    float _794 = powr(((_782 == 0.0) ? 1.0 : _782) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_165 * _773, _773 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _797 = (_757.y == 0.0) ? _794 : _757.y;
    float2 _798 = _757;
    _798.y = _797;
    float _799 = precise::max(_797, _794);
    float _806;
    if (_799 != 0.0)
    {
        _806 = precise::min(_797, _794) / _799;
    }
    else
    {
        _806 = 0.0;
    }
    float _807 = 1.0 - _806;
    float2 _828;
    if (_760)
    {
        _828 = float2((_757.x != 0.0) ? 2.0 : 1.0, _794);
    }
    else
    {
        float2 _823;
        if (_757.x <= 1.0)
        {
            float2 _822 = _798;
            _822.y = mix(_797, _794, 0.5);
            _823 = _822;
        }
        else
        {
            float2 _820;
            if (_807 > 0.100000001490116119384765625)
            {
                _820 = float2(0.0, _797);
            }
            else
            {
                _820 = _798;
            }
            _823 = _820;
        }
        _828 = _823;
    }
    float _832 = precise::max(precise::max(_215, _761), fast::clamp((0.89999997615814208984375 - _806) * 10.0, 0.0, 1.0));
    float _833 = 1.0 - _832;
    float _841 = ((_828.x * _833) * fast::clamp(1.0 - _216, 0.0, 1.0)) * float(_210 < 0.100000001490116119384765625);
    float _845 = precise::max(_828.y, _794);
    float _852;
    if (_845 != 0.0)
    {
        _852 = precise::min(_828.y, _794) / _845;
    }
    else
    {
        _852 = 0.0;
    }
    float2 _860 = _163 * cbFSR2.fDownscaleFactor;
    int2 _862 = int2(floor(_860));
    float2 _865 = (float2(_862) + float2(0.5)) - cbFSR2.fJitter;
    bool _868 = _865.x > _860.x;
    bool _872 = _865.y > _860.y;
    int2 _874 = int2(_868 ? (-2) : (-1), _872 ? (-2) : (-1));
    float2 _875 = float2(_874);
    int _876 = _868 ? 3 : 0;
    int _877 = _872 ? 3 : 0;
    int2 _878 = int2(_876, _877);
    int2 _879 = _862 + _874;
    int2 _880 = _879 + _878;
    int2 _882 = _880;
    _882.y = _880.y;
    float3 _886 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_882)), 0u).xyz;
    int _887 = _868 ? 2 : 1;
    int2 _888 = int2(_887, _877);
    int2 _889 = _879 + _888;
    int2 _891 = _889;
    _891.y = _889.y;
    float3 _895 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_891)), 0u).xyz;
    int _896 = _868 ? 1 : 2;
    int2 _897 = int2(_896, _877);
    int2 _898 = _879 + _897;
    int2 _900 = _898;
    _900.y = _898.y;
    float3 _904 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_900)), 0u).xyz;
    int _905 = _872 ? 2 : 1;
    int2 _906 = int2(_876, _905);
    int2 _907 = _879 + _906;
    int2 _909 = _907;
    _909.y = _907.y;
    float3 _913 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_909)), 0u).xyz;
    int2 _914 = int2(_887, _905);
    int2 _915 = _879 + _914;
    int2 _917 = _915;
    _917.y = _915.y;
    float3 _921 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_917)), 0u).xyz;
    int2 _922 = int2(_896, _905);
    int2 _923 = _879 + _922;
    int2 _925 = _923;
    _925.y = _923.y;
    float3 _929 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_925)), 0u).xyz;
    int _930 = _872 ? 1 : 2;
    int2 _931 = int2(_876, _930);
    int2 _932 = _879 + _931;
    int2 _934 = _932;
    _934.y = _932.y;
    float3 _938 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_934)), 0u).xyz;
    int2 _939 = int2(_887, _930);
    int2 _940 = _879 + _939;
    int2 _942 = _940;
    _942.y = _940.y;
    float3 _946 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_942)), 0u).xyz;
    int2 _947 = int2(_896, _930);
    int2 _948 = _879 + _947;
    int2 _950 = _948;
    _950.y = _948.y;
    float3 _954 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_950)), 0u).xyz;
    float2 _955 = _865 - _860;
    float _957 = precise::max(_832, float(_220));
    float _964 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _957);
    float _974 = mix(-2.0, -3.0, fast::clamp(_188 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _977 = _955 + (_875 + float2(_878));
    uint2 _979 = uint2(cbFSR2.iRenderSize);
    float2 _983 = float2(mix(_964, precise::max(1.0, (1.0 + _964) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _210, _957))));
    float2 _984 = _977 * _983;
    float _986 = precise::min(dot(_984, _984), 4.0);
    float _988 = (0.4000000059604644775390625 * _986) - 1.0;
    float _990 = (0.25 * _986) - 1.0;
    float _996 = float(all(uint2(_880) < _979)) * ((((1.5625 * _988) * _988) - 0.5625) * (_990 * _990));
    float _1004 = exp(_974 * dot(_977, _977));
    float3 _1005 = _886 * _1004;
    float2 _1009 = _955 + (_875 + float2(_888));
    float2 _1014 = _1009 * _983;
    float _1016 = precise::min(dot(_1014, _1014), 4.0);
    float _1018 = (0.4000000059604644775390625 * _1016) - 1.0;
    float _1020 = (0.25 * _1016) - 1.0;
    float _1026 = float(all(uint2(_889) < _979)) * ((((1.5625 * _1018) * _1018) - 0.5625) * (_1020 * _1020));
    float _1035 = exp(_974 * dot(_1009, _1009));
    float3 _1038 = _895 * _1035;
    float2 _1045 = _955 + (_875 + float2(_897));
    float2 _1050 = _1045 * _983;
    float _1052 = precise::min(dot(_1050, _1050), 4.0);
    float _1054 = (0.4000000059604644775390625 * _1052) - 1.0;
    float _1056 = (0.25 * _1052) - 1.0;
    float _1062 = float(all(uint2(_898) < _979)) * ((((1.5625 * _1054) * _1054) - 0.5625) * (_1056 * _1056));
    float _1071 = exp(_974 * dot(_1045, _1045));
    float3 _1074 = _904 * _1071;
    float2 _1081 = _955 + (_875 + float2(_906));
    float2 _1086 = _1081 * _983;
    float _1088 = precise::min(dot(_1086, _1086), 4.0);
    float _1090 = (0.4000000059604644775390625 * _1088) - 1.0;
    float _1092 = (0.25 * _1088) - 1.0;
    float _1098 = float(all(uint2(_907) < _979)) * ((((1.5625 * _1090) * _1090) - 0.5625) * (_1092 * _1092));
    float _1107 = exp(_974 * dot(_1081, _1081));
    float3 _1110 = _913 * _1107;
    float2 _1117 = _955 + (_875 + float2(_914));
    float2 _1122 = _1117 * _983;
    float _1124 = precise::min(dot(_1122, _1122), 4.0);
    float _1126 = (0.4000000059604644775390625 * _1124) - 1.0;
    float _1128 = (0.25 * _1124) - 1.0;
    float _1134 = float(all(uint2(_915) < _979)) * ((((1.5625 * _1126) * _1126) - 0.5625) * (_1128 * _1128));
    float _1143 = exp(_974 * dot(_1117, _1117));
    float3 _1146 = _921 * _1143;
    float2 _1153 = _955 + (_875 + float2(_922));
    float2 _1158 = _1153 * _983;
    float _1160 = precise::min(dot(_1158, _1158), 4.0);
    float _1162 = (0.4000000059604644775390625 * _1160) - 1.0;
    float _1164 = (0.25 * _1160) - 1.0;
    float _1170 = float(all(uint2(_923) < _979)) * ((((1.5625 * _1162) * _1162) - 0.5625) * (_1164 * _1164));
    float _1179 = exp(_974 * dot(_1153, _1153));
    float3 _1182 = _929 * _1179;
    float2 _1189 = _955 + (_875 + float2(_931));
    float2 _1194 = _1189 * _983;
    float _1196 = precise::min(dot(_1194, _1194), 4.0);
    float _1198 = (0.4000000059604644775390625 * _1196) - 1.0;
    float _1200 = (0.25 * _1196) - 1.0;
    float _1206 = float(all(uint2(_932) < _979)) * ((((1.5625 * _1198) * _1198) - 0.5625) * (_1200 * _1200));
    float _1215 = exp(_974 * dot(_1189, _1189));
    float3 _1218 = _938 * _1215;
    float2 _1225 = _955 + (_875 + float2(_939));
    float2 _1230 = _1225 * _983;
    float _1232 = precise::min(dot(_1230, _1230), 4.0);
    float _1234 = (0.4000000059604644775390625 * _1232) - 1.0;
    float _1236 = (0.25 * _1232) - 1.0;
    float _1242 = float(all(uint2(_940) < _979)) * ((((1.5625 * _1234) * _1234) - 0.5625) * (_1236 * _1236));
    float _1251 = exp(_974 * dot(_1225, _1225));
    float3 _1254 = _946 * _1251;
    float2 _1261 = _955 + (_875 + float2(_947));
    float2 _1266 = _1261 * _983;
    float _1268 = precise::min(dot(_1266, _1266), 4.0);
    float _1270 = (0.4000000059604644775390625 * _1268) - 1.0;
    float _1272 = (0.25 * _1268) - 1.0;
    float _1278 = float(all(uint2(_948) < _979)) * ((((1.5625 * _1270) * _1270) - 0.5625) * (_1272 * _1272));
    float4 _1284 = (((((((float4(_886 * _996, _996) + float4(_895 * _1026, _1026)) + float4(_904 * _1062, _1062)) + float4(_913 * _1098, _1098)) + float4(_921 * _1134, _1134)) + float4(_929 * _1170, _1170)) + float4(_938 * _1206, _1206)) + float4(_946 * _1242, _1242)) + float4(_954 * _1278, _1278);
    float _1287 = exp(_974 * dot(_1261, _1261));
    float3 _1288 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_886, _895), _904), _913), _921), _929), _938), _946), _954);
    float3 _1289 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_886, _895), _904), _913), _921), _929), _938), _946), _954);
    float3 _1290 = _954 * _1287;
    float _1294 = (((((((_1004 + _1035) + _1071) + _1107) + _1143) + _1179) + _1215) + _1251) + _1287;
    float3 _1298 = float3((abs(_1294) > 0.001000000047497451305389404296875) ? _1294 : 1.0);
    float3 _1299 = ((((((((_1005 + _1038) + _1074) + _1110) + _1146) + _1182) + _1218) + _1254) + _1290) / _1298;
    float3 _1304 = sqrt(abs(((((((((((_886 * _1005) + (_895 * _1038)) + (_904 * _1074)) + (_913 * _1110)) + (_921 * _1146)) + (_929 * _1182)) + (_938 * _1218)) + (_946 * _1254)) + (_954 * _1290)) / _1298) - (_1299 * _1299)));
    float _1308 = _1284.w * float(_1284.w > 0.001000000047497451305389404296875);
    float4 _1309 = _1284;
    _1309.w = _1308;
    float4 _1322;
    if (_1308 > 0.001000000047497451305389404296875)
    {
        float3 _1315 = _1309.xyz / float3(_1308);
        float4 _1316 = float4(_1315.x, _1315.y, _1315.z, _1309.w);
        _1316.w = _1308 * 0.083333335816860198974609375;
        float3 _1320 = fast::clamp(_1316.xyz, _1288, _1289);
        _1322 = float4(_1320.x, _1320.y, _1320.z, _1316.w);
    }
    else
    {
        _1322 = _1309;
    }
    float _1323 = _1299.x;
    float _1329 = rint((_1323 / (1.0 + precise::max(0.0, _1323))) * 255.0) * 0.0039215688593685626983642578125;
    bool _1336;
    if (precise::max(precise::max(_210, _216), _807) < 0.100000001490116119384765625)
    {
        _1336 = !_220;
    }
    else
    {
        _1336 = false;
    }
    float4 _1344;
    if (_1336)
    {
        _1344 = r_luma_history.sample(s_LinearClamp, _189, level(0.0));
    }
    else
    {
        _1344 = float4(0.0);
    }
    float4 _144 = _1344;
    float _1347 = _1329 - _144.x;
    float _1348 = abs(_1347);
    float _1387;
    if (_1348 >= 0.0039215688593685626983642578125)
    {
        float _1353;
        _1353 = _1348;
        float _1354;
        for (int _1356 = 1; _1356 <= 3; _1353 = _1354, _1356++)
        {
            float _1364 = _1329 - _144[uint(_1356)];
            if (int(sign(_1347)) == int(sign(_1364)))
            {
                _1354 = precise::min(_1353, abs(_1364));
            }
            else
            {
                _1354 = _1353;
            }
        }
        _1387 = float((float(_1353 != _1348) * powr(fast::clamp(_1304.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_216, powr(_832, 0.16666667163372039794921875)));
    }
    else
    {
        _1387 = 0.0;
    }
    _144.w = _144.z;
    _144.z = _144.y;
    _144.y = _144.x;
    _144.x = _1329;
    sdk_hlsl_store(rw_luma_history, _144, uint2(_160));
    float _1404 = (float(_204) * _833) * (1.0 - _210);
    float _1408 = fast::clamp(_188 * 10.0, 0.0, 1.0);
    float _1411 = precise::min(_1404, mix(_1404, _1322.w * 10.0, precise::max(float(_759), _1408)));
    float _1413 = fast::clamp(_188 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1416 = float3(precise::min(_1411, mix(_1411, _1322.w, _1413)));
    float3 _1546;
    if (_220)
    {
        _1546 = float3((_1322.x + _1322.y) - _1322.z, _1322.x + _1322.z, (_1322.x - _1322.y) - _1322.z);
    }
    else
    {
        float3 _1430 = _1304 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_210, precise::max(_216, _1413)));
        float3 _1433 = precise::max(_1288, _1299 - _1430);
        float3 _1434 = precise::min(_1289, _1299 + _1430);
        bool _1442;
        if (!any(_1433 > _758))
        {
            _1442 = any(_758 > _1434);
        }
        else
        {
            _1442 = true;
        }
        float3 _1455;
        float3 _1456;
        if (_1442)
        {
            float3 _1451 = fast::clamp(float3(precise::max(_1387 * float(_144.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_841 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_852, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_215, 0.5)), float3(0.0), float3(1.0));
            _1455 = mix(fast::clamp(_758, _1433, _1434), _758, _1451);
            _1456 = mix(precise::min(_1416, float3(0.100000001490116119384765625)), _1416, _1451);
        }
        else
        {
            _1455 = _758;
            _1456 = _1416;
        }
        float _1464 = (_1322.x + _1322.y) - _1322.z;
        float _1465 = _1322.x + _1322.z;
        float _1467 = (_1322.x - _1322.y) - _1322.z;
        float3 _1474 = float3(_1464, _1465, _1467) / float3(precise::max(precise::max(0.0, _1464), precise::max(_1465, _1467)) + 1.0);
        float _1475 = _1474.x;
        float _1478 = 0.5 * _1474.y;
        float _1480 = _1474.z;
        float _1481 = 0.25 * _1480;
        float _1493 = (_1455.x + _1455.y) - _1455.z;
        float _1494 = _1455.x + _1455.z;
        float _1496 = (_1455.x - _1455.y) - _1455.z;
        float3 _1503 = float3(_1493, _1494, _1496) / float3(precise::max(precise::max(0.0, _1493), precise::max(_1494, _1496)) + 1.0);
        float _1504 = _1503.x;
        float _1507 = 0.5 * _1503.y;
        float _1509 = _1503.z;
        float _1510 = 0.25 * _1509;
        float3 _1521 = mix(float3(((0.25 * _1504) + _1507) + _1510, 0.5 * (_1504 - _1509), (((-0.25) * _1504) + _1507) - _1510), float3(((0.25 * _1475) + _1478) + _1481, 0.5 * (_1475 - _1480), (((-0.25) * _1475) + _1478) - _1481).xyz, _1322.www / precise::max(float3(0.001000000047497451305389404296875), _1456 + _1322.www));
        float _1526 = (_1521.x + _1521.y) - _1521.z;
        float _1527 = _1521.x + _1521.z;
        float _1529 = (_1521.x - _1521.y) - _1521.z;
        _1546 = float3(_1526, _1527, _1529) / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_1526, precise::max(_1527, _1529))));
    }
    float4 _1548 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1549 = _1548.x;
    float3 _1556 = (_1546 / float3((_1549 == 0.0) ? 1.0 : _1549)) * cbFSR2.fPreExposure;
    float2 _1557 = _165 - _186;
    float _1558 = _1557.x;
    bool _1563;
    if (_1558 >= 0.0)
    {
        _1563 = _1558 <= 1.0;
    }
    else
    {
        _1563 = false;
    }
    bool _1572;
    if (_1563)
    {
        float _1566 = _1557.y;
        bool _1571;
        if (_1566 >= 0.0)
        {
            _1571 = _1566 <= 1.0;
        }
        else
        {
            _1571 = false;
        }
        _1572 = _1571;
    }
    else
    {
        _1572 = false;
    }
    float2 _1585;
    if (!_1572)
    {
        float2 _1584 = _828;
        _1584.x = 0.0;
        _1585 = _1584;
    }
    else
    {
        float2 _1583 = _828;
        _1583.x = precise::max(0.0, _841 - (_1322.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1585 = _1583;
    }
    sdk_hlsl_store(rw_lock_status, _1585.xyyy, uint2(_160));
    float _1587 = precise::min(0.9900000095367431640625, _832);
    float _1590 = precise::max(_1587, mix(_1587, 0.4000000059604644775390625, fast::clamp(_188, 0.0, 1.0)));
    float _1595 = _220 ? 1.0 : precise::max(_1590 * _1590, precise::max(_210 * 0.100000001490116119384765625, _215));
    float _1601;
    if (_1408 >= 1.0)
    {
        _1601 = precise::max(0.001000000047497451305389404296875, _1595) * (-1.0);
    }
    else
    {
        _1601 = _1595;
    }
    float _1602 = _1556.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1602, _1556.yz, _1601), uint2(_160));
    sdk_hlsl_store(rw_upscaled_output, float4(_1602, _1556.yz, 1.0), uint2(_160));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_160));
}

