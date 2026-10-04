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

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_exposure [[texture(0)]], texture2d<float> r_dilated_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float> r_lock_status [[texture(3)]], texture2d<float> r_prepared_input_color [[texture(4)]], texture2d<float> r_luma_history [[texture(5)]], texture2d<float> r_lanczos_lut [[texture(6)]], texture2d<float> r_imgMips [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(9)]], texture2d<float, access::write> rw_lock_status [[texture(10)]], texture2d<float, access::read_write> rw_new_locks [[texture(11)]], texture2d<float, access::write> rw_luma_history [[texture(12)]], texture2d<float, access::write> rw_upscaled_output [[texture(13)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
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
    float2 _682;
    float3 _683;
    bool _684;
    bool _685;
    float _686;
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
        float2 _420 = float2(float(abs(half(-1.0) - _413)) * 0.5, 0.5);
        half _424 = half(r_lanczos_lut.sample(s_LinearClamp, _420, level(0.0)).x);
        float2 _431 = float2(float(abs(half(-0.0) - _413)) * 0.5, 0.5);
        half _435 = half(r_lanczos_lut.sample(s_LinearClamp, _431, level(0.0)).x);
        float2 _442 = float2(float(abs(half(1.0) - _413)) * 0.5, 0.5);
        half _446 = half(r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0)).x);
        float2 _453 = float2(float(abs(half(2.0) - _413)) * 0.5, 0.5);
        half _457 = half(r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0)).x);
        half _475 = half(r_lanczos_lut.sample(s_LinearClamp, _420, level(0.0)).x);
        half _481 = half(r_lanczos_lut.sample(s_LinearClamp, _431, level(0.0)).x);
        half _487 = half(r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0)).x);
        half _493 = half(r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0)).x);
        half _511 = half(r_lanczos_lut.sample(s_LinearClamp, _420, level(0.0)).x);
        half _517 = half(r_lanczos_lut.sample(s_LinearClamp, _431, level(0.0)).x);
        half _523 = half(r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0)).x);
        half _529 = half(r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0)).x);
        half _547 = half(r_lanczos_lut.sample(s_LinearClamp, _420, level(0.0)).x);
        half _553 = half(r_lanczos_lut.sample(s_LinearClamp, _431, level(0.0)).x);
        half _559 = half(r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0)).x);
        half _565 = half(r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0)).x);
        half _578 = _249.y;
        half _589 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-1.0) - _578)) * 0.5, 0.5), level(0.0)).x);
        half _600 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-0.0) - _578)) * 0.5, 0.5), level(0.0)).x);
        half _611 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(1.0) - _578)) * 0.5, 0.5), level(0.0)).x);
        half _622 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(2.0) - _578)) * 0.5, 0.5), level(0.0)).x);
        half4 _629 = ((((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_255)), 0u)) * _424) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_265)), 0u)) * _435)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_277)), 0u)) * _446)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_288)), 0u)) * _457)) / half4(((_424 + _435) + _446) + _457)) * _589) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_298)), 0u)) * _475) + (_309 * _481)) + (_319 * _487)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_324)), 0u)) * _493)) / half4(((_475 + _481) + _487) + _493)) * _600)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_334)), 0u)) * _511) + (_349 * _517)) + (_360 * _523)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_365)), 0u)) * _529)) / half4(((_511 + _517) + _523) + _529)) * _611)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_376)), 0u)) * _547) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_383)), 0u)) * _553)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_395)), 0u)) * _559)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_406)), 0u)) * _565)) / half4(((_547 + _553) + _559) + _565)) * _622);
        float4 _642 = float4(clamp(_629 / half4(((_589 + _600) + _611) + _622), min(min(min(_309, _319), _349), _360), max(max(max(_309, _319), _349), _360)));
        float4 _645 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _646 = _645.x;
        float3 _654 = fast::clamp((_642.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_646 == 0.0) ? 1.0 : _646), float3(0.0), float3(65504.0));
        float _655 = _654.x;
        float _658 = 0.5 * _654.y;
        float _660 = _654.z;
        float _661 = 0.25 * _660;
        float _669 = _642.w;
        spvImageFence(rw_new_locks);
        _682 = r_lock_status.sample(s_LinearClamp, _196, level(0.0)).xy;
        _683 = float3(((0.25 * _655) + _658) + _661, 0.5 * (_655 - _660), (((-0.25) * _655) + _658) - _661);
        _684 = _669 < 0.0;
        _685 = sdk_hlsl_load(rw_new_locks, uint2(_166)).x > 0.4980392158031463623046875;
        _686 = fast::clamp(abs(_669), 0.0, 1.0);
    }
    else
    {
        _682 = float2(0.0);
        _683 = float3(0.0);
        _684 = false;
        _685 = false;
        _686 = 0.0;
    }
    float2 _698 = float2(int2(_176 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _706 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _707 = _706.x;
    float _719 = powr(((_707 == 0.0) ? 1.0 : _707) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_171 * _698, _698 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _722 = (_682.y == 0.0) ? _719 : _682.y;
    float2 _723 = _682;
    _723.y = _722;
    float _724 = precise::max(_722, _719);
    float _731;
    if (_724 != 0.0)
    {
        _731 = precise::min(_722, _719) / _724;
    }
    else
    {
        _731 = 0.0;
    }
    float _732 = 1.0 - _731;
    float2 _753;
    if (_685)
    {
        _753 = float2((_682.x != 0.0) ? 2.0 : 1.0, _719);
    }
    else
    {
        float2 _748;
        if (_682.x <= 1.0)
        {
            float2 _747 = _723;
            _747.y = mix(_722, _719, 0.5);
            _748 = _747;
        }
        else
        {
            float2 _745;
            if (_732 > 0.100000001490116119384765625)
            {
                _745 = float2(0.0, _722);
            }
            else
            {
                _745 = _723;
            }
            _748 = _745;
        }
        _753 = _748;
    }
    float _757 = precise::max(precise::max(_222, _686), fast::clamp((0.89999997615814208984375 - _731) * 10.0, 0.0, 1.0));
    float _758 = 1.0 - _757;
    float _766 = ((_753.x * _758) * fast::clamp(1.0 - _223, 0.0, 1.0)) * float(_217 < 0.100000001490116119384765625);
    float _770 = precise::max(_753.y, _719);
    float _777;
    if (_770 != 0.0)
    {
        _777 = precise::min(_753.y, _719) / _770;
    }
    else
    {
        _777 = 0.0;
    }
    float2 _785 = _169 * cbFSR2.fDownscaleFactor;
    int2 _787 = int2(floor(_785));
    float2 _790 = (float2(_787) + float2(0.5)) - cbFSR2.fJitter;
    bool _793 = _790.x > _785.x;
    bool _797 = _790.y > _785.y;
    int2 _799 = int2(_793 ? (-2) : (-1), _797 ? (-2) : (-1));
    float2 _800 = float2(_799);
    int _801 = _793 ? 3 : 0;
    int _802 = _797 ? 3 : 0;
    int2 _803 = int2(_801, _802);
    int2 _804 = _787 + _799;
    int2 _805 = _804 + _803;
    int2 _807 = _805;
    _807.y = _805.y;
    float3 _811 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_807)), 0u).xyz;
    int _812 = _793 ? 2 : 1;
    int2 _813 = int2(_812, _802);
    int2 _814 = _804 + _813;
    int2 _816 = _814;
    _816.y = _814.y;
    float3 _820 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_816)), 0u).xyz;
    int _821 = _793 ? 1 : 2;
    int2 _822 = int2(_821, _802);
    int2 _823 = _804 + _822;
    int2 _825 = _823;
    _825.y = _823.y;
    float3 _829 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_825)), 0u).xyz;
    int _830 = _797 ? 2 : 1;
    int2 _831 = int2(_801, _830);
    int2 _832 = _804 + _831;
    int2 _834 = _832;
    _834.y = _832.y;
    float3 _838 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_834)), 0u).xyz;
    int2 _839 = int2(_812, _830);
    int2 _840 = _804 + _839;
    int2 _842 = _840;
    _842.y = _840.y;
    float3 _846 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_842)), 0u).xyz;
    int2 _847 = int2(_821, _830);
    int2 _848 = _804 + _847;
    int2 _850 = _848;
    _850.y = _848.y;
    float3 _854 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_850)), 0u).xyz;
    int _855 = _797 ? 1 : 2;
    int2 _856 = int2(_801, _855);
    int2 _857 = _804 + _856;
    int2 _859 = _857;
    _859.y = _857.y;
    float3 _863 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_859)), 0u).xyz;
    int2 _864 = int2(_812, _855);
    int2 _865 = _804 + _864;
    int2 _867 = _865;
    _867.y = _865.y;
    float3 _871 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_867)), 0u).xyz;
    int2 _872 = int2(_821, _855);
    int2 _873 = _804 + _872;
    int2 _875 = _873;
    _875.y = _873.y;
    float3 _879 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_875)), 0u).xyz;
    float2 _880 = _790 - _785;
    float _882 = precise::max(_757, float(_227));
    float _889 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _882);
    float _899 = mix(-2.0, -3.0, fast::clamp(_195 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _902 = _880 + (_800 + float2(_803));
    uint2 _904 = uint2(cbFSR2.iRenderSize);
    float2 _908 = float2(mix(_889, precise::max(1.0, (1.0 + _889) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _217, _882))));
    float2 _909 = _902 * _908;
    float _911 = precise::min(dot(_909, _909), 4.0);
    float _913 = (0.4000000059604644775390625 * _911) - 1.0;
    float _915 = (0.25 * _911) - 1.0;
    float _921 = float(all(uint2(_805) < _904)) * ((((1.5625 * _913) * _913) - 0.5625) * (_915 * _915));
    float _929 = exp(_899 * dot(_902, _902));
    float3 _930 = _811 * _929;
    float2 _934 = _880 + (_800 + float2(_813));
    float2 _939 = _934 * _908;
    float _941 = precise::min(dot(_939, _939), 4.0);
    float _943 = (0.4000000059604644775390625 * _941) - 1.0;
    float _945 = (0.25 * _941) - 1.0;
    float _951 = float(all(uint2(_814) < _904)) * ((((1.5625 * _943) * _943) - 0.5625) * (_945 * _945));
    float _960 = exp(_899 * dot(_934, _934));
    float3 _963 = _820 * _960;
    float2 _970 = _880 + (_800 + float2(_822));
    float2 _975 = _970 * _908;
    float _977 = precise::min(dot(_975, _975), 4.0);
    float _979 = (0.4000000059604644775390625 * _977) - 1.0;
    float _981 = (0.25 * _977) - 1.0;
    float _987 = float(all(uint2(_823) < _904)) * ((((1.5625 * _979) * _979) - 0.5625) * (_981 * _981));
    float _996 = exp(_899 * dot(_970, _970));
    float3 _999 = _829 * _996;
    float2 _1006 = _880 + (_800 + float2(_831));
    float2 _1011 = _1006 * _908;
    float _1013 = precise::min(dot(_1011, _1011), 4.0);
    float _1015 = (0.4000000059604644775390625 * _1013) - 1.0;
    float _1017 = (0.25 * _1013) - 1.0;
    float _1023 = float(all(uint2(_832) < _904)) * ((((1.5625 * _1015) * _1015) - 0.5625) * (_1017 * _1017));
    float _1032 = exp(_899 * dot(_1006, _1006));
    float3 _1035 = _838 * _1032;
    float2 _1042 = _880 + (_800 + float2(_839));
    float2 _1047 = _1042 * _908;
    float _1049 = precise::min(dot(_1047, _1047), 4.0);
    float _1051 = (0.4000000059604644775390625 * _1049) - 1.0;
    float _1053 = (0.25 * _1049) - 1.0;
    float _1059 = float(all(uint2(_840) < _904)) * ((((1.5625 * _1051) * _1051) - 0.5625) * (_1053 * _1053));
    float _1068 = exp(_899 * dot(_1042, _1042));
    float3 _1071 = _846 * _1068;
    float2 _1078 = _880 + (_800 + float2(_847));
    float2 _1083 = _1078 * _908;
    float _1085 = precise::min(dot(_1083, _1083), 4.0);
    float _1087 = (0.4000000059604644775390625 * _1085) - 1.0;
    float _1089 = (0.25 * _1085) - 1.0;
    float _1095 = float(all(uint2(_848) < _904)) * ((((1.5625 * _1087) * _1087) - 0.5625) * (_1089 * _1089));
    float _1104 = exp(_899 * dot(_1078, _1078));
    float3 _1107 = _854 * _1104;
    float2 _1114 = _880 + (_800 + float2(_856));
    float2 _1119 = _1114 * _908;
    float _1121 = precise::min(dot(_1119, _1119), 4.0);
    float _1123 = (0.4000000059604644775390625 * _1121) - 1.0;
    float _1125 = (0.25 * _1121) - 1.0;
    float _1131 = float(all(uint2(_857) < _904)) * ((((1.5625 * _1123) * _1123) - 0.5625) * (_1125 * _1125));
    float _1140 = exp(_899 * dot(_1114, _1114));
    float3 _1143 = _863 * _1140;
    float2 _1150 = _880 + (_800 + float2(_864));
    float2 _1155 = _1150 * _908;
    float _1157 = precise::min(dot(_1155, _1155), 4.0);
    float _1159 = (0.4000000059604644775390625 * _1157) - 1.0;
    float _1161 = (0.25 * _1157) - 1.0;
    float _1167 = float(all(uint2(_865) < _904)) * ((((1.5625 * _1159) * _1159) - 0.5625) * (_1161 * _1161));
    float _1176 = exp(_899 * dot(_1150, _1150));
    float3 _1179 = _871 * _1176;
    float2 _1186 = _880 + (_800 + float2(_872));
    float2 _1191 = _1186 * _908;
    float _1193 = precise::min(dot(_1191, _1191), 4.0);
    float _1195 = (0.4000000059604644775390625 * _1193) - 1.0;
    float _1197 = (0.25 * _1193) - 1.0;
    float _1203 = float(all(uint2(_873) < _904)) * ((((1.5625 * _1195) * _1195) - 0.5625) * (_1197 * _1197));
    float4 _1209 = (((((((float4(_811 * _921, _921) + float4(_820 * _951, _951)) + float4(_829 * _987, _987)) + float4(_838 * _1023, _1023)) + float4(_846 * _1059, _1059)) + float4(_854 * _1095, _1095)) + float4(_863 * _1131, _1131)) + float4(_871 * _1167, _1167)) + float4(_879 * _1203, _1203);
    float _1212 = exp(_899 * dot(_1186, _1186));
    float3 _1213 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_811, _820), _829), _838), _846), _854), _863), _871), _879);
    float3 _1214 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_811, _820), _829), _838), _846), _854), _863), _871), _879);
    float3 _1215 = _879 * _1212;
    float _1219 = (((((((_929 + _960) + _996) + _1032) + _1068) + _1104) + _1140) + _1176) + _1212;
    float3 _1223 = float3((abs(_1219) > 0.001000000047497451305389404296875) ? _1219 : 1.0);
    float3 _1224 = ((((((((_930 + _963) + _999) + _1035) + _1071) + _1107) + _1143) + _1179) + _1215) / _1223;
    float3 _1229 = sqrt(abs(((((((((((_811 * _930) + (_820 * _963)) + (_829 * _999)) + (_838 * _1035)) + (_846 * _1071)) + (_854 * _1107)) + (_863 * _1143)) + (_871 * _1179)) + (_879 * _1215)) / _1223) - (_1224 * _1224)));
    float _1233 = _1209.w * float(_1209.w > 0.001000000047497451305389404296875);
    float4 _1234 = _1209;
    _1234.w = _1233;
    float4 _1247;
    if (_1233 > 0.001000000047497451305389404296875)
    {
        float3 _1240 = _1234.xyz / float3(_1233);
        float4 _1241 = float4(_1240.x, _1240.y, _1240.z, _1234.w);
        _1241.w = _1233 * 0.083333335816860198974609375;
        float3 _1245 = fast::clamp(_1241.xyz, _1213, _1214);
        _1247 = float4(_1245.x, _1245.y, _1245.z, _1241.w);
    }
    else
    {
        _1247 = _1234;
    }
    float _1251 = rint(_1224.x * 255.0) * 0.0039215688593685626983642578125;
    bool _1258;
    if (precise::max(precise::max(_217, _223), _732) < 0.100000001490116119384765625)
    {
        _1258 = !_227;
    }
    else
    {
        _1258 = false;
    }
    float4 _1266;
    if (_1258)
    {
        _1266 = r_luma_history.sample(s_LinearClamp, _196, level(0.0));
    }
    else
    {
        _1266 = float4(0.0);
    }
    float4 _150 = _1266;
    float _1269 = _1251 - _150.x;
    float _1270 = abs(_1269);
    float _1309;
    if (_1270 >= 0.0039215688593685626983642578125)
    {
        float _1275;
        _1275 = _1270;
        float _1276;
        for (int _1278 = 1; _1278 <= 3; _1275 = _1276, _1278++)
        {
            float _1286 = _1251 - _150[uint(_1278)];
            if (int(sign(_1269)) == int(sign(_1286)))
            {
                _1276 = precise::min(_1275, abs(_1286));
            }
            else
            {
                _1276 = _1275;
            }
        }
        _1309 = float((float(_1275 != _1270) * powr(fast::clamp(_1229.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_223, powr(_757, 0.16666667163372039794921875)));
    }
    else
    {
        _1309 = 0.0;
    }
    _150.w = _150.z;
    _150.z = _150.y;
    _150.y = _150.x;
    _150.x = _1251;
    sdk_hlsl_store(rw_luma_history, _150, uint2(_166));
    float _1326 = (float(_211) * _758) * (1.0 - _217);
    float _1330 = fast::clamp(_195 * 10.0, 0.0, 1.0);
    float _1333 = precise::min(_1326, mix(_1326, _1247.w * 10.0, precise::max(float(_684), _1330)));
    float _1335 = fast::clamp(_195 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1338 = float3(precise::min(_1333, mix(_1333, _1247.w, _1335)));
    float3 _1403;
    if (_227)
    {
        _1403 = float3((_1247.x + _1247.y) - _1247.z, _1247.x + _1247.z, (_1247.x - _1247.y) - _1247.z);
    }
    else
    {
        float3 _1352 = _1229 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_217, precise::max(_223, _1335)));
        float3 _1355 = precise::max(_1213, _1224 - _1352);
        float3 _1356 = precise::min(_1214, _1224 + _1352);
        bool _1364;
        if (!any(_1355 > _683))
        {
            _1364 = any(_683 > _1356);
        }
        else
        {
            _1364 = true;
        }
        float3 _1377;
        float3 _1378;
        if (_1364)
        {
            float3 _1373 = fast::clamp(float3(precise::max(_1309 * float(_150.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_766 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_777, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_222, 0.5)), float3(0.0), float3(1.0));
            _1377 = mix(fast::clamp(_683, _1355, _1356), _683, _1373);
            _1378 = mix(precise::min(_1338, float3(0.100000001490116119384765625)), _1338, _1373);
        }
        else
        {
            _1377 = _683;
            _1378 = _1338;
        }
        float3 _1384 = mix(_1377, _1247.xyz, _1247.www / precise::max(float3(0.001000000047497451305389404296875), _1378 + _1247.www));
        float _1385 = _1384.x;
        float _1386 = _1384.y;
        float _1388 = _1384.z;
        _1403 = float3((_1385 + _1386) - _1388, _1385 + _1388, (_1385 - _1386) - _1388);
    }
    float4 _1405 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1406 = _1405.x;
    float3 _1413 = (_1403 / float3((_1406 == 0.0) ? 1.0 : _1406)) * cbFSR2.fPreExposure;
    float2 _1414 = _171 - _193;
    float _1415 = _1414.x;
    bool _1420;
    if (_1415 >= 0.0)
    {
        _1420 = _1415 <= 1.0;
    }
    else
    {
        _1420 = false;
    }
    bool _1429;
    if (_1420)
    {
        float _1423 = _1414.y;
        bool _1428;
        if (_1423 >= 0.0)
        {
            _1428 = _1423 <= 1.0;
        }
        else
        {
            _1428 = false;
        }
        _1429 = _1428;
    }
    else
    {
        _1429 = false;
    }
    float2 _1442;
    if (!_1429)
    {
        float2 _1441 = _753;
        _1441.x = 0.0;
        _1442 = _1441;
    }
    else
    {
        float2 _1440 = _753;
        _1440.x = precise::max(0.0, _766 - (_1247.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1442 = _1440;
    }
    sdk_hlsl_store(rw_lock_status, _1442.xyyy, uint2(_166));
    float _1444 = precise::min(0.9900000095367431640625, _757);
    float _1447 = precise::max(_1444, mix(_1444, 0.4000000059604644775390625, fast::clamp(_195, 0.0, 1.0)));
    float _1452 = _227 ? 1.0 : precise::max(_1447 * _1447, precise::max(_217 * 0.100000001490116119384765625, _222));
    float _1458;
    if (_1330 >= 1.0)
    {
        _1458 = precise::max(0.001000000047497451305389404296875, _1452) * (-1.0);
    }
    else
    {
        _1458 = _1452;
    }
    float _1459 = _1413.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1459, _1413.yz, _1458), uint2(_166));
    sdk_hlsl_store(rw_upscaled_output, float4(_1459, _1413.yz, 1.0), uint2(_166));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_166));
}

