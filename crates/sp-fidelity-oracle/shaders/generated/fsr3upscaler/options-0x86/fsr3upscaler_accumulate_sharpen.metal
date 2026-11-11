#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

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


template<typename T, size_t Num>
struct spvUnsafeArray
{
    T elements[Num ? Num : 1];
    
    thread T& operator [] (size_t pos) thread
    {
        return elements[pos];
    }
    constexpr const thread T& operator [] (size_t pos) const thread
    {
        return elements[pos];
    }
    
    device T& operator [] (size_t pos) device
    {
        return elements[pos];
    }
    constexpr const device T& operator [] (size_t pos) const device
    {
        return elements[pos];
    }
    
    constexpr const constant T& operator [] (size_t pos) const constant
    {
        return elements[pos];
    }
    
    threadgroup T& operator [] (size_t pos) threadgroup
    {
        return elements[pos];
    }
    constexpr const threadgroup T& operator [] (size_t pos) const threadgroup
    {
        return elements[pos];
    }
};

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
    float2 _135 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _138 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _139 = _135 / _138;
    float2 _144 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _146 = _139 + (cbFSR3Upscaler.fJitter / _144);
    float2 _150 = _144 - float2(0.5);
    float2 _153 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _155 = _139 * _144;
    float2 _161 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_155)))), 0u).xy;
    float _163 = length(_161 * float2(3840.0, 2160.0));
    float2 _164 = _139 + _161;
    float _165 = _164.x;
    bool _170;
    if (_165 >= 0.0)
    {
        _170 = _165 <= 1.0;
    }
    else
    {
        _170 = false;
    }
    bool _179;
    if (_170)
    {
        float _173 = _164.y;
        bool _178;
        if (_173 >= 0.0)
        {
            _178 = _173 <= 1.0;
        }
        else
        {
            _178 = false;
        }
        _179 = _178;
    }
    else
    {
        _179 = false;
    }
    uint2 _190 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _196 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _213;
    if (_179)
    {
        _213 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _213 = true;
    }
    float4 _217 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_146 * _144, _150)) / _153), level(0.0));
    float _219 = fast::clamp(_217.x, 0.0, 1.0);
    float _221 = fast::clamp(_217.y, 0.0, 1.0);
    float _223 = fast::clamp(_217.z, 0.0, 1.0);
    float _225 = fast::clamp(_217.w, 0.0, 1.0);
    float _230 = _225 * float(rint(_225 * 100.0) > 1.0);
    bool _234;
    if (_179)
    {
        _234 = !_213;
    }
    else
    {
        _234 = false;
    }
    float3 _831;
    float _832;
    if (_234)
    {
        float2 _238 = (_164 * _138) - float2(0.5);
        half2 _241 = half2(_238 - floor(_238));
        int2 _254 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _238.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _238.y)))));
        int2 _255 = _254 + int2(-1);
        int _257 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _261 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _269 = _254 + int2(0, -1);
        int2 _281 = _254 + int2(1, -1);
        int2 _293 = _254 + int2(2, -1);
        int2 _305 = _254 + int2(-1, 0);
        half4 _327 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_254.x, _257)), max(1, min(_254.y, _261))))), 0u));
        int2 _328 = _254 + int2(1, 0);
        half4 _339 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_328.x, _257)), max(1, min(_328.y, _261))))), 0u));
        int2 _340 = _254 + int2(2, 0);
        int2 _352 = _254 + int2(-1, 1);
        int2 _364 = _254 + int2(0, 1);
        half4 _375 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_364.x, _257)), max(1, min(_364.y, _261))))), 0u));
        int2 _376 = _254 + int2(1);
        half4 _387 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_376.x, _257)), max(1, min(_376.y, _261))))), 0u));
        int2 _388 = _254 + int2(2, 1);
        int2 _400 = _254 + int2(-1, 2);
        int2 _412 = _254 + int2(0, 2);
        int2 _424 = _254 + int2(1, 2);
        int2 _436 = _254 + int2(2);
        half _448 = _241.x;
        float _452 = float(min(abs(half(-1.0) - _448), half(2.0)));
        bool _454 = abs(_452) < 6.099999882280826568603515625e-05;
        float _465;
        if (_454)
        {
            _465 = 1.0;
        }
        else
        {
            float _458 = 3.1415927410125732421875 * _452;
            float _461 = 1.57079637050628662109375 * _452;
            _465 = (sin(_458) / _458) * (sin(_461) / _461);
        }
        half _466 = half(_465);
        float _470 = float(min(abs(half(-0.0) - _448), half(2.0)));
        bool _472 = abs(_470) < 6.099999882280826568603515625e-05;
        float _483;
        if (_472)
        {
            _483 = 1.0;
        }
        else
        {
            float _476 = 3.1415927410125732421875 * _470;
            float _479 = 1.57079637050628662109375 * _470;
            _483 = (sin(_476) / _476) * (sin(_479) / _479);
        }
        half _484 = half(_483);
        float _488 = float(min(abs(half(1.0) - _448), half(2.0)));
        bool _490 = abs(_488) < 6.099999882280826568603515625e-05;
        float _501;
        if (_490)
        {
            _501 = 1.0;
        }
        else
        {
            float _494 = 3.1415927410125732421875 * _488;
            float _497 = 1.57079637050628662109375 * _488;
            _501 = (sin(_494) / _494) * (sin(_497) / _497);
        }
        half _502 = half(_501);
        float _506 = float(min(abs(half(2.0) - _448), half(2.0)));
        bool _508 = abs(_506) < 6.099999882280826568603515625e-05;
        float _519;
        if (_508)
        {
            _519 = 1.0;
        }
        else
        {
            float _512 = 3.1415927410125732421875 * _506;
            float _515 = 1.57079637050628662109375 * _506;
            _519 = (sin(_512) / _512) * (sin(_515) / _515);
        }
        half _520 = half(_519);
        float _543;
        if (_454)
        {
            _543 = 1.0;
        }
        else
        {
            float _536 = 3.1415927410125732421875 * _452;
            float _539 = 1.57079637050628662109375 * _452;
            _543 = (sin(_536) / _536) * (sin(_539) / _539);
        }
        half _544 = half(_543);
        float _555;
        if (_472)
        {
            _555 = 1.0;
        }
        else
        {
            float _548 = 3.1415927410125732421875 * _470;
            float _551 = 1.57079637050628662109375 * _470;
            _555 = (sin(_548) / _548) * (sin(_551) / _551);
        }
        half _556 = half(_555);
        float _567;
        if (_490)
        {
            _567 = 1.0;
        }
        else
        {
            float _560 = 3.1415927410125732421875 * _488;
            float _563 = 1.57079637050628662109375 * _488;
            _567 = (sin(_560) / _560) * (sin(_563) / _563);
        }
        half _568 = half(_567);
        float _579;
        if (_508)
        {
            _579 = 1.0;
        }
        else
        {
            float _572 = 3.1415927410125732421875 * _506;
            float _575 = 1.57079637050628662109375 * _506;
            _579 = (sin(_572) / _572) * (sin(_575) / _575);
        }
        half _580 = half(_579);
        float _603;
        if (_454)
        {
            _603 = 1.0;
        }
        else
        {
            float _596 = 3.1415927410125732421875 * _452;
            float _599 = 1.57079637050628662109375 * _452;
            _603 = (sin(_596) / _596) * (sin(_599) / _599);
        }
        half _604 = half(_603);
        float _615;
        if (_472)
        {
            _615 = 1.0;
        }
        else
        {
            float _608 = 3.1415927410125732421875 * _470;
            float _611 = 1.57079637050628662109375 * _470;
            _615 = (sin(_608) / _608) * (sin(_611) / _611);
        }
        half _616 = half(_615);
        float _627;
        if (_490)
        {
            _627 = 1.0;
        }
        else
        {
            float _620 = 3.1415927410125732421875 * _488;
            float _623 = 1.57079637050628662109375 * _488;
            _627 = (sin(_620) / _620) * (sin(_623) / _623);
        }
        half _628 = half(_627);
        float _639;
        if (_508)
        {
            _639 = 1.0;
        }
        else
        {
            float _632 = 3.1415927410125732421875 * _506;
            float _635 = 1.57079637050628662109375 * _506;
            _639 = (sin(_632) / _632) * (sin(_635) / _635);
        }
        half _640 = half(_639);
        float _663;
        if (_454)
        {
            _663 = 1.0;
        }
        else
        {
            float _656 = 3.1415927410125732421875 * _452;
            float _659 = 1.57079637050628662109375 * _452;
            _663 = (sin(_656) / _656) * (sin(_659) / _659);
        }
        half _664 = half(_663);
        float _675;
        if (_472)
        {
            _675 = 1.0;
        }
        else
        {
            float _668 = 3.1415927410125732421875 * _470;
            float _671 = 1.57079637050628662109375 * _470;
            _675 = (sin(_668) / _668) * (sin(_671) / _671);
        }
        half _676 = half(_675);
        float _687;
        if (_490)
        {
            _687 = 1.0;
        }
        else
        {
            float _680 = 3.1415927410125732421875 * _488;
            float _683 = 1.57079637050628662109375 * _488;
            _687 = (sin(_680) / _680) * (sin(_683) / _683);
        }
        half _688 = half(_687);
        float _699;
        if (_508)
        {
            _699 = 1.0;
        }
        else
        {
            float _692 = 3.1415927410125732421875 * _506;
            float _695 = 1.57079637050628662109375 * _506;
            _699 = (sin(_692) / _692) * (sin(_695) / _695);
        }
        half _700 = half(_699);
        half _713 = _241.y;
        float _717 = float(min(abs(half(-1.0) - _713), half(2.0)));
        float _730;
        if (abs(_717) < 6.099999882280826568603515625e-05)
        {
            _730 = 1.0;
        }
        else
        {
            float _723 = 3.1415927410125732421875 * _717;
            float _726 = 1.57079637050628662109375 * _717;
            _730 = (sin(_723) / _723) * (sin(_726) / _726);
        }
        half _731 = half(_730);
        float _735 = float(min(abs(half(-0.0) - _713), half(2.0)));
        float _748;
        if (abs(_735) < 6.099999882280826568603515625e-05)
        {
            _748 = 1.0;
        }
        else
        {
            float _741 = 3.1415927410125732421875 * _735;
            float _744 = 1.57079637050628662109375 * _735;
            _748 = (sin(_741) / _741) * (sin(_744) / _744);
        }
        half _749 = half(_748);
        float _753 = float(min(abs(half(1.0) - _713), half(2.0)));
        float _766;
        if (abs(_753) < 6.099999882280826568603515625e-05)
        {
            _766 = 1.0;
        }
        else
        {
            float _759 = 3.1415927410125732421875 * _753;
            float _762 = 1.57079637050628662109375 * _753;
            _766 = (sin(_759) / _759) * (sin(_762) / _762);
        }
        half _767 = half(_766);
        float _771 = float(min(abs(half(2.0) - _713), half(2.0)));
        float _784;
        if (abs(_771) < 6.099999882280826568603515625e-05)
        {
            _784 = 1.0;
        }
        else
        {
            float _777 = 3.1415927410125732421875 * _771;
            float _780 = 1.57079637050628662109375 * _771;
            _784 = (sin(_777) / _777) * (sin(_780) / _780);
        }
        half _785 = half(_784);
        half4 _790 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_255.x, _257)), max(1, min(_255.y, _261))))), 0u)) * _466) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_269.x, _257)), max(1, min(_269.y, _261))))), 0u)) * _484)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_281.x, _257)), max(1, min(_281.y, _261))))), 0u)) * _502)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_293.x, _257)), max(1, min(_293.y, _261))))), 0u)) * _520)) / half4(((_466 + _484) + _502) + _520)) * _731) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_305.x, _257)), max(1, min(_305.y, _261))))), 0u)) * _544) + (_327 * _556)) + (_339 * _568)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_340.x, _257)), max(1, min(_340.y, _261))))), 0u)) * _580)) / half4(((_544 + _556) + _568) + _580)) * _749)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_352.x, _257)), max(1, min(_352.y, _261))))), 0u)) * _604) + (_375 * _616)) + (_387 * _628)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_388.x, _257)), max(1, min(_388.y, _261))))), 0u)) * _640)) / half4(((_604 + _616) + _628) + _640)) * _767);
        half4 _797 = (_790 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_400.x, _257)), max(1, min(_400.y, _261))))), 0u)) * _664) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_412.x, _257)), max(1, min(_412.y, _261))))), 0u)) * _676)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_424.x, _257)), max(1, min(_424.y, _261))))), 0u)) * _688)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_436.x, _257)), max(1, min(_436.y, _261))))), 0u)) * _700)) / half4(((_664 + _676) + _688) + _700)) * _785)) / half4(((_731 + _749) + _767) + _785);
        float4 _805 = float4(clamp(_797, min(min(min(_327, _339), _375), _387), max(max(max(_327, _339), _375), _387)));
        float4 _811 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _812 = _811.x;
        float3 _815 = (_805.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_812 == 0.0) ? 1.0 : _812);
        float _819 = 0.5 * _815.y;
        float _822 = 0.25 * _815.z;
        _831 = float3(((0.25 * _815.x) + _819) + _822, 0.5 * (_815.x - _815.z), (((-0.25) * _815.x) + _819) - _822);
        _832 = _805.w;
    }
    else
    {
        _831 = float3(0.0);
        _832 = 0.0;
    }
    float _838 = precise::max(fast::clamp(_223, 0.0, 1.0), precise::max(_219, _221));
    float _841 = precise::max(0.0, (_832 * float(!_213)) - (_838 * 2.0));
    uint2 _845 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _862 = _139 - _161;
    float _863 = _862.x;
    bool _868;
    if (_863 >= 0.0)
    {
        _868 = _863 <= 1.0;
    }
    else
    {
        _868 = false;
    }
    bool _877;
    if (_868)
    {
        float _871 = _862.y;
        bool _876;
        if (_871 >= 0.0)
        {
            _876 = _871 <= 1.0;
        }
        else
        {
            _876 = false;
        }
        _877 = _876;
    }
    else
    {
        _877 = false;
    }
    float _887 = precise::min(_230, mix(_230, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_163 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _890 = _135 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _892 = int2(floor(_890));
    float2 _895 = (float2(_892) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _896 = _895 - _890;
    bool _899 = _895.x > _890.x;
    bool _903 = _895.y > _890.y;
    int2 _905 = int2(_899 ? (-2) : (-1), _903 ? (-2) : (-1));
    float2 _906 = float2(_905);
    bool _907 = _230 == 0.0;
    int _908 = _899 ? 3 : 0;
    int _909 = _903 ? 3 : 0;
    int2 _910 = int2(_908, _909);
    int2 _911 = _892 + _905;
    int2 _912 = _911 + _910;
    int _915 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _920 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _930 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _931 = _930.x;
    float3 _934 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_912.x, _915)), max(0, min(_912.y, _920))))), 0u).xyz) * ((_931 == 0.0) ? 1.0 : _931);
    float _935 = _934.x;
    float _938 = 0.5 * _934.y;
    float _940 = _934.z;
    float _941 = 0.25 * _940;
    spvUnsafeArray<float3, 9> _131;
    _131[0] = float3(((0.25 * _935) + _938) + _941, 0.5 * (_935 - _940), (((-0.25) * _935) + _938) - _941);
    int _950 = _899 ? 2 : 1;
    int2 _951 = int2(_950, _909);
    int2 _952 = _911 + _951;
    float4 _966 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _967 = _966.x;
    float3 _970 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_952.x, _915)), max(0, min(_952.y, _920))))), 0u).xyz) * ((_967 == 0.0) ? 1.0 : _967);
    float _971 = _970.x;
    float _974 = 0.5 * _970.y;
    float _976 = _970.z;
    float _977 = 0.25 * _976;
    _131[1] = float3(((0.25 * _971) + _974) + _977, 0.5 * (_971 - _976), (((-0.25) * _971) + _974) - _977);
    int _986 = _899 ? 1 : 2;
    int2 _987 = int2(_986, _909);
    int2 _988 = _911 + _987;
    float4 _1002 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1003 = _1002.x;
    float3 _1006 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_988.x, _915)), max(0, min(_988.y, _920))))), 0u).xyz) * ((_1003 == 0.0) ? 1.0 : _1003);
    float _1007 = _1006.x;
    float _1010 = 0.5 * _1006.y;
    float _1012 = _1006.z;
    float _1013 = 0.25 * _1012;
    _131[2] = float3(((0.25 * _1007) + _1010) + _1013, 0.5 * (_1007 - _1012), (((-0.25) * _1007) + _1010) - _1013);
    int _1022 = _903 ? 2 : 1;
    int2 _1023 = int2(_908, _1022);
    int2 _1024 = _911 + _1023;
    float4 _1038 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1039 = _1038.x;
    float3 _1042 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1024.x, _915)), max(0, min(_1024.y, _920))))), 0u).xyz) * ((_1039 == 0.0) ? 1.0 : _1039);
    float _1043 = _1042.x;
    float _1046 = 0.5 * _1042.y;
    float _1048 = _1042.z;
    float _1049 = 0.25 * _1048;
    _131[3] = float3(((0.25 * _1043) + _1046) + _1049, 0.5 * (_1043 - _1048), (((-0.25) * _1043) + _1046) - _1049);
    int2 _1058 = int2(_950, _1022);
    int2 _1059 = _911 + _1058;
    float4 _1073 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1074 = _1073.x;
    float3 _1077 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1059.x, _915)), max(0, min(_1059.y, _920))))), 0u).xyz) * ((_1074 == 0.0) ? 1.0 : _1074);
    float _1078 = _1077.x;
    float _1081 = 0.5 * _1077.y;
    float _1083 = _1077.z;
    float _1084 = 0.25 * _1083;
    _131[4] = float3(((0.25 * _1078) + _1081) + _1084, 0.5 * (_1078 - _1083), (((-0.25) * _1078) + _1081) - _1084);
    int2 _1093 = int2(_986, _1022);
    int2 _1094 = _911 + _1093;
    float4 _1108 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1109 = _1108.x;
    float3 _1112 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1094.x, _915)), max(0, min(_1094.y, _920))))), 0u).xyz) * ((_1109 == 0.0) ? 1.0 : _1109);
    float _1113 = _1112.x;
    float _1116 = 0.5 * _1112.y;
    float _1118 = _1112.z;
    float _1119 = 0.25 * _1118;
    _131[5] = float3(((0.25 * _1113) + _1116) + _1119, 0.5 * (_1113 - _1118), (((-0.25) * _1113) + _1116) - _1119);
    int _1128 = _903 ? 1 : 2;
    int2 _1129 = int2(_908, _1128);
    int2 _1130 = _911 + _1129;
    float4 _1144 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1145 = _1144.x;
    float3 _1148 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1130.x, _915)), max(0, min(_1130.y, _920))))), 0u).xyz) * ((_1145 == 0.0) ? 1.0 : _1145);
    float _1149 = _1148.x;
    float _1152 = 0.5 * _1148.y;
    float _1154 = _1148.z;
    float _1155 = 0.25 * _1154;
    _131[6] = float3(((0.25 * _1149) + _1152) + _1155, 0.5 * (_1149 - _1154), (((-0.25) * _1149) + _1152) - _1155);
    int2 _1164 = int2(_950, _1128);
    int2 _1165 = _911 + _1164;
    float4 _1179 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1180 = _1179.x;
    float3 _1183 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1165.x, _915)), max(0, min(_1165.y, _920))))), 0u).xyz) * ((_1180 == 0.0) ? 1.0 : _1180);
    float _1184 = _1183.x;
    float _1187 = 0.5 * _1183.y;
    float _1189 = _1183.z;
    float _1190 = 0.25 * _1189;
    _131[7] = float3(((0.25 * _1184) + _1187) + _1190, 0.5 * (_1184 - _1189), (((-0.25) * _1184) + _1187) - _1190);
    int2 _1199 = int2(_986, _1128);
    int2 _1200 = _911 + _1199;
    float4 _1214 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1215 = _1214.x;
    float3 _1218 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1200.x, _915)), max(0, min(_1200.y, _920))))), 0u).xyz) * ((_1215 == 0.0) ? 1.0 : _1215);
    float _1219 = _1218.x;
    float _1222 = 0.5 * _1218.y;
    float _1224 = _1218.z;
    float _1225 = 0.25 * _1224;
    _131[8] = float3(((0.25 * _1219) + _1222) + _1225, 0.5 * (_1219 - _1224), (((-0.25) * _1219) + _1222) - _1225);
    if (_907)
    {
        for (int _1237 = 0; _1237 < 9; )
        {
            float _1248 = (_131[_1237].x + _131[_1237].y) - _131[_1237].z;
            float _1249 = _131[_1237].x + _131[_1237].z;
            float _1251 = (_131[_1237].x - _131[_1237].y) - _131[_1237].z;
            float3 _1258 = float3(_1248, _1249, _1251) / float3(precise::max(precise::max(0.0, _1248), precise::max(_1249, _1251)) + 1.0);
            float _1259 = _1258.x;
            float _1262 = 0.5 * _1258.y;
            float _1264 = _1258.z;
            float _1265 = 0.25 * _1264;
            _131[_1237] = float3(((0.25 * _1259) + _1262) + _1265, 0.5 * (_1259 - _1264), (((-0.25) * _1259) + _1262) - _1265);
            _1237++;
            continue;
        }
    }
    float _1277 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1288 = mix(precise::max(1.0, (1.0 + _1277) * 0.300000011920928955078125), _1277, precise::min(1.0 - (_221 * 0.5), precise::min(1.0 - _223, fast::clamp(_887 * 5.0, 0.0, 1.0))));
    float2 _1291 = _896 + (_906 + float2(_910));
    uint2 _1293 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1296 = float(all(uint2(_912) < _1293));
    bool _1297 = !_907;
    float _1316;
    float3 _1317;
    if (_1297)
    {
        float2 _1301 = _1291 * float2(_1288);
        float _1303 = precise::min(dot(_1301, _1301), 4.0);
        float _1305 = (0.4000000059604644775390625 * _1303) - 1.0;
        float _1307 = (0.25 * _1303) - 1.0;
        float _1313 = _1296 * ((((1.5625 * _1305) * _1305) - 0.5625) * (_1307 * _1307));
        _1316 = _1313;
        _1317 = _131[0] * _1313;
    }
    else
    {
        _1316 = 0.0;
        _1317 = float3(0.0);
    }
    float _1321 = exp((-2.2999999523162841796875) * dot(_1291, _1291)) * _1296;
    float3 _1323 = _131[0] * _1321;
    float2 _1327 = _896 + (_906 + float2(_951));
    float _1331 = float(all(uint2(_952) < _1293));
    float _1352;
    float3 _1353;
    if (_1297)
    {
        float2 _1335 = _1327 * float2(_1288);
        float _1337 = precise::min(dot(_1335, _1335), 4.0);
        float _1339 = (0.4000000059604644775390625 * _1337) - 1.0;
        float _1341 = (0.25 * _1337) - 1.0;
        float _1347 = _1331 * ((((1.5625 * _1339) * _1339) - 0.5625) * (_1341 * _1341));
        _1352 = _1316 + _1347;
        _1353 = _1317 + (_131[1] * _1347);
    }
    else
    {
        _1352 = _1316;
        _1353 = _1317;
    }
    float _1357 = exp((-2.2999999523162841796875) * dot(_1327, _1327)) * _1331;
    float3 _1361 = _131[1] * _1357;
    float2 _1368 = _896 + (_906 + float2(_987));
    float _1372 = float(all(uint2(_988) < _1293));
    float _1393;
    float3 _1394;
    if (_1297)
    {
        float2 _1376 = _1368 * float2(_1288);
        float _1378 = precise::min(dot(_1376, _1376), 4.0);
        float _1380 = (0.4000000059604644775390625 * _1378) - 1.0;
        float _1382 = (0.25 * _1378) - 1.0;
        float _1388 = _1372 * ((((1.5625 * _1380) * _1380) - 0.5625) * (_1382 * _1382));
        _1393 = _1352 + _1388;
        _1394 = _1353 + (_131[2] * _1388);
    }
    else
    {
        _1393 = _1352;
        _1394 = _1353;
    }
    float _1398 = exp((-2.2999999523162841796875) * dot(_1368, _1368)) * _1372;
    float3 _1402 = _131[2] * _1398;
    float2 _1409 = _896 + (_906 + float2(_1023));
    float _1413 = float(all(uint2(_1024) < _1293));
    float _1434;
    float3 _1435;
    if (_1297)
    {
        float2 _1417 = _1409 * float2(_1288);
        float _1419 = precise::min(dot(_1417, _1417), 4.0);
        float _1421 = (0.4000000059604644775390625 * _1419) - 1.0;
        float _1423 = (0.25 * _1419) - 1.0;
        float _1429 = _1413 * ((((1.5625 * _1421) * _1421) - 0.5625) * (_1423 * _1423));
        _1434 = _1393 + _1429;
        _1435 = _1394 + (_131[3] * _1429);
    }
    else
    {
        _1434 = _1393;
        _1435 = _1394;
    }
    float _1439 = exp((-2.2999999523162841796875) * dot(_1409, _1409)) * _1413;
    float3 _1443 = _131[3] * _1439;
    float2 _1450 = _896 + (_906 + float2(_1058));
    float _1454 = float(all(uint2(_1059) < _1293));
    float _1475;
    float3 _1476;
    if (_1297)
    {
        float2 _1458 = _1450 * float2(_1288);
        float _1460 = precise::min(dot(_1458, _1458), 4.0);
        float _1462 = (0.4000000059604644775390625 * _1460) - 1.0;
        float _1464 = (0.25 * _1460) - 1.0;
        float _1470 = _1454 * ((((1.5625 * _1462) * _1462) - 0.5625) * (_1464 * _1464));
        _1475 = _1434 + _1470;
        _1476 = _1435 + (_131[4] * _1470);
    }
    else
    {
        _1475 = _1434;
        _1476 = _1435;
    }
    float _1480 = exp((-2.2999999523162841796875) * dot(_1450, _1450)) * _1454;
    float3 _1484 = _131[4] * _1480;
    float2 _1491 = _896 + (_906 + float2(_1093));
    float _1495 = float(all(uint2(_1094) < _1293));
    float _1516;
    float3 _1517;
    if (_1297)
    {
        float2 _1499 = _1491 * float2(_1288);
        float _1501 = precise::min(dot(_1499, _1499), 4.0);
        float _1503 = (0.4000000059604644775390625 * _1501) - 1.0;
        float _1505 = (0.25 * _1501) - 1.0;
        float _1511 = _1495 * ((((1.5625 * _1503) * _1503) - 0.5625) * (_1505 * _1505));
        _1516 = _1475 + _1511;
        _1517 = _1476 + (_131[5] * _1511);
    }
    else
    {
        _1516 = _1475;
        _1517 = _1476;
    }
    float _1521 = exp((-2.2999999523162841796875) * dot(_1491, _1491)) * _1495;
    float3 _1525 = _131[5] * _1521;
    float2 _1532 = _896 + (_906 + float2(_1129));
    float _1536 = float(all(uint2(_1130) < _1293));
    float _1557;
    float3 _1558;
    if (_1297)
    {
        float2 _1540 = _1532 * float2(_1288);
        float _1542 = precise::min(dot(_1540, _1540), 4.0);
        float _1544 = (0.4000000059604644775390625 * _1542) - 1.0;
        float _1546 = (0.25 * _1542) - 1.0;
        float _1552 = _1536 * ((((1.5625 * _1544) * _1544) - 0.5625) * (_1546 * _1546));
        _1557 = _1516 + _1552;
        _1558 = _1517 + (_131[6] * _1552);
    }
    else
    {
        _1557 = _1516;
        _1558 = _1517;
    }
    float _1562 = exp((-2.2999999523162841796875) * dot(_1532, _1532)) * _1536;
    float3 _1566 = _131[6] * _1562;
    float2 _1573 = _896 + (_906 + float2(_1164));
    float _1577 = float(all(uint2(_1165) < _1293));
    float _1598;
    float3 _1599;
    if (_1297)
    {
        float2 _1581 = _1573 * float2(_1288);
        float _1583 = precise::min(dot(_1581, _1581), 4.0);
        float _1585 = (0.4000000059604644775390625 * _1583) - 1.0;
        float _1587 = (0.25 * _1583) - 1.0;
        float _1593 = _1577 * ((((1.5625 * _1585) * _1585) - 0.5625) * (_1587 * _1587));
        _1598 = _1557 + _1593;
        _1599 = _1558 + (_131[7] * _1593);
    }
    else
    {
        _1598 = _1557;
        _1599 = _1558;
    }
    float _1603 = exp((-2.2999999523162841796875) * dot(_1573, _1573)) * _1577;
    float3 _1607 = _131[7] * _1603;
    float2 _1614 = _896 + (_906 + float2(_1199));
    float _1618 = float(all(uint2(_1200) < _1293));
    float _1639;
    float3 _1640;
    if (_1297)
    {
        float2 _1622 = _1614 * float2(_1288);
        float _1624 = precise::min(dot(_1622, _1622), 4.0);
        float _1626 = (0.4000000059604644775390625 * _1624) - 1.0;
        float _1628 = (0.25 * _1624) - 1.0;
        float _1634 = _1618 * ((((1.5625 * _1626) * _1626) - 0.5625) * (_1628 * _1628));
        _1639 = _1598 + _1634;
        _1640 = _1599 + (_131[8] * _1634);
    }
    else
    {
        _1639 = _1598;
        _1640 = _1599;
    }
    float _1644 = exp((-2.2999999523162841796875) * dot(_1614, _1614)) * _1618;
    float3 _1648 = _131[8] * _1644;
    float _1652 = (((((((_1321 + _1357) + _1398) + _1439) + _1480) + _1521) + _1562) + _1603) + _1644;
    float3 _1656 = float3((abs(_1652) > 1.1754943508222875079687365372222e-38) ? _1652 : 1.0);
    float3 _1657 = ((((((((_1323 + _1361) + _1402) + _1443) + _1484) + _1525) + _1566) + _1607) + _1648) / _1656;
    float _1665 = _1639 * float(_1639 > 6.099999882280826568603515625e-05);
    float3 _1673;
    float _1674;
    if (_1665 > 6.099999882280826568603515625e-05)
    {
        _1673 = fast::clamp(_1640 / float3(_1665), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_131[0], _131[1]), _131[2]), _131[3]), _131[4]), _131[5]), _131[6]), _131[7]), _131[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_131[0], _131[1]), _131[2]), _131[3]), _131[4]), _131[5]), _131[6]), _131[7]), _131[8]));
        _1674 = _1665 * 0.04625000059604644775390625;
    }
    else
    {
        _1673 = _1640;
        _1674 = _1665;
    }
    float3 _1706;
    if (_907)
    {
        float _1677 = _1657.x;
        float _1678 = _1657.y;
        float _1680 = _1657.z;
        float _1681 = (_1677 + _1678) - _1680;
        float _1682 = _1677 + _1680;
        float _1684 = (_1677 - _1678) - _1680;
        float3 _1691 = float3(_1681, _1682, _1684) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1681, precise::max(_1682, _1684))));
        float _1692 = _1691.x;
        float _1695 = 0.5 * _1691.y;
        float _1697 = _1691.z;
        float _1698 = 0.25 * _1697;
        _1706 = float3(((0.25 * _1692) + _1695) + _1698, 0.5 * (_1692 - _1697), (((-0.25) * _1692) + _1695) - _1698);
    }
    else
    {
        _1706 = _1673;
    }
    float _1707 = _907 ? 1.0 : _1674;
    float _1708 = _907 ? 0.0 : _887;
    float3 _1722 = (sqrt(abs(((((((((((_131[0] * _1323) + (_131[1] * _1361)) + (_131[2] * _1402)) + (_131[3] * _1443)) + (_131[4] * _1484)) + (_131[5] * _1525)) + (_131[6] * _1566)) + (_131[7] * _1607)) + (_131[8] * _1648)) / _1656) - (_1657 * _1657))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_163 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_146 * _196, _196 - float2(0.5))) / float2(int2(int(_190.x), int(_190.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _230, precise::max(powr(_219, 0.5), _223)))));
    float3 _1725 = (_831 - _1657) / precise::max(_1722, float3(1.19299997436428384389728307724e-07));
    float3 _1740;
    if (length(_1725) > 1.0)
    {
        _1740 = mix((fast::normalize(_1725) * _1722) + _1657, _831, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_155, _150)) / _153), level(0.0)).x, fast::clamp(fast::clamp(_841 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _230) * (1.0 - _221), 0.0, 1.0)));
    }
    else
    {
        _1740 = _831;
    }
    float _1750 = (_1706.x + _1706.y) - _1706.z;
    float _1751 = _1706.x + _1706.z;
    float _1753 = (_1706.x - _1706.y) - _1706.z;
    float3 _1760 = float3(_1750, _1751, _1753) / float3(precise::max(precise::max(0.0, _1750), precise::max(_1751, _1753)) + 1.0);
    float _1761 = _1760.x;
    float _1764 = 0.5 * _1760.y;
    float _1766 = _1760.z;
    float _1767 = 0.25 * _1766;
    float _1779 = (_1740.x + _1740.y) - _1740.z;
    float _1780 = _1740.x + _1740.z;
    float _1782 = (_1740.x - _1740.y) - _1740.z;
    float3 _1789 = float3(_1779, _1780, _1782) / float3(precise::max(precise::max(0.0, _1779), precise::max(_1780, _1782)) + 1.0);
    float _1790 = _1789.x;
    float _1793 = 0.5 * _1789.y;
    float _1795 = _1789.z;
    float _1796 = 0.25 * _1795;
    float3 _1807 = mix(float3(((0.25 * _1790) + _1793) + _1796, 0.5 * (_1790 - _1795), (((-0.25) * _1790) + _1793) - _1796), float3(((0.25 * _1761) + _1764) + _1767, 0.5 * (_1761 - _1766), (((-0.25) * _1761) + _1764) - _1767), float3(fast::clamp(_1707 / precise::max(6.099999882280826568603515625e-05, (_1708 * float(_1708 > 6.099999882280826568603515625e-05)) + _1707), 0.0, 1.0)));
    float _1812 = (_1807.x + _1807.y) - _1807.z;
    float _1813 = _1807.x + _1807.z;
    float _1815 = (_1807.x - _1807.y) - _1807.z;
    float4 _1824 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1825 = _1824.x;
    float3 _1830 = precise::max((float3(_1812, _1813, _1815) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1812, precise::max(_1813, _1815))))) / float3((_1825 == 0.0) ? 1.0 : _1825), float3(0.0));
    float _1831 = _1830.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1831, _1830.yz, precise::max(0.0, precise::max(0.0, precise::min(_841 + (sdk_hlsl_load(rw_new_locks, uint2(_845)).x * (1.0 - precise::max(0.0, _219))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _838))) * float(_877)), uint2(_845));
    sdk_hlsl_store(rw_upscaled_output, float4(_1831, _1830.yz, 1.0), uint2(_845));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_845));
}

