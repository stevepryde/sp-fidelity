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
    float2 _127 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _131 = _127 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _136 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _138 = _131 + (cbFSR3Upscaler.fJitter / _136);
    float2 _142 = _136 - float2(0.5);
    float2 _145 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _147 = _131 * _136;
    float2 _152 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_147))), 0u).xy;
    float _154 = length(_152 * float2(3840.0, 2160.0));
    float2 _155 = _131 + _152;
    float _156 = _155.x;
    bool _161;
    if (_156 >= 0.0)
    {
        _161 = _156 <= 1.0;
    }
    else
    {
        _161 = false;
    }
    bool _170;
    if (_161)
    {
        float _164 = _155.y;
        bool _169;
        if (_164 >= 0.0)
        {
            _169 = _164 <= 1.0;
        }
        else
        {
            _169 = false;
        }
        _170 = _169;
    }
    else
    {
        _170 = false;
    }
    uint2 _181 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _187 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _204;
    if (_170)
    {
        _204 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _204 = true;
    }
    float4 _208 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _136, _142)) / _145), level(0.0));
    float _210 = fast::clamp(_208.x, 0.0, 1.0);
    float _212 = fast::clamp(_208.y, 0.0, 1.0);
    float _214 = fast::clamp(_208.z, 0.0, 1.0);
    float _216 = fast::clamp(_208.w, 0.0, 1.0);
    float _221 = _216 * float(rint(_216 * 100.0) > 1.0);
    bool _225;
    if (_170)
    {
        _225 = !_204;
    }
    else
    {
        _225 = false;
    }
    float3 _781;
    float _782;
    if (_225)
    {
        float2 _232 = (_155 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _234 = _232 - floor(_232);
        int2 _249 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _232.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _232.y)))));
        int2 _250 = _249 + int2(-1);
        int _252 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _256 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _263 = _249 + int2(0, -1);
        int2 _274 = _249 + int2(1, -1);
        int2 _285 = _249 + int2(2, -1);
        int2 _296 = _249 + int2(-1, 0);
        float4 _316 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_249.x, _252)), max(1, min(_249.y, _256))))), 0u);
        int2 _317 = _249 + int2(1, 0);
        float4 _327 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_317.x, _252)), max(1, min(_317.y, _256))))), 0u);
        int2 _328 = _249 + int2(2, 0);
        int2 _339 = _249 + int2(-1, 1);
        int2 _350 = _249 + int2(0, 1);
        float4 _360 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_350.x, _252)), max(1, min(_350.y, _256))))), 0u);
        int2 _361 = _249 + int2(1);
        float4 _371 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_361.x, _252)), max(1, min(_361.y, _256))))), 0u);
        int2 _372 = _249 + int2(2, 1);
        int2 _383 = _249 + int2(-1, 2);
        int2 _394 = _249 + int2(0, 2);
        int2 _405 = _249 + int2(1, 2);
        int2 _416 = _249 + int2(2);
        float _427 = _234.x;
        float _430 = precise::min(abs((-1.0) - _427), 2.0);
        bool _432 = abs(_430) < 6.099999882280826568603515625e-05;
        float _443;
        if (_432)
        {
            _443 = 1.0;
        }
        else
        {
            float _436 = 3.1415927410125732421875 * _430;
            float _439 = 1.57079637050628662109375 * _430;
            _443 = (sin(_436) / _436) * (sin(_439) / _439);
        }
        float _446 = precise::min(abs(-_427), 2.0);
        bool _448 = abs(_446) < 6.099999882280826568603515625e-05;
        float _459;
        if (_448)
        {
            _459 = 1.0;
        }
        else
        {
            float _452 = 3.1415927410125732421875 * _446;
            float _455 = 1.57079637050628662109375 * _446;
            _459 = (sin(_452) / _452) * (sin(_455) / _455);
        }
        float _462 = precise::min(abs(1.0 - _427), 2.0);
        bool _464 = abs(_462) < 6.099999882280826568603515625e-05;
        float _475;
        if (_464)
        {
            _475 = 1.0;
        }
        else
        {
            float _468 = 3.1415927410125732421875 * _462;
            float _471 = 1.57079637050628662109375 * _462;
            _475 = (sin(_468) / _468) * (sin(_471) / _471);
        }
        float _478 = precise::min(abs(2.0 - _427), 2.0);
        bool _480 = abs(_478) < 6.099999882280826568603515625e-05;
        float _491;
        if (_480)
        {
            _491 = 1.0;
        }
        else
        {
            float _484 = 3.1415927410125732421875 * _478;
            float _487 = 1.57079637050628662109375 * _478;
            _491 = (sin(_484) / _484) * (sin(_487) / _487);
        }
        float _514;
        if (_432)
        {
            _514 = 1.0;
        }
        else
        {
            float _507 = 3.1415927410125732421875 * _430;
            float _510 = 1.57079637050628662109375 * _430;
            _514 = (sin(_507) / _507) * (sin(_510) / _510);
        }
        float _525;
        if (_448)
        {
            _525 = 1.0;
        }
        else
        {
            float _518 = 3.1415927410125732421875 * _446;
            float _521 = 1.57079637050628662109375 * _446;
            _525 = (sin(_518) / _518) * (sin(_521) / _521);
        }
        float _536;
        if (_464)
        {
            _536 = 1.0;
        }
        else
        {
            float _529 = 3.1415927410125732421875 * _462;
            float _532 = 1.57079637050628662109375 * _462;
            _536 = (sin(_529) / _529) * (sin(_532) / _532);
        }
        float _547;
        if (_480)
        {
            _547 = 1.0;
        }
        else
        {
            float _540 = 3.1415927410125732421875 * _478;
            float _543 = 1.57079637050628662109375 * _478;
            _547 = (sin(_540) / _540) * (sin(_543) / _543);
        }
        float _570;
        if (_432)
        {
            _570 = 1.0;
        }
        else
        {
            float _563 = 3.1415927410125732421875 * _430;
            float _566 = 1.57079637050628662109375 * _430;
            _570 = (sin(_563) / _563) * (sin(_566) / _566);
        }
        float _581;
        if (_448)
        {
            _581 = 1.0;
        }
        else
        {
            float _574 = 3.1415927410125732421875 * _446;
            float _577 = 1.57079637050628662109375 * _446;
            _581 = (sin(_574) / _574) * (sin(_577) / _577);
        }
        float _592;
        if (_464)
        {
            _592 = 1.0;
        }
        else
        {
            float _585 = 3.1415927410125732421875 * _462;
            float _588 = 1.57079637050628662109375 * _462;
            _592 = (sin(_585) / _585) * (sin(_588) / _588);
        }
        float _603;
        if (_480)
        {
            _603 = 1.0;
        }
        else
        {
            float _596 = 3.1415927410125732421875 * _478;
            float _599 = 1.57079637050628662109375 * _478;
            _603 = (sin(_596) / _596) * (sin(_599) / _599);
        }
        float _626;
        if (_432)
        {
            _626 = 1.0;
        }
        else
        {
            float _619 = 3.1415927410125732421875 * _430;
            float _622 = 1.57079637050628662109375 * _430;
            _626 = (sin(_619) / _619) * (sin(_622) / _622);
        }
        float _637;
        if (_448)
        {
            _637 = 1.0;
        }
        else
        {
            float _630 = 3.1415927410125732421875 * _446;
            float _633 = 1.57079637050628662109375 * _446;
            _637 = (sin(_630) / _630) * (sin(_633) / _633);
        }
        float _648;
        if (_464)
        {
            _648 = 1.0;
        }
        else
        {
            float _641 = 3.1415927410125732421875 * _462;
            float _644 = 1.57079637050628662109375 * _462;
            _648 = (sin(_641) / _641) * (sin(_644) / _644);
        }
        float _659;
        if (_480)
        {
            _659 = 1.0;
        }
        else
        {
            float _652 = 3.1415927410125732421875 * _478;
            float _655 = 1.57079637050628662109375 * _478;
            _659 = (sin(_652) / _652) * (sin(_655) / _655);
        }
        float _672 = _234.y;
        float _675 = precise::min(abs((-1.0) - _672), 2.0);
        float _688;
        if (abs(_675) < 6.099999882280826568603515625e-05)
        {
            _688 = 1.0;
        }
        else
        {
            float _681 = 3.1415927410125732421875 * _675;
            float _684 = 1.57079637050628662109375 * _675;
            _688 = (sin(_681) / _681) * (sin(_684) / _684);
        }
        float _691 = precise::min(abs(-_672), 2.0);
        float _704;
        if (abs(_691) < 6.099999882280826568603515625e-05)
        {
            _704 = 1.0;
        }
        else
        {
            float _697 = 3.1415927410125732421875 * _691;
            float _700 = 1.57079637050628662109375 * _691;
            _704 = (sin(_697) / _697) * (sin(_700) / _700);
        }
        float _707 = precise::min(abs(1.0 - _672), 2.0);
        float _720;
        if (abs(_707) < 6.099999882280826568603515625e-05)
        {
            _720 = 1.0;
        }
        else
        {
            float _713 = 3.1415927410125732421875 * _707;
            float _716 = 1.57079637050628662109375 * _707;
            _720 = (sin(_713) / _713) * (sin(_716) / _716);
        }
        float _723 = precise::min(abs(2.0 - _672), 2.0);
        float _736;
        if (abs(_723) < 6.099999882280826568603515625e-05)
        {
            _736 = 1.0;
        }
        else
        {
            float _729 = 3.1415927410125732421875 * _723;
            float _732 = 1.57079637050628662109375 * _723;
            _736 = (sin(_729) / _729) * (sin(_732) / _732);
        }
        float4 _741 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_250.x, _252)), max(1, min(_250.y, _256))))), 0u) * _443) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_263.x, _252)), max(1, min(_263.y, _256))))), 0u) * _459)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_274.x, _252)), max(1, min(_274.y, _256))))), 0u) * _475)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_285.x, _252)), max(1, min(_285.y, _256))))), 0u) * _491)) / float4(((_443 + _459) + _475) + _491)) * _688) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_296.x, _252)), max(1, min(_296.y, _256))))), 0u) * _514) + (_316 * _525)) + (_327 * _536)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_328.x, _252)), max(1, min(_328.y, _256))))), 0u) * _547)) / float4(((_514 + _525) + _536) + _547)) * _704)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_339.x, _252)), max(1, min(_339.y, _256))))), 0u) * _570) + (_360 * _581)) + (_371 * _592)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_372.x, _252)), max(1, min(_372.y, _256))))), 0u) * _603)) / float4(((_570 + _581) + _592) + _603)) * _720);
        float4 _755 = fast::clamp((_741 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_383.x, _252)), max(1, min(_383.y, _256))))), 0u) * _626) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_394.x, _252)), max(1, min(_394.y, _256))))), 0u) * _637)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_405.x, _252)), max(1, min(_405.y, _256))))), 0u) * _648)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_416.x, _252)), max(1, min(_416.y, _256))))), 0u) * _659)) / float4(((_626 + _637) + _648) + _659)) * _736)) / float4(((_688 + _704) + _720) + _736), precise::min(precise::min(precise::min(_316, _327), _360), _371), precise::max(precise::max(precise::max(_316, _327), _360), _371));
        float4 _761 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _762 = _761.x;
        float3 _765 = (_755.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_762 == 0.0) ? 1.0 : _762);
        float _766 = _765.x;
        float _769 = 0.5 * _765.y;
        float _771 = _765.z;
        float _772 = 0.25 * _771;
        _781 = float3(((0.25 * _766) + _769) + _772, 0.5 * (_766 - _771), (((-0.25) * _766) + _769) - _772);
        _782 = _755.w;
    }
    else
    {
        _781 = float3(0.0);
        _782 = 0.0;
    }
    float _788 = precise::max(fast::clamp(_214, 0.0, 1.0), precise::max(_210, _212));
    float _791 = precise::max(0.0, (_782 * float(!_204)) - (_788 * 2.0));
    uint2 _795 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _812 = _131 - _152;
    float _813 = _812.x;
    bool _818;
    if (_813 >= 0.0)
    {
        _818 = _813 <= 1.0;
    }
    else
    {
        _818 = false;
    }
    bool _827;
    if (_818)
    {
        float _821 = _812.y;
        bool _826;
        if (_821 >= 0.0)
        {
            _826 = _821 <= 1.0;
        }
        else
        {
            _826 = false;
        }
        _827 = _826;
    }
    else
    {
        _827 = false;
    }
    float _837 = precise::min(_221, mix(_221, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_154 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _840 = _127 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _842 = int2(floor(_840));
    float2 _845 = (float2(_842) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _846 = _845 - _840;
    bool _849 = _845.x > _840.x;
    bool _853 = _845.y > _840.y;
    int2 _855 = int2(_849 ? (-2) : (-1), _853 ? (-2) : (-1));
    float2 _856 = float2(_855);
    bool _857 = _221 == 0.0;
    int _858 = _849 ? 3 : 0;
    int _859 = _853 ? 3 : 0;
    int2 _860 = int2(_858, _859);
    int2 _861 = _842 + _855;
    int2 _862 = _861 + _860;
    int _865 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _870 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _880 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _881 = _880.x;
    float3 _884 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_862.x, _865)), max(0, min(_862.y, _870))))), 0u).xyz) * ((_881 == 0.0) ? 1.0 : _881);
    float _885 = _884.x;
    float _888 = 0.5 * _884.y;
    float _890 = _884.z;
    float _891 = 0.25 * _890;
    spvUnsafeArray<float3, 9> _123;
    _123[0] = float3(((0.25 * _885) + _888) + _891, 0.5 * (_885 - _890), (((-0.25) * _885) + _888) - _891);
    int _900 = _849 ? 2 : 1;
    int2 _901 = int2(_900, _859);
    int2 _902 = _861 + _901;
    float4 _916 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _917 = _916.x;
    float3 _920 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_902.x, _865)), max(0, min(_902.y, _870))))), 0u).xyz) * ((_917 == 0.0) ? 1.0 : _917);
    float _921 = _920.x;
    float _924 = 0.5 * _920.y;
    float _926 = _920.z;
    float _927 = 0.25 * _926;
    _123[1] = float3(((0.25 * _921) + _924) + _927, 0.5 * (_921 - _926), (((-0.25) * _921) + _924) - _927);
    int _936 = _849 ? 1 : 2;
    int2 _937 = int2(_936, _859);
    int2 _938 = _861 + _937;
    float4 _952 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _953 = _952.x;
    float3 _956 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_938.x, _865)), max(0, min(_938.y, _870))))), 0u).xyz) * ((_953 == 0.0) ? 1.0 : _953);
    float _957 = _956.x;
    float _960 = 0.5 * _956.y;
    float _962 = _956.z;
    float _963 = 0.25 * _962;
    _123[2] = float3(((0.25 * _957) + _960) + _963, 0.5 * (_957 - _962), (((-0.25) * _957) + _960) - _963);
    int _972 = _853 ? 2 : 1;
    int2 _973 = int2(_858, _972);
    int2 _974 = _861 + _973;
    float4 _988 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _989 = _988.x;
    float3 _992 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_974.x, _865)), max(0, min(_974.y, _870))))), 0u).xyz) * ((_989 == 0.0) ? 1.0 : _989);
    float _993 = _992.x;
    float _996 = 0.5 * _992.y;
    float _998 = _992.z;
    float _999 = 0.25 * _998;
    _123[3] = float3(((0.25 * _993) + _996) + _999, 0.5 * (_993 - _998), (((-0.25) * _993) + _996) - _999);
    int2 _1008 = int2(_900, _972);
    int2 _1009 = _861 + _1008;
    float4 _1023 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1024 = _1023.x;
    float3 _1027 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1009.x, _865)), max(0, min(_1009.y, _870))))), 0u).xyz) * ((_1024 == 0.0) ? 1.0 : _1024);
    float _1028 = _1027.x;
    float _1031 = 0.5 * _1027.y;
    float _1033 = _1027.z;
    float _1034 = 0.25 * _1033;
    _123[4] = float3(((0.25 * _1028) + _1031) + _1034, 0.5 * (_1028 - _1033), (((-0.25) * _1028) + _1031) - _1034);
    int2 _1043 = int2(_936, _972);
    int2 _1044 = _861 + _1043;
    float4 _1058 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1059 = _1058.x;
    float3 _1062 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1044.x, _865)), max(0, min(_1044.y, _870))))), 0u).xyz) * ((_1059 == 0.0) ? 1.0 : _1059);
    float _1063 = _1062.x;
    float _1066 = 0.5 * _1062.y;
    float _1068 = _1062.z;
    float _1069 = 0.25 * _1068;
    _123[5] = float3(((0.25 * _1063) + _1066) + _1069, 0.5 * (_1063 - _1068), (((-0.25) * _1063) + _1066) - _1069);
    int _1078 = _853 ? 1 : 2;
    int2 _1079 = int2(_858, _1078);
    int2 _1080 = _861 + _1079;
    float4 _1094 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1095 = _1094.x;
    float3 _1098 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1080.x, _865)), max(0, min(_1080.y, _870))))), 0u).xyz) * ((_1095 == 0.0) ? 1.0 : _1095);
    float _1099 = _1098.x;
    float _1102 = 0.5 * _1098.y;
    float _1104 = _1098.z;
    float _1105 = 0.25 * _1104;
    _123[6] = float3(((0.25 * _1099) + _1102) + _1105, 0.5 * (_1099 - _1104), (((-0.25) * _1099) + _1102) - _1105);
    int2 _1114 = int2(_900, _1078);
    int2 _1115 = _861 + _1114;
    float4 _1129 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1130 = _1129.x;
    float3 _1133 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1115.x, _865)), max(0, min(_1115.y, _870))))), 0u).xyz) * ((_1130 == 0.0) ? 1.0 : _1130);
    float _1134 = _1133.x;
    float _1137 = 0.5 * _1133.y;
    float _1139 = _1133.z;
    float _1140 = 0.25 * _1139;
    _123[7] = float3(((0.25 * _1134) + _1137) + _1140, 0.5 * (_1134 - _1139), (((-0.25) * _1134) + _1137) - _1140);
    int2 _1149 = int2(_936, _1078);
    int2 _1150 = _861 + _1149;
    float4 _1164 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1165 = _1164.x;
    float3 _1168 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1150.x, _865)), max(0, min(_1150.y, _870))))), 0u).xyz) * ((_1165 == 0.0) ? 1.0 : _1165);
    float _1169 = _1168.x;
    float _1172 = 0.5 * _1168.y;
    float _1174 = _1168.z;
    float _1175 = 0.25 * _1174;
    _123[8] = float3(((0.25 * _1169) + _1172) + _1175, 0.5 * (_1169 - _1174), (((-0.25) * _1169) + _1172) - _1175);
    if (_857)
    {
        for (int _1187 = 0; _1187 < 9; )
        {
            float _1198 = (_123[_1187].x + _123[_1187].y) - _123[_1187].z;
            float _1199 = _123[_1187].x + _123[_1187].z;
            float _1201 = (_123[_1187].x - _123[_1187].y) - _123[_1187].z;
            float3 _1208 = float3(_1198, _1199, _1201) / float3(precise::max(precise::max(0.0, _1198), precise::max(_1199, _1201)) + 1.0);
            float _1209 = _1208.x;
            float _1212 = 0.5 * _1208.y;
            float _1214 = _1208.z;
            float _1215 = 0.25 * _1214;
            _123[_1187] = float3(((0.25 * _1209) + _1212) + _1215, 0.5 * (_1209 - _1214), (((-0.25) * _1209) + _1212) - _1215);
            _1187++;
            continue;
        }
    }
    float _1227 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1238 = mix(precise::max(1.0, (1.0 + _1227) * 0.300000011920928955078125), _1227, precise::min(1.0 - (_212 * 0.5), precise::min(1.0 - _214, fast::clamp(_837 * 5.0, 0.0, 1.0))));
    float2 _1241 = _846 + (_856 + float2(_860));
    uint2 _1243 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1246 = float(all(uint2(_862) < _1243));
    bool _1247 = !_857;
    float _1266;
    float3 _1267;
    if (_1247)
    {
        float2 _1251 = _1241 * float2(_1238);
        float _1253 = precise::min(dot(_1251, _1251), 4.0);
        float _1255 = (0.4000000059604644775390625 * _1253) - 1.0;
        float _1257 = (0.25 * _1253) - 1.0;
        float _1263 = _1246 * ((((1.5625 * _1255) * _1255) - 0.5625) * (_1257 * _1257));
        _1266 = _1263;
        _1267 = _123[0] * _1263;
    }
    else
    {
        _1266 = 0.0;
        _1267 = float3(0.0);
    }
    float _1271 = exp((-2.2999999523162841796875) * dot(_1241, _1241)) * _1246;
    float3 _1273 = _123[0] * _1271;
    float2 _1277 = _846 + (_856 + float2(_901));
    float _1281 = float(all(uint2(_902) < _1243));
    float _1302;
    float3 _1303;
    if (_1247)
    {
        float2 _1285 = _1277 * float2(_1238);
        float _1287 = precise::min(dot(_1285, _1285), 4.0);
        float _1289 = (0.4000000059604644775390625 * _1287) - 1.0;
        float _1291 = (0.25 * _1287) - 1.0;
        float _1297 = _1281 * ((((1.5625 * _1289) * _1289) - 0.5625) * (_1291 * _1291));
        _1302 = _1266 + _1297;
        _1303 = _1267 + (_123[1] * _1297);
    }
    else
    {
        _1302 = _1266;
        _1303 = _1267;
    }
    float _1307 = exp((-2.2999999523162841796875) * dot(_1277, _1277)) * _1281;
    float3 _1311 = _123[1] * _1307;
    float2 _1318 = _846 + (_856 + float2(_937));
    float _1322 = float(all(uint2(_938) < _1243));
    float _1343;
    float3 _1344;
    if (_1247)
    {
        float2 _1326 = _1318 * float2(_1238);
        float _1328 = precise::min(dot(_1326, _1326), 4.0);
        float _1330 = (0.4000000059604644775390625 * _1328) - 1.0;
        float _1332 = (0.25 * _1328) - 1.0;
        float _1338 = _1322 * ((((1.5625 * _1330) * _1330) - 0.5625) * (_1332 * _1332));
        _1343 = _1302 + _1338;
        _1344 = _1303 + (_123[2] * _1338);
    }
    else
    {
        _1343 = _1302;
        _1344 = _1303;
    }
    float _1348 = exp((-2.2999999523162841796875) * dot(_1318, _1318)) * _1322;
    float3 _1352 = _123[2] * _1348;
    float2 _1359 = _846 + (_856 + float2(_973));
    float _1363 = float(all(uint2(_974) < _1243));
    float _1384;
    float3 _1385;
    if (_1247)
    {
        float2 _1367 = _1359 * float2(_1238);
        float _1369 = precise::min(dot(_1367, _1367), 4.0);
        float _1371 = (0.4000000059604644775390625 * _1369) - 1.0;
        float _1373 = (0.25 * _1369) - 1.0;
        float _1379 = _1363 * ((((1.5625 * _1371) * _1371) - 0.5625) * (_1373 * _1373));
        _1384 = _1343 + _1379;
        _1385 = _1344 + (_123[3] * _1379);
    }
    else
    {
        _1384 = _1343;
        _1385 = _1344;
    }
    float _1389 = exp((-2.2999999523162841796875) * dot(_1359, _1359)) * _1363;
    float3 _1393 = _123[3] * _1389;
    float2 _1400 = _846 + (_856 + float2(_1008));
    float _1404 = float(all(uint2(_1009) < _1243));
    float _1425;
    float3 _1426;
    if (_1247)
    {
        float2 _1408 = _1400 * float2(_1238);
        float _1410 = precise::min(dot(_1408, _1408), 4.0);
        float _1412 = (0.4000000059604644775390625 * _1410) - 1.0;
        float _1414 = (0.25 * _1410) - 1.0;
        float _1420 = _1404 * ((((1.5625 * _1412) * _1412) - 0.5625) * (_1414 * _1414));
        _1425 = _1384 + _1420;
        _1426 = _1385 + (_123[4] * _1420);
    }
    else
    {
        _1425 = _1384;
        _1426 = _1385;
    }
    float _1430 = exp((-2.2999999523162841796875) * dot(_1400, _1400)) * _1404;
    float3 _1434 = _123[4] * _1430;
    float2 _1441 = _846 + (_856 + float2(_1043));
    float _1445 = float(all(uint2(_1044) < _1243));
    float _1466;
    float3 _1467;
    if (_1247)
    {
        float2 _1449 = _1441 * float2(_1238);
        float _1451 = precise::min(dot(_1449, _1449), 4.0);
        float _1453 = (0.4000000059604644775390625 * _1451) - 1.0;
        float _1455 = (0.25 * _1451) - 1.0;
        float _1461 = _1445 * ((((1.5625 * _1453) * _1453) - 0.5625) * (_1455 * _1455));
        _1466 = _1425 + _1461;
        _1467 = _1426 + (_123[5] * _1461);
    }
    else
    {
        _1466 = _1425;
        _1467 = _1426;
    }
    float _1471 = exp((-2.2999999523162841796875) * dot(_1441, _1441)) * _1445;
    float3 _1475 = _123[5] * _1471;
    float2 _1482 = _846 + (_856 + float2(_1079));
    float _1486 = float(all(uint2(_1080) < _1243));
    float _1507;
    float3 _1508;
    if (_1247)
    {
        float2 _1490 = _1482 * float2(_1238);
        float _1492 = precise::min(dot(_1490, _1490), 4.0);
        float _1494 = (0.4000000059604644775390625 * _1492) - 1.0;
        float _1496 = (0.25 * _1492) - 1.0;
        float _1502 = _1486 * ((((1.5625 * _1494) * _1494) - 0.5625) * (_1496 * _1496));
        _1507 = _1466 + _1502;
        _1508 = _1467 + (_123[6] * _1502);
    }
    else
    {
        _1507 = _1466;
        _1508 = _1467;
    }
    float _1512 = exp((-2.2999999523162841796875) * dot(_1482, _1482)) * _1486;
    float3 _1516 = _123[6] * _1512;
    float2 _1523 = _846 + (_856 + float2(_1114));
    float _1527 = float(all(uint2(_1115) < _1243));
    float _1548;
    float3 _1549;
    if (_1247)
    {
        float2 _1531 = _1523 * float2(_1238);
        float _1533 = precise::min(dot(_1531, _1531), 4.0);
        float _1535 = (0.4000000059604644775390625 * _1533) - 1.0;
        float _1537 = (0.25 * _1533) - 1.0;
        float _1543 = _1527 * ((((1.5625 * _1535) * _1535) - 0.5625) * (_1537 * _1537));
        _1548 = _1507 + _1543;
        _1549 = _1508 + (_123[7] * _1543);
    }
    else
    {
        _1548 = _1507;
        _1549 = _1508;
    }
    float _1553 = exp((-2.2999999523162841796875) * dot(_1523, _1523)) * _1527;
    float3 _1557 = _123[7] * _1553;
    float2 _1564 = _846 + (_856 + float2(_1149));
    float _1568 = float(all(uint2(_1150) < _1243));
    float _1589;
    float3 _1590;
    if (_1247)
    {
        float2 _1572 = _1564 * float2(_1238);
        float _1574 = precise::min(dot(_1572, _1572), 4.0);
        float _1576 = (0.4000000059604644775390625 * _1574) - 1.0;
        float _1578 = (0.25 * _1574) - 1.0;
        float _1584 = _1568 * ((((1.5625 * _1576) * _1576) - 0.5625) * (_1578 * _1578));
        _1589 = _1548 + _1584;
        _1590 = _1549 + (_123[8] * _1584);
    }
    else
    {
        _1589 = _1548;
        _1590 = _1549;
    }
    float _1594 = exp((-2.2999999523162841796875) * dot(_1564, _1564)) * _1568;
    float3 _1598 = _123[8] * _1594;
    float _1602 = (((((((_1271 + _1307) + _1348) + _1389) + _1430) + _1471) + _1512) + _1553) + _1594;
    float3 _1606 = float3((abs(_1602) > 1.1754943508222875079687365372222e-38) ? _1602 : 1.0);
    float3 _1607 = ((((((((_1273 + _1311) + _1352) + _1393) + _1434) + _1475) + _1516) + _1557) + _1598) / _1606;
    float _1615 = _1589 * float(_1589 > 6.099999882280826568603515625e-05);
    float3 _1623;
    float _1624;
    if (_1615 > 6.099999882280826568603515625e-05)
    {
        _1623 = fast::clamp(_1590 / float3(_1615), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_123[0], _123[1]), _123[2]), _123[3]), _123[4]), _123[5]), _123[6]), _123[7]), _123[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_123[0], _123[1]), _123[2]), _123[3]), _123[4]), _123[5]), _123[6]), _123[7]), _123[8]));
        _1624 = _1615 * 0.04625000059604644775390625;
    }
    else
    {
        _1623 = _1590;
        _1624 = _1615;
    }
    float3 _1656;
    if (_857)
    {
        float _1627 = _1607.x;
        float _1628 = _1607.y;
        float _1630 = _1607.z;
        float _1631 = (_1627 + _1628) - _1630;
        float _1632 = _1627 + _1630;
        float _1634 = (_1627 - _1628) - _1630;
        float3 _1641 = float3(_1631, _1632, _1634) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1631, precise::max(_1632, _1634))));
        float _1642 = _1641.x;
        float _1645 = 0.5 * _1641.y;
        float _1647 = _1641.z;
        float _1648 = 0.25 * _1647;
        _1656 = float3(((0.25 * _1642) + _1645) + _1648, 0.5 * (_1642 - _1647), (((-0.25) * _1642) + _1645) - _1648);
    }
    else
    {
        _1656 = _1623;
    }
    float _1657 = _857 ? 1.0 : _1624;
    float _1658 = _857 ? 0.0 : _837;
    float3 _1672 = (sqrt(abs(((((((((((_123[0] * _1273) + (_123[1] * _1311)) + (_123[2] * _1352)) + (_123[3] * _1393)) + (_123[4] * _1434)) + (_123[5] * _1475)) + (_123[6] * _1516)) + (_123[7] * _1557)) + (_123[8] * _1598)) / _1606) - (_1607 * _1607))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_154 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _187, _187 - float2(0.5))) / float2(int2(int(_181.x), int(_181.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _221, precise::max(powr(_210, 0.5), _214)))));
    float3 _1675 = (_781 - _1607) / precise::max(_1672, float3(1.19299997436428384389728307724e-07));
    float3 _1690;
    if (length(_1675) > 1.0)
    {
        _1690 = mix((fast::normalize(_1675) * _1672) + _1607, _781, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_147, _142)) / _145), level(0.0)).x, fast::clamp(fast::clamp(_791 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _221) * (1.0 - _212), 0.0, 1.0)));
    }
    else
    {
        _1690 = _781;
    }
    float _1700 = (_1656.x + _1656.y) - _1656.z;
    float _1701 = _1656.x + _1656.z;
    float _1703 = (_1656.x - _1656.y) - _1656.z;
    float3 _1710 = float3(_1700, _1701, _1703) / float3(precise::max(precise::max(0.0, _1700), precise::max(_1701, _1703)) + 1.0);
    float _1711 = _1710.x;
    float _1714 = 0.5 * _1710.y;
    float _1716 = _1710.z;
    float _1717 = 0.25 * _1716;
    float _1729 = (_1690.x + _1690.y) - _1690.z;
    float _1730 = _1690.x + _1690.z;
    float _1732 = (_1690.x - _1690.y) - _1690.z;
    float3 _1739 = float3(_1729, _1730, _1732) / float3(precise::max(precise::max(0.0, _1729), precise::max(_1730, _1732)) + 1.0);
    float _1740 = _1739.x;
    float _1743 = 0.5 * _1739.y;
    float _1745 = _1739.z;
    float _1746 = 0.25 * _1745;
    float3 _1757 = mix(float3(((0.25 * _1740) + _1743) + _1746, 0.5 * (_1740 - _1745), (((-0.25) * _1740) + _1743) - _1746), float3(((0.25 * _1711) + _1714) + _1717, 0.5 * (_1711 - _1716), (((-0.25) * _1711) + _1714) - _1717), float3(fast::clamp(_1657 / precise::max(6.099999882280826568603515625e-05, (_1658 * float(_1658 > 6.099999882280826568603515625e-05)) + _1657), 0.0, 1.0)));
    float _1762 = (_1757.x + _1757.y) - _1757.z;
    float _1763 = _1757.x + _1757.z;
    float _1765 = (_1757.x - _1757.y) - _1757.z;
    float4 _1774 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1775 = _1774.x;
    float3 _1780 = precise::max((float3(_1762, _1763, _1765) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1762, precise::max(_1763, _1765))))) / float3((_1775 == 0.0) ? 1.0 : _1775), float3(0.0));
    float _1781 = _1780.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1781, _1780.yz, precise::max(0.0, precise::max(0.0, precise::min(_791 + (sdk_hlsl_load(rw_new_locks, uint2(_795)).x * (1.0 - precise::max(0.0, _210))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _788))) * float(_827)), uint2(_795));
    sdk_hlsl_store(rw_upscaled_output, float4(_1781, _1780.yz, 1.0), uint2(_795));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_795));
}

