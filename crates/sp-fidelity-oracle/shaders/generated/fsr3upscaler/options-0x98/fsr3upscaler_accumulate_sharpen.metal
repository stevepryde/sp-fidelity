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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(3)]], texture2d<float, access::write> rw_upscaled_output [[texture(4)]], texture2d<float> r_farthest_depth_mip1 [[texture(5)]], texture2d<float> r_luma_instability [[texture(6)]], texture2d<float, access::read_write> rw_new_locks [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _127 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _130 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _131 = _127 / _130;
    float2 _136 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _138 = _131 + (cbFSR3Upscaler.fJitter / _136);
    float2 _142 = _136 - float2(0.5);
    float2 _145 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _147 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _156 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_147), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _158 = length(_156 * float2(3840.0, 2160.0));
    float2 _159 = _131 + _156;
    float _160 = _159.x;
    bool _165;
    if (_160 >= 0.0)
    {
        _165 = _160 <= 1.0;
    }
    else
    {
        _165 = false;
    }
    bool _174;
    if (_165)
    {
        float _168 = _159.y;
        bool _173;
        if (_168 >= 0.0)
        {
            _173 = _168 <= 1.0;
        }
        else
        {
            _173 = false;
        }
        _174 = _173;
    }
    else
    {
        _174 = false;
    }
    uint2 _186 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _192 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _209;
    if (_174)
    {
        _209 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _209 = true;
    }
    float4 _213 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _136, _142)) / _145), level(0.0));
    float _215 = fast::clamp(_213.x, 0.0, 1.0);
    float _217 = fast::clamp(_213.y, 0.0, 1.0);
    float _219 = fast::clamp(_213.z, 0.0, 1.0);
    float _221 = fast::clamp(_213.w, 0.0, 1.0);
    float _226 = _221 * float(rint(_221 * 100.0) > 1.0);
    bool _230;
    if (_174)
    {
        _230 = !_209;
    }
    else
    {
        _230 = false;
    }
    float3 _827;
    float _828;
    if (_230)
    {
        float2 _234 = (_159 * _130) - float2(0.5);
        half2 _237 = half2(_234 - floor(_234));
        int2 _250 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _234.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _234.y)))));
        int2 _251 = _250 + int2(-1);
        int _253 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _257 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _265 = _250 + int2(0, -1);
        int2 _277 = _250 + int2(1, -1);
        int2 _289 = _250 + int2(2, -1);
        int2 _301 = _250 + int2(-1, 0);
        half4 _323 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_250.x, _253)), max(1, min(_250.y, _257))))), 0u));
        int2 _324 = _250 + int2(1, 0);
        half4 _335 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_324.x, _253)), max(1, min(_324.y, _257))))), 0u));
        int2 _336 = _250 + int2(2, 0);
        int2 _348 = _250 + int2(-1, 1);
        int2 _360 = _250 + int2(0, 1);
        half4 _371 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_360.x, _253)), max(1, min(_360.y, _257))))), 0u));
        int2 _372 = _250 + int2(1);
        half4 _383 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_372.x, _253)), max(1, min(_372.y, _257))))), 0u));
        int2 _384 = _250 + int2(2, 1);
        int2 _396 = _250 + int2(-1, 2);
        int2 _408 = _250 + int2(0, 2);
        int2 _420 = _250 + int2(1, 2);
        int2 _432 = _250 + int2(2);
        half _444 = _237.x;
        float _448 = float(min(abs(half(-1.0) - _444), half(2.0)));
        bool _450 = abs(_448) < 6.099999882280826568603515625e-05;
        float _461;
        if (_450)
        {
            _461 = 1.0;
        }
        else
        {
            float _454 = 3.1415927410125732421875 * _448;
            float _457 = 1.57079637050628662109375 * _448;
            _461 = (sin(_454) / _454) * (sin(_457) / _457);
        }
        half _462 = half(_461);
        float _466 = float(min(abs(half(-0.0) - _444), half(2.0)));
        bool _468 = abs(_466) < 6.099999882280826568603515625e-05;
        float _479;
        if (_468)
        {
            _479 = 1.0;
        }
        else
        {
            float _472 = 3.1415927410125732421875 * _466;
            float _475 = 1.57079637050628662109375 * _466;
            _479 = (sin(_472) / _472) * (sin(_475) / _475);
        }
        half _480 = half(_479);
        float _484 = float(min(abs(half(1.0) - _444), half(2.0)));
        bool _486 = abs(_484) < 6.099999882280826568603515625e-05;
        float _497;
        if (_486)
        {
            _497 = 1.0;
        }
        else
        {
            float _490 = 3.1415927410125732421875 * _484;
            float _493 = 1.57079637050628662109375 * _484;
            _497 = (sin(_490) / _490) * (sin(_493) / _493);
        }
        half _498 = half(_497);
        float _502 = float(min(abs(half(2.0) - _444), half(2.0)));
        bool _504 = abs(_502) < 6.099999882280826568603515625e-05;
        float _515;
        if (_504)
        {
            _515 = 1.0;
        }
        else
        {
            float _508 = 3.1415927410125732421875 * _502;
            float _511 = 1.57079637050628662109375 * _502;
            _515 = (sin(_508) / _508) * (sin(_511) / _511);
        }
        half _516 = half(_515);
        float _539;
        if (_450)
        {
            _539 = 1.0;
        }
        else
        {
            float _532 = 3.1415927410125732421875 * _448;
            float _535 = 1.57079637050628662109375 * _448;
            _539 = (sin(_532) / _532) * (sin(_535) / _535);
        }
        half _540 = half(_539);
        float _551;
        if (_468)
        {
            _551 = 1.0;
        }
        else
        {
            float _544 = 3.1415927410125732421875 * _466;
            float _547 = 1.57079637050628662109375 * _466;
            _551 = (sin(_544) / _544) * (sin(_547) / _547);
        }
        half _552 = half(_551);
        float _563;
        if (_486)
        {
            _563 = 1.0;
        }
        else
        {
            float _556 = 3.1415927410125732421875 * _484;
            float _559 = 1.57079637050628662109375 * _484;
            _563 = (sin(_556) / _556) * (sin(_559) / _559);
        }
        half _564 = half(_563);
        float _575;
        if (_504)
        {
            _575 = 1.0;
        }
        else
        {
            float _568 = 3.1415927410125732421875 * _502;
            float _571 = 1.57079637050628662109375 * _502;
            _575 = (sin(_568) / _568) * (sin(_571) / _571);
        }
        half _576 = half(_575);
        float _599;
        if (_450)
        {
            _599 = 1.0;
        }
        else
        {
            float _592 = 3.1415927410125732421875 * _448;
            float _595 = 1.57079637050628662109375 * _448;
            _599 = (sin(_592) / _592) * (sin(_595) / _595);
        }
        half _600 = half(_599);
        float _611;
        if (_468)
        {
            _611 = 1.0;
        }
        else
        {
            float _604 = 3.1415927410125732421875 * _466;
            float _607 = 1.57079637050628662109375 * _466;
            _611 = (sin(_604) / _604) * (sin(_607) / _607);
        }
        half _612 = half(_611);
        float _623;
        if (_486)
        {
            _623 = 1.0;
        }
        else
        {
            float _616 = 3.1415927410125732421875 * _484;
            float _619 = 1.57079637050628662109375 * _484;
            _623 = (sin(_616) / _616) * (sin(_619) / _619);
        }
        half _624 = half(_623);
        float _635;
        if (_504)
        {
            _635 = 1.0;
        }
        else
        {
            float _628 = 3.1415927410125732421875 * _502;
            float _631 = 1.57079637050628662109375 * _502;
            _635 = (sin(_628) / _628) * (sin(_631) / _631);
        }
        half _636 = half(_635);
        float _659;
        if (_450)
        {
            _659 = 1.0;
        }
        else
        {
            float _652 = 3.1415927410125732421875 * _448;
            float _655 = 1.57079637050628662109375 * _448;
            _659 = (sin(_652) / _652) * (sin(_655) / _655);
        }
        half _660 = half(_659);
        float _671;
        if (_468)
        {
            _671 = 1.0;
        }
        else
        {
            float _664 = 3.1415927410125732421875 * _466;
            float _667 = 1.57079637050628662109375 * _466;
            _671 = (sin(_664) / _664) * (sin(_667) / _667);
        }
        half _672 = half(_671);
        float _683;
        if (_486)
        {
            _683 = 1.0;
        }
        else
        {
            float _676 = 3.1415927410125732421875 * _484;
            float _679 = 1.57079637050628662109375 * _484;
            _683 = (sin(_676) / _676) * (sin(_679) / _679);
        }
        half _684 = half(_683);
        float _695;
        if (_504)
        {
            _695 = 1.0;
        }
        else
        {
            float _688 = 3.1415927410125732421875 * _502;
            float _691 = 1.57079637050628662109375 * _502;
            _695 = (sin(_688) / _688) * (sin(_691) / _691);
        }
        half _696 = half(_695);
        half _709 = _237.y;
        float _713 = float(min(abs(half(-1.0) - _709), half(2.0)));
        float _726;
        if (abs(_713) < 6.099999882280826568603515625e-05)
        {
            _726 = 1.0;
        }
        else
        {
            float _719 = 3.1415927410125732421875 * _713;
            float _722 = 1.57079637050628662109375 * _713;
            _726 = (sin(_719) / _719) * (sin(_722) / _722);
        }
        half _727 = half(_726);
        float _731 = float(min(abs(half(-0.0) - _709), half(2.0)));
        float _744;
        if (abs(_731) < 6.099999882280826568603515625e-05)
        {
            _744 = 1.0;
        }
        else
        {
            float _737 = 3.1415927410125732421875 * _731;
            float _740 = 1.57079637050628662109375 * _731;
            _744 = (sin(_737) / _737) * (sin(_740) / _740);
        }
        half _745 = half(_744);
        float _749 = float(min(abs(half(1.0) - _709), half(2.0)));
        float _762;
        if (abs(_749) < 6.099999882280826568603515625e-05)
        {
            _762 = 1.0;
        }
        else
        {
            float _755 = 3.1415927410125732421875 * _749;
            float _758 = 1.57079637050628662109375 * _749;
            _762 = (sin(_755) / _755) * (sin(_758) / _758);
        }
        half _763 = half(_762);
        float _767 = float(min(abs(half(2.0) - _709), half(2.0)));
        float _780;
        if (abs(_767) < 6.099999882280826568603515625e-05)
        {
            _780 = 1.0;
        }
        else
        {
            float _773 = 3.1415927410125732421875 * _767;
            float _776 = 1.57079637050628662109375 * _767;
            _780 = (sin(_773) / _773) * (sin(_776) / _776);
        }
        half _781 = half(_780);
        half4 _786 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_251.x, _253)), max(1, min(_251.y, _257))))), 0u)) * _462) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_265.x, _253)), max(1, min(_265.y, _257))))), 0u)) * _480)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_277.x, _253)), max(1, min(_277.y, _257))))), 0u)) * _498)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_289.x, _253)), max(1, min(_289.y, _257))))), 0u)) * _516)) / half4(((_462 + _480) + _498) + _516)) * _727) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_301.x, _253)), max(1, min(_301.y, _257))))), 0u)) * _540) + (_323 * _552)) + (_335 * _564)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_336.x, _253)), max(1, min(_336.y, _257))))), 0u)) * _576)) / half4(((_540 + _552) + _564) + _576)) * _745)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_348.x, _253)), max(1, min(_348.y, _257))))), 0u)) * _600) + (_371 * _612)) + (_383 * _624)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_384.x, _253)), max(1, min(_384.y, _257))))), 0u)) * _636)) / half4(((_600 + _612) + _624) + _636)) * _763);
        half4 _793 = (_786 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_396.x, _253)), max(1, min(_396.y, _257))))), 0u)) * _660) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_408.x, _253)), max(1, min(_408.y, _257))))), 0u)) * _672)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_420.x, _253)), max(1, min(_420.y, _257))))), 0u)) * _684)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_432.x, _253)), max(1, min(_432.y, _257))))), 0u)) * _696)) / half4(((_660 + _672) + _684) + _696)) * _781)) / half4(((_727 + _745) + _763) + _781);
        float4 _801 = float4(clamp(_793, min(min(min(_323, _335), _371), _383), max(max(max(_323, _335), _371), _383)));
        float4 _807 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _808 = _807.x;
        float3 _811 = (_801.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_808 == 0.0) ? 1.0 : _808);
        float _815 = 0.5 * _811.y;
        float _818 = 0.25 * _811.z;
        _827 = float3(((0.25 * _811.x) + _815) + _818, 0.5 * (_811.x - _811.z), (((-0.25) * _811.x) + _815) - _818);
        _828 = _801.w;
    }
    else
    {
        _827 = float3(0.0);
        _828 = 0.0;
    }
    float _834 = precise::max(fast::clamp(_219, 0.0, 1.0), precise::max(_215, _217));
    float _837 = precise::max(0.0, (_828 * float(!_209)) - (_834 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _857 = _131 - _156;
    float _858 = _857.x;
    bool _863;
    if (_858 >= 0.0)
    {
        _863 = _858 <= 1.0;
    }
    else
    {
        _863 = false;
    }
    bool _872;
    if (_863)
    {
        float _866 = _857.y;
        bool _871;
        if (_866 >= 0.0)
        {
            _871 = _866 <= 1.0;
        }
        else
        {
            _871 = false;
        }
        _872 = _871;
    }
    else
    {
        _872 = false;
    }
    float _882 = precise::min(_226, mix(_226, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_158 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _885 = _127 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _887 = int2(floor(_885));
    float2 _890 = (float2(_887) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _891 = _890 - _885;
    bool _894 = _890.x > _885.x;
    bool _898 = _890.y > _885.y;
    int2 _900 = int2(_894 ? (-2) : (-1), _898 ? (-2) : (-1));
    float2 _901 = float2(_900);
    bool _902 = _226 == 0.0;
    int _903 = _894 ? 3 : 0;
    int _904 = _898 ? 3 : 0;
    int2 _905 = int2(_903, _904);
    int2 _906 = _887 + _900;
    int2 _907 = _906 + _905;
    int _910 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _915 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _925 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _926 = _925.x;
    float3 _929 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_907.x, _910)), max(0, min(_907.y, _915))))), 0u).xyz) * ((_926 == 0.0) ? 1.0 : _926);
    float _930 = _929.x;
    float _933 = 0.5 * _929.y;
    float _935 = _929.z;
    float _936 = 0.25 * _935;
    float3 _943 = float3(((0.25 * _930) + _933) + _936, 0.5 * (_930 - _935), (((-0.25) * _930) + _933) - _936);
    int _944 = _894 ? 2 : 1;
    int2 _945 = int2(_944, _904);
    int2 _946 = _906 + _945;
    float4 _960 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _961 = _960.x;
    float3 _964 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_946.x, _910)), max(0, min(_946.y, _915))))), 0u).xyz) * ((_961 == 0.0) ? 1.0 : _961);
    float _965 = _964.x;
    float _968 = 0.5 * _964.y;
    float _970 = _964.z;
    float _971 = 0.25 * _970;
    float3 _978 = float3(((0.25 * _965) + _968) + _971, 0.5 * (_965 - _970), (((-0.25) * _965) + _968) - _971);
    int _979 = _894 ? 1 : 2;
    int2 _980 = int2(_979, _904);
    int2 _981 = _906 + _980;
    float4 _995 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _996 = _995.x;
    float3 _999 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_981.x, _910)), max(0, min(_981.y, _915))))), 0u).xyz) * ((_996 == 0.0) ? 1.0 : _996);
    float _1000 = _999.x;
    float _1003 = 0.5 * _999.y;
    float _1005 = _999.z;
    float _1006 = 0.25 * _1005;
    float3 _1013 = float3(((0.25 * _1000) + _1003) + _1006, 0.5 * (_1000 - _1005), (((-0.25) * _1000) + _1003) - _1006);
    int _1014 = _898 ? 2 : 1;
    int2 _1015 = int2(_903, _1014);
    int2 _1016 = _906 + _1015;
    float4 _1030 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1031 = _1030.x;
    float3 _1034 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1016.x, _910)), max(0, min(_1016.y, _915))))), 0u).xyz) * ((_1031 == 0.0) ? 1.0 : _1031);
    float _1035 = _1034.x;
    float _1038 = 0.5 * _1034.y;
    float _1040 = _1034.z;
    float _1041 = 0.25 * _1040;
    float3 _1048 = float3(((0.25 * _1035) + _1038) + _1041, 0.5 * (_1035 - _1040), (((-0.25) * _1035) + _1038) - _1041);
    int2 _1049 = int2(_944, _1014);
    int2 _1050 = _906 + _1049;
    float4 _1064 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1065 = _1064.x;
    float3 _1068 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1050.x, _910)), max(0, min(_1050.y, _915))))), 0u).xyz) * ((_1065 == 0.0) ? 1.0 : _1065);
    float _1069 = _1068.x;
    float _1072 = 0.5 * _1068.y;
    float _1074 = _1068.z;
    float _1075 = 0.25 * _1074;
    float3 _1082 = float3(((0.25 * _1069) + _1072) + _1075, 0.5 * (_1069 - _1074), (((-0.25) * _1069) + _1072) - _1075);
    int2 _1083 = int2(_979, _1014);
    int2 _1084 = _906 + _1083;
    float4 _1098 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1099 = _1098.x;
    float3 _1102 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1084.x, _910)), max(0, min(_1084.y, _915))))), 0u).xyz) * ((_1099 == 0.0) ? 1.0 : _1099);
    float _1103 = _1102.x;
    float _1106 = 0.5 * _1102.y;
    float _1108 = _1102.z;
    float _1109 = 0.25 * _1108;
    float3 _1116 = float3(((0.25 * _1103) + _1106) + _1109, 0.5 * (_1103 - _1108), (((-0.25) * _1103) + _1106) - _1109);
    int _1117 = _898 ? 1 : 2;
    int2 _1118 = int2(_903, _1117);
    int2 _1119 = _906 + _1118;
    float4 _1133 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1134 = _1133.x;
    float3 _1137 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1119.x, _910)), max(0, min(_1119.y, _915))))), 0u).xyz) * ((_1134 == 0.0) ? 1.0 : _1134);
    float _1138 = _1137.x;
    float _1141 = 0.5 * _1137.y;
    float _1143 = _1137.z;
    float _1144 = 0.25 * _1143;
    float3 _1151 = float3(((0.25 * _1138) + _1141) + _1144, 0.5 * (_1138 - _1143), (((-0.25) * _1138) + _1141) - _1144);
    int2 _1152 = int2(_944, _1117);
    int2 _1153 = _906 + _1152;
    float4 _1167 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1168 = _1167.x;
    float3 _1171 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1153.x, _910)), max(0, min(_1153.y, _915))))), 0u).xyz) * ((_1168 == 0.0) ? 1.0 : _1168);
    float _1172 = _1171.x;
    float _1175 = 0.5 * _1171.y;
    float _1177 = _1171.z;
    float _1178 = 0.25 * _1177;
    float3 _1185 = float3(((0.25 * _1172) + _1175) + _1178, 0.5 * (_1172 - _1177), (((-0.25) * _1172) + _1175) - _1178);
    int2 _1186 = int2(_979, _1117);
    int2 _1187 = _906 + _1186;
    float4 _1201 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1202 = _1201.x;
    float3 _1205 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1187.x, _910)), max(0, min(_1187.y, _915))))), 0u).xyz) * ((_1202 == 0.0) ? 1.0 : _1202);
    float _1206 = _1205.x;
    float _1209 = 0.5 * _1205.y;
    float _1211 = _1205.z;
    float _1212 = 0.25 * _1211;
    float3 _1219 = float3(((0.25 * _1206) + _1209) + _1212, 0.5 * (_1206 - _1211), (((-0.25) * _1206) + _1209) - _1212);
    float _1224 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1235 = mix(precise::max(1.0, (1.0 + _1224) * 0.300000011920928955078125), _1224, precise::min(1.0 - (_217 * 0.5), precise::min(1.0 - _219, fast::clamp(_882 * 5.0, 0.0, 1.0))));
    float2 _1238 = _891 + (_901 + float2(_905));
    uint2 _1240 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1243 = float(all(uint2(_907) < _1240));
    bool _1244 = !_902;
    float _1262;
    float3 _1263;
    if (_1244)
    {
        float2 _1248 = _1238 * float2(_1235);
        float _1250 = precise::min(dot(_1248, _1248), 4.0);
        float _1252 = (0.4000000059604644775390625 * _1250) - 1.0;
        float _1254 = (0.25 * _1250) - 1.0;
        float _1260 = _1243 * ((((1.5625 * _1252) * _1252) - 0.5625) * (_1254 * _1254));
        _1262 = _1260;
        _1263 = _943 * _1260;
    }
    else
    {
        _1262 = 0.0;
        _1263 = float3(0.0);
    }
    float _1267 = exp((-2.2999999523162841796875) * dot(_1238, _1238)) * _1243;
    float3 _1268 = _943 * _1267;
    float2 _1272 = _891 + (_901 + float2(_945));
    float _1276 = float(all(uint2(_946) < _1240));
    float _1296;
    float3 _1297;
    if (_1244)
    {
        float2 _1280 = _1272 * float2(_1235);
        float _1282 = precise::min(dot(_1280, _1280), 4.0);
        float _1284 = (0.4000000059604644775390625 * _1282) - 1.0;
        float _1286 = (0.25 * _1282) - 1.0;
        float _1292 = _1276 * ((((1.5625 * _1284) * _1284) - 0.5625) * (_1286 * _1286));
        _1296 = _1262 + _1292;
        _1297 = _1263 + (_978 * _1292);
    }
    else
    {
        _1296 = _1262;
        _1297 = _1263;
    }
    float _1301 = exp((-2.2999999523162841796875) * dot(_1272, _1272)) * _1276;
    float3 _1304 = _978 * _1301;
    float2 _1311 = _891 + (_901 + float2(_980));
    float _1315 = float(all(uint2(_981) < _1240));
    float _1335;
    float3 _1336;
    if (_1244)
    {
        float2 _1319 = _1311 * float2(_1235);
        float _1321 = precise::min(dot(_1319, _1319), 4.0);
        float _1323 = (0.4000000059604644775390625 * _1321) - 1.0;
        float _1325 = (0.25 * _1321) - 1.0;
        float _1331 = _1315 * ((((1.5625 * _1323) * _1323) - 0.5625) * (_1325 * _1325));
        _1335 = _1296 + _1331;
        _1336 = _1297 + (_1013 * _1331);
    }
    else
    {
        _1335 = _1296;
        _1336 = _1297;
    }
    float _1340 = exp((-2.2999999523162841796875) * dot(_1311, _1311)) * _1315;
    float3 _1343 = _1013 * _1340;
    float2 _1350 = _891 + (_901 + float2(_1015));
    float _1354 = float(all(uint2(_1016) < _1240));
    float _1374;
    float3 _1375;
    if (_1244)
    {
        float2 _1358 = _1350 * float2(_1235);
        float _1360 = precise::min(dot(_1358, _1358), 4.0);
        float _1362 = (0.4000000059604644775390625 * _1360) - 1.0;
        float _1364 = (0.25 * _1360) - 1.0;
        float _1370 = _1354 * ((((1.5625 * _1362) * _1362) - 0.5625) * (_1364 * _1364));
        _1374 = _1335 + _1370;
        _1375 = _1336 + (_1048 * _1370);
    }
    else
    {
        _1374 = _1335;
        _1375 = _1336;
    }
    float _1379 = exp((-2.2999999523162841796875) * dot(_1350, _1350)) * _1354;
    float3 _1382 = _1048 * _1379;
    float2 _1389 = _891 + (_901 + float2(_1049));
    float _1393 = float(all(uint2(_1050) < _1240));
    float _1413;
    float3 _1414;
    if (_1244)
    {
        float2 _1397 = _1389 * float2(_1235);
        float _1399 = precise::min(dot(_1397, _1397), 4.0);
        float _1401 = (0.4000000059604644775390625 * _1399) - 1.0;
        float _1403 = (0.25 * _1399) - 1.0;
        float _1409 = _1393 * ((((1.5625 * _1401) * _1401) - 0.5625) * (_1403 * _1403));
        _1413 = _1374 + _1409;
        _1414 = _1375 + (_1082 * _1409);
    }
    else
    {
        _1413 = _1374;
        _1414 = _1375;
    }
    float _1418 = exp((-2.2999999523162841796875) * dot(_1389, _1389)) * _1393;
    float3 _1421 = _1082 * _1418;
    float2 _1428 = _891 + (_901 + float2(_1083));
    float _1432 = float(all(uint2(_1084) < _1240));
    float _1452;
    float3 _1453;
    if (_1244)
    {
        float2 _1436 = _1428 * float2(_1235);
        float _1438 = precise::min(dot(_1436, _1436), 4.0);
        float _1440 = (0.4000000059604644775390625 * _1438) - 1.0;
        float _1442 = (0.25 * _1438) - 1.0;
        float _1448 = _1432 * ((((1.5625 * _1440) * _1440) - 0.5625) * (_1442 * _1442));
        _1452 = _1413 + _1448;
        _1453 = _1414 + (_1116 * _1448);
    }
    else
    {
        _1452 = _1413;
        _1453 = _1414;
    }
    float _1457 = exp((-2.2999999523162841796875) * dot(_1428, _1428)) * _1432;
    float3 _1460 = _1116 * _1457;
    float2 _1467 = _891 + (_901 + float2(_1118));
    float _1471 = float(all(uint2(_1119) < _1240));
    float _1491;
    float3 _1492;
    if (_1244)
    {
        float2 _1475 = _1467 * float2(_1235);
        float _1477 = precise::min(dot(_1475, _1475), 4.0);
        float _1479 = (0.4000000059604644775390625 * _1477) - 1.0;
        float _1481 = (0.25 * _1477) - 1.0;
        float _1487 = _1471 * ((((1.5625 * _1479) * _1479) - 0.5625) * (_1481 * _1481));
        _1491 = _1452 + _1487;
        _1492 = _1453 + (_1151 * _1487);
    }
    else
    {
        _1491 = _1452;
        _1492 = _1453;
    }
    float _1496 = exp((-2.2999999523162841796875) * dot(_1467, _1467)) * _1471;
    float3 _1499 = _1151 * _1496;
    float2 _1506 = _891 + (_901 + float2(_1152));
    float _1510 = float(all(uint2(_1153) < _1240));
    float _1530;
    float3 _1531;
    if (_1244)
    {
        float2 _1514 = _1506 * float2(_1235);
        float _1516 = precise::min(dot(_1514, _1514), 4.0);
        float _1518 = (0.4000000059604644775390625 * _1516) - 1.0;
        float _1520 = (0.25 * _1516) - 1.0;
        float _1526 = _1510 * ((((1.5625 * _1518) * _1518) - 0.5625) * (_1520 * _1520));
        _1530 = _1491 + _1526;
        _1531 = _1492 + (_1185 * _1526);
    }
    else
    {
        _1530 = _1491;
        _1531 = _1492;
    }
    float _1535 = exp((-2.2999999523162841796875) * dot(_1506, _1506)) * _1510;
    float3 _1538 = _1185 * _1535;
    float2 _1545 = _891 + (_901 + float2(_1186));
    float _1549 = float(all(uint2(_1187) < _1240));
    float _1569;
    float3 _1570;
    if (_1244)
    {
        float2 _1553 = _1545 * float2(_1235);
        float _1555 = precise::min(dot(_1553, _1553), 4.0);
        float _1557 = (0.4000000059604644775390625 * _1555) - 1.0;
        float _1559 = (0.25 * _1555) - 1.0;
        float _1565 = _1549 * ((((1.5625 * _1557) * _1557) - 0.5625) * (_1559 * _1559));
        _1569 = _1530 + _1565;
        _1570 = _1531 + (_1219 * _1565);
    }
    else
    {
        _1569 = _1530;
        _1570 = _1531;
    }
    float _1574 = exp((-2.2999999523162841796875) * dot(_1545, _1545)) * _1549;
    float3 _1577 = _1219 * _1574;
    float _1581 = (((((((_1267 + _1301) + _1340) + _1379) + _1418) + _1457) + _1496) + _1535) + _1574;
    float3 _1585 = float3((abs(_1581) > 1.1754943508222875079687365372222e-38) ? _1581 : 1.0);
    float3 _1586 = ((((((((_1268 + _1304) + _1343) + _1382) + _1421) + _1460) + _1499) + _1538) + _1577) / _1585;
    float _1594 = _1569 * float(_1569 > 6.099999882280826568603515625e-05);
    float3 _1602;
    float _1603;
    if (_1594 > 6.099999882280826568603515625e-05)
    {
        _1602 = fast::clamp(_1570 / float3(_1594), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_943, _978), _1013), _1048), _1082), _1116), _1151), _1185), _1219), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_943, _978), _1013), _1048), _1082), _1116), _1151), _1185), _1219));
        _1603 = _1594 * 0.04625000059604644775390625;
    }
    else
    {
        _1602 = _1570;
        _1603 = _1594;
    }
    float _1606 = _902 ? 1.0 : _1603;
    float _1607 = _902 ? 0.0 : _882;
    float3 _1621 = (sqrt(abs(((((((((((_943 * _1268) + (_978 * _1304)) + (_1013 * _1343)) + (_1048 * _1382)) + (_1082 * _1421)) + (_1116 * _1460)) + (_1151 * _1499)) + (_1185 * _1538)) + (_1219 * _1577)) / _1585) - (_1586 * _1586))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_158 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _192, _192 - float2(0.5))) / float2(int2(int(_186.x), int(_186.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _226, precise::max(powr(_215, 0.5), _219)))));
    float3 _1624 = (_827 - _1586) / precise::max(_1621, float3(1.19299997436428384389728307724e-07));
    float3 _1639;
    if (length(_1624) > 1.0)
    {
        _1639 = mix((fast::normalize(_1624) * _1621) + _1586, _827, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_131 * _136, _142)) / _145), level(0.0)).x, fast::clamp(fast::clamp(_837 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _226) * (1.0 - _217), 0.0, 1.0)));
    }
    else
    {
        _1639 = _827;
    }
    float3 _1648 = mix(_1639, select(_1602, _1586, bool3(_902)), float3(fast::clamp(_1606 / precise::max(6.099999882280826568603515625e-05, (_1607 * float(_1607 > 6.099999882280826568603515625e-05)) + _1606), 0.0, 1.0)));
    float _1649 = _1648.x;
    float _1650 = _1648.y;
    float _1652 = _1648.z;
    float4 _1659 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1660 = _1659.x;
    float3 _1665 = precise::max(float3((_1649 + _1650) - _1652, _1649 + _1652, (_1649 - _1650) - _1652) / float3((_1660 == 0.0) ? 1.0 : _1660), float3(0.0));
    float _1666 = _1665.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1666, _1665.yz, precise::max(0.0, precise::max(0.0, precise::min(_837 + (sdk_hlsl_load(rw_new_locks, uint2(_147)).x * (1.0 - precise::max(0.0, _215))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _834))) * float(_872)), uint2(_147));
    sdk_hlsl_store(rw_upscaled_output, float4(_1666, _1665.yz, 1.0), uint2(_147));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_147));
}

