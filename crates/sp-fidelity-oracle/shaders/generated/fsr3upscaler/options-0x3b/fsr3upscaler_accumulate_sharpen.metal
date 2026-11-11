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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(3)]], texture2d<float> r_farthest_depth_mip1 [[texture(4)]], texture2d<float> r_luma_instability [[texture(5)]], texture2d<float, access::read_write> rw_new_locks [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_lanczos_lut [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _124 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _128 = _124 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _133 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _135 = _128 + (cbFSR3Upscaler.fJitter / _133);
    float2 _139 = _133 - float2(0.5);
    float2 _142 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _144 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _153 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_144), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _155 = length(_153 * float2(3840.0, 2160.0));
    float2 _156 = _128 + _153;
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
    uint2 _183 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _189 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _206;
    if (_171)
    {
        _206 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _206 = true;
    }
    float4 _210 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _133, _139)) / _142), level(0.0));
    float _212 = fast::clamp(_210.x, 0.0, 1.0);
    float _214 = fast::clamp(_210.y, 0.0, 1.0);
    float _216 = fast::clamp(_210.z, 0.0, 1.0);
    float _218 = fast::clamp(_210.w, 0.0, 1.0);
    float _223 = _218 * float(rint(_218 * 100.0) > 1.0);
    bool _227;
    if (_171)
    {
        _227 = !_206;
    }
    else
    {
        _227 = false;
    }
    float3 _655;
    float _656;
    if (_227)
    {
        float2 _234 = (_156 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _236 = _234 - floor(_234);
        int2 _251 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _234.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _234.y)))));
        int2 _252 = _251 + int2(-1);
        int _254 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _258 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _265 = _251 + int2(0, -1);
        int2 _276 = _251 + int2(1, -1);
        int2 _287 = _251 + int2(2, -1);
        int2 _298 = _251 + int2(-1, 0);
        float4 _318 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_251.x, _254)), max(1, min(_251.y, _258))))), 0u);
        int2 _319 = _251 + int2(1, 0);
        float4 _329 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_319.x, _254)), max(1, min(_319.y, _258))))), 0u);
        int2 _330 = _251 + int2(2, 0);
        int2 _341 = _251 + int2(-1, 1);
        int2 _352 = _251 + int2(0, 1);
        float4 _362 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_352.x, _254)), max(1, min(_352.y, _258))))), 0u);
        int2 _363 = _251 + int2(1);
        float4 _373 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_363.x, _254)), max(1, min(_363.y, _258))))), 0u);
        int2 _374 = _251 + int2(2, 1);
        int2 _385 = _251 + int2(-1, 2);
        int2 _396 = _251 + int2(0, 2);
        int2 _407 = _251 + int2(1, 2);
        int2 _418 = _251 + int2(2);
        float _429 = _236.x;
        float2 _435 = float2(abs((-1.0) - _429) * 0.5, 0.5);
        float4 _437 = r_lanczos_lut.sample(s_LinearClamp, _435, level(0.0));
        float _438 = _437.x;
        float2 _444 = float2(abs(-_429) * 0.5, 0.5);
        float4 _446 = r_lanczos_lut.sample(s_LinearClamp, _444, level(0.0));
        float _447 = _446.x;
        float2 _453 = float2(abs(1.0 - _429) * 0.5, 0.5);
        float4 _455 = r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0));
        float _456 = _455.x;
        float2 _462 = float2(abs(2.0 - _429) * 0.5, 0.5);
        float4 _464 = r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0));
        float _465 = _464.x;
        float4 _481 = r_lanczos_lut.sample(s_LinearClamp, _435, level(0.0));
        float _482 = _481.x;
        float4 _486 = r_lanczos_lut.sample(s_LinearClamp, _444, level(0.0));
        float _487 = _486.x;
        float4 _491 = r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0));
        float _492 = _491.x;
        float4 _496 = r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0));
        float _497 = _496.x;
        float4 _513 = r_lanczos_lut.sample(s_LinearClamp, _435, level(0.0));
        float _514 = _513.x;
        float4 _518 = r_lanczos_lut.sample(s_LinearClamp, _444, level(0.0));
        float _519 = _518.x;
        float4 _523 = r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0));
        float _524 = _523.x;
        float4 _528 = r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0));
        float _529 = _528.x;
        float4 _545 = r_lanczos_lut.sample(s_LinearClamp, _435, level(0.0));
        float _546 = _545.x;
        float4 _550 = r_lanczos_lut.sample(s_LinearClamp, _444, level(0.0));
        float _551 = _550.x;
        float4 _555 = r_lanczos_lut.sample(s_LinearClamp, _453, level(0.0));
        float _556 = _555.x;
        float4 _560 = r_lanczos_lut.sample(s_LinearClamp, _462, level(0.0));
        float _561 = _560.x;
        float _574 = _236.y;
        float4 _582 = r_lanczos_lut.sample(s_LinearClamp, float2(abs((-1.0) - _574) * 0.5, 0.5), level(0.0));
        float _583 = _582.x;
        float4 _591 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(-_574) * 0.5, 0.5), level(0.0));
        float _592 = _591.x;
        float4 _600 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(1.0 - _574) * 0.5, 0.5), level(0.0));
        float _601 = _600.x;
        float4 _609 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(2.0 - _574) * 0.5, 0.5), level(0.0));
        float _610 = _609.x;
        float4 _615 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_252.x, _254)), max(1, min(_252.y, _258))))), 0u) * _438) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_265.x, _254)), max(1, min(_265.y, _258))))), 0u) * _447)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_276.x, _254)), max(1, min(_276.y, _258))))), 0u) * _456)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_287.x, _254)), max(1, min(_287.y, _258))))), 0u) * _465)) / float4(((_438 + _447) + _456) + _465)) * _583) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_298.x, _254)), max(1, min(_298.y, _258))))), 0u) * _482) + (_318 * _487)) + (_329 * _492)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_330.x, _254)), max(1, min(_330.y, _258))))), 0u) * _497)) / float4(((_482 + _487) + _492) + _497)) * _592)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_341.x, _254)), max(1, min(_341.y, _258))))), 0u) * _514) + (_362 * _519)) + (_373 * _524)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_374.x, _254)), max(1, min(_374.y, _258))))), 0u) * _529)) / float4(((_514 + _519) + _524) + _529)) * _601);
        float4 _629 = fast::clamp((_615 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_385.x, _254)), max(1, min(_385.y, _258))))), 0u) * _546) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_396.x, _254)), max(1, min(_396.y, _258))))), 0u) * _551)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_407.x, _254)), max(1, min(_407.y, _258))))), 0u) * _556)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_418.x, _254)), max(1, min(_418.y, _258))))), 0u) * _561)) / float4(((_546 + _551) + _556) + _561)) * _610)) / float4(((_583 + _592) + _601) + _610), precise::min(precise::min(precise::min(_318, _329), _362), _373), precise::max(precise::max(precise::max(_318, _329), _362), _373));
        float4 _635 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _636 = _635.x;
        float3 _639 = (_629.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_636 == 0.0) ? 1.0 : _636);
        float _640 = _639.x;
        float _643 = 0.5 * _639.y;
        float _645 = _639.z;
        float _646 = 0.25 * _645;
        _655 = float3(((0.25 * _640) + _643) + _646, 0.5 * (_640 - _645), (((-0.25) * _640) + _643) - _646);
        _656 = _629.w;
    }
    else
    {
        _655 = float3(0.0);
        _656 = 0.0;
    }
    float _662 = precise::max(fast::clamp(_216, 0.0, 1.0), precise::max(_212, _214));
    float _665 = precise::max(0.0, (_656 * float(!_206)) - (_662 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _685 = _128 - _153;
    float _686 = _685.x;
    bool _691;
    if (_686 >= 0.0)
    {
        _691 = _686 <= 1.0;
    }
    else
    {
        _691 = false;
    }
    bool _700;
    if (_691)
    {
        float _694 = _685.y;
        bool _699;
        if (_694 >= 0.0)
        {
            _699 = _694 <= 1.0;
        }
        else
        {
            _699 = false;
        }
        _700 = _699;
    }
    else
    {
        _700 = false;
    }
    float _710 = precise::min(_223, mix(_223, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_155 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _713 = _124 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _715 = int2(floor(_713));
    float2 _718 = (float2(_715) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _719 = _718 - _713;
    bool _722 = _718.x > _713.x;
    bool _726 = _718.y > _713.y;
    int2 _728 = int2(_722 ? (-2) : (-1), _726 ? (-2) : (-1));
    float2 _729 = float2(_728);
    bool _730 = _223 == 0.0;
    int _731 = _722 ? 3 : 0;
    int _732 = _726 ? 3 : 0;
    int2 _733 = int2(_731, _732);
    int2 _734 = _715 + _728;
    int2 _735 = _734 + _733;
    int _738 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _743 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _753 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _754 = _753.x;
    float3 _757 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_735.x, _738)), max(0, min(_735.y, _743))))), 0u).xyz) * ((_754 == 0.0) ? 1.0 : _754);
    float _758 = _757.x;
    float _761 = 0.5 * _757.y;
    float _763 = _757.z;
    float _764 = 0.25 * _763;
    spvUnsafeArray<float3, 9> _120;
    _120[0] = float3(((0.25 * _758) + _761) + _764, 0.5 * (_758 - _763), (((-0.25) * _758) + _761) - _764);
    int _773 = _722 ? 2 : 1;
    int2 _774 = int2(_773, _732);
    int2 _775 = _734 + _774;
    float4 _789 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _790 = _789.x;
    float3 _793 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_775.x, _738)), max(0, min(_775.y, _743))))), 0u).xyz) * ((_790 == 0.0) ? 1.0 : _790);
    float _794 = _793.x;
    float _797 = 0.5 * _793.y;
    float _799 = _793.z;
    float _800 = 0.25 * _799;
    _120[1] = float3(((0.25 * _794) + _797) + _800, 0.5 * (_794 - _799), (((-0.25) * _794) + _797) - _800);
    int _809 = _722 ? 1 : 2;
    int2 _810 = int2(_809, _732);
    int2 _811 = _734 + _810;
    float4 _825 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _826 = _825.x;
    float3 _829 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_811.x, _738)), max(0, min(_811.y, _743))))), 0u).xyz) * ((_826 == 0.0) ? 1.0 : _826);
    float _830 = _829.x;
    float _833 = 0.5 * _829.y;
    float _835 = _829.z;
    float _836 = 0.25 * _835;
    _120[2] = float3(((0.25 * _830) + _833) + _836, 0.5 * (_830 - _835), (((-0.25) * _830) + _833) - _836);
    int _845 = _726 ? 2 : 1;
    int2 _846 = int2(_731, _845);
    int2 _847 = _734 + _846;
    float4 _861 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _862 = _861.x;
    float3 _865 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_847.x, _738)), max(0, min(_847.y, _743))))), 0u).xyz) * ((_862 == 0.0) ? 1.0 : _862);
    float _866 = _865.x;
    float _869 = 0.5 * _865.y;
    float _871 = _865.z;
    float _872 = 0.25 * _871;
    _120[3] = float3(((0.25 * _866) + _869) + _872, 0.5 * (_866 - _871), (((-0.25) * _866) + _869) - _872);
    int2 _881 = int2(_773, _845);
    int2 _882 = _734 + _881;
    float4 _896 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _897 = _896.x;
    float3 _900 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_882.x, _738)), max(0, min(_882.y, _743))))), 0u).xyz) * ((_897 == 0.0) ? 1.0 : _897);
    float _901 = _900.x;
    float _904 = 0.5 * _900.y;
    float _906 = _900.z;
    float _907 = 0.25 * _906;
    _120[4] = float3(((0.25 * _901) + _904) + _907, 0.5 * (_901 - _906), (((-0.25) * _901) + _904) - _907);
    int2 _916 = int2(_809, _845);
    int2 _917 = _734 + _916;
    float4 _931 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _932 = _931.x;
    float3 _935 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_917.x, _738)), max(0, min(_917.y, _743))))), 0u).xyz) * ((_932 == 0.0) ? 1.0 : _932);
    float _936 = _935.x;
    float _939 = 0.5 * _935.y;
    float _941 = _935.z;
    float _942 = 0.25 * _941;
    _120[5] = float3(((0.25 * _936) + _939) + _942, 0.5 * (_936 - _941), (((-0.25) * _936) + _939) - _942);
    int _951 = _726 ? 1 : 2;
    int2 _952 = int2(_731, _951);
    int2 _953 = _734 + _952;
    float4 _967 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _968 = _967.x;
    float3 _971 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_953.x, _738)), max(0, min(_953.y, _743))))), 0u).xyz) * ((_968 == 0.0) ? 1.0 : _968);
    float _972 = _971.x;
    float _975 = 0.5 * _971.y;
    float _977 = _971.z;
    float _978 = 0.25 * _977;
    _120[6] = float3(((0.25 * _972) + _975) + _978, 0.5 * (_972 - _977), (((-0.25) * _972) + _975) - _978);
    int2 _987 = int2(_773, _951);
    int2 _988 = _734 + _987;
    float4 _1002 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1003 = _1002.x;
    float3 _1006 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_988.x, _738)), max(0, min(_988.y, _743))))), 0u).xyz) * ((_1003 == 0.0) ? 1.0 : _1003);
    float _1007 = _1006.x;
    float _1010 = 0.5 * _1006.y;
    float _1012 = _1006.z;
    float _1013 = 0.25 * _1012;
    _120[7] = float3(((0.25 * _1007) + _1010) + _1013, 0.5 * (_1007 - _1012), (((-0.25) * _1007) + _1010) - _1013);
    int2 _1022 = int2(_809, _951);
    int2 _1023 = _734 + _1022;
    float4 _1037 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1038 = _1037.x;
    float3 _1041 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1023.x, _738)), max(0, min(_1023.y, _743))))), 0u).xyz) * ((_1038 == 0.0) ? 1.0 : _1038);
    float _1042 = _1041.x;
    float _1045 = 0.5 * _1041.y;
    float _1047 = _1041.z;
    float _1048 = 0.25 * _1047;
    _120[8] = float3(((0.25 * _1042) + _1045) + _1048, 0.5 * (_1042 - _1047), (((-0.25) * _1042) + _1045) - _1048);
    if (_730)
    {
        for (int _1060 = 0; _1060 < 9; )
        {
            float _1071 = (_120[_1060].x + _120[_1060].y) - _120[_1060].z;
            float _1072 = _120[_1060].x + _120[_1060].z;
            float _1074 = (_120[_1060].x - _120[_1060].y) - _120[_1060].z;
            float3 _1081 = float3(_1071, _1072, _1074) / float3(precise::max(precise::max(0.0, _1071), precise::max(_1072, _1074)) + 1.0);
            float _1082 = _1081.x;
            float _1085 = 0.5 * _1081.y;
            float _1087 = _1081.z;
            float _1088 = 0.25 * _1087;
            _120[_1060] = float3(((0.25 * _1082) + _1085) + _1088, 0.5 * (_1082 - _1087), (((-0.25) * _1082) + _1085) - _1088);
            _1060++;
            continue;
        }
    }
    float _1100 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1111 = mix(precise::max(1.0, (1.0 + _1100) * 0.300000011920928955078125), _1100, precise::min(1.0 - (_214 * 0.5), precise::min(1.0 - _216, fast::clamp(_710 * 5.0, 0.0, 1.0))));
    float2 _1114 = _719 + (_729 + float2(_733));
    uint2 _1116 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1119 = float(all(uint2(_735) < _1116));
    bool _1120 = !_730;
    float _1139;
    float3 _1140;
    if (_1120)
    {
        float2 _1124 = _1114 * float2(_1111);
        float _1126 = precise::min(dot(_1124, _1124), 4.0);
        float _1128 = (0.4000000059604644775390625 * _1126) - 1.0;
        float _1130 = (0.25 * _1126) - 1.0;
        float _1136 = _1119 * ((((1.5625 * _1128) * _1128) - 0.5625) * (_1130 * _1130));
        _1139 = _1136;
        _1140 = _120[0] * _1136;
    }
    else
    {
        _1139 = 0.0;
        _1140 = float3(0.0);
    }
    float _1144 = exp((-2.2999999523162841796875) * dot(_1114, _1114)) * _1119;
    float3 _1146 = _120[0] * _1144;
    float2 _1150 = _719 + (_729 + float2(_774));
    float _1154 = float(all(uint2(_775) < _1116));
    float _1175;
    float3 _1176;
    if (_1120)
    {
        float2 _1158 = _1150 * float2(_1111);
        float _1160 = precise::min(dot(_1158, _1158), 4.0);
        float _1162 = (0.4000000059604644775390625 * _1160) - 1.0;
        float _1164 = (0.25 * _1160) - 1.0;
        float _1170 = _1154 * ((((1.5625 * _1162) * _1162) - 0.5625) * (_1164 * _1164));
        _1175 = _1139 + _1170;
        _1176 = _1140 + (_120[1] * _1170);
    }
    else
    {
        _1175 = _1139;
        _1176 = _1140;
    }
    float _1180 = exp((-2.2999999523162841796875) * dot(_1150, _1150)) * _1154;
    float3 _1184 = _120[1] * _1180;
    float2 _1191 = _719 + (_729 + float2(_810));
    float _1195 = float(all(uint2(_811) < _1116));
    float _1216;
    float3 _1217;
    if (_1120)
    {
        float2 _1199 = _1191 * float2(_1111);
        float _1201 = precise::min(dot(_1199, _1199), 4.0);
        float _1203 = (0.4000000059604644775390625 * _1201) - 1.0;
        float _1205 = (0.25 * _1201) - 1.0;
        float _1211 = _1195 * ((((1.5625 * _1203) * _1203) - 0.5625) * (_1205 * _1205));
        _1216 = _1175 + _1211;
        _1217 = _1176 + (_120[2] * _1211);
    }
    else
    {
        _1216 = _1175;
        _1217 = _1176;
    }
    float _1221 = exp((-2.2999999523162841796875) * dot(_1191, _1191)) * _1195;
    float3 _1225 = _120[2] * _1221;
    float2 _1232 = _719 + (_729 + float2(_846));
    float _1236 = float(all(uint2(_847) < _1116));
    float _1257;
    float3 _1258;
    if (_1120)
    {
        float2 _1240 = _1232 * float2(_1111);
        float _1242 = precise::min(dot(_1240, _1240), 4.0);
        float _1244 = (0.4000000059604644775390625 * _1242) - 1.0;
        float _1246 = (0.25 * _1242) - 1.0;
        float _1252 = _1236 * ((((1.5625 * _1244) * _1244) - 0.5625) * (_1246 * _1246));
        _1257 = _1216 + _1252;
        _1258 = _1217 + (_120[3] * _1252);
    }
    else
    {
        _1257 = _1216;
        _1258 = _1217;
    }
    float _1262 = exp((-2.2999999523162841796875) * dot(_1232, _1232)) * _1236;
    float3 _1266 = _120[3] * _1262;
    float2 _1273 = _719 + (_729 + float2(_881));
    float _1277 = float(all(uint2(_882) < _1116));
    float _1298;
    float3 _1299;
    if (_1120)
    {
        float2 _1281 = _1273 * float2(_1111);
        float _1283 = precise::min(dot(_1281, _1281), 4.0);
        float _1285 = (0.4000000059604644775390625 * _1283) - 1.0;
        float _1287 = (0.25 * _1283) - 1.0;
        float _1293 = _1277 * ((((1.5625 * _1285) * _1285) - 0.5625) * (_1287 * _1287));
        _1298 = _1257 + _1293;
        _1299 = _1258 + (_120[4] * _1293);
    }
    else
    {
        _1298 = _1257;
        _1299 = _1258;
    }
    float _1303 = exp((-2.2999999523162841796875) * dot(_1273, _1273)) * _1277;
    float3 _1307 = _120[4] * _1303;
    float2 _1314 = _719 + (_729 + float2(_916));
    float _1318 = float(all(uint2(_917) < _1116));
    float _1339;
    float3 _1340;
    if (_1120)
    {
        float2 _1322 = _1314 * float2(_1111);
        float _1324 = precise::min(dot(_1322, _1322), 4.0);
        float _1326 = (0.4000000059604644775390625 * _1324) - 1.0;
        float _1328 = (0.25 * _1324) - 1.0;
        float _1334 = _1318 * ((((1.5625 * _1326) * _1326) - 0.5625) * (_1328 * _1328));
        _1339 = _1298 + _1334;
        _1340 = _1299 + (_120[5] * _1334);
    }
    else
    {
        _1339 = _1298;
        _1340 = _1299;
    }
    float _1344 = exp((-2.2999999523162841796875) * dot(_1314, _1314)) * _1318;
    float3 _1348 = _120[5] * _1344;
    float2 _1355 = _719 + (_729 + float2(_952));
    float _1359 = float(all(uint2(_953) < _1116));
    float _1380;
    float3 _1381;
    if (_1120)
    {
        float2 _1363 = _1355 * float2(_1111);
        float _1365 = precise::min(dot(_1363, _1363), 4.0);
        float _1367 = (0.4000000059604644775390625 * _1365) - 1.0;
        float _1369 = (0.25 * _1365) - 1.0;
        float _1375 = _1359 * ((((1.5625 * _1367) * _1367) - 0.5625) * (_1369 * _1369));
        _1380 = _1339 + _1375;
        _1381 = _1340 + (_120[6] * _1375);
    }
    else
    {
        _1380 = _1339;
        _1381 = _1340;
    }
    float _1385 = exp((-2.2999999523162841796875) * dot(_1355, _1355)) * _1359;
    float3 _1389 = _120[6] * _1385;
    float2 _1396 = _719 + (_729 + float2(_987));
    float _1400 = float(all(uint2(_988) < _1116));
    float _1421;
    float3 _1422;
    if (_1120)
    {
        float2 _1404 = _1396 * float2(_1111);
        float _1406 = precise::min(dot(_1404, _1404), 4.0);
        float _1408 = (0.4000000059604644775390625 * _1406) - 1.0;
        float _1410 = (0.25 * _1406) - 1.0;
        float _1416 = _1400 * ((((1.5625 * _1408) * _1408) - 0.5625) * (_1410 * _1410));
        _1421 = _1380 + _1416;
        _1422 = _1381 + (_120[7] * _1416);
    }
    else
    {
        _1421 = _1380;
        _1422 = _1381;
    }
    float _1426 = exp((-2.2999999523162841796875) * dot(_1396, _1396)) * _1400;
    float3 _1430 = _120[7] * _1426;
    float2 _1437 = _719 + (_729 + float2(_1022));
    float _1441 = float(all(uint2(_1023) < _1116));
    float _1462;
    float3 _1463;
    if (_1120)
    {
        float2 _1445 = _1437 * float2(_1111);
        float _1447 = precise::min(dot(_1445, _1445), 4.0);
        float _1449 = (0.4000000059604644775390625 * _1447) - 1.0;
        float _1451 = (0.25 * _1447) - 1.0;
        float _1457 = _1441 * ((((1.5625 * _1449) * _1449) - 0.5625) * (_1451 * _1451));
        _1462 = _1421 + _1457;
        _1463 = _1422 + (_120[8] * _1457);
    }
    else
    {
        _1462 = _1421;
        _1463 = _1422;
    }
    float _1467 = exp((-2.2999999523162841796875) * dot(_1437, _1437)) * _1441;
    float3 _1471 = _120[8] * _1467;
    float _1475 = (((((((_1144 + _1180) + _1221) + _1262) + _1303) + _1344) + _1385) + _1426) + _1467;
    float3 _1479 = float3((abs(_1475) > 1.1754943508222875079687365372222e-38) ? _1475 : 1.0);
    float3 _1480 = ((((((((_1146 + _1184) + _1225) + _1266) + _1307) + _1348) + _1389) + _1430) + _1471) / _1479;
    float _1488 = _1462 * float(_1462 > 6.099999882280826568603515625e-05);
    float3 _1496;
    float _1497;
    if (_1488 > 6.099999882280826568603515625e-05)
    {
        _1496 = fast::clamp(_1463 / float3(_1488), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_120[0], _120[1]), _120[2]), _120[3]), _120[4]), _120[5]), _120[6]), _120[7]), _120[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_120[0], _120[1]), _120[2]), _120[3]), _120[4]), _120[5]), _120[6]), _120[7]), _120[8]));
        _1497 = _1488 * 0.04625000059604644775390625;
    }
    else
    {
        _1496 = _1463;
        _1497 = _1488;
    }
    float3 _1529;
    if (_730)
    {
        float _1500 = _1480.x;
        float _1501 = _1480.y;
        float _1503 = _1480.z;
        float _1504 = (_1500 + _1501) - _1503;
        float _1505 = _1500 + _1503;
        float _1507 = (_1500 - _1501) - _1503;
        float3 _1514 = float3(_1504, _1505, _1507) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1504, precise::max(_1505, _1507))));
        float _1515 = _1514.x;
        float _1518 = 0.5 * _1514.y;
        float _1520 = _1514.z;
        float _1521 = 0.25 * _1520;
        _1529 = float3(((0.25 * _1515) + _1518) + _1521, 0.5 * (_1515 - _1520), (((-0.25) * _1515) + _1518) - _1521);
    }
    else
    {
        _1529 = _1496;
    }
    float _1530 = _730 ? 1.0 : _1497;
    float _1531 = _730 ? 0.0 : _710;
    float3 _1545 = (sqrt(abs(((((((((((_120[0] * _1146) + (_120[1] * _1184)) + (_120[2] * _1225)) + (_120[3] * _1266)) + (_120[4] * _1307)) + (_120[5] * _1348)) + (_120[6] * _1389)) + (_120[7] * _1430)) + (_120[8] * _1471)) / _1479) - (_1480 * _1480))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_155 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _189, _189 - float2(0.5))) / float2(int2(int(_183.x), int(_183.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _223, precise::max(powr(_212, 0.5), _216)))));
    float3 _1548 = (_655 - _1480) / precise::max(_1545, float3(1.19299997436428384389728307724e-07));
    float3 _1563;
    if (length(_1548) > 1.0)
    {
        _1563 = mix((fast::normalize(_1548) * _1545) + _1480, _655, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_128 * _133, _139)) / _142), level(0.0)).x, fast::clamp(fast::clamp(_665 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _223) * (1.0 - _214), 0.0, 1.0)));
    }
    else
    {
        _1563 = _655;
    }
    float _1573 = (_1529.x + _1529.y) - _1529.z;
    float _1574 = _1529.x + _1529.z;
    float _1576 = (_1529.x - _1529.y) - _1529.z;
    float3 _1583 = float3(_1573, _1574, _1576) / float3(precise::max(precise::max(0.0, _1573), precise::max(_1574, _1576)) + 1.0);
    float _1584 = _1583.x;
    float _1587 = 0.5 * _1583.y;
    float _1589 = _1583.z;
    float _1590 = 0.25 * _1589;
    float _1602 = (_1563.x + _1563.y) - _1563.z;
    float _1603 = _1563.x + _1563.z;
    float _1605 = (_1563.x - _1563.y) - _1563.z;
    float3 _1612 = float3(_1602, _1603, _1605) / float3(precise::max(precise::max(0.0, _1602), precise::max(_1603, _1605)) + 1.0);
    float _1613 = _1612.x;
    float _1616 = 0.5 * _1612.y;
    float _1618 = _1612.z;
    float _1619 = 0.25 * _1618;
    float3 _1630 = mix(float3(((0.25 * _1613) + _1616) + _1619, 0.5 * (_1613 - _1618), (((-0.25) * _1613) + _1616) - _1619), float3(((0.25 * _1584) + _1587) + _1590, 0.5 * (_1584 - _1589), (((-0.25) * _1584) + _1587) - _1590), float3(fast::clamp(_1530 / precise::max(6.099999882280826568603515625e-05, (_1531 * float(_1531 > 6.099999882280826568603515625e-05)) + _1530), 0.0, 1.0)));
    float _1635 = (_1630.x + _1630.y) - _1630.z;
    float _1636 = _1630.x + _1630.z;
    float _1638 = (_1630.x - _1630.y) - _1630.z;
    float4 _1647 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1648 = _1647.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max((float3(_1635, _1636, _1638) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1635, precise::max(_1636, _1638))))) / float3((_1648 == 0.0) ? 1.0 : _1648), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_665 + (sdk_hlsl_load(rw_new_locks, uint2(_144)).x * (1.0 - precise::max(0.0, _212))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _662))) * float(_700)), uint2(_144));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_144));
}

