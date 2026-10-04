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
    uint2 _144 = gl_WorkGroupID.xy;
    _144.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _158 = (_144 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _161 = float2(int2(_158)) + float2(0.5);
    float2 _162 = float2(cbFSR2.iDisplaySize);
    float2 _163 = _161 / _162;
    float2 _168 = float2(cbFSR2.iRenderSize);
    float2 _178 = precise::max(float2(0.5), precise::min((_163 + (cbFSR2.fJitter / _168)) * _168, _168 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _184 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_163 * _168))), 0u).xy;
    float _186 = length(_184 * _162);
    float2 _187 = _163 + _184;
    float _188 = _187.x;
    bool _193;
    if (_188 >= 0.0)
    {
        _193 = _188 <= 1.0;
    }
    else
    {
        _193 = false;
    }
    bool _202;
    if (_193)
    {
        float _196 = _187.y;
        bool _201;
        if (_196 >= 0.0)
        {
            _201 = _196 <= 1.0;
        }
        else
        {
            _201 = false;
        }
        _202 = _201;
    }
    else
    {
        _202 = false;
    }
    float _208 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _178, level(0.0)).w, 0.0, 1.0);
    float4 _212 = r_dilated_reactive_masks.sample(s_LinearClamp, _178, level(0.0));
    float _213 = _212.x;
    float _214 = _212.y;
    bool _217 = 0 == cbFSR2.iFrameIndex;
    bool _218 = _202 ? _217 : true;
    bool _222;
    if (_202)
    {
        _222 = !_217;
    }
    else
    {
        _222 = false;
    }
    float2 _755;
    float3 _756;
    bool _757;
    bool _758;
    float _759;
    if (_222)
    {
        float2 _226 = (_187 * _162) - float2(0.5);
        float2 _236 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _226.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _226.y)));
        float2 _237 = floor(_236);
        int2 _238 = int2(_237);
        float2 _239 = _236 - _237;
        int2 _240 = _238 + int2(-1);
        int _244 = max(_240.y, 0);
        int2 _245 = int2(max(_240.x, 0), _244);
        _245.y = _244;
        int2 _250 = _238 + int2(0, -1);
        int _253 = max(_250.y, 0);
        int2 _254 = int2(_250.x, _253);
        _254.y = _253;
        int2 _259 = _238 + int2(1, -1);
        int _261 = cbFSR2.iDisplaySize.x - 1;
        int _264 = max(_259.y, 0);
        int2 _265 = int2(min(_259.x, _261), _264);
        _265.y = _264;
        int2 _270 = _238 + int2(2, -1);
        int _274 = max(_270.y, 0);
        int2 _275 = int2(min(_270.x, _261), _274);
        _275.y = _274;
        int2 _280 = _238 + int2(-1, 0);
        int _283 = _280.y;
        int2 _284 = int2(max(_280.x, 0), _283);
        _284.y = _283;
        int2 _290 = _238;
        _290.y = _238.y;
        float4 _293 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_290)), 0u);
        int2 _294 = _238 + int2(1, 0);
        int _297 = _294.y;
        int2 _298 = int2(min(_294.x, _261), _297);
        _298.y = _297;
        float4 _302 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_298)), 0u);
        int2 _303 = _238 + int2(2, 0);
        int _306 = _303.y;
        int2 _307 = int2(min(_303.x, _261), _306);
        _307.y = _306;
        int2 _312 = _238 + int2(-1, 1);
        int _315 = _312.y;
        int2 _316 = int2(max(_312.x, 0), _315);
        int _317 = cbFSR2.iDisplaySize.y - 1;
        _316.y = min(_315, _317);
        int2 _323 = _238 + int2(0, 1);
        _323.y = min(_323.y, _317);
        float4 _329 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_323)), 0u);
        int2 _330 = _238 + int2(1);
        int _333 = _330.y;
        int2 _334 = int2(min(_330.x, _261), _333);
        _334.y = min(_333, _317);
        float4 _339 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_334)), 0u);
        int2 _340 = _238 + int2(2, 1);
        int _343 = _340.y;
        int2 _344 = int2(min(_340.x, _261), _343);
        _344.y = min(_343, _317);
        int2 _350 = _238 + int2(-1, 2);
        int _353 = _350.y;
        int2 _354 = int2(max(_350.x, 0), _353);
        _354.y = min(_353, _317);
        int2 _360 = _238 + int2(0, 2);
        _360.y = min(_360.y, _317);
        int2 _367 = _238 + int2(1, 2);
        int _370 = _367.y;
        int2 _371 = int2(min(_367.x, _261), _370);
        _371.y = min(_370, _317);
        int2 _377 = _238 + int2(2);
        int _380 = _377.y;
        int2 _381 = int2(min(_377.x, _261), _380);
        _381.y = min(_380, _317);
        float _387 = _239.x;
        float _390 = precise::min(abs((-1.0) - _387), 2.0);
        bool _392 = abs(_390) < 0.001000000047497451305389404296875;
        float _403;
        if (_392)
        {
            _403 = 1.0;
        }
        else
        {
            float _396 = 3.1415927410125732421875 * _390;
            float _399 = 1.57079637050628662109375 * _390;
            _403 = (sin(_396) / _396) * (sin(_399) / _399);
        }
        float _406 = precise::min(abs(-_387), 2.0);
        bool _408 = abs(_406) < 0.001000000047497451305389404296875;
        float _419;
        if (_408)
        {
            _419 = 1.0;
        }
        else
        {
            float _412 = 3.1415927410125732421875 * _406;
            float _415 = 1.57079637050628662109375 * _406;
            _419 = (sin(_412) / _412) * (sin(_415) / _415);
        }
        float _422 = precise::min(abs(1.0 - _387), 2.0);
        bool _424 = abs(_422) < 0.001000000047497451305389404296875;
        float _435;
        if (_424)
        {
            _435 = 1.0;
        }
        else
        {
            float _428 = 3.1415927410125732421875 * _422;
            float _431 = 1.57079637050628662109375 * _422;
            _435 = (sin(_428) / _428) * (sin(_431) / _431);
        }
        float _438 = precise::min(abs(2.0 - _387), 2.0);
        bool _440 = abs(_438) < 0.001000000047497451305389404296875;
        float _451;
        if (_440)
        {
            _451 = 1.0;
        }
        else
        {
            float _444 = 3.1415927410125732421875 * _438;
            float _447 = 1.57079637050628662109375 * _438;
            _451 = (sin(_444) / _444) * (sin(_447) / _447);
        }
        float _474;
        if (_392)
        {
            _474 = 1.0;
        }
        else
        {
            float _467 = 3.1415927410125732421875 * _390;
            float _470 = 1.57079637050628662109375 * _390;
            _474 = (sin(_467) / _467) * (sin(_470) / _470);
        }
        float _485;
        if (_408)
        {
            _485 = 1.0;
        }
        else
        {
            float _478 = 3.1415927410125732421875 * _406;
            float _481 = 1.57079637050628662109375 * _406;
            _485 = (sin(_478) / _478) * (sin(_481) / _481);
        }
        float _496;
        if (_424)
        {
            _496 = 1.0;
        }
        else
        {
            float _489 = 3.1415927410125732421875 * _422;
            float _492 = 1.57079637050628662109375 * _422;
            _496 = (sin(_489) / _489) * (sin(_492) / _492);
        }
        float _507;
        if (_440)
        {
            _507 = 1.0;
        }
        else
        {
            float _500 = 3.1415927410125732421875 * _438;
            float _503 = 1.57079637050628662109375 * _438;
            _507 = (sin(_500) / _500) * (sin(_503) / _503);
        }
        float _530;
        if (_392)
        {
            _530 = 1.0;
        }
        else
        {
            float _523 = 3.1415927410125732421875 * _390;
            float _526 = 1.57079637050628662109375 * _390;
            _530 = (sin(_523) / _523) * (sin(_526) / _526);
        }
        float _541;
        if (_408)
        {
            _541 = 1.0;
        }
        else
        {
            float _534 = 3.1415927410125732421875 * _406;
            float _537 = 1.57079637050628662109375 * _406;
            _541 = (sin(_534) / _534) * (sin(_537) / _537);
        }
        float _552;
        if (_424)
        {
            _552 = 1.0;
        }
        else
        {
            float _545 = 3.1415927410125732421875 * _422;
            float _548 = 1.57079637050628662109375 * _422;
            _552 = (sin(_545) / _545) * (sin(_548) / _548);
        }
        float _563;
        if (_440)
        {
            _563 = 1.0;
        }
        else
        {
            float _556 = 3.1415927410125732421875 * _438;
            float _559 = 1.57079637050628662109375 * _438;
            _563 = (sin(_556) / _556) * (sin(_559) / _559);
        }
        float _586;
        if (_392)
        {
            _586 = 1.0;
        }
        else
        {
            float _579 = 3.1415927410125732421875 * _390;
            float _582 = 1.57079637050628662109375 * _390;
            _586 = (sin(_579) / _579) * (sin(_582) / _582);
        }
        float _597;
        if (_408)
        {
            _597 = 1.0;
        }
        else
        {
            float _590 = 3.1415927410125732421875 * _406;
            float _593 = 1.57079637050628662109375 * _406;
            _597 = (sin(_590) / _590) * (sin(_593) / _593);
        }
        float _608;
        if (_424)
        {
            _608 = 1.0;
        }
        else
        {
            float _601 = 3.1415927410125732421875 * _422;
            float _604 = 1.57079637050628662109375 * _422;
            _608 = (sin(_601) / _601) * (sin(_604) / _604);
        }
        float _619;
        if (_440)
        {
            _619 = 1.0;
        }
        else
        {
            float _612 = 3.1415927410125732421875 * _438;
            float _615 = 1.57079637050628662109375 * _438;
            _619 = (sin(_612) / _612) * (sin(_615) / _615);
        }
        float _632 = _239.y;
        float _635 = precise::min(abs((-1.0) - _632), 2.0);
        float _648;
        if (abs(_635) < 0.001000000047497451305389404296875)
        {
            _648 = 1.0;
        }
        else
        {
            float _641 = 3.1415927410125732421875 * _635;
            float _644 = 1.57079637050628662109375 * _635;
            _648 = (sin(_641) / _641) * (sin(_644) / _644);
        }
        float _651 = precise::min(abs(-_632), 2.0);
        float _664;
        if (abs(_651) < 0.001000000047497451305389404296875)
        {
            _664 = 1.0;
        }
        else
        {
            float _657 = 3.1415927410125732421875 * _651;
            float _660 = 1.57079637050628662109375 * _651;
            _664 = (sin(_657) / _657) * (sin(_660) / _660);
        }
        float _667 = precise::min(abs(1.0 - _632), 2.0);
        float _680;
        if (abs(_667) < 0.001000000047497451305389404296875)
        {
            _680 = 1.0;
        }
        else
        {
            float _673 = 3.1415927410125732421875 * _667;
            float _676 = 1.57079637050628662109375 * _667;
            _680 = (sin(_673) / _673) * (sin(_676) / _676);
        }
        float _683 = precise::min(abs(2.0 - _632), 2.0);
        float _696;
        if (abs(_683) < 0.001000000047497451305389404296875)
        {
            _696 = 1.0;
        }
        else
        {
            float _689 = 3.1415927410125732421875 * _683;
            float _692 = 1.57079637050628662109375 * _683;
            _696 = (sin(_689) / _689) * (sin(_692) / _692);
        }
        float4 _703 = ((((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_245)), 0u) * _403) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_254)), 0u) * _419)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_265)), 0u) * _435)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_275)), 0u) * _451)) / float4(((_403 + _419) + _435) + _451)) * _648) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_284)), 0u) * _474) + (_293 * _485)) + (_302 * _496)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_307)), 0u) * _507)) / float4(((_474 + _485) + _496) + _507)) * _664)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_316)), 0u) * _530) + (_329 * _541)) + (_339 * _552)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_344)), 0u) * _563)) / float4(((_530 + _541) + _552) + _563)) * _680)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_354)), 0u) * _586) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_360)), 0u) * _597)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_371)), 0u) * _608)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_381)), 0u) * _619)) / float4(((_586 + _597) + _608) + _619)) * _696);
        float4 _715 = fast::clamp(_703 / float4(((_648 + _664) + _680) + _696), precise::min(precise::min(precise::min(_293, _302), _329), _339), precise::max(precise::max(precise::max(_293, _302), _329), _339));
        float4 _718 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _719 = _718.x;
        float3 _727 = fast::clamp((_715.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_719 == 0.0) ? 1.0 : _719), float3(0.0), float3(65504.0));
        float _728 = _727.x;
        float _731 = 0.5 * _727.y;
        float _733 = _727.z;
        float _734 = 0.25 * _733;
        float _742 = _715.w;
        spvImageFence(rw_new_locks);
        _755 = r_lock_status.sample(s_LinearClamp, _187, level(0.0)).xy;
        _756 = float3(((0.25 * _728) + _731) + _734, 0.5 * (_728 - _733), (((-0.25) * _728) + _731) - _734);
        _757 = _742 < 0.0;
        _758 = sdk_hlsl_load(rw_new_locks, uint2(_158)).x > 0.4980392158031463623046875;
        _759 = fast::clamp(abs(_742), 0.0, 1.0);
    }
    else
    {
        _755 = float2(0.0);
        _756 = float3(0.0);
        _757 = false;
        _758 = false;
        _759 = 0.0;
    }
    float2 _771 = float2(int2(_168 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _779 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _780 = _779.x;
    float _792 = powr(((_780 == 0.0) ? 1.0 : _780) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_163 * _771, _771 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _795 = (_755.y == 0.0) ? _792 : _755.y;
    float2 _796 = _755;
    _796.y = _795;
    float _797 = precise::max(_795, _792);
    float _804;
    if (_797 != 0.0)
    {
        _804 = precise::min(_795, _792) / _797;
    }
    else
    {
        _804 = 0.0;
    }
    float _805 = 1.0 - _804;
    float2 _826;
    if (_758)
    {
        _826 = float2((_755.x != 0.0) ? 2.0 : 1.0, _792);
    }
    else
    {
        float2 _821;
        if (_755.x <= 1.0)
        {
            float2 _820 = _796;
            _820.y = mix(_795, _792, 0.5);
            _821 = _820;
        }
        else
        {
            float2 _818;
            if (_805 > 0.100000001490116119384765625)
            {
                _818 = float2(0.0, _795);
            }
            else
            {
                _818 = _796;
            }
            _821 = _818;
        }
        _826 = _821;
    }
    float _830 = precise::max(precise::max(_213, _759), fast::clamp((0.89999997615814208984375 - _804) * 10.0, 0.0, 1.0));
    float _831 = 1.0 - _830;
    float _839 = ((_826.x * _831) * fast::clamp(1.0 - _214, 0.0, 1.0)) * float(_208 < 0.100000001490116119384765625);
    float _843 = precise::max(_826.y, _792);
    float _850;
    if (_843 != 0.0)
    {
        _850 = precise::min(_826.y, _792) / _843;
    }
    else
    {
        _850 = 0.0;
    }
    float2 _858 = _161 * cbFSR2.fDownscaleFactor;
    int2 _860 = int2(floor(_858));
    float2 _863 = (float2(_860) + float2(0.5)) - cbFSR2.fJitter;
    bool _866 = _863.x > _858.x;
    bool _870 = _863.y > _858.y;
    int2 _872 = int2(_866 ? (-2) : (-1), _870 ? (-2) : (-1));
    float2 _873 = float2(_872);
    int _874 = _866 ? 3 : 0;
    int _875 = _870 ? 3 : 0;
    int2 _876 = int2(_874, _875);
    int2 _877 = _860 + _872;
    int2 _878 = _877 + _876;
    int2 _880 = _878;
    _880.y = _878.y;
    float3 _884 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_880)), 0u).xyz;
    int _885 = _866 ? 2 : 1;
    int2 _886 = int2(_885, _875);
    int2 _887 = _877 + _886;
    int2 _889 = _887;
    _889.y = _887.y;
    float3 _893 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_889)), 0u).xyz;
    int _894 = _866 ? 1 : 2;
    int2 _895 = int2(_894, _875);
    int2 _896 = _877 + _895;
    int2 _898 = _896;
    _898.y = _896.y;
    float3 _902 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_898)), 0u).xyz;
    int _903 = _870 ? 2 : 1;
    int2 _904 = int2(_874, _903);
    int2 _905 = _877 + _904;
    int2 _907 = _905;
    _907.y = _905.y;
    float3 _911 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_907)), 0u).xyz;
    int2 _912 = int2(_885, _903);
    int2 _913 = _877 + _912;
    int2 _915 = _913;
    _915.y = _913.y;
    float3 _919 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_915)), 0u).xyz;
    int2 _920 = int2(_894, _903);
    int2 _921 = _877 + _920;
    int2 _923 = _921;
    _923.y = _921.y;
    float3 _927 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_923)), 0u).xyz;
    int _928 = _870 ? 1 : 2;
    int2 _929 = int2(_874, _928);
    int2 _930 = _877 + _929;
    int2 _932 = _930;
    _932.y = _930.y;
    float3 _936 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_932)), 0u).xyz;
    int2 _937 = int2(_885, _928);
    int2 _938 = _877 + _937;
    int2 _940 = _938;
    _940.y = _938.y;
    float3 _944 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_940)), 0u).xyz;
    int2 _945 = int2(_894, _928);
    int2 _946 = _877 + _945;
    int2 _948 = _946;
    _948.y = _946.y;
    float3 _952 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_948)), 0u).xyz;
    float2 _953 = _863 - _858;
    float _955 = precise::max(_830, float(_218));
    float _962 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _955);
    float _972 = mix(-2.0, -3.0, fast::clamp(_186 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _975 = _953 + (_873 + float2(_876));
    uint2 _977 = uint2(cbFSR2.iRenderSize);
    float2 _981 = float2(mix(_962, precise::max(1.0, (1.0 + _962) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _208, _955))));
    float2 _982 = _975 * _981;
    float _984 = precise::min(dot(_982, _982), 4.0);
    float _986 = (0.4000000059604644775390625 * _984) - 1.0;
    float _988 = (0.25 * _984) - 1.0;
    float _994 = float(all(uint2(_878) < _977)) * ((((1.5625 * _986) * _986) - 0.5625) * (_988 * _988));
    float _1002 = exp(_972 * dot(_975, _975));
    float3 _1003 = _884 * _1002;
    float2 _1007 = _953 + (_873 + float2(_886));
    float2 _1012 = _1007 * _981;
    float _1014 = precise::min(dot(_1012, _1012), 4.0);
    float _1016 = (0.4000000059604644775390625 * _1014) - 1.0;
    float _1018 = (0.25 * _1014) - 1.0;
    float _1024 = float(all(uint2(_887) < _977)) * ((((1.5625 * _1016) * _1016) - 0.5625) * (_1018 * _1018));
    float _1033 = exp(_972 * dot(_1007, _1007));
    float3 _1036 = _893 * _1033;
    float2 _1043 = _953 + (_873 + float2(_895));
    float2 _1048 = _1043 * _981;
    float _1050 = precise::min(dot(_1048, _1048), 4.0);
    float _1052 = (0.4000000059604644775390625 * _1050) - 1.0;
    float _1054 = (0.25 * _1050) - 1.0;
    float _1060 = float(all(uint2(_896) < _977)) * ((((1.5625 * _1052) * _1052) - 0.5625) * (_1054 * _1054));
    float _1069 = exp(_972 * dot(_1043, _1043));
    float3 _1072 = _902 * _1069;
    float2 _1079 = _953 + (_873 + float2(_904));
    float2 _1084 = _1079 * _981;
    float _1086 = precise::min(dot(_1084, _1084), 4.0);
    float _1088 = (0.4000000059604644775390625 * _1086) - 1.0;
    float _1090 = (0.25 * _1086) - 1.0;
    float _1096 = float(all(uint2(_905) < _977)) * ((((1.5625 * _1088) * _1088) - 0.5625) * (_1090 * _1090));
    float _1105 = exp(_972 * dot(_1079, _1079));
    float3 _1108 = _911 * _1105;
    float2 _1115 = _953 + (_873 + float2(_912));
    float2 _1120 = _1115 * _981;
    float _1122 = precise::min(dot(_1120, _1120), 4.0);
    float _1124 = (0.4000000059604644775390625 * _1122) - 1.0;
    float _1126 = (0.25 * _1122) - 1.0;
    float _1132 = float(all(uint2(_913) < _977)) * ((((1.5625 * _1124) * _1124) - 0.5625) * (_1126 * _1126));
    float _1141 = exp(_972 * dot(_1115, _1115));
    float3 _1144 = _919 * _1141;
    float2 _1151 = _953 + (_873 + float2(_920));
    float2 _1156 = _1151 * _981;
    float _1158 = precise::min(dot(_1156, _1156), 4.0);
    float _1160 = (0.4000000059604644775390625 * _1158) - 1.0;
    float _1162 = (0.25 * _1158) - 1.0;
    float _1168 = float(all(uint2(_921) < _977)) * ((((1.5625 * _1160) * _1160) - 0.5625) * (_1162 * _1162));
    float _1177 = exp(_972 * dot(_1151, _1151));
    float3 _1180 = _927 * _1177;
    float2 _1187 = _953 + (_873 + float2(_929));
    float2 _1192 = _1187 * _981;
    float _1194 = precise::min(dot(_1192, _1192), 4.0);
    float _1196 = (0.4000000059604644775390625 * _1194) - 1.0;
    float _1198 = (0.25 * _1194) - 1.0;
    float _1204 = float(all(uint2(_930) < _977)) * ((((1.5625 * _1196) * _1196) - 0.5625) * (_1198 * _1198));
    float _1213 = exp(_972 * dot(_1187, _1187));
    float3 _1216 = _936 * _1213;
    float2 _1223 = _953 + (_873 + float2(_937));
    float2 _1228 = _1223 * _981;
    float _1230 = precise::min(dot(_1228, _1228), 4.0);
    float _1232 = (0.4000000059604644775390625 * _1230) - 1.0;
    float _1234 = (0.25 * _1230) - 1.0;
    float _1240 = float(all(uint2(_938) < _977)) * ((((1.5625 * _1232) * _1232) - 0.5625) * (_1234 * _1234));
    float _1249 = exp(_972 * dot(_1223, _1223));
    float3 _1252 = _944 * _1249;
    float2 _1259 = _953 + (_873 + float2(_945));
    float2 _1264 = _1259 * _981;
    float _1266 = precise::min(dot(_1264, _1264), 4.0);
    float _1268 = (0.4000000059604644775390625 * _1266) - 1.0;
    float _1270 = (0.25 * _1266) - 1.0;
    float _1276 = float(all(uint2(_946) < _977)) * ((((1.5625 * _1268) * _1268) - 0.5625) * (_1270 * _1270));
    float4 _1282 = (((((((float4(_884 * _994, _994) + float4(_893 * _1024, _1024)) + float4(_902 * _1060, _1060)) + float4(_911 * _1096, _1096)) + float4(_919 * _1132, _1132)) + float4(_927 * _1168, _1168)) + float4(_936 * _1204, _1204)) + float4(_944 * _1240, _1240)) + float4(_952 * _1276, _1276);
    float _1285 = exp(_972 * dot(_1259, _1259));
    float3 _1286 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_884, _893), _902), _911), _919), _927), _936), _944), _952);
    float3 _1287 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_884, _893), _902), _911), _919), _927), _936), _944), _952);
    float3 _1288 = _952 * _1285;
    float _1292 = (((((((_1002 + _1033) + _1069) + _1105) + _1141) + _1177) + _1213) + _1249) + _1285;
    float3 _1296 = float3((abs(_1292) > 0.001000000047497451305389404296875) ? _1292 : 1.0);
    float3 _1297 = ((((((((_1003 + _1036) + _1072) + _1108) + _1144) + _1180) + _1216) + _1252) + _1288) / _1296;
    float3 _1302 = sqrt(abs(((((((((((_884 * _1003) + (_893 * _1036)) + (_902 * _1072)) + (_911 * _1108)) + (_919 * _1144)) + (_927 * _1180)) + (_936 * _1216)) + (_944 * _1252)) + (_952 * _1288)) / _1296) - (_1297 * _1297)));
    float _1306 = _1282.w * float(_1282.w > 0.001000000047497451305389404296875);
    float4 _1307 = _1282;
    _1307.w = _1306;
    float4 _1320;
    if (_1306 > 0.001000000047497451305389404296875)
    {
        float3 _1313 = _1307.xyz / float3(_1306);
        float4 _1314 = float4(_1313.x, _1313.y, _1313.z, _1307.w);
        _1314.w = _1306 * 0.083333335816860198974609375;
        float3 _1318 = fast::clamp(_1314.xyz, _1286, _1287);
        _1320 = float4(_1318.x, _1318.y, _1318.z, _1314.w);
    }
    else
    {
        _1320 = _1307;
    }
    float _1324 = rint(_1297.x * 255.0) * 0.0039215688593685626983642578125;
    bool _1331;
    if (precise::max(precise::max(_208, _214), _805) < 0.100000001490116119384765625)
    {
        _1331 = !_218;
    }
    else
    {
        _1331 = false;
    }
    float4 _1339;
    if (_1331)
    {
        _1339 = r_luma_history.sample(s_LinearClamp, _187, level(0.0));
    }
    else
    {
        _1339 = float4(0.0);
    }
    float4 _142 = _1339;
    float _1342 = _1324 - _142.x;
    float _1343 = abs(_1342);
    float _1382;
    if (_1343 >= 0.0039215688593685626983642578125)
    {
        float _1348;
        _1348 = _1343;
        float _1349;
        for (int _1351 = 1; _1351 <= 3; _1348 = _1349, _1351++)
        {
            float _1359 = _1324 - _142[uint(_1351)];
            if (int(sign(_1342)) == int(sign(_1359)))
            {
                _1349 = precise::min(_1348, abs(_1359));
            }
            else
            {
                _1349 = _1348;
            }
        }
        _1382 = float((float(_1348 != _1343) * powr(fast::clamp(_1302.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_214, powr(_830, 0.16666667163372039794921875)));
    }
    else
    {
        _1382 = 0.0;
    }
    _142.w = _142.z;
    _142.z = _142.y;
    _142.y = _142.x;
    _142.x = _1324;
    sdk_hlsl_store(rw_luma_history, _142, uint2(_158));
    float _1399 = (float(_202) * _831) * (1.0 - _208);
    float _1403 = fast::clamp(_186 * 10.0, 0.0, 1.0);
    float _1406 = precise::min(_1399, mix(_1399, _1320.w * 10.0, precise::max(float(_757), _1403)));
    float _1408 = fast::clamp(_186 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1411 = float3(precise::min(_1406, mix(_1406, _1320.w, _1408)));
    float3 _1476;
    if (_218)
    {
        _1476 = float3((_1320.x + _1320.y) - _1320.z, _1320.x + _1320.z, (_1320.x - _1320.y) - _1320.z);
    }
    else
    {
        float3 _1425 = _1302 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_208, precise::max(_214, _1408)));
        float3 _1428 = precise::max(_1286, _1297 - _1425);
        float3 _1429 = precise::min(_1287, _1297 + _1425);
        bool _1437;
        if (!any(_1428 > _756))
        {
            _1437 = any(_756 > _1429);
        }
        else
        {
            _1437 = true;
        }
        float3 _1450;
        float3 _1451;
        if (_1437)
        {
            float3 _1446 = fast::clamp(float3(precise::max(_1382 * float(_142.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_839 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_850, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_213, 0.5)), float3(0.0), float3(1.0));
            _1450 = mix(fast::clamp(_756, _1428, _1429), _756, _1446);
            _1451 = mix(precise::min(_1411, float3(0.100000001490116119384765625)), _1411, _1446);
        }
        else
        {
            _1450 = _756;
            _1451 = _1411;
        }
        float3 _1457 = mix(_1450, _1320.xyz, _1320.www / precise::max(float3(0.001000000047497451305389404296875), _1451 + _1320.www));
        float _1458 = _1457.x;
        float _1459 = _1457.y;
        float _1461 = _1457.z;
        _1476 = float3((_1458 + _1459) - _1461, _1458 + _1461, (_1458 - _1459) - _1461);
    }
    float4 _1478 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1479 = _1478.x;
    float3 _1486 = (_1476 / float3((_1479 == 0.0) ? 1.0 : _1479)) * cbFSR2.fPreExposure;
    float2 _1487 = _163 - _184;
    float _1488 = _1487.x;
    bool _1493;
    if (_1488 >= 0.0)
    {
        _1493 = _1488 <= 1.0;
    }
    else
    {
        _1493 = false;
    }
    bool _1502;
    if (_1493)
    {
        float _1496 = _1487.y;
        bool _1501;
        if (_1496 >= 0.0)
        {
            _1501 = _1496 <= 1.0;
        }
        else
        {
            _1501 = false;
        }
        _1502 = _1501;
    }
    else
    {
        _1502 = false;
    }
    float2 _1515;
    if (!_1502)
    {
        float2 _1514 = _826;
        _1514.x = 0.0;
        _1515 = _1514;
    }
    else
    {
        float2 _1513 = _826;
        _1513.x = precise::max(0.0, _839 - (_1320.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1515 = _1513;
    }
    sdk_hlsl_store(rw_lock_status, _1515.xyyy, uint2(_158));
    float _1517 = precise::min(0.9900000095367431640625, _830);
    float _1520 = precise::max(_1517, mix(_1517, 0.4000000059604644775390625, fast::clamp(_186, 0.0, 1.0)));
    float _1525 = _218 ? 1.0 : precise::max(_1520 * _1520, precise::max(_208 * 0.100000001490116119384765625, _213));
    float _1531;
    if (_1403 >= 1.0)
    {
        _1531 = precise::max(0.001000000047497451305389404296875, _1525) * (-1.0);
    }
    else
    {
        _1531 = _1525;
    }
    float _1532 = _1486.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1532, _1486.yz, _1531), uint2(_158));
    sdk_hlsl_store(rw_upscaled_output, float4(_1532, _1486.yz, 1.0), uint2(_158));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_158));
}

