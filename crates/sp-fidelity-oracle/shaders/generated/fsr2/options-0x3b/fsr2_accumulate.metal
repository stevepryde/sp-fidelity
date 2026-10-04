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

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_motion_vectors [[texture(0)]], texture2d<float> r_input_exposure [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float> r_lock_status [[texture(3)]], texture2d<float> r_prepared_input_color [[texture(4)]], texture2d<float> r_luma_history [[texture(5)]], texture2d<float> r_lanczos_lut [[texture(6)]], texture2d<float> r_imgMips [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(9)]], texture2d<float, access::write> rw_lock_status [[texture(10)]], texture2d<float, access::read_write> rw_new_locks [[texture(11)]], texture2d<float, access::write> rw_luma_history [[texture(12)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _144 = gl_WorkGroupID.xy;
    _144.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _158 = (_144 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _161 = float2(int2(_158)) + float2(0.5);
    float2 _162 = float2(cbFSR2.iDisplaySize);
    float2 _163 = _161 / _162;
    float2 _168 = float2(cbFSR2.iRenderSize);
    float2 _178 = precise::max(float2(0.5), precise::min((_163 + (cbFSR2.fJitter / _168)) * _168, _168 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _187 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_158), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
    float _189 = length(_187 * _162);
    float2 _190 = _163 + _187;
    float _191 = _190.x;
    bool _196;
    if (_191 >= 0.0)
    {
        _196 = _191 <= 1.0;
    }
    else
    {
        _196 = false;
    }
    bool _205;
    if (_196)
    {
        float _199 = _190.y;
        bool _204;
        if (_199 >= 0.0)
        {
            _204 = _199 <= 1.0;
        }
        else
        {
            _204 = false;
        }
        _205 = _204;
    }
    else
    {
        _205 = false;
    }
    float _211 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _178, level(0.0)).w, 0.0, 1.0);
    float4 _215 = r_dilated_reactive_masks.sample(s_LinearClamp, _178, level(0.0));
    float _216 = _215.x;
    float _217 = _215.y;
    bool _220 = 0 == cbFSR2.iFrameIndex;
    bool _221 = _205 ? _220 : true;
    bool _225;
    if (_205)
    {
        _225 = !_220;
    }
    else
    {
        _225 = false;
    }
    float2 _630;
    float3 _631;
    bool _632;
    bool _633;
    float _634;
    if (_225)
    {
        float2 _229 = (_190 * _162) - float2(0.5);
        float2 _239 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _229.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _229.y)));
        float2 _240 = floor(_239);
        int2 _241 = int2(_240);
        float2 _242 = _239 - _240;
        int2 _243 = _241 + int2(-1);
        int _247 = max(_243.y, 0);
        int2 _248 = int2(max(_243.x, 0), _247);
        _248.y = _247;
        int2 _253 = _241 + int2(0, -1);
        int _256 = max(_253.y, 0);
        int2 _257 = int2(_253.x, _256);
        _257.y = _256;
        int2 _262 = _241 + int2(1, -1);
        int _264 = cbFSR2.iDisplaySize.x - 1;
        int _267 = max(_262.y, 0);
        int2 _268 = int2(min(_262.x, _264), _267);
        _268.y = _267;
        int2 _273 = _241 + int2(2, -1);
        int _277 = max(_273.y, 0);
        int2 _278 = int2(min(_273.x, _264), _277);
        _278.y = _277;
        int2 _283 = _241 + int2(-1, 0);
        int _286 = _283.y;
        int2 _287 = int2(max(_283.x, 0), _286);
        _287.y = _286;
        int2 _293 = _241;
        _293.y = _241.y;
        float4 _296 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_293)), 0u);
        int2 _297 = _241 + int2(1, 0);
        int _300 = _297.y;
        int2 _301 = int2(min(_297.x, _264), _300);
        _301.y = _300;
        float4 _305 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_301)), 0u);
        int2 _306 = _241 + int2(2, 0);
        int _309 = _306.y;
        int2 _310 = int2(min(_306.x, _264), _309);
        _310.y = _309;
        int2 _315 = _241 + int2(-1, 1);
        int _318 = _315.y;
        int2 _319 = int2(max(_315.x, 0), _318);
        int _320 = cbFSR2.iDisplaySize.y - 1;
        _319.y = min(_318, _320);
        int2 _326 = _241 + int2(0, 1);
        _326.y = min(_326.y, _320);
        float4 _332 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_326)), 0u);
        int2 _333 = _241 + int2(1);
        int _336 = _333.y;
        int2 _337 = int2(min(_333.x, _264), _336);
        _337.y = min(_336, _320);
        float4 _342 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_337)), 0u);
        int2 _343 = _241 + int2(2, 1);
        int _346 = _343.y;
        int2 _347 = int2(min(_343.x, _264), _346);
        _347.y = min(_346, _320);
        int2 _353 = _241 + int2(-1, 2);
        int _356 = _353.y;
        int2 _357 = int2(max(_353.x, 0), _356);
        _357.y = min(_356, _320);
        int2 _363 = _241 + int2(0, 2);
        _363.y = min(_363.y, _320);
        int2 _370 = _241 + int2(1, 2);
        int _373 = _370.y;
        int2 _374 = int2(min(_370.x, _264), _373);
        _374.y = min(_373, _320);
        int2 _380 = _241 + int2(2);
        int _383 = _380.y;
        int2 _384 = int2(min(_380.x, _264), _383);
        _384.y = min(_383, _320);
        float _390 = _242.x;
        float2 _396 = float2(abs((-1.0) - _390) * 0.5, 0.5);
        float4 _398 = r_lanczos_lut.sample(s_LinearClamp, _396, level(0.0));
        float _399 = _398.x;
        float2 _405 = float2(abs(-_390) * 0.5, 0.5);
        float4 _407 = r_lanczos_lut.sample(s_LinearClamp, _405, level(0.0));
        float _408 = _407.x;
        float2 _414 = float2(abs(1.0 - _390) * 0.5, 0.5);
        float4 _416 = r_lanczos_lut.sample(s_LinearClamp, _414, level(0.0));
        float _417 = _416.x;
        float2 _423 = float2(abs(2.0 - _390) * 0.5, 0.5);
        float4 _425 = r_lanczos_lut.sample(s_LinearClamp, _423, level(0.0));
        float _426 = _425.x;
        float4 _442 = r_lanczos_lut.sample(s_LinearClamp, _396, level(0.0));
        float _443 = _442.x;
        float4 _447 = r_lanczos_lut.sample(s_LinearClamp, _405, level(0.0));
        float _448 = _447.x;
        float4 _452 = r_lanczos_lut.sample(s_LinearClamp, _414, level(0.0));
        float _453 = _452.x;
        float4 _457 = r_lanczos_lut.sample(s_LinearClamp, _423, level(0.0));
        float _458 = _457.x;
        float4 _474 = r_lanczos_lut.sample(s_LinearClamp, _396, level(0.0));
        float _475 = _474.x;
        float4 _479 = r_lanczos_lut.sample(s_LinearClamp, _405, level(0.0));
        float _480 = _479.x;
        float4 _484 = r_lanczos_lut.sample(s_LinearClamp, _414, level(0.0));
        float _485 = _484.x;
        float4 _489 = r_lanczos_lut.sample(s_LinearClamp, _423, level(0.0));
        float _490 = _489.x;
        float4 _506 = r_lanczos_lut.sample(s_LinearClamp, _396, level(0.0));
        float _507 = _506.x;
        float4 _511 = r_lanczos_lut.sample(s_LinearClamp, _405, level(0.0));
        float _512 = _511.x;
        float4 _516 = r_lanczos_lut.sample(s_LinearClamp, _414, level(0.0));
        float _517 = _516.x;
        float4 _521 = r_lanczos_lut.sample(s_LinearClamp, _423, level(0.0));
        float _522 = _521.x;
        float _535 = _242.y;
        float4 _543 = r_lanczos_lut.sample(s_LinearClamp, float2(abs((-1.0) - _535) * 0.5, 0.5), level(0.0));
        float _544 = _543.x;
        float4 _552 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(-_535) * 0.5, 0.5), level(0.0));
        float _553 = _552.x;
        float4 _561 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(1.0 - _535) * 0.5, 0.5), level(0.0));
        float _562 = _561.x;
        float4 _570 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(2.0 - _535) * 0.5, 0.5), level(0.0));
        float _571 = _570.x;
        float4 _578 = ((((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_248)), 0u) * _399) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_257)), 0u) * _408)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_268)), 0u) * _417)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_278)), 0u) * _426)) / float4(((_399 + _408) + _417) + _426)) * _544) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_287)), 0u) * _443) + (_296 * _448)) + (_305 * _453)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_310)), 0u) * _458)) / float4(((_443 + _448) + _453) + _458)) * _553)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_319)), 0u) * _475) + (_332 * _480)) + (_342 * _485)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_347)), 0u) * _490)) / float4(((_475 + _480) + _485) + _490)) * _562)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_357)), 0u) * _507) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_363)), 0u) * _512)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_374)), 0u) * _517)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_384)), 0u) * _522)) / float4(((_507 + _512) + _517) + _522)) * _571);
        float4 _590 = fast::clamp(_578 / float4(((_544 + _553) + _562) + _571), precise::min(precise::min(precise::min(_296, _305), _332), _342), precise::max(precise::max(precise::max(_296, _305), _332), _342));
        float4 _593 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _594 = _593.x;
        float3 _602 = fast::clamp((_590.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_594 == 0.0) ? 1.0 : _594), float3(0.0), float3(65504.0));
        float _603 = _602.x;
        float _606 = 0.5 * _602.y;
        float _608 = _602.z;
        float _609 = 0.25 * _608;
        float _617 = _590.w;
        spvImageFence(rw_new_locks);
        _630 = r_lock_status.sample(s_LinearClamp, _190, level(0.0)).xy;
        _631 = float3(((0.25 * _603) + _606) + _609, 0.5 * (_603 - _608), (((-0.25) * _603) + _606) - _609);
        _632 = _617 < 0.0;
        _633 = sdk_hlsl_load(rw_new_locks, uint2(_158)).x > 0.4980392158031463623046875;
        _634 = fast::clamp(abs(_617), 0.0, 1.0);
    }
    else
    {
        _630 = float2(0.0);
        _631 = float3(0.0);
        _632 = false;
        _633 = false;
        _634 = 0.0;
    }
    float2 _646 = float2(int2(_168 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _654 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _655 = _654.x;
    float _667 = powr(((_655 == 0.0) ? 1.0 : _655) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_163 * _646, _646 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _670 = (_630.y == 0.0) ? _667 : _630.y;
    float2 _671 = _630;
    _671.y = _670;
    float _672 = precise::max(_670, _667);
    float _679;
    if (_672 != 0.0)
    {
        _679 = precise::min(_670, _667) / _672;
    }
    else
    {
        _679 = 0.0;
    }
    float _680 = 1.0 - _679;
    float2 _701;
    if (_633)
    {
        _701 = float2((_630.x != 0.0) ? 2.0 : 1.0, _667);
    }
    else
    {
        float2 _696;
        if (_630.x <= 1.0)
        {
            float2 _695 = _671;
            _695.y = mix(_670, _667, 0.5);
            _696 = _695;
        }
        else
        {
            float2 _693;
            if (_680 > 0.100000001490116119384765625)
            {
                _693 = float2(0.0, _670);
            }
            else
            {
                _693 = _671;
            }
            _696 = _693;
        }
        _701 = _696;
    }
    float _705 = precise::max(precise::max(_216, _634), fast::clamp((0.89999997615814208984375 - _679) * 10.0, 0.0, 1.0));
    float _706 = 1.0 - _705;
    float _714 = ((_701.x * _706) * fast::clamp(1.0 - _217, 0.0, 1.0)) * float(_211 < 0.100000001490116119384765625);
    float _718 = precise::max(_701.y, _667);
    float _725;
    if (_718 != 0.0)
    {
        _725 = precise::min(_701.y, _667) / _718;
    }
    else
    {
        _725 = 0.0;
    }
    float2 _733 = _161 * cbFSR2.fDownscaleFactor;
    int2 _735 = int2(floor(_733));
    float2 _738 = (float2(_735) + float2(0.5)) - cbFSR2.fJitter;
    bool _741 = _738.x > _733.x;
    bool _745 = _738.y > _733.y;
    int2 _747 = int2(_741 ? (-2) : (-1), _745 ? (-2) : (-1));
    float2 _748 = float2(_747);
    int _749 = _741 ? 3 : 0;
    int _750 = _745 ? 3 : 0;
    int2 _751 = int2(_749, _750);
    int2 _752 = _735 + _747;
    int2 _753 = _752 + _751;
    int2 _755 = _753;
    _755.y = _753.y;
    float3 _759 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_755)), 0u).xyz;
    int _760 = _741 ? 2 : 1;
    int2 _761 = int2(_760, _750);
    int2 _762 = _752 + _761;
    int2 _764 = _762;
    _764.y = _762.y;
    float3 _768 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_764)), 0u).xyz;
    int _769 = _741 ? 1 : 2;
    int2 _770 = int2(_769, _750);
    int2 _771 = _752 + _770;
    int2 _773 = _771;
    _773.y = _771.y;
    float3 _777 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_773)), 0u).xyz;
    int _778 = _745 ? 2 : 1;
    int2 _779 = int2(_749, _778);
    int2 _780 = _752 + _779;
    int2 _782 = _780;
    _782.y = _780.y;
    float3 _786 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_782)), 0u).xyz;
    int2 _787 = int2(_760, _778);
    int2 _788 = _752 + _787;
    int2 _790 = _788;
    _790.y = _788.y;
    float3 _794 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_790)), 0u).xyz;
    int2 _795 = int2(_769, _778);
    int2 _796 = _752 + _795;
    int2 _798 = _796;
    _798.y = _796.y;
    float3 _802 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_798)), 0u).xyz;
    int _803 = _745 ? 1 : 2;
    int2 _804 = int2(_749, _803);
    int2 _805 = _752 + _804;
    int2 _807 = _805;
    _807.y = _805.y;
    float3 _811 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_807)), 0u).xyz;
    int2 _812 = int2(_760, _803);
    int2 _813 = _752 + _812;
    int2 _815 = _813;
    _815.y = _813.y;
    float3 _819 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_815)), 0u).xyz;
    int2 _820 = int2(_769, _803);
    int2 _821 = _752 + _820;
    int2 _823 = _821;
    _823.y = _821.y;
    float3 _827 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_823)), 0u).xyz;
    float2 _828 = _738 - _733;
    float _830 = precise::max(_705, float(_221));
    float _837 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _830);
    float _847 = mix(-2.0, -3.0, fast::clamp(_189 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _850 = _828 + (_748 + float2(_751));
    uint2 _852 = uint2(cbFSR2.iRenderSize);
    float2 _856 = float2(mix(_837, precise::max(1.0, (1.0 + _837) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _211, _830))));
    float2 _857 = _850 * _856;
    float _859 = precise::min(dot(_857, _857), 4.0);
    float _861 = (0.4000000059604644775390625 * _859) - 1.0;
    float _863 = (0.25 * _859) - 1.0;
    float _869 = float(all(uint2(_753) < _852)) * ((((1.5625 * _861) * _861) - 0.5625) * (_863 * _863));
    float _877 = exp(_847 * dot(_850, _850));
    float3 _878 = _759 * _877;
    float2 _882 = _828 + (_748 + float2(_761));
    float2 _887 = _882 * _856;
    float _889 = precise::min(dot(_887, _887), 4.0);
    float _891 = (0.4000000059604644775390625 * _889) - 1.0;
    float _893 = (0.25 * _889) - 1.0;
    float _899 = float(all(uint2(_762) < _852)) * ((((1.5625 * _891) * _891) - 0.5625) * (_893 * _893));
    float _908 = exp(_847 * dot(_882, _882));
    float3 _911 = _768 * _908;
    float2 _918 = _828 + (_748 + float2(_770));
    float2 _923 = _918 * _856;
    float _925 = precise::min(dot(_923, _923), 4.0);
    float _927 = (0.4000000059604644775390625 * _925) - 1.0;
    float _929 = (0.25 * _925) - 1.0;
    float _935 = float(all(uint2(_771) < _852)) * ((((1.5625 * _927) * _927) - 0.5625) * (_929 * _929));
    float _944 = exp(_847 * dot(_918, _918));
    float3 _947 = _777 * _944;
    float2 _954 = _828 + (_748 + float2(_779));
    float2 _959 = _954 * _856;
    float _961 = precise::min(dot(_959, _959), 4.0);
    float _963 = (0.4000000059604644775390625 * _961) - 1.0;
    float _965 = (0.25 * _961) - 1.0;
    float _971 = float(all(uint2(_780) < _852)) * ((((1.5625 * _963) * _963) - 0.5625) * (_965 * _965));
    float _980 = exp(_847 * dot(_954, _954));
    float3 _983 = _786 * _980;
    float2 _990 = _828 + (_748 + float2(_787));
    float2 _995 = _990 * _856;
    float _997 = precise::min(dot(_995, _995), 4.0);
    float _999 = (0.4000000059604644775390625 * _997) - 1.0;
    float _1001 = (0.25 * _997) - 1.0;
    float _1007 = float(all(uint2(_788) < _852)) * ((((1.5625 * _999) * _999) - 0.5625) * (_1001 * _1001));
    float _1016 = exp(_847 * dot(_990, _990));
    float3 _1019 = _794 * _1016;
    float2 _1026 = _828 + (_748 + float2(_795));
    float2 _1031 = _1026 * _856;
    float _1033 = precise::min(dot(_1031, _1031), 4.0);
    float _1035 = (0.4000000059604644775390625 * _1033) - 1.0;
    float _1037 = (0.25 * _1033) - 1.0;
    float _1043 = float(all(uint2(_796) < _852)) * ((((1.5625 * _1035) * _1035) - 0.5625) * (_1037 * _1037));
    float _1052 = exp(_847 * dot(_1026, _1026));
    float3 _1055 = _802 * _1052;
    float2 _1062 = _828 + (_748 + float2(_804));
    float2 _1067 = _1062 * _856;
    float _1069 = precise::min(dot(_1067, _1067), 4.0);
    float _1071 = (0.4000000059604644775390625 * _1069) - 1.0;
    float _1073 = (0.25 * _1069) - 1.0;
    float _1079 = float(all(uint2(_805) < _852)) * ((((1.5625 * _1071) * _1071) - 0.5625) * (_1073 * _1073));
    float _1088 = exp(_847 * dot(_1062, _1062));
    float3 _1091 = _811 * _1088;
    float2 _1098 = _828 + (_748 + float2(_812));
    float2 _1103 = _1098 * _856;
    float _1105 = precise::min(dot(_1103, _1103), 4.0);
    float _1107 = (0.4000000059604644775390625 * _1105) - 1.0;
    float _1109 = (0.25 * _1105) - 1.0;
    float _1115 = float(all(uint2(_813) < _852)) * ((((1.5625 * _1107) * _1107) - 0.5625) * (_1109 * _1109));
    float _1124 = exp(_847 * dot(_1098, _1098));
    float3 _1127 = _819 * _1124;
    float2 _1134 = _828 + (_748 + float2(_820));
    float2 _1139 = _1134 * _856;
    float _1141 = precise::min(dot(_1139, _1139), 4.0);
    float _1143 = (0.4000000059604644775390625 * _1141) - 1.0;
    float _1145 = (0.25 * _1141) - 1.0;
    float _1151 = float(all(uint2(_821) < _852)) * ((((1.5625 * _1143) * _1143) - 0.5625) * (_1145 * _1145));
    float4 _1157 = (((((((float4(_759 * _869, _869) + float4(_768 * _899, _899)) + float4(_777 * _935, _935)) + float4(_786 * _971, _971)) + float4(_794 * _1007, _1007)) + float4(_802 * _1043, _1043)) + float4(_811 * _1079, _1079)) + float4(_819 * _1115, _1115)) + float4(_827 * _1151, _1151);
    float _1160 = exp(_847 * dot(_1134, _1134));
    float3 _1161 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_759, _768), _777), _786), _794), _802), _811), _819), _827);
    float3 _1162 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_759, _768), _777), _786), _794), _802), _811), _819), _827);
    float3 _1163 = _827 * _1160;
    float _1167 = (((((((_877 + _908) + _944) + _980) + _1016) + _1052) + _1088) + _1124) + _1160;
    float3 _1171 = float3((abs(_1167) > 0.001000000047497451305389404296875) ? _1167 : 1.0);
    float3 _1172 = ((((((((_878 + _911) + _947) + _983) + _1019) + _1055) + _1091) + _1127) + _1163) / _1171;
    float3 _1177 = sqrt(abs(((((((((((_759 * _878) + (_768 * _911)) + (_777 * _947)) + (_786 * _983)) + (_794 * _1019)) + (_802 * _1055)) + (_811 * _1091)) + (_819 * _1127)) + (_827 * _1163)) / _1171) - (_1172 * _1172)));
    float _1181 = _1157.w * float(_1157.w > 0.001000000047497451305389404296875);
    float4 _1182 = _1157;
    _1182.w = _1181;
    float4 _1195;
    if (_1181 > 0.001000000047497451305389404296875)
    {
        float3 _1188 = _1182.xyz / float3(_1181);
        float4 _1189 = float4(_1188.x, _1188.y, _1188.z, _1182.w);
        _1189.w = _1181 * 0.083333335816860198974609375;
        float3 _1193 = fast::clamp(_1189.xyz, _1161, _1162);
        _1195 = float4(_1193.x, _1193.y, _1193.z, _1189.w);
    }
    else
    {
        _1195 = _1182;
    }
    float _1196 = _1172.x;
    float _1202 = rint((_1196 / (1.0 + precise::max(0.0, _1196))) * 255.0) * 0.0039215688593685626983642578125;
    bool _1209;
    if (precise::max(precise::max(_211, _217), _680) < 0.100000001490116119384765625)
    {
        _1209 = !_221;
    }
    else
    {
        _1209 = false;
    }
    float4 _1217;
    if (_1209)
    {
        _1217 = r_luma_history.sample(s_LinearClamp, _190, level(0.0));
    }
    else
    {
        _1217 = float4(0.0);
    }
    float4 _142 = _1217;
    float _1220 = _1202 - _142.x;
    float _1221 = abs(_1220);
    float _1260;
    if (_1221 >= 0.0039215688593685626983642578125)
    {
        float _1226;
        _1226 = _1221;
        float _1227;
        for (int _1229 = 1; _1229 <= 3; _1226 = _1227, _1229++)
        {
            float _1237 = _1202 - _142[uint(_1229)];
            if (int(sign(_1220)) == int(sign(_1237)))
            {
                _1227 = precise::min(_1226, abs(_1237));
            }
            else
            {
                _1227 = _1226;
            }
        }
        _1260 = float((float(_1226 != _1221) * powr(fast::clamp(_1177.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_217, powr(_705, 0.16666667163372039794921875)));
    }
    else
    {
        _1260 = 0.0;
    }
    _142.w = _142.z;
    _142.z = _142.y;
    _142.y = _142.x;
    _142.x = _1202;
    sdk_hlsl_store(rw_luma_history, _142, uint2(_158));
    float _1277 = (float(_205) * _706) * (1.0 - _211);
    float _1281 = fast::clamp(_189 * 10.0, 0.0, 1.0);
    float _1284 = precise::min(_1277, mix(_1277, _1195.w * 10.0, precise::max(float(_632), _1281)));
    float _1286 = fast::clamp(_189 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1289 = float3(precise::min(_1284, mix(_1284, _1195.w, _1286)));
    float3 _1419;
    if (_221)
    {
        _1419 = float3((_1195.x + _1195.y) - _1195.z, _1195.x + _1195.z, (_1195.x - _1195.y) - _1195.z);
    }
    else
    {
        float3 _1303 = _1177 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_211, precise::max(_217, _1286)));
        float3 _1306 = precise::max(_1161, _1172 - _1303);
        float3 _1307 = precise::min(_1162, _1172 + _1303);
        bool _1315;
        if (!any(_1306 > _631))
        {
            _1315 = any(_631 > _1307);
        }
        else
        {
            _1315 = true;
        }
        float3 _1328;
        float3 _1329;
        if (_1315)
        {
            float3 _1324 = fast::clamp(float3(precise::max(_1260 * float(_142.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_714 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_725, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_216, 0.5)), float3(0.0), float3(1.0));
            _1328 = mix(fast::clamp(_631, _1306, _1307), _631, _1324);
            _1329 = mix(precise::min(_1289, float3(0.100000001490116119384765625)), _1289, _1324);
        }
        else
        {
            _1328 = _631;
            _1329 = _1289;
        }
        float _1337 = (_1195.x + _1195.y) - _1195.z;
        float _1338 = _1195.x + _1195.z;
        float _1340 = (_1195.x - _1195.y) - _1195.z;
        float3 _1347 = float3(_1337, _1338, _1340) / float3(precise::max(precise::max(0.0, _1337), precise::max(_1338, _1340)) + 1.0);
        float _1348 = _1347.x;
        float _1351 = 0.5 * _1347.y;
        float _1353 = _1347.z;
        float _1354 = 0.25 * _1353;
        float _1366 = (_1328.x + _1328.y) - _1328.z;
        float _1367 = _1328.x + _1328.z;
        float _1369 = (_1328.x - _1328.y) - _1328.z;
        float3 _1376 = float3(_1366, _1367, _1369) / float3(precise::max(precise::max(0.0, _1366), precise::max(_1367, _1369)) + 1.0);
        float _1377 = _1376.x;
        float _1380 = 0.5 * _1376.y;
        float _1382 = _1376.z;
        float _1383 = 0.25 * _1382;
        float3 _1394 = mix(float3(((0.25 * _1377) + _1380) + _1383, 0.5 * (_1377 - _1382), (((-0.25) * _1377) + _1380) - _1383), float3(((0.25 * _1348) + _1351) + _1354, 0.5 * (_1348 - _1353), (((-0.25) * _1348) + _1351) - _1354).xyz, _1195.www / precise::max(float3(0.001000000047497451305389404296875), _1329 + _1195.www));
        float _1399 = (_1394.x + _1394.y) - _1394.z;
        float _1400 = _1394.x + _1394.z;
        float _1402 = (_1394.x - _1394.y) - _1394.z;
        _1419 = float3(_1399, _1400, _1402) / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_1399, precise::max(_1400, _1402))));
    }
    float4 _1421 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1422 = _1421.x;
    float2 _1430 = _163 - _187;
    float _1431 = _1430.x;
    bool _1436;
    if (_1431 >= 0.0)
    {
        _1436 = _1431 <= 1.0;
    }
    else
    {
        _1436 = false;
    }
    bool _1445;
    if (_1436)
    {
        float _1439 = _1430.y;
        bool _1444;
        if (_1439 >= 0.0)
        {
            _1444 = _1439 <= 1.0;
        }
        else
        {
            _1444 = false;
        }
        _1445 = _1444;
    }
    else
    {
        _1445 = false;
    }
    float2 _1458;
    if (!_1445)
    {
        float2 _1457 = _701;
        _1457.x = 0.0;
        _1458 = _1457;
    }
    else
    {
        float2 _1456 = _701;
        _1456.x = precise::max(0.0, _714 - (_1195.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1458 = _1456;
    }
    sdk_hlsl_store(rw_lock_status, _1458.xyyy, uint2(_158));
    float _1460 = precise::min(0.9900000095367431640625, _705);
    float _1463 = precise::max(_1460, mix(_1460, 0.4000000059604644775390625, fast::clamp(_189, 0.0, 1.0)));
    float _1468 = _221 ? 1.0 : precise::max(_1463 * _1463, precise::max(_211 * 0.100000001490116119384765625, _216));
    float _1474;
    if (_1281 >= 1.0)
    {
        _1474 = precise::max(0.001000000047497451305389404296875, _1468) * (-1.0);
    }
    else
    {
        _1474 = _1468;
    }
    sdk_hlsl_store(rw_internal_upscaled_color, float4((_1419 / float3((_1422 == 0.0) ? 1.0 : _1422)) * cbFSR2.fPreExposure, _1474), uint2(_158));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_158));
}

