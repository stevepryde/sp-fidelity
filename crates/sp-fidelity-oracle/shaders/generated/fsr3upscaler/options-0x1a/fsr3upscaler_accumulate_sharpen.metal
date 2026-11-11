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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(3)]], texture2d<float, access::write> rw_upscaled_output [[texture(4)]], texture2d<float> r_farthest_depth_mip1 [[texture(5)]], texture2d<float> r_luma_instability [[texture(6)]], texture2d<float, access::read_write> rw_new_locks [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _128 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _132 = _128 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _137 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _139 = _132 + (cbFSR3Upscaler.fJitter / _137);
    float2 _143 = _137 - float2(0.5);
    float2 _146 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _148 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _157 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_148), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _159 = length(_157 * float2(3840.0, 2160.0));
    float2 _160 = _132 + _157;
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
    uint2 _187 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _193 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _210;
    if (_175)
    {
        _210 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _210 = true;
    }
    float4 _214 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_139 * _137, _143)) / _146), level(0.0));
    float _216 = fast::clamp(_214.x, 0.0, 1.0);
    float _218 = fast::clamp(_214.y, 0.0, 1.0);
    float _220 = fast::clamp(_214.z, 0.0, 1.0);
    float _222 = fast::clamp(_214.w, 0.0, 1.0);
    float _227 = _222 * float(rint(_222 * 100.0) > 1.0);
    bool _231;
    if (_175)
    {
        _231 = !_210;
    }
    else
    {
        _231 = false;
    }
    float3 _787;
    float _788;
    if (_231)
    {
        float2 _238 = (_160 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _240 = _238 - floor(_238);
        int2 _255 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _238.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _238.y)))));
        int2 _256 = _255 + int2(-1);
        int _258 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _262 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _269 = _255 + int2(0, -1);
        int2 _280 = _255 + int2(1, -1);
        int2 _291 = _255 + int2(2, -1);
        int2 _302 = _255 + int2(-1, 0);
        float4 _322 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_255.x, _258)), max(1, min(_255.y, _262))))), 0u);
        int2 _323 = _255 + int2(1, 0);
        float4 _333 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_323.x, _258)), max(1, min(_323.y, _262))))), 0u);
        int2 _334 = _255 + int2(2, 0);
        int2 _345 = _255 + int2(-1, 1);
        int2 _356 = _255 + int2(0, 1);
        float4 _366 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_356.x, _258)), max(1, min(_356.y, _262))))), 0u);
        int2 _367 = _255 + int2(1);
        float4 _377 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_367.x, _258)), max(1, min(_367.y, _262))))), 0u);
        int2 _378 = _255 + int2(2, 1);
        int2 _389 = _255 + int2(-1, 2);
        int2 _400 = _255 + int2(0, 2);
        int2 _411 = _255 + int2(1, 2);
        int2 _422 = _255 + int2(2);
        float _433 = _240.x;
        float _436 = precise::min(abs((-1.0) - _433), 2.0);
        bool _438 = abs(_436) < 6.099999882280826568603515625e-05;
        float _449;
        if (_438)
        {
            _449 = 1.0;
        }
        else
        {
            float _442 = 3.1415927410125732421875 * _436;
            float _445 = 1.57079637050628662109375 * _436;
            _449 = (sin(_442) / _442) * (sin(_445) / _445);
        }
        float _452 = precise::min(abs(-_433), 2.0);
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
        float _468 = precise::min(abs(1.0 - _433), 2.0);
        bool _470 = abs(_468) < 6.099999882280826568603515625e-05;
        float _481;
        if (_470)
        {
            _481 = 1.0;
        }
        else
        {
            float _474 = 3.1415927410125732421875 * _468;
            float _477 = 1.57079637050628662109375 * _468;
            _481 = (sin(_474) / _474) * (sin(_477) / _477);
        }
        float _484 = precise::min(abs(2.0 - _433), 2.0);
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
        float _520;
        if (_438)
        {
            _520 = 1.0;
        }
        else
        {
            float _513 = 3.1415927410125732421875 * _436;
            float _516 = 1.57079637050628662109375 * _436;
            _520 = (sin(_513) / _513) * (sin(_516) / _516);
        }
        float _531;
        if (_454)
        {
            _531 = 1.0;
        }
        else
        {
            float _524 = 3.1415927410125732421875 * _452;
            float _527 = 1.57079637050628662109375 * _452;
            _531 = (sin(_524) / _524) * (sin(_527) / _527);
        }
        float _542;
        if (_470)
        {
            _542 = 1.0;
        }
        else
        {
            float _535 = 3.1415927410125732421875 * _468;
            float _538 = 1.57079637050628662109375 * _468;
            _542 = (sin(_535) / _535) * (sin(_538) / _538);
        }
        float _553;
        if (_486)
        {
            _553 = 1.0;
        }
        else
        {
            float _546 = 3.1415927410125732421875 * _484;
            float _549 = 1.57079637050628662109375 * _484;
            _553 = (sin(_546) / _546) * (sin(_549) / _549);
        }
        float _576;
        if (_438)
        {
            _576 = 1.0;
        }
        else
        {
            float _569 = 3.1415927410125732421875 * _436;
            float _572 = 1.57079637050628662109375 * _436;
            _576 = (sin(_569) / _569) * (sin(_572) / _572);
        }
        float _587;
        if (_454)
        {
            _587 = 1.0;
        }
        else
        {
            float _580 = 3.1415927410125732421875 * _452;
            float _583 = 1.57079637050628662109375 * _452;
            _587 = (sin(_580) / _580) * (sin(_583) / _583);
        }
        float _598;
        if (_470)
        {
            _598 = 1.0;
        }
        else
        {
            float _591 = 3.1415927410125732421875 * _468;
            float _594 = 1.57079637050628662109375 * _468;
            _598 = (sin(_591) / _591) * (sin(_594) / _594);
        }
        float _609;
        if (_486)
        {
            _609 = 1.0;
        }
        else
        {
            float _602 = 3.1415927410125732421875 * _484;
            float _605 = 1.57079637050628662109375 * _484;
            _609 = (sin(_602) / _602) * (sin(_605) / _605);
        }
        float _632;
        if (_438)
        {
            _632 = 1.0;
        }
        else
        {
            float _625 = 3.1415927410125732421875 * _436;
            float _628 = 1.57079637050628662109375 * _436;
            _632 = (sin(_625) / _625) * (sin(_628) / _628);
        }
        float _643;
        if (_454)
        {
            _643 = 1.0;
        }
        else
        {
            float _636 = 3.1415927410125732421875 * _452;
            float _639 = 1.57079637050628662109375 * _452;
            _643 = (sin(_636) / _636) * (sin(_639) / _639);
        }
        float _654;
        if (_470)
        {
            _654 = 1.0;
        }
        else
        {
            float _647 = 3.1415927410125732421875 * _468;
            float _650 = 1.57079637050628662109375 * _468;
            _654 = (sin(_647) / _647) * (sin(_650) / _650);
        }
        float _665;
        if (_486)
        {
            _665 = 1.0;
        }
        else
        {
            float _658 = 3.1415927410125732421875 * _484;
            float _661 = 1.57079637050628662109375 * _484;
            _665 = (sin(_658) / _658) * (sin(_661) / _661);
        }
        float _678 = _240.y;
        float _681 = precise::min(abs((-1.0) - _678), 2.0);
        float _694;
        if (abs(_681) < 6.099999882280826568603515625e-05)
        {
            _694 = 1.0;
        }
        else
        {
            float _687 = 3.1415927410125732421875 * _681;
            float _690 = 1.57079637050628662109375 * _681;
            _694 = (sin(_687) / _687) * (sin(_690) / _690);
        }
        float _697 = precise::min(abs(-_678), 2.0);
        float _710;
        if (abs(_697) < 6.099999882280826568603515625e-05)
        {
            _710 = 1.0;
        }
        else
        {
            float _703 = 3.1415927410125732421875 * _697;
            float _706 = 1.57079637050628662109375 * _697;
            _710 = (sin(_703) / _703) * (sin(_706) / _706);
        }
        float _713 = precise::min(abs(1.0 - _678), 2.0);
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
        float _729 = precise::min(abs(2.0 - _678), 2.0);
        float _742;
        if (abs(_729) < 6.099999882280826568603515625e-05)
        {
            _742 = 1.0;
        }
        else
        {
            float _735 = 3.1415927410125732421875 * _729;
            float _738 = 1.57079637050628662109375 * _729;
            _742 = (sin(_735) / _735) * (sin(_738) / _738);
        }
        float4 _747 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_256.x, _258)), max(1, min(_256.y, _262))))), 0u) * _449) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_269.x, _258)), max(1, min(_269.y, _262))))), 0u) * _465)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_280.x, _258)), max(1, min(_280.y, _262))))), 0u) * _481)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_291.x, _258)), max(1, min(_291.y, _262))))), 0u) * _497)) / float4(((_449 + _465) + _481) + _497)) * _694) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_302.x, _258)), max(1, min(_302.y, _262))))), 0u) * _520) + (_322 * _531)) + (_333 * _542)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_334.x, _258)), max(1, min(_334.y, _262))))), 0u) * _553)) / float4(((_520 + _531) + _542) + _553)) * _710)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_345.x, _258)), max(1, min(_345.y, _262))))), 0u) * _576) + (_366 * _587)) + (_377 * _598)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_378.x, _258)), max(1, min(_378.y, _262))))), 0u) * _609)) / float4(((_576 + _587) + _598) + _609)) * _726);
        float4 _761 = fast::clamp((_747 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_389.x, _258)), max(1, min(_389.y, _262))))), 0u) * _632) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_400.x, _258)), max(1, min(_400.y, _262))))), 0u) * _643)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_411.x, _258)), max(1, min(_411.y, _262))))), 0u) * _654)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_422.x, _258)), max(1, min(_422.y, _262))))), 0u) * _665)) / float4(((_632 + _643) + _654) + _665)) * _742)) / float4(((_694 + _710) + _726) + _742), precise::min(precise::min(precise::min(_322, _333), _366), _377), precise::max(precise::max(precise::max(_322, _333), _366), _377));
        float4 _767 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _768 = _767.x;
        float3 _771 = (_761.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_768 == 0.0) ? 1.0 : _768);
        float _772 = _771.x;
        float _775 = 0.5 * _771.y;
        float _777 = _771.z;
        float _778 = 0.25 * _777;
        _787 = float3(((0.25 * _772) + _775) + _778, 0.5 * (_772 - _777), (((-0.25) * _772) + _775) - _778);
        _788 = _761.w;
    }
    else
    {
        _787 = float3(0.0);
        _788 = 0.0;
    }
    float _794 = precise::max(fast::clamp(_220, 0.0, 1.0), precise::max(_216, _218));
    float _797 = precise::max(0.0, (_788 * float(!_210)) - (_794 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _817 = _132 - _157;
    float _818 = _817.x;
    bool _823;
    if (_818 >= 0.0)
    {
        _823 = _818 <= 1.0;
    }
    else
    {
        _823 = false;
    }
    bool _832;
    if (_823)
    {
        float _826 = _817.y;
        bool _831;
        if (_826 >= 0.0)
        {
            _831 = _826 <= 1.0;
        }
        else
        {
            _831 = false;
        }
        _832 = _831;
    }
    else
    {
        _832 = false;
    }
    float _842 = precise::min(_227, mix(_227, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_159 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _845 = _128 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _847 = int2(floor(_845));
    float2 _850 = (float2(_847) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _851 = _850 - _845;
    bool _854 = _850.x > _845.x;
    bool _858 = _850.y > _845.y;
    int2 _860 = int2(_854 ? (-2) : (-1), _858 ? (-2) : (-1));
    float2 _861 = float2(_860);
    bool _862 = _227 == 0.0;
    int _863 = _854 ? 3 : 0;
    int _864 = _858 ? 3 : 0;
    int2 _865 = int2(_863, _864);
    int2 _866 = _847 + _860;
    int2 _867 = _866 + _865;
    int _870 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _875 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _885 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _886 = _885.x;
    float3 _889 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_867.x, _870)), max(0, min(_867.y, _875))))), 0u).xyz) * ((_886 == 0.0) ? 1.0 : _886);
    float _890 = _889.x;
    float _893 = 0.5 * _889.y;
    float _895 = _889.z;
    float _896 = 0.25 * _895;
    spvUnsafeArray<float3, 9> _124;
    _124[0] = float3(((0.25 * _890) + _893) + _896, 0.5 * (_890 - _895), (((-0.25) * _890) + _893) - _896);
    int _905 = _854 ? 2 : 1;
    int2 _906 = int2(_905, _864);
    int2 _907 = _866 + _906;
    float4 _921 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _922 = _921.x;
    float3 _925 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_907.x, _870)), max(0, min(_907.y, _875))))), 0u).xyz) * ((_922 == 0.0) ? 1.0 : _922);
    float _926 = _925.x;
    float _929 = 0.5 * _925.y;
    float _931 = _925.z;
    float _932 = 0.25 * _931;
    _124[1] = float3(((0.25 * _926) + _929) + _932, 0.5 * (_926 - _931), (((-0.25) * _926) + _929) - _932);
    int _941 = _854 ? 1 : 2;
    int2 _942 = int2(_941, _864);
    int2 _943 = _866 + _942;
    float4 _957 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _958 = _957.x;
    float3 _961 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_943.x, _870)), max(0, min(_943.y, _875))))), 0u).xyz) * ((_958 == 0.0) ? 1.0 : _958);
    float _962 = _961.x;
    float _965 = 0.5 * _961.y;
    float _967 = _961.z;
    float _968 = 0.25 * _967;
    _124[2] = float3(((0.25 * _962) + _965) + _968, 0.5 * (_962 - _967), (((-0.25) * _962) + _965) - _968);
    int _977 = _858 ? 2 : 1;
    int2 _978 = int2(_863, _977);
    int2 _979 = _866 + _978;
    float4 _993 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _994 = _993.x;
    float3 _997 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_979.x, _870)), max(0, min(_979.y, _875))))), 0u).xyz) * ((_994 == 0.0) ? 1.0 : _994);
    float _998 = _997.x;
    float _1001 = 0.5 * _997.y;
    float _1003 = _997.z;
    float _1004 = 0.25 * _1003;
    _124[3] = float3(((0.25 * _998) + _1001) + _1004, 0.5 * (_998 - _1003), (((-0.25) * _998) + _1001) - _1004);
    int2 _1013 = int2(_905, _977);
    int2 _1014 = _866 + _1013;
    float4 _1028 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1029 = _1028.x;
    float3 _1032 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1014.x, _870)), max(0, min(_1014.y, _875))))), 0u).xyz) * ((_1029 == 0.0) ? 1.0 : _1029);
    float _1033 = _1032.x;
    float _1036 = 0.5 * _1032.y;
    float _1038 = _1032.z;
    float _1039 = 0.25 * _1038;
    _124[4] = float3(((0.25 * _1033) + _1036) + _1039, 0.5 * (_1033 - _1038), (((-0.25) * _1033) + _1036) - _1039);
    int2 _1048 = int2(_941, _977);
    int2 _1049 = _866 + _1048;
    float4 _1063 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1064 = _1063.x;
    float3 _1067 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1049.x, _870)), max(0, min(_1049.y, _875))))), 0u).xyz) * ((_1064 == 0.0) ? 1.0 : _1064);
    float _1068 = _1067.x;
    float _1071 = 0.5 * _1067.y;
    float _1073 = _1067.z;
    float _1074 = 0.25 * _1073;
    _124[5] = float3(((0.25 * _1068) + _1071) + _1074, 0.5 * (_1068 - _1073), (((-0.25) * _1068) + _1071) - _1074);
    int _1083 = _858 ? 1 : 2;
    int2 _1084 = int2(_863, _1083);
    int2 _1085 = _866 + _1084;
    float4 _1099 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1100 = _1099.x;
    float3 _1103 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1085.x, _870)), max(0, min(_1085.y, _875))))), 0u).xyz) * ((_1100 == 0.0) ? 1.0 : _1100);
    float _1104 = _1103.x;
    float _1107 = 0.5 * _1103.y;
    float _1109 = _1103.z;
    float _1110 = 0.25 * _1109;
    _124[6] = float3(((0.25 * _1104) + _1107) + _1110, 0.5 * (_1104 - _1109), (((-0.25) * _1104) + _1107) - _1110);
    int2 _1119 = int2(_905, _1083);
    int2 _1120 = _866 + _1119;
    float4 _1134 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1135 = _1134.x;
    float3 _1138 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1120.x, _870)), max(0, min(_1120.y, _875))))), 0u).xyz) * ((_1135 == 0.0) ? 1.0 : _1135);
    float _1139 = _1138.x;
    float _1142 = 0.5 * _1138.y;
    float _1144 = _1138.z;
    float _1145 = 0.25 * _1144;
    _124[7] = float3(((0.25 * _1139) + _1142) + _1145, 0.5 * (_1139 - _1144), (((-0.25) * _1139) + _1142) - _1145);
    int2 _1154 = int2(_941, _1083);
    int2 _1155 = _866 + _1154;
    float4 _1169 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1170 = _1169.x;
    float3 _1173 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1155.x, _870)), max(0, min(_1155.y, _875))))), 0u).xyz) * ((_1170 == 0.0) ? 1.0 : _1170);
    float _1174 = _1173.x;
    float _1177 = 0.5 * _1173.y;
    float _1179 = _1173.z;
    float _1180 = 0.25 * _1179;
    _124[8] = float3(((0.25 * _1174) + _1177) + _1180, 0.5 * (_1174 - _1179), (((-0.25) * _1174) + _1177) - _1180);
    if (_862)
    {
        for (int _1192 = 0; _1192 < 9; )
        {
            float _1203 = (_124[_1192].x + _124[_1192].y) - _124[_1192].z;
            float _1204 = _124[_1192].x + _124[_1192].z;
            float _1206 = (_124[_1192].x - _124[_1192].y) - _124[_1192].z;
            float3 _1213 = float3(_1203, _1204, _1206) / float3(precise::max(precise::max(0.0, _1203), precise::max(_1204, _1206)) + 1.0);
            float _1214 = _1213.x;
            float _1217 = 0.5 * _1213.y;
            float _1219 = _1213.z;
            float _1220 = 0.25 * _1219;
            _124[_1192] = float3(((0.25 * _1214) + _1217) + _1220, 0.5 * (_1214 - _1219), (((-0.25) * _1214) + _1217) - _1220);
            _1192++;
            continue;
        }
    }
    float _1232 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1243 = mix(precise::max(1.0, (1.0 + _1232) * 0.300000011920928955078125), _1232, precise::min(1.0 - (_218 * 0.5), precise::min(1.0 - _220, fast::clamp(_842 * 5.0, 0.0, 1.0))));
    float2 _1246 = _851 + (_861 + float2(_865));
    uint2 _1248 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1251 = float(all(uint2(_867) < _1248));
    bool _1252 = !_862;
    float _1271;
    float3 _1272;
    if (_1252)
    {
        float2 _1256 = _1246 * float2(_1243);
        float _1258 = precise::min(dot(_1256, _1256), 4.0);
        float _1260 = (0.4000000059604644775390625 * _1258) - 1.0;
        float _1262 = (0.25 * _1258) - 1.0;
        float _1268 = _1251 * ((((1.5625 * _1260) * _1260) - 0.5625) * (_1262 * _1262));
        _1271 = _1268;
        _1272 = _124[0] * _1268;
    }
    else
    {
        _1271 = 0.0;
        _1272 = float3(0.0);
    }
    float _1276 = exp((-2.2999999523162841796875) * dot(_1246, _1246)) * _1251;
    float3 _1278 = _124[0] * _1276;
    float2 _1282 = _851 + (_861 + float2(_906));
    float _1286 = float(all(uint2(_907) < _1248));
    float _1307;
    float3 _1308;
    if (_1252)
    {
        float2 _1290 = _1282 * float2(_1243);
        float _1292 = precise::min(dot(_1290, _1290), 4.0);
        float _1294 = (0.4000000059604644775390625 * _1292) - 1.0;
        float _1296 = (0.25 * _1292) - 1.0;
        float _1302 = _1286 * ((((1.5625 * _1294) * _1294) - 0.5625) * (_1296 * _1296));
        _1307 = _1271 + _1302;
        _1308 = _1272 + (_124[1] * _1302);
    }
    else
    {
        _1307 = _1271;
        _1308 = _1272;
    }
    float _1312 = exp((-2.2999999523162841796875) * dot(_1282, _1282)) * _1286;
    float3 _1316 = _124[1] * _1312;
    float2 _1323 = _851 + (_861 + float2(_942));
    float _1327 = float(all(uint2(_943) < _1248));
    float _1348;
    float3 _1349;
    if (_1252)
    {
        float2 _1331 = _1323 * float2(_1243);
        float _1333 = precise::min(dot(_1331, _1331), 4.0);
        float _1335 = (0.4000000059604644775390625 * _1333) - 1.0;
        float _1337 = (0.25 * _1333) - 1.0;
        float _1343 = _1327 * ((((1.5625 * _1335) * _1335) - 0.5625) * (_1337 * _1337));
        _1348 = _1307 + _1343;
        _1349 = _1308 + (_124[2] * _1343);
    }
    else
    {
        _1348 = _1307;
        _1349 = _1308;
    }
    float _1353 = exp((-2.2999999523162841796875) * dot(_1323, _1323)) * _1327;
    float3 _1357 = _124[2] * _1353;
    float2 _1364 = _851 + (_861 + float2(_978));
    float _1368 = float(all(uint2(_979) < _1248));
    float _1389;
    float3 _1390;
    if (_1252)
    {
        float2 _1372 = _1364 * float2(_1243);
        float _1374 = precise::min(dot(_1372, _1372), 4.0);
        float _1376 = (0.4000000059604644775390625 * _1374) - 1.0;
        float _1378 = (0.25 * _1374) - 1.0;
        float _1384 = _1368 * ((((1.5625 * _1376) * _1376) - 0.5625) * (_1378 * _1378));
        _1389 = _1348 + _1384;
        _1390 = _1349 + (_124[3] * _1384);
    }
    else
    {
        _1389 = _1348;
        _1390 = _1349;
    }
    float _1394 = exp((-2.2999999523162841796875) * dot(_1364, _1364)) * _1368;
    float3 _1398 = _124[3] * _1394;
    float2 _1405 = _851 + (_861 + float2(_1013));
    float _1409 = float(all(uint2(_1014) < _1248));
    float _1430;
    float3 _1431;
    if (_1252)
    {
        float2 _1413 = _1405 * float2(_1243);
        float _1415 = precise::min(dot(_1413, _1413), 4.0);
        float _1417 = (0.4000000059604644775390625 * _1415) - 1.0;
        float _1419 = (0.25 * _1415) - 1.0;
        float _1425 = _1409 * ((((1.5625 * _1417) * _1417) - 0.5625) * (_1419 * _1419));
        _1430 = _1389 + _1425;
        _1431 = _1390 + (_124[4] * _1425);
    }
    else
    {
        _1430 = _1389;
        _1431 = _1390;
    }
    float _1435 = exp((-2.2999999523162841796875) * dot(_1405, _1405)) * _1409;
    float3 _1439 = _124[4] * _1435;
    float2 _1446 = _851 + (_861 + float2(_1048));
    float _1450 = float(all(uint2(_1049) < _1248));
    float _1471;
    float3 _1472;
    if (_1252)
    {
        float2 _1454 = _1446 * float2(_1243);
        float _1456 = precise::min(dot(_1454, _1454), 4.0);
        float _1458 = (0.4000000059604644775390625 * _1456) - 1.0;
        float _1460 = (0.25 * _1456) - 1.0;
        float _1466 = _1450 * ((((1.5625 * _1458) * _1458) - 0.5625) * (_1460 * _1460));
        _1471 = _1430 + _1466;
        _1472 = _1431 + (_124[5] * _1466);
    }
    else
    {
        _1471 = _1430;
        _1472 = _1431;
    }
    float _1476 = exp((-2.2999999523162841796875) * dot(_1446, _1446)) * _1450;
    float3 _1480 = _124[5] * _1476;
    float2 _1487 = _851 + (_861 + float2(_1084));
    float _1491 = float(all(uint2(_1085) < _1248));
    float _1512;
    float3 _1513;
    if (_1252)
    {
        float2 _1495 = _1487 * float2(_1243);
        float _1497 = precise::min(dot(_1495, _1495), 4.0);
        float _1499 = (0.4000000059604644775390625 * _1497) - 1.0;
        float _1501 = (0.25 * _1497) - 1.0;
        float _1507 = _1491 * ((((1.5625 * _1499) * _1499) - 0.5625) * (_1501 * _1501));
        _1512 = _1471 + _1507;
        _1513 = _1472 + (_124[6] * _1507);
    }
    else
    {
        _1512 = _1471;
        _1513 = _1472;
    }
    float _1517 = exp((-2.2999999523162841796875) * dot(_1487, _1487)) * _1491;
    float3 _1521 = _124[6] * _1517;
    float2 _1528 = _851 + (_861 + float2(_1119));
    float _1532 = float(all(uint2(_1120) < _1248));
    float _1553;
    float3 _1554;
    if (_1252)
    {
        float2 _1536 = _1528 * float2(_1243);
        float _1538 = precise::min(dot(_1536, _1536), 4.0);
        float _1540 = (0.4000000059604644775390625 * _1538) - 1.0;
        float _1542 = (0.25 * _1538) - 1.0;
        float _1548 = _1532 * ((((1.5625 * _1540) * _1540) - 0.5625) * (_1542 * _1542));
        _1553 = _1512 + _1548;
        _1554 = _1513 + (_124[7] * _1548);
    }
    else
    {
        _1553 = _1512;
        _1554 = _1513;
    }
    float _1558 = exp((-2.2999999523162841796875) * dot(_1528, _1528)) * _1532;
    float3 _1562 = _124[7] * _1558;
    float2 _1569 = _851 + (_861 + float2(_1154));
    float _1573 = float(all(uint2(_1155) < _1248));
    float _1594;
    float3 _1595;
    if (_1252)
    {
        float2 _1577 = _1569 * float2(_1243);
        float _1579 = precise::min(dot(_1577, _1577), 4.0);
        float _1581 = (0.4000000059604644775390625 * _1579) - 1.0;
        float _1583 = (0.25 * _1579) - 1.0;
        float _1589 = _1573 * ((((1.5625 * _1581) * _1581) - 0.5625) * (_1583 * _1583));
        _1594 = _1553 + _1589;
        _1595 = _1554 + (_124[8] * _1589);
    }
    else
    {
        _1594 = _1553;
        _1595 = _1554;
    }
    float _1599 = exp((-2.2999999523162841796875) * dot(_1569, _1569)) * _1573;
    float3 _1603 = _124[8] * _1599;
    float _1607 = (((((((_1276 + _1312) + _1353) + _1394) + _1435) + _1476) + _1517) + _1558) + _1599;
    float3 _1611 = float3((abs(_1607) > 1.1754943508222875079687365372222e-38) ? _1607 : 1.0);
    float3 _1612 = ((((((((_1278 + _1316) + _1357) + _1398) + _1439) + _1480) + _1521) + _1562) + _1603) / _1611;
    float _1620 = _1594 * float(_1594 > 6.099999882280826568603515625e-05);
    float3 _1628;
    float _1629;
    if (_1620 > 6.099999882280826568603515625e-05)
    {
        _1628 = fast::clamp(_1595 / float3(_1620), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_124[0], _124[1]), _124[2]), _124[3]), _124[4]), _124[5]), _124[6]), _124[7]), _124[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_124[0], _124[1]), _124[2]), _124[3]), _124[4]), _124[5]), _124[6]), _124[7]), _124[8]));
        _1629 = _1620 * 0.04625000059604644775390625;
    }
    else
    {
        _1628 = _1595;
        _1629 = _1620;
    }
    float3 _1661;
    if (_862)
    {
        float _1632 = _1612.x;
        float _1633 = _1612.y;
        float _1635 = _1612.z;
        float _1636 = (_1632 + _1633) - _1635;
        float _1637 = _1632 + _1635;
        float _1639 = (_1632 - _1633) - _1635;
        float3 _1646 = float3(_1636, _1637, _1639) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1636, precise::max(_1637, _1639))));
        float _1647 = _1646.x;
        float _1650 = 0.5 * _1646.y;
        float _1652 = _1646.z;
        float _1653 = 0.25 * _1652;
        _1661 = float3(((0.25 * _1647) + _1650) + _1653, 0.5 * (_1647 - _1652), (((-0.25) * _1647) + _1650) - _1653);
    }
    else
    {
        _1661 = _1628;
    }
    float _1662 = _862 ? 1.0 : _1629;
    float _1663 = _862 ? 0.0 : _842;
    float3 _1677 = (sqrt(abs(((((((((((_124[0] * _1278) + (_124[1] * _1316)) + (_124[2] * _1357)) + (_124[3] * _1398)) + (_124[4] * _1439)) + (_124[5] * _1480)) + (_124[6] * _1521)) + (_124[7] * _1562)) + (_124[8] * _1603)) / _1611) - (_1612 * _1612))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_159 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_139 * _193, _193 - float2(0.5))) / float2(int2(int(_187.x), int(_187.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _227, precise::max(powr(_216, 0.5), _220)))));
    float3 _1680 = (_787 - _1612) / precise::max(_1677, float3(1.19299997436428384389728307724e-07));
    float3 _1695;
    if (length(_1680) > 1.0)
    {
        _1695 = mix((fast::normalize(_1680) * _1677) + _1612, _787, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_132 * _137, _143)) / _146), level(0.0)).x, fast::clamp(fast::clamp(_797 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _227) * (1.0 - _218), 0.0, 1.0)));
    }
    else
    {
        _1695 = _787;
    }
    float _1705 = (_1661.x + _1661.y) - _1661.z;
    float _1706 = _1661.x + _1661.z;
    float _1708 = (_1661.x - _1661.y) - _1661.z;
    float3 _1715 = float3(_1705, _1706, _1708) / float3(precise::max(precise::max(0.0, _1705), precise::max(_1706, _1708)) + 1.0);
    float _1716 = _1715.x;
    float _1719 = 0.5 * _1715.y;
    float _1721 = _1715.z;
    float _1722 = 0.25 * _1721;
    float _1734 = (_1695.x + _1695.y) - _1695.z;
    float _1735 = _1695.x + _1695.z;
    float _1737 = (_1695.x - _1695.y) - _1695.z;
    float3 _1744 = float3(_1734, _1735, _1737) / float3(precise::max(precise::max(0.0, _1734), precise::max(_1735, _1737)) + 1.0);
    float _1745 = _1744.x;
    float _1748 = 0.5 * _1744.y;
    float _1750 = _1744.z;
    float _1751 = 0.25 * _1750;
    float3 _1762 = mix(float3(((0.25 * _1745) + _1748) + _1751, 0.5 * (_1745 - _1750), (((-0.25) * _1745) + _1748) - _1751), float3(((0.25 * _1716) + _1719) + _1722, 0.5 * (_1716 - _1721), (((-0.25) * _1716) + _1719) - _1722), float3(fast::clamp(_1662 / precise::max(6.099999882280826568603515625e-05, (_1663 * float(_1663 > 6.099999882280826568603515625e-05)) + _1662), 0.0, 1.0)));
    float _1767 = (_1762.x + _1762.y) - _1762.z;
    float _1768 = _1762.x + _1762.z;
    float _1770 = (_1762.x - _1762.y) - _1762.z;
    float4 _1779 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1780 = _1779.x;
    float3 _1785 = precise::max((float3(_1767, _1768, _1770) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1767, precise::max(_1768, _1770))))) / float3((_1780 == 0.0) ? 1.0 : _1780), float3(0.0));
    float _1786 = _1785.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1786, _1785.yz, precise::max(0.0, precise::max(0.0, precise::min(_797 + (sdk_hlsl_load(rw_new_locks, uint2(_148)).x * (1.0 - precise::max(0.0, _216))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _794))) * float(_832)), uint2(_148));
    sdk_hlsl_store(rw_upscaled_output, float4(_1786, _1785.yz, 1.0), uint2(_148));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_148));
}

