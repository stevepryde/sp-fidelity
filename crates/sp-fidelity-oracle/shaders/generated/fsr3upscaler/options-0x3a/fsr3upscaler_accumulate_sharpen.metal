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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(3)]], texture2d<float> r_farthest_depth_mip1 [[texture(4)]], texture2d<float> r_luma_instability [[texture(5)]], texture2d<float, access::read_write> rw_new_locks [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _125 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _129 = _125 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _134 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _136 = _129 + (cbFSR3Upscaler.fJitter / _134);
    float2 _140 = _134 - float2(0.5);
    float2 _143 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _145 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _154 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_145), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _156 = length(_154 * float2(3840.0, 2160.0));
    float2 _157 = _129 + _154;
    float _158 = _157.x;
    bool _163;
    if (_158 >= 0.0)
    {
        _163 = _158 <= 1.0;
    }
    else
    {
        _163 = false;
    }
    bool _172;
    if (_163)
    {
        float _166 = _157.y;
        bool _171;
        if (_166 >= 0.0)
        {
            _171 = _166 <= 1.0;
        }
        else
        {
            _171 = false;
        }
        _172 = _171;
    }
    else
    {
        _172 = false;
    }
    uint2 _184 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _190 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _207;
    if (_172)
    {
        _207 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _207 = true;
    }
    float4 _211 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_136 * _134, _140)) / _143), level(0.0));
    float _213 = fast::clamp(_211.x, 0.0, 1.0);
    float _215 = fast::clamp(_211.y, 0.0, 1.0);
    float _217 = fast::clamp(_211.z, 0.0, 1.0);
    float _219 = fast::clamp(_211.w, 0.0, 1.0);
    float _224 = _219 * float(rint(_219 * 100.0) > 1.0);
    bool _228;
    if (_172)
    {
        _228 = !_207;
    }
    else
    {
        _228 = false;
    }
    float3 _784;
    float _785;
    if (_228)
    {
        float2 _235 = (_157 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _237 = _235 - floor(_235);
        int2 _252 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _235.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _235.y)))));
        int2 _253 = _252 + int2(-1);
        int _255 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _259 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _266 = _252 + int2(0, -1);
        int2 _277 = _252 + int2(1, -1);
        int2 _288 = _252 + int2(2, -1);
        int2 _299 = _252 + int2(-1, 0);
        float4 _319 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_252.x, _255)), max(1, min(_252.y, _259))))), 0u);
        int2 _320 = _252 + int2(1, 0);
        float4 _330 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_320.x, _255)), max(1, min(_320.y, _259))))), 0u);
        int2 _331 = _252 + int2(2, 0);
        int2 _342 = _252 + int2(-1, 1);
        int2 _353 = _252 + int2(0, 1);
        float4 _363 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_353.x, _255)), max(1, min(_353.y, _259))))), 0u);
        int2 _364 = _252 + int2(1);
        float4 _374 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_364.x, _255)), max(1, min(_364.y, _259))))), 0u);
        int2 _375 = _252 + int2(2, 1);
        int2 _386 = _252 + int2(-1, 2);
        int2 _397 = _252 + int2(0, 2);
        int2 _408 = _252 + int2(1, 2);
        int2 _419 = _252 + int2(2);
        float _430 = _237.x;
        float _433 = precise::min(abs((-1.0) - _430), 2.0);
        bool _435 = abs(_433) < 6.099999882280826568603515625e-05;
        float _446;
        if (_435)
        {
            _446 = 1.0;
        }
        else
        {
            float _439 = 3.1415927410125732421875 * _433;
            float _442 = 1.57079637050628662109375 * _433;
            _446 = (sin(_439) / _439) * (sin(_442) / _442);
        }
        float _449 = precise::min(abs(-_430), 2.0);
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
        float _465 = precise::min(abs(1.0 - _430), 2.0);
        bool _467 = abs(_465) < 6.099999882280826568603515625e-05;
        float _478;
        if (_467)
        {
            _478 = 1.0;
        }
        else
        {
            float _471 = 3.1415927410125732421875 * _465;
            float _474 = 1.57079637050628662109375 * _465;
            _478 = (sin(_471) / _471) * (sin(_474) / _474);
        }
        float _481 = precise::min(abs(2.0 - _430), 2.0);
        bool _483 = abs(_481) < 6.099999882280826568603515625e-05;
        float _494;
        if (_483)
        {
            _494 = 1.0;
        }
        else
        {
            float _487 = 3.1415927410125732421875 * _481;
            float _490 = 1.57079637050628662109375 * _481;
            _494 = (sin(_487) / _487) * (sin(_490) / _490);
        }
        float _517;
        if (_435)
        {
            _517 = 1.0;
        }
        else
        {
            float _510 = 3.1415927410125732421875 * _433;
            float _513 = 1.57079637050628662109375 * _433;
            _517 = (sin(_510) / _510) * (sin(_513) / _513);
        }
        float _528;
        if (_451)
        {
            _528 = 1.0;
        }
        else
        {
            float _521 = 3.1415927410125732421875 * _449;
            float _524 = 1.57079637050628662109375 * _449;
            _528 = (sin(_521) / _521) * (sin(_524) / _524);
        }
        float _539;
        if (_467)
        {
            _539 = 1.0;
        }
        else
        {
            float _532 = 3.1415927410125732421875 * _465;
            float _535 = 1.57079637050628662109375 * _465;
            _539 = (sin(_532) / _532) * (sin(_535) / _535);
        }
        float _550;
        if (_483)
        {
            _550 = 1.0;
        }
        else
        {
            float _543 = 3.1415927410125732421875 * _481;
            float _546 = 1.57079637050628662109375 * _481;
            _550 = (sin(_543) / _543) * (sin(_546) / _546);
        }
        float _573;
        if (_435)
        {
            _573 = 1.0;
        }
        else
        {
            float _566 = 3.1415927410125732421875 * _433;
            float _569 = 1.57079637050628662109375 * _433;
            _573 = (sin(_566) / _566) * (sin(_569) / _569);
        }
        float _584;
        if (_451)
        {
            _584 = 1.0;
        }
        else
        {
            float _577 = 3.1415927410125732421875 * _449;
            float _580 = 1.57079637050628662109375 * _449;
            _584 = (sin(_577) / _577) * (sin(_580) / _580);
        }
        float _595;
        if (_467)
        {
            _595 = 1.0;
        }
        else
        {
            float _588 = 3.1415927410125732421875 * _465;
            float _591 = 1.57079637050628662109375 * _465;
            _595 = (sin(_588) / _588) * (sin(_591) / _591);
        }
        float _606;
        if (_483)
        {
            _606 = 1.0;
        }
        else
        {
            float _599 = 3.1415927410125732421875 * _481;
            float _602 = 1.57079637050628662109375 * _481;
            _606 = (sin(_599) / _599) * (sin(_602) / _602);
        }
        float _629;
        if (_435)
        {
            _629 = 1.0;
        }
        else
        {
            float _622 = 3.1415927410125732421875 * _433;
            float _625 = 1.57079637050628662109375 * _433;
            _629 = (sin(_622) / _622) * (sin(_625) / _625);
        }
        float _640;
        if (_451)
        {
            _640 = 1.0;
        }
        else
        {
            float _633 = 3.1415927410125732421875 * _449;
            float _636 = 1.57079637050628662109375 * _449;
            _640 = (sin(_633) / _633) * (sin(_636) / _636);
        }
        float _651;
        if (_467)
        {
            _651 = 1.0;
        }
        else
        {
            float _644 = 3.1415927410125732421875 * _465;
            float _647 = 1.57079637050628662109375 * _465;
            _651 = (sin(_644) / _644) * (sin(_647) / _647);
        }
        float _662;
        if (_483)
        {
            _662 = 1.0;
        }
        else
        {
            float _655 = 3.1415927410125732421875 * _481;
            float _658 = 1.57079637050628662109375 * _481;
            _662 = (sin(_655) / _655) * (sin(_658) / _658);
        }
        float _675 = _237.y;
        float _678 = precise::min(abs((-1.0) - _675), 2.0);
        float _691;
        if (abs(_678) < 6.099999882280826568603515625e-05)
        {
            _691 = 1.0;
        }
        else
        {
            float _684 = 3.1415927410125732421875 * _678;
            float _687 = 1.57079637050628662109375 * _678;
            _691 = (sin(_684) / _684) * (sin(_687) / _687);
        }
        float _694 = precise::min(abs(-_675), 2.0);
        float _707;
        if (abs(_694) < 6.099999882280826568603515625e-05)
        {
            _707 = 1.0;
        }
        else
        {
            float _700 = 3.1415927410125732421875 * _694;
            float _703 = 1.57079637050628662109375 * _694;
            _707 = (sin(_700) / _700) * (sin(_703) / _703);
        }
        float _710 = precise::min(abs(1.0 - _675), 2.0);
        float _723;
        if (abs(_710) < 6.099999882280826568603515625e-05)
        {
            _723 = 1.0;
        }
        else
        {
            float _716 = 3.1415927410125732421875 * _710;
            float _719 = 1.57079637050628662109375 * _710;
            _723 = (sin(_716) / _716) * (sin(_719) / _719);
        }
        float _726 = precise::min(abs(2.0 - _675), 2.0);
        float _739;
        if (abs(_726) < 6.099999882280826568603515625e-05)
        {
            _739 = 1.0;
        }
        else
        {
            float _732 = 3.1415927410125732421875 * _726;
            float _735 = 1.57079637050628662109375 * _726;
            _739 = (sin(_732) / _732) * (sin(_735) / _735);
        }
        float4 _744 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_253.x, _255)), max(1, min(_253.y, _259))))), 0u) * _446) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_266.x, _255)), max(1, min(_266.y, _259))))), 0u) * _462)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_277.x, _255)), max(1, min(_277.y, _259))))), 0u) * _478)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_288.x, _255)), max(1, min(_288.y, _259))))), 0u) * _494)) / float4(((_446 + _462) + _478) + _494)) * _691) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_299.x, _255)), max(1, min(_299.y, _259))))), 0u) * _517) + (_319 * _528)) + (_330 * _539)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_331.x, _255)), max(1, min(_331.y, _259))))), 0u) * _550)) / float4(((_517 + _528) + _539) + _550)) * _707)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_342.x, _255)), max(1, min(_342.y, _259))))), 0u) * _573) + (_363 * _584)) + (_374 * _595)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_375.x, _255)), max(1, min(_375.y, _259))))), 0u) * _606)) / float4(((_573 + _584) + _595) + _606)) * _723);
        float4 _758 = fast::clamp((_744 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_386.x, _255)), max(1, min(_386.y, _259))))), 0u) * _629) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_397.x, _255)), max(1, min(_397.y, _259))))), 0u) * _640)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_408.x, _255)), max(1, min(_408.y, _259))))), 0u) * _651)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_419.x, _255)), max(1, min(_419.y, _259))))), 0u) * _662)) / float4(((_629 + _640) + _651) + _662)) * _739)) / float4(((_691 + _707) + _723) + _739), precise::min(precise::min(precise::min(_319, _330), _363), _374), precise::max(precise::max(precise::max(_319, _330), _363), _374));
        float4 _764 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _765 = _764.x;
        float3 _768 = (_758.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_765 == 0.0) ? 1.0 : _765);
        float _769 = _768.x;
        float _772 = 0.5 * _768.y;
        float _774 = _768.z;
        float _775 = 0.25 * _774;
        _784 = float3(((0.25 * _769) + _772) + _775, 0.5 * (_769 - _774), (((-0.25) * _769) + _772) - _775);
        _785 = _758.w;
    }
    else
    {
        _784 = float3(0.0);
        _785 = 0.0;
    }
    float _791 = precise::max(fast::clamp(_217, 0.0, 1.0), precise::max(_213, _215));
    float _794 = precise::max(0.0, (_785 * float(!_207)) - (_791 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _814 = _129 - _154;
    float _815 = _814.x;
    bool _820;
    if (_815 >= 0.0)
    {
        _820 = _815 <= 1.0;
    }
    else
    {
        _820 = false;
    }
    bool _829;
    if (_820)
    {
        float _823 = _814.y;
        bool _828;
        if (_823 >= 0.0)
        {
            _828 = _823 <= 1.0;
        }
        else
        {
            _828 = false;
        }
        _829 = _828;
    }
    else
    {
        _829 = false;
    }
    float _839 = precise::min(_224, mix(_224, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_156 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _842 = _125 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _844 = int2(floor(_842));
    float2 _847 = (float2(_844) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _848 = _847 - _842;
    bool _851 = _847.x > _842.x;
    bool _855 = _847.y > _842.y;
    int2 _857 = int2(_851 ? (-2) : (-1), _855 ? (-2) : (-1));
    float2 _858 = float2(_857);
    bool _859 = _224 == 0.0;
    int _860 = _851 ? 3 : 0;
    int _861 = _855 ? 3 : 0;
    int2 _862 = int2(_860, _861);
    int2 _863 = _844 + _857;
    int2 _864 = _863 + _862;
    int _867 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _872 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _882 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _883 = _882.x;
    float3 _886 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_864.x, _867)), max(0, min(_864.y, _872))))), 0u).xyz) * ((_883 == 0.0) ? 1.0 : _883);
    float _887 = _886.x;
    float _890 = 0.5 * _886.y;
    float _892 = _886.z;
    float _893 = 0.25 * _892;
    spvUnsafeArray<float3, 9> _121;
    _121[0] = float3(((0.25 * _887) + _890) + _893, 0.5 * (_887 - _892), (((-0.25) * _887) + _890) - _893);
    int _902 = _851 ? 2 : 1;
    int2 _903 = int2(_902, _861);
    int2 _904 = _863 + _903;
    float4 _918 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _919 = _918.x;
    float3 _922 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_904.x, _867)), max(0, min(_904.y, _872))))), 0u).xyz) * ((_919 == 0.0) ? 1.0 : _919);
    float _923 = _922.x;
    float _926 = 0.5 * _922.y;
    float _928 = _922.z;
    float _929 = 0.25 * _928;
    _121[1] = float3(((0.25 * _923) + _926) + _929, 0.5 * (_923 - _928), (((-0.25) * _923) + _926) - _929);
    int _938 = _851 ? 1 : 2;
    int2 _939 = int2(_938, _861);
    int2 _940 = _863 + _939;
    float4 _954 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _955 = _954.x;
    float3 _958 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_940.x, _867)), max(0, min(_940.y, _872))))), 0u).xyz) * ((_955 == 0.0) ? 1.0 : _955);
    float _959 = _958.x;
    float _962 = 0.5 * _958.y;
    float _964 = _958.z;
    float _965 = 0.25 * _964;
    _121[2] = float3(((0.25 * _959) + _962) + _965, 0.5 * (_959 - _964), (((-0.25) * _959) + _962) - _965);
    int _974 = _855 ? 2 : 1;
    int2 _975 = int2(_860, _974);
    int2 _976 = _863 + _975;
    float4 _990 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _991 = _990.x;
    float3 _994 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_976.x, _867)), max(0, min(_976.y, _872))))), 0u).xyz) * ((_991 == 0.0) ? 1.0 : _991);
    float _995 = _994.x;
    float _998 = 0.5 * _994.y;
    float _1000 = _994.z;
    float _1001 = 0.25 * _1000;
    _121[3] = float3(((0.25 * _995) + _998) + _1001, 0.5 * (_995 - _1000), (((-0.25) * _995) + _998) - _1001);
    int2 _1010 = int2(_902, _974);
    int2 _1011 = _863 + _1010;
    float4 _1025 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1026 = _1025.x;
    float3 _1029 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1011.x, _867)), max(0, min(_1011.y, _872))))), 0u).xyz) * ((_1026 == 0.0) ? 1.0 : _1026);
    float _1030 = _1029.x;
    float _1033 = 0.5 * _1029.y;
    float _1035 = _1029.z;
    float _1036 = 0.25 * _1035;
    _121[4] = float3(((0.25 * _1030) + _1033) + _1036, 0.5 * (_1030 - _1035), (((-0.25) * _1030) + _1033) - _1036);
    int2 _1045 = int2(_938, _974);
    int2 _1046 = _863 + _1045;
    float4 _1060 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1061 = _1060.x;
    float3 _1064 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1046.x, _867)), max(0, min(_1046.y, _872))))), 0u).xyz) * ((_1061 == 0.0) ? 1.0 : _1061);
    float _1065 = _1064.x;
    float _1068 = 0.5 * _1064.y;
    float _1070 = _1064.z;
    float _1071 = 0.25 * _1070;
    _121[5] = float3(((0.25 * _1065) + _1068) + _1071, 0.5 * (_1065 - _1070), (((-0.25) * _1065) + _1068) - _1071);
    int _1080 = _855 ? 1 : 2;
    int2 _1081 = int2(_860, _1080);
    int2 _1082 = _863 + _1081;
    float4 _1096 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1097 = _1096.x;
    float3 _1100 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1082.x, _867)), max(0, min(_1082.y, _872))))), 0u).xyz) * ((_1097 == 0.0) ? 1.0 : _1097);
    float _1101 = _1100.x;
    float _1104 = 0.5 * _1100.y;
    float _1106 = _1100.z;
    float _1107 = 0.25 * _1106;
    _121[6] = float3(((0.25 * _1101) + _1104) + _1107, 0.5 * (_1101 - _1106), (((-0.25) * _1101) + _1104) - _1107);
    int2 _1116 = int2(_902, _1080);
    int2 _1117 = _863 + _1116;
    float4 _1131 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1132 = _1131.x;
    float3 _1135 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1117.x, _867)), max(0, min(_1117.y, _872))))), 0u).xyz) * ((_1132 == 0.0) ? 1.0 : _1132);
    float _1136 = _1135.x;
    float _1139 = 0.5 * _1135.y;
    float _1141 = _1135.z;
    float _1142 = 0.25 * _1141;
    _121[7] = float3(((0.25 * _1136) + _1139) + _1142, 0.5 * (_1136 - _1141), (((-0.25) * _1136) + _1139) - _1142);
    int2 _1151 = int2(_938, _1080);
    int2 _1152 = _863 + _1151;
    float4 _1166 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1167 = _1166.x;
    float3 _1170 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1152.x, _867)), max(0, min(_1152.y, _872))))), 0u).xyz) * ((_1167 == 0.0) ? 1.0 : _1167);
    float _1171 = _1170.x;
    float _1174 = 0.5 * _1170.y;
    float _1176 = _1170.z;
    float _1177 = 0.25 * _1176;
    _121[8] = float3(((0.25 * _1171) + _1174) + _1177, 0.5 * (_1171 - _1176), (((-0.25) * _1171) + _1174) - _1177);
    if (_859)
    {
        for (int _1189 = 0; _1189 < 9; )
        {
            float _1200 = (_121[_1189].x + _121[_1189].y) - _121[_1189].z;
            float _1201 = _121[_1189].x + _121[_1189].z;
            float _1203 = (_121[_1189].x - _121[_1189].y) - _121[_1189].z;
            float3 _1210 = float3(_1200, _1201, _1203) / float3(precise::max(precise::max(0.0, _1200), precise::max(_1201, _1203)) + 1.0);
            float _1211 = _1210.x;
            float _1214 = 0.5 * _1210.y;
            float _1216 = _1210.z;
            float _1217 = 0.25 * _1216;
            _121[_1189] = float3(((0.25 * _1211) + _1214) + _1217, 0.5 * (_1211 - _1216), (((-0.25) * _1211) + _1214) - _1217);
            _1189++;
            continue;
        }
    }
    float _1229 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1240 = mix(precise::max(1.0, (1.0 + _1229) * 0.300000011920928955078125), _1229, precise::min(1.0 - (_215 * 0.5), precise::min(1.0 - _217, fast::clamp(_839 * 5.0, 0.0, 1.0))));
    float2 _1243 = _848 + (_858 + float2(_862));
    uint2 _1245 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1248 = float(all(uint2(_864) < _1245));
    bool _1249 = !_859;
    float _1268;
    float3 _1269;
    if (_1249)
    {
        float2 _1253 = _1243 * float2(_1240);
        float _1255 = precise::min(dot(_1253, _1253), 4.0);
        float _1257 = (0.4000000059604644775390625 * _1255) - 1.0;
        float _1259 = (0.25 * _1255) - 1.0;
        float _1265 = _1248 * ((((1.5625 * _1257) * _1257) - 0.5625) * (_1259 * _1259));
        _1268 = _1265;
        _1269 = _121[0] * _1265;
    }
    else
    {
        _1268 = 0.0;
        _1269 = float3(0.0);
    }
    float _1273 = exp((-2.2999999523162841796875) * dot(_1243, _1243)) * _1248;
    float3 _1275 = _121[0] * _1273;
    float2 _1279 = _848 + (_858 + float2(_903));
    float _1283 = float(all(uint2(_904) < _1245));
    float _1304;
    float3 _1305;
    if (_1249)
    {
        float2 _1287 = _1279 * float2(_1240);
        float _1289 = precise::min(dot(_1287, _1287), 4.0);
        float _1291 = (0.4000000059604644775390625 * _1289) - 1.0;
        float _1293 = (0.25 * _1289) - 1.0;
        float _1299 = _1283 * ((((1.5625 * _1291) * _1291) - 0.5625) * (_1293 * _1293));
        _1304 = _1268 + _1299;
        _1305 = _1269 + (_121[1] * _1299);
    }
    else
    {
        _1304 = _1268;
        _1305 = _1269;
    }
    float _1309 = exp((-2.2999999523162841796875) * dot(_1279, _1279)) * _1283;
    float3 _1313 = _121[1] * _1309;
    float2 _1320 = _848 + (_858 + float2(_939));
    float _1324 = float(all(uint2(_940) < _1245));
    float _1345;
    float3 _1346;
    if (_1249)
    {
        float2 _1328 = _1320 * float2(_1240);
        float _1330 = precise::min(dot(_1328, _1328), 4.0);
        float _1332 = (0.4000000059604644775390625 * _1330) - 1.0;
        float _1334 = (0.25 * _1330) - 1.0;
        float _1340 = _1324 * ((((1.5625 * _1332) * _1332) - 0.5625) * (_1334 * _1334));
        _1345 = _1304 + _1340;
        _1346 = _1305 + (_121[2] * _1340);
    }
    else
    {
        _1345 = _1304;
        _1346 = _1305;
    }
    float _1350 = exp((-2.2999999523162841796875) * dot(_1320, _1320)) * _1324;
    float3 _1354 = _121[2] * _1350;
    float2 _1361 = _848 + (_858 + float2(_975));
    float _1365 = float(all(uint2(_976) < _1245));
    float _1386;
    float3 _1387;
    if (_1249)
    {
        float2 _1369 = _1361 * float2(_1240);
        float _1371 = precise::min(dot(_1369, _1369), 4.0);
        float _1373 = (0.4000000059604644775390625 * _1371) - 1.0;
        float _1375 = (0.25 * _1371) - 1.0;
        float _1381 = _1365 * ((((1.5625 * _1373) * _1373) - 0.5625) * (_1375 * _1375));
        _1386 = _1345 + _1381;
        _1387 = _1346 + (_121[3] * _1381);
    }
    else
    {
        _1386 = _1345;
        _1387 = _1346;
    }
    float _1391 = exp((-2.2999999523162841796875) * dot(_1361, _1361)) * _1365;
    float3 _1395 = _121[3] * _1391;
    float2 _1402 = _848 + (_858 + float2(_1010));
    float _1406 = float(all(uint2(_1011) < _1245));
    float _1427;
    float3 _1428;
    if (_1249)
    {
        float2 _1410 = _1402 * float2(_1240);
        float _1412 = precise::min(dot(_1410, _1410), 4.0);
        float _1414 = (0.4000000059604644775390625 * _1412) - 1.0;
        float _1416 = (0.25 * _1412) - 1.0;
        float _1422 = _1406 * ((((1.5625 * _1414) * _1414) - 0.5625) * (_1416 * _1416));
        _1427 = _1386 + _1422;
        _1428 = _1387 + (_121[4] * _1422);
    }
    else
    {
        _1427 = _1386;
        _1428 = _1387;
    }
    float _1432 = exp((-2.2999999523162841796875) * dot(_1402, _1402)) * _1406;
    float3 _1436 = _121[4] * _1432;
    float2 _1443 = _848 + (_858 + float2(_1045));
    float _1447 = float(all(uint2(_1046) < _1245));
    float _1468;
    float3 _1469;
    if (_1249)
    {
        float2 _1451 = _1443 * float2(_1240);
        float _1453 = precise::min(dot(_1451, _1451), 4.0);
        float _1455 = (0.4000000059604644775390625 * _1453) - 1.0;
        float _1457 = (0.25 * _1453) - 1.0;
        float _1463 = _1447 * ((((1.5625 * _1455) * _1455) - 0.5625) * (_1457 * _1457));
        _1468 = _1427 + _1463;
        _1469 = _1428 + (_121[5] * _1463);
    }
    else
    {
        _1468 = _1427;
        _1469 = _1428;
    }
    float _1473 = exp((-2.2999999523162841796875) * dot(_1443, _1443)) * _1447;
    float3 _1477 = _121[5] * _1473;
    float2 _1484 = _848 + (_858 + float2(_1081));
    float _1488 = float(all(uint2(_1082) < _1245));
    float _1509;
    float3 _1510;
    if (_1249)
    {
        float2 _1492 = _1484 * float2(_1240);
        float _1494 = precise::min(dot(_1492, _1492), 4.0);
        float _1496 = (0.4000000059604644775390625 * _1494) - 1.0;
        float _1498 = (0.25 * _1494) - 1.0;
        float _1504 = _1488 * ((((1.5625 * _1496) * _1496) - 0.5625) * (_1498 * _1498));
        _1509 = _1468 + _1504;
        _1510 = _1469 + (_121[6] * _1504);
    }
    else
    {
        _1509 = _1468;
        _1510 = _1469;
    }
    float _1514 = exp((-2.2999999523162841796875) * dot(_1484, _1484)) * _1488;
    float3 _1518 = _121[6] * _1514;
    float2 _1525 = _848 + (_858 + float2(_1116));
    float _1529 = float(all(uint2(_1117) < _1245));
    float _1550;
    float3 _1551;
    if (_1249)
    {
        float2 _1533 = _1525 * float2(_1240);
        float _1535 = precise::min(dot(_1533, _1533), 4.0);
        float _1537 = (0.4000000059604644775390625 * _1535) - 1.0;
        float _1539 = (0.25 * _1535) - 1.0;
        float _1545 = _1529 * ((((1.5625 * _1537) * _1537) - 0.5625) * (_1539 * _1539));
        _1550 = _1509 + _1545;
        _1551 = _1510 + (_121[7] * _1545);
    }
    else
    {
        _1550 = _1509;
        _1551 = _1510;
    }
    float _1555 = exp((-2.2999999523162841796875) * dot(_1525, _1525)) * _1529;
    float3 _1559 = _121[7] * _1555;
    float2 _1566 = _848 + (_858 + float2(_1151));
    float _1570 = float(all(uint2(_1152) < _1245));
    float _1591;
    float3 _1592;
    if (_1249)
    {
        float2 _1574 = _1566 * float2(_1240);
        float _1576 = precise::min(dot(_1574, _1574), 4.0);
        float _1578 = (0.4000000059604644775390625 * _1576) - 1.0;
        float _1580 = (0.25 * _1576) - 1.0;
        float _1586 = _1570 * ((((1.5625 * _1578) * _1578) - 0.5625) * (_1580 * _1580));
        _1591 = _1550 + _1586;
        _1592 = _1551 + (_121[8] * _1586);
    }
    else
    {
        _1591 = _1550;
        _1592 = _1551;
    }
    float _1596 = exp((-2.2999999523162841796875) * dot(_1566, _1566)) * _1570;
    float3 _1600 = _121[8] * _1596;
    float _1604 = (((((((_1273 + _1309) + _1350) + _1391) + _1432) + _1473) + _1514) + _1555) + _1596;
    float3 _1608 = float3((abs(_1604) > 1.1754943508222875079687365372222e-38) ? _1604 : 1.0);
    float3 _1609 = ((((((((_1275 + _1313) + _1354) + _1395) + _1436) + _1477) + _1518) + _1559) + _1600) / _1608;
    float _1617 = _1591 * float(_1591 > 6.099999882280826568603515625e-05);
    float3 _1625;
    float _1626;
    if (_1617 > 6.099999882280826568603515625e-05)
    {
        _1625 = fast::clamp(_1592 / float3(_1617), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_121[0], _121[1]), _121[2]), _121[3]), _121[4]), _121[5]), _121[6]), _121[7]), _121[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_121[0], _121[1]), _121[2]), _121[3]), _121[4]), _121[5]), _121[6]), _121[7]), _121[8]));
        _1626 = _1617 * 0.04625000059604644775390625;
    }
    else
    {
        _1625 = _1592;
        _1626 = _1617;
    }
    float3 _1658;
    if (_859)
    {
        float _1629 = _1609.x;
        float _1630 = _1609.y;
        float _1632 = _1609.z;
        float _1633 = (_1629 + _1630) - _1632;
        float _1634 = _1629 + _1632;
        float _1636 = (_1629 - _1630) - _1632;
        float3 _1643 = float3(_1633, _1634, _1636) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1633, precise::max(_1634, _1636))));
        float _1644 = _1643.x;
        float _1647 = 0.5 * _1643.y;
        float _1649 = _1643.z;
        float _1650 = 0.25 * _1649;
        _1658 = float3(((0.25 * _1644) + _1647) + _1650, 0.5 * (_1644 - _1649), (((-0.25) * _1644) + _1647) - _1650);
    }
    else
    {
        _1658 = _1625;
    }
    float _1659 = _859 ? 1.0 : _1626;
    float _1660 = _859 ? 0.0 : _839;
    float3 _1674 = (sqrt(abs(((((((((((_121[0] * _1275) + (_121[1] * _1313)) + (_121[2] * _1354)) + (_121[3] * _1395)) + (_121[4] * _1436)) + (_121[5] * _1477)) + (_121[6] * _1518)) + (_121[7] * _1559)) + (_121[8] * _1600)) / _1608) - (_1609 * _1609))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_156 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_136 * _190, _190 - float2(0.5))) / float2(int2(int(_184.x), int(_184.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _224, precise::max(powr(_213, 0.5), _217)))));
    float3 _1677 = (_784 - _1609) / precise::max(_1674, float3(1.19299997436428384389728307724e-07));
    float3 _1692;
    if (length(_1677) > 1.0)
    {
        _1692 = mix((fast::normalize(_1677) * _1674) + _1609, _784, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_129 * _134, _140)) / _143), level(0.0)).x, fast::clamp(fast::clamp(_794 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _224) * (1.0 - _215), 0.0, 1.0)));
    }
    else
    {
        _1692 = _784;
    }
    float _1702 = (_1658.x + _1658.y) - _1658.z;
    float _1703 = _1658.x + _1658.z;
    float _1705 = (_1658.x - _1658.y) - _1658.z;
    float3 _1712 = float3(_1702, _1703, _1705) / float3(precise::max(precise::max(0.0, _1702), precise::max(_1703, _1705)) + 1.0);
    float _1713 = _1712.x;
    float _1716 = 0.5 * _1712.y;
    float _1718 = _1712.z;
    float _1719 = 0.25 * _1718;
    float _1731 = (_1692.x + _1692.y) - _1692.z;
    float _1732 = _1692.x + _1692.z;
    float _1734 = (_1692.x - _1692.y) - _1692.z;
    float3 _1741 = float3(_1731, _1732, _1734) / float3(precise::max(precise::max(0.0, _1731), precise::max(_1732, _1734)) + 1.0);
    float _1742 = _1741.x;
    float _1745 = 0.5 * _1741.y;
    float _1747 = _1741.z;
    float _1748 = 0.25 * _1747;
    float3 _1759 = mix(float3(((0.25 * _1742) + _1745) + _1748, 0.5 * (_1742 - _1747), (((-0.25) * _1742) + _1745) - _1748), float3(((0.25 * _1713) + _1716) + _1719, 0.5 * (_1713 - _1718), (((-0.25) * _1713) + _1716) - _1719), float3(fast::clamp(_1659 / precise::max(6.099999882280826568603515625e-05, (_1660 * float(_1660 > 6.099999882280826568603515625e-05)) + _1659), 0.0, 1.0)));
    float _1764 = (_1759.x + _1759.y) - _1759.z;
    float _1765 = _1759.x + _1759.z;
    float _1767 = (_1759.x - _1759.y) - _1759.z;
    float4 _1776 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1777 = _1776.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max((float3(_1764, _1765, _1767) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1764, precise::max(_1765, _1767))))) / float3((_1777 == 0.0) ? 1.0 : _1777), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_794 + (sdk_hlsl_load(rw_new_locks, uint2(_145)).x * (1.0 - precise::max(0.0, _213))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _791))) * float(_829)), uint2(_145));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_145));
}

