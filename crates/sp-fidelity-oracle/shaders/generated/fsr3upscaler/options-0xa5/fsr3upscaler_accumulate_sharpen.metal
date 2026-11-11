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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float> r_farthest_depth_mip1 [[texture(3)]], texture2d<float> r_luma_instability [[texture(4)]], texture2d<float, access::read_write> rw_new_locks [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_lanczos_lut [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _123 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _126 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _127 = _123 / _126;
    float2 _132 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _134 = _127 + (cbFSR3Upscaler.fJitter / _132);
    float2 _138 = _132 - float2(0.5);
    float2 _141 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _143 = _127 * _132;
    float2 _149 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_143)))), 0u).xy;
    float _151 = length(_149 * float2(3840.0, 2160.0));
    float2 _152 = _127 + _149;
    float _153 = _152.x;
    bool _158;
    if (_153 >= 0.0)
    {
        _158 = _153 <= 1.0;
    }
    else
    {
        _158 = false;
    }
    bool _167;
    if (_158)
    {
        float _161 = _152.y;
        bool _166;
        if (_161 >= 0.0)
        {
            _166 = _161 <= 1.0;
        }
        else
        {
            _166 = false;
        }
        _167 = _166;
    }
    else
    {
        _167 = false;
    }
    uint2 _178 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _184 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _201;
    if (_167)
    {
        _201 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _201 = true;
    }
    float4 _205 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_134 * _132, _138)) / _141), level(0.0));
    float _207 = fast::clamp(_205.x, 0.0, 1.0);
    float _209 = fast::clamp(_205.y, 0.0, 1.0);
    float _211 = fast::clamp(_205.z, 0.0, 1.0);
    float _213 = fast::clamp(_205.w, 0.0, 1.0);
    float _218 = _213 * float(rint(_213 * 100.0) > 1.0);
    bool _222;
    if (_167)
    {
        _222 = !_201;
    }
    else
    {
        _222 = false;
    }
    float3 _691;
    float _692;
    if (_222)
    {
        float2 _226 = (_152 * _126) - float2(0.5);
        half2 _229 = half2(_226 - floor(_226));
        int2 _242 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _226.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _226.y)))));
        int2 _243 = _242 + int2(-1);
        int _245 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _249 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _257 = _242 + int2(0, -1);
        int2 _269 = _242 + int2(1, -1);
        int2 _281 = _242 + int2(2, -1);
        int2 _293 = _242 + int2(-1, 0);
        half4 _315 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_242.x, _245)), max(1, min(_242.y, _249))))), 0u));
        int2 _316 = _242 + int2(1, 0);
        half4 _327 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_316.x, _245)), max(1, min(_316.y, _249))))), 0u));
        int2 _328 = _242 + int2(2, 0);
        int2 _340 = _242 + int2(-1, 1);
        int2 _352 = _242 + int2(0, 1);
        half4 _363 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_352.x, _245)), max(1, min(_352.y, _249))))), 0u));
        int2 _364 = _242 + int2(1);
        half4 _375 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_364.x, _245)), max(1, min(_364.y, _249))))), 0u));
        int2 _376 = _242 + int2(2, 1);
        int2 _388 = _242 + int2(-1, 2);
        int2 _400 = _242 + int2(0, 2);
        int2 _412 = _242 + int2(1, 2);
        int2 _424 = _242 + int2(2);
        half _436 = _229.x;
        float2 _443 = float2(float(abs(half(-1.0) - _436)) * 0.5, 0.5);
        half _447 = half(r_lanczos_lut.sample(s_LinearClamp, _443, level(0.0)).x);
        float2 _454 = float2(float(abs(half(-0.0) - _436)) * 0.5, 0.5);
        half _458 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        float2 _465 = float2(float(abs(half(1.0) - _436)) * 0.5, 0.5);
        half _469 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        float2 _476 = float2(float(abs(half(2.0) - _436)) * 0.5, 0.5);
        half _480 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        half _498 = half(r_lanczos_lut.sample(s_LinearClamp, _443, level(0.0)).x);
        half _504 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        half _510 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        half _516 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        half _534 = half(r_lanczos_lut.sample(s_LinearClamp, _443, level(0.0)).x);
        half _540 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        half _546 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        half _552 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        half _570 = half(r_lanczos_lut.sample(s_LinearClamp, _443, level(0.0)).x);
        half _576 = half(r_lanczos_lut.sample(s_LinearClamp, _454, level(0.0)).x);
        half _582 = half(r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0)).x);
        half _588 = half(r_lanczos_lut.sample(s_LinearClamp, _476, level(0.0)).x);
        half _601 = _229.y;
        half _612 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-1.0) - _601)) * 0.5, 0.5), level(0.0)).x);
        half _623 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-0.0) - _601)) * 0.5, 0.5), level(0.0)).x);
        half _634 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(1.0) - _601)) * 0.5, 0.5), level(0.0)).x);
        half _645 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(2.0) - _601)) * 0.5, 0.5), level(0.0)).x);
        half4 _650 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_243.x, _245)), max(1, min(_243.y, _249))))), 0u)) * _447) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_257.x, _245)), max(1, min(_257.y, _249))))), 0u)) * _458)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_269.x, _245)), max(1, min(_269.y, _249))))), 0u)) * _469)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_281.x, _245)), max(1, min(_281.y, _249))))), 0u)) * _480)) / half4(((_447 + _458) + _469) + _480)) * _612) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_293.x, _245)), max(1, min(_293.y, _249))))), 0u)) * _498) + (_315 * _504)) + (_327 * _510)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_328.x, _245)), max(1, min(_328.y, _249))))), 0u)) * _516)) / half4(((_498 + _504) + _510) + _516)) * _623)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_340.x, _245)), max(1, min(_340.y, _249))))), 0u)) * _534) + (_363 * _540)) + (_375 * _546)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_376.x, _245)), max(1, min(_376.y, _249))))), 0u)) * _552)) / half4(((_534 + _540) + _546) + _552)) * _634);
        half4 _657 = (_650 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_388.x, _245)), max(1, min(_388.y, _249))))), 0u)) * _570) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_400.x, _245)), max(1, min(_400.y, _249))))), 0u)) * _576)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_412.x, _245)), max(1, min(_412.y, _249))))), 0u)) * _582)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_424.x, _245)), max(1, min(_424.y, _249))))), 0u)) * _588)) / half4(((_570 + _576) + _582) + _588)) * _645)) / half4(((_612 + _623) + _634) + _645);
        float4 _665 = float4(clamp(_657, min(min(min(_315, _327), _363), _375), max(max(max(_315, _327), _363), _375)));
        float4 _671 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _672 = _671.x;
        float3 _675 = (_665.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_672 == 0.0) ? 1.0 : _672);
        float _676 = _675.x;
        float _679 = 0.5 * _675.y;
        float _681 = _675.z;
        float _682 = 0.25 * _681;
        _691 = float3(((0.25 * _676) + _679) + _682, 0.5 * (_676 - _681), (((-0.25) * _676) + _679) - _682);
        _692 = _665.w;
    }
    else
    {
        _691 = float3(0.0);
        _692 = 0.0;
    }
    float _698 = precise::max(fast::clamp(_211, 0.0, 1.0), precise::max(_207, _209));
    float _701 = precise::max(0.0, (_692 * float(!_201)) - (_698 * 2.0));
    uint2 _705 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _722 = _127 - _149;
    float _723 = _722.x;
    bool _728;
    if (_723 >= 0.0)
    {
        _728 = _723 <= 1.0;
    }
    else
    {
        _728 = false;
    }
    bool _737;
    if (_728)
    {
        float _731 = _722.y;
        bool _736;
        if (_731 >= 0.0)
        {
            _736 = _731 <= 1.0;
        }
        else
        {
            _736 = false;
        }
        _737 = _736;
    }
    else
    {
        _737 = false;
    }
    float _747 = precise::min(_218, mix(_218, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_151 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _750 = _123 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _752 = int2(floor(_750));
    float2 _755 = (float2(_752) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _756 = _755 - _750;
    bool _759 = _755.x > _750.x;
    bool _763 = _755.y > _750.y;
    int2 _765 = int2(_759 ? (-2) : (-1), _763 ? (-2) : (-1));
    float2 _766 = float2(_765);
    bool _767 = _218 == 0.0;
    int _768 = _759 ? 3 : 0;
    int _769 = _763 ? 3 : 0;
    int2 _770 = int2(_768, _769);
    int2 _771 = _752 + _765;
    int2 _772 = _771 + _770;
    int _775 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _780 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _790 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _791 = _790.x;
    float3 _794 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_772.x, _775)), max(0, min(_772.y, _780))))), 0u).xyz) * ((_791 == 0.0) ? 1.0 : _791);
    float _795 = _794.x;
    float _798 = 0.5 * _794.y;
    float _800 = _794.z;
    float _801 = 0.25 * _800;
    float3 _808 = float3(((0.25 * _795) + _798) + _801, 0.5 * (_795 - _800), (((-0.25) * _795) + _798) - _801);
    int _809 = _759 ? 2 : 1;
    int2 _810 = int2(_809, _769);
    int2 _811 = _771 + _810;
    float4 _825 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _826 = _825.x;
    float3 _829 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_811.x, _775)), max(0, min(_811.y, _780))))), 0u).xyz) * ((_826 == 0.0) ? 1.0 : _826);
    float _830 = _829.x;
    float _833 = 0.5 * _829.y;
    float _835 = _829.z;
    float _836 = 0.25 * _835;
    float3 _843 = float3(((0.25 * _830) + _833) + _836, 0.5 * (_830 - _835), (((-0.25) * _830) + _833) - _836);
    int _844 = _759 ? 1 : 2;
    int2 _845 = int2(_844, _769);
    int2 _846 = _771 + _845;
    float4 _860 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _861 = _860.x;
    float3 _864 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_846.x, _775)), max(0, min(_846.y, _780))))), 0u).xyz) * ((_861 == 0.0) ? 1.0 : _861);
    float _865 = _864.x;
    float _868 = 0.5 * _864.y;
    float _870 = _864.z;
    float _871 = 0.25 * _870;
    float3 _878 = float3(((0.25 * _865) + _868) + _871, 0.5 * (_865 - _870), (((-0.25) * _865) + _868) - _871);
    int _879 = _763 ? 2 : 1;
    int2 _880 = int2(_768, _879);
    int2 _881 = _771 + _880;
    float4 _895 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _896 = _895.x;
    float3 _899 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_881.x, _775)), max(0, min(_881.y, _780))))), 0u).xyz) * ((_896 == 0.0) ? 1.0 : _896);
    float _900 = _899.x;
    float _903 = 0.5 * _899.y;
    float _905 = _899.z;
    float _906 = 0.25 * _905;
    float3 _913 = float3(((0.25 * _900) + _903) + _906, 0.5 * (_900 - _905), (((-0.25) * _900) + _903) - _906);
    int2 _914 = int2(_809, _879);
    int2 _915 = _771 + _914;
    float4 _929 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _930 = _929.x;
    float3 _933 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_915.x, _775)), max(0, min(_915.y, _780))))), 0u).xyz) * ((_930 == 0.0) ? 1.0 : _930);
    float _934 = _933.x;
    float _937 = 0.5 * _933.y;
    float _939 = _933.z;
    float _940 = 0.25 * _939;
    float3 _947 = float3(((0.25 * _934) + _937) + _940, 0.5 * (_934 - _939), (((-0.25) * _934) + _937) - _940);
    int2 _948 = int2(_844, _879);
    int2 _949 = _771 + _948;
    float4 _963 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _964 = _963.x;
    float3 _967 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_949.x, _775)), max(0, min(_949.y, _780))))), 0u).xyz) * ((_964 == 0.0) ? 1.0 : _964);
    float _968 = _967.x;
    float _971 = 0.5 * _967.y;
    float _973 = _967.z;
    float _974 = 0.25 * _973;
    float3 _981 = float3(((0.25 * _968) + _971) + _974, 0.5 * (_968 - _973), (((-0.25) * _968) + _971) - _974);
    int _982 = _763 ? 1 : 2;
    int2 _983 = int2(_768, _982);
    int2 _984 = _771 + _983;
    float4 _998 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _999 = _998.x;
    float3 _1002 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_984.x, _775)), max(0, min(_984.y, _780))))), 0u).xyz) * ((_999 == 0.0) ? 1.0 : _999);
    float _1003 = _1002.x;
    float _1006 = 0.5 * _1002.y;
    float _1008 = _1002.z;
    float _1009 = 0.25 * _1008;
    float3 _1016 = float3(((0.25 * _1003) + _1006) + _1009, 0.5 * (_1003 - _1008), (((-0.25) * _1003) + _1006) - _1009);
    int2 _1017 = int2(_809, _982);
    int2 _1018 = _771 + _1017;
    float4 _1032 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1033 = _1032.x;
    float3 _1036 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1018.x, _775)), max(0, min(_1018.y, _780))))), 0u).xyz) * ((_1033 == 0.0) ? 1.0 : _1033);
    float _1037 = _1036.x;
    float _1040 = 0.5 * _1036.y;
    float _1042 = _1036.z;
    float _1043 = 0.25 * _1042;
    float3 _1050 = float3(((0.25 * _1037) + _1040) + _1043, 0.5 * (_1037 - _1042), (((-0.25) * _1037) + _1040) - _1043);
    int2 _1051 = int2(_844, _982);
    int2 _1052 = _771 + _1051;
    float4 _1066 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1067 = _1066.x;
    float3 _1070 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1052.x, _775)), max(0, min(_1052.y, _780))))), 0u).xyz) * ((_1067 == 0.0) ? 1.0 : _1067);
    float _1071 = _1070.x;
    float _1074 = 0.5 * _1070.y;
    float _1076 = _1070.z;
    float _1077 = 0.25 * _1076;
    float3 _1084 = float3(((0.25 * _1071) + _1074) + _1077, 0.5 * (_1071 - _1076), (((-0.25) * _1071) + _1074) - _1077);
    float _1089 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1100 = mix(precise::max(1.0, (1.0 + _1089) * 0.300000011920928955078125), _1089, precise::min(1.0 - (_209 * 0.5), precise::min(1.0 - _211, fast::clamp(_747 * 5.0, 0.0, 1.0))));
    float2 _1103 = _756 + (_766 + float2(_770));
    uint2 _1105 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1108 = float(all(uint2(_772) < _1105));
    bool _1109 = !_767;
    float _1127;
    float3 _1128;
    if (_1109)
    {
        float2 _1113 = _1103 * float2(_1100);
        float _1115 = precise::min(dot(_1113, _1113), 4.0);
        float _1117 = (0.4000000059604644775390625 * _1115) - 1.0;
        float _1119 = (0.25 * _1115) - 1.0;
        float _1125 = _1108 * ((((1.5625 * _1117) * _1117) - 0.5625) * (_1119 * _1119));
        _1127 = _1125;
        _1128 = _808 * _1125;
    }
    else
    {
        _1127 = 0.0;
        _1128 = float3(0.0);
    }
    float _1132 = exp((-2.2999999523162841796875) * dot(_1103, _1103)) * _1108;
    float3 _1133 = _808 * _1132;
    float2 _1137 = _756 + (_766 + float2(_810));
    float _1141 = float(all(uint2(_811) < _1105));
    float _1161;
    float3 _1162;
    if (_1109)
    {
        float2 _1145 = _1137 * float2(_1100);
        float _1147 = precise::min(dot(_1145, _1145), 4.0);
        float _1149 = (0.4000000059604644775390625 * _1147) - 1.0;
        float _1151 = (0.25 * _1147) - 1.0;
        float _1157 = _1141 * ((((1.5625 * _1149) * _1149) - 0.5625) * (_1151 * _1151));
        _1161 = _1127 + _1157;
        _1162 = _1128 + (_843 * _1157);
    }
    else
    {
        _1161 = _1127;
        _1162 = _1128;
    }
    float _1166 = exp((-2.2999999523162841796875) * dot(_1137, _1137)) * _1141;
    float3 _1169 = _843 * _1166;
    float2 _1176 = _756 + (_766 + float2(_845));
    float _1180 = float(all(uint2(_846) < _1105));
    float _1200;
    float3 _1201;
    if (_1109)
    {
        float2 _1184 = _1176 * float2(_1100);
        float _1186 = precise::min(dot(_1184, _1184), 4.0);
        float _1188 = (0.4000000059604644775390625 * _1186) - 1.0;
        float _1190 = (0.25 * _1186) - 1.0;
        float _1196 = _1180 * ((((1.5625 * _1188) * _1188) - 0.5625) * (_1190 * _1190));
        _1200 = _1161 + _1196;
        _1201 = _1162 + (_878 * _1196);
    }
    else
    {
        _1200 = _1161;
        _1201 = _1162;
    }
    float _1205 = exp((-2.2999999523162841796875) * dot(_1176, _1176)) * _1180;
    float3 _1208 = _878 * _1205;
    float2 _1215 = _756 + (_766 + float2(_880));
    float _1219 = float(all(uint2(_881) < _1105));
    float _1239;
    float3 _1240;
    if (_1109)
    {
        float2 _1223 = _1215 * float2(_1100);
        float _1225 = precise::min(dot(_1223, _1223), 4.0);
        float _1227 = (0.4000000059604644775390625 * _1225) - 1.0;
        float _1229 = (0.25 * _1225) - 1.0;
        float _1235 = _1219 * ((((1.5625 * _1227) * _1227) - 0.5625) * (_1229 * _1229));
        _1239 = _1200 + _1235;
        _1240 = _1201 + (_913 * _1235);
    }
    else
    {
        _1239 = _1200;
        _1240 = _1201;
    }
    float _1244 = exp((-2.2999999523162841796875) * dot(_1215, _1215)) * _1219;
    float3 _1247 = _913 * _1244;
    float2 _1254 = _756 + (_766 + float2(_914));
    float _1258 = float(all(uint2(_915) < _1105));
    float _1278;
    float3 _1279;
    if (_1109)
    {
        float2 _1262 = _1254 * float2(_1100);
        float _1264 = precise::min(dot(_1262, _1262), 4.0);
        float _1266 = (0.4000000059604644775390625 * _1264) - 1.0;
        float _1268 = (0.25 * _1264) - 1.0;
        float _1274 = _1258 * ((((1.5625 * _1266) * _1266) - 0.5625) * (_1268 * _1268));
        _1278 = _1239 + _1274;
        _1279 = _1240 + (_947 * _1274);
    }
    else
    {
        _1278 = _1239;
        _1279 = _1240;
    }
    float _1283 = exp((-2.2999999523162841796875) * dot(_1254, _1254)) * _1258;
    float3 _1286 = _947 * _1283;
    float2 _1293 = _756 + (_766 + float2(_948));
    float _1297 = float(all(uint2(_949) < _1105));
    float _1317;
    float3 _1318;
    if (_1109)
    {
        float2 _1301 = _1293 * float2(_1100);
        float _1303 = precise::min(dot(_1301, _1301), 4.0);
        float _1305 = (0.4000000059604644775390625 * _1303) - 1.0;
        float _1307 = (0.25 * _1303) - 1.0;
        float _1313 = _1297 * ((((1.5625 * _1305) * _1305) - 0.5625) * (_1307 * _1307));
        _1317 = _1278 + _1313;
        _1318 = _1279 + (_981 * _1313);
    }
    else
    {
        _1317 = _1278;
        _1318 = _1279;
    }
    float _1322 = exp((-2.2999999523162841796875) * dot(_1293, _1293)) * _1297;
    float3 _1325 = _981 * _1322;
    float2 _1332 = _756 + (_766 + float2(_983));
    float _1336 = float(all(uint2(_984) < _1105));
    float _1356;
    float3 _1357;
    if (_1109)
    {
        float2 _1340 = _1332 * float2(_1100);
        float _1342 = precise::min(dot(_1340, _1340), 4.0);
        float _1344 = (0.4000000059604644775390625 * _1342) - 1.0;
        float _1346 = (0.25 * _1342) - 1.0;
        float _1352 = _1336 * ((((1.5625 * _1344) * _1344) - 0.5625) * (_1346 * _1346));
        _1356 = _1317 + _1352;
        _1357 = _1318 + (_1016 * _1352);
    }
    else
    {
        _1356 = _1317;
        _1357 = _1318;
    }
    float _1361 = exp((-2.2999999523162841796875) * dot(_1332, _1332)) * _1336;
    float3 _1364 = _1016 * _1361;
    float2 _1371 = _756 + (_766 + float2(_1017));
    float _1375 = float(all(uint2(_1018) < _1105));
    float _1395;
    float3 _1396;
    if (_1109)
    {
        float2 _1379 = _1371 * float2(_1100);
        float _1381 = precise::min(dot(_1379, _1379), 4.0);
        float _1383 = (0.4000000059604644775390625 * _1381) - 1.0;
        float _1385 = (0.25 * _1381) - 1.0;
        float _1391 = _1375 * ((((1.5625 * _1383) * _1383) - 0.5625) * (_1385 * _1385));
        _1395 = _1356 + _1391;
        _1396 = _1357 + (_1050 * _1391);
    }
    else
    {
        _1395 = _1356;
        _1396 = _1357;
    }
    float _1400 = exp((-2.2999999523162841796875) * dot(_1371, _1371)) * _1375;
    float3 _1403 = _1050 * _1400;
    float2 _1410 = _756 + (_766 + float2(_1051));
    float _1414 = float(all(uint2(_1052) < _1105));
    float _1434;
    float3 _1435;
    if (_1109)
    {
        float2 _1418 = _1410 * float2(_1100);
        float _1420 = precise::min(dot(_1418, _1418), 4.0);
        float _1422 = (0.4000000059604644775390625 * _1420) - 1.0;
        float _1424 = (0.25 * _1420) - 1.0;
        float _1430 = _1414 * ((((1.5625 * _1422) * _1422) - 0.5625) * (_1424 * _1424));
        _1434 = _1395 + _1430;
        _1435 = _1396 + (_1084 * _1430);
    }
    else
    {
        _1434 = _1395;
        _1435 = _1396;
    }
    float _1439 = exp((-2.2999999523162841796875) * dot(_1410, _1410)) * _1414;
    float3 _1442 = _1084 * _1439;
    float _1446 = (((((((_1132 + _1166) + _1205) + _1244) + _1283) + _1322) + _1361) + _1400) + _1439;
    float3 _1450 = float3((abs(_1446) > 1.1754943508222875079687365372222e-38) ? _1446 : 1.0);
    float3 _1451 = ((((((((_1133 + _1169) + _1208) + _1247) + _1286) + _1325) + _1364) + _1403) + _1442) / _1450;
    float _1459 = _1434 * float(_1434 > 6.099999882280826568603515625e-05);
    float3 _1467;
    float _1468;
    if (_1459 > 6.099999882280826568603515625e-05)
    {
        _1467 = fast::clamp(_1435 / float3(_1459), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_808, _843), _878), _913), _947), _981), _1016), _1050), _1084), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_808, _843), _878), _913), _947), _981), _1016), _1050), _1084));
        _1468 = _1459 * 0.04625000059604644775390625;
    }
    else
    {
        _1467 = _1435;
        _1468 = _1459;
    }
    float _1471 = _767 ? 1.0 : _1468;
    float _1472 = _767 ? 0.0 : _747;
    float3 _1486 = (sqrt(abs(((((((((((_808 * _1133) + (_843 * _1169)) + (_878 * _1208)) + (_913 * _1247)) + (_947 * _1286)) + (_981 * _1325)) + (_1016 * _1364)) + (_1050 * _1403)) + (_1084 * _1442)) / _1450) - (_1451 * _1451))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_151 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_134 * _184, _184 - float2(0.5))) / float2(int2(int(_178.x), int(_178.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _218, precise::max(powr(_207, 0.5), _211)))));
    float3 _1489 = (_691 - _1451) / precise::max(_1486, float3(1.19299997436428384389728307724e-07));
    float3 _1504;
    if (length(_1489) > 1.0)
    {
        _1504 = mix((fast::normalize(_1489) * _1486) + _1451, _691, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_143, _138)) / _141), level(0.0)).x, fast::clamp(fast::clamp(_701 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _218) * (1.0 - _209), 0.0, 1.0)));
    }
    else
    {
        _1504 = _691;
    }
    float3 _1513 = mix(_1504, select(_1467, _1451, bool3(_767)), float3(fast::clamp(_1471 / precise::max(6.099999882280826568603515625e-05, (_1472 * float(_1472 > 6.099999882280826568603515625e-05)) + _1471), 0.0, 1.0)));
    float _1514 = _1513.x;
    float _1515 = _1513.y;
    float _1517 = _1513.z;
    float4 _1524 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1525 = _1524.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max(float3((_1514 + _1515) - _1517, _1514 + _1517, (_1514 - _1515) - _1517) / float3((_1525 == 0.0) ? 1.0 : _1525), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_701 + (sdk_hlsl_load(rw_new_locks, uint2(_705)).x * (1.0 - precise::max(0.0, _207))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _698))) * float(_737)), uint2(_705));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_705));
}

