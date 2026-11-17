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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_upscaled_output [[texture(3)]], texture2d<float> r_farthest_depth_mip1 [[texture(4)]], texture2d<float> r_luma_instability [[texture(5)]], texture2d<float, access::read_write> rw_new_locks [[texture(6)]], texture2d<float> r_dilated_motion_vectors [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_lanczos_lut [[texture(9)]], texture2d<float> r_dilated_reactive_masks [[texture(10)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _134 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _137 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _138 = _134 / _137;
    float2 _143 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _145 = _138 + (cbFSR3Upscaler.fJitter / _143);
    float2 _149 = _143 - float2(0.5);
    float2 _152 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _154 = _138 * _143;
    float2 _160 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_154)))), 0u).xy;
    float _162 = length(_160 * float2(3840.0, 2160.0));
    float2 _163 = _138 + _160;
    float _164 = _163.x;
    bool _169;
    if (_164 >= 0.0)
    {
        _169 = _164 <= 1.0;
    }
    else
    {
        _169 = false;
    }
    bool _178;
    if (_169)
    {
        float _172 = _163.y;
        bool _177;
        if (_172 >= 0.0)
        {
            _177 = _172 <= 1.0;
        }
        else
        {
            _177 = false;
        }
        _178 = _177;
    }
    else
    {
        _178 = false;
    }
    uint2 _189 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _195 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _212;
    if (_178)
    {
        _212 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _212 = true;
    }
    float4 _216 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_145 * _143, _149)) / _152), level(0.0));
    float _218 = fast::clamp(_216.x, 0.0, 1.0);
    float _220 = fast::clamp(_216.y, 0.0, 1.0);
    float _222 = fast::clamp(_216.z, 0.0, 1.0);
    float _224 = fast::clamp(_216.w, 0.0, 1.0);
    float _229 = _224 * float(rint(_224 * 100.0) > 1.0);
    bool _233;
    if (_178)
    {
        _233 = !_212;
    }
    else
    {
        _233 = false;
    }
    float3 _702;
    float _703;
    if (_233)
    {
        float2 _237 = (_163 * _137) - float2(0.5);
        half2 _240 = half2(_237 - floor(_237));
        int2 _253 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _237.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _237.y)))));
        int2 _254 = _253 + int2(-1);
        int _256 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _260 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _268 = _253 + int2(0, -1);
        int2 _280 = _253 + int2(1, -1);
        int2 _292 = _253 + int2(2, -1);
        int2 _304 = _253 + int2(-1, 0);
        half4 _326 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_253.x, _256)), max(1, min(_253.y, _260))))), 0u));
        int2 _327 = _253 + int2(1, 0);
        half4 _338 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_327.x, _256)), max(1, min(_327.y, _260))))), 0u));
        int2 _339 = _253 + int2(2, 0);
        int2 _351 = _253 + int2(-1, 1);
        int2 _363 = _253 + int2(0, 1);
        half4 _374 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_363.x, _256)), max(1, min(_363.y, _260))))), 0u));
        int2 _375 = _253 + int2(1);
        half4 _386 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_375.x, _256)), max(1, min(_375.y, _260))))), 0u));
        int2 _387 = _253 + int2(2, 1);
        int2 _399 = _253 + int2(-1, 2);
        int2 _411 = _253 + int2(0, 2);
        int2 _423 = _253 + int2(1, 2);
        int2 _435 = _253 + int2(2);
        half _447 = _240.x;
        float2 _454 = float2(float(abs(half(-1.0) - _447)) * 0.5, 0.5);
        half _458 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        float2 _465 = float2(float(abs(half(-0.0) - _447)) * 0.5, 0.5);
        half _469 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        float2 _476 = float2(float(abs(half(1.0) - _447)) * 0.5, 0.5);
        half _480 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        float2 _487 = float2(float(abs(half(2.0) - _447)) * 0.5, 0.5);
        half _491 = half(r_lanczos_lut.sample(s_LinearClamp, _487, level(0.0)).x);
        half _509 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        half _515 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        half _521 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        half _527 = half(r_lanczos_lut.sample(s_LinearClamp, _487, level(0.0)).x);
        half _545 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        half _551 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        half _557 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        half _563 = half(r_lanczos_lut.sample(s_LinearClamp, _487, level(0.0)).x);
        half _581 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        half _587 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        half _593 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        half _599 = half(r_lanczos_lut.sample(s_LinearClamp, _487, level(0.0)).x);
        half _612 = _240.y;
        half _623 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-1.0) - _612)) * 0.5, 0.5), level(0.0)).x);
        half _634 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-0.0) - _612)) * 0.5, 0.5), level(0.0)).x);
        half _645 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(1.0) - _612)) * 0.5, 0.5), level(0.0)).x);
        half _656 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(2.0) - _612)) * 0.5, 0.5), level(0.0)).x);
        half4 _661 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_254.x, _256)), max(1, min(_254.y, _260))))), 0u)) * _458) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_268.x, _256)), max(1, min(_268.y, _260))))), 0u)) * _469)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_280.x, _256)), max(1, min(_280.y, _260))))), 0u)) * _480)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_292.x, _256)), max(1, min(_292.y, _260))))), 0u)) * _491)) / half4(((_458 + _469) + _480) + _491)) * _623) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_304.x, _256)), max(1, min(_304.y, _260))))), 0u)) * _509) + (_326 * _515)) + (_338 * _521)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_339.x, _256)), max(1, min(_339.y, _260))))), 0u)) * _527)) / half4(((_509 + _515) + _521) + _527)) * _634)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_351.x, _256)), max(1, min(_351.y, _260))))), 0u)) * _545) + (_374 * _551)) + (_386 * _557)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_387.x, _256)), max(1, min(_387.y, _260))))), 0u)) * _563)) / half4(((_545 + _551) + _557) + _563)) * _645);
        half4 _668 = (_661 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_399.x, _256)), max(1, min(_399.y, _260))))), 0u)) * _581) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_411.x, _256)), max(1, min(_411.y, _260))))), 0u)) * _587)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_423.x, _256)), max(1, min(_423.y, _260))))), 0u)) * _593)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_435.x, _256)), max(1, min(_435.y, _260))))), 0u)) * _599)) / half4(((_581 + _587) + _593) + _599)) * _656)) / half4(((_623 + _634) + _645) + _656);
        float4 _676 = float4(clamp(_668, min(min(min(_326, _338), _374), _386), max(max(max(_326, _338), _374), _386)));
        float4 _682 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _683 = _682.x;
        float3 _686 = (_676.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_683 == 0.0) ? 1.0 : _683);
        float _687 = _686.x;
        float _690 = 0.5 * _686.y;
        float _692 = _686.z;
        float _693 = 0.25 * _692;
        _702 = float3(((0.25 * _687) + _690) + _693, 0.5 * (_687 - _692), (((-0.25) * _687) + _690) - _693);
        _703 = _676.w;
    }
    else
    {
        _702 = float3(0.0);
        _703 = 0.0;
    }
    float _709 = precise::max(fast::clamp(_222, 0.0, 1.0), precise::max(_218, _220));
    float _712 = precise::max(0.0, (_703 * float(!_212)) - (_709 * 2.0));
    uint2 _716 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _733 = _138 - _160;
    float _734 = _733.x;
    bool _739;
    if (_734 >= 0.0)
    {
        _739 = _734 <= 1.0;
    }
    else
    {
        _739 = false;
    }
    bool _748;
    if (_739)
    {
        float _742 = _733.y;
        bool _747;
        if (_742 >= 0.0)
        {
            _747 = _742 <= 1.0;
        }
        else
        {
            _747 = false;
        }
        _748 = _747;
    }
    else
    {
        _748 = false;
    }
    float _758 = precise::min(_229, mix(_229, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_162 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _761 = _134 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _763 = int2(floor(_761));
    float2 _766 = (float2(_763) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _767 = _766 - _761;
    bool _770 = _766.x > _761.x;
    bool _774 = _766.y > _761.y;
    int2 _776 = int2(_770 ? (-2) : (-1), _774 ? (-2) : (-1));
    float2 _777 = float2(_776);
    bool _778 = _229 == 0.0;
    int _779 = _770 ? 3 : 0;
    int _780 = _774 ? 3 : 0;
    int2 _781 = int2(_779, _780);
    int2 _782 = _763 + _776;
    int2 _783 = _782 + _781;
    int _786 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _791 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _801 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _802 = _801.x;
    float3 _805 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_783.x, _786)), max(0, min(_783.y, _791))))), 0u).xyz) * ((_802 == 0.0) ? 1.0 : _802);
    float _806 = _805.x;
    float _809 = 0.5 * _805.y;
    float _811 = _805.z;
    float _812 = 0.25 * _811;
    spvUnsafeArray<float3, 9> _130;
    _130[0] = float3(((0.25 * _806) + _809) + _812, 0.5 * (_806 - _811), (((-0.25) * _806) + _809) - _812);
    int _821 = _770 ? 2 : 1;
    int2 _822 = int2(_821, _780);
    int2 _823 = _782 + _822;
    float4 _837 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _838 = _837.x;
    float3 _841 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_823.x, _786)), max(0, min(_823.y, _791))))), 0u).xyz) * ((_838 == 0.0) ? 1.0 : _838);
    float _842 = _841.x;
    float _845 = 0.5 * _841.y;
    float _847 = _841.z;
    float _848 = 0.25 * _847;
    _130[1] = float3(((0.25 * _842) + _845) + _848, 0.5 * (_842 - _847), (((-0.25) * _842) + _845) - _848);
    int _857 = _770 ? 1 : 2;
    int2 _858 = int2(_857, _780);
    int2 _859 = _782 + _858;
    float4 _873 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _874 = _873.x;
    float3 _877 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_859.x, _786)), max(0, min(_859.y, _791))))), 0u).xyz) * ((_874 == 0.0) ? 1.0 : _874);
    float _878 = _877.x;
    float _881 = 0.5 * _877.y;
    float _883 = _877.z;
    float _884 = 0.25 * _883;
    _130[2] = float3(((0.25 * _878) + _881) + _884, 0.5 * (_878 - _883), (((-0.25) * _878) + _881) - _884);
    int _893 = _774 ? 2 : 1;
    int2 _894 = int2(_779, _893);
    int2 _895 = _782 + _894;
    float4 _909 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _910 = _909.x;
    float3 _913 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_895.x, _786)), max(0, min(_895.y, _791))))), 0u).xyz) * ((_910 == 0.0) ? 1.0 : _910);
    float _914 = _913.x;
    float _917 = 0.5 * _913.y;
    float _919 = _913.z;
    float _920 = 0.25 * _919;
    _130[3] = float3(((0.25 * _914) + _917) + _920, 0.5 * (_914 - _919), (((-0.25) * _914) + _917) - _920);
    int2 _929 = int2(_821, _893);
    int2 _930 = _782 + _929;
    float4 _944 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _945 = _944.x;
    float3 _948 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_930.x, _786)), max(0, min(_930.y, _791))))), 0u).xyz) * ((_945 == 0.0) ? 1.0 : _945);
    float _949 = _948.x;
    float _952 = 0.5 * _948.y;
    float _954 = _948.z;
    float _955 = 0.25 * _954;
    _130[4] = float3(((0.25 * _949) + _952) + _955, 0.5 * (_949 - _954), (((-0.25) * _949) + _952) - _955);
    int2 _964 = int2(_857, _893);
    int2 _965 = _782 + _964;
    float4 _979 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _980 = _979.x;
    float3 _983 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_965.x, _786)), max(0, min(_965.y, _791))))), 0u).xyz) * ((_980 == 0.0) ? 1.0 : _980);
    float _984 = _983.x;
    float _987 = 0.5 * _983.y;
    float _989 = _983.z;
    float _990 = 0.25 * _989;
    _130[5] = float3(((0.25 * _984) + _987) + _990, 0.5 * (_984 - _989), (((-0.25) * _984) + _987) - _990);
    int _999 = _774 ? 1 : 2;
    int2 _1000 = int2(_779, _999);
    int2 _1001 = _782 + _1000;
    float4 _1015 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1016 = _1015.x;
    float3 _1019 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1001.x, _786)), max(0, min(_1001.y, _791))))), 0u).xyz) * ((_1016 == 0.0) ? 1.0 : _1016);
    float _1020 = _1019.x;
    float _1023 = 0.5 * _1019.y;
    float _1025 = _1019.z;
    float _1026 = 0.25 * _1025;
    _130[6] = float3(((0.25 * _1020) + _1023) + _1026, 0.5 * (_1020 - _1025), (((-0.25) * _1020) + _1023) - _1026);
    int2 _1035 = int2(_821, _999);
    int2 _1036 = _782 + _1035;
    float4 _1050 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1051 = _1050.x;
    float3 _1054 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1036.x, _786)), max(0, min(_1036.y, _791))))), 0u).xyz) * ((_1051 == 0.0) ? 1.0 : _1051);
    float _1055 = _1054.x;
    float _1058 = 0.5 * _1054.y;
    float _1060 = _1054.z;
    float _1061 = 0.25 * _1060;
    _130[7] = float3(((0.25 * _1055) + _1058) + _1061, 0.5 * (_1055 - _1060), (((-0.25) * _1055) + _1058) - _1061);
    int2 _1070 = int2(_857, _999);
    int2 _1071 = _782 + _1070;
    float4 _1085 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1086 = _1085.x;
    float3 _1089 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1071.x, _786)), max(0, min(_1071.y, _791))))), 0u).xyz) * ((_1086 == 0.0) ? 1.0 : _1086);
    float _1090 = _1089.x;
    float _1093 = 0.5 * _1089.y;
    float _1095 = _1089.z;
    float _1096 = 0.25 * _1095;
    _130[8] = float3(((0.25 * _1090) + _1093) + _1096, 0.5 * (_1090 - _1095), (((-0.25) * _1090) + _1093) - _1096);
    if (_778)
    {
        for (int _1108 = 0; _1108 < 9; )
        {
            float _1119 = (_130[_1108].x + _130[_1108].y) - _130[_1108].z;
            float _1120 = _130[_1108].x + _130[_1108].z;
            float _1122 = (_130[_1108].x - _130[_1108].y) - _130[_1108].z;
            float3 _1129 = float3(_1119, _1120, _1122) / float3(precise::max(precise::max(0.0, _1119), precise::max(_1120, _1122)) + 1.0);
            float _1130 = _1129.x;
            float _1133 = 0.5 * _1129.y;
            float _1135 = _1129.z;
            float _1136 = 0.25 * _1135;
            _130[_1108] = float3(((0.25 * _1130) + _1133) + _1136, 0.5 * (_1130 - _1135), (((-0.25) * _1130) + _1133) - _1136);
            _1108++;
            continue;
        }
    }
    float _1148 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1159 = mix(precise::max(1.0, (1.0 + _1148) * 0.300000011920928955078125), _1148, precise::min(1.0 - (_220 * 0.5), precise::min(1.0 - _222, fast::clamp(_758 * 5.0, 0.0, 1.0))));
    float2 _1162 = _767 + (_777 + float2(_781));
    uint2 _1164 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1167 = float(all(uint2(_783) < _1164));
    bool _1168 = !_778;
    float _1187;
    float3 _1188;
    if (_1168)
    {
        float2 _1172 = _1162 * float2(_1159);
        float _1174 = precise::min(dot(_1172, _1172), 4.0);
        float _1176 = (0.4000000059604644775390625 * _1174) - 1.0;
        float _1178 = (0.25 * _1174) - 1.0;
        float _1184 = _1167 * ((((1.5625 * _1176) * _1176) - 0.5625) * (_1178 * _1178));
        _1187 = _1184;
        _1188 = _130[0] * _1184;
    }
    else
    {
        _1187 = 0.0;
        _1188 = float3(0.0);
    }
    float _1192 = exp((-2.2999999523162841796875) * dot(_1162, _1162)) * _1167;
    float3 _1194 = _130[0] * _1192;
    float2 _1198 = _767 + (_777 + float2(_822));
    float _1202 = float(all(uint2(_823) < _1164));
    float _1223;
    float3 _1224;
    if (_1168)
    {
        float2 _1206 = _1198 * float2(_1159);
        float _1208 = precise::min(dot(_1206, _1206), 4.0);
        float _1210 = (0.4000000059604644775390625 * _1208) - 1.0;
        float _1212 = (0.25 * _1208) - 1.0;
        float _1218 = _1202 * ((((1.5625 * _1210) * _1210) - 0.5625) * (_1212 * _1212));
        _1223 = _1187 + _1218;
        _1224 = _1188 + (_130[1] * _1218);
    }
    else
    {
        _1223 = _1187;
        _1224 = _1188;
    }
    float _1228 = exp((-2.2999999523162841796875) * dot(_1198, _1198)) * _1202;
    float3 _1232 = _130[1] * _1228;
    float2 _1239 = _767 + (_777 + float2(_858));
    float _1243 = float(all(uint2(_859) < _1164));
    float _1264;
    float3 _1265;
    if (_1168)
    {
        float2 _1247 = _1239 * float2(_1159);
        float _1249 = precise::min(dot(_1247, _1247), 4.0);
        float _1251 = (0.4000000059604644775390625 * _1249) - 1.0;
        float _1253 = (0.25 * _1249) - 1.0;
        float _1259 = _1243 * ((((1.5625 * _1251) * _1251) - 0.5625) * (_1253 * _1253));
        _1264 = _1223 + _1259;
        _1265 = _1224 + (_130[2] * _1259);
    }
    else
    {
        _1264 = _1223;
        _1265 = _1224;
    }
    float _1269 = exp((-2.2999999523162841796875) * dot(_1239, _1239)) * _1243;
    float3 _1273 = _130[2] * _1269;
    float2 _1280 = _767 + (_777 + float2(_894));
    float _1284 = float(all(uint2(_895) < _1164));
    float _1305;
    float3 _1306;
    if (_1168)
    {
        float2 _1288 = _1280 * float2(_1159);
        float _1290 = precise::min(dot(_1288, _1288), 4.0);
        float _1292 = (0.4000000059604644775390625 * _1290) - 1.0;
        float _1294 = (0.25 * _1290) - 1.0;
        float _1300 = _1284 * ((((1.5625 * _1292) * _1292) - 0.5625) * (_1294 * _1294));
        _1305 = _1264 + _1300;
        _1306 = _1265 + (_130[3] * _1300);
    }
    else
    {
        _1305 = _1264;
        _1306 = _1265;
    }
    float _1310 = exp((-2.2999999523162841796875) * dot(_1280, _1280)) * _1284;
    float3 _1314 = _130[3] * _1310;
    float2 _1321 = _767 + (_777 + float2(_929));
    float _1325 = float(all(uint2(_930) < _1164));
    float _1346;
    float3 _1347;
    if (_1168)
    {
        float2 _1329 = _1321 * float2(_1159);
        float _1331 = precise::min(dot(_1329, _1329), 4.0);
        float _1333 = (0.4000000059604644775390625 * _1331) - 1.0;
        float _1335 = (0.25 * _1331) - 1.0;
        float _1341 = _1325 * ((((1.5625 * _1333) * _1333) - 0.5625) * (_1335 * _1335));
        _1346 = _1305 + _1341;
        _1347 = _1306 + (_130[4] * _1341);
    }
    else
    {
        _1346 = _1305;
        _1347 = _1306;
    }
    float _1351 = exp((-2.2999999523162841796875) * dot(_1321, _1321)) * _1325;
    float3 _1355 = _130[4] * _1351;
    float2 _1362 = _767 + (_777 + float2(_964));
    float _1366 = float(all(uint2(_965) < _1164));
    float _1387;
    float3 _1388;
    if (_1168)
    {
        float2 _1370 = _1362 * float2(_1159);
        float _1372 = precise::min(dot(_1370, _1370), 4.0);
        float _1374 = (0.4000000059604644775390625 * _1372) - 1.0;
        float _1376 = (0.25 * _1372) - 1.0;
        float _1382 = _1366 * ((((1.5625 * _1374) * _1374) - 0.5625) * (_1376 * _1376));
        _1387 = _1346 + _1382;
        _1388 = _1347 + (_130[5] * _1382);
    }
    else
    {
        _1387 = _1346;
        _1388 = _1347;
    }
    float _1392 = exp((-2.2999999523162841796875) * dot(_1362, _1362)) * _1366;
    float3 _1396 = _130[5] * _1392;
    float2 _1403 = _767 + (_777 + float2(_1000));
    float _1407 = float(all(uint2(_1001) < _1164));
    float _1428;
    float3 _1429;
    if (_1168)
    {
        float2 _1411 = _1403 * float2(_1159);
        float _1413 = precise::min(dot(_1411, _1411), 4.0);
        float _1415 = (0.4000000059604644775390625 * _1413) - 1.0;
        float _1417 = (0.25 * _1413) - 1.0;
        float _1423 = _1407 * ((((1.5625 * _1415) * _1415) - 0.5625) * (_1417 * _1417));
        _1428 = _1387 + _1423;
        _1429 = _1388 + (_130[6] * _1423);
    }
    else
    {
        _1428 = _1387;
        _1429 = _1388;
    }
    float _1433 = exp((-2.2999999523162841796875) * dot(_1403, _1403)) * _1407;
    float3 _1437 = _130[6] * _1433;
    float2 _1444 = _767 + (_777 + float2(_1035));
    float _1448 = float(all(uint2(_1036) < _1164));
    float _1469;
    float3 _1470;
    if (_1168)
    {
        float2 _1452 = _1444 * float2(_1159);
        float _1454 = precise::min(dot(_1452, _1452), 4.0);
        float _1456 = (0.4000000059604644775390625 * _1454) - 1.0;
        float _1458 = (0.25 * _1454) - 1.0;
        float _1464 = _1448 * ((((1.5625 * _1456) * _1456) - 0.5625) * (_1458 * _1458));
        _1469 = _1428 + _1464;
        _1470 = _1429 + (_130[7] * _1464);
    }
    else
    {
        _1469 = _1428;
        _1470 = _1429;
    }
    float _1474 = exp((-2.2999999523162841796875) * dot(_1444, _1444)) * _1448;
    float3 _1478 = _130[7] * _1474;
    float2 _1485 = _767 + (_777 + float2(_1070));
    float _1489 = float(all(uint2(_1071) < _1164));
    float _1510;
    float3 _1511;
    if (_1168)
    {
        float2 _1493 = _1485 * float2(_1159);
        float _1495 = precise::min(dot(_1493, _1493), 4.0);
        float _1497 = (0.4000000059604644775390625 * _1495) - 1.0;
        float _1499 = (0.25 * _1495) - 1.0;
        float _1505 = _1489 * ((((1.5625 * _1497) * _1497) - 0.5625) * (_1499 * _1499));
        _1510 = _1469 + _1505;
        _1511 = _1470 + (_130[8] * _1505);
    }
    else
    {
        _1510 = _1469;
        _1511 = _1470;
    }
    float _1515 = exp((-2.2999999523162841796875) * dot(_1485, _1485)) * _1489;
    float3 _1519 = _130[8] * _1515;
    float _1523 = (((((((_1192 + _1228) + _1269) + _1310) + _1351) + _1392) + _1433) + _1474) + _1515;
    float3 _1527 = float3((abs(_1523) > 1.1754943508222875079687365372222e-38) ? _1523 : 1.0);
    float3 _1528 = ((((((((_1194 + _1232) + _1273) + _1314) + _1355) + _1396) + _1437) + _1478) + _1519) / _1527;
    float _1536 = _1510 * float(_1510 > 6.099999882280826568603515625e-05);
    float3 _1544;
    float _1545;
    if (_1536 > 6.099999882280826568603515625e-05)
    {
        _1544 = fast::clamp(_1511 / float3(_1536), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_130[0], _130[1]), _130[2]), _130[3]), _130[4]), _130[5]), _130[6]), _130[7]), _130[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_130[0], _130[1]), _130[2]), _130[3]), _130[4]), _130[5]), _130[6]), _130[7]), _130[8]));
        _1545 = _1536 * 0.04625000059604644775390625;
    }
    else
    {
        _1544 = _1511;
        _1545 = _1536;
    }
    float3 _1577;
    if (_778)
    {
        float _1548 = _1528.x;
        float _1549 = _1528.y;
        float _1551 = _1528.z;
        float _1552 = (_1548 + _1549) - _1551;
        float _1553 = _1548 + _1551;
        float _1555 = (_1548 - _1549) - _1551;
        float3 _1562 = float3(_1552, _1553, _1555) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1552, precise::max(_1553, _1555))));
        float _1563 = _1562.x;
        float _1566 = 0.5 * _1562.y;
        float _1568 = _1562.z;
        float _1569 = 0.25 * _1568;
        _1577 = float3(((0.25 * _1563) + _1566) + _1569, 0.5 * (_1563 - _1568), (((-0.25) * _1563) + _1566) - _1569);
    }
    else
    {
        _1577 = _1544;
    }
    float _1578 = _778 ? 1.0 : _1545;
    float _1579 = _778 ? 0.0 : _758;
    float3 _1593 = (sqrt(abs(((((((((((_130[0] * _1194) + (_130[1] * _1232)) + (_130[2] * _1273)) + (_130[3] * _1314)) + (_130[4] * _1355)) + (_130[5] * _1396)) + (_130[6] * _1437)) + (_130[7] * _1478)) + (_130[8] * _1519)) / _1527) - (_1528 * _1528))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_162 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_145 * _195, _195 - float2(0.5))) / float2(int2(int(_189.x), int(_189.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _229, precise::max(powr(_218, 0.5), _222)))));
    float3 _1596 = (_702 - _1528) / precise::max(_1593, float3(1.19299997436428384389728307724e-07));
    float3 _1611;
    if (length(_1596) > 1.0)
    {
        _1611 = mix((fast::normalize(_1596) * _1593) + _1528, _702, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_154, _149)) / _152), level(0.0)).x, fast::clamp(fast::clamp(_712 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _229) * (1.0 - _220), 0.0, 1.0)));
    }
    else
    {
        _1611 = _702;
    }
    float _1621 = (_1577.x + _1577.y) - _1577.z;
    float _1622 = _1577.x + _1577.z;
    float _1624 = (_1577.x - _1577.y) - _1577.z;
    float3 _1631 = float3(_1621, _1622, _1624) / float3(precise::max(precise::max(0.0, _1621), precise::max(_1622, _1624)) + 1.0);
    float _1632 = _1631.x;
    float _1635 = 0.5 * _1631.y;
    float _1637 = _1631.z;
    float _1638 = 0.25 * _1637;
    float _1650 = (_1611.x + _1611.y) - _1611.z;
    float _1651 = _1611.x + _1611.z;
    float _1653 = (_1611.x - _1611.y) - _1611.z;
    float3 _1660 = float3(_1650, _1651, _1653) / float3(precise::max(precise::max(0.0, _1650), precise::max(_1651, _1653)) + 1.0);
    float _1661 = _1660.x;
    float _1664 = 0.5 * _1660.y;
    float _1666 = _1660.z;
    float _1667 = 0.25 * _1666;
    float3 _1678 = mix(float3(((0.25 * _1661) + _1664) + _1667, 0.5 * (_1661 - _1666), (((-0.25) * _1661) + _1664) - _1667), float3(((0.25 * _1632) + _1635) + _1638, 0.5 * (_1632 - _1637), (((-0.25) * _1632) + _1635) - _1638), float3(fast::clamp(_1578 / precise::max(6.099999882280826568603515625e-05, (_1579 * float(_1579 > 6.099999882280826568603515625e-05)) + _1578), 0.0, 1.0)));
    float _1683 = (_1678.x + _1678.y) - _1678.z;
    float _1684 = _1678.x + _1678.z;
    float _1686 = (_1678.x - _1678.y) - _1678.z;
    float4 _1695 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1696 = _1695.x;
    float3 _1701 = precise::max((float3(_1683, _1684, _1686) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1683, precise::max(_1684, _1686))))) / float3((_1696 == 0.0) ? 1.0 : _1696), float3(0.0));
    float _1702 = _1701.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1702, _1701.yz, precise::max(0.0, precise::max(0.0, precise::min(_712 + (sdk_hlsl_load(rw_new_locks, uint2(_716)).x * (1.0 - precise::max(0.0, _218))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _709))) * float(_748)), uint2(_716));
    sdk_hlsl_store(rw_upscaled_output, float4(_1702, _1701.yz, 1.0), uint2(_716));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_716));
}

