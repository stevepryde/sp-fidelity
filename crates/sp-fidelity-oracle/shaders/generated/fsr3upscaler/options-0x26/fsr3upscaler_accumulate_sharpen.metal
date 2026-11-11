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
    float2 _124 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _128 = _124 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _133 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _135 = _128 + (cbFSR3Upscaler.fJitter / _133);
    float2 _139 = _133 - float2(0.5);
    float2 _142 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _144 = _128 * _133;
    float2 _149 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_144))), 0u).xy;
    float _151 = length(_149 * float2(3840.0, 2160.0));
    float2 _152 = _128 + _149;
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
    float4 _205 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _133, _139)) / _142), level(0.0));
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
    float3 _778;
    float _779;
    if (_222)
    {
        float2 _229 = (_152 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _231 = _229 - floor(_229);
        int2 _246 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _229.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _229.y)))));
        int2 _247 = _246 + int2(-1);
        int _249 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _253 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _260 = _246 + int2(0, -1);
        int2 _271 = _246 + int2(1, -1);
        int2 _282 = _246 + int2(2, -1);
        int2 _293 = _246 + int2(-1, 0);
        float4 _313 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_246.x, _249)), max(1, min(_246.y, _253))))), 0u);
        int2 _314 = _246 + int2(1, 0);
        float4 _324 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_314.x, _249)), max(1, min(_314.y, _253))))), 0u);
        int2 _325 = _246 + int2(2, 0);
        int2 _336 = _246 + int2(-1, 1);
        int2 _347 = _246 + int2(0, 1);
        float4 _357 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_347.x, _249)), max(1, min(_347.y, _253))))), 0u);
        int2 _358 = _246 + int2(1);
        float4 _368 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_358.x, _249)), max(1, min(_358.y, _253))))), 0u);
        int2 _369 = _246 + int2(2, 1);
        int2 _380 = _246 + int2(-1, 2);
        int2 _391 = _246 + int2(0, 2);
        int2 _402 = _246 + int2(1, 2);
        int2 _413 = _246 + int2(2);
        float _424 = _231.x;
        float _427 = precise::min(abs((-1.0) - _424), 2.0);
        bool _429 = abs(_427) < 6.099999882280826568603515625e-05;
        float _440;
        if (_429)
        {
            _440 = 1.0;
        }
        else
        {
            float _433 = 3.1415927410125732421875 * _427;
            float _436 = 1.57079637050628662109375 * _427;
            _440 = (sin(_433) / _433) * (sin(_436) / _436);
        }
        float _443 = precise::min(abs(-_424), 2.0);
        bool _445 = abs(_443) < 6.099999882280826568603515625e-05;
        float _456;
        if (_445)
        {
            _456 = 1.0;
        }
        else
        {
            float _449 = 3.1415927410125732421875 * _443;
            float _452 = 1.57079637050628662109375 * _443;
            _456 = (sin(_449) / _449) * (sin(_452) / _452);
        }
        float _459 = precise::min(abs(1.0 - _424), 2.0);
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
        float _475 = precise::min(abs(2.0 - _424), 2.0);
        bool _477 = abs(_475) < 6.099999882280826568603515625e-05;
        float _488;
        if (_477)
        {
            _488 = 1.0;
        }
        else
        {
            float _481 = 3.1415927410125732421875 * _475;
            float _484 = 1.57079637050628662109375 * _475;
            _488 = (sin(_481) / _481) * (sin(_484) / _484);
        }
        float _511;
        if (_429)
        {
            _511 = 1.0;
        }
        else
        {
            float _504 = 3.1415927410125732421875 * _427;
            float _507 = 1.57079637050628662109375 * _427;
            _511 = (sin(_504) / _504) * (sin(_507) / _507);
        }
        float _522;
        if (_445)
        {
            _522 = 1.0;
        }
        else
        {
            float _515 = 3.1415927410125732421875 * _443;
            float _518 = 1.57079637050628662109375 * _443;
            _522 = (sin(_515) / _515) * (sin(_518) / _518);
        }
        float _533;
        if (_461)
        {
            _533 = 1.0;
        }
        else
        {
            float _526 = 3.1415927410125732421875 * _459;
            float _529 = 1.57079637050628662109375 * _459;
            _533 = (sin(_526) / _526) * (sin(_529) / _529);
        }
        float _544;
        if (_477)
        {
            _544 = 1.0;
        }
        else
        {
            float _537 = 3.1415927410125732421875 * _475;
            float _540 = 1.57079637050628662109375 * _475;
            _544 = (sin(_537) / _537) * (sin(_540) / _540);
        }
        float _567;
        if (_429)
        {
            _567 = 1.0;
        }
        else
        {
            float _560 = 3.1415927410125732421875 * _427;
            float _563 = 1.57079637050628662109375 * _427;
            _567 = (sin(_560) / _560) * (sin(_563) / _563);
        }
        float _578;
        if (_445)
        {
            _578 = 1.0;
        }
        else
        {
            float _571 = 3.1415927410125732421875 * _443;
            float _574 = 1.57079637050628662109375 * _443;
            _578 = (sin(_571) / _571) * (sin(_574) / _574);
        }
        float _589;
        if (_461)
        {
            _589 = 1.0;
        }
        else
        {
            float _582 = 3.1415927410125732421875 * _459;
            float _585 = 1.57079637050628662109375 * _459;
            _589 = (sin(_582) / _582) * (sin(_585) / _585);
        }
        float _600;
        if (_477)
        {
            _600 = 1.0;
        }
        else
        {
            float _593 = 3.1415927410125732421875 * _475;
            float _596 = 1.57079637050628662109375 * _475;
            _600 = (sin(_593) / _593) * (sin(_596) / _596);
        }
        float _623;
        if (_429)
        {
            _623 = 1.0;
        }
        else
        {
            float _616 = 3.1415927410125732421875 * _427;
            float _619 = 1.57079637050628662109375 * _427;
            _623 = (sin(_616) / _616) * (sin(_619) / _619);
        }
        float _634;
        if (_445)
        {
            _634 = 1.0;
        }
        else
        {
            float _627 = 3.1415927410125732421875 * _443;
            float _630 = 1.57079637050628662109375 * _443;
            _634 = (sin(_627) / _627) * (sin(_630) / _630);
        }
        float _645;
        if (_461)
        {
            _645 = 1.0;
        }
        else
        {
            float _638 = 3.1415927410125732421875 * _459;
            float _641 = 1.57079637050628662109375 * _459;
            _645 = (sin(_638) / _638) * (sin(_641) / _641);
        }
        float _656;
        if (_477)
        {
            _656 = 1.0;
        }
        else
        {
            float _649 = 3.1415927410125732421875 * _475;
            float _652 = 1.57079637050628662109375 * _475;
            _656 = (sin(_649) / _649) * (sin(_652) / _652);
        }
        float _669 = _231.y;
        float _672 = precise::min(abs((-1.0) - _669), 2.0);
        float _685;
        if (abs(_672) < 6.099999882280826568603515625e-05)
        {
            _685 = 1.0;
        }
        else
        {
            float _678 = 3.1415927410125732421875 * _672;
            float _681 = 1.57079637050628662109375 * _672;
            _685 = (sin(_678) / _678) * (sin(_681) / _681);
        }
        float _688 = precise::min(abs(-_669), 2.0);
        float _701;
        if (abs(_688) < 6.099999882280826568603515625e-05)
        {
            _701 = 1.0;
        }
        else
        {
            float _694 = 3.1415927410125732421875 * _688;
            float _697 = 1.57079637050628662109375 * _688;
            _701 = (sin(_694) / _694) * (sin(_697) / _697);
        }
        float _704 = precise::min(abs(1.0 - _669), 2.0);
        float _717;
        if (abs(_704) < 6.099999882280826568603515625e-05)
        {
            _717 = 1.0;
        }
        else
        {
            float _710 = 3.1415927410125732421875 * _704;
            float _713 = 1.57079637050628662109375 * _704;
            _717 = (sin(_710) / _710) * (sin(_713) / _713);
        }
        float _720 = precise::min(abs(2.0 - _669), 2.0);
        float _733;
        if (abs(_720) < 6.099999882280826568603515625e-05)
        {
            _733 = 1.0;
        }
        else
        {
            float _726 = 3.1415927410125732421875 * _720;
            float _729 = 1.57079637050628662109375 * _720;
            _733 = (sin(_726) / _726) * (sin(_729) / _729);
        }
        float4 _738 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_247.x, _249)), max(1, min(_247.y, _253))))), 0u) * _440) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_260.x, _249)), max(1, min(_260.y, _253))))), 0u) * _456)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_271.x, _249)), max(1, min(_271.y, _253))))), 0u) * _472)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_282.x, _249)), max(1, min(_282.y, _253))))), 0u) * _488)) / float4(((_440 + _456) + _472) + _488)) * _685) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_293.x, _249)), max(1, min(_293.y, _253))))), 0u) * _511) + (_313 * _522)) + (_324 * _533)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_325.x, _249)), max(1, min(_325.y, _253))))), 0u) * _544)) / float4(((_511 + _522) + _533) + _544)) * _701)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_336.x, _249)), max(1, min(_336.y, _253))))), 0u) * _567) + (_357 * _578)) + (_368 * _589)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_369.x, _249)), max(1, min(_369.y, _253))))), 0u) * _600)) / float4(((_567 + _578) + _589) + _600)) * _717);
        float4 _752 = fast::clamp((_738 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_380.x, _249)), max(1, min(_380.y, _253))))), 0u) * _623) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_391.x, _249)), max(1, min(_391.y, _253))))), 0u) * _634)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_402.x, _249)), max(1, min(_402.y, _253))))), 0u) * _645)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_413.x, _249)), max(1, min(_413.y, _253))))), 0u) * _656)) / float4(((_623 + _634) + _645) + _656)) * _733)) / float4(((_685 + _701) + _717) + _733), precise::min(precise::min(precise::min(_313, _324), _357), _368), precise::max(precise::max(precise::max(_313, _324), _357), _368));
        float4 _758 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _759 = _758.x;
        float3 _762 = (_752.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_759 == 0.0) ? 1.0 : _759);
        float _763 = _762.x;
        float _766 = 0.5 * _762.y;
        float _768 = _762.z;
        float _769 = 0.25 * _768;
        _778 = float3(((0.25 * _763) + _766) + _769, 0.5 * (_763 - _768), (((-0.25) * _763) + _766) - _769);
        _779 = _752.w;
    }
    else
    {
        _778 = float3(0.0);
        _779 = 0.0;
    }
    float _785 = precise::max(fast::clamp(_211, 0.0, 1.0), precise::max(_207, _209));
    float _788 = precise::max(0.0, (_779 * float(!_201)) - (_785 * 2.0));
    uint2 _792 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _809 = _128 - _149;
    float _810 = _809.x;
    bool _815;
    if (_810 >= 0.0)
    {
        _815 = _810 <= 1.0;
    }
    else
    {
        _815 = false;
    }
    bool _824;
    if (_815)
    {
        float _818 = _809.y;
        bool _823;
        if (_818 >= 0.0)
        {
            _823 = _818 <= 1.0;
        }
        else
        {
            _823 = false;
        }
        _824 = _823;
    }
    else
    {
        _824 = false;
    }
    float _834 = precise::min(_218, mix(_218, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_151 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _837 = _124 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _839 = int2(floor(_837));
    float2 _842 = (float2(_839) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _843 = _842 - _837;
    bool _846 = _842.x > _837.x;
    bool _850 = _842.y > _837.y;
    int2 _852 = int2(_846 ? (-2) : (-1), _850 ? (-2) : (-1));
    float2 _853 = float2(_852);
    bool _854 = _218 == 0.0;
    int _855 = _846 ? 3 : 0;
    int _856 = _850 ? 3 : 0;
    int2 _857 = int2(_855, _856);
    int2 _858 = _839 + _852;
    int2 _859 = _858 + _857;
    int _862 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _867 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _877 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _878 = _877.x;
    float3 _881 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_859.x, _862)), max(0, min(_859.y, _867))))), 0u).xyz) * ((_878 == 0.0) ? 1.0 : _878);
    float _882 = _881.x;
    float _885 = 0.5 * _881.y;
    float _887 = _881.z;
    float _888 = 0.25 * _887;
    spvUnsafeArray<float3, 9> _120;
    _120[0] = float3(((0.25 * _882) + _885) + _888, 0.5 * (_882 - _887), (((-0.25) * _882) + _885) - _888);
    int _897 = _846 ? 2 : 1;
    int2 _898 = int2(_897, _856);
    int2 _899 = _858 + _898;
    float4 _913 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _914 = _913.x;
    float3 _917 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_899.x, _862)), max(0, min(_899.y, _867))))), 0u).xyz) * ((_914 == 0.0) ? 1.0 : _914);
    float _918 = _917.x;
    float _921 = 0.5 * _917.y;
    float _923 = _917.z;
    float _924 = 0.25 * _923;
    _120[1] = float3(((0.25 * _918) + _921) + _924, 0.5 * (_918 - _923), (((-0.25) * _918) + _921) - _924);
    int _933 = _846 ? 1 : 2;
    int2 _934 = int2(_933, _856);
    int2 _935 = _858 + _934;
    float4 _949 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _950 = _949.x;
    float3 _953 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_935.x, _862)), max(0, min(_935.y, _867))))), 0u).xyz) * ((_950 == 0.0) ? 1.0 : _950);
    float _954 = _953.x;
    float _957 = 0.5 * _953.y;
    float _959 = _953.z;
    float _960 = 0.25 * _959;
    _120[2] = float3(((0.25 * _954) + _957) + _960, 0.5 * (_954 - _959), (((-0.25) * _954) + _957) - _960);
    int _969 = _850 ? 2 : 1;
    int2 _970 = int2(_855, _969);
    int2 _971 = _858 + _970;
    float4 _985 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _986 = _985.x;
    float3 _989 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_971.x, _862)), max(0, min(_971.y, _867))))), 0u).xyz) * ((_986 == 0.0) ? 1.0 : _986);
    float _990 = _989.x;
    float _993 = 0.5 * _989.y;
    float _995 = _989.z;
    float _996 = 0.25 * _995;
    _120[3] = float3(((0.25 * _990) + _993) + _996, 0.5 * (_990 - _995), (((-0.25) * _990) + _993) - _996);
    int2 _1005 = int2(_897, _969);
    int2 _1006 = _858 + _1005;
    float4 _1020 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1021 = _1020.x;
    float3 _1024 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1006.x, _862)), max(0, min(_1006.y, _867))))), 0u).xyz) * ((_1021 == 0.0) ? 1.0 : _1021);
    float _1025 = _1024.x;
    float _1028 = 0.5 * _1024.y;
    float _1030 = _1024.z;
    float _1031 = 0.25 * _1030;
    _120[4] = float3(((0.25 * _1025) + _1028) + _1031, 0.5 * (_1025 - _1030), (((-0.25) * _1025) + _1028) - _1031);
    int2 _1040 = int2(_933, _969);
    int2 _1041 = _858 + _1040;
    float4 _1055 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1056 = _1055.x;
    float3 _1059 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1041.x, _862)), max(0, min(_1041.y, _867))))), 0u).xyz) * ((_1056 == 0.0) ? 1.0 : _1056);
    float _1060 = _1059.x;
    float _1063 = 0.5 * _1059.y;
    float _1065 = _1059.z;
    float _1066 = 0.25 * _1065;
    _120[5] = float3(((0.25 * _1060) + _1063) + _1066, 0.5 * (_1060 - _1065), (((-0.25) * _1060) + _1063) - _1066);
    int _1075 = _850 ? 1 : 2;
    int2 _1076 = int2(_855, _1075);
    int2 _1077 = _858 + _1076;
    float4 _1091 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1092 = _1091.x;
    float3 _1095 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1077.x, _862)), max(0, min(_1077.y, _867))))), 0u).xyz) * ((_1092 == 0.0) ? 1.0 : _1092);
    float _1096 = _1095.x;
    float _1099 = 0.5 * _1095.y;
    float _1101 = _1095.z;
    float _1102 = 0.25 * _1101;
    _120[6] = float3(((0.25 * _1096) + _1099) + _1102, 0.5 * (_1096 - _1101), (((-0.25) * _1096) + _1099) - _1102);
    int2 _1111 = int2(_897, _1075);
    int2 _1112 = _858 + _1111;
    float4 _1126 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1127 = _1126.x;
    float3 _1130 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1112.x, _862)), max(0, min(_1112.y, _867))))), 0u).xyz) * ((_1127 == 0.0) ? 1.0 : _1127);
    float _1131 = _1130.x;
    float _1134 = 0.5 * _1130.y;
    float _1136 = _1130.z;
    float _1137 = 0.25 * _1136;
    _120[7] = float3(((0.25 * _1131) + _1134) + _1137, 0.5 * (_1131 - _1136), (((-0.25) * _1131) + _1134) - _1137);
    int2 _1146 = int2(_933, _1075);
    int2 _1147 = _858 + _1146;
    float4 _1161 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1162 = _1161.x;
    float3 _1165 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1147.x, _862)), max(0, min(_1147.y, _867))))), 0u).xyz) * ((_1162 == 0.0) ? 1.0 : _1162);
    float _1166 = _1165.x;
    float _1169 = 0.5 * _1165.y;
    float _1171 = _1165.z;
    float _1172 = 0.25 * _1171;
    _120[8] = float3(((0.25 * _1166) + _1169) + _1172, 0.5 * (_1166 - _1171), (((-0.25) * _1166) + _1169) - _1172);
    if (_854)
    {
        for (int _1184 = 0; _1184 < 9; )
        {
            float _1195 = (_120[_1184].x + _120[_1184].y) - _120[_1184].z;
            float _1196 = _120[_1184].x + _120[_1184].z;
            float _1198 = (_120[_1184].x - _120[_1184].y) - _120[_1184].z;
            float3 _1205 = float3(_1195, _1196, _1198) / float3(precise::max(precise::max(0.0, _1195), precise::max(_1196, _1198)) + 1.0);
            float _1206 = _1205.x;
            float _1209 = 0.5 * _1205.y;
            float _1211 = _1205.z;
            float _1212 = 0.25 * _1211;
            _120[_1184] = float3(((0.25 * _1206) + _1209) + _1212, 0.5 * (_1206 - _1211), (((-0.25) * _1206) + _1209) - _1212);
            _1184++;
            continue;
        }
    }
    float _1224 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1235 = mix(precise::max(1.0, (1.0 + _1224) * 0.300000011920928955078125), _1224, precise::min(1.0 - (_209 * 0.5), precise::min(1.0 - _211, fast::clamp(_834 * 5.0, 0.0, 1.0))));
    float2 _1238 = _843 + (_853 + float2(_857));
    uint2 _1240 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1243 = float(all(uint2(_859) < _1240));
    bool _1244 = !_854;
    float _1263;
    float3 _1264;
    if (_1244)
    {
        float2 _1248 = _1238 * float2(_1235);
        float _1250 = precise::min(dot(_1248, _1248), 4.0);
        float _1252 = (0.4000000059604644775390625 * _1250) - 1.0;
        float _1254 = (0.25 * _1250) - 1.0;
        float _1260 = _1243 * ((((1.5625 * _1252) * _1252) - 0.5625) * (_1254 * _1254));
        _1263 = _1260;
        _1264 = _120[0] * _1260;
    }
    else
    {
        _1263 = 0.0;
        _1264 = float3(0.0);
    }
    float _1268 = exp((-2.2999999523162841796875) * dot(_1238, _1238)) * _1243;
    float3 _1270 = _120[0] * _1268;
    float2 _1274 = _843 + (_853 + float2(_898));
    float _1278 = float(all(uint2(_899) < _1240));
    float _1299;
    float3 _1300;
    if (_1244)
    {
        float2 _1282 = _1274 * float2(_1235);
        float _1284 = precise::min(dot(_1282, _1282), 4.0);
        float _1286 = (0.4000000059604644775390625 * _1284) - 1.0;
        float _1288 = (0.25 * _1284) - 1.0;
        float _1294 = _1278 * ((((1.5625 * _1286) * _1286) - 0.5625) * (_1288 * _1288));
        _1299 = _1263 + _1294;
        _1300 = _1264 + (_120[1] * _1294);
    }
    else
    {
        _1299 = _1263;
        _1300 = _1264;
    }
    float _1304 = exp((-2.2999999523162841796875) * dot(_1274, _1274)) * _1278;
    float3 _1308 = _120[1] * _1304;
    float2 _1315 = _843 + (_853 + float2(_934));
    float _1319 = float(all(uint2(_935) < _1240));
    float _1340;
    float3 _1341;
    if (_1244)
    {
        float2 _1323 = _1315 * float2(_1235);
        float _1325 = precise::min(dot(_1323, _1323), 4.0);
        float _1327 = (0.4000000059604644775390625 * _1325) - 1.0;
        float _1329 = (0.25 * _1325) - 1.0;
        float _1335 = _1319 * ((((1.5625 * _1327) * _1327) - 0.5625) * (_1329 * _1329));
        _1340 = _1299 + _1335;
        _1341 = _1300 + (_120[2] * _1335);
    }
    else
    {
        _1340 = _1299;
        _1341 = _1300;
    }
    float _1345 = exp((-2.2999999523162841796875) * dot(_1315, _1315)) * _1319;
    float3 _1349 = _120[2] * _1345;
    float2 _1356 = _843 + (_853 + float2(_970));
    float _1360 = float(all(uint2(_971) < _1240));
    float _1381;
    float3 _1382;
    if (_1244)
    {
        float2 _1364 = _1356 * float2(_1235);
        float _1366 = precise::min(dot(_1364, _1364), 4.0);
        float _1368 = (0.4000000059604644775390625 * _1366) - 1.0;
        float _1370 = (0.25 * _1366) - 1.0;
        float _1376 = _1360 * ((((1.5625 * _1368) * _1368) - 0.5625) * (_1370 * _1370));
        _1381 = _1340 + _1376;
        _1382 = _1341 + (_120[3] * _1376);
    }
    else
    {
        _1381 = _1340;
        _1382 = _1341;
    }
    float _1386 = exp((-2.2999999523162841796875) * dot(_1356, _1356)) * _1360;
    float3 _1390 = _120[3] * _1386;
    float2 _1397 = _843 + (_853 + float2(_1005));
    float _1401 = float(all(uint2(_1006) < _1240));
    float _1422;
    float3 _1423;
    if (_1244)
    {
        float2 _1405 = _1397 * float2(_1235);
        float _1407 = precise::min(dot(_1405, _1405), 4.0);
        float _1409 = (0.4000000059604644775390625 * _1407) - 1.0;
        float _1411 = (0.25 * _1407) - 1.0;
        float _1417 = _1401 * ((((1.5625 * _1409) * _1409) - 0.5625) * (_1411 * _1411));
        _1422 = _1381 + _1417;
        _1423 = _1382 + (_120[4] * _1417);
    }
    else
    {
        _1422 = _1381;
        _1423 = _1382;
    }
    float _1427 = exp((-2.2999999523162841796875) * dot(_1397, _1397)) * _1401;
    float3 _1431 = _120[4] * _1427;
    float2 _1438 = _843 + (_853 + float2(_1040));
    float _1442 = float(all(uint2(_1041) < _1240));
    float _1463;
    float3 _1464;
    if (_1244)
    {
        float2 _1446 = _1438 * float2(_1235);
        float _1448 = precise::min(dot(_1446, _1446), 4.0);
        float _1450 = (0.4000000059604644775390625 * _1448) - 1.0;
        float _1452 = (0.25 * _1448) - 1.0;
        float _1458 = _1442 * ((((1.5625 * _1450) * _1450) - 0.5625) * (_1452 * _1452));
        _1463 = _1422 + _1458;
        _1464 = _1423 + (_120[5] * _1458);
    }
    else
    {
        _1463 = _1422;
        _1464 = _1423;
    }
    float _1468 = exp((-2.2999999523162841796875) * dot(_1438, _1438)) * _1442;
    float3 _1472 = _120[5] * _1468;
    float2 _1479 = _843 + (_853 + float2(_1076));
    float _1483 = float(all(uint2(_1077) < _1240));
    float _1504;
    float3 _1505;
    if (_1244)
    {
        float2 _1487 = _1479 * float2(_1235);
        float _1489 = precise::min(dot(_1487, _1487), 4.0);
        float _1491 = (0.4000000059604644775390625 * _1489) - 1.0;
        float _1493 = (0.25 * _1489) - 1.0;
        float _1499 = _1483 * ((((1.5625 * _1491) * _1491) - 0.5625) * (_1493 * _1493));
        _1504 = _1463 + _1499;
        _1505 = _1464 + (_120[6] * _1499);
    }
    else
    {
        _1504 = _1463;
        _1505 = _1464;
    }
    float _1509 = exp((-2.2999999523162841796875) * dot(_1479, _1479)) * _1483;
    float3 _1513 = _120[6] * _1509;
    float2 _1520 = _843 + (_853 + float2(_1111));
    float _1524 = float(all(uint2(_1112) < _1240));
    float _1545;
    float3 _1546;
    if (_1244)
    {
        float2 _1528 = _1520 * float2(_1235);
        float _1530 = precise::min(dot(_1528, _1528), 4.0);
        float _1532 = (0.4000000059604644775390625 * _1530) - 1.0;
        float _1534 = (0.25 * _1530) - 1.0;
        float _1540 = _1524 * ((((1.5625 * _1532) * _1532) - 0.5625) * (_1534 * _1534));
        _1545 = _1504 + _1540;
        _1546 = _1505 + (_120[7] * _1540);
    }
    else
    {
        _1545 = _1504;
        _1546 = _1505;
    }
    float _1550 = exp((-2.2999999523162841796875) * dot(_1520, _1520)) * _1524;
    float3 _1554 = _120[7] * _1550;
    float2 _1561 = _843 + (_853 + float2(_1146));
    float _1565 = float(all(uint2(_1147) < _1240));
    float _1586;
    float3 _1587;
    if (_1244)
    {
        float2 _1569 = _1561 * float2(_1235);
        float _1571 = precise::min(dot(_1569, _1569), 4.0);
        float _1573 = (0.4000000059604644775390625 * _1571) - 1.0;
        float _1575 = (0.25 * _1571) - 1.0;
        float _1581 = _1565 * ((((1.5625 * _1573) * _1573) - 0.5625) * (_1575 * _1575));
        _1586 = _1545 + _1581;
        _1587 = _1546 + (_120[8] * _1581);
    }
    else
    {
        _1586 = _1545;
        _1587 = _1546;
    }
    float _1591 = exp((-2.2999999523162841796875) * dot(_1561, _1561)) * _1565;
    float3 _1595 = _120[8] * _1591;
    float _1599 = (((((((_1268 + _1304) + _1345) + _1386) + _1427) + _1468) + _1509) + _1550) + _1591;
    float3 _1603 = float3((abs(_1599) > 1.1754943508222875079687365372222e-38) ? _1599 : 1.0);
    float3 _1604 = ((((((((_1270 + _1308) + _1349) + _1390) + _1431) + _1472) + _1513) + _1554) + _1595) / _1603;
    float _1612 = _1586 * float(_1586 > 6.099999882280826568603515625e-05);
    float3 _1620;
    float _1621;
    if (_1612 > 6.099999882280826568603515625e-05)
    {
        _1620 = fast::clamp(_1587 / float3(_1612), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_120[0], _120[1]), _120[2]), _120[3]), _120[4]), _120[5]), _120[6]), _120[7]), _120[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_120[0], _120[1]), _120[2]), _120[3]), _120[4]), _120[5]), _120[6]), _120[7]), _120[8]));
        _1621 = _1612 * 0.04625000059604644775390625;
    }
    else
    {
        _1620 = _1587;
        _1621 = _1612;
    }
    float3 _1653;
    if (_854)
    {
        float _1624 = _1604.x;
        float _1625 = _1604.y;
        float _1627 = _1604.z;
        float _1628 = (_1624 + _1625) - _1627;
        float _1629 = _1624 + _1627;
        float _1631 = (_1624 - _1625) - _1627;
        float3 _1638 = float3(_1628, _1629, _1631) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1628, precise::max(_1629, _1631))));
        float _1639 = _1638.x;
        float _1642 = 0.5 * _1638.y;
        float _1644 = _1638.z;
        float _1645 = 0.25 * _1644;
        _1653 = float3(((0.25 * _1639) + _1642) + _1645, 0.5 * (_1639 - _1644), (((-0.25) * _1639) + _1642) - _1645);
    }
    else
    {
        _1653 = _1620;
    }
    float _1654 = _854 ? 1.0 : _1621;
    float _1655 = _854 ? 0.0 : _834;
    float3 _1669 = (sqrt(abs(((((((((((_120[0] * _1270) + (_120[1] * _1308)) + (_120[2] * _1349)) + (_120[3] * _1390)) + (_120[4] * _1431)) + (_120[5] * _1472)) + (_120[6] * _1513)) + (_120[7] * _1554)) + (_120[8] * _1595)) / _1603) - (_1604 * _1604))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_151 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _184, _184 - float2(0.5))) / float2(int2(int(_178.x), int(_178.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _218, precise::max(powr(_207, 0.5), _211)))));
    float3 _1672 = (_778 - _1604) / precise::max(_1669, float3(1.19299997436428384389728307724e-07));
    float3 _1687;
    if (length(_1672) > 1.0)
    {
        _1687 = mix((fast::normalize(_1672) * _1669) + _1604, _778, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_144, _139)) / _142), level(0.0)).x, fast::clamp(fast::clamp(_788 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _218) * (1.0 - _209), 0.0, 1.0)));
    }
    else
    {
        _1687 = _778;
    }
    float _1697 = (_1653.x + _1653.y) - _1653.z;
    float _1698 = _1653.x + _1653.z;
    float _1700 = (_1653.x - _1653.y) - _1653.z;
    float3 _1707 = float3(_1697, _1698, _1700) / float3(precise::max(precise::max(0.0, _1697), precise::max(_1698, _1700)) + 1.0);
    float _1708 = _1707.x;
    float _1711 = 0.5 * _1707.y;
    float _1713 = _1707.z;
    float _1714 = 0.25 * _1713;
    float _1726 = (_1687.x + _1687.y) - _1687.z;
    float _1727 = _1687.x + _1687.z;
    float _1729 = (_1687.x - _1687.y) - _1687.z;
    float3 _1736 = float3(_1726, _1727, _1729) / float3(precise::max(precise::max(0.0, _1726), precise::max(_1727, _1729)) + 1.0);
    float _1737 = _1736.x;
    float _1740 = 0.5 * _1736.y;
    float _1742 = _1736.z;
    float _1743 = 0.25 * _1742;
    float3 _1754 = mix(float3(((0.25 * _1737) + _1740) + _1743, 0.5 * (_1737 - _1742), (((-0.25) * _1737) + _1740) - _1743), float3(((0.25 * _1708) + _1711) + _1714, 0.5 * (_1708 - _1713), (((-0.25) * _1708) + _1711) - _1714), float3(fast::clamp(_1654 / precise::max(6.099999882280826568603515625e-05, (_1655 * float(_1655 > 6.099999882280826568603515625e-05)) + _1654), 0.0, 1.0)));
    float _1759 = (_1754.x + _1754.y) - _1754.z;
    float _1760 = _1754.x + _1754.z;
    float _1762 = (_1754.x - _1754.y) - _1754.z;
    float4 _1771 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1772 = _1771.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max((float3(_1759, _1760, _1762) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1759, precise::max(_1760, _1762))))) / float3((_1772 == 0.0) ? 1.0 : _1772), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_788 + (sdk_hlsl_load(rw_new_locks, uint2(_792)).x * (1.0 - precise::max(0.0, _207))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _785))) * float(_824)), uint2(_792));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_792));
}

