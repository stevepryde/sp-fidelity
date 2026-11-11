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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float> r_farthest_depth_mip1 [[texture(3)]], texture2d<float> r_luma_instability [[texture(4)]], texture2d<float, access::read_write> rw_new_locks [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _132 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _135 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _136 = _132 / _135;
    float2 _141 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _143 = _136 + (cbFSR3Upscaler.fJitter / _141);
    float2 _147 = _141 - float2(0.5);
    float2 _150 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _152 = _136 * _141;
    float2 _158 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_152)))), 0u).xy;
    float _160 = length(_158 * float2(3840.0, 2160.0));
    float2 _161 = _136 + _158;
    float _162 = _161.x;
    bool _167;
    if (_162 >= 0.0)
    {
        _167 = _162 <= 1.0;
    }
    else
    {
        _167 = false;
    }
    bool _176;
    if (_167)
    {
        float _170 = _161.y;
        bool _175;
        if (_170 >= 0.0)
        {
            _175 = _170 <= 1.0;
        }
        else
        {
            _175 = false;
        }
        _176 = _175;
    }
    else
    {
        _176 = false;
    }
    uint2 _187 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _193 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _210;
    if (_176)
    {
        _210 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _210 = true;
    }
    float4 _214 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_143 * _141, _147)) / _150), level(0.0));
    float _216 = fast::clamp(_214.x, 0.0, 1.0);
    float _218 = fast::clamp(_214.y, 0.0, 1.0);
    float _220 = fast::clamp(_214.z, 0.0, 1.0);
    float _222 = fast::clamp(_214.w, 0.0, 1.0);
    float _227 = _222 * float(rint(_222 * 100.0) > 1.0);
    bool _231;
    if (_176)
    {
        _231 = !_210;
    }
    else
    {
        _231 = false;
    }
    float3 _828;
    float _829;
    if (_231)
    {
        float2 _235 = (_161 * _135) - float2(0.5);
        half2 _238 = half2(_235 - floor(_235));
        int2 _251 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _235.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _235.y)))));
        int2 _252 = _251 + int2(-1);
        int _254 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _258 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _266 = _251 + int2(0, -1);
        int2 _278 = _251 + int2(1, -1);
        int2 _290 = _251 + int2(2, -1);
        int2 _302 = _251 + int2(-1, 0);
        half4 _324 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_251.x, _254)), max(1, min(_251.y, _258))))), 0u));
        int2 _325 = _251 + int2(1, 0);
        half4 _336 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_325.x, _254)), max(1, min(_325.y, _258))))), 0u));
        int2 _337 = _251 + int2(2, 0);
        int2 _349 = _251 + int2(-1, 1);
        int2 _361 = _251 + int2(0, 1);
        half4 _372 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_361.x, _254)), max(1, min(_361.y, _258))))), 0u));
        int2 _373 = _251 + int2(1);
        half4 _384 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_373.x, _254)), max(1, min(_373.y, _258))))), 0u));
        int2 _385 = _251 + int2(2, 1);
        int2 _397 = _251 + int2(-1, 2);
        int2 _409 = _251 + int2(0, 2);
        int2 _421 = _251 + int2(1, 2);
        int2 _433 = _251 + int2(2);
        half _445 = _238.x;
        float _449 = float(min(abs(half(-1.0) - _445), half(2.0)));
        bool _451 = abs(_449) < 6.099999882280826568603515625e-05;
        float _462;
        if (_451)
        {
            _462 = 1.0;
        }
        else
        {
            float _455 = 3.1415927410125732421875 * _449;
            float _458 = 1.57079637050628662109375 * _449;
            _462 = (sin(_455) / _455) * (sin(_458) / _458);
        }
        half _463 = half(_462);
        float _467 = float(min(abs(half(-0.0) - _445), half(2.0)));
        bool _469 = abs(_467) < 6.099999882280826568603515625e-05;
        float _480;
        if (_469)
        {
            _480 = 1.0;
        }
        else
        {
            float _473 = 3.1415927410125732421875 * _467;
            float _476 = 1.57079637050628662109375 * _467;
            _480 = (sin(_473) / _473) * (sin(_476) / _476);
        }
        half _481 = half(_480);
        float _485 = float(min(abs(half(1.0) - _445), half(2.0)));
        bool _487 = abs(_485) < 6.099999882280826568603515625e-05;
        float _498;
        if (_487)
        {
            _498 = 1.0;
        }
        else
        {
            float _491 = 3.1415927410125732421875 * _485;
            float _494 = 1.57079637050628662109375 * _485;
            _498 = (sin(_491) / _491) * (sin(_494) / _494);
        }
        half _499 = half(_498);
        float _503 = float(min(abs(half(2.0) - _445), half(2.0)));
        bool _505 = abs(_503) < 6.099999882280826568603515625e-05;
        float _516;
        if (_505)
        {
            _516 = 1.0;
        }
        else
        {
            float _509 = 3.1415927410125732421875 * _503;
            float _512 = 1.57079637050628662109375 * _503;
            _516 = (sin(_509) / _509) * (sin(_512) / _512);
        }
        half _517 = half(_516);
        float _540;
        if (_451)
        {
            _540 = 1.0;
        }
        else
        {
            float _533 = 3.1415927410125732421875 * _449;
            float _536 = 1.57079637050628662109375 * _449;
            _540 = (sin(_533) / _533) * (sin(_536) / _536);
        }
        half _541 = half(_540);
        float _552;
        if (_469)
        {
            _552 = 1.0;
        }
        else
        {
            float _545 = 3.1415927410125732421875 * _467;
            float _548 = 1.57079637050628662109375 * _467;
            _552 = (sin(_545) / _545) * (sin(_548) / _548);
        }
        half _553 = half(_552);
        float _564;
        if (_487)
        {
            _564 = 1.0;
        }
        else
        {
            float _557 = 3.1415927410125732421875 * _485;
            float _560 = 1.57079637050628662109375 * _485;
            _564 = (sin(_557) / _557) * (sin(_560) / _560);
        }
        half _565 = half(_564);
        float _576;
        if (_505)
        {
            _576 = 1.0;
        }
        else
        {
            float _569 = 3.1415927410125732421875 * _503;
            float _572 = 1.57079637050628662109375 * _503;
            _576 = (sin(_569) / _569) * (sin(_572) / _572);
        }
        half _577 = half(_576);
        float _600;
        if (_451)
        {
            _600 = 1.0;
        }
        else
        {
            float _593 = 3.1415927410125732421875 * _449;
            float _596 = 1.57079637050628662109375 * _449;
            _600 = (sin(_593) / _593) * (sin(_596) / _596);
        }
        half _601 = half(_600);
        float _612;
        if (_469)
        {
            _612 = 1.0;
        }
        else
        {
            float _605 = 3.1415927410125732421875 * _467;
            float _608 = 1.57079637050628662109375 * _467;
            _612 = (sin(_605) / _605) * (sin(_608) / _608);
        }
        half _613 = half(_612);
        float _624;
        if (_487)
        {
            _624 = 1.0;
        }
        else
        {
            float _617 = 3.1415927410125732421875 * _485;
            float _620 = 1.57079637050628662109375 * _485;
            _624 = (sin(_617) / _617) * (sin(_620) / _620);
        }
        half _625 = half(_624);
        float _636;
        if (_505)
        {
            _636 = 1.0;
        }
        else
        {
            float _629 = 3.1415927410125732421875 * _503;
            float _632 = 1.57079637050628662109375 * _503;
            _636 = (sin(_629) / _629) * (sin(_632) / _632);
        }
        half _637 = half(_636);
        float _660;
        if (_451)
        {
            _660 = 1.0;
        }
        else
        {
            float _653 = 3.1415927410125732421875 * _449;
            float _656 = 1.57079637050628662109375 * _449;
            _660 = (sin(_653) / _653) * (sin(_656) / _656);
        }
        half _661 = half(_660);
        float _672;
        if (_469)
        {
            _672 = 1.0;
        }
        else
        {
            float _665 = 3.1415927410125732421875 * _467;
            float _668 = 1.57079637050628662109375 * _467;
            _672 = (sin(_665) / _665) * (sin(_668) / _668);
        }
        half _673 = half(_672);
        float _684;
        if (_487)
        {
            _684 = 1.0;
        }
        else
        {
            float _677 = 3.1415927410125732421875 * _485;
            float _680 = 1.57079637050628662109375 * _485;
            _684 = (sin(_677) / _677) * (sin(_680) / _680);
        }
        half _685 = half(_684);
        float _696;
        if (_505)
        {
            _696 = 1.0;
        }
        else
        {
            float _689 = 3.1415927410125732421875 * _503;
            float _692 = 1.57079637050628662109375 * _503;
            _696 = (sin(_689) / _689) * (sin(_692) / _692);
        }
        half _697 = half(_696);
        half _710 = _238.y;
        float _714 = float(min(abs(half(-1.0) - _710), half(2.0)));
        float _727;
        if (abs(_714) < 6.099999882280826568603515625e-05)
        {
            _727 = 1.0;
        }
        else
        {
            float _720 = 3.1415927410125732421875 * _714;
            float _723 = 1.57079637050628662109375 * _714;
            _727 = (sin(_720) / _720) * (sin(_723) / _723);
        }
        half _728 = half(_727);
        float _732 = float(min(abs(half(-0.0) - _710), half(2.0)));
        float _745;
        if (abs(_732) < 6.099999882280826568603515625e-05)
        {
            _745 = 1.0;
        }
        else
        {
            float _738 = 3.1415927410125732421875 * _732;
            float _741 = 1.57079637050628662109375 * _732;
            _745 = (sin(_738) / _738) * (sin(_741) / _741);
        }
        half _746 = half(_745);
        float _750 = float(min(abs(half(1.0) - _710), half(2.0)));
        float _763;
        if (abs(_750) < 6.099999882280826568603515625e-05)
        {
            _763 = 1.0;
        }
        else
        {
            float _756 = 3.1415927410125732421875 * _750;
            float _759 = 1.57079637050628662109375 * _750;
            _763 = (sin(_756) / _756) * (sin(_759) / _759);
        }
        half _764 = half(_763);
        float _768 = float(min(abs(half(2.0) - _710), half(2.0)));
        float _781;
        if (abs(_768) < 6.099999882280826568603515625e-05)
        {
            _781 = 1.0;
        }
        else
        {
            float _774 = 3.1415927410125732421875 * _768;
            float _777 = 1.57079637050628662109375 * _768;
            _781 = (sin(_774) / _774) * (sin(_777) / _777);
        }
        half _782 = half(_781);
        half4 _787 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_252.x, _254)), max(1, min(_252.y, _258))))), 0u)) * _463) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_266.x, _254)), max(1, min(_266.y, _258))))), 0u)) * _481)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_278.x, _254)), max(1, min(_278.y, _258))))), 0u)) * _499)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_290.x, _254)), max(1, min(_290.y, _258))))), 0u)) * _517)) / half4(((_463 + _481) + _499) + _517)) * _728) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_302.x, _254)), max(1, min(_302.y, _258))))), 0u)) * _541) + (_324 * _553)) + (_336 * _565)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_337.x, _254)), max(1, min(_337.y, _258))))), 0u)) * _577)) / half4(((_541 + _553) + _565) + _577)) * _746)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_349.x, _254)), max(1, min(_349.y, _258))))), 0u)) * _601) + (_372 * _613)) + (_384 * _625)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_385.x, _254)), max(1, min(_385.y, _258))))), 0u)) * _637)) / half4(((_601 + _613) + _625) + _637)) * _764);
        half4 _794 = (_787 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_397.x, _254)), max(1, min(_397.y, _258))))), 0u)) * _661) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_409.x, _254)), max(1, min(_409.y, _258))))), 0u)) * _673)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_421.x, _254)), max(1, min(_421.y, _258))))), 0u)) * _685)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_433.x, _254)), max(1, min(_433.y, _258))))), 0u)) * _697)) / half4(((_661 + _673) + _685) + _697)) * _782)) / half4(((_728 + _746) + _764) + _782);
        float4 _802 = float4(clamp(_794, min(min(min(_324, _336), _372), _384), max(max(max(_324, _336), _372), _384)));
        float4 _808 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _809 = _808.x;
        float3 _812 = (_802.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_809 == 0.0) ? 1.0 : _809);
        float _816 = 0.5 * _812.y;
        float _819 = 0.25 * _812.z;
        _828 = float3(((0.25 * _812.x) + _816) + _819, 0.5 * (_812.x - _812.z), (((-0.25) * _812.x) + _816) - _819);
        _829 = _802.w;
    }
    else
    {
        _828 = float3(0.0);
        _829 = 0.0;
    }
    float _835 = precise::max(fast::clamp(_220, 0.0, 1.0), precise::max(_216, _218));
    float _838 = precise::max(0.0, (_829 * float(!_210)) - (_835 * 2.0));
    uint2 _842 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _859 = _136 - _158;
    float _860 = _859.x;
    bool _865;
    if (_860 >= 0.0)
    {
        _865 = _860 <= 1.0;
    }
    else
    {
        _865 = false;
    }
    bool _874;
    if (_865)
    {
        float _868 = _859.y;
        bool _873;
        if (_868 >= 0.0)
        {
            _873 = _868 <= 1.0;
        }
        else
        {
            _873 = false;
        }
        _874 = _873;
    }
    else
    {
        _874 = false;
    }
    float _884 = precise::min(_227, mix(_227, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_160 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _887 = _132 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _889 = int2(floor(_887));
    float2 _892 = (float2(_889) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _893 = _892 - _887;
    bool _896 = _892.x > _887.x;
    bool _900 = _892.y > _887.y;
    int2 _902 = int2(_896 ? (-2) : (-1), _900 ? (-2) : (-1));
    float2 _903 = float2(_902);
    bool _904 = _227 == 0.0;
    int _905 = _896 ? 3 : 0;
    int _906 = _900 ? 3 : 0;
    int2 _907 = int2(_905, _906);
    int2 _908 = _889 + _902;
    int2 _909 = _908 + _907;
    int _912 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _917 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _927 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _928 = _927.x;
    float3 _931 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_909.x, _912)), max(0, min(_909.y, _917))))), 0u).xyz) * ((_928 == 0.0) ? 1.0 : _928);
    float _932 = _931.x;
    float _935 = 0.5 * _931.y;
    float _937 = _931.z;
    float _938 = 0.25 * _937;
    spvUnsafeArray<float3, 9> _128;
    _128[0] = float3(((0.25 * _932) + _935) + _938, 0.5 * (_932 - _937), (((-0.25) * _932) + _935) - _938);
    int _947 = _896 ? 2 : 1;
    int2 _948 = int2(_947, _906);
    int2 _949 = _908 + _948;
    float4 _963 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _964 = _963.x;
    float3 _967 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_949.x, _912)), max(0, min(_949.y, _917))))), 0u).xyz) * ((_964 == 0.0) ? 1.0 : _964);
    float _968 = _967.x;
    float _971 = 0.5 * _967.y;
    float _973 = _967.z;
    float _974 = 0.25 * _973;
    _128[1] = float3(((0.25 * _968) + _971) + _974, 0.5 * (_968 - _973), (((-0.25) * _968) + _971) - _974);
    int _983 = _896 ? 1 : 2;
    int2 _984 = int2(_983, _906);
    int2 _985 = _908 + _984;
    float4 _999 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1000 = _999.x;
    float3 _1003 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_985.x, _912)), max(0, min(_985.y, _917))))), 0u).xyz) * ((_1000 == 0.0) ? 1.0 : _1000);
    float _1004 = _1003.x;
    float _1007 = 0.5 * _1003.y;
    float _1009 = _1003.z;
    float _1010 = 0.25 * _1009;
    _128[2] = float3(((0.25 * _1004) + _1007) + _1010, 0.5 * (_1004 - _1009), (((-0.25) * _1004) + _1007) - _1010);
    int _1019 = _900 ? 2 : 1;
    int2 _1020 = int2(_905, _1019);
    int2 _1021 = _908 + _1020;
    float4 _1035 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1036 = _1035.x;
    float3 _1039 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1021.x, _912)), max(0, min(_1021.y, _917))))), 0u).xyz) * ((_1036 == 0.0) ? 1.0 : _1036);
    float _1040 = _1039.x;
    float _1043 = 0.5 * _1039.y;
    float _1045 = _1039.z;
    float _1046 = 0.25 * _1045;
    _128[3] = float3(((0.25 * _1040) + _1043) + _1046, 0.5 * (_1040 - _1045), (((-0.25) * _1040) + _1043) - _1046);
    int2 _1055 = int2(_947, _1019);
    int2 _1056 = _908 + _1055;
    float4 _1070 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1071 = _1070.x;
    float3 _1074 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1056.x, _912)), max(0, min(_1056.y, _917))))), 0u).xyz) * ((_1071 == 0.0) ? 1.0 : _1071);
    float _1075 = _1074.x;
    float _1078 = 0.5 * _1074.y;
    float _1080 = _1074.z;
    float _1081 = 0.25 * _1080;
    _128[4] = float3(((0.25 * _1075) + _1078) + _1081, 0.5 * (_1075 - _1080), (((-0.25) * _1075) + _1078) - _1081);
    int2 _1090 = int2(_983, _1019);
    int2 _1091 = _908 + _1090;
    float4 _1105 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1106 = _1105.x;
    float3 _1109 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1091.x, _912)), max(0, min(_1091.y, _917))))), 0u).xyz) * ((_1106 == 0.0) ? 1.0 : _1106);
    float _1110 = _1109.x;
    float _1113 = 0.5 * _1109.y;
    float _1115 = _1109.z;
    float _1116 = 0.25 * _1115;
    _128[5] = float3(((0.25 * _1110) + _1113) + _1116, 0.5 * (_1110 - _1115), (((-0.25) * _1110) + _1113) - _1116);
    int _1125 = _900 ? 1 : 2;
    int2 _1126 = int2(_905, _1125);
    int2 _1127 = _908 + _1126;
    float4 _1141 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1142 = _1141.x;
    float3 _1145 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1127.x, _912)), max(0, min(_1127.y, _917))))), 0u).xyz) * ((_1142 == 0.0) ? 1.0 : _1142);
    float _1146 = _1145.x;
    float _1149 = 0.5 * _1145.y;
    float _1151 = _1145.z;
    float _1152 = 0.25 * _1151;
    _128[6] = float3(((0.25 * _1146) + _1149) + _1152, 0.5 * (_1146 - _1151), (((-0.25) * _1146) + _1149) - _1152);
    int2 _1161 = int2(_947, _1125);
    int2 _1162 = _908 + _1161;
    float4 _1176 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1177 = _1176.x;
    float3 _1180 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1162.x, _912)), max(0, min(_1162.y, _917))))), 0u).xyz) * ((_1177 == 0.0) ? 1.0 : _1177);
    float _1181 = _1180.x;
    float _1184 = 0.5 * _1180.y;
    float _1186 = _1180.z;
    float _1187 = 0.25 * _1186;
    _128[7] = float3(((0.25 * _1181) + _1184) + _1187, 0.5 * (_1181 - _1186), (((-0.25) * _1181) + _1184) - _1187);
    int2 _1196 = int2(_983, _1125);
    int2 _1197 = _908 + _1196;
    float4 _1211 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1212 = _1211.x;
    float3 _1215 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1197.x, _912)), max(0, min(_1197.y, _917))))), 0u).xyz) * ((_1212 == 0.0) ? 1.0 : _1212);
    float _1216 = _1215.x;
    float _1219 = 0.5 * _1215.y;
    float _1221 = _1215.z;
    float _1222 = 0.25 * _1221;
    _128[8] = float3(((0.25 * _1216) + _1219) + _1222, 0.5 * (_1216 - _1221), (((-0.25) * _1216) + _1219) - _1222);
    if (_904)
    {
        for (int _1234 = 0; _1234 < 9; )
        {
            float _1245 = (_128[_1234].x + _128[_1234].y) - _128[_1234].z;
            float _1246 = _128[_1234].x + _128[_1234].z;
            float _1248 = (_128[_1234].x - _128[_1234].y) - _128[_1234].z;
            float3 _1255 = float3(_1245, _1246, _1248) / float3(precise::max(precise::max(0.0, _1245), precise::max(_1246, _1248)) + 1.0);
            float _1256 = _1255.x;
            float _1259 = 0.5 * _1255.y;
            float _1261 = _1255.z;
            float _1262 = 0.25 * _1261;
            _128[_1234] = float3(((0.25 * _1256) + _1259) + _1262, 0.5 * (_1256 - _1261), (((-0.25) * _1256) + _1259) - _1262);
            _1234++;
            continue;
        }
    }
    float _1274 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1285 = mix(precise::max(1.0, (1.0 + _1274) * 0.300000011920928955078125), _1274, precise::min(1.0 - (_218 * 0.5), precise::min(1.0 - _220, fast::clamp(_884 * 5.0, 0.0, 1.0))));
    float2 _1288 = _893 + (_903 + float2(_907));
    uint2 _1290 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1293 = float(all(uint2(_909) < _1290));
    bool _1294 = !_904;
    float _1313;
    float3 _1314;
    if (_1294)
    {
        float2 _1298 = _1288 * float2(_1285);
        float _1300 = precise::min(dot(_1298, _1298), 4.0);
        float _1302 = (0.4000000059604644775390625 * _1300) - 1.0;
        float _1304 = (0.25 * _1300) - 1.0;
        float _1310 = _1293 * ((((1.5625 * _1302) * _1302) - 0.5625) * (_1304 * _1304));
        _1313 = _1310;
        _1314 = _128[0] * _1310;
    }
    else
    {
        _1313 = 0.0;
        _1314 = float3(0.0);
    }
    float _1318 = exp((-2.2999999523162841796875) * dot(_1288, _1288)) * _1293;
    float3 _1320 = _128[0] * _1318;
    float2 _1324 = _893 + (_903 + float2(_948));
    float _1328 = float(all(uint2(_949) < _1290));
    float _1349;
    float3 _1350;
    if (_1294)
    {
        float2 _1332 = _1324 * float2(_1285);
        float _1334 = precise::min(dot(_1332, _1332), 4.0);
        float _1336 = (0.4000000059604644775390625 * _1334) - 1.0;
        float _1338 = (0.25 * _1334) - 1.0;
        float _1344 = _1328 * ((((1.5625 * _1336) * _1336) - 0.5625) * (_1338 * _1338));
        _1349 = _1313 + _1344;
        _1350 = _1314 + (_128[1] * _1344);
    }
    else
    {
        _1349 = _1313;
        _1350 = _1314;
    }
    float _1354 = exp((-2.2999999523162841796875) * dot(_1324, _1324)) * _1328;
    float3 _1358 = _128[1] * _1354;
    float2 _1365 = _893 + (_903 + float2(_984));
    float _1369 = float(all(uint2(_985) < _1290));
    float _1390;
    float3 _1391;
    if (_1294)
    {
        float2 _1373 = _1365 * float2(_1285);
        float _1375 = precise::min(dot(_1373, _1373), 4.0);
        float _1377 = (0.4000000059604644775390625 * _1375) - 1.0;
        float _1379 = (0.25 * _1375) - 1.0;
        float _1385 = _1369 * ((((1.5625 * _1377) * _1377) - 0.5625) * (_1379 * _1379));
        _1390 = _1349 + _1385;
        _1391 = _1350 + (_128[2] * _1385);
    }
    else
    {
        _1390 = _1349;
        _1391 = _1350;
    }
    float _1395 = exp((-2.2999999523162841796875) * dot(_1365, _1365)) * _1369;
    float3 _1399 = _128[2] * _1395;
    float2 _1406 = _893 + (_903 + float2(_1020));
    float _1410 = float(all(uint2(_1021) < _1290));
    float _1431;
    float3 _1432;
    if (_1294)
    {
        float2 _1414 = _1406 * float2(_1285);
        float _1416 = precise::min(dot(_1414, _1414), 4.0);
        float _1418 = (0.4000000059604644775390625 * _1416) - 1.0;
        float _1420 = (0.25 * _1416) - 1.0;
        float _1426 = _1410 * ((((1.5625 * _1418) * _1418) - 0.5625) * (_1420 * _1420));
        _1431 = _1390 + _1426;
        _1432 = _1391 + (_128[3] * _1426);
    }
    else
    {
        _1431 = _1390;
        _1432 = _1391;
    }
    float _1436 = exp((-2.2999999523162841796875) * dot(_1406, _1406)) * _1410;
    float3 _1440 = _128[3] * _1436;
    float2 _1447 = _893 + (_903 + float2(_1055));
    float _1451 = float(all(uint2(_1056) < _1290));
    float _1472;
    float3 _1473;
    if (_1294)
    {
        float2 _1455 = _1447 * float2(_1285);
        float _1457 = precise::min(dot(_1455, _1455), 4.0);
        float _1459 = (0.4000000059604644775390625 * _1457) - 1.0;
        float _1461 = (0.25 * _1457) - 1.0;
        float _1467 = _1451 * ((((1.5625 * _1459) * _1459) - 0.5625) * (_1461 * _1461));
        _1472 = _1431 + _1467;
        _1473 = _1432 + (_128[4] * _1467);
    }
    else
    {
        _1472 = _1431;
        _1473 = _1432;
    }
    float _1477 = exp((-2.2999999523162841796875) * dot(_1447, _1447)) * _1451;
    float3 _1481 = _128[4] * _1477;
    float2 _1488 = _893 + (_903 + float2(_1090));
    float _1492 = float(all(uint2(_1091) < _1290));
    float _1513;
    float3 _1514;
    if (_1294)
    {
        float2 _1496 = _1488 * float2(_1285);
        float _1498 = precise::min(dot(_1496, _1496), 4.0);
        float _1500 = (0.4000000059604644775390625 * _1498) - 1.0;
        float _1502 = (0.25 * _1498) - 1.0;
        float _1508 = _1492 * ((((1.5625 * _1500) * _1500) - 0.5625) * (_1502 * _1502));
        _1513 = _1472 + _1508;
        _1514 = _1473 + (_128[5] * _1508);
    }
    else
    {
        _1513 = _1472;
        _1514 = _1473;
    }
    float _1518 = exp((-2.2999999523162841796875) * dot(_1488, _1488)) * _1492;
    float3 _1522 = _128[5] * _1518;
    float2 _1529 = _893 + (_903 + float2(_1126));
    float _1533 = float(all(uint2(_1127) < _1290));
    float _1554;
    float3 _1555;
    if (_1294)
    {
        float2 _1537 = _1529 * float2(_1285);
        float _1539 = precise::min(dot(_1537, _1537), 4.0);
        float _1541 = (0.4000000059604644775390625 * _1539) - 1.0;
        float _1543 = (0.25 * _1539) - 1.0;
        float _1549 = _1533 * ((((1.5625 * _1541) * _1541) - 0.5625) * (_1543 * _1543));
        _1554 = _1513 + _1549;
        _1555 = _1514 + (_128[6] * _1549);
    }
    else
    {
        _1554 = _1513;
        _1555 = _1514;
    }
    float _1559 = exp((-2.2999999523162841796875) * dot(_1529, _1529)) * _1533;
    float3 _1563 = _128[6] * _1559;
    float2 _1570 = _893 + (_903 + float2(_1161));
    float _1574 = float(all(uint2(_1162) < _1290));
    float _1595;
    float3 _1596;
    if (_1294)
    {
        float2 _1578 = _1570 * float2(_1285);
        float _1580 = precise::min(dot(_1578, _1578), 4.0);
        float _1582 = (0.4000000059604644775390625 * _1580) - 1.0;
        float _1584 = (0.25 * _1580) - 1.0;
        float _1590 = _1574 * ((((1.5625 * _1582) * _1582) - 0.5625) * (_1584 * _1584));
        _1595 = _1554 + _1590;
        _1596 = _1555 + (_128[7] * _1590);
    }
    else
    {
        _1595 = _1554;
        _1596 = _1555;
    }
    float _1600 = exp((-2.2999999523162841796875) * dot(_1570, _1570)) * _1574;
    float3 _1604 = _128[7] * _1600;
    float2 _1611 = _893 + (_903 + float2(_1196));
    float _1615 = float(all(uint2(_1197) < _1290));
    float _1636;
    float3 _1637;
    if (_1294)
    {
        float2 _1619 = _1611 * float2(_1285);
        float _1621 = precise::min(dot(_1619, _1619), 4.0);
        float _1623 = (0.4000000059604644775390625 * _1621) - 1.0;
        float _1625 = (0.25 * _1621) - 1.0;
        float _1631 = _1615 * ((((1.5625 * _1623) * _1623) - 0.5625) * (_1625 * _1625));
        _1636 = _1595 + _1631;
        _1637 = _1596 + (_128[8] * _1631);
    }
    else
    {
        _1636 = _1595;
        _1637 = _1596;
    }
    float _1641 = exp((-2.2999999523162841796875) * dot(_1611, _1611)) * _1615;
    float3 _1645 = _128[8] * _1641;
    float _1649 = (((((((_1318 + _1354) + _1395) + _1436) + _1477) + _1518) + _1559) + _1600) + _1641;
    float3 _1653 = float3((abs(_1649) > 1.1754943508222875079687365372222e-38) ? _1649 : 1.0);
    float3 _1654 = ((((((((_1320 + _1358) + _1399) + _1440) + _1481) + _1522) + _1563) + _1604) + _1645) / _1653;
    float _1662 = _1636 * float(_1636 > 6.099999882280826568603515625e-05);
    float3 _1670;
    float _1671;
    if (_1662 > 6.099999882280826568603515625e-05)
    {
        _1670 = fast::clamp(_1637 / float3(_1662), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_128[0], _128[1]), _128[2]), _128[3]), _128[4]), _128[5]), _128[6]), _128[7]), _128[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_128[0], _128[1]), _128[2]), _128[3]), _128[4]), _128[5]), _128[6]), _128[7]), _128[8]));
        _1671 = _1662 * 0.04625000059604644775390625;
    }
    else
    {
        _1670 = _1637;
        _1671 = _1662;
    }
    float3 _1703;
    if (_904)
    {
        float _1674 = _1654.x;
        float _1675 = _1654.y;
        float _1677 = _1654.z;
        float _1678 = (_1674 + _1675) - _1677;
        float _1679 = _1674 + _1677;
        float _1681 = (_1674 - _1675) - _1677;
        float3 _1688 = float3(_1678, _1679, _1681) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1678, precise::max(_1679, _1681))));
        float _1689 = _1688.x;
        float _1692 = 0.5 * _1688.y;
        float _1694 = _1688.z;
        float _1695 = 0.25 * _1694;
        _1703 = float3(((0.25 * _1689) + _1692) + _1695, 0.5 * (_1689 - _1694), (((-0.25) * _1689) + _1692) - _1695);
    }
    else
    {
        _1703 = _1670;
    }
    float _1704 = _904 ? 1.0 : _1671;
    float _1705 = _904 ? 0.0 : _884;
    float3 _1719 = (sqrt(abs(((((((((((_128[0] * _1320) + (_128[1] * _1358)) + (_128[2] * _1399)) + (_128[3] * _1440)) + (_128[4] * _1481)) + (_128[5] * _1522)) + (_128[6] * _1563)) + (_128[7] * _1604)) + (_128[8] * _1645)) / _1653) - (_1654 * _1654))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_160 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_143 * _193, _193 - float2(0.5))) / float2(int2(int(_187.x), int(_187.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _227, precise::max(powr(_216, 0.5), _220)))));
    float3 _1722 = (_828 - _1654) / precise::max(_1719, float3(1.19299997436428384389728307724e-07));
    float3 _1737;
    if (length(_1722) > 1.0)
    {
        _1737 = mix((fast::normalize(_1722) * _1719) + _1654, _828, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_152, _147)) / _150), level(0.0)).x, fast::clamp(fast::clamp(_838 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _227) * (1.0 - _218), 0.0, 1.0)));
    }
    else
    {
        _1737 = _828;
    }
    float _1747 = (_1703.x + _1703.y) - _1703.z;
    float _1748 = _1703.x + _1703.z;
    float _1750 = (_1703.x - _1703.y) - _1703.z;
    float3 _1757 = float3(_1747, _1748, _1750) / float3(precise::max(precise::max(0.0, _1747), precise::max(_1748, _1750)) + 1.0);
    float _1758 = _1757.x;
    float _1761 = 0.5 * _1757.y;
    float _1763 = _1757.z;
    float _1764 = 0.25 * _1763;
    float _1776 = (_1737.x + _1737.y) - _1737.z;
    float _1777 = _1737.x + _1737.z;
    float _1779 = (_1737.x - _1737.y) - _1737.z;
    float3 _1786 = float3(_1776, _1777, _1779) / float3(precise::max(precise::max(0.0, _1776), precise::max(_1777, _1779)) + 1.0);
    float _1787 = _1786.x;
    float _1790 = 0.5 * _1786.y;
    float _1792 = _1786.z;
    float _1793 = 0.25 * _1792;
    float3 _1804 = mix(float3(((0.25 * _1787) + _1790) + _1793, 0.5 * (_1787 - _1792), (((-0.25) * _1787) + _1790) - _1793), float3(((0.25 * _1758) + _1761) + _1764, 0.5 * (_1758 - _1763), (((-0.25) * _1758) + _1761) - _1764), float3(fast::clamp(_1704 / precise::max(6.099999882280826568603515625e-05, (_1705 * float(_1705 > 6.099999882280826568603515625e-05)) + _1704), 0.0, 1.0)));
    float _1809 = (_1804.x + _1804.y) - _1804.z;
    float _1810 = _1804.x + _1804.z;
    float _1812 = (_1804.x - _1804.y) - _1804.z;
    float4 _1821 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1822 = _1821.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max((float3(_1809, _1810, _1812) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1809, precise::max(_1810, _1812))))) / float3((_1822 == 0.0) ? 1.0 : _1822), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_838 + (sdk_hlsl_load(rw_new_locks, uint2(_842)).x * (1.0 - precise::max(0.0, _216))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _835))) * float(_874)), uint2(_842));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_842));
}

