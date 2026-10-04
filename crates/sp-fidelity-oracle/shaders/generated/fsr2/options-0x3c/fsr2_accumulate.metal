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
    uint2 _141 = gl_WorkGroupID.xy;
    _141.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _155 = (_141 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _158 = float2(int2(_155)) + float2(0.5);
    float2 _159 = float2(cbFSR2.iDisplaySize);
    float2 _160 = _158 / _159;
    float2 _165 = float2(cbFSR2.iRenderSize);
    float2 _175 = precise::max(float2(0.5), precise::min((_160 + (cbFSR2.fJitter / _165)) * _165, _165 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _181 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_160 * _165))), 0u).xy;
    float _183 = length(_181 * _159);
    float2 _184 = _160 + _181;
    float _185 = _184.x;
    bool _190;
    if (_185 >= 0.0)
    {
        _190 = _185 <= 1.0;
    }
    else
    {
        _190 = false;
    }
    bool _199;
    if (_190)
    {
        float _193 = _184.y;
        bool _198;
        if (_193 >= 0.0)
        {
            _198 = _193 <= 1.0;
        }
        else
        {
            _198 = false;
        }
        _199 = _198;
    }
    else
    {
        _199 = false;
    }
    float _205 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _175, level(0.0)).w, 0.0, 1.0);
    float4 _209 = r_dilated_reactive_masks.sample(s_LinearClamp, _175, level(0.0));
    float _210 = _209.x;
    float _211 = _209.y;
    bool _214 = 0 == cbFSR2.iFrameIndex;
    bool _215 = _199 ? _214 : true;
    bool _219;
    if (_199)
    {
        _219 = !_214;
    }
    else
    {
        _219 = false;
    }
    float2 _752;
    float3 _753;
    bool _754;
    bool _755;
    float _756;
    if (_219)
    {
        float2 _223 = (_184 * _159) - float2(0.5);
        float2 _233 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _223.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _223.y)));
        float2 _234 = floor(_233);
        int2 _235 = int2(_234);
        float2 _236 = _233 - _234;
        int2 _237 = _235 + int2(-1);
        int _241 = max(_237.y, 0);
        int2 _242 = int2(max(_237.x, 0), _241);
        _242.y = _241;
        int2 _247 = _235 + int2(0, -1);
        int _250 = max(_247.y, 0);
        int2 _251 = int2(_247.x, _250);
        _251.y = _250;
        int2 _256 = _235 + int2(1, -1);
        int _258 = cbFSR2.iDisplaySize.x - 1;
        int _261 = max(_256.y, 0);
        int2 _262 = int2(min(_256.x, _258), _261);
        _262.y = _261;
        int2 _267 = _235 + int2(2, -1);
        int _271 = max(_267.y, 0);
        int2 _272 = int2(min(_267.x, _258), _271);
        _272.y = _271;
        int2 _277 = _235 + int2(-1, 0);
        int _280 = _277.y;
        int2 _281 = int2(max(_277.x, 0), _280);
        _281.y = _280;
        int2 _287 = _235;
        _287.y = _235.y;
        float4 _290 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_287)), 0u);
        int2 _291 = _235 + int2(1, 0);
        int _294 = _291.y;
        int2 _295 = int2(min(_291.x, _258), _294);
        _295.y = _294;
        float4 _299 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_295)), 0u);
        int2 _300 = _235 + int2(2, 0);
        int _303 = _300.y;
        int2 _304 = int2(min(_300.x, _258), _303);
        _304.y = _303;
        int2 _309 = _235 + int2(-1, 1);
        int _312 = _309.y;
        int2 _313 = int2(max(_309.x, 0), _312);
        int _314 = cbFSR2.iDisplaySize.y - 1;
        _313.y = min(_312, _314);
        int2 _320 = _235 + int2(0, 1);
        _320.y = min(_320.y, _314);
        float4 _326 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_320)), 0u);
        int2 _327 = _235 + int2(1);
        int _330 = _327.y;
        int2 _331 = int2(min(_327.x, _258), _330);
        _331.y = min(_330, _314);
        float4 _336 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_331)), 0u);
        int2 _337 = _235 + int2(2, 1);
        int _340 = _337.y;
        int2 _341 = int2(min(_337.x, _258), _340);
        _341.y = min(_340, _314);
        int2 _347 = _235 + int2(-1, 2);
        int _350 = _347.y;
        int2 _351 = int2(max(_347.x, 0), _350);
        _351.y = min(_350, _314);
        int2 _357 = _235 + int2(0, 2);
        _357.y = min(_357.y, _314);
        int2 _364 = _235 + int2(1, 2);
        int _367 = _364.y;
        int2 _368 = int2(min(_364.x, _258), _367);
        _368.y = min(_367, _314);
        int2 _374 = _235 + int2(2);
        int _377 = _374.y;
        int2 _378 = int2(min(_374.x, _258), _377);
        _378.y = min(_377, _314);
        float _384 = _236.x;
        float _387 = precise::min(abs((-1.0) - _384), 2.0);
        bool _389 = abs(_387) < 0.001000000047497451305389404296875;
        float _400;
        if (_389)
        {
            _400 = 1.0;
        }
        else
        {
            float _393 = 3.1415927410125732421875 * _387;
            float _396 = 1.57079637050628662109375 * _387;
            _400 = (sin(_393) / _393) * (sin(_396) / _396);
        }
        float _403 = precise::min(abs(-_384), 2.0);
        bool _405 = abs(_403) < 0.001000000047497451305389404296875;
        float _416;
        if (_405)
        {
            _416 = 1.0;
        }
        else
        {
            float _409 = 3.1415927410125732421875 * _403;
            float _412 = 1.57079637050628662109375 * _403;
            _416 = (sin(_409) / _409) * (sin(_412) / _412);
        }
        float _419 = precise::min(abs(1.0 - _384), 2.0);
        bool _421 = abs(_419) < 0.001000000047497451305389404296875;
        float _432;
        if (_421)
        {
            _432 = 1.0;
        }
        else
        {
            float _425 = 3.1415927410125732421875 * _419;
            float _428 = 1.57079637050628662109375 * _419;
            _432 = (sin(_425) / _425) * (sin(_428) / _428);
        }
        float _435 = precise::min(abs(2.0 - _384), 2.0);
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
        float _471;
        if (_389)
        {
            _471 = 1.0;
        }
        else
        {
            float _464 = 3.1415927410125732421875 * _387;
            float _467 = 1.57079637050628662109375 * _387;
            _471 = (sin(_464) / _464) * (sin(_467) / _467);
        }
        float _482;
        if (_405)
        {
            _482 = 1.0;
        }
        else
        {
            float _475 = 3.1415927410125732421875 * _403;
            float _478 = 1.57079637050628662109375 * _403;
            _482 = (sin(_475) / _475) * (sin(_478) / _478);
        }
        float _493;
        if (_421)
        {
            _493 = 1.0;
        }
        else
        {
            float _486 = 3.1415927410125732421875 * _419;
            float _489 = 1.57079637050628662109375 * _419;
            _493 = (sin(_486) / _486) * (sin(_489) / _489);
        }
        float _504;
        if (_437)
        {
            _504 = 1.0;
        }
        else
        {
            float _497 = 3.1415927410125732421875 * _435;
            float _500 = 1.57079637050628662109375 * _435;
            _504 = (sin(_497) / _497) * (sin(_500) / _500);
        }
        float _527;
        if (_389)
        {
            _527 = 1.0;
        }
        else
        {
            float _520 = 3.1415927410125732421875 * _387;
            float _523 = 1.57079637050628662109375 * _387;
            _527 = (sin(_520) / _520) * (sin(_523) / _523);
        }
        float _538;
        if (_405)
        {
            _538 = 1.0;
        }
        else
        {
            float _531 = 3.1415927410125732421875 * _403;
            float _534 = 1.57079637050628662109375 * _403;
            _538 = (sin(_531) / _531) * (sin(_534) / _534);
        }
        float _549;
        if (_421)
        {
            _549 = 1.0;
        }
        else
        {
            float _542 = 3.1415927410125732421875 * _419;
            float _545 = 1.57079637050628662109375 * _419;
            _549 = (sin(_542) / _542) * (sin(_545) / _545);
        }
        float _560;
        if (_437)
        {
            _560 = 1.0;
        }
        else
        {
            float _553 = 3.1415927410125732421875 * _435;
            float _556 = 1.57079637050628662109375 * _435;
            _560 = (sin(_553) / _553) * (sin(_556) / _556);
        }
        float _583;
        if (_389)
        {
            _583 = 1.0;
        }
        else
        {
            float _576 = 3.1415927410125732421875 * _387;
            float _579 = 1.57079637050628662109375 * _387;
            _583 = (sin(_576) / _576) * (sin(_579) / _579);
        }
        float _594;
        if (_405)
        {
            _594 = 1.0;
        }
        else
        {
            float _587 = 3.1415927410125732421875 * _403;
            float _590 = 1.57079637050628662109375 * _403;
            _594 = (sin(_587) / _587) * (sin(_590) / _590);
        }
        float _605;
        if (_421)
        {
            _605 = 1.0;
        }
        else
        {
            float _598 = 3.1415927410125732421875 * _419;
            float _601 = 1.57079637050628662109375 * _419;
            _605 = (sin(_598) / _598) * (sin(_601) / _601);
        }
        float _616;
        if (_437)
        {
            _616 = 1.0;
        }
        else
        {
            float _609 = 3.1415927410125732421875 * _435;
            float _612 = 1.57079637050628662109375 * _435;
            _616 = (sin(_609) / _609) * (sin(_612) / _612);
        }
        float _629 = _236.y;
        float _632 = precise::min(abs((-1.0) - _629), 2.0);
        float _645;
        if (abs(_632) < 0.001000000047497451305389404296875)
        {
            _645 = 1.0;
        }
        else
        {
            float _638 = 3.1415927410125732421875 * _632;
            float _641 = 1.57079637050628662109375 * _632;
            _645 = (sin(_638) / _638) * (sin(_641) / _641);
        }
        float _648 = precise::min(abs(-_629), 2.0);
        float _661;
        if (abs(_648) < 0.001000000047497451305389404296875)
        {
            _661 = 1.0;
        }
        else
        {
            float _654 = 3.1415927410125732421875 * _648;
            float _657 = 1.57079637050628662109375 * _648;
            _661 = (sin(_654) / _654) * (sin(_657) / _657);
        }
        float _664 = precise::min(abs(1.0 - _629), 2.0);
        float _677;
        if (abs(_664) < 0.001000000047497451305389404296875)
        {
            _677 = 1.0;
        }
        else
        {
            float _670 = 3.1415927410125732421875 * _664;
            float _673 = 1.57079637050628662109375 * _664;
            _677 = (sin(_670) / _670) * (sin(_673) / _673);
        }
        float _680 = precise::min(abs(2.0 - _629), 2.0);
        float _693;
        if (abs(_680) < 0.001000000047497451305389404296875)
        {
            _693 = 1.0;
        }
        else
        {
            float _686 = 3.1415927410125732421875 * _680;
            float _689 = 1.57079637050628662109375 * _680;
            _693 = (sin(_686) / _686) * (sin(_689) / _689);
        }
        float4 _700 = ((((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_242)), 0u) * _400) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_251)), 0u) * _416)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_262)), 0u) * _432)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_272)), 0u) * _448)) / float4(((_400 + _416) + _432) + _448)) * _645) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_281)), 0u) * _471) + (_290 * _482)) + (_299 * _493)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_304)), 0u) * _504)) / float4(((_471 + _482) + _493) + _504)) * _661)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_313)), 0u) * _527) + (_326 * _538)) + (_336 * _549)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_341)), 0u) * _560)) / float4(((_527 + _538) + _549) + _560)) * _677)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_351)), 0u) * _583) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_357)), 0u) * _594)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_368)), 0u) * _605)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_378)), 0u) * _616)) / float4(((_583 + _594) + _605) + _616)) * _693);
        float4 _712 = fast::clamp(_700 / float4(((_645 + _661) + _677) + _693), precise::min(precise::min(precise::min(_290, _299), _326), _336), precise::max(precise::max(precise::max(_290, _299), _326), _336));
        float4 _715 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _716 = _715.x;
        float3 _724 = fast::clamp((_712.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_716 == 0.0) ? 1.0 : _716), float3(0.0), float3(65504.0));
        float _725 = _724.x;
        float _728 = 0.5 * _724.y;
        float _730 = _724.z;
        float _731 = 0.25 * _730;
        float _739 = _712.w;
        spvImageFence(rw_new_locks);
        _752 = r_lock_status.sample(s_LinearClamp, _184, level(0.0)).xy;
        _753 = float3(((0.25 * _725) + _728) + _731, 0.5 * (_725 - _730), (((-0.25) * _725) + _728) - _731);
        _754 = _739 < 0.0;
        _755 = sdk_hlsl_load(rw_new_locks, uint2(_155)).x > 0.4980392158031463623046875;
        _756 = fast::clamp(abs(_739), 0.0, 1.0);
    }
    else
    {
        _752 = float2(0.0);
        _753 = float3(0.0);
        _754 = false;
        _755 = false;
        _756 = 0.0;
    }
    float2 _768 = float2(int2(_165 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _776 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _777 = _776.x;
    float _789 = powr(((_777 == 0.0) ? 1.0 : _777) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_160 * _768, _768 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _792 = (_752.y == 0.0) ? _789 : _752.y;
    float2 _793 = _752;
    _793.y = _792;
    float _794 = precise::max(_792, _789);
    float _801;
    if (_794 != 0.0)
    {
        _801 = precise::min(_792, _789) / _794;
    }
    else
    {
        _801 = 0.0;
    }
    float _802 = 1.0 - _801;
    float2 _823;
    if (_755)
    {
        _823 = float2((_752.x != 0.0) ? 2.0 : 1.0, _789);
    }
    else
    {
        float2 _818;
        if (_752.x <= 1.0)
        {
            float2 _817 = _793;
            _817.y = mix(_792, _789, 0.5);
            _818 = _817;
        }
        else
        {
            float2 _815;
            if (_802 > 0.100000001490116119384765625)
            {
                _815 = float2(0.0, _792);
            }
            else
            {
                _815 = _793;
            }
            _818 = _815;
        }
        _823 = _818;
    }
    float _827 = precise::max(precise::max(_210, _756), fast::clamp((0.89999997615814208984375 - _801) * 10.0, 0.0, 1.0));
    float _828 = 1.0 - _827;
    float _836 = ((_823.x * _828) * fast::clamp(1.0 - _211, 0.0, 1.0)) * float(_205 < 0.100000001490116119384765625);
    float _840 = precise::max(_823.y, _789);
    float _847;
    if (_840 != 0.0)
    {
        _847 = precise::min(_823.y, _789) / _840;
    }
    else
    {
        _847 = 0.0;
    }
    float2 _855 = _158 * cbFSR2.fDownscaleFactor;
    int2 _857 = int2(floor(_855));
    float2 _860 = (float2(_857) + float2(0.5)) - cbFSR2.fJitter;
    bool _863 = _860.x > _855.x;
    bool _867 = _860.y > _855.y;
    int2 _869 = int2(_863 ? (-2) : (-1), _867 ? (-2) : (-1));
    float2 _870 = float2(_869);
    int _871 = _863 ? 3 : 0;
    int _872 = _867 ? 3 : 0;
    int2 _873 = int2(_871, _872);
    int2 _874 = _857 + _869;
    int2 _875 = _874 + _873;
    int2 _877 = _875;
    _877.y = _875.y;
    float3 _881 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_877)), 0u).xyz;
    int _882 = _863 ? 2 : 1;
    int2 _883 = int2(_882, _872);
    int2 _884 = _874 + _883;
    int2 _886 = _884;
    _886.y = _884.y;
    float3 _890 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_886)), 0u).xyz;
    int _891 = _863 ? 1 : 2;
    int2 _892 = int2(_891, _872);
    int2 _893 = _874 + _892;
    int2 _895 = _893;
    _895.y = _893.y;
    float3 _899 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_895)), 0u).xyz;
    int _900 = _867 ? 2 : 1;
    int2 _901 = int2(_871, _900);
    int2 _902 = _874 + _901;
    int2 _904 = _902;
    _904.y = _902.y;
    float3 _908 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_904)), 0u).xyz;
    int2 _909 = int2(_882, _900);
    int2 _910 = _874 + _909;
    int2 _912 = _910;
    _912.y = _910.y;
    float3 _916 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_912)), 0u).xyz;
    int2 _917 = int2(_891, _900);
    int2 _918 = _874 + _917;
    int2 _920 = _918;
    _920.y = _918.y;
    float3 _924 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_920)), 0u).xyz;
    int _925 = _867 ? 1 : 2;
    int2 _926 = int2(_871, _925);
    int2 _927 = _874 + _926;
    int2 _929 = _927;
    _929.y = _927.y;
    float3 _933 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_929)), 0u).xyz;
    int2 _934 = int2(_882, _925);
    int2 _935 = _874 + _934;
    int2 _937 = _935;
    _937.y = _935.y;
    float3 _941 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_937)), 0u).xyz;
    int2 _942 = int2(_891, _925);
    int2 _943 = _874 + _942;
    int2 _945 = _943;
    _945.y = _943.y;
    float3 _949 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_945)), 0u).xyz;
    float2 _950 = _860 - _855;
    float _952 = precise::max(_827, float(_215));
    float _959 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _952);
    float _969 = mix(-2.0, -3.0, fast::clamp(_183 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _972 = _950 + (_870 + float2(_873));
    uint2 _974 = uint2(cbFSR2.iRenderSize);
    float2 _978 = float2(mix(_959, precise::max(1.0, (1.0 + _959) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _205, _952))));
    float2 _979 = _972 * _978;
    float _981 = precise::min(dot(_979, _979), 4.0);
    float _983 = (0.4000000059604644775390625 * _981) - 1.0;
    float _985 = (0.25 * _981) - 1.0;
    float _991 = float(all(uint2(_875) < _974)) * ((((1.5625 * _983) * _983) - 0.5625) * (_985 * _985));
    float _999 = exp(_969 * dot(_972, _972));
    float3 _1000 = _881 * _999;
    float2 _1004 = _950 + (_870 + float2(_883));
    float2 _1009 = _1004 * _978;
    float _1011 = precise::min(dot(_1009, _1009), 4.0);
    float _1013 = (0.4000000059604644775390625 * _1011) - 1.0;
    float _1015 = (0.25 * _1011) - 1.0;
    float _1021 = float(all(uint2(_884) < _974)) * ((((1.5625 * _1013) * _1013) - 0.5625) * (_1015 * _1015));
    float _1030 = exp(_969 * dot(_1004, _1004));
    float3 _1033 = _890 * _1030;
    float2 _1040 = _950 + (_870 + float2(_892));
    float2 _1045 = _1040 * _978;
    float _1047 = precise::min(dot(_1045, _1045), 4.0);
    float _1049 = (0.4000000059604644775390625 * _1047) - 1.0;
    float _1051 = (0.25 * _1047) - 1.0;
    float _1057 = float(all(uint2(_893) < _974)) * ((((1.5625 * _1049) * _1049) - 0.5625) * (_1051 * _1051));
    float _1066 = exp(_969 * dot(_1040, _1040));
    float3 _1069 = _899 * _1066;
    float2 _1076 = _950 + (_870 + float2(_901));
    float2 _1081 = _1076 * _978;
    float _1083 = precise::min(dot(_1081, _1081), 4.0);
    float _1085 = (0.4000000059604644775390625 * _1083) - 1.0;
    float _1087 = (0.25 * _1083) - 1.0;
    float _1093 = float(all(uint2(_902) < _974)) * ((((1.5625 * _1085) * _1085) - 0.5625) * (_1087 * _1087));
    float _1102 = exp(_969 * dot(_1076, _1076));
    float3 _1105 = _908 * _1102;
    float2 _1112 = _950 + (_870 + float2(_909));
    float2 _1117 = _1112 * _978;
    float _1119 = precise::min(dot(_1117, _1117), 4.0);
    float _1121 = (0.4000000059604644775390625 * _1119) - 1.0;
    float _1123 = (0.25 * _1119) - 1.0;
    float _1129 = float(all(uint2(_910) < _974)) * ((((1.5625 * _1121) * _1121) - 0.5625) * (_1123 * _1123));
    float _1138 = exp(_969 * dot(_1112, _1112));
    float3 _1141 = _916 * _1138;
    float2 _1148 = _950 + (_870 + float2(_917));
    float2 _1153 = _1148 * _978;
    float _1155 = precise::min(dot(_1153, _1153), 4.0);
    float _1157 = (0.4000000059604644775390625 * _1155) - 1.0;
    float _1159 = (0.25 * _1155) - 1.0;
    float _1165 = float(all(uint2(_918) < _974)) * ((((1.5625 * _1157) * _1157) - 0.5625) * (_1159 * _1159));
    float _1174 = exp(_969 * dot(_1148, _1148));
    float3 _1177 = _924 * _1174;
    float2 _1184 = _950 + (_870 + float2(_926));
    float2 _1189 = _1184 * _978;
    float _1191 = precise::min(dot(_1189, _1189), 4.0);
    float _1193 = (0.4000000059604644775390625 * _1191) - 1.0;
    float _1195 = (0.25 * _1191) - 1.0;
    float _1201 = float(all(uint2(_927) < _974)) * ((((1.5625 * _1193) * _1193) - 0.5625) * (_1195 * _1195));
    float _1210 = exp(_969 * dot(_1184, _1184));
    float3 _1213 = _933 * _1210;
    float2 _1220 = _950 + (_870 + float2(_934));
    float2 _1225 = _1220 * _978;
    float _1227 = precise::min(dot(_1225, _1225), 4.0);
    float _1229 = (0.4000000059604644775390625 * _1227) - 1.0;
    float _1231 = (0.25 * _1227) - 1.0;
    float _1237 = float(all(uint2(_935) < _974)) * ((((1.5625 * _1229) * _1229) - 0.5625) * (_1231 * _1231));
    float _1246 = exp(_969 * dot(_1220, _1220));
    float3 _1249 = _941 * _1246;
    float2 _1256 = _950 + (_870 + float2(_942));
    float2 _1261 = _1256 * _978;
    float _1263 = precise::min(dot(_1261, _1261), 4.0);
    float _1265 = (0.4000000059604644775390625 * _1263) - 1.0;
    float _1267 = (0.25 * _1263) - 1.0;
    float _1273 = float(all(uint2(_943) < _974)) * ((((1.5625 * _1265) * _1265) - 0.5625) * (_1267 * _1267));
    float4 _1279 = (((((((float4(_881 * _991, _991) + float4(_890 * _1021, _1021)) + float4(_899 * _1057, _1057)) + float4(_908 * _1093, _1093)) + float4(_916 * _1129, _1129)) + float4(_924 * _1165, _1165)) + float4(_933 * _1201, _1201)) + float4(_941 * _1237, _1237)) + float4(_949 * _1273, _1273);
    float _1282 = exp(_969 * dot(_1256, _1256));
    float3 _1283 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_881, _890), _899), _908), _916), _924), _933), _941), _949);
    float3 _1284 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_881, _890), _899), _908), _916), _924), _933), _941), _949);
    float3 _1285 = _949 * _1282;
    float _1289 = (((((((_999 + _1030) + _1066) + _1102) + _1138) + _1174) + _1210) + _1246) + _1282;
    float3 _1293 = float3((abs(_1289) > 0.001000000047497451305389404296875) ? _1289 : 1.0);
    float3 _1294 = ((((((((_1000 + _1033) + _1069) + _1105) + _1141) + _1177) + _1213) + _1249) + _1285) / _1293;
    float3 _1299 = sqrt(abs(((((((((((_881 * _1000) + (_890 * _1033)) + (_899 * _1069)) + (_908 * _1105)) + (_916 * _1141)) + (_924 * _1177)) + (_933 * _1213)) + (_941 * _1249)) + (_949 * _1285)) / _1293) - (_1294 * _1294)));
    float _1303 = _1279.w * float(_1279.w > 0.001000000047497451305389404296875);
    float4 _1304 = _1279;
    _1304.w = _1303;
    float4 _1317;
    if (_1303 > 0.001000000047497451305389404296875)
    {
        float3 _1310 = _1304.xyz / float3(_1303);
        float4 _1311 = float4(_1310.x, _1310.y, _1310.z, _1304.w);
        _1311.w = _1303 * 0.083333335816860198974609375;
        float3 _1315 = fast::clamp(_1311.xyz, _1283, _1284);
        _1317 = float4(_1315.x, _1315.y, _1315.z, _1311.w);
    }
    else
    {
        _1317 = _1304;
    }
    float _1321 = rint(_1294.x * 255.0) * 0.0039215688593685626983642578125;
    bool _1328;
    if (precise::max(precise::max(_205, _211), _802) < 0.100000001490116119384765625)
    {
        _1328 = !_215;
    }
    else
    {
        _1328 = false;
    }
    float4 _1336;
    if (_1328)
    {
        _1336 = r_luma_history.sample(s_LinearClamp, _184, level(0.0));
    }
    else
    {
        _1336 = float4(0.0);
    }
    float4 _139 = _1336;
    float _1339 = _1321 - _139.x;
    float _1340 = abs(_1339);
    float _1379;
    if (_1340 >= 0.0039215688593685626983642578125)
    {
        float _1345;
        _1345 = _1340;
        float _1346;
        for (int _1348 = 1; _1348 <= 3; _1345 = _1346, _1348++)
        {
            float _1356 = _1321 - _139[uint(_1348)];
            if (int(sign(_1339)) == int(sign(_1356)))
            {
                _1346 = precise::min(_1345, abs(_1356));
            }
            else
            {
                _1346 = _1345;
            }
        }
        _1379 = float((float(_1345 != _1340) * powr(fast::clamp(_1299.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_211, powr(_827, 0.16666667163372039794921875)));
    }
    else
    {
        _1379 = 0.0;
    }
    _139.w = _139.z;
    _139.z = _139.y;
    _139.y = _139.x;
    _139.x = _1321;
    sdk_hlsl_store(rw_luma_history, _139, uint2(_155));
    float _1396 = (float(_199) * _828) * (1.0 - _205);
    float _1400 = fast::clamp(_183 * 10.0, 0.0, 1.0);
    float _1403 = precise::min(_1396, mix(_1396, _1317.w * 10.0, precise::max(float(_754), _1400)));
    float _1405 = fast::clamp(_183 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1408 = float3(precise::min(_1403, mix(_1403, _1317.w, _1405)));
    float3 _1473;
    if (_215)
    {
        _1473 = float3((_1317.x + _1317.y) - _1317.z, _1317.x + _1317.z, (_1317.x - _1317.y) - _1317.z);
    }
    else
    {
        float3 _1422 = _1299 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_205, precise::max(_211, _1405)));
        float3 _1425 = precise::max(_1283, _1294 - _1422);
        float3 _1426 = precise::min(_1284, _1294 + _1422);
        bool _1434;
        if (!any(_1425 > _753))
        {
            _1434 = any(_753 > _1426);
        }
        else
        {
            _1434 = true;
        }
        float3 _1447;
        float3 _1448;
        if (_1434)
        {
            float3 _1443 = fast::clamp(float3(precise::max(_1379 * float(_139.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_836 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_847, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_210, 0.5)), float3(0.0), float3(1.0));
            _1447 = mix(fast::clamp(_753, _1425, _1426), _753, _1443);
            _1448 = mix(precise::min(_1408, float3(0.100000001490116119384765625)), _1408, _1443);
        }
        else
        {
            _1447 = _753;
            _1448 = _1408;
        }
        float3 _1454 = mix(_1447, _1317.xyz, _1317.www / precise::max(float3(0.001000000047497451305389404296875), _1448 + _1317.www));
        float _1455 = _1454.x;
        float _1456 = _1454.y;
        float _1458 = _1454.z;
        _1473 = float3((_1455 + _1456) - _1458, _1455 + _1458, (_1455 - _1456) - _1458);
    }
    float4 _1475 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1476 = _1475.x;
    float2 _1484 = _160 - _181;
    float _1485 = _1484.x;
    bool _1490;
    if (_1485 >= 0.0)
    {
        _1490 = _1485 <= 1.0;
    }
    else
    {
        _1490 = false;
    }
    bool _1499;
    if (_1490)
    {
        float _1493 = _1484.y;
        bool _1498;
        if (_1493 >= 0.0)
        {
            _1498 = _1493 <= 1.0;
        }
        else
        {
            _1498 = false;
        }
        _1499 = _1498;
    }
    else
    {
        _1499 = false;
    }
    float2 _1512;
    if (!_1499)
    {
        float2 _1511 = _823;
        _1511.x = 0.0;
        _1512 = _1511;
    }
    else
    {
        float2 _1510 = _823;
        _1510.x = precise::max(0.0, _836 - (_1317.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1512 = _1510;
    }
    sdk_hlsl_store(rw_lock_status, _1512.xyyy, uint2(_155));
    float _1514 = precise::min(0.9900000095367431640625, _827);
    float _1517 = precise::max(_1514, mix(_1514, 0.4000000059604644775390625, fast::clamp(_183, 0.0, 1.0)));
    float _1522 = _215 ? 1.0 : precise::max(_1517 * _1517, precise::max(_205 * 0.100000001490116119384765625, _210));
    float _1528;
    if (_1400 >= 1.0)
    {
        _1528 = precise::max(0.001000000047497451305389404296875, _1522) * (-1.0);
    }
    else
    {
        _1528 = _1522;
    }
    sdk_hlsl_store(rw_internal_upscaled_color, float4((_1473 / float3((_1476 == 0.0) ? 1.0 : _1476)) * cbFSR2.fPreExposure, _1528), uint2(_155));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_155));
}

