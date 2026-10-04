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
    uint2 _155 = gl_WorkGroupID.xy;
    _155.y = (((uint(cbFSR2.iDisplaySize.y) + 7u) / 8u) - gl_WorkGroupID.y) - 1u;
    uint2 _169 = (_155 * uint2(8u)) + gl_LocalInvocationID.xy;
    float2 _172 = float2(int2(_169)) + float2(0.5);
    float2 _173 = float2(cbFSR2.iDisplaySize);
    float2 _174 = _172 / _173;
    float2 _179 = float2(cbFSR2.iRenderSize);
    float2 _189 = precise::max(float2(0.5), precise::min((_174 + (cbFSR2.fJitter / _179)) * _179, _179 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize);
    float2 _196 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_174 * _179)))), 0u).xy;
    float _198 = length(_196 * _173);
    float2 _199 = _174 + _196;
    float _200 = _199.x;
    bool _205;
    if (_200 >= 0.0)
    {
        _205 = _200 <= 1.0;
    }
    else
    {
        _205 = false;
    }
    bool _214;
    if (_205)
    {
        float _208 = _199.y;
        bool _213;
        if (_208 >= 0.0)
        {
            _213 = _208 <= 1.0;
        }
        else
        {
            _213 = false;
        }
        _214 = _213;
    }
    else
    {
        _214 = false;
    }
    float _220 = fast::clamp(r_prepared_input_color.sample(s_LinearClamp, _189, level(0.0)).w, 0.0, 1.0);
    float4 _224 = r_dilated_reactive_masks.sample(s_LinearClamp, _189, level(0.0));
    float _225 = _224.x;
    float _226 = _224.y;
    bool _229 = 0 == cbFSR2.iFrameIndex;
    bool _230 = _214 ? _229 : true;
    bool _234;
    if (_214)
    {
        _234 = !_229;
    }
    else
    {
        _234 = false;
    }
    float2 _813;
    float3 _814;
    bool _815;
    bool _816;
    float _817;
    if (_234)
    {
        float2 _238 = (_199 * _173) - float2(0.5);
        float2 _248 = float2(precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.x), _238.x)), precise::max(0.0, precise::min(float(cbFSR2.iDisplaySize.y), _238.y)));
        float2 _249 = floor(_248);
        int2 _250 = int2(_249);
        half2 _252 = half2(_248 - _249);
        int2 _253 = _250 + int2(-1);
        int _257 = max(_253.y, 0);
        int2 _258 = int2(max(_253.x, 0), _257);
        _258.y = _257;
        int2 _264 = _250 + int2(0, -1);
        int _267 = max(_264.y, 0);
        int2 _268 = int2(_264.x, _267);
        _268.y = _267;
        int2 _274 = _250 + int2(1, -1);
        int _276 = cbFSR2.iDisplaySize.x - 1;
        int _279 = max(_274.y, 0);
        int2 _280 = int2(min(_274.x, _276), _279);
        _280.y = _279;
        int2 _286 = _250 + int2(2, -1);
        int _290 = max(_286.y, 0);
        int2 _291 = int2(min(_286.x, _276), _290);
        _291.y = _290;
        int2 _297 = _250 + int2(-1, 0);
        int _300 = _297.y;
        int2 _301 = int2(max(_297.x, 0), _300);
        _301.y = _300;
        int2 _308 = _250;
        _308.y = _250.y;
        half4 _312 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_308)), 0u));
        int2 _313 = _250 + int2(1, 0);
        int _316 = _313.y;
        int2 _317 = int2(min(_313.x, _276), _316);
        _317.y = _316;
        half4 _322 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_317)), 0u));
        int2 _323 = _250 + int2(2, 0);
        int _326 = _323.y;
        int2 _327 = int2(min(_323.x, _276), _326);
        _327.y = _326;
        int2 _333 = _250 + int2(-1, 1);
        int _336 = _333.y;
        int2 _337 = int2(max(_333.x, 0), _336);
        int _338 = cbFSR2.iDisplaySize.y - 1;
        _337.y = min(_336, _338);
        int2 _345 = _250 + int2(0, 1);
        _345.y = min(_345.y, _338);
        half4 _352 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_345)), 0u));
        int2 _353 = _250 + int2(1);
        int _356 = _353.y;
        int2 _357 = int2(min(_353.x, _276), _356);
        _357.y = min(_356, _338);
        half4 _363 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_357)), 0u));
        int2 _364 = _250 + int2(2, 1);
        int _367 = _364.y;
        int2 _368 = int2(min(_364.x, _276), _367);
        _368.y = min(_367, _338);
        int2 _375 = _250 + int2(-1, 2);
        int _378 = _375.y;
        int2 _379 = int2(max(_375.x, 0), _378);
        _379.y = min(_378, _338);
        int2 _386 = _250 + int2(0, 2);
        _386.y = min(_386.y, _338);
        int2 _394 = _250 + int2(1, 2);
        int _397 = _394.y;
        int2 _398 = int2(min(_394.x, _276), _397);
        _398.y = min(_397, _338);
        int2 _405 = _250 + int2(2);
        int _408 = _405.y;
        int2 _409 = int2(min(_405.x, _276), _408);
        _409.y = min(_408, _338);
        half _416 = _252.x;
        float _420 = float(min(abs(half(-1.0) - _416), half(2.0)));
        bool _422 = abs(_420) < 0.001000000047497451305389404296875;
        float _433;
        if (_422)
        {
            _433 = 1.0;
        }
        else
        {
            float _426 = 3.1415927410125732421875 * _420;
            float _429 = 1.57079637050628662109375 * _420;
            _433 = (sin(_426) / _426) * (sin(_429) / _429);
        }
        half _434 = half(_433);
        float _438 = float(min(abs(half(-0.0) - _416), half(2.0)));
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
        half _452 = half(_451);
        float _456 = float(min(abs(half(1.0) - _416), half(2.0)));
        bool _458 = abs(_456) < 0.001000000047497451305389404296875;
        float _469;
        if (_458)
        {
            _469 = 1.0;
        }
        else
        {
            float _462 = 3.1415927410125732421875 * _456;
            float _465 = 1.57079637050628662109375 * _456;
            _469 = (sin(_462) / _462) * (sin(_465) / _465);
        }
        half _470 = half(_469);
        float _474 = float(min(abs(half(2.0) - _416), half(2.0)));
        bool _476 = abs(_474) < 0.001000000047497451305389404296875;
        float _487;
        if (_476)
        {
            _487 = 1.0;
        }
        else
        {
            float _480 = 3.1415927410125732421875 * _474;
            float _483 = 1.57079637050628662109375 * _474;
            _487 = (sin(_480) / _480) * (sin(_483) / _483);
        }
        half _488 = half(_487);
        float _511;
        if (_422)
        {
            _511 = 1.0;
        }
        else
        {
            float _504 = 3.1415927410125732421875 * _420;
            float _507 = 1.57079637050628662109375 * _420;
            _511 = (sin(_504) / _504) * (sin(_507) / _507);
        }
        half _512 = half(_511);
        float _523;
        if (_440)
        {
            _523 = 1.0;
        }
        else
        {
            float _516 = 3.1415927410125732421875 * _438;
            float _519 = 1.57079637050628662109375 * _438;
            _523 = (sin(_516) / _516) * (sin(_519) / _519);
        }
        half _524 = half(_523);
        float _535;
        if (_458)
        {
            _535 = 1.0;
        }
        else
        {
            float _528 = 3.1415927410125732421875 * _456;
            float _531 = 1.57079637050628662109375 * _456;
            _535 = (sin(_528) / _528) * (sin(_531) / _531);
        }
        half _536 = half(_535);
        float _547;
        if (_476)
        {
            _547 = 1.0;
        }
        else
        {
            float _540 = 3.1415927410125732421875 * _474;
            float _543 = 1.57079637050628662109375 * _474;
            _547 = (sin(_540) / _540) * (sin(_543) / _543);
        }
        half _548 = half(_547);
        float _571;
        if (_422)
        {
            _571 = 1.0;
        }
        else
        {
            float _564 = 3.1415927410125732421875 * _420;
            float _567 = 1.57079637050628662109375 * _420;
            _571 = (sin(_564) / _564) * (sin(_567) / _567);
        }
        half _572 = half(_571);
        float _583;
        if (_440)
        {
            _583 = 1.0;
        }
        else
        {
            float _576 = 3.1415927410125732421875 * _438;
            float _579 = 1.57079637050628662109375 * _438;
            _583 = (sin(_576) / _576) * (sin(_579) / _579);
        }
        half _584 = half(_583);
        float _595;
        if (_458)
        {
            _595 = 1.0;
        }
        else
        {
            float _588 = 3.1415927410125732421875 * _456;
            float _591 = 1.57079637050628662109375 * _456;
            _595 = (sin(_588) / _588) * (sin(_591) / _591);
        }
        half _596 = half(_595);
        float _607;
        if (_476)
        {
            _607 = 1.0;
        }
        else
        {
            float _600 = 3.1415927410125732421875 * _474;
            float _603 = 1.57079637050628662109375 * _474;
            _607 = (sin(_600) / _600) * (sin(_603) / _603);
        }
        half _608 = half(_607);
        float _631;
        if (_422)
        {
            _631 = 1.0;
        }
        else
        {
            float _624 = 3.1415927410125732421875 * _420;
            float _627 = 1.57079637050628662109375 * _420;
            _631 = (sin(_624) / _624) * (sin(_627) / _627);
        }
        half _632 = half(_631);
        float _643;
        if (_440)
        {
            _643 = 1.0;
        }
        else
        {
            float _636 = 3.1415927410125732421875 * _438;
            float _639 = 1.57079637050628662109375 * _438;
            _643 = (sin(_636) / _636) * (sin(_639) / _639);
        }
        half _644 = half(_643);
        float _655;
        if (_458)
        {
            _655 = 1.0;
        }
        else
        {
            float _648 = 3.1415927410125732421875 * _456;
            float _651 = 1.57079637050628662109375 * _456;
            _655 = (sin(_648) / _648) * (sin(_651) / _651);
        }
        half _656 = half(_655);
        float _667;
        if (_476)
        {
            _667 = 1.0;
        }
        else
        {
            float _660 = 3.1415927410125732421875 * _474;
            float _663 = 1.57079637050628662109375 * _474;
            _667 = (sin(_660) / _660) * (sin(_663) / _663);
        }
        half _668 = half(_667);
        half _681 = _252.y;
        float _685 = float(min(abs(half(-1.0) - _681), half(2.0)));
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
        half _699 = half(_698);
        float _703 = float(min(abs(half(-0.0) - _681), half(2.0)));
        float _716;
        if (abs(_703) < 0.001000000047497451305389404296875)
        {
            _716 = 1.0;
        }
        else
        {
            float _709 = 3.1415927410125732421875 * _703;
            float _712 = 1.57079637050628662109375 * _703;
            _716 = (sin(_709) / _709) * (sin(_712) / _712);
        }
        half _717 = half(_716);
        float _721 = float(min(abs(half(1.0) - _681), half(2.0)));
        float _734;
        if (abs(_721) < 0.001000000047497451305389404296875)
        {
            _734 = 1.0;
        }
        else
        {
            float _727 = 3.1415927410125732421875 * _721;
            float _730 = 1.57079637050628662109375 * _721;
            _734 = (sin(_727) / _727) * (sin(_730) / _730);
        }
        half _735 = half(_734);
        float _739 = float(min(abs(half(2.0) - _681), half(2.0)));
        float _752;
        if (abs(_739) < 0.001000000047497451305389404296875)
        {
            _752 = 1.0;
        }
        else
        {
            float _745 = 3.1415927410125732421875 * _739;
            float _748 = 1.57079637050628662109375 * _739;
            _752 = (sin(_745) / _745) * (sin(_748) / _748);
        }
        half _753 = half(_752);
        half4 _760 = ((((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_258)), 0u)) * _434) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_268)), 0u)) * _452)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_280)), 0u)) * _470)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_291)), 0u)) * _488)) / half4(((_434 + _452) + _470) + _488)) * _699) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_301)), 0u)) * _512) + (_312 * _524)) + (_322 * _536)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_327)), 0u)) * _548)) / half4(((_512 + _524) + _536) + _548)) * _717)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_337)), 0u)) * _572) + (_352 * _584)) + (_363 * _596)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_368)), 0u)) * _608)) / half4(((_572 + _584) + _596) + _608)) * _735)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_379)), 0u)) * _632) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_386)), 0u)) * _644)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_398)), 0u)) * _656)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(_409)), 0u)) * _668)) / half4(((_632 + _644) + _656) + _668)) * _753);
        float4 _773 = float4(clamp(_760 / half4(((_699 + _717) + _735) + _753), min(min(min(_312, _322), _352), _363), max(max(max(_312, _322), _352), _363)));
        float4 _776 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _777 = _776.x;
        float3 _785 = fast::clamp((_773.xyz / float3(cbFSR2.fPreviousFramePreExposure)) * ((_777 == 0.0) ? 1.0 : _777), float3(0.0), float3(65504.0));
        float _786 = _785.x;
        float _789 = 0.5 * _785.y;
        float _791 = _785.z;
        float _792 = 0.25 * _791;
        float _800 = _773.w;
        spvImageFence(rw_new_locks);
        _813 = r_lock_status.sample(s_LinearClamp, _199, level(0.0)).xy;
        _814 = float3(((0.25 * _786) + _789) + _792, 0.5 * (_786 - _791), (((-0.25) * _786) + _789) - _792);
        _815 = _800 < 0.0;
        _816 = sdk_hlsl_load(rw_new_locks, uint2(_169)).x > 0.4980392158031463623046875;
        _817 = fast::clamp(abs(_800), 0.0, 1.0);
    }
    else
    {
        _813 = float2(0.0);
        _814 = float3(0.0);
        _815 = false;
        _816 = false;
        _817 = 0.0;
    }
    float2 _829 = float2(int2(_179 / float2(float(2 << (cbFSR2.iLumaMipLevelToUse & 31)))));
    float4 _837 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _838 = _837.x;
    float _850 = powr(((_838 == 0.0) ? 1.0 : _838) * exp(r_imgMips.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_174 * _829, _829 - float2(0.5))) / float2(cbFSR2.iLumaMipDimensions)), level(float(uint(cbFSR2.iLumaMipLevelToUse)))).x), 0.16666667163372039794921875);
    float _853 = (_813.y == 0.0) ? _850 : _813.y;
    float2 _854 = _813;
    _854.y = _853;
    float _855 = precise::max(_853, _850);
    float _862;
    if (_855 != 0.0)
    {
        _862 = precise::min(_853, _850) / _855;
    }
    else
    {
        _862 = 0.0;
    }
    float _863 = 1.0 - _862;
    float2 _884;
    if (_816)
    {
        _884 = float2((_813.x != 0.0) ? 2.0 : 1.0, _850);
    }
    else
    {
        float2 _879;
        if (_813.x <= 1.0)
        {
            float2 _878 = _854;
            _878.y = mix(_853, _850, 0.5);
            _879 = _878;
        }
        else
        {
            float2 _876;
            if (_863 > 0.100000001490116119384765625)
            {
                _876 = float2(0.0, _853);
            }
            else
            {
                _876 = _854;
            }
            _879 = _876;
        }
        _884 = _879;
    }
    float _888 = precise::max(precise::max(_225, _817), fast::clamp((0.89999997615814208984375 - _862) * 10.0, 0.0, 1.0));
    float _889 = 1.0 - _888;
    float _897 = ((_884.x * _889) * fast::clamp(1.0 - _226, 0.0, 1.0)) * float(_220 < 0.100000001490116119384765625);
    float _901 = precise::max(_884.y, _850);
    float _908;
    if (_901 != 0.0)
    {
        _908 = precise::min(_884.y, _850) / _901;
    }
    else
    {
        _908 = 0.0;
    }
    float2 _916 = _172 * cbFSR2.fDownscaleFactor;
    int2 _918 = int2(floor(_916));
    float2 _921 = (float2(_918) + float2(0.5)) - cbFSR2.fJitter;
    bool _924 = _921.x > _916.x;
    bool _928 = _921.y > _916.y;
    int2 _930 = int2(_924 ? (-2) : (-1), _928 ? (-2) : (-1));
    float2 _931 = float2(_930);
    int _932 = _924 ? 3 : 0;
    int _933 = _928 ? 3 : 0;
    int2 _934 = int2(_932, _933);
    int2 _935 = _918 + _930;
    int2 _936 = _935 + _934;
    int2 _938 = _936;
    _938.y = _936.y;
    float3 _942 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_938)), 0u).xyz;
    int _943 = _924 ? 2 : 1;
    int2 _944 = int2(_943, _933);
    int2 _945 = _935 + _944;
    int2 _947 = _945;
    _947.y = _945.y;
    float3 _951 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_947)), 0u).xyz;
    int _952 = _924 ? 1 : 2;
    int2 _953 = int2(_952, _933);
    int2 _954 = _935 + _953;
    int2 _956 = _954;
    _956.y = _954.y;
    float3 _960 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_956)), 0u).xyz;
    int _961 = _928 ? 2 : 1;
    int2 _962 = int2(_932, _961);
    int2 _963 = _935 + _962;
    int2 _965 = _963;
    _965.y = _963.y;
    float3 _969 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_965)), 0u).xyz;
    int2 _970 = int2(_943, _961);
    int2 _971 = _935 + _970;
    int2 _973 = _971;
    _973.y = _971.y;
    float3 _977 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_973)), 0u).xyz;
    int2 _978 = int2(_952, _961);
    int2 _979 = _935 + _978;
    int2 _981 = _979;
    _981.y = _979.y;
    float3 _985 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_981)), 0u).xyz;
    int _986 = _928 ? 1 : 2;
    int2 _987 = int2(_932, _986);
    int2 _988 = _935 + _987;
    int2 _990 = _988;
    _990.y = _988.y;
    float3 _994 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_990)), 0u).xyz;
    int2 _995 = int2(_943, _986);
    int2 _996 = _935 + _995;
    int2 _998 = _996;
    _998.y = _996.y;
    float3 _1002 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_998)), 0u).xyz;
    int2 _1003 = int2(_952, _986);
    int2 _1004 = _935 + _1003;
    int2 _1006 = _1004;
    _1006.y = _1004.y;
    float3 _1010 = sdk_hlsl_load(r_prepared_input_color, uint2(uint2(_1006)), 0u).xyz;
    float2 _1011 = _921 - _916;
    float _1013 = precise::max(_888, float(_230));
    float _1020 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR2.fDownscaleFactor) - float2(1.0)).x) * (1.0 - _1013);
    float _1030 = mix(-2.0, -3.0, fast::clamp(_198 * 0.0199999995529651641845703125, 0.0, 1.0));
    float2 _1033 = _1011 + (_931 + float2(_934));
    uint2 _1035 = uint2(cbFSR2.iRenderSize);
    float2 _1039 = float2(mix(_1020, precise::max(1.0, (1.0 + _1020) * 0.300000011920928955078125), precise::max(0.0, precise::max(0.25 * _220, _1013))));
    float2 _1040 = _1033 * _1039;
    float _1042 = precise::min(dot(_1040, _1040), 4.0);
    float _1044 = (0.4000000059604644775390625 * _1042) - 1.0;
    float _1046 = (0.25 * _1042) - 1.0;
    float _1052 = float(all(uint2(_936) < _1035)) * ((((1.5625 * _1044) * _1044) - 0.5625) * (_1046 * _1046));
    float _1060 = exp(_1030 * dot(_1033, _1033));
    float3 _1061 = _942 * _1060;
    float2 _1065 = _1011 + (_931 + float2(_944));
    float2 _1070 = _1065 * _1039;
    float _1072 = precise::min(dot(_1070, _1070), 4.0);
    float _1074 = (0.4000000059604644775390625 * _1072) - 1.0;
    float _1076 = (0.25 * _1072) - 1.0;
    float _1082 = float(all(uint2(_945) < _1035)) * ((((1.5625 * _1074) * _1074) - 0.5625) * (_1076 * _1076));
    float _1091 = exp(_1030 * dot(_1065, _1065));
    float3 _1094 = _951 * _1091;
    float2 _1101 = _1011 + (_931 + float2(_953));
    float2 _1106 = _1101 * _1039;
    float _1108 = precise::min(dot(_1106, _1106), 4.0);
    float _1110 = (0.4000000059604644775390625 * _1108) - 1.0;
    float _1112 = (0.25 * _1108) - 1.0;
    float _1118 = float(all(uint2(_954) < _1035)) * ((((1.5625 * _1110) * _1110) - 0.5625) * (_1112 * _1112));
    float _1127 = exp(_1030 * dot(_1101, _1101));
    float3 _1130 = _960 * _1127;
    float2 _1137 = _1011 + (_931 + float2(_962));
    float2 _1142 = _1137 * _1039;
    float _1144 = precise::min(dot(_1142, _1142), 4.0);
    float _1146 = (0.4000000059604644775390625 * _1144) - 1.0;
    float _1148 = (0.25 * _1144) - 1.0;
    float _1154 = float(all(uint2(_963) < _1035)) * ((((1.5625 * _1146) * _1146) - 0.5625) * (_1148 * _1148));
    float _1163 = exp(_1030 * dot(_1137, _1137));
    float3 _1166 = _969 * _1163;
    float2 _1173 = _1011 + (_931 + float2(_970));
    float2 _1178 = _1173 * _1039;
    float _1180 = precise::min(dot(_1178, _1178), 4.0);
    float _1182 = (0.4000000059604644775390625 * _1180) - 1.0;
    float _1184 = (0.25 * _1180) - 1.0;
    float _1190 = float(all(uint2(_971) < _1035)) * ((((1.5625 * _1182) * _1182) - 0.5625) * (_1184 * _1184));
    float _1199 = exp(_1030 * dot(_1173, _1173));
    float3 _1202 = _977 * _1199;
    float2 _1209 = _1011 + (_931 + float2(_978));
    float2 _1214 = _1209 * _1039;
    float _1216 = precise::min(dot(_1214, _1214), 4.0);
    float _1218 = (0.4000000059604644775390625 * _1216) - 1.0;
    float _1220 = (0.25 * _1216) - 1.0;
    float _1226 = float(all(uint2(_979) < _1035)) * ((((1.5625 * _1218) * _1218) - 0.5625) * (_1220 * _1220));
    float _1235 = exp(_1030 * dot(_1209, _1209));
    float3 _1238 = _985 * _1235;
    float2 _1245 = _1011 + (_931 + float2(_987));
    float2 _1250 = _1245 * _1039;
    float _1252 = precise::min(dot(_1250, _1250), 4.0);
    float _1254 = (0.4000000059604644775390625 * _1252) - 1.0;
    float _1256 = (0.25 * _1252) - 1.0;
    float _1262 = float(all(uint2(_988) < _1035)) * ((((1.5625 * _1254) * _1254) - 0.5625) * (_1256 * _1256));
    float _1271 = exp(_1030 * dot(_1245, _1245));
    float3 _1274 = _994 * _1271;
    float2 _1281 = _1011 + (_931 + float2(_995));
    float2 _1286 = _1281 * _1039;
    float _1288 = precise::min(dot(_1286, _1286), 4.0);
    float _1290 = (0.4000000059604644775390625 * _1288) - 1.0;
    float _1292 = (0.25 * _1288) - 1.0;
    float _1298 = float(all(uint2(_996) < _1035)) * ((((1.5625 * _1290) * _1290) - 0.5625) * (_1292 * _1292));
    float _1307 = exp(_1030 * dot(_1281, _1281));
    float3 _1310 = _1002 * _1307;
    float2 _1317 = _1011 + (_931 + float2(_1003));
    float2 _1322 = _1317 * _1039;
    float _1324 = precise::min(dot(_1322, _1322), 4.0);
    float _1326 = (0.4000000059604644775390625 * _1324) - 1.0;
    float _1328 = (0.25 * _1324) - 1.0;
    float _1334 = float(all(uint2(_1004) < _1035)) * ((((1.5625 * _1326) * _1326) - 0.5625) * (_1328 * _1328));
    float4 _1340 = (((((((float4(_942 * _1052, _1052) + float4(_951 * _1082, _1082)) + float4(_960 * _1118, _1118)) + float4(_969 * _1154, _1154)) + float4(_977 * _1190, _1190)) + float4(_985 * _1226, _1226)) + float4(_994 * _1262, _1262)) + float4(_1002 * _1298, _1298)) + float4(_1010 * _1334, _1334);
    float _1343 = exp(_1030 * dot(_1317, _1317));
    float3 _1344 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_942, _951), _960), _969), _977), _985), _994), _1002), _1010);
    float3 _1345 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_942, _951), _960), _969), _977), _985), _994), _1002), _1010);
    float3 _1346 = _1010 * _1343;
    float _1350 = (((((((_1060 + _1091) + _1127) + _1163) + _1199) + _1235) + _1271) + _1307) + _1343;
    float3 _1354 = float3((abs(_1350) > 0.001000000047497451305389404296875) ? _1350 : 1.0);
    float3 _1355 = ((((((((_1061 + _1094) + _1130) + _1166) + _1202) + _1238) + _1274) + _1310) + _1346) / _1354;
    float3 _1360 = sqrt(abs(((((((((((_942 * _1061) + (_951 * _1094)) + (_960 * _1130)) + (_969 * _1166)) + (_977 * _1202)) + (_985 * _1238)) + (_994 * _1274)) + (_1002 * _1310)) + (_1010 * _1346)) / _1354) - (_1355 * _1355)));
    float _1364 = _1340.w * float(_1340.w > 0.001000000047497451305389404296875);
    float4 _1365 = _1340;
    _1365.w = _1364;
    float4 _1378;
    if (_1364 > 0.001000000047497451305389404296875)
    {
        float3 _1371 = _1365.xyz / float3(_1364);
        float4 _1372 = float4(_1371.x, _1371.y, _1371.z, _1365.w);
        _1372.w = _1364 * 0.083333335816860198974609375;
        float3 _1376 = fast::clamp(_1372.xyz, _1344, _1345);
        _1378 = float4(_1376.x, _1376.y, _1376.z, _1372.w);
    }
    else
    {
        _1378 = _1365;
    }
    float _1379 = _1355.x;
    float _1385 = rint((_1379 / (1.0 + precise::max(0.0, _1379))) * 255.0) * 0.0039215688593685626983642578125;
    bool _1392;
    if (precise::max(precise::max(_220, _226), _863) < 0.100000001490116119384765625)
    {
        _1392 = !_230;
    }
    else
    {
        _1392 = false;
    }
    float4 _1400;
    if (_1392)
    {
        _1400 = r_luma_history.sample(s_LinearClamp, _199, level(0.0));
    }
    else
    {
        _1400 = float4(0.0);
    }
    float4 _153 = _1400;
    float _1403 = _1385 - _153.x;
    float _1404 = abs(_1403);
    float _1443;
    if (_1404 >= 0.0039215688593685626983642578125)
    {
        float _1409;
        _1409 = _1404;
        float _1410;
        for (int _1412 = 1; _1412 <= 3; _1409 = _1410, _1412++)
        {
            float _1420 = _1385 - _153[uint(_1412)];
            if (int(sign(_1403)) == int(sign(_1420)))
            {
                _1410 = precise::min(_1409, abs(_1420));
            }
            else
            {
                _1410 = _1409;
            }
        }
        _1443 = float((float(_1409 != _1404) * powr(fast::clamp(_1360.x * 10.0, 0.0, 1.0), 6.0)) > 0.0039215688593685626983642578125) * (1.0 - precise::max(_226, powr(_888, 0.16666667163372039794921875)));
    }
    else
    {
        _1443 = 0.0;
    }
    _153.w = _153.z;
    _153.z = _153.y;
    _153.y = _153.x;
    _153.x = _1385;
    sdk_hlsl_store(rw_luma_history, _153, uint2(_169));
    float _1460 = (float(_214) * _889) * (1.0 - _220);
    float _1464 = fast::clamp(_198 * 10.0, 0.0, 1.0);
    float _1467 = precise::min(_1460, mix(_1460, _1378.w * 10.0, precise::max(float(_815), _1464)));
    float _1469 = fast::clamp(_198 * 0.0500000007450580596923828125, 0.0, 1.0);
    float3 _1472 = float3(precise::min(_1467, mix(_1467, _1378.w, _1469)));
    float3 _1602;
    if (_230)
    {
        _1602 = float3((_1378.x + _1378.y) - _1378.z, _1378.x + _1378.z, (_1378.x - _1378.y) - _1378.z);
    }
    else
    {
        float3 _1486 = _1360 * mix(precise::min(20.0, powr(1.0 / abs(cbFSR2.fDownscaleFactor.x * cbFSR2.fDownscaleFactor.y), 3.0)), 1.0, precise::max(_220, precise::max(_226, _1469)));
        float3 _1489 = precise::max(_1344, _1355 - _1486);
        float3 _1490 = precise::min(_1345, _1355 + _1486);
        bool _1498;
        if (!any(_1489 > _814))
        {
            _1498 = any(_814 > _1490);
        }
        else
        {
            _1498 = true;
        }
        float3 _1511;
        float3 _1512;
        if (_1498)
        {
            float3 _1507 = fast::clamp(float3(precise::max(_1443 * float(_153.w != 0.0), fast::clamp(fast::clamp(fast::clamp(_897 - 1.0, 0.0, 1.0) * 4.0, 0.0, 1.0) * fast::clamp(_908, 0.0, 1.0), 0.0, 1.0))) * (1.0 - powr(_225, 0.5)), float3(0.0), float3(1.0));
            _1511 = mix(fast::clamp(_814, _1489, _1490), _814, _1507);
            _1512 = mix(precise::min(_1472, float3(0.100000001490116119384765625)), _1472, _1507);
        }
        else
        {
            _1511 = _814;
            _1512 = _1472;
        }
        float _1520 = (_1378.x + _1378.y) - _1378.z;
        float _1521 = _1378.x + _1378.z;
        float _1523 = (_1378.x - _1378.y) - _1378.z;
        float3 _1530 = float3(_1520, _1521, _1523) / float3(precise::max(precise::max(0.0, _1520), precise::max(_1521, _1523)) + 1.0);
        float _1531 = _1530.x;
        float _1534 = 0.5 * _1530.y;
        float _1536 = _1530.z;
        float _1537 = 0.25 * _1536;
        float _1549 = (_1511.x + _1511.y) - _1511.z;
        float _1550 = _1511.x + _1511.z;
        float _1552 = (_1511.x - _1511.y) - _1511.z;
        float3 _1559 = float3(_1549, _1550, _1552) / float3(precise::max(precise::max(0.0, _1549), precise::max(_1550, _1552)) + 1.0);
        float _1560 = _1559.x;
        float _1563 = 0.5 * _1559.y;
        float _1565 = _1559.z;
        float _1566 = 0.25 * _1565;
        float3 _1577 = mix(float3(((0.25 * _1560) + _1563) + _1566, 0.5 * (_1560 - _1565), (((-0.25) * _1560) + _1563) - _1566), float3(((0.25 * _1531) + _1534) + _1537, 0.5 * (_1531 - _1536), (((-0.25) * _1531) + _1534) - _1537).xyz, _1378.www / precise::max(float3(0.001000000047497451305389404296875), _1512 + _1378.www));
        float _1582 = (_1577.x + _1577.y) - _1577.z;
        float _1583 = _1577.x + _1577.z;
        float _1585 = (_1577.x - _1577.y) - _1577.z;
        _1602 = float3(_1582, _1583, _1585) / float3(precise::max(1.5266243281075730919837951660156e-05, 1.0 - precise::max(_1582, precise::max(_1583, _1585))));
    }
    float4 _1604 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1605 = _1604.x;
    float3 _1612 = (_1602 / float3((_1605 == 0.0) ? 1.0 : _1605)) * cbFSR2.fPreExposure;
    float2 _1613 = _174 - _196;
    float _1614 = _1613.x;
    bool _1619;
    if (_1614 >= 0.0)
    {
        _1619 = _1614 <= 1.0;
    }
    else
    {
        _1619 = false;
    }
    bool _1628;
    if (_1619)
    {
        float _1622 = _1613.y;
        bool _1627;
        if (_1622 >= 0.0)
        {
            _1627 = _1622 <= 1.0;
        }
        else
        {
            _1627 = false;
        }
        _1628 = _1627;
    }
    else
    {
        _1628 = false;
    }
    float2 _1641;
    if (!_1628)
    {
        float2 _1640 = _884;
        _1640.x = 0.0;
        _1641 = _1640;
    }
    else
    {
        float2 _1639 = _884;
        _1639.x = precise::max(0.0, _897 - (_1378.w / (cbFSR2.fJitterSequenceLength * 0.061666667461395263671875)));
        _1641 = _1639;
    }
    sdk_hlsl_store(rw_lock_status, _1641.xyyy, uint2(_169));
    float _1643 = precise::min(0.9900000095367431640625, _888);
    float _1646 = precise::max(_1643, mix(_1643, 0.4000000059604644775390625, fast::clamp(_198, 0.0, 1.0)));
    float _1651 = _230 ? 1.0 : precise::max(_1646 * _1646, precise::max(_220 * 0.100000001490116119384765625, _225));
    float _1657;
    if (_1464 >= 1.0)
    {
        _1657 = precise::max(0.001000000047497451305389404296875, _1651) * (-1.0);
    }
    else
    {
        _1657 = _1651;
    }
    float _1658 = _1612.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1658, _1612.yz, _1657), uint2(_169));
    sdk_hlsl_store(rw_upscaled_output, float4(_1658, _1612.yz, 1.0), uint2(_169));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_169));
}

