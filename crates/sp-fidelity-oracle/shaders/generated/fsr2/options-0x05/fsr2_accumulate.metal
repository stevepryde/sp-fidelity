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
    uint2 _143 = gl_WorkGroupID.xy;
    _143.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _157 = (_143 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _160 = float2(int2(_157)) + float2(0.5);
    float2 _161 = float2(cbFSR2.iDisplaySize);
    float2 _162 = _160 / _161;
    float2 _167 = float2(cbFSR2.iRenderSize);
    float2 _177 = precise::max(float2(0.5), precise::min((_162 + (cbFSR2.fJitter / _167)) * _167, _167 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _183 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_162 * _167))), 0u).xy;
    float _185 = length(_183 * _161);
    float2 _186 = _162 + _183;
    float _187 = _186.x;
    bool _192;
    if (_187 >= 0.0)
    {
        _192 = _187 <= 1.0;
    }
    else
    {
        _192 = false;
    }
    bool _201;
    if (_192)
    {
        float _195 = _186.y;
        bool _200;
        if (_195 >= 0.0)
        {
            _200 = _195 <= 1.0;
        }
        else
        {
            _200 = false;
        }
        _201 = _200;
    }
    else
    {
        _201 = false;
    }
    float _207 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _177, level(0.0)).w, 0.0, 1.0);
    float4 _211 = r_dilated_reactive_masks.sample(s_LinearClamp, _177, level(0.0));
    float _212 = _211.x;
    float _213 = _211.y;
    bool _216 = 0 == cbFSR2.iFrameIndex;
    bool _217 = _201 ? _216 : true;
    bool _221;
    if (_201)
    {
        _221 = !_216;
    }
    else
    {
        _221 = false;
    }
    float2 _626;
    float3 _627;
    bool _628;
    bool _629;
    float _630;
    if (_221)
    {
        float2 _225 = (_186 * _161) - float2(0.5);
        float2 _235 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _225.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _225.y)));
        float2 _236 = floor(_235);
        int2 _237 = int2(_236);
        float2 _238 = _235 - _236;
        int2 _239 = _237 + int2(-1);
        int _243 = max(_239.y, 0);
        int2 _244 = int2(max(_239.x, 0), _243);
        _244.y = _243;
        int2 _249 = _237 + int2(0, -1);
        int _252 = max(_249.y, 0);
        int2 _253 = int2(_249.x, _252);
        _253.y = _252;
        int2 _258 = _237 + int2(1, -1);
        int _260 = cbFSR2.iDisplaySize.x - 1;
        int _263 = max(_258.y, 0);
        int2 _264 = int2(min(_258.x, _260), _263);
        _264.y = _263;
        int2 _269 = _237 + int2(2, -1);
        int _273 = max(_269.y, 0);
        int2 _274 = int2(min(_269.x, _260), _273);
        _274.y = _273;
        int2 _279 = _237 + int2(-1, 0);
        int _282 = _279.y;
        int2 _283 = int2(max(_279.x, 0), _282);
        _283.y = _282;
        int2 _289 = _237;
        _289.y = _237.y;
        float4 _292 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_289)), 0u);
        int2 _293 = _237 + int2(1, 0);
        int _296 = _293.y;
        int2 _297 = int2(min(_293.x, _260), _296);
        _297.y = _296;
        float4 _301 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_297)), 0u);
        int2 _302 = _237 + int2(2, 0);
        int _305 = _302.y;
        int2 _306 = int2(min(_302.x, _260), _305);
        _306.y = _305;
        int2 _311 = _237 + int2(-1, 1);
        int _314 = _311.y;
        int2 _315 = int2(max(_311.x, 0), _314);
        int _316 = cbFSR2.iDisplaySize.y - 1;
        _315.y = min(_314, _316);
        int2 _322 = _237 + int2(0, 1);
        _322.y = min(_322.y, _316);
        float4 _328 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_322)), 0u);
        int2 _329 = _237 + int2(1);
        int _332 = _329.y;
        int2 _333 = int2(min(_329.x, _260), _332);
        _333.y = min(_332, _316);
        float4 _338 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_333)), 0u);
        int2 _339 = _237 + int2(2, 1);
        int _342 = _339.y;
        int2 _343 = int2(min(_339.x, _260), _342);
        _343.y = min(_342, _316);
        int2 _349 = _237 + int2(-1, 2);
        int _352 = _349.y;
        int2 _353 = int2(max(_349.x, 0), _352);
        _353.y = min(_352, _316);
        int2 _359 = _237 + int2(0, 2);
        _359.y = min(_359.y, _316);
        int2 _366 = _237 + int2(1, 2);
        int _369 = _366.y;
        int2 _370 = int2(min(_366.x, _260), _369);
        _370.y = min(_369, _316);
        int2 _376 = _237 + int2(2);
        int _379 = _376.y;
        int2 _380 = int2(min(_376.x, _260), _379);
        _380.y = min(_379, _316);
        float _386 = _238.x;
        float2 _392 = float2(abs((-1.0) - _386) * 0.5, 0.5);
        float4 _394 = r_lanczos_lut.sample(s_LinearClamp, _392, level(0.0));
        float _395 = _394.x;
        float2 _401 = float2(abs(-_386) * 0.5, 0.5);
        float4 _403 = r_lanczos_lut.sample(s_LinearClamp, _401, level(0.0));
        float _404 = _403.x;
        float2 _410 = float2(abs(1.0 - _386) * 0.5, 0.5);
        float4 _412 = r_lanczos_lut.sample(s_LinearClamp, _410, level(0.0));
        float _413 = _412.x;
        float2 _419 = float2(abs(2.0 - _386) * 0.5, 0.5);
        float4 _421 = r_lanczos_lut.sample(s_LinearClamp, _419, level(0.0));
        float _422 = _421.x;
        float4 _438 = r_lanczos_lut.sample(s_LinearClamp, _392, level(0.0));
        float _439 = _438.x;
        float4 _443 = r_lanczos_lut.sample(s_LinearClamp, _401, level(0.0));
        float _444 = _443.x;
        float4 _448 = r_lanczos_lut.sample(s_LinearClamp, _410, level(0.0));
        float _449 = _448.x;
        float4 _453 = r_lanczos_lut.sample(s_LinearClamp, _419, level(0.0));
        float _454 = _453.x;
        float4 _470 = r_lanczos_lut.sample(s_LinearClamp, _392, level(0.0));
        float _471 = _470.x;
        float4 _475 = r_lanczos_lut.sample(s_LinearClamp, _401, level(0.0));
        float _476 = _475.x;
        float4 _480 = r_lanczos_lut.sample(s_LinearClamp, _410, level(0.0));
        float _481 = _480.x;
        float4 _485 = r_lanczos_lut.sample(s_LinearClamp, _419, level(0.0));
        float _486 = _485.x;
        float4 _502 = r_lanczos_lut.sample(s_LinearClamp, _392, level(0.0));
        float _503 = _502.x;
        float4 _507 = r_lanczos_lut.sample(s_LinearClamp, _401, level(0.0));
        float _508 = _507.x;
        float4 _512 = r_lanczos_lut.sample(s_LinearClamp, _410, level(0.0));
        float _513 = _512.x;
        float4 _517 = r_lanczos_lut.sample(s_LinearClamp, _419, level(0.0));
        float _518 = _517.x;
        float _531 = _238.y;
        float4 _539 = r_lanczos_lut.sample(s_LinearClamp, float2(abs((-1.0) - _531) * 0.5, 0.5), level(0.0));
        float _540 = _539.x;
        float4 _548 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(-_531) * 0.5, 0.5), level(0.0));
        float _549 = _548.x;
        float4 _557 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(1.0 - _531) * 0.5, 0.5), level(0.0));
        float _558 = _557.x;
        float4 _566 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(2.0 - _531) * 0.5, 0.5), level(0.0));
        float _567 = _566.x;
        float4 _574 = ((((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_244)), 0u) * _395) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_253)), 0u) * _404)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_264)), 0u) * _413)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_274)), 0u) * _422)) / float4(((_395 + _404) + _413) + _422)) * _540) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_283)), 0u) * _439) + (_292 * _444)) + (_301 * _449)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_306)), 0u) * _454)) / float4(((_439 + _444) + _449) + _454)) * _549)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_315)), 0u) * _471) + (_328 * _476)) + (_338 * _481)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_343)), 0u) * _486)) / float4(((_471 + _476) + _481) + _486)) * _558)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_353)), 0u) * _503) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_359)), 0u) * _508)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_370)), 0u) * _513)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_380)), 0u) * _518)) / float4(((_503 + _508) + _513) + _518)) * _567);
        float4 _586 = fast::clamp(_574 / float4(((_540 + _549) + _558) + _567), precise::min(precise::min(precise::min(_292, _301), _328), _338), precise::max(precise::max(precise::max(_292, _301), _328), _338));
        float4 _589 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _590 = _589.x;
        float3 _598 = fast::clamp((_586.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_590 == 0.0) ? 1.0 : _590), float3(0.0), float3(65504.0));
        float _599 = _598.x;
        float _602 = 0.5 * _598.y;
        float _604 = _598.z;
        float _605 = 0.25 * _604;
        float _613 = _586.w;
        spvImageFence(rw_new_locks);
        _626 = r_lock_status.sample(s_LinearClamp, _186, level(0.0)).xy;
        _627 = float3(((0.25 * _599) + _602) + _605, 0.5 * (_599 - _604), (((-0.25) * _599) + _602) - _605);
        _628 = _613 < 0.0;
        _629 = sdk_hlsl_load(rw_new_locks, uint2(_157)).x > 0.4980392158031463623046875;
        _630 = fast::clamp(abs(_613), 0.0, 1.0);
    }
    else
    {
        _626 = float2(0.0);
        _627 = float3(0.0);
        _628 = false;
        _629 = false;
        _630 = 0.0;
    }
    float2 _642 = float2(int2(_167 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _650 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _651 = _650.x;
    float _663 = powr(((_651 == 0.0) ? 1.0 : _651) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_162 * _642, _642 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _666 = (_626.y == 0.0) ? _663 : _626.y;
    float2 _667 = _626;
    _667.y = _666;
    float _668 = precise::max(_666, _663);
    float _675;
    if (_668 != 0.0)
    {
        _675 = precise::min(_666, _663) / _668;
    }
    else
    {
        _675 = 0.0;
    }
    float _676 = 1.0 - _675;
    float2 _697;
    if (_629)
    {
        _697 = float2((_626.x != 0.0) ? 2.0 : 1.0, _663);
    }
    else
    {
        float2 _692;
        if (_626.x <= 1.0)
        {
            float2 _691 = _667;
            _691.y = mix(_666, _663, 0.5);
            _692 = _691;
        }
        else
        {
            float2 _689;
            if (_676 > 0.100000001490116119384765625)
            {
                _689 = float2(0.0, _666);
            }
            else
            {
                _689 = _667;
            }
            _692 = _689;
        }
        _697 = _692;
    }
    float _701 = precise::max(precise::max(_212, _630), fast::clamp((0.89999997615814208984375 - _675) * 10.0, 0.0, 1.0));
    float _702 = 1.0 - _701;
    float _710 = ((_697.x * _702) * fast::clamp(1.0 - _213, 0.0, 1.0)) * float(_207 < 0.100000001490116119384765625);
    float _714 = precise::max(_697.y, _663);
    float _721;
    if (_714 != 0.0)
    {
        _721 = precise::min(_697.y, _663) / _714;
    }
    else
    {
        _721 = 0.0;
    }
    float2 _729 = _160 * cbFSR2.fDownscaleFactor;
    int2 _731 = int2(floor(_729));
    float2 _734 = (float2(_731) + float2(0.5)) - cbFSR2.fJitter;
    bool _737 = _734.x > _729.x;
    bool _741 = _734.y > _729.y;
    int2 _743 = int2(_737 ? (-2) : (-1), _741 ? (-2) : (-1));
    float2 _744 = float2(_743);
    int _745 = _737 ? 3 : 0;
    int _746 = _741 ? 3 : 0;
    int2 _747 = int2(_745, _746);
    int2 _748 = _731 + _743;
    int2 _749 = _748 + _747;
    int2 _751 = _749;
    _751.y = _749.y;
    float3 _755 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_751)), 0u).xyz;
    int _756 = _737 ? 2 : 1;
    int2 _757 = int2(_756, _746);
    int2 _758 = _748 + _757;
    int2 _760 = _758;
    _760.y = _758.y;
    float3 _764 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_760)), 0u).xyz;
    int _765 = _737 ? 1 : 2;
    int2 _766 = int2(_765, _746);
    int2 _767 = _748 + _766;
    int2 _769 = _767;
    _769.y = _767.y;
    float3 _773 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_769)), 0u).xyz;
    int _774 = _741 ? 2 : 1;
    int2 _775 = int2(_745, _774);
    int2 _776 = _748 + _775;
    int2 _778 = _776;
    _778.y = _776.y;
    float3 _782 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_778)), 0u).xyz;
    int2 _783 = int2(_756, _774);
    int2 _784 = _748 + _783;
    int2 _786 = _784;
    _786.y = _784.y;
    float3 _790 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_786)), 0u).xyz;
    int2 _791 = int2(_765, _774);
    int2 _792 = _748 + _791;
    int2 _794 = _792;
    _794.y = _792.y;
    float3 _798 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_794)), 0u).xyz;
    int _799 = _741 ? 1 : 2;
    int2 _800 = int2(_745, _799);
    int2 _801 = _748 + _800;
    int2 _803 = _801;
    _803.y = _801.y;
    float3 _807 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_803)), 0u).xyz;
    int2 _808 = int2(_756, _799);
    int2 _809 = _748 + _808;
    int2 _811 = _809;
    _811.y = _809.y;
    float3 _815 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_811)), 0u).xyz;
    int2 _816 = int2(_765, _799);
    int2 _817 = _748 + _816;
    int2 _819 = _817;
    _819.y = _817.y;
    float3 _823 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_819)), 0u).xyz;
    float2 _824 = _734 - _729;
    float _826 = precise::max(_701, float(_217));
    float _833 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _826);
    float _843 = mix(-2.0, -3.0, fast::clamp(_185 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _846 = _824 + (_744 + float2(_747));
    uint2 _848 = uint2(cbFSR2.iRenderSize);
    float2 _852 = float2(mix(_833, precise::max(1.0, (1.0 + _833) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _207, _826))));
    float2 _853 = _846 * _852;
    float _855 = precise::min(dot(_853, _853), 4.0);
    float _857 = (0.4000000059604644775390625 * _855) - 1.0;
    float _859 = (0.25 * _855) - 1.0;
    float _865 = float(all(uint2(_749) < _848)) * ((((1.5625 * _857) * _857) - 0.5625) * (_859 * _859));
    float _873 = exp(_843 * dot(_846, _846));
    float3 _874 = _755 * _873;
    float2 _878 = _824 + (_744 + float2(_757));
    float2 _883 = _878 * _852;
    float _885 = precise::min(dot(_883, _883), 4.0);
    float _887 = (0.4000000059604644775390625 * _885) - 1.0;
    float _889 = (0.25 * _885) - 1.0;
    float _895 = float(all(uint2(_758) < _848)) * ((((1.5625 * _887) * _887) - 0.5625) * (_889 * _889));
    float _904 = exp(_843 * dot(_878, _878));
    float3 _907 = _764 * _904;
    float2 _914 = _824 + (_744 + float2(_766));
    float2 _919 = _914 * _852;
    float _921 = precise::min(dot(_919, _919), 4.0);
    float _923 = (0.4000000059604644775390625 * _921) - 1.0;
    float _925 = (0.25 * _921) - 1.0;
    float _931 = float(all(uint2(_767) < _848)) * ((((1.5625 * _923) * _923) - 0.5625) * (_925 * _925));
    float _940 = exp(_843 * dot(_914, _914));
    float3 _943 = _773 * _940;
    float2 _950 = _824 + (_744 + float2(_775));
    float2 _955 = _950 * _852;
    float _957 = precise::min(dot(_955, _955), 4.0);
    float _959 = (0.4000000059604644775390625 * _957) - 1.0;
    float _961 = (0.25 * _957) - 1.0;
    float _967 = float(all(uint2(_776) < _848)) * ((((1.5625 * _959) * _959) - 0.5625) * (_961 * _961));
    float _976 = exp(_843 * dot(_950, _950));
    float3 _979 = _782 * _976;
    float2 _986 = _824 + (_744 + float2(_783));
    float2 _991 = _986 * _852;
    float _993 = precise::min(dot(_991, _991), 4.0);
    float _995 = (0.4000000059604644775390625 * _993) - 1.0;
    float _997 = (0.25 * _993) - 1.0;
    float _1003 = float(all(uint2(_784) < _848)) * ((((1.5625 * _995) * _995) - 0.5625) * (_997 * _997));
    float _1012 = exp(_843 * dot(_986, _986));
    float3 _1015 = _790 * _1012;
    float2 _1022 = _824 + (_744 + float2(_791));
    float2 _1027 = _1022 * _852;
    float _1029 = precise::min(dot(_1027, _1027), 4.0);
    float _1031 = (0.4000000059604644775390625 * _1029) - 1.0;
    float _1033 = (0.25 * _1029) - 1.0;
    float _1039 = float(all(uint2(_792) < _848)) * ((((1.5625 * _1031) * _1031) - 0.5625) * (_1033 * _1033));
    float _1048 = exp(_843 * dot(_1022, _1022));
    float3 _1051 = _798 * _1048;
    float2 _1058 = _824 + (_744 + float2(_800));
    float2 _1063 = _1058 * _852;
    float _1065 = precise::min(dot(_1063, _1063), 4.0);
    float _1067 = (0.4000000059604644775390625 * _1065) - 1.0;
    float _1069 = (0.25 * _1065) - 1.0;
    float _1075 = float(all(uint2(_801) < _848)) * ((((1.5625 * _1067) * _1067) - 0.5625) * (_1069 * _1069));
    float _1084 = exp(_843 * dot(_1058, _1058));
    float3 _1087 = _807 * _1084;
    float2 _1094 = _824 + (_744 + float2(_808));
    float2 _1099 = _1094 * _852;
    float _1101 = precise::min(dot(_1099, _1099), 4.0);
    float _1103 = (0.4000000059604644775390625 * _1101) - 1.0;
    float _1105 = (0.25 * _1101) - 1.0;
    float _1111 = float(all(uint2(_809) < _848)) * ((((1.5625 * _1103) * _1103) - 0.5625) * (_1105 * _1105));
    float _1120 = exp(_843 * dot(_1094, _1094));
    float3 _1123 = _815 * _1120;
    float2 _1130 = _824 + (_744 + float2(_816));
    float2 _1135 = _1130 * _852;
    float _1137 = precise::min(dot(_1135, _1135), 4.0);
    float _1139 = (0.4000000059604644775390625 * _1137) - 1.0;
    float _1141 = (0.25 * _1137) - 1.0;
    float _1147 = float(all(uint2(_817) < _848)) * ((((1.5625 * _1139) * _1139) - 0.5625) * (_1141 * _1141));
    float4 _1153 = (((((((float4(_755 * _865, _865) + float4(_764 * _895, _895)) + float4(_773 * _931, _931)) + float4(_782 * _967, _967)) + float4(_790 * _1003, _1003)) + float4(_798 * _1039, _1039)) + float4(_807 * _1075, _1075)) + float4(_815 * _1111, _1111)) + float4(_823 * _1147, _1147);
    float _1156 = exp(_843 * dot(_1130, _1130));
    float3 _1157 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_755, _764), _773), _782), _790), _798), _807), _815), _823);
    float3 _1158 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_755, _764), _773), _782), _790), _798), _807), _815), _823);
    float3 _1159 = _823 * _1156;
    float _1163 = (((((((_873 + _904) + _940) + _976) + _1012) + _1048) + _1084) + _1120) + _1156;
    float3 _1167 = float3((abs(_1163) > 0.001000000047497451305389404296875) ? _1163 : 1.0);
    float3 _1168 = ((((((((_874 + _907) + _943) + _979) + _1015) + _1051) + _1087) + _1123) + _1159) / _1167;
    float3 _1173 = sqrt(abs(((((((((((_755 * _874) + (_764 * _907)) + (_773 * _943)) + (_782 * _979)) + (_790 * _1015)) + (_798 * _1051)) + (_807 * _1087)) + (_815 * _1123)) + (_823 * _1159)) / _1167) - (_1168 * _1168)));
    float _1177 = _1153.w * float(_1153.w > 0.001000000047497451305389404296875);
    float4 _1178 = _1153;
    _1178.w = _1177;
    float4 _1191;
    if (_1177 > 0.001000000047497451305389404296875)
    {
        float3 _1184 = _1178.xyz / float3(_1177);
        float4 _1185 = float4(_1184.x, _1184.y, _1184.z, _1178.w);
        _1185.w = _1177 * 0.083333335816860198974609375;
        float3 _1189 = fast::clamp(_1185.xyz, _1157, _1158);
        _1191 = float4(_1189.x, _1189.y, _1189.z, _1185.w);
    }
    else
    {
        _1191 = _1178;
    }
    float _1195 = rint(_1168.x * 255.0) * 0.0039215688593685626983642578125;
    bool _1202;
    if (precise::max(precise::max(_207, _213), _676) < 0.100000001490116119384765625)
    {
        _1202 = !_217;
    }
    else
    {
        _1202 = false;
    }
    float4 _1210;
    if (_1202)
    {
        _1210 = r_luma_history.sample(s_LinearClamp, _186, level(0.0));
    }
    else
    {
        _1210 = float4(0.0);
    }
    float4 _141 = _1210;
    float _1213 = _1195 - _141.x;
    float _1214 = abs(_1213);
    float _1253;
    if (_1214 >= 0.0039215688593685626983642578125)
    {
        float _1219;
        _1219 = _1214;
        float _1220;
        for (int _1222 = 1; _1222 <= 3; _1219 = _1220, _1222++)
        {
            float _1230 = _1195 - _141[uint(_1222)];
            if (int(sign(_1213)) == int(sign(_1230)))
            {
                _1220 = precise::min(_1219, abs(_1230));
            }
            else
            {
                _1220 = _1219;
            }
        }
        _1253 = float((float(_1219 != _1214) * powr(fast::clamp(_1173.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_213, powr(_701, 0.16666667163372039794921875)));
    }
    else
    {
        _1253 = 0.0;
    }
    _141.w = _141.z;
    _141.z = _141.y;
    _141.y = _141.x;
    _141.x = _1195;
    sdk_hlsl_store(rw_luma_history, _141, uint2(_157));
    float _1270 = (float(_201) * _702) * (1.0 - _207);
    float _1274 = fast::clamp(_185 * 10.0, 0.0, 1.0);
    float _1277 = precise::min(_1270, mix(_1270, _1191.w * 10.0, precise::max(float(_628), _1274)));
    float _1279 = fast::clamp(_185 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1282 = float3(precise::min(_1277, mix(_1277, _1191.w, _1279)));
    float3 _1347;
    if (_217)
    {
        _1347 = float3((_1191.x + _1191.y) - _1191.z, _1191.x + _1191.z, (_1191.x - _1191.y) - _1191.z);
    }
    else
    {
        float3 _1296 = _1173 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_207, precise::max(_213, _1279)));
        float3 _1299 = precise::max(_1157, _1168 - _1296);
        float3 _1300 = precise::min(_1158, _1168 + _1296);
        bool _1308;
        if (!any(_1299 > _627))
        {
            _1308 = any(_627 > _1300);
        }
        else
        {
            _1308 = true;
        }
        float3 _1321;
        float3 _1322;
        if (_1308)
        {
            float3 _1317 = fast::clamp(float3(precise::max(_1253 * float(_141.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_710 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_721, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_212, 0.5)), float3(0.0), float3(1.0));
            _1321 = mix(fast::clamp(_627, _1299, _1300), _627, _1317);
            _1322 = mix(precise::min(_1282, float3(0.100000001490116119384765625)), _1282, _1317);
        }
        else
        {
            _1321 = _627;
            _1322 = _1282;
        }
        float3 _1328 = mix(_1321, _1191.xyz, _1191.www / precise::max(float3(0.001000000047497451305389404296875), _1322 + _1191.www));
        float _1329 = _1328.x;
        float _1330 = _1328.y;
        float _1332 = _1328.z;
        _1347 = float3((_1329 + _1330) - _1332, _1329 + _1332, (_1329 - _1330) - _1332);
    }
    float4 _1349 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1350 = _1349.x;
    float3 _1357 = (_1347 / float3((_1350 == 0.0) ? 1.0 : _1350)) * cbFSR2.fPreExposure;
    float2 _1358 = _162 - _183;
    float _1359 = _1358.x;
    bool _1364;
    if (_1359 >= 0.0)
    {
        _1364 = _1359 <= 1.0;
    }
    else
    {
        _1364 = false;
    }
    bool _1373;
    if (_1364)
    {
        float _1367 = _1358.y;
        bool _1372;
        if (_1367 >= 0.0)
        {
            _1372 = _1367 <= 1.0;
        }
        else
        {
            _1372 = false;
        }
        _1373 = _1372;
    }
    else
    {
        _1373 = false;
    }
    float2 _1386;
    if (!_1373)
    {
        float2 _1385 = _697;
        _1385.x = 0.0;
        _1386 = _1385;
    }
    else
    {
        float2 _1384 = _697;
        _1384.x = precise::max(0.0, _710 - (_1191.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1386 = _1384;
    }
    sdk_hlsl_store(rw_lock_status, _1386.xyyy, uint2(_157));
    float _1388 = precise::min(0.9900000095367431640625, _701);
    float _1391 = precise::max(_1388, mix(_1388, 0.4000000059604644775390625, fast::clamp(_185, 0.0, 1.0)));
    float _1396 = _217 ? 1.0 : precise::max(_1391 * _1391, precise::max(_207 * 0.100000001490116119384765625, _212));
    float _1402;
    if (_1274 >= 1.0)
    {
        _1402 = precise::max(0.001000000047497451305389404296875, _1396) * (-1.0);
    }
    else
    {
        _1402 = _1396;
    }
    float _1403 = _1357.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1403, _1357.yz, _1402), uint2(_157));
    sdk_hlsl_store(rw_upscaled_output, float4(_1403, _1357.yz, 1.0), uint2(_157));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_157));
}

