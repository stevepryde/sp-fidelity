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

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_motion_vectors [[texture(0)]], texture2d<float> r_input_exposure [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float> r_lock_status [[texture(3)]], texture2d<float> r_prepared_input_color [[texture(4)]], texture2d<float> r_luma_history [[texture(5)]], texture2d<float> r_lanczos_lut [[texture(6)]], texture2d<float> r_imgMips [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(9)]], texture2d<float, access::write> rw_lock_status [[texture(10)]], texture2d<float, access::read_write> rw_new_locks [[texture(11)]], texture2d<float, access::write> rw_luma_history [[texture(12)]], texture2d<float, access::write> rw_upscaled_output [[texture(13)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _147 = gl_WorkGroupID.xy;
    _147.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _161 = (_147 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _164 = float2(int2(_161)) + float2(0.5);
    float2 _165 = float2(cbFSR2.iDisplaySize);
    float2 _166 = _164 / _165;
    float2 _171 = float2(cbFSR2.iRenderSize);
    float2 _181 = precise::max(float2(0.5), precise::min((_166 + (cbFSR2.fJitter / _171)) * _171, _171 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _190 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_161), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
    float _192 = length(_190 * _165);
    float2 _193 = _166 + _190;
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
    float _214 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _181, level(0.0)).w, 0.0, 1.0);
    float4 _218 = r_dilated_reactive_masks.sample(s_LinearClamp, _181, level(0.0));
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
    float2 _633;
    float3 _634;
    bool _635;
    bool _636;
    float _637;
    if (_228)
    {
        float2 _232 = (_193 * _165) - float2(0.5);
        float2 _242 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _232.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _232.y)));
        float2 _243 = floor(_242);
        int2 _244 = int2(_243);
        float2 _245 = _242 - _243;
        int2 _246 = _244 + int2(-1);
        int _250 = max(_246.y, 0);
        int2 _251 = int2(max(_246.x, 0), _250);
        _251.y = _250;
        int2 _256 = _244 + int2(0, -1);
        int _259 = max(_256.y, 0);
        int2 _260 = int2(_256.x, _259);
        _260.y = _259;
        int2 _265 = _244 + int2(1, -1);
        int _267 = cbFSR2.iDisplaySize.x - 1;
        int _270 = max(_265.y, 0);
        int2 _271 = int2(min(_265.x, _267), _270);
        _271.y = _270;
        int2 _276 = _244 + int2(2, -1);
        int _280 = max(_276.y, 0);
        int2 _281 = int2(min(_276.x, _267), _280);
        _281.y = _280;
        int2 _286 = _244 + int2(-1, 0);
        int _289 = _286.y;
        int2 _290 = int2(max(_286.x, 0), _289);
        _290.y = _289;
        int2 _296 = _244;
        _296.y = _244.y;
        float4 _299 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_296)), 0u);
        int2 _300 = _244 + int2(1, 0);
        int _303 = _300.y;
        int2 _304 = int2(min(_300.x, _267), _303);
        _304.y = _303;
        float4 _308 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_304)), 0u);
        int2 _309 = _244 + int2(2, 0);
        int _312 = _309.y;
        int2 _313 = int2(min(_309.x, _267), _312);
        _313.y = _312;
        int2 _318 = _244 + int2(-1, 1);
        int _321 = _318.y;
        int2 _322 = int2(max(_318.x, 0), _321);
        int _323 = cbFSR2.iDisplaySize.y - 1;
        _322.y = min(_321, _323);
        int2 _329 = _244 + int2(0, 1);
        _329.y = min(_329.y, _323);
        float4 _335 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_329)), 0u);
        int2 _336 = _244 + int2(1);
        int _339 = _336.y;
        int2 _340 = int2(min(_336.x, _267), _339);
        _340.y = min(_339, _323);
        float4 _345 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_340)), 0u);
        int2 _346 = _244 + int2(2, 1);
        int _349 = _346.y;
        int2 _350 = int2(min(_346.x, _267), _349);
        _350.y = min(_349, _323);
        int2 _356 = _244 + int2(-1, 2);
        int _359 = _356.y;
        int2 _360 = int2(max(_356.x, 0), _359);
        _360.y = min(_359, _323);
        int2 _366 = _244 + int2(0, 2);
        _366.y = min(_366.y, _323);
        int2 _373 = _244 + int2(1, 2);
        int _376 = _373.y;
        int2 _377 = int2(min(_373.x, _267), _376);
        _377.y = min(_376, _323);
        int2 _383 = _244 + int2(2);
        int _386 = _383.y;
        int2 _387 = int2(min(_383.x, _267), _386);
        _387.y = min(_386, _323);
        float _393 = _245.x;
        float2 _399 = float2(abs((-1.0) - _393) * 0.5, 0.5);
        float4 _401 = r_lanczos_lut.sample(s_LinearClamp, _399, level(0.0));
        float _402 = _401.x;
        float2 _408 = float2(abs(-_393) * 0.5, 0.5);
        float4 _410 = r_lanczos_lut.sample(s_LinearClamp, _408, level(0.0));
        float _411 = _410.x;
        float2 _417 = float2(abs(1.0 - _393) * 0.5, 0.5);
        float4 _419 = r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0));
        float _420 = _419.x;
        float2 _426 = float2(abs(2.0 - _393) * 0.5, 0.5);
        float4 _428 = r_lanczos_lut.sample(s_LinearClamp, _426, level(0.0));
        float _429 = _428.x;
        float4 _445 = r_lanczos_lut.sample(s_LinearClamp, _399, level(0.0));
        float _446 = _445.x;
        float4 _450 = r_lanczos_lut.sample(s_LinearClamp, _408, level(0.0));
        float _451 = _450.x;
        float4 _455 = r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0));
        float _456 = _455.x;
        float4 _460 = r_lanczos_lut.sample(s_LinearClamp, _426, level(0.0));
        float _461 = _460.x;
        float4 _477 = r_lanczos_lut.sample(s_LinearClamp, _399, level(0.0));
        float _478 = _477.x;
        float4 _482 = r_lanczos_lut.sample(s_LinearClamp, _408, level(0.0));
        float _483 = _482.x;
        float4 _487 = r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0));
        float _488 = _487.x;
        float4 _492 = r_lanczos_lut.sample(s_LinearClamp, _426, level(0.0));
        float _493 = _492.x;
        float4 _509 = r_lanczos_lut.sample(s_LinearClamp, _399, level(0.0));
        float _510 = _509.x;
        float4 _514 = r_lanczos_lut.sample(s_LinearClamp, _408, level(0.0));
        float _515 = _514.x;
        float4 _519 = r_lanczos_lut.sample(s_LinearClamp, _417, level(0.0));
        float _520 = _519.x;
        float4 _524 = r_lanczos_lut.sample(s_LinearClamp, _426, level(0.0));
        float _525 = _524.x;
        float _538 = _245.y;
        float4 _546 = r_lanczos_lut.sample(s_LinearClamp, float2(abs((-1.0) - _538) * 0.5, 0.5), level(0.0));
        float _547 = _546.x;
        float4 _555 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(-_538) * 0.5, 0.5), level(0.0));
        float _556 = _555.x;
        float4 _564 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(1.0 - _538) * 0.5, 0.5), level(0.0));
        float _565 = _564.x;
        float4 _573 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(2.0 - _538) * 0.5, 0.5), level(0.0));
        float _574 = _573.x;
        float4 _581 = ((((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_251)), 0u) * _402) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_260)), 0u) * _411)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_271)), 0u) * _420)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_281)), 0u) * _429)) / float4(((_402 + _411) + _420) + _429)) * _547) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_290)), 0u) * _446) + (_299 * _451)) + (_308 * _456)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_313)), 0u) * _461)) / float4(((_446 + _451) + _456) + _461)) * _556)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_322)), 0u) * _478) + (_335 * _483)) + (_345 * _488)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_350)), 0u) * _493)) / float4(((_478 + _483) + _488) + _493)) * _565)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_360)), 0u) * _510) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_366)), 0u) * _515)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_377)), 0u) * _520)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_387)), 0u) * _525)) / float4(((_510 + _515) + _520) + _525)) * _574);
        float4 _593 = fast::clamp(_581 / float4(((_547 + _556) + _565) + _574), precise::min(precise::min(precise::min(_299, _308), _335), _345), precise::max(precise::max(precise::max(_299, _308), _335), _345));
        float4 _596 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _597 = _596.x;
        float3 _605 = fast::clamp((_593.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_597 == 0.0) ? 1.0 : _597), float3(0.0), float3(65504.0));
        float _606 = _605.x;
        float _609 = 0.5 * _605.y;
        float _611 = _605.z;
        float _612 = 0.25 * _611;
        float _620 = _593.w;
        spvImageFence(rw_new_locks);
        _633 = r_lock_status.sample(s_LinearClamp, _193, level(0.0)).xy;
        _634 = float3(((0.25 * _606) + _609) + _612, 0.5 * (_606 - _611), (((-0.25) * _606) + _609) - _612);
        _635 = _620 < 0.0;
        _636 = sdk_hlsl_load(rw_new_locks, uint2(_161)).x > 0.4980392158031463623046875;
        _637 = fast::clamp(abs(_620), 0.0, 1.0);
    }
    else
    {
        _633 = float2(0.0);
        _634 = float3(0.0);
        _635 = false;
        _636 = false;
        _637 = 0.0;
    }
    float2 _649 = float2(int2(_171 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _657 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _658 = _657.x;
    float _670 = powr(((_658 == 0.0) ? 1.0 : _658) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_166 * _649, _649 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _673 = (_633.y == 0.0) ? _670 : _633.y;
    float2 _674 = _633;
    _674.y = _673;
    float _675 = precise::max(_673, _670);
    float _682;
    if (_675 != 0.0)
    {
        _682 = precise::min(_673, _670) / _675;
    }
    else
    {
        _682 = 0.0;
    }
    float _683 = 1.0 - _682;
    float2 _704;
    if (_636)
    {
        _704 = float2((_633.x != 0.0) ? 2.0 : 1.0, _670);
    }
    else
    {
        float2 _699;
        if (_633.x <= 1.0)
        {
            float2 _698 = _674;
            _698.y = mix(_673, _670, 0.5);
            _699 = _698;
        }
        else
        {
            float2 _696;
            if (_683 > 0.100000001490116119384765625)
            {
                _696 = float2(0.0, _673);
            }
            else
            {
                _696 = _674;
            }
            _699 = _696;
        }
        _704 = _699;
    }
    float _708 = precise::max(precise::max(_219, _637), fast::clamp((0.89999997615814208984375 - _682) * 10.0, 0.0, 1.0));
    float _709 = 1.0 - _708;
    float _717 = ((_704.x * _709) * fast::clamp(1.0 - _220, 0.0, 1.0)) * float(_214 < 0.100000001490116119384765625);
    float _721 = precise::max(_704.y, _670);
    float _728;
    if (_721 != 0.0)
    {
        _728 = precise::min(_704.y, _670) / _721;
    }
    else
    {
        _728 = 0.0;
    }
    float2 _736 = _164 * cbFSR2.fDownscaleFactor;
    int2 _738 = int2(floor(_736));
    float2 _741 = (float2(_738) + float2(0.5)) - cbFSR2.fJitter;
    bool _744 = _741.x > _736.x;
    bool _748 = _741.y > _736.y;
    int2 _750 = int2(_744 ? (-2) : (-1), _748 ? (-2) : (-1));
    float2 _751 = float2(_750);
    int _752 = _744 ? 3 : 0;
    int _753 = _748 ? 3 : 0;
    int2 _754 = int2(_752, _753);
    int2 _755 = _738 + _750;
    int2 _756 = _755 + _754;
    int2 _758 = _756;
    _758.y = _756.y;
    float3 _762 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_758)), 0u).xyz;
    int _763 = _744 ? 2 : 1;
    int2 _764 = int2(_763, _753);
    int2 _765 = _755 + _764;
    int2 _767 = _765;
    _767.y = _765.y;
    float3 _771 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_767)), 0u).xyz;
    int _772 = _744 ? 1 : 2;
    int2 _773 = int2(_772, _753);
    int2 _774 = _755 + _773;
    int2 _776 = _774;
    _776.y = _774.y;
    float3 _780 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_776)), 0u).xyz;
    int _781 = _748 ? 2 : 1;
    int2 _782 = int2(_752, _781);
    int2 _783 = _755 + _782;
    int2 _785 = _783;
    _785.y = _783.y;
    float3 _789 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_785)), 0u).xyz;
    int2 _790 = int2(_763, _781);
    int2 _791 = _755 + _790;
    int2 _793 = _791;
    _793.y = _791.y;
    float3 _797 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_793)), 0u).xyz;
    int2 _798 = int2(_772, _781);
    int2 _799 = _755 + _798;
    int2 _801 = _799;
    _801.y = _799.y;
    float3 _805 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_801)), 0u).xyz;
    int _806 = _748 ? 1 : 2;
    int2 _807 = int2(_752, _806);
    int2 _808 = _755 + _807;
    int2 _810 = _808;
    _810.y = _808.y;
    float3 _814 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_810)), 0u).xyz;
    int2 _815 = int2(_763, _806);
    int2 _816 = _755 + _815;
    int2 _818 = _816;
    _818.y = _816.y;
    float3 _822 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_818)), 0u).xyz;
    int2 _823 = int2(_772, _806);
    int2 _824 = _755 + _823;
    int2 _826 = _824;
    _826.y = _824.y;
    float3 _830 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_826)), 0u).xyz;
    float2 _831 = _741 - _736;
    float _833 = precise::max(_708, float(_224));
    float _840 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _833);
    float _850 = mix(-2.0, -3.0, fast::clamp(_192 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _853 = _831 + (_751 + float2(_754));
    uint2 _855 = uint2(cbFSR2.iRenderSize);
    float2 _859 = float2(mix(_840, precise::max(1.0, (1.0 + _840) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _214, _833))));
    float2 _860 = _853 * _859;
    float _862 = precise::min(dot(_860, _860), 4.0);
    float _864 = (0.4000000059604644775390625 * _862) - 1.0;
    float _866 = (0.25 * _862) - 1.0;
    float _872 = float(all(uint2(_756) < _855)) * ((((1.5625 * _864) * _864) - 0.5625) * (_866 * _866));
    float _880 = exp(_850 * dot(_853, _853));
    float3 _881 = _762 * _880;
    float2 _885 = _831 + (_751 + float2(_764));
    float2 _890 = _885 * _859;
    float _892 = precise::min(dot(_890, _890), 4.0);
    float _894 = (0.4000000059604644775390625 * _892) - 1.0;
    float _896 = (0.25 * _892) - 1.0;
    float _902 = float(all(uint2(_765) < _855)) * ((((1.5625 * _894) * _894) - 0.5625) * (_896 * _896));
    float _911 = exp(_850 * dot(_885, _885));
    float3 _914 = _771 * _911;
    float2 _921 = _831 + (_751 + float2(_773));
    float2 _926 = _921 * _859;
    float _928 = precise::min(dot(_926, _926), 4.0);
    float _930 = (0.4000000059604644775390625 * _928) - 1.0;
    float _932 = (0.25 * _928) - 1.0;
    float _938 = float(all(uint2(_774) < _855)) * ((((1.5625 * _930) * _930) - 0.5625) * (_932 * _932));
    float _947 = exp(_850 * dot(_921, _921));
    float3 _950 = _780 * _947;
    float2 _957 = _831 + (_751 + float2(_782));
    float2 _962 = _957 * _859;
    float _964 = precise::min(dot(_962, _962), 4.0);
    float _966 = (0.4000000059604644775390625 * _964) - 1.0;
    float _968 = (0.25 * _964) - 1.0;
    float _974 = float(all(uint2(_783) < _855)) * ((((1.5625 * _966) * _966) - 0.5625) * (_968 * _968));
    float _983 = exp(_850 * dot(_957, _957));
    float3 _986 = _789 * _983;
    float2 _993 = _831 + (_751 + float2(_790));
    float2 _998 = _993 * _859;
    float _1000 = precise::min(dot(_998, _998), 4.0);
    float _1002 = (0.4000000059604644775390625 * _1000) - 1.0;
    float _1004 = (0.25 * _1000) - 1.0;
    float _1010 = float(all(uint2(_791) < _855)) * ((((1.5625 * _1002) * _1002) - 0.5625) * (_1004 * _1004));
    float _1019 = exp(_850 * dot(_993, _993));
    float3 _1022 = _797 * _1019;
    float2 _1029 = _831 + (_751 + float2(_798));
    float2 _1034 = _1029 * _859;
    float _1036 = precise::min(dot(_1034, _1034), 4.0);
    float _1038 = (0.4000000059604644775390625 * _1036) - 1.0;
    float _1040 = (0.25 * _1036) - 1.0;
    float _1046 = float(all(uint2(_799) < _855)) * ((((1.5625 * _1038) * _1038) - 0.5625) * (_1040 * _1040));
    float _1055 = exp(_850 * dot(_1029, _1029));
    float3 _1058 = _805 * _1055;
    float2 _1065 = _831 + (_751 + float2(_807));
    float2 _1070 = _1065 * _859;
    float _1072 = precise::min(dot(_1070, _1070), 4.0);
    float _1074 = (0.4000000059604644775390625 * _1072) - 1.0;
    float _1076 = (0.25 * _1072) - 1.0;
    float _1082 = float(all(uint2(_808) < _855)) * ((((1.5625 * _1074) * _1074) - 0.5625) * (_1076 * _1076));
    float _1091 = exp(_850 * dot(_1065, _1065));
    float3 _1094 = _814 * _1091;
    float2 _1101 = _831 + (_751 + float2(_815));
    float2 _1106 = _1101 * _859;
    float _1108 = precise::min(dot(_1106, _1106), 4.0);
    float _1110 = (0.4000000059604644775390625 * _1108) - 1.0;
    float _1112 = (0.25 * _1108) - 1.0;
    float _1118 = float(all(uint2(_816) < _855)) * ((((1.5625 * _1110) * _1110) - 0.5625) * (_1112 * _1112));
    float _1127 = exp(_850 * dot(_1101, _1101));
    float3 _1130 = _822 * _1127;
    float2 _1137 = _831 + (_751 + float2(_823));
    float2 _1142 = _1137 * _859;
    float _1144 = precise::min(dot(_1142, _1142), 4.0);
    float _1146 = (0.4000000059604644775390625 * _1144) - 1.0;
    float _1148 = (0.25 * _1144) - 1.0;
    float _1154 = float(all(uint2(_824) < _855)) * ((((1.5625 * _1146) * _1146) - 0.5625) * (_1148 * _1148));
    float4 _1160 = (((((((float4(_762 * _872, _872) + float4(_771 * _902, _902)) + float4(_780 * _938, _938)) + float4(_789 * _974, _974)) + float4(_797 * _1010, _1010)) + float4(_805 * _1046, _1046)) + float4(_814 * _1082, _1082)) + float4(_822 * _1118, _1118)) + float4(_830 * _1154, _1154);
    float _1163 = exp(_850 * dot(_1137, _1137));
    float3 _1164 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_762, _771), _780), _789), _797), _805), _814), _822), _830);
    float3 _1165 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_762, _771), _780), _789), _797), _805), _814), _822), _830);
    float3 _1166 = _830 * _1163;
    float _1170 = (((((((_880 + _911) + _947) + _983) + _1019) + _1055) + _1091) + _1127) + _1163;
    float3 _1174 = float3((abs(_1170) > 0.001000000047497451305389404296875) ? _1170 : 1.0);
    float3 _1175 = ((((((((_881 + _914) + _950) + _986) + _1022) + _1058) + _1094) + _1130) + _1166) / _1174;
    float3 _1180 = sqrt(abs(((((((((((_762 * _881) + (_771 * _914)) + (_780 * _950)) + (_789 * _986)) + (_797 * _1022)) + (_805 * _1058)) + (_814 * _1094)) + (_822 * _1130)) + (_830 * _1166)) / _1174) - (_1175 * _1175)));
    float _1184 = _1160.w * float(_1160.w > 0.001000000047497451305389404296875);
    float4 _1185 = _1160;
    _1185.w = _1184;
    float4 _1198;
    if (_1184 > 0.001000000047497451305389404296875)
    {
        float3 _1191 = _1185.xyz / float3(_1184);
        float4 _1192 = float4(_1191.x, _1191.y, _1191.z, _1185.w);
        _1192.w = _1184 * 0.083333335816860198974609375;
        float3 _1196 = fast::clamp(_1192.xyz, _1164, _1165);
        _1198 = float4(_1196.x, _1196.y, _1196.z, _1192.w);
    }
    else
    {
        _1198 = _1185;
    }
    float _1199 = _1175.x;
    float _1205 = rint((_1199 / (1.0 + precise::max(0.0, _1199))) * 255.0) * 0.0039215688593685626983642578125;
    bool _1212;
    if (precise::max(precise::max(_214, _220), _683) < 0.100000001490116119384765625)
    {
        _1212 = !_224;
    }
    else
    {
        _1212 = false;
    }
    float4 _1220;
    if (_1212)
    {
        _1220 = r_luma_history.sample(s_LinearClamp, _193, level(0.0));
    }
    else
    {
        _1220 = float4(0.0);
    }
    float4 _145 = _1220;
    float _1223 = _1205 - _145.x;
    float _1224 = abs(_1223);
    float _1263;
    if (_1224 >= 0.0039215688593685626983642578125)
    {
        float _1229;
        _1229 = _1224;
        float _1230;
        for (int _1232 = 1; _1232 <= 3; _1229 = _1230, _1232++)
        {
            float _1240 = _1205 - _145[uint(_1232)];
            if (int(sign(_1223)) == int(sign(_1240)))
            {
                _1230 = precise::min(_1229, abs(_1240));
            }
            else
            {
                _1230 = _1229;
            }
        }
        _1263 = float((float(_1229 != _1224) * powr(fast::clamp(_1180.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_220, powr(_708, 0.16666667163372039794921875)));
    }
    else
    {
        _1263 = 0.0;
    }
    _145.w = _145.z;
    _145.z = _145.y;
    _145.y = _145.x;
    _145.x = _1205;
    sdk_hlsl_store(rw_luma_history, _145, uint2(_161));
    float _1280 = (float(_208) * _709) * (1.0 - _214);
    float _1284 = fast::clamp(_192 * 10.0, 0.0, 1.0);
    float _1287 = precise::min(_1280, mix(_1280, _1198.w * 10.0, precise::max(float(_635), _1284)));
    float _1289 = fast::clamp(_192 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1292 = float3(precise::min(_1287, mix(_1287, _1198.w, _1289)));
    float3 _1422;
    if (_224)
    {
        _1422 = float3((_1198.x + _1198.y) - _1198.z, _1198.x + _1198.z, (_1198.x - _1198.y) - _1198.z);
    }
    else
    {
        float3 _1306 = _1180 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_214, precise::max(_220, _1289)));
        float3 _1309 = precise::max(_1164, _1175 - _1306);
        float3 _1310 = precise::min(_1165, _1175 + _1306);
        bool _1318;
        if (!any(_1309 > _634))
        {
            _1318 = any(_634 > _1310);
        }
        else
        {
            _1318 = true;
        }
        float3 _1331;
        float3 _1332;
        if (_1318)
        {
            float3 _1327 = fast::clamp(float3(precise::max(_1263 * float(_145.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_717 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_728, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_219, 0.5)), float3(0.0), float3(1.0));
            _1331 = mix(fast::clamp(_634, _1309, _1310), _634, _1327);
            _1332 = mix(precise::min(_1292, float3(0.100000001490116119384765625)), _1292, _1327);
        }
        else
        {
            _1331 = _634;
            _1332 = _1292;
        }
        float _1340 = (_1198.x + _1198.y) - _1198.z;
        float _1341 = _1198.x + _1198.z;
        float _1343 = (_1198.x - _1198.y) - _1198.z;
        float3 _1350 = float3(_1340, _1341, _1343) / float3(precise::max(precise::max(0.0, _1340), precise::max(_1341, _1343)) + 1.0);
        float _1351 = _1350.x;
        float _1354 = 0.5 * _1350.y;
        float _1356 = _1350.z;
        float _1357 = 0.25 * _1356;
        float _1369 = (_1331.x + _1331.y) - _1331.z;
        float _1370 = _1331.x + _1331.z;
        float _1372 = (_1331.x - _1331.y) - _1331.z;
        float3 _1379 = float3(_1369, _1370, _1372) / float3(precise::max(precise::max(0.0, _1369), precise::max(_1370, _1372)) + 1.0);
        float _1380 = _1379.x;
        float _1383 = 0.5 * _1379.y;
        float _1385 = _1379.z;
        float _1386 = 0.25 * _1385;
        float3 _1397 = mix(float3(((0.25 * _1380) + _1383) + _1386, 0.5 * (_1380 - _1385), (((-0.25) * _1380) + _1383) - _1386), float3(((0.25 * _1351) + _1354) + _1357, 0.5 * (_1351 - _1356), (((-0.25) * _1351) + _1354) - _1357).xyz, _1198.www / precise::max(float3(0.001000000047497451305389404296875), _1332 + _1198.www));
        float _1402 = (_1397.x + _1397.y) - _1397.z;
        float _1403 = _1397.x + _1397.z;
        float _1405 = (_1397.x - _1397.y) - _1397.z;
        _1422 = float3(_1402, _1403, _1405) / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_1402, precise::max(_1403, _1405))));
    }
    float4 _1424 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1425 = _1424.x;
    float3 _1432 = (_1422 / float3((_1425 == 0.0) ? 1.0 : _1425)) * cbFSR2.fPreExposure;
    float2 _1433 = _166 - _190;
    float _1434 = _1433.x;
    bool _1439;
    if (_1434 >= 0.0)
    {
        _1439 = _1434 <= 1.0;
    }
    else
    {
        _1439 = false;
    }
    bool _1448;
    if (_1439)
    {
        float _1442 = _1433.y;
        bool _1447;
        if (_1442 >= 0.0)
        {
            _1447 = _1442 <= 1.0;
        }
        else
        {
            _1447 = false;
        }
        _1448 = _1447;
    }
    else
    {
        _1448 = false;
    }
    float2 _1461;
    if (!_1448)
    {
        float2 _1460 = _704;
        _1460.x = 0.0;
        _1461 = _1460;
    }
    else
    {
        float2 _1459 = _704;
        _1459.x = precise::max(0.0, _717 - (_1198.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1461 = _1459;
    }
    sdk_hlsl_store(rw_lock_status, _1461.xyyy, uint2(_161));
    float _1463 = precise::min(0.9900000095367431640625, _708);
    float _1466 = precise::max(_1463, mix(_1463, 0.4000000059604644775390625, fast::clamp(_192, 0.0, 1.0)));
    float _1471 = _224 ? 1.0 : precise::max(_1466 * _1466, precise::max(_214 * 0.100000001490116119384765625, _219));
    float _1477;
    if (_1284 >= 1.0)
    {
        _1477 = precise::max(0.001000000047497451305389404296875, _1471) * (-1.0);
    }
    else
    {
        _1477 = _1471;
    }
    float _1478 = _1432.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1478, _1432.yz, _1477), uint2(_161));
    sdk_hlsl_store(rw_upscaled_output, float4(_1478, _1432.yz, 1.0), uint2(_161));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_161));
}

