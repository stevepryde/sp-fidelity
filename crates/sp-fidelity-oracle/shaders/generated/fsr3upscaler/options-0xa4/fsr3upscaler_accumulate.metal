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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float> r_farthest_depth_mip1 [[texture(3)]], texture2d<float> r_luma_instability [[texture(4)]], texture2d<float, access::read_write> rw_new_locks [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _124 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _127 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _128 = _124 / _127;
    float2 _133 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _135 = _128 + (cbFSR3Upscaler.fJitter / _133);
    float2 _139 = _133 - float2(0.5);
    float2 _142 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _144 = _128 * _133;
    float2 _150 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_144)))), 0u).xy;
    float _152 = length(_150 * float2(3840.0, 2160.0));
    float2 _153 = _128 + _150;
    float _154 = _153.x;
    bool _159;
    if (_154 >= 0.0)
    {
        _159 = _154 <= 1.0;
    }
    else
    {
        _159 = false;
    }
    bool _168;
    if (_159)
    {
        float _162 = _153.y;
        bool _167;
        if (_162 >= 0.0)
        {
            _167 = _162 <= 1.0;
        }
        else
        {
            _167 = false;
        }
        _168 = _167;
    }
    else
    {
        _168 = false;
    }
    uint2 _179 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _185 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _202;
    if (_168)
    {
        _202 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _202 = true;
    }
    float4 _206 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _133, _139)) / _142), level(0.0));
    float _208 = fast::clamp(_206.x, 0.0, 1.0);
    float _210 = fast::clamp(_206.y, 0.0, 1.0);
    float _212 = fast::clamp(_206.z, 0.0, 1.0);
    float _214 = fast::clamp(_206.w, 0.0, 1.0);
    float _219 = _214 * float(rint(_214 * 100.0) > 1.0);
    bool _223;
    if (_168)
    {
        _223 = !_202;
    }
    else
    {
        _223 = false;
    }
    float3 _820;
    float _821;
    if (_223)
    {
        float2 _227 = (_153 * _127) - float2(0.5);
        half2 _230 = half2(_227 - floor(_227));
        int2 _243 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _227.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _227.y)))));
        int2 _244 = _243 + int2(-1);
        int _246 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _250 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _258 = _243 + int2(0, -1);
        int2 _270 = _243 + int2(1, -1);
        int2 _282 = _243 + int2(2, -1);
        int2 _294 = _243 + int2(-1, 0);
        half4 _316 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_243.x, _246)), max(1, min(_243.y, _250))))), 0u));
        int2 _317 = _243 + int2(1, 0);
        half4 _328 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_317.x, _246)), max(1, min(_317.y, _250))))), 0u));
        int2 _329 = _243 + int2(2, 0);
        int2 _341 = _243 + int2(-1, 1);
        int2 _353 = _243 + int2(0, 1);
        half4 _364 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_353.x, _246)), max(1, min(_353.y, _250))))), 0u));
        int2 _365 = _243 + int2(1);
        half4 _376 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_365.x, _246)), max(1, min(_365.y, _250))))), 0u));
        int2 _377 = _243 + int2(2, 1);
        int2 _389 = _243 + int2(-1, 2);
        int2 _401 = _243 + int2(0, 2);
        int2 _413 = _243 + int2(1, 2);
        int2 _425 = _243 + int2(2);
        half _437 = _230.x;
        float _441 = float(min(abs(half(-1.0) - _437), half(2.0)));
        bool _443 = abs(_441) < 6.099999882280826568603515625e-05;
        float _454;
        if (_443)
        {
            _454 = 1.0;
        }
        else
        {
            float _447 = 3.1415927410125732421875 * _441;
            float _450 = 1.57079637050628662109375 * _441;
            _454 = (sin(_447) / _447) * (sin(_450) / _450);
        }
        half _455 = half(_454);
        float _459 = float(min(abs(half(-0.0) - _437), half(2.0)));
        bool _461 = abs(_459) < 6.099999882280826568603515625e-05;
        float _472;
        if (_461)
        {
            _472 = 1.0;
        }
        else
        {
            float _465 = 3.1415927410125732421875 * _459;
            float _468 = 1.57079637050628662109375 * _459;
            _472 = (sin(_465) / _465) * (sin(_468) / _468);
        }
        half _473 = half(_472);
        float _477 = float(min(abs(half(1.0) - _437), half(2.0)));
        bool _479 = abs(_477) < 6.099999882280826568603515625e-05;
        float _490;
        if (_479)
        {
            _490 = 1.0;
        }
        else
        {
            float _483 = 3.1415927410125732421875 * _477;
            float _486 = 1.57079637050628662109375 * _477;
            _490 = (sin(_483) / _483) * (sin(_486) / _486);
        }
        half _491 = half(_490);
        float _495 = float(min(abs(half(2.0) - _437), half(2.0)));
        bool _497 = abs(_495) < 6.099999882280826568603515625e-05;
        float _508;
        if (_497)
        {
            _508 = 1.0;
        }
        else
        {
            float _501 = 3.1415927410125732421875 * _495;
            float _504 = 1.57079637050628662109375 * _495;
            _508 = (sin(_501) / _501) * (sin(_504) / _504);
        }
        half _509 = half(_508);
        float _532;
        if (_443)
        {
            _532 = 1.0;
        }
        else
        {
            float _525 = 3.1415927410125732421875 * _441;
            float _528 = 1.57079637050628662109375 * _441;
            _532 = (sin(_525) / _525) * (sin(_528) / _528);
        }
        half _533 = half(_532);
        float _544;
        if (_461)
        {
            _544 = 1.0;
        }
        else
        {
            float _537 = 3.1415927410125732421875 * _459;
            float _540 = 1.57079637050628662109375 * _459;
            _544 = (sin(_537) / _537) * (sin(_540) / _540);
        }
        half _545 = half(_544);
        float _556;
        if (_479)
        {
            _556 = 1.0;
        }
        else
        {
            float _549 = 3.1415927410125732421875 * _477;
            float _552 = 1.57079637050628662109375 * _477;
            _556 = (sin(_549) / _549) * (sin(_552) / _552);
        }
        half _557 = half(_556);
        float _568;
        if (_497)
        {
            _568 = 1.0;
        }
        else
        {
            float _561 = 3.1415927410125732421875 * _495;
            float _564 = 1.57079637050628662109375 * _495;
            _568 = (sin(_561) / _561) * (sin(_564) / _564);
        }
        half _569 = half(_568);
        float _592;
        if (_443)
        {
            _592 = 1.0;
        }
        else
        {
            float _585 = 3.1415927410125732421875 * _441;
            float _588 = 1.57079637050628662109375 * _441;
            _592 = (sin(_585) / _585) * (sin(_588) / _588);
        }
        half _593 = half(_592);
        float _604;
        if (_461)
        {
            _604 = 1.0;
        }
        else
        {
            float _597 = 3.1415927410125732421875 * _459;
            float _600 = 1.57079637050628662109375 * _459;
            _604 = (sin(_597) / _597) * (sin(_600) / _600);
        }
        half _605 = half(_604);
        float _616;
        if (_479)
        {
            _616 = 1.0;
        }
        else
        {
            float _609 = 3.1415927410125732421875 * _477;
            float _612 = 1.57079637050628662109375 * _477;
            _616 = (sin(_609) / _609) * (sin(_612) / _612);
        }
        half _617 = half(_616);
        float _628;
        if (_497)
        {
            _628 = 1.0;
        }
        else
        {
            float _621 = 3.1415927410125732421875 * _495;
            float _624 = 1.57079637050628662109375 * _495;
            _628 = (sin(_621) / _621) * (sin(_624) / _624);
        }
        half _629 = half(_628);
        float _652;
        if (_443)
        {
            _652 = 1.0;
        }
        else
        {
            float _645 = 3.1415927410125732421875 * _441;
            float _648 = 1.57079637050628662109375 * _441;
            _652 = (sin(_645) / _645) * (sin(_648) / _648);
        }
        half _653 = half(_652);
        float _664;
        if (_461)
        {
            _664 = 1.0;
        }
        else
        {
            float _657 = 3.1415927410125732421875 * _459;
            float _660 = 1.57079637050628662109375 * _459;
            _664 = (sin(_657) / _657) * (sin(_660) / _660);
        }
        half _665 = half(_664);
        float _676;
        if (_479)
        {
            _676 = 1.0;
        }
        else
        {
            float _669 = 3.1415927410125732421875 * _477;
            float _672 = 1.57079637050628662109375 * _477;
            _676 = (sin(_669) / _669) * (sin(_672) / _672);
        }
        half _677 = half(_676);
        float _688;
        if (_497)
        {
            _688 = 1.0;
        }
        else
        {
            float _681 = 3.1415927410125732421875 * _495;
            float _684 = 1.57079637050628662109375 * _495;
            _688 = (sin(_681) / _681) * (sin(_684) / _684);
        }
        half _689 = half(_688);
        half _702 = _230.y;
        float _706 = float(min(abs(half(-1.0) - _702), half(2.0)));
        float _719;
        if (abs(_706) < 6.099999882280826568603515625e-05)
        {
            _719 = 1.0;
        }
        else
        {
            float _712 = 3.1415927410125732421875 * _706;
            float _715 = 1.57079637050628662109375 * _706;
            _719 = (sin(_712) / _712) * (sin(_715) / _715);
        }
        half _720 = half(_719);
        float _724 = float(min(abs(half(-0.0) - _702), half(2.0)));
        float _737;
        if (abs(_724) < 6.099999882280826568603515625e-05)
        {
            _737 = 1.0;
        }
        else
        {
            float _730 = 3.1415927410125732421875 * _724;
            float _733 = 1.57079637050628662109375 * _724;
            _737 = (sin(_730) / _730) * (sin(_733) / _733);
        }
        half _738 = half(_737);
        float _742 = float(min(abs(half(1.0) - _702), half(2.0)));
        float _755;
        if (abs(_742) < 6.099999882280826568603515625e-05)
        {
            _755 = 1.0;
        }
        else
        {
            float _748 = 3.1415927410125732421875 * _742;
            float _751 = 1.57079637050628662109375 * _742;
            _755 = (sin(_748) / _748) * (sin(_751) / _751);
        }
        half _756 = half(_755);
        float _760 = float(min(abs(half(2.0) - _702), half(2.0)));
        float _773;
        if (abs(_760) < 6.099999882280826568603515625e-05)
        {
            _773 = 1.0;
        }
        else
        {
            float _766 = 3.1415927410125732421875 * _760;
            float _769 = 1.57079637050628662109375 * _760;
            _773 = (sin(_766) / _766) * (sin(_769) / _769);
        }
        half _774 = half(_773);
        half4 _779 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_244.x, _246)), max(1, min(_244.y, _250))))), 0u)) * _455) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_258.x, _246)), max(1, min(_258.y, _250))))), 0u)) * _473)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_270.x, _246)), max(1, min(_270.y, _250))))), 0u)) * _491)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_282.x, _246)), max(1, min(_282.y, _250))))), 0u)) * _509)) / half4(((_455 + _473) + _491) + _509)) * _720) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_294.x, _246)), max(1, min(_294.y, _250))))), 0u)) * _533) + (_316 * _545)) + (_328 * _557)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_329.x, _246)), max(1, min(_329.y, _250))))), 0u)) * _569)) / half4(((_533 + _545) + _557) + _569)) * _738)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_341.x, _246)), max(1, min(_341.y, _250))))), 0u)) * _593) + (_364 * _605)) + (_376 * _617)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_377.x, _246)), max(1, min(_377.y, _250))))), 0u)) * _629)) / half4(((_593 + _605) + _617) + _629)) * _756);
        half4 _786 = (_779 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_389.x, _246)), max(1, min(_389.y, _250))))), 0u)) * _653) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_401.x, _246)), max(1, min(_401.y, _250))))), 0u)) * _665)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_413.x, _246)), max(1, min(_413.y, _250))))), 0u)) * _677)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_425.x, _246)), max(1, min(_425.y, _250))))), 0u)) * _689)) / half4(((_653 + _665) + _677) + _689)) * _774)) / half4(((_720 + _738) + _756) + _774);
        float4 _794 = float4(clamp(_786, min(min(min(_316, _328), _364), _376), max(max(max(_316, _328), _364), _376)));
        float4 _800 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _801 = _800.x;
        float3 _804 = (_794.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_801 == 0.0) ? 1.0 : _801);
        float _808 = 0.5 * _804.y;
        float _811 = 0.25 * _804.z;
        _820 = float3(((0.25 * _804.x) + _808) + _811, 0.5 * (_804.x - _804.z), (((-0.25) * _804.x) + _808) - _811);
        _821 = _794.w;
    }
    else
    {
        _820 = float3(0.0);
        _821 = 0.0;
    }
    float _827 = precise::max(fast::clamp(_212, 0.0, 1.0), precise::max(_208, _210));
    float _830 = precise::max(0.0, (_821 * float(!_202)) - (_827 * 2.0));
    uint2 _834 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _851 = _128 - _150;
    float _852 = _851.x;
    bool _857;
    if (_852 >= 0.0)
    {
        _857 = _852 <= 1.0;
    }
    else
    {
        _857 = false;
    }
    bool _866;
    if (_857)
    {
        float _860 = _851.y;
        bool _865;
        if (_860 >= 0.0)
        {
            _865 = _860 <= 1.0;
        }
        else
        {
            _865 = false;
        }
        _866 = _865;
    }
    else
    {
        _866 = false;
    }
    float _876 = precise::min(_219, mix(_219, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_152 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _879 = _124 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _881 = int2(floor(_879));
    float2 _884 = (float2(_881) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _885 = _884 - _879;
    bool _888 = _884.x > _879.x;
    bool _892 = _884.y > _879.y;
    int2 _894 = int2(_888 ? (-2) : (-1), _892 ? (-2) : (-1));
    float2 _895 = float2(_894);
    bool _896 = _219 == 0.0;
    int _897 = _888 ? 3 : 0;
    int _898 = _892 ? 3 : 0;
    int2 _899 = int2(_897, _898);
    int2 _900 = _881 + _894;
    int2 _901 = _900 + _899;
    int _904 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _909 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _919 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _920 = _919.x;
    float3 _923 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_901.x, _904)), max(0, min(_901.y, _909))))), 0u).xyz) * ((_920 == 0.0) ? 1.0 : _920);
    float _924 = _923.x;
    float _927 = 0.5 * _923.y;
    float _929 = _923.z;
    float _930 = 0.25 * _929;
    float3 _937 = float3(((0.25 * _924) + _927) + _930, 0.5 * (_924 - _929), (((-0.25) * _924) + _927) - _930);
    int _938 = _888 ? 2 : 1;
    int2 _939 = int2(_938, _898);
    int2 _940 = _900 + _939;
    float4 _954 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _955 = _954.x;
    float3 _958 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_940.x, _904)), max(0, min(_940.y, _909))))), 0u).xyz) * ((_955 == 0.0) ? 1.0 : _955);
    float _959 = _958.x;
    float _962 = 0.5 * _958.y;
    float _964 = _958.z;
    float _965 = 0.25 * _964;
    float3 _972 = float3(((0.25 * _959) + _962) + _965, 0.5 * (_959 - _964), (((-0.25) * _959) + _962) - _965);
    int _973 = _888 ? 1 : 2;
    int2 _974 = int2(_973, _898);
    int2 _975 = _900 + _974;
    float4 _989 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _990 = _989.x;
    float3 _993 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_975.x, _904)), max(0, min(_975.y, _909))))), 0u).xyz) * ((_990 == 0.0) ? 1.0 : _990);
    float _994 = _993.x;
    float _997 = 0.5 * _993.y;
    float _999 = _993.z;
    float _1000 = 0.25 * _999;
    float3 _1007 = float3(((0.25 * _994) + _997) + _1000, 0.5 * (_994 - _999), (((-0.25) * _994) + _997) - _1000);
    int _1008 = _892 ? 2 : 1;
    int2 _1009 = int2(_897, _1008);
    int2 _1010 = _900 + _1009;
    float4 _1024 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1025 = _1024.x;
    float3 _1028 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1010.x, _904)), max(0, min(_1010.y, _909))))), 0u).xyz) * ((_1025 == 0.0) ? 1.0 : _1025);
    float _1029 = _1028.x;
    float _1032 = 0.5 * _1028.y;
    float _1034 = _1028.z;
    float _1035 = 0.25 * _1034;
    float3 _1042 = float3(((0.25 * _1029) + _1032) + _1035, 0.5 * (_1029 - _1034), (((-0.25) * _1029) + _1032) - _1035);
    int2 _1043 = int2(_938, _1008);
    int2 _1044 = _900 + _1043;
    float4 _1058 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1059 = _1058.x;
    float3 _1062 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1044.x, _904)), max(0, min(_1044.y, _909))))), 0u).xyz) * ((_1059 == 0.0) ? 1.0 : _1059);
    float _1063 = _1062.x;
    float _1066 = 0.5 * _1062.y;
    float _1068 = _1062.z;
    float _1069 = 0.25 * _1068;
    float3 _1076 = float3(((0.25 * _1063) + _1066) + _1069, 0.5 * (_1063 - _1068), (((-0.25) * _1063) + _1066) - _1069);
    int2 _1077 = int2(_973, _1008);
    int2 _1078 = _900 + _1077;
    float4 _1092 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1093 = _1092.x;
    float3 _1096 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1078.x, _904)), max(0, min(_1078.y, _909))))), 0u).xyz) * ((_1093 == 0.0) ? 1.0 : _1093);
    float _1097 = _1096.x;
    float _1100 = 0.5 * _1096.y;
    float _1102 = _1096.z;
    float _1103 = 0.25 * _1102;
    float3 _1110 = float3(((0.25 * _1097) + _1100) + _1103, 0.5 * (_1097 - _1102), (((-0.25) * _1097) + _1100) - _1103);
    int _1111 = _892 ? 1 : 2;
    int2 _1112 = int2(_897, _1111);
    int2 _1113 = _900 + _1112;
    float4 _1127 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1128 = _1127.x;
    float3 _1131 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1113.x, _904)), max(0, min(_1113.y, _909))))), 0u).xyz) * ((_1128 == 0.0) ? 1.0 : _1128);
    float _1132 = _1131.x;
    float _1135 = 0.5 * _1131.y;
    float _1137 = _1131.z;
    float _1138 = 0.25 * _1137;
    float3 _1145 = float3(((0.25 * _1132) + _1135) + _1138, 0.5 * (_1132 - _1137), (((-0.25) * _1132) + _1135) - _1138);
    int2 _1146 = int2(_938, _1111);
    int2 _1147 = _900 + _1146;
    float4 _1161 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1162 = _1161.x;
    float3 _1165 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1147.x, _904)), max(0, min(_1147.y, _909))))), 0u).xyz) * ((_1162 == 0.0) ? 1.0 : _1162);
    float _1166 = _1165.x;
    float _1169 = 0.5 * _1165.y;
    float _1171 = _1165.z;
    float _1172 = 0.25 * _1171;
    float3 _1179 = float3(((0.25 * _1166) + _1169) + _1172, 0.5 * (_1166 - _1171), (((-0.25) * _1166) + _1169) - _1172);
    int2 _1180 = int2(_973, _1111);
    int2 _1181 = _900 + _1180;
    float4 _1195 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1196 = _1195.x;
    float3 _1199 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1181.x, _904)), max(0, min(_1181.y, _909))))), 0u).xyz) * ((_1196 == 0.0) ? 1.0 : _1196);
    float _1200 = _1199.x;
    float _1203 = 0.5 * _1199.y;
    float _1205 = _1199.z;
    float _1206 = 0.25 * _1205;
    float3 _1213 = float3(((0.25 * _1200) + _1203) + _1206, 0.5 * (_1200 - _1205), (((-0.25) * _1200) + _1203) - _1206);
    float _1218 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1229 = mix(precise::max(1.0, (1.0 + _1218) * 0.300000011920928955078125), _1218, precise::min(1.0 - (_210 * 0.5), precise::min(1.0 - _212, fast::clamp(_876 * 5.0, 0.0, 1.0))));
    float2 _1232 = _885 + (_895 + float2(_899));
    uint2 _1234 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1237 = float(all(uint2(_901) < _1234));
    bool _1238 = !_896;
    float _1256;
    float3 _1257;
    if (_1238)
    {
        float2 _1242 = _1232 * float2(_1229);
        float _1244 = precise::min(dot(_1242, _1242), 4.0);
        float _1246 = (0.4000000059604644775390625 * _1244) - 1.0;
        float _1248 = (0.25 * _1244) - 1.0;
        float _1254 = _1237 * ((((1.5625 * _1246) * _1246) - 0.5625) * (_1248 * _1248));
        _1256 = _1254;
        _1257 = _937 * _1254;
    }
    else
    {
        _1256 = 0.0;
        _1257 = float3(0.0);
    }
    float _1261 = exp((-2.2999999523162841796875) * dot(_1232, _1232)) * _1237;
    float3 _1262 = _937 * _1261;
    float2 _1266 = _885 + (_895 + float2(_939));
    float _1270 = float(all(uint2(_940) < _1234));
    float _1290;
    float3 _1291;
    if (_1238)
    {
        float2 _1274 = _1266 * float2(_1229);
        float _1276 = precise::min(dot(_1274, _1274), 4.0);
        float _1278 = (0.4000000059604644775390625 * _1276) - 1.0;
        float _1280 = (0.25 * _1276) - 1.0;
        float _1286 = _1270 * ((((1.5625 * _1278) * _1278) - 0.5625) * (_1280 * _1280));
        _1290 = _1256 + _1286;
        _1291 = _1257 + (_972 * _1286);
    }
    else
    {
        _1290 = _1256;
        _1291 = _1257;
    }
    float _1295 = exp((-2.2999999523162841796875) * dot(_1266, _1266)) * _1270;
    float3 _1298 = _972 * _1295;
    float2 _1305 = _885 + (_895 + float2(_974));
    float _1309 = float(all(uint2(_975) < _1234));
    float _1329;
    float3 _1330;
    if (_1238)
    {
        float2 _1313 = _1305 * float2(_1229);
        float _1315 = precise::min(dot(_1313, _1313), 4.0);
        float _1317 = (0.4000000059604644775390625 * _1315) - 1.0;
        float _1319 = (0.25 * _1315) - 1.0;
        float _1325 = _1309 * ((((1.5625 * _1317) * _1317) - 0.5625) * (_1319 * _1319));
        _1329 = _1290 + _1325;
        _1330 = _1291 + (_1007 * _1325);
    }
    else
    {
        _1329 = _1290;
        _1330 = _1291;
    }
    float _1334 = exp((-2.2999999523162841796875) * dot(_1305, _1305)) * _1309;
    float3 _1337 = _1007 * _1334;
    float2 _1344 = _885 + (_895 + float2(_1009));
    float _1348 = float(all(uint2(_1010) < _1234));
    float _1368;
    float3 _1369;
    if (_1238)
    {
        float2 _1352 = _1344 * float2(_1229);
        float _1354 = precise::min(dot(_1352, _1352), 4.0);
        float _1356 = (0.4000000059604644775390625 * _1354) - 1.0;
        float _1358 = (0.25 * _1354) - 1.0;
        float _1364 = _1348 * ((((1.5625 * _1356) * _1356) - 0.5625) * (_1358 * _1358));
        _1368 = _1329 + _1364;
        _1369 = _1330 + (_1042 * _1364);
    }
    else
    {
        _1368 = _1329;
        _1369 = _1330;
    }
    float _1373 = exp((-2.2999999523162841796875) * dot(_1344, _1344)) * _1348;
    float3 _1376 = _1042 * _1373;
    float2 _1383 = _885 + (_895 + float2(_1043));
    float _1387 = float(all(uint2(_1044) < _1234));
    float _1407;
    float3 _1408;
    if (_1238)
    {
        float2 _1391 = _1383 * float2(_1229);
        float _1393 = precise::min(dot(_1391, _1391), 4.0);
        float _1395 = (0.4000000059604644775390625 * _1393) - 1.0;
        float _1397 = (0.25 * _1393) - 1.0;
        float _1403 = _1387 * ((((1.5625 * _1395) * _1395) - 0.5625) * (_1397 * _1397));
        _1407 = _1368 + _1403;
        _1408 = _1369 + (_1076 * _1403);
    }
    else
    {
        _1407 = _1368;
        _1408 = _1369;
    }
    float _1412 = exp((-2.2999999523162841796875) * dot(_1383, _1383)) * _1387;
    float3 _1415 = _1076 * _1412;
    float2 _1422 = _885 + (_895 + float2(_1077));
    float _1426 = float(all(uint2(_1078) < _1234));
    float _1446;
    float3 _1447;
    if (_1238)
    {
        float2 _1430 = _1422 * float2(_1229);
        float _1432 = precise::min(dot(_1430, _1430), 4.0);
        float _1434 = (0.4000000059604644775390625 * _1432) - 1.0;
        float _1436 = (0.25 * _1432) - 1.0;
        float _1442 = _1426 * ((((1.5625 * _1434) * _1434) - 0.5625) * (_1436 * _1436));
        _1446 = _1407 + _1442;
        _1447 = _1408 + (_1110 * _1442);
    }
    else
    {
        _1446 = _1407;
        _1447 = _1408;
    }
    float _1451 = exp((-2.2999999523162841796875) * dot(_1422, _1422)) * _1426;
    float3 _1454 = _1110 * _1451;
    float2 _1461 = _885 + (_895 + float2(_1112));
    float _1465 = float(all(uint2(_1113) < _1234));
    float _1485;
    float3 _1486;
    if (_1238)
    {
        float2 _1469 = _1461 * float2(_1229);
        float _1471 = precise::min(dot(_1469, _1469), 4.0);
        float _1473 = (0.4000000059604644775390625 * _1471) - 1.0;
        float _1475 = (0.25 * _1471) - 1.0;
        float _1481 = _1465 * ((((1.5625 * _1473) * _1473) - 0.5625) * (_1475 * _1475));
        _1485 = _1446 + _1481;
        _1486 = _1447 + (_1145 * _1481);
    }
    else
    {
        _1485 = _1446;
        _1486 = _1447;
    }
    float _1490 = exp((-2.2999999523162841796875) * dot(_1461, _1461)) * _1465;
    float3 _1493 = _1145 * _1490;
    float2 _1500 = _885 + (_895 + float2(_1146));
    float _1504 = float(all(uint2(_1147) < _1234));
    float _1524;
    float3 _1525;
    if (_1238)
    {
        float2 _1508 = _1500 * float2(_1229);
        float _1510 = precise::min(dot(_1508, _1508), 4.0);
        float _1512 = (0.4000000059604644775390625 * _1510) - 1.0;
        float _1514 = (0.25 * _1510) - 1.0;
        float _1520 = _1504 * ((((1.5625 * _1512) * _1512) - 0.5625) * (_1514 * _1514));
        _1524 = _1485 + _1520;
        _1525 = _1486 + (_1179 * _1520);
    }
    else
    {
        _1524 = _1485;
        _1525 = _1486;
    }
    float _1529 = exp((-2.2999999523162841796875) * dot(_1500, _1500)) * _1504;
    float3 _1532 = _1179 * _1529;
    float2 _1539 = _885 + (_895 + float2(_1180));
    float _1543 = float(all(uint2(_1181) < _1234));
    float _1563;
    float3 _1564;
    if (_1238)
    {
        float2 _1547 = _1539 * float2(_1229);
        float _1549 = precise::min(dot(_1547, _1547), 4.0);
        float _1551 = (0.4000000059604644775390625 * _1549) - 1.0;
        float _1553 = (0.25 * _1549) - 1.0;
        float _1559 = _1543 * ((((1.5625 * _1551) * _1551) - 0.5625) * (_1553 * _1553));
        _1563 = _1524 + _1559;
        _1564 = _1525 + (_1213 * _1559);
    }
    else
    {
        _1563 = _1524;
        _1564 = _1525;
    }
    float _1568 = exp((-2.2999999523162841796875) * dot(_1539, _1539)) * _1543;
    float3 _1571 = _1213 * _1568;
    float _1575 = (((((((_1261 + _1295) + _1334) + _1373) + _1412) + _1451) + _1490) + _1529) + _1568;
    float3 _1579 = float3((abs(_1575) > 1.1754943508222875079687365372222e-38) ? _1575 : 1.0);
    float3 _1580 = ((((((((_1262 + _1298) + _1337) + _1376) + _1415) + _1454) + _1493) + _1532) + _1571) / _1579;
    float _1588 = _1563 * float(_1563 > 6.099999882280826568603515625e-05);
    float3 _1596;
    float _1597;
    if (_1588 > 6.099999882280826568603515625e-05)
    {
        _1596 = fast::clamp(_1564 / float3(_1588), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_937, _972), _1007), _1042), _1076), _1110), _1145), _1179), _1213), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_937, _972), _1007), _1042), _1076), _1110), _1145), _1179), _1213));
        _1597 = _1588 * 0.04625000059604644775390625;
    }
    else
    {
        _1596 = _1564;
        _1597 = _1588;
    }
    float _1600 = _896 ? 1.0 : _1597;
    float _1601 = _896 ? 0.0 : _876;
    float3 _1615 = (sqrt(abs(((((((((((_937 * _1262) + (_972 * _1298)) + (_1007 * _1337)) + (_1042 * _1376)) + (_1076 * _1415)) + (_1110 * _1454)) + (_1145 * _1493)) + (_1179 * _1532)) + (_1213 * _1571)) / _1579) - (_1580 * _1580))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_152 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _185, _185 - float2(0.5))) / float2(int2(int(_179.x), int(_179.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _219, precise::max(powr(_208, 0.5), _212)))));
    float3 _1618 = (_820 - _1580) / precise::max(_1615, float3(1.19299997436428384389728307724e-07));
    float3 _1633;
    if (length(_1618) > 1.0)
    {
        _1633 = mix((fast::normalize(_1618) * _1615) + _1580, _820, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_144, _139)) / _142), level(0.0)).x, fast::clamp(fast::clamp(_830 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _219) * (1.0 - _210), 0.0, 1.0)));
    }
    else
    {
        _1633 = _820;
    }
    float3 _1642 = mix(_1633, select(_1596, _1580, bool3(_896)), float3(fast::clamp(_1600 / precise::max(6.099999882280826568603515625e-05, (_1601 * float(_1601 > 6.099999882280826568603515625e-05)) + _1600), 0.0, 1.0)));
    float _1643 = _1642.x;
    float _1644 = _1642.y;
    float _1646 = _1642.z;
    float4 _1653 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1654 = _1653.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max(float3((_1643 + _1644) - _1646, _1643 + _1646, (_1643 - _1644) - _1646) / float3((_1654 == 0.0) ? 1.0 : _1654), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_830 + (sdk_hlsl_load(rw_new_locks, uint2(_834)).x * (1.0 - precise::max(0.0, _208))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _827))) * float(_866)), uint2(_834));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_834));
}

