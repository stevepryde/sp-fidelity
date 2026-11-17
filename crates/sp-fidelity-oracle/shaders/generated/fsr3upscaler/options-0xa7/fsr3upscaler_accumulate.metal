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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float> r_farthest_depth_mip1 [[texture(3)]], texture2d<float> r_luma_instability [[texture(4)]], texture2d<float, access::read_write> rw_new_locks [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_lanczos_lut [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _131 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _134 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _135 = _131 / _134;
    float2 _140 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _142 = _135 + (cbFSR3Upscaler.fJitter / _140);
    float2 _146 = _140 - float2(0.5);
    float2 _149 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _151 = _135 * _140;
    float2 _157 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_151)))), 0u).xy;
    float _159 = length(_157 * float2(3840.0, 2160.0));
    float2 _160 = _135 + _157;
    float _161 = _160.x;
    bool _166;
    if (_161 >= 0.0)
    {
        _166 = _161 <= 1.0;
    }
    else
    {
        _166 = false;
    }
    bool _175;
    if (_166)
    {
        float _169 = _160.y;
        bool _174;
        if (_169 >= 0.0)
        {
            _174 = _169 <= 1.0;
        }
        else
        {
            _174 = false;
        }
        _175 = _174;
    }
    else
    {
        _175 = false;
    }
    uint2 _186 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _192 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _209;
    if (_175)
    {
        _209 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _209 = true;
    }
    float4 _213 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_142 * _140, _146)) / _149), level(0.0));
    float _215 = fast::clamp(_213.x, 0.0, 1.0);
    float _217 = fast::clamp(_213.y, 0.0, 1.0);
    float _219 = fast::clamp(_213.z, 0.0, 1.0);
    float _221 = fast::clamp(_213.w, 0.0, 1.0);
    float _226 = _221 * float(rint(_221 * 100.0) > 1.0);
    bool _230;
    if (_175)
    {
        _230 = !_209;
    }
    else
    {
        _230 = false;
    }
    float3 _699;
    float _700;
    if (_230)
    {
        float2 _234 = (_160 * _134) - float2(0.5);
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
        float2 _451 = float2(float(abs(half(-1.0) - _444)) * 0.5, 0.5);
        half _455 = half(r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0)).x);
        float2 _462 = float2(float(abs(half(-0.0) - _444)) * 0.5, 0.5);
        half _466 = half(r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0)).x);
        float2 _473 = float2(float(abs(half(1.0) - _444)) * 0.5, 0.5);
        half _477 = half(r_lanczos_lut.sample(s_LinearClamp, _473, level(0.0)).x);
        float2 _484 = float2(float(abs(half(2.0) - _444)) * 0.5, 0.5);
        half _488 = half(r_lanczos_lut.sample(s_LinearClamp, _484, level(0.0)).x);
        half _506 = half(r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0)).x);
        half _512 = half(r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0)).x);
        half _518 = half(r_lanczos_lut.sample(s_LinearClamp, _473, level(0.0)).x);
        half _524 = half(r_lanczos_lut.sample(s_LinearClamp, _484, level(0.0)).x);
        half _542 = half(r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0)).x);
        half _548 = half(r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0)).x);
        half _554 = half(r_lanczos_lut.sample(s_LinearClamp, _473, level(0.0)).x);
        half _560 = half(r_lanczos_lut.sample(s_LinearClamp, _484, level(0.0)).x);
        half _578 = half(r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0)).x);
        half _584 = half(r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0)).x);
        half _590 = half(r_lanczos_lut.sample(s_LinearClamp, _473, level(0.0)).x);
        half _596 = half(r_lanczos_lut.sample(s_LinearClamp, _484, level(0.0)).x);
        half _609 = _237.y;
        half _620 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-1.0) - _609)) * 0.5, 0.5), level(0.0)).x);
        half _631 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-0.0) - _609)) * 0.5, 0.5), level(0.0)).x);
        half _642 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(1.0) - _609)) * 0.5, 0.5), level(0.0)).x);
        half _653 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(2.0) - _609)) * 0.5, 0.5), level(0.0)).x);
        half4 _658 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_251.x, _253)), max(1, min(_251.y, _257))))), 0u)) * _455) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_265.x, _253)), max(1, min(_265.y, _257))))), 0u)) * _466)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_277.x, _253)), max(1, min(_277.y, _257))))), 0u)) * _477)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_289.x, _253)), max(1, min(_289.y, _257))))), 0u)) * _488)) / half4(((_455 + _466) + _477) + _488)) * _620) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_301.x, _253)), max(1, min(_301.y, _257))))), 0u)) * _506) + (_323 * _512)) + (_335 * _518)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_336.x, _253)), max(1, min(_336.y, _257))))), 0u)) * _524)) / half4(((_506 + _512) + _518) + _524)) * _631)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_348.x, _253)), max(1, min(_348.y, _257))))), 0u)) * _542) + (_371 * _548)) + (_383 * _554)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_384.x, _253)), max(1, min(_384.y, _257))))), 0u)) * _560)) / half4(((_542 + _548) + _554) + _560)) * _642);
        half4 _665 = (_658 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_396.x, _253)), max(1, min(_396.y, _257))))), 0u)) * _578) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_408.x, _253)), max(1, min(_408.y, _257))))), 0u)) * _584)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_420.x, _253)), max(1, min(_420.y, _257))))), 0u)) * _590)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_432.x, _253)), max(1, min(_432.y, _257))))), 0u)) * _596)) / half4(((_578 + _584) + _590) + _596)) * _653)) / half4(((_620 + _631) + _642) + _653);
        float4 _673 = float4(clamp(_665, min(min(min(_323, _335), _371), _383), max(max(max(_323, _335), _371), _383)));
        float4 _679 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _680 = _679.x;
        float3 _683 = (_673.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_680 == 0.0) ? 1.0 : _680);
        float _684 = _683.x;
        float _687 = 0.5 * _683.y;
        float _689 = _683.z;
        float _690 = 0.25 * _689;
        _699 = float3(((0.25 * _684) + _687) + _690, 0.5 * (_684 - _689), (((-0.25) * _684) + _687) - _690);
        _700 = _673.w;
    }
    else
    {
        _699 = float3(0.0);
        _700 = 0.0;
    }
    float _706 = precise::max(fast::clamp(_219, 0.0, 1.0), precise::max(_215, _217));
    float _709 = precise::max(0.0, (_700 * float(!_209)) - (_706 * 2.0));
    uint2 _713 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _730 = _135 - _157;
    float _731 = _730.x;
    bool _736;
    if (_731 >= 0.0)
    {
        _736 = _731 <= 1.0;
    }
    else
    {
        _736 = false;
    }
    bool _745;
    if (_736)
    {
        float _739 = _730.y;
        bool _744;
        if (_739 >= 0.0)
        {
            _744 = _739 <= 1.0;
        }
        else
        {
            _744 = false;
        }
        _745 = _744;
    }
    else
    {
        _745 = false;
    }
    float _755 = precise::min(_226, mix(_226, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_159 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _758 = _131 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _760 = int2(floor(_758));
    float2 _763 = (float2(_760) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _764 = _763 - _758;
    bool _767 = _763.x > _758.x;
    bool _771 = _763.y > _758.y;
    int2 _773 = int2(_767 ? (-2) : (-1), _771 ? (-2) : (-1));
    float2 _774 = float2(_773);
    bool _775 = _226 == 0.0;
    int _776 = _767 ? 3 : 0;
    int _777 = _771 ? 3 : 0;
    int2 _778 = int2(_776, _777);
    int2 _779 = _760 + _773;
    int2 _780 = _779 + _778;
    int _783 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _788 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _798 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _799 = _798.x;
    float3 _802 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_780.x, _783)), max(0, min(_780.y, _788))))), 0u).xyz) * ((_799 == 0.0) ? 1.0 : _799);
    float _803 = _802.x;
    float _806 = 0.5 * _802.y;
    float _808 = _802.z;
    float _809 = 0.25 * _808;
    spvUnsafeArray<float3, 9> _127;
    _127[0] = float3(((0.25 * _803) + _806) + _809, 0.5 * (_803 - _808), (((-0.25) * _803) + _806) - _809);
    int _818 = _767 ? 2 : 1;
    int2 _819 = int2(_818, _777);
    int2 _820 = _779 + _819;
    float4 _834 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _835 = _834.x;
    float3 _838 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_820.x, _783)), max(0, min(_820.y, _788))))), 0u).xyz) * ((_835 == 0.0) ? 1.0 : _835);
    float _839 = _838.x;
    float _842 = 0.5 * _838.y;
    float _844 = _838.z;
    float _845 = 0.25 * _844;
    _127[1] = float3(((0.25 * _839) + _842) + _845, 0.5 * (_839 - _844), (((-0.25) * _839) + _842) - _845);
    int _854 = _767 ? 1 : 2;
    int2 _855 = int2(_854, _777);
    int2 _856 = _779 + _855;
    float4 _870 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _871 = _870.x;
    float3 _874 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_856.x, _783)), max(0, min(_856.y, _788))))), 0u).xyz) * ((_871 == 0.0) ? 1.0 : _871);
    float _875 = _874.x;
    float _878 = 0.5 * _874.y;
    float _880 = _874.z;
    float _881 = 0.25 * _880;
    _127[2] = float3(((0.25 * _875) + _878) + _881, 0.5 * (_875 - _880), (((-0.25) * _875) + _878) - _881);
    int _890 = _771 ? 2 : 1;
    int2 _891 = int2(_776, _890);
    int2 _892 = _779 + _891;
    float4 _906 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _907 = _906.x;
    float3 _910 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_892.x, _783)), max(0, min(_892.y, _788))))), 0u).xyz) * ((_907 == 0.0) ? 1.0 : _907);
    float _911 = _910.x;
    float _914 = 0.5 * _910.y;
    float _916 = _910.z;
    float _917 = 0.25 * _916;
    _127[3] = float3(((0.25 * _911) + _914) + _917, 0.5 * (_911 - _916), (((-0.25) * _911) + _914) - _917);
    int2 _926 = int2(_818, _890);
    int2 _927 = _779 + _926;
    float4 _941 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _942 = _941.x;
    float3 _945 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_927.x, _783)), max(0, min(_927.y, _788))))), 0u).xyz) * ((_942 == 0.0) ? 1.0 : _942);
    float _946 = _945.x;
    float _949 = 0.5 * _945.y;
    float _951 = _945.z;
    float _952 = 0.25 * _951;
    _127[4] = float3(((0.25 * _946) + _949) + _952, 0.5 * (_946 - _951), (((-0.25) * _946) + _949) - _952);
    int2 _961 = int2(_854, _890);
    int2 _962 = _779 + _961;
    float4 _976 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _977 = _976.x;
    float3 _980 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_962.x, _783)), max(0, min(_962.y, _788))))), 0u).xyz) * ((_977 == 0.0) ? 1.0 : _977);
    float _981 = _980.x;
    float _984 = 0.5 * _980.y;
    float _986 = _980.z;
    float _987 = 0.25 * _986;
    _127[5] = float3(((0.25 * _981) + _984) + _987, 0.5 * (_981 - _986), (((-0.25) * _981) + _984) - _987);
    int _996 = _771 ? 1 : 2;
    int2 _997 = int2(_776, _996);
    int2 _998 = _779 + _997;
    float4 _1012 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1013 = _1012.x;
    float3 _1016 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_998.x, _783)), max(0, min(_998.y, _788))))), 0u).xyz) * ((_1013 == 0.0) ? 1.0 : _1013);
    float _1017 = _1016.x;
    float _1020 = 0.5 * _1016.y;
    float _1022 = _1016.z;
    float _1023 = 0.25 * _1022;
    _127[6] = float3(((0.25 * _1017) + _1020) + _1023, 0.5 * (_1017 - _1022), (((-0.25) * _1017) + _1020) - _1023);
    int2 _1032 = int2(_818, _996);
    int2 _1033 = _779 + _1032;
    float4 _1047 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1048 = _1047.x;
    float3 _1051 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1033.x, _783)), max(0, min(_1033.y, _788))))), 0u).xyz) * ((_1048 == 0.0) ? 1.0 : _1048);
    float _1052 = _1051.x;
    float _1055 = 0.5 * _1051.y;
    float _1057 = _1051.z;
    float _1058 = 0.25 * _1057;
    _127[7] = float3(((0.25 * _1052) + _1055) + _1058, 0.5 * (_1052 - _1057), (((-0.25) * _1052) + _1055) - _1058);
    int2 _1067 = int2(_854, _996);
    int2 _1068 = _779 + _1067;
    float4 _1082 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1083 = _1082.x;
    float3 _1086 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1068.x, _783)), max(0, min(_1068.y, _788))))), 0u).xyz) * ((_1083 == 0.0) ? 1.0 : _1083);
    float _1087 = _1086.x;
    float _1090 = 0.5 * _1086.y;
    float _1092 = _1086.z;
    float _1093 = 0.25 * _1092;
    _127[8] = float3(((0.25 * _1087) + _1090) + _1093, 0.5 * (_1087 - _1092), (((-0.25) * _1087) + _1090) - _1093);
    if (_775)
    {
        for (int _1105 = 0; _1105 < 9; )
        {
            float _1116 = (_127[_1105].x + _127[_1105].y) - _127[_1105].z;
            float _1117 = _127[_1105].x + _127[_1105].z;
            float _1119 = (_127[_1105].x - _127[_1105].y) - _127[_1105].z;
            float3 _1126 = float3(_1116, _1117, _1119) / float3(precise::max(precise::max(0.0, _1116), precise::max(_1117, _1119)) + 1.0);
            float _1127 = _1126.x;
            float _1130 = 0.5 * _1126.y;
            float _1132 = _1126.z;
            float _1133 = 0.25 * _1132;
            _127[_1105] = float3(((0.25 * _1127) + _1130) + _1133, 0.5 * (_1127 - _1132), (((-0.25) * _1127) + _1130) - _1133);
            _1105++;
            continue;
        }
    }
    float _1145 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1156 = mix(precise::max(1.0, (1.0 + _1145) * 0.300000011920928955078125), _1145, precise::min(1.0 - (_217 * 0.5), precise::min(1.0 - _219, fast::clamp(_755 * 5.0, 0.0, 1.0))));
    float2 _1159 = _764 + (_774 + float2(_778));
    uint2 _1161 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1164 = float(all(uint2(_780) < _1161));
    bool _1165 = !_775;
    float _1184;
    float3 _1185;
    if (_1165)
    {
        float2 _1169 = _1159 * float2(_1156);
        float _1171 = precise::min(dot(_1169, _1169), 4.0);
        float _1173 = (0.4000000059604644775390625 * _1171) - 1.0;
        float _1175 = (0.25 * _1171) - 1.0;
        float _1181 = _1164 * ((((1.5625 * _1173) * _1173) - 0.5625) * (_1175 * _1175));
        _1184 = _1181;
        _1185 = _127[0] * _1181;
    }
    else
    {
        _1184 = 0.0;
        _1185 = float3(0.0);
    }
    float _1189 = exp((-2.2999999523162841796875) * dot(_1159, _1159)) * _1164;
    float3 _1191 = _127[0] * _1189;
    float2 _1195 = _764 + (_774 + float2(_819));
    float _1199 = float(all(uint2(_820) < _1161));
    float _1220;
    float3 _1221;
    if (_1165)
    {
        float2 _1203 = _1195 * float2(_1156);
        float _1205 = precise::min(dot(_1203, _1203), 4.0);
        float _1207 = (0.4000000059604644775390625 * _1205) - 1.0;
        float _1209 = (0.25 * _1205) - 1.0;
        float _1215 = _1199 * ((((1.5625 * _1207) * _1207) - 0.5625) * (_1209 * _1209));
        _1220 = _1184 + _1215;
        _1221 = _1185 + (_127[1] * _1215);
    }
    else
    {
        _1220 = _1184;
        _1221 = _1185;
    }
    float _1225 = exp((-2.2999999523162841796875) * dot(_1195, _1195)) * _1199;
    float3 _1229 = _127[1] * _1225;
    float2 _1236 = _764 + (_774 + float2(_855));
    float _1240 = float(all(uint2(_856) < _1161));
    float _1261;
    float3 _1262;
    if (_1165)
    {
        float2 _1244 = _1236 * float2(_1156);
        float _1246 = precise::min(dot(_1244, _1244), 4.0);
        float _1248 = (0.4000000059604644775390625 * _1246) - 1.0;
        float _1250 = (0.25 * _1246) - 1.0;
        float _1256 = _1240 * ((((1.5625 * _1248) * _1248) - 0.5625) * (_1250 * _1250));
        _1261 = _1220 + _1256;
        _1262 = _1221 + (_127[2] * _1256);
    }
    else
    {
        _1261 = _1220;
        _1262 = _1221;
    }
    float _1266 = exp((-2.2999999523162841796875) * dot(_1236, _1236)) * _1240;
    float3 _1270 = _127[2] * _1266;
    float2 _1277 = _764 + (_774 + float2(_891));
    float _1281 = float(all(uint2(_892) < _1161));
    float _1302;
    float3 _1303;
    if (_1165)
    {
        float2 _1285 = _1277 * float2(_1156);
        float _1287 = precise::min(dot(_1285, _1285), 4.0);
        float _1289 = (0.4000000059604644775390625 * _1287) - 1.0;
        float _1291 = (0.25 * _1287) - 1.0;
        float _1297 = _1281 * ((((1.5625 * _1289) * _1289) - 0.5625) * (_1291 * _1291));
        _1302 = _1261 + _1297;
        _1303 = _1262 + (_127[3] * _1297);
    }
    else
    {
        _1302 = _1261;
        _1303 = _1262;
    }
    float _1307 = exp((-2.2999999523162841796875) * dot(_1277, _1277)) * _1281;
    float3 _1311 = _127[3] * _1307;
    float2 _1318 = _764 + (_774 + float2(_926));
    float _1322 = float(all(uint2(_927) < _1161));
    float _1343;
    float3 _1344;
    if (_1165)
    {
        float2 _1326 = _1318 * float2(_1156);
        float _1328 = precise::min(dot(_1326, _1326), 4.0);
        float _1330 = (0.4000000059604644775390625 * _1328) - 1.0;
        float _1332 = (0.25 * _1328) - 1.0;
        float _1338 = _1322 * ((((1.5625 * _1330) * _1330) - 0.5625) * (_1332 * _1332));
        _1343 = _1302 + _1338;
        _1344 = _1303 + (_127[4] * _1338);
    }
    else
    {
        _1343 = _1302;
        _1344 = _1303;
    }
    float _1348 = exp((-2.2999999523162841796875) * dot(_1318, _1318)) * _1322;
    float3 _1352 = _127[4] * _1348;
    float2 _1359 = _764 + (_774 + float2(_961));
    float _1363 = float(all(uint2(_962) < _1161));
    float _1384;
    float3 _1385;
    if (_1165)
    {
        float2 _1367 = _1359 * float2(_1156);
        float _1369 = precise::min(dot(_1367, _1367), 4.0);
        float _1371 = (0.4000000059604644775390625 * _1369) - 1.0;
        float _1373 = (0.25 * _1369) - 1.0;
        float _1379 = _1363 * ((((1.5625 * _1371) * _1371) - 0.5625) * (_1373 * _1373));
        _1384 = _1343 + _1379;
        _1385 = _1344 + (_127[5] * _1379);
    }
    else
    {
        _1384 = _1343;
        _1385 = _1344;
    }
    float _1389 = exp((-2.2999999523162841796875) * dot(_1359, _1359)) * _1363;
    float3 _1393 = _127[5] * _1389;
    float2 _1400 = _764 + (_774 + float2(_997));
    float _1404 = float(all(uint2(_998) < _1161));
    float _1425;
    float3 _1426;
    if (_1165)
    {
        float2 _1408 = _1400 * float2(_1156);
        float _1410 = precise::min(dot(_1408, _1408), 4.0);
        float _1412 = (0.4000000059604644775390625 * _1410) - 1.0;
        float _1414 = (0.25 * _1410) - 1.0;
        float _1420 = _1404 * ((((1.5625 * _1412) * _1412) - 0.5625) * (_1414 * _1414));
        _1425 = _1384 + _1420;
        _1426 = _1385 + (_127[6] * _1420);
    }
    else
    {
        _1425 = _1384;
        _1426 = _1385;
    }
    float _1430 = exp((-2.2999999523162841796875) * dot(_1400, _1400)) * _1404;
    float3 _1434 = _127[6] * _1430;
    float2 _1441 = _764 + (_774 + float2(_1032));
    float _1445 = float(all(uint2(_1033) < _1161));
    float _1466;
    float3 _1467;
    if (_1165)
    {
        float2 _1449 = _1441 * float2(_1156);
        float _1451 = precise::min(dot(_1449, _1449), 4.0);
        float _1453 = (0.4000000059604644775390625 * _1451) - 1.0;
        float _1455 = (0.25 * _1451) - 1.0;
        float _1461 = _1445 * ((((1.5625 * _1453) * _1453) - 0.5625) * (_1455 * _1455));
        _1466 = _1425 + _1461;
        _1467 = _1426 + (_127[7] * _1461);
    }
    else
    {
        _1466 = _1425;
        _1467 = _1426;
    }
    float _1471 = exp((-2.2999999523162841796875) * dot(_1441, _1441)) * _1445;
    float3 _1475 = _127[7] * _1471;
    float2 _1482 = _764 + (_774 + float2(_1067));
    float _1486 = float(all(uint2(_1068) < _1161));
    float _1507;
    float3 _1508;
    if (_1165)
    {
        float2 _1490 = _1482 * float2(_1156);
        float _1492 = precise::min(dot(_1490, _1490), 4.0);
        float _1494 = (0.4000000059604644775390625 * _1492) - 1.0;
        float _1496 = (0.25 * _1492) - 1.0;
        float _1502 = _1486 * ((((1.5625 * _1494) * _1494) - 0.5625) * (_1496 * _1496));
        _1507 = _1466 + _1502;
        _1508 = _1467 + (_127[8] * _1502);
    }
    else
    {
        _1507 = _1466;
        _1508 = _1467;
    }
    float _1512 = exp((-2.2999999523162841796875) * dot(_1482, _1482)) * _1486;
    float3 _1516 = _127[8] * _1512;
    float _1520 = (((((((_1189 + _1225) + _1266) + _1307) + _1348) + _1389) + _1430) + _1471) + _1512;
    float3 _1524 = float3((abs(_1520) > 1.1754943508222875079687365372222e-38) ? _1520 : 1.0);
    float3 _1525 = ((((((((_1191 + _1229) + _1270) + _1311) + _1352) + _1393) + _1434) + _1475) + _1516) / _1524;
    float _1533 = _1507 * float(_1507 > 6.099999882280826568603515625e-05);
    float3 _1541;
    float _1542;
    if (_1533 > 6.099999882280826568603515625e-05)
    {
        _1541 = fast::clamp(_1508 / float3(_1533), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_127[0], _127[1]), _127[2]), _127[3]), _127[4]), _127[5]), _127[6]), _127[7]), _127[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_127[0], _127[1]), _127[2]), _127[3]), _127[4]), _127[5]), _127[6]), _127[7]), _127[8]));
        _1542 = _1533 * 0.04625000059604644775390625;
    }
    else
    {
        _1541 = _1508;
        _1542 = _1533;
    }
    float3 _1574;
    if (_775)
    {
        float _1545 = _1525.x;
        float _1546 = _1525.y;
        float _1548 = _1525.z;
        float _1549 = (_1545 + _1546) - _1548;
        float _1550 = _1545 + _1548;
        float _1552 = (_1545 - _1546) - _1548;
        float3 _1559 = float3(_1549, _1550, _1552) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1549, precise::max(_1550, _1552))));
        float _1560 = _1559.x;
        float _1563 = 0.5 * _1559.y;
        float _1565 = _1559.z;
        float _1566 = 0.25 * _1565;
        _1574 = float3(((0.25 * _1560) + _1563) + _1566, 0.5 * (_1560 - _1565), (((-0.25) * _1560) + _1563) - _1566);
    }
    else
    {
        _1574 = _1541;
    }
    float _1575 = _775 ? 1.0 : _1542;
    float _1576 = _775 ? 0.0 : _755;
    float3 _1590 = (sqrt(abs(((((((((((_127[0] * _1191) + (_127[1] * _1229)) + (_127[2] * _1270)) + (_127[3] * _1311)) + (_127[4] * _1352)) + (_127[5] * _1393)) + (_127[6] * _1434)) + (_127[7] * _1475)) + (_127[8] * _1516)) / _1524) - (_1525 * _1525))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_159 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_142 * _192, _192 - float2(0.5))) / float2(int2(int(_186.x), int(_186.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _226, precise::max(powr(_215, 0.5), _219)))));
    float3 _1593 = (_699 - _1525) / precise::max(_1590, float3(1.19299997436428384389728307724e-07));
    float3 _1608;
    if (length(_1593) > 1.0)
    {
        _1608 = mix((fast::normalize(_1593) * _1590) + _1525, _699, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_151, _146)) / _149), level(0.0)).x, fast::clamp(fast::clamp(_709 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _226) * (1.0 - _217), 0.0, 1.0)));
    }
    else
    {
        _1608 = _699;
    }
    float _1618 = (_1574.x + _1574.y) - _1574.z;
    float _1619 = _1574.x + _1574.z;
    float _1621 = (_1574.x - _1574.y) - _1574.z;
    float3 _1628 = float3(_1618, _1619, _1621) / float3(precise::max(precise::max(0.0, _1618), precise::max(_1619, _1621)) + 1.0);
    float _1629 = _1628.x;
    float _1632 = 0.5 * _1628.y;
    float _1634 = _1628.z;
    float _1635 = 0.25 * _1634;
    float _1647 = (_1608.x + _1608.y) - _1608.z;
    float _1648 = _1608.x + _1608.z;
    float _1650 = (_1608.x - _1608.y) - _1608.z;
    float3 _1657 = float3(_1647, _1648, _1650) / float3(precise::max(precise::max(0.0, _1647), precise::max(_1648, _1650)) + 1.0);
    float _1658 = _1657.x;
    float _1661 = 0.5 * _1657.y;
    float _1663 = _1657.z;
    float _1664 = 0.25 * _1663;
    float3 _1675 = mix(float3(((0.25 * _1658) + _1661) + _1664, 0.5 * (_1658 - _1663), (((-0.25) * _1658) + _1661) - _1664), float3(((0.25 * _1629) + _1632) + _1635, 0.5 * (_1629 - _1634), (((-0.25) * _1629) + _1632) - _1635), float3(fast::clamp(_1575 / precise::max(6.099999882280826568603515625e-05, (_1576 * float(_1576 > 6.099999882280826568603515625e-05)) + _1575), 0.0, 1.0)));
    float _1680 = (_1675.x + _1675.y) - _1675.z;
    float _1681 = _1675.x + _1675.z;
    float _1683 = (_1675.x - _1675.y) - _1675.z;
    float4 _1692 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1693 = _1692.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max((float3(_1680, _1681, _1683) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1680, precise::max(_1681, _1683))))) / float3((_1693 == 0.0) ? 1.0 : _1693), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_709 + (sdk_hlsl_load(rw_new_locks, uint2(_713)).x * (1.0 - precise::max(0.0, _215))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _706))) * float(_745)), uint2(_713));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_713));
}

