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

struct type_cbFSR3Upscaler
{
    int2 iRenderSize;
    int2 iPreviousFrameRenderSize;
    int2 iUpscaleSize;
    int2 iPreviousFrameUpscaleSize;
    int2 iMaxRenderSize;
    int2 iMaxUpscaleSize;
    float4 fDeviceToViewDepth;
    float2 fJitter;
    float2 fPreviousFrameJitter;
    float2 fMotionVectorScale;
    float2 fDownscaleFactor;
    float2 fMotionVectorJitterCancellation;
    float fTanHalfFOV;
    float fJitterSequenceLength;
    float fDeltaTime;
    float fDeltaPreExposure;
    float fViewSpaceToMetersFactor;
    float fFrameIndex;
    float fVelocityFactor;
    float fReactivenessScale;
    float fShadingChangeScale;
    float fAccumulationAddedPerFrame;
    float fMinDisocclusionAccumulation;
};

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_upscaled_output [[texture(3)]], texture2d<float> r_farthest_depth_mip1 [[texture(4)]], texture2d<float> r_luma_instability [[texture(5)]], texture2d<float, access::read_write> rw_new_locks [[texture(6)]], texture2d<float> r_dilated_motion_vectors [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _127 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _130 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _131 = _127 / _130;
    float2 _136 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _138 = _131 + (cbFSR3Upscaler.fJitter / _136);
    float2 _142 = _136 - float2(0.5);
    float2 _145 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _147 = _131 * _136;
    float2 _153 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_147)))), 0u).xy;
    float _155 = length(_153 * float2(3840.0, 2160.0));
    float2 _156 = _131 + _153;
    float _157 = _156.x;
    bool _162;
    if (_157 >= 0.0)
    {
        _162 = _157 <= 1.0;
    }
    else
    {
        _162 = false;
    }
    bool _171;
    if (_162)
    {
        float _165 = _156.y;
        bool _170;
        if (_165 >= 0.0)
        {
            _170 = _165 <= 1.0;
        }
        else
        {
            _170 = false;
        }
        _171 = _170;
    }
    else
    {
        _171 = false;
    }
    uint2 _182 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _188 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _205;
    if (_171)
    {
        _205 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _205 = true;
    }
    float4 _209 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _136, _142)) / _145), level(0.0));
    float _211 = fast::clamp(_209.x, 0.0, 1.0);
    float _213 = fast::clamp(_209.y, 0.0, 1.0);
    float _215 = fast::clamp(_209.z, 0.0, 1.0);
    float _217 = fast::clamp(_209.w, 0.0, 1.0);
    float _222 = _217 * float(rint(_217 * 100.0) > 1.0);
    bool _226;
    if (_171)
    {
        _226 = !_205;
    }
    else
    {
        _226 = false;
    }
    float3 _823;
    float _824;
    if (_226)
    {
        float2 _230 = (_156 * _130) - float2(0.5);
        half2 _233 = half2(_230 - floor(_230));
        int2 _246 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _230.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _230.y)))));
        int2 _247 = _246 + int2(-1);
        int _249 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _253 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _261 = _246 + int2(0, -1);
        int2 _273 = _246 + int2(1, -1);
        int2 _285 = _246 + int2(2, -1);
        int2 _297 = _246 + int2(-1, 0);
        half4 _319 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_246.x, _249)), max(1, min(_246.y, _253))))), 0u));
        int2 _320 = _246 + int2(1, 0);
        half4 _331 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_320.x, _249)), max(1, min(_320.y, _253))))), 0u));
        int2 _332 = _246 + int2(2, 0);
        int2 _344 = _246 + int2(-1, 1);
        int2 _356 = _246 + int2(0, 1);
        half4 _367 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_356.x, _249)), max(1, min(_356.y, _253))))), 0u));
        int2 _368 = _246 + int2(1);
        half4 _379 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_368.x, _249)), max(1, min(_368.y, _253))))), 0u));
        int2 _380 = _246 + int2(2, 1);
        int2 _392 = _246 + int2(-1, 2);
        int2 _404 = _246 + int2(0, 2);
        int2 _416 = _246 + int2(1, 2);
        int2 _428 = _246 + int2(2);
        half _440 = _233.x;
        float _444 = float(min(abs(half(-1.0) - _440), half(2.0)));
        bool _446 = abs(_444) < 6.099999882280826568603515625e-05;
        float _457;
        if (_446)
        {
            _457 = 1.0;
        }
        else
        {
            float _450 = 3.1415927410125732421875 * _444;
            float _453 = 1.57079637050628662109375 * _444;
            _457 = (sin(_450) / _450) * (sin(_453) / _453);
        }
        half _458 = half(_457);
        float _462 = float(min(abs(half(-0.0) - _440), half(2.0)));
        bool _464 = abs(_462) < 6.099999882280826568603515625e-05;
        float _475;
        if (_464)
        {
            _475 = 1.0;
        }
        else
        {
            float _468 = 3.1415927410125732421875 * _462;
            float _471 = 1.57079637050628662109375 * _462;
            _475 = (sin(_468) / _468) * (sin(_471) / _471);
        }
        half _476 = half(_475);
        float _480 = float(min(abs(half(1.0) - _440), half(2.0)));
        bool _482 = abs(_480) < 6.099999882280826568603515625e-05;
        float _493;
        if (_482)
        {
            _493 = 1.0;
        }
        else
        {
            float _486 = 3.1415927410125732421875 * _480;
            float _489 = 1.57079637050628662109375 * _480;
            _493 = (sin(_486) / _486) * (sin(_489) / _489);
        }
        half _494 = half(_493);
        float _498 = float(min(abs(half(2.0) - _440), half(2.0)));
        bool _500 = abs(_498) < 6.099999882280826568603515625e-05;
        float _511;
        if (_500)
        {
            _511 = 1.0;
        }
        else
        {
            float _504 = 3.1415927410125732421875 * _498;
            float _507 = 1.57079637050628662109375 * _498;
            _511 = (sin(_504) / _504) * (sin(_507) / _507);
        }
        half _512 = half(_511);
        float _535;
        if (_446)
        {
            _535 = 1.0;
        }
        else
        {
            float _528 = 3.1415927410125732421875 * _444;
            float _531 = 1.57079637050628662109375 * _444;
            _535 = (sin(_528) / _528) * (sin(_531) / _531);
        }
        half _536 = half(_535);
        float _547;
        if (_464)
        {
            _547 = 1.0;
        }
        else
        {
            float _540 = 3.1415927410125732421875 * _462;
            float _543 = 1.57079637050628662109375 * _462;
            _547 = (sin(_540) / _540) * (sin(_543) / _543);
        }
        half _548 = half(_547);
        float _559;
        if (_482)
        {
            _559 = 1.0;
        }
        else
        {
            float _552 = 3.1415927410125732421875 * _480;
            float _555 = 1.57079637050628662109375 * _480;
            _559 = (sin(_552) / _552) * (sin(_555) / _555);
        }
        half _560 = half(_559);
        float _571;
        if (_500)
        {
            _571 = 1.0;
        }
        else
        {
            float _564 = 3.1415927410125732421875 * _498;
            float _567 = 1.57079637050628662109375 * _498;
            _571 = (sin(_564) / _564) * (sin(_567) / _567);
        }
        half _572 = half(_571);
        float _595;
        if (_446)
        {
            _595 = 1.0;
        }
        else
        {
            float _588 = 3.1415927410125732421875 * _444;
            float _591 = 1.57079637050628662109375 * _444;
            _595 = (sin(_588) / _588) * (sin(_591) / _591);
        }
        half _596 = half(_595);
        float _607;
        if (_464)
        {
            _607 = 1.0;
        }
        else
        {
            float _600 = 3.1415927410125732421875 * _462;
            float _603 = 1.57079637050628662109375 * _462;
            _607 = (sin(_600) / _600) * (sin(_603) / _603);
        }
        half _608 = half(_607);
        float _619;
        if (_482)
        {
            _619 = 1.0;
        }
        else
        {
            float _612 = 3.1415927410125732421875 * _480;
            float _615 = 1.57079637050628662109375 * _480;
            _619 = (sin(_612) / _612) * (sin(_615) / _615);
        }
        half _620 = half(_619);
        float _631;
        if (_500)
        {
            _631 = 1.0;
        }
        else
        {
            float _624 = 3.1415927410125732421875 * _498;
            float _627 = 1.57079637050628662109375 * _498;
            _631 = (sin(_624) / _624) * (sin(_627) / _627);
        }
        half _632 = half(_631);
        float _655;
        if (_446)
        {
            _655 = 1.0;
        }
        else
        {
            float _648 = 3.1415927410125732421875 * _444;
            float _651 = 1.57079637050628662109375 * _444;
            _655 = (sin(_648) / _648) * (sin(_651) / _651);
        }
        half _656 = half(_655);
        float _667;
        if (_464)
        {
            _667 = 1.0;
        }
        else
        {
            float _660 = 3.1415927410125732421875 * _462;
            float _663 = 1.57079637050628662109375 * _462;
            _667 = (sin(_660) / _660) * (sin(_663) / _663);
        }
        half _668 = half(_667);
        float _679;
        if (_482)
        {
            _679 = 1.0;
        }
        else
        {
            float _672 = 3.1415927410125732421875 * _480;
            float _675 = 1.57079637050628662109375 * _480;
            _679 = (sin(_672) / _672) * (sin(_675) / _675);
        }
        half _680 = half(_679);
        float _691;
        if (_500)
        {
            _691 = 1.0;
        }
        else
        {
            float _684 = 3.1415927410125732421875 * _498;
            float _687 = 1.57079637050628662109375 * _498;
            _691 = (sin(_684) / _684) * (sin(_687) / _687);
        }
        half _692 = half(_691);
        half _705 = _233.y;
        float _709 = float(min(abs(half(-1.0) - _705), half(2.0)));
        float _722;
        if (abs(_709) < 6.099999882280826568603515625e-05)
        {
            _722 = 1.0;
        }
        else
        {
            float _715 = 3.1415927410125732421875 * _709;
            float _718 = 1.57079637050628662109375 * _709;
            _722 = (sin(_715) / _715) * (sin(_718) / _718);
        }
        half _723 = half(_722);
        float _727 = float(min(abs(half(-0.0) - _705), half(2.0)));
        float _740;
        if (abs(_727) < 6.099999882280826568603515625e-05)
        {
            _740 = 1.0;
        }
        else
        {
            float _733 = 3.1415927410125732421875 * _727;
            float _736 = 1.57079637050628662109375 * _727;
            _740 = (sin(_733) / _733) * (sin(_736) / _736);
        }
        half _741 = half(_740);
        float _745 = float(min(abs(half(1.0) - _705), half(2.0)));
        float _758;
        if (abs(_745) < 6.099999882280826568603515625e-05)
        {
            _758 = 1.0;
        }
        else
        {
            float _751 = 3.1415927410125732421875 * _745;
            float _754 = 1.57079637050628662109375 * _745;
            _758 = (sin(_751) / _751) * (sin(_754) / _754);
        }
        half _759 = half(_758);
        float _763 = float(min(abs(half(2.0) - _705), half(2.0)));
        float _776;
        if (abs(_763) < 6.099999882280826568603515625e-05)
        {
            _776 = 1.0;
        }
        else
        {
            float _769 = 3.1415927410125732421875 * _763;
            float _772 = 1.57079637050628662109375 * _763;
            _776 = (sin(_769) / _769) * (sin(_772) / _772);
        }
        half _777 = half(_776);
        half4 _782 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_247.x, _249)), max(1, min(_247.y, _253))))), 0u)) * _458) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_261.x, _249)), max(1, min(_261.y, _253))))), 0u)) * _476)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_273.x, _249)), max(1, min(_273.y, _253))))), 0u)) * _494)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_285.x, _249)), max(1, min(_285.y, _253))))), 0u)) * _512)) / half4(((_458 + _476) + _494) + _512)) * _723) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_297.x, _249)), max(1, min(_297.y, _253))))), 0u)) * _536) + (_319 * _548)) + (_331 * _560)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_332.x, _249)), max(1, min(_332.y, _253))))), 0u)) * _572)) / half4(((_536 + _548) + _560) + _572)) * _741)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_344.x, _249)), max(1, min(_344.y, _253))))), 0u)) * _596) + (_367 * _608)) + (_379 * _620)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_380.x, _249)), max(1, min(_380.y, _253))))), 0u)) * _632)) / half4(((_596 + _608) + _620) + _632)) * _759);
        half4 _789 = (_782 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_392.x, _249)), max(1, min(_392.y, _253))))), 0u)) * _656) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_404.x, _249)), max(1, min(_404.y, _253))))), 0u)) * _668)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_416.x, _249)), max(1, min(_416.y, _253))))), 0u)) * _680)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_428.x, _249)), max(1, min(_428.y, _253))))), 0u)) * _692)) / half4(((_656 + _668) + _680) + _692)) * _777)) / half4(((_723 + _741) + _759) + _777);
        float4 _797 = float4(clamp(_789, min(min(min(_319, _331), _367), _379), max(max(max(_319, _331), _367), _379)));
        float4 _803 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _804 = _803.x;
        float3 _807 = (_797.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_804 == 0.0) ? 1.0 : _804);
        float _811 = 0.5 * _807.y;
        float _814 = 0.25 * _807.z;
        _823 = float3(((0.25 * _807.x) + _811) + _814, 0.5 * (_807.x - _807.z), (((-0.25) * _807.x) + _811) - _814);
        _824 = _797.w;
    }
    else
    {
        _823 = float3(0.0);
        _824 = 0.0;
    }
    float _830 = precise::max(fast::clamp(_215, 0.0, 1.0), precise::max(_211, _213));
    float _833 = precise::max(0.0, (_824 * float(!_205)) - (_830 * 2.0));
    uint2 _837 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _854 = _131 - _153;
    float _855 = _854.x;
    bool _860;
    if (_855 >= 0.0)
    {
        _860 = _855 <= 1.0;
    }
    else
    {
        _860 = false;
    }
    bool _869;
    if (_860)
    {
        float _863 = _854.y;
        bool _868;
        if (_863 >= 0.0)
        {
            _868 = _863 <= 1.0;
        }
        else
        {
            _868 = false;
        }
        _869 = _868;
    }
    else
    {
        _869 = false;
    }
    float _879 = precise::min(_222, mix(_222, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_155 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _882 = _127 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _884 = int2(floor(_882));
    float2 _887 = (float2(_884) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _888 = _887 - _882;
    bool _891 = _887.x > _882.x;
    bool _895 = _887.y > _882.y;
    int2 _897 = int2(_891 ? (-2) : (-1), _895 ? (-2) : (-1));
    float2 _898 = float2(_897);
    bool _899 = _222 == 0.0;
    int _900 = _891 ? 3 : 0;
    int _901 = _895 ? 3 : 0;
    int2 _902 = int2(_900, _901);
    int2 _903 = _884 + _897;
    int2 _904 = _903 + _902;
    int _907 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _912 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _922 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _923 = _922.x;
    float3 _926 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_904.x, _907)), max(0, min(_904.y, _912))))), 0u).xyz) * ((_923 == 0.0) ? 1.0 : _923);
    float _927 = _926.x;
    float _930 = 0.5 * _926.y;
    float _932 = _926.z;
    float _933 = 0.25 * _932;
    float3 _940 = float3(((0.25 * _927) + _930) + _933, 0.5 * (_927 - _932), (((-0.25) * _927) + _930) - _933);
    int _941 = _891 ? 2 : 1;
    int2 _942 = int2(_941, _901);
    int2 _943 = _903 + _942;
    float4 _957 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _958 = _957.x;
    float3 _961 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_943.x, _907)), max(0, min(_943.y, _912))))), 0u).xyz) * ((_958 == 0.0) ? 1.0 : _958);
    float _962 = _961.x;
    float _965 = 0.5 * _961.y;
    float _967 = _961.z;
    float _968 = 0.25 * _967;
    float3 _975 = float3(((0.25 * _962) + _965) + _968, 0.5 * (_962 - _967), (((-0.25) * _962) + _965) - _968);
    int _976 = _891 ? 1 : 2;
    int2 _977 = int2(_976, _901);
    int2 _978 = _903 + _977;
    float4 _992 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _993 = _992.x;
    float3 _996 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_978.x, _907)), max(0, min(_978.y, _912))))), 0u).xyz) * ((_993 == 0.0) ? 1.0 : _993);
    float _997 = _996.x;
    float _1000 = 0.5 * _996.y;
    float _1002 = _996.z;
    float _1003 = 0.25 * _1002;
    float3 _1010 = float3(((0.25 * _997) + _1000) + _1003, 0.5 * (_997 - _1002), (((-0.25) * _997) + _1000) - _1003);
    int _1011 = _895 ? 2 : 1;
    int2 _1012 = int2(_900, _1011);
    int2 _1013 = _903 + _1012;
    float4 _1027 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1028 = _1027.x;
    float3 _1031 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1013.x, _907)), max(0, min(_1013.y, _912))))), 0u).xyz) * ((_1028 == 0.0) ? 1.0 : _1028);
    float _1032 = _1031.x;
    float _1035 = 0.5 * _1031.y;
    float _1037 = _1031.z;
    float _1038 = 0.25 * _1037;
    float3 _1045 = float3(((0.25 * _1032) + _1035) + _1038, 0.5 * (_1032 - _1037), (((-0.25) * _1032) + _1035) - _1038);
    int2 _1046 = int2(_941, _1011);
    int2 _1047 = _903 + _1046;
    float4 _1061 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1062 = _1061.x;
    float3 _1065 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1047.x, _907)), max(0, min(_1047.y, _912))))), 0u).xyz) * ((_1062 == 0.0) ? 1.0 : _1062);
    float _1066 = _1065.x;
    float _1069 = 0.5 * _1065.y;
    float _1071 = _1065.z;
    float _1072 = 0.25 * _1071;
    float3 _1079 = float3(((0.25 * _1066) + _1069) + _1072, 0.5 * (_1066 - _1071), (((-0.25) * _1066) + _1069) - _1072);
    int2 _1080 = int2(_976, _1011);
    int2 _1081 = _903 + _1080;
    float4 _1095 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1096 = _1095.x;
    float3 _1099 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1081.x, _907)), max(0, min(_1081.y, _912))))), 0u).xyz) * ((_1096 == 0.0) ? 1.0 : _1096);
    float _1100 = _1099.x;
    float _1103 = 0.5 * _1099.y;
    float _1105 = _1099.z;
    float _1106 = 0.25 * _1105;
    float3 _1113 = float3(((0.25 * _1100) + _1103) + _1106, 0.5 * (_1100 - _1105), (((-0.25) * _1100) + _1103) - _1106);
    int _1114 = _895 ? 1 : 2;
    int2 _1115 = int2(_900, _1114);
    int2 _1116 = _903 + _1115;
    float4 _1130 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1131 = _1130.x;
    float3 _1134 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1116.x, _907)), max(0, min(_1116.y, _912))))), 0u).xyz) * ((_1131 == 0.0) ? 1.0 : _1131);
    float _1135 = _1134.x;
    float _1138 = 0.5 * _1134.y;
    float _1140 = _1134.z;
    float _1141 = 0.25 * _1140;
    float3 _1148 = float3(((0.25 * _1135) + _1138) + _1141, 0.5 * (_1135 - _1140), (((-0.25) * _1135) + _1138) - _1141);
    int2 _1149 = int2(_941, _1114);
    int2 _1150 = _903 + _1149;
    float4 _1164 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1165 = _1164.x;
    float3 _1168 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1150.x, _907)), max(0, min(_1150.y, _912))))), 0u).xyz) * ((_1165 == 0.0) ? 1.0 : _1165);
    float _1169 = _1168.x;
    float _1172 = 0.5 * _1168.y;
    float _1174 = _1168.z;
    float _1175 = 0.25 * _1174;
    float3 _1182 = float3(((0.25 * _1169) + _1172) + _1175, 0.5 * (_1169 - _1174), (((-0.25) * _1169) + _1172) - _1175);
    int2 _1183 = int2(_976, _1114);
    int2 _1184 = _903 + _1183;
    float4 _1198 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1199 = _1198.x;
    float3 _1202 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1184.x, _907)), max(0, min(_1184.y, _912))))), 0u).xyz) * ((_1199 == 0.0) ? 1.0 : _1199);
    float _1203 = _1202.x;
    float _1206 = 0.5 * _1202.y;
    float _1208 = _1202.z;
    float _1209 = 0.25 * _1208;
    float3 _1216 = float3(((0.25 * _1203) + _1206) + _1209, 0.5 * (_1203 - _1208), (((-0.25) * _1203) + _1206) - _1209);
    float _1221 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1232 = mix(precise::max(1.0, (1.0 + _1221) * 0.300000011920928955078125), _1221, precise::min(1.0 - (_213 * 0.5), precise::min(1.0 - _215, fast::clamp(_879 * 5.0, 0.0, 1.0))));
    float2 _1235 = _888 + (_898 + float2(_902));
    uint2 _1237 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1240 = float(all(uint2(_904) < _1237));
    bool _1241 = !_899;
    float _1259;
    float3 _1260;
    if (_1241)
    {
        float2 _1245 = _1235 * float2(_1232);
        float _1247 = precise::min(dot(_1245, _1245), 4.0);
        float _1249 = (0.4000000059604644775390625 * _1247) - 1.0;
        float _1251 = (0.25 * _1247) - 1.0;
        float _1257 = _1240 * ((((1.5625 * _1249) * _1249) - 0.5625) * (_1251 * _1251));
        _1259 = _1257;
        _1260 = _940 * _1257;
    }
    else
    {
        _1259 = 0.0;
        _1260 = float3(0.0);
    }
    float _1264 = exp((-2.2999999523162841796875) * dot(_1235, _1235)) * _1240;
    float3 _1265 = _940 * _1264;
    float2 _1269 = _888 + (_898 + float2(_942));
    float _1273 = float(all(uint2(_943) < _1237));
    float _1293;
    float3 _1294;
    if (_1241)
    {
        float2 _1277 = _1269 * float2(_1232);
        float _1279 = precise::min(dot(_1277, _1277), 4.0);
        float _1281 = (0.4000000059604644775390625 * _1279) - 1.0;
        float _1283 = (0.25 * _1279) - 1.0;
        float _1289 = _1273 * ((((1.5625 * _1281) * _1281) - 0.5625) * (_1283 * _1283));
        _1293 = _1259 + _1289;
        _1294 = _1260 + (_975 * _1289);
    }
    else
    {
        _1293 = _1259;
        _1294 = _1260;
    }
    float _1298 = exp((-2.2999999523162841796875) * dot(_1269, _1269)) * _1273;
    float3 _1301 = _975 * _1298;
    float2 _1308 = _888 + (_898 + float2(_977));
    float _1312 = float(all(uint2(_978) < _1237));
    float _1332;
    float3 _1333;
    if (_1241)
    {
        float2 _1316 = _1308 * float2(_1232);
        float _1318 = precise::min(dot(_1316, _1316), 4.0);
        float _1320 = (0.4000000059604644775390625 * _1318) - 1.0;
        float _1322 = (0.25 * _1318) - 1.0;
        float _1328 = _1312 * ((((1.5625 * _1320) * _1320) - 0.5625) * (_1322 * _1322));
        _1332 = _1293 + _1328;
        _1333 = _1294 + (_1010 * _1328);
    }
    else
    {
        _1332 = _1293;
        _1333 = _1294;
    }
    float _1337 = exp((-2.2999999523162841796875) * dot(_1308, _1308)) * _1312;
    float3 _1340 = _1010 * _1337;
    float2 _1347 = _888 + (_898 + float2(_1012));
    float _1351 = float(all(uint2(_1013) < _1237));
    float _1371;
    float3 _1372;
    if (_1241)
    {
        float2 _1355 = _1347 * float2(_1232);
        float _1357 = precise::min(dot(_1355, _1355), 4.0);
        float _1359 = (0.4000000059604644775390625 * _1357) - 1.0;
        float _1361 = (0.25 * _1357) - 1.0;
        float _1367 = _1351 * ((((1.5625 * _1359) * _1359) - 0.5625) * (_1361 * _1361));
        _1371 = _1332 + _1367;
        _1372 = _1333 + (_1045 * _1367);
    }
    else
    {
        _1371 = _1332;
        _1372 = _1333;
    }
    float _1376 = exp((-2.2999999523162841796875) * dot(_1347, _1347)) * _1351;
    float3 _1379 = _1045 * _1376;
    float2 _1386 = _888 + (_898 + float2(_1046));
    float _1390 = float(all(uint2(_1047) < _1237));
    float _1410;
    float3 _1411;
    if (_1241)
    {
        float2 _1394 = _1386 * float2(_1232);
        float _1396 = precise::min(dot(_1394, _1394), 4.0);
        float _1398 = (0.4000000059604644775390625 * _1396) - 1.0;
        float _1400 = (0.25 * _1396) - 1.0;
        float _1406 = _1390 * ((((1.5625 * _1398) * _1398) - 0.5625) * (_1400 * _1400));
        _1410 = _1371 + _1406;
        _1411 = _1372 + (_1079 * _1406);
    }
    else
    {
        _1410 = _1371;
        _1411 = _1372;
    }
    float _1415 = exp((-2.2999999523162841796875) * dot(_1386, _1386)) * _1390;
    float3 _1418 = _1079 * _1415;
    float2 _1425 = _888 + (_898 + float2(_1080));
    float _1429 = float(all(uint2(_1081) < _1237));
    float _1449;
    float3 _1450;
    if (_1241)
    {
        float2 _1433 = _1425 * float2(_1232);
        float _1435 = precise::min(dot(_1433, _1433), 4.0);
        float _1437 = (0.4000000059604644775390625 * _1435) - 1.0;
        float _1439 = (0.25 * _1435) - 1.0;
        float _1445 = _1429 * ((((1.5625 * _1437) * _1437) - 0.5625) * (_1439 * _1439));
        _1449 = _1410 + _1445;
        _1450 = _1411 + (_1113 * _1445);
    }
    else
    {
        _1449 = _1410;
        _1450 = _1411;
    }
    float _1454 = exp((-2.2999999523162841796875) * dot(_1425, _1425)) * _1429;
    float3 _1457 = _1113 * _1454;
    float2 _1464 = _888 + (_898 + float2(_1115));
    float _1468 = float(all(uint2(_1116) < _1237));
    float _1488;
    float3 _1489;
    if (_1241)
    {
        float2 _1472 = _1464 * float2(_1232);
        float _1474 = precise::min(dot(_1472, _1472), 4.0);
        float _1476 = (0.4000000059604644775390625 * _1474) - 1.0;
        float _1478 = (0.25 * _1474) - 1.0;
        float _1484 = _1468 * ((((1.5625 * _1476) * _1476) - 0.5625) * (_1478 * _1478));
        _1488 = _1449 + _1484;
        _1489 = _1450 + (_1148 * _1484);
    }
    else
    {
        _1488 = _1449;
        _1489 = _1450;
    }
    float _1493 = exp((-2.2999999523162841796875) * dot(_1464, _1464)) * _1468;
    float3 _1496 = _1148 * _1493;
    float2 _1503 = _888 + (_898 + float2(_1149));
    float _1507 = float(all(uint2(_1150) < _1237));
    float _1527;
    float3 _1528;
    if (_1241)
    {
        float2 _1511 = _1503 * float2(_1232);
        float _1513 = precise::min(dot(_1511, _1511), 4.0);
        float _1515 = (0.4000000059604644775390625 * _1513) - 1.0;
        float _1517 = (0.25 * _1513) - 1.0;
        float _1523 = _1507 * ((((1.5625 * _1515) * _1515) - 0.5625) * (_1517 * _1517));
        _1527 = _1488 + _1523;
        _1528 = _1489 + (_1182 * _1523);
    }
    else
    {
        _1527 = _1488;
        _1528 = _1489;
    }
    float _1532 = exp((-2.2999999523162841796875) * dot(_1503, _1503)) * _1507;
    float3 _1535 = _1182 * _1532;
    float2 _1542 = _888 + (_898 + float2(_1183));
    float _1546 = float(all(uint2(_1184) < _1237));
    float _1566;
    float3 _1567;
    if (_1241)
    {
        float2 _1550 = _1542 * float2(_1232);
        float _1552 = precise::min(dot(_1550, _1550), 4.0);
        float _1554 = (0.4000000059604644775390625 * _1552) - 1.0;
        float _1556 = (0.25 * _1552) - 1.0;
        float _1562 = _1546 * ((((1.5625 * _1554) * _1554) - 0.5625) * (_1556 * _1556));
        _1566 = _1527 + _1562;
        _1567 = _1528 + (_1216 * _1562);
    }
    else
    {
        _1566 = _1527;
        _1567 = _1528;
    }
    float _1571 = exp((-2.2999999523162841796875) * dot(_1542, _1542)) * _1546;
    float3 _1574 = _1216 * _1571;
    float _1578 = (((((((_1264 + _1298) + _1337) + _1376) + _1415) + _1454) + _1493) + _1532) + _1571;
    float3 _1582 = float3((abs(_1578) > 1.1754943508222875079687365372222e-38) ? _1578 : 1.0);
    float3 _1583 = ((((((((_1265 + _1301) + _1340) + _1379) + _1418) + _1457) + _1496) + _1535) + _1574) / _1582;
    float _1591 = _1566 * float(_1566 > 6.099999882280826568603515625e-05);
    float3 _1599;
    float _1600;
    if (_1591 > 6.099999882280826568603515625e-05)
    {
        _1599 = fast::clamp(_1567 / float3(_1591), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_940, _975), _1010), _1045), _1079), _1113), _1148), _1182), _1216), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_940, _975), _1010), _1045), _1079), _1113), _1148), _1182), _1216));
        _1600 = _1591 * 0.04625000059604644775390625;
    }
    else
    {
        _1599 = _1567;
        _1600 = _1591;
    }
    float _1603 = _899 ? 1.0 : _1600;
    float _1604 = _899 ? 0.0 : _879;
    float3 _1618 = (sqrt(abs(((((((((((_940 * _1265) + (_975 * _1301)) + (_1010 * _1340)) + (_1045 * _1379)) + (_1079 * _1418)) + (_1113 * _1457)) + (_1148 * _1496)) + (_1182 * _1535)) + (_1216 * _1574)) / _1582) - (_1583 * _1583))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_155 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _188, _188 - float2(0.5))) / float2(int2(int(_182.x), int(_182.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _222, precise::max(powr(_211, 0.5), _215)))));
    float3 _1621 = (_823 - _1583) / precise::max(_1618, float3(1.19299997436428384389728307724e-07));
    float3 _1636;
    if (length(_1621) > 1.0)
    {
        _1636 = mix((fast::normalize(_1621) * _1618) + _1583, _823, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_147, _142)) / _145), level(0.0)).x, fast::clamp(fast::clamp(_833 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _222) * (1.0 - _213), 0.0, 1.0)));
    }
    else
    {
        _1636 = _823;
    }
    float3 _1645 = mix(_1636, select(_1599, _1583, bool3(_899)), float3(fast::clamp(_1603 / precise::max(6.099999882280826568603515625e-05, (_1604 * float(_1604 > 6.099999882280826568603515625e-05)) + _1603), 0.0, 1.0)));
    float _1646 = _1645.x;
    float _1647 = _1645.y;
    float _1649 = _1645.z;
    float4 _1656 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1657 = _1656.x;
    float3 _1662 = precise::max(float3((_1646 + _1647) - _1649, _1646 + _1649, (_1646 - _1647) - _1649) / float3((_1657 == 0.0) ? 1.0 : _1657), float3(0.0));
    float _1663 = _1662.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1663, _1662.yz, precise::max(0.0, precise::max(0.0, precise::min(_833 + (sdk_hlsl_load(rw_new_locks, uint2(_837)).x * (1.0 - precise::max(0.0, _211))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _830))) * float(_869)), uint2(_837));
    sdk_hlsl_store(rw_upscaled_output, float4(_1663, _1662.yz, 1.0), uint2(_837));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_837));
}

