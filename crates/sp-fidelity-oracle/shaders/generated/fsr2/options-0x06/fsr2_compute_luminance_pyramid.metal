#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-braces"

#include <metal_stdlib>
#include <simd/simd.h>
#include <metal_atomic>

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

template<typename T>
inline T spvQuadSwap(T value, uint dir)
{
    return quad_shuffle_xor(value, dir + 1);
}

template<>
inline bool spvQuadSwap(bool value, uint dir)
{
    return !!quad_shuffle_xor((ushort)value, dir + 1);
}

template<uint N>
inline vec<bool, N> spvQuadSwap(vec<bool, N> value, uint dir)
{
    return (vec<bool, N>)quad_shuffle_xor((vec<ushort, N>)value, dir + 1);
}

template <typename ImageT>
void spvImageFence(ImageT img) { img.fence(); }

struct type_cbFSR2
{
    int2 iRenderSize;
    int2 iMaxRenderSize;
    int2 iDisplaySize;
    int2 iInputColorResourceDimensions;
    int2 iLumaMipDimensions;
    int iLumaMipLevelToUse;
    int iFrameIndex;
    float4 fDeviceToViewDepth;
    float2 fJitter;
    float2 fMotionVectorScale;
    float2 fDownscaleFactor;
    float2 fMotionVectorJitterCancellation;
    float fPreExposure;
    float fPreviousFramePreExposure;
    float fTanHalfFOV;
    float fJitterSequenceLength;
    float fDeltaTime;
    float fDynamicResChangeFactor;
    float fViewSpaceToMetersFactor;
    float fPadding;
};

struct type_cbSPD
{
    uint mips;
    uint numWorkGroups;
    uint2 workGroupOffset;
    uint2 renderSize;
};

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], constant type_cbSPD& cbSPD [[buffer(1)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float, access::read_write> rw_img_mip_shading_change [[texture(1)]], texture2d<float, access::read_write> rw_img_mip_5 [[texture(2)]], texture2d<float, access::read_write> rw_auto_exposure [[texture(3)]], texture2d<uint, access::read_write> rw_spd_global_atomic [[texture(4)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup uint spdCounter;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateR;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateG;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateB;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateA;
    uint2 _122 = gl_WorkGroupID.xy + cbSPD.workGroupOffset;
    do
    {
        uint _146;
        int _147;
        uint _148;
        int _149;
        int2 _150;
        int2 _156;
        uint _259;
        uint _269;
        uint _125 = gl_LocalInvocationIndex % 64u;
        uint _138 = ((_125 & 1u) | ((_125 >> 2u) & 6u)) + (8u * ((gl_LocalInvocationIndex >> 6u) % 2u));
        uint _141 = (((_125 >> 1u) & 3u) | ((_125 >> 3u) & 4u)) + (8u * (gl_LocalInvocationIndex >> 7u));
        do
        {
            int2 _145 = int2(_122 * uint2(64u));
            _146 = _138 * 2u;
            _147 = int(_146);
            _148 = _141 * 2u;
            _149 = int(_148);
            _150 = int2(_147, _149);
            int2 _151 = _145 + _150;
            int2 _153 = int2(_122 * uint2(32u));
            int _154 = int(_138);
            int _155 = int(_141);
            _156 = int2(_154, _155);
            int2 _157 = _153 + _156;
            uint2 _158 = uint2(_151);
            float2 _162 = float2(_151);
            float2 _169 = float2(cbFSR2.iRenderSize);
            float2 _172 = _169 - float2(0.5);
            float2 _175 = float2(cbFSR2.iInputColorResourceDimensions);
            float3 _184 = float3(cbFSR2.fPreExposure);
            float2 _194 = float2(int2(_158 + uint2(0u, 1u)));
            float2 _214 = float2(int2(_158 + uint2(1u, 0u)));
            float2 _234 = float2(int2(_158 + uint2(1u)));
            float4 _256 = (((float4(all(_162 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_162 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0) + float4(all(_194 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_194 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_214 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_214 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_234 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_234 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) * 0.25;
            _259 = uint(cbFSR2.iLumaMipLevelToUse);
            bool _261 = 0u == _259;
            if (_261)
            {
                uint2 _264 = uint2(_157);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_264)).x), uint2(_264));
            }
            _269 = cbSPD.mips - 1u;
            bool _270 = 0u == _269;
            if (_270)
            {
                if (all(_157 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _278 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _279 = _278.y;
                    float _280 = _256.x;
                    float _292;
                    if (_279 < 100000000.0)
                    {
                        _292 = _279 + ((_280 - _279) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _292 = _280;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_292) * 8.0)), _292).xyyy, uint2(uint2(0u)));
                }
            }
            int _301 = int(_146 + 32u);
            int2 _303 = _145 + int2(_301, _149);
            int _305 = int(_138 + 16u);
            int2 _307 = _153 + int2(_305, _155);
            uint2 _308 = uint2(_303);
            float2 _312 = float2(_303);
            float2 _332 = float2(int2(_308 + uint2(0u, 1u)));
            float2 _352 = float2(int2(_308 + uint2(1u, 0u)));
            float2 _372 = float2(int2(_308 + uint2(1u)));
            float4 _394 = (((float4(all(_312 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_312 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0) + float4(all(_332 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_332 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_352 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_352 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_372 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_372 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) * 0.25;
            if (_261)
            {
                uint2 _397 = uint2(_307);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_397)).x), uint2(_397));
            }
            if (_270)
            {
                if (all(_307 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _409 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _410 = _409.y;
                    float _411 = _394.x;
                    float _423;
                    if (_410 < 100000000.0)
                    {
                        _423 = _410 + ((_411 - _410) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _423 = _411;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_423) * 8.0)), _423).xyyy, uint2(uint2(0u)));
                }
            }
            int _432 = int(_148 + 32u);
            int2 _434 = _145 + int2(_147, _432);
            int _436 = int(_141 + 16u);
            int2 _438 = _153 + int2(_154, _436);
            uint2 _439 = uint2(_434);
            float2 _443 = float2(_434);
            float2 _463 = float2(int2(_439 + uint2(0u, 1u)));
            float2 _483 = float2(int2(_439 + uint2(1u, 0u)));
            float2 _503 = float2(int2(_439 + uint2(1u)));
            float4 _525 = (((float4(all(_443 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_443 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0) + float4(all(_463 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_463 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_483 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_483 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_503 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_503 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) * 0.25;
            if (_261)
            {
                uint2 _528 = uint2(_438);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_528)).x), uint2(_528));
            }
            if (_270)
            {
                if (all(_438 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _540 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _541 = _540.y;
                    float _542 = _525.x;
                    float _554;
                    if (_541 < 100000000.0)
                    {
                        _554 = _541 + ((_542 - _541) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _554 = _542;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_554) * 8.0)), _554).xyyy, uint2(uint2(0u)));
                }
            }
            int2 _563 = _145 + int2(_301, _432);
            int2 _565 = _153 + int2(_305, _436);
            uint2 _566 = uint2(_563);
            float2 _570 = float2(_563);
            float2 _590 = float2(int2(_566 + uint2(0u, 1u)));
            float2 _610 = float2(int2(_566 + uint2(1u, 0u)));
            float2 _630 = float2(int2(_566 + uint2(1u)));
            float4 _652 = (((float4(all(_570 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_570 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0) + float4(all(_590 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_590 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_610 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_610 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) + float4(all(_630 < _169) ? log(precise::max(0.001000000047497451305389404296875, dot(r_input_color_jittered.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_630 + float2(0.5)) + cbFSR2.fJitter, _172)) / _175), level(0.0)).xyz / _184, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875)))) : 0.0, 0.0, 0.0, 0.0)) * 0.25;
            if (_261)
            {
                uint2 _655 = uint2(_565);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_655)).x), uint2(_655));
            }
            if (_270)
            {
                if (all(_565 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _667 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _668 = _667.y;
                    float _669 = _652.x;
                    float _681;
                    if (_668 < 100000000.0)
                    {
                        _681 = _668 + ((_669 - _668) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _681 = _669;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_681) * 8.0)), _681).xyyy, uint2(uint2(0u)));
                }
            }
            if (cbSPD.mips <= 1u)
            {
                break;
            }
            float4 _692 = spvQuadSwap(_256, 0u);
            float4 _693 = spvQuadSwap(_256, 1u);
            float4 _694 = spvQuadSwap(_256, 2u);
            float4 _698 = (((_256 + _692) + _693) + _694) * 0.25;
            float4 _699 = spvQuadSwap(_394, 0u);
            float4 _700 = spvQuadSwap(_394, 1u);
            float4 _701 = spvQuadSwap(_394, 2u);
            float4 _705 = (((_394 + _699) + _700) + _701) * 0.25;
            float4 _706 = spvQuadSwap(_525, 0u);
            float4 _707 = spvQuadSwap(_525, 1u);
            float4 _708 = spvQuadSwap(_525, 2u);
            float4 _712 = (((_525 + _706) + _707) + _708) * 0.25;
            float4 _713 = spvQuadSwap(_652, 0u);
            float4 _714 = spvQuadSwap(_652, 1u);
            float4 _715 = spvQuadSwap(_652, 2u);
            float4 _719 = (((_652 + _713) + _714) + _715) * 0.25;
            if ((gl_LocalInvocationIndex % 4u) == 0u)
            {
                int2 _725 = int2(_122 * uint2(16u));
                uint _726 = _138 / 2u;
                int _727 = int(_726);
                uint _728 = _141 / 2u;
                int _729 = int(_728);
                int2 _731 = _725 + int2(_727, _729);
                bool _733 = 1u == _259;
                if (_733)
                {
                    uint2 _736 = uint2(_731);
                    spvImageFence(rw_img_mip_shading_change);
                    sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_736)).x), uint2(_736));
                }
                bool _741 = 1u == _269;
                if (_741)
                {
                    if (all(_731 == int2(0)))
                    {
                        spvImageFence(rw_auto_exposure);
                        float4 _749 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                        float _750 = _749.y;
                        float _751 = _698.x;
                        float _763;
                        if (_750 < 100000000.0)
                        {
                            _763 = _750 + ((_751 - _750) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                        }
                        else
                        {
                            _763 = _751;
                        }
                        sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_763) * 8.0)), _763).xyyy, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_726][_728] = _698.x;
                spdIntermediateG[_726][_728] = _698.y;
                spdIntermediateB[_726][_728] = _698.z;
                spdIntermediateA[_726][_728] = _698.w;
                uint _779 = _726 + 8u;
                int _780 = int(_779);
                int2 _782 = _725 + int2(_780, _729);
                if (_733)
                {
                    uint2 _785 = uint2(_782);
                    spvImageFence(rw_img_mip_shading_change);
                    sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_785)).x), uint2(_785));
                }
                if (_741)
                {
                    if (all(_782 == int2(0)))
                    {
                        spvImageFence(rw_auto_exposure);
                        float4 _797 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                        float _798 = _797.y;
                        float _799 = _705.x;
                        float _811;
                        if (_798 < 100000000.0)
                        {
                            _811 = _798 + ((_799 - _798) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                        }
                        else
                        {
                            _811 = _799;
                        }
                        sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_811) * 8.0)), _811).xyyy, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_779][_728] = _705.x;
                spdIntermediateG[_779][_728] = _705.y;
                spdIntermediateB[_779][_728] = _705.z;
                spdIntermediateA[_779][_728] = _705.w;
                uint _827 = _728 + 8u;
                int _828 = int(_827);
                int2 _830 = _725 + int2(_727, _828);
                if (_733)
                {
                    uint2 _833 = uint2(_830);
                    spvImageFence(rw_img_mip_shading_change);
                    sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_833)).x), uint2(_833));
                }
                if (_741)
                {
                    if (all(_830 == int2(0)))
                    {
                        spvImageFence(rw_auto_exposure);
                        float4 _845 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                        float _846 = _845.y;
                        float _847 = _712.x;
                        float _859;
                        if (_846 < 100000000.0)
                        {
                            _859 = _846 + ((_847 - _846) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                        }
                        else
                        {
                            _859 = _847;
                        }
                        sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_859) * 8.0)), _859).xyyy, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_726][_827] = _712.x;
                spdIntermediateG[_726][_827] = _712.y;
                spdIntermediateB[_726][_827] = _712.z;
                spdIntermediateA[_726][_827] = _712.w;
                int2 _876 = _725 + int2(_780, _828);
                if (_733)
                {
                    uint2 _879 = uint2(_876);
                    spvImageFence(rw_img_mip_shading_change);
                    sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_879)).x), uint2(_879));
                }
                if (_741)
                {
                    if (all(_876 == int2(0)))
                    {
                        spvImageFence(rw_auto_exposure);
                        float4 _891 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                        float _892 = _891.y;
                        float _893 = _719.x;
                        float _905;
                        if (_892 < 100000000.0)
                        {
                            _905 = _892 + ((_893 - _892) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                        }
                        else
                        {
                            _905 = _893;
                        }
                        sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_905) * 8.0)), _905).xyyy, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_779][_827] = _719.x;
                spdIntermediateG[_779][_827] = _719.y;
                spdIntermediateB[_779][_827] = _719.z;
                spdIntermediateA[_779][_827] = _719.w;
            }
            break;
        } while(false);
        do
        {
            if (cbSPD.mips <= 2u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float _927 = spdIntermediateR[_138][_141];
            float _929 = spdIntermediateG[_138][_141];
            float _931 = spdIntermediateB[_138][_141];
            float4 _934 = float4(_927, _929, _931, spdIntermediateA[_138][_141]);
            float4 _935 = spvQuadSwap(_934, 0u);
            float4 _936 = spvQuadSwap(_934, 1u);
            float4 _937 = spvQuadSwap(_934, 2u);
            float4 _941 = (((_934 + _935) + _936) + _937) * 0.25;
            bool _943 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_943)
            {
                uint _950 = _141 / 2u;
                int2 _953 = int2(_122 * uint2(8u)) + int2(int(_138 / 2u), int(_950));
                if (2u == _259)
                {
                    uint2 _958 = uint2(_953);
                    spvImageFence(rw_img_mip_shading_change);
                    sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_958)).x), uint2(_958));
                }
                if (2u == _269)
                {
                    if (all(_953 == int2(0)))
                    {
                        spvImageFence(rw_auto_exposure);
                        float4 _971 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                        float _972 = _971.y;
                        float _973 = _941.x;
                        float _985;
                        if (_972 < 100000000.0)
                        {
                            _985 = _972 + ((_973 - _972) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                        }
                        else
                        {
                            _985 = _973;
                        }
                        sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_985) * 8.0)), _985).xyyy, uint2(uint2(0u)));
                    }
                }
                uint _994 = _138 + (_950 % 2u);
                spdIntermediateR[_994][_141] = _941.x;
                spdIntermediateG[_994][_141] = _941.y;
                spdIntermediateB[_994][_141] = _941.z;
                spdIntermediateA[_994][_141] = _941.w;
            }
            if (cbSPD.mips <= 3u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _1010 = _146 + (_141 % 2u);
                float _1012 = spdIntermediateR[_1010][_148];
                float _1014 = spdIntermediateG[_1010][_148];
                float _1016 = spdIntermediateB[_1010][_148];
                float4 _1019 = float4(_1012, _1014, _1016, spdIntermediateA[_1010][_148]);
                float4 _1020 = spvQuadSwap(_1019, 0u);
                float4 _1021 = spvQuadSwap(_1019, 1u);
                float4 _1022 = spvQuadSwap(_1019, 2u);
                float4 _1026 = (((_1019 + _1020) + _1021) + _1022) * 0.25;
                if (_943)
                {
                    uint _1033 = _141 / 2u;
                    int2 _1036 = int2(_122 * uint2(4u)) + int2(int(_138 / 2u), int(_1033));
                    if (3u == _259)
                    {
                        uint2 _1041 = uint2(_1036);
                        spvImageFence(rw_img_mip_shading_change);
                        sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1041)).x), uint2(_1041));
                    }
                    if (3u == _269)
                    {
                        if (all(_1036 == int2(0)))
                        {
                            spvImageFence(rw_auto_exposure);
                            float4 _1054 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                            float _1055 = _1054.y;
                            float _1056 = _1026.x;
                            float _1068;
                            if (_1055 < 100000000.0)
                            {
                                _1068 = _1055 + ((_1056 - _1055) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                            }
                            else
                            {
                                _1068 = _1056;
                            }
                            sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1068) * 8.0)), _1068).xyyy, uint2(uint2(0u)));
                        }
                    }
                    uint _1076 = _146 + _1033;
                    spdIntermediateR[_1076][_148] = _1026.x;
                    spdIntermediateG[_1076][_148] = _1026.y;
                    spdIntermediateB[_1076][_148] = _1026.z;
                    spdIntermediateA[_1076][_148] = _1026.w;
                }
            }
            if (cbSPD.mips <= 4u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1092 = (_138 * 4u) + _141;
                uint _1093 = _141 * 4u;
                float _1095 = spdIntermediateR[_1092][_1093];
                float _1097 = spdIntermediateG[_1092][_1093];
                float _1099 = spdIntermediateB[_1092][_1093];
                float4 _1102 = float4(_1095, _1097, _1099, spdIntermediateA[_1092][_1093]);
                float4 _1103 = spvQuadSwap(_1102, 0u);
                float4 _1104 = spvQuadSwap(_1102, 1u);
                float4 _1105 = spvQuadSwap(_1102, 2u);
                float4 _1109 = (((_1102 + _1103) + _1104) + _1105) * 0.25;
                if (_943)
                {
                    uint _1114 = _138 / 2u;
                    int2 _1119 = int2(_122 * uint2(2u)) + int2(int(_1114), int(_141 / 2u));
                    if (4u == _259)
                    {
                        sdk_hlsl_store(rw_img_mip_shading_change, float4(_1109.x), uint2(uint2(_1119)));
                    }
                    if (4u == _269)
                    {
                        if (all(_1119 == int2(0)))
                        {
                            spvImageFence(rw_auto_exposure);
                            float4 _1135 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                            float _1136 = _1135.y;
                            float _1137 = _1109.x;
                            float _1149;
                            if (_1136 < 100000000.0)
                            {
                                _1149 = _1136 + ((_1137 - _1136) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                            }
                            else
                            {
                                _1149 = _1137;
                            }
                            sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1149) * 8.0)), _1149).xyyy, uint2(uint2(0u)));
                        }
                    }
                    uint _1157 = _1114 + _141;
                    spdIntermediateR[_1157][0u] = _1109.x;
                    spdIntermediateG[_1157][0u] = _1109.y;
                    spdIntermediateB[_1157][0u] = _1109.z;
                    spdIntermediateA[_1157][0u] = _1109.w;
                }
            }
            if (cbSPD.mips <= 5u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1180 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1181 = spvQuadSwap(_1180, 0u);
                float4 _1182 = spvQuadSwap(_1180, 1u);
                float4 _1183 = spvQuadSwap(_1180, 2u);
                float4 _1187 = (((_1180 + _1181) + _1182) + _1183) * 0.25;
                if (_943)
                {
                    float _1191 = _1187.x;
                    sdk_hlsl_store(rw_img_mip_5, float4(_1191), uint2(_122));
                    if (5u == _269)
                    {
                        if (all(int2(_122) == int2(0)))
                        {
                            spvImageFence(rw_auto_exposure);
                            float4 _1201 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                            float _1202 = _1201.y;
                            float _1214;
                            if (_1202 < 100000000.0)
                            {
                                _1214 = _1202 + ((_1191 - _1202) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                            }
                            else
                            {
                                _1214 = _1191;
                            }
                            sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1214) * 8.0)), _1214).xyyy, uint2(uint2(0u)));
                        }
                    }
                }
            }
            break;
        } while(false);
        if (cbSPD.mips <= 6u)
        {
            break;
        }
        if (gl_LocalInvocationIndex == 0u)
        {
            uint _1229 = rw_spd_global_atomic.atomic_fetch_add(uint2(0u), 1u).x;
            spdCounter = _1229;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (spdCounter != (cbSPD.numWorkGroups - 1u))
        {
            break;
        }
        uint _1238;
        uint _1240;
        sdk_hlsl_store(rw_spd_global_atomic, uint4(0u), uint2(uint2(0u)));
        do
        {
            _1238 = _138 * 4u;
            int _1239 = int(_1238);
            _1240 = _141 * 4u;
            int _1241 = int(_1240);
            uint2 _1243 = uint2(int2(_1239, _1241));
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            float4 _1266 = (((float4(sdk_hlsl_load(rw_img_mip_5, uint2(_1243)).x, 0.0, 0.0, 0.0) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1243 + uint2(0u, 1u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1243 + uint2(1u, 0u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1243 + uint2(1u)))).x, 0.0, 0.0, 0.0)) * 0.25;
            bool _1268 = 6u == _259;
            if (_1268)
            {
                uint2 _1271 = uint2(_150);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1271)).x), uint2(_1271));
            }
            bool _1276 = 6u == _269;
            if (_1276)
            {
                if (all(_150 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _1284 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _1285 = _1284.y;
                    float _1286 = _1266.x;
                    float _1298;
                    if (_1285 < 100000000.0)
                    {
                        _1298 = _1285 + ((_1286 - _1285) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _1298 = _1286;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1298) * 8.0)), _1298).xyyy, uint2(uint2(0u)));
                }
            }
            int _1307 = int(_1238 + 2u);
            int _1310 = int(_146 + 1u);
            int2 _1311 = int2(_1310, _149);
            uint2 _1312 = uint2(int2(_1307, _1241));
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            float4 _1335 = (((float4(sdk_hlsl_load(rw_img_mip_5, uint2(_1312)).x, 0.0, 0.0, 0.0) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1312 + uint2(0u, 1u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1312 + uint2(1u, 0u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1312 + uint2(1u)))).x, 0.0, 0.0, 0.0)) * 0.25;
            if (_1268)
            {
                uint2 _1338 = uint2(_1311);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1338)).x), uint2(_1338));
            }
            if (_1276)
            {
                if (all(_1311 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _1350 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _1351 = _1350.y;
                    float _1352 = _1335.x;
                    float _1364;
                    if (_1351 < 100000000.0)
                    {
                        _1364 = _1351 + ((_1352 - _1351) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _1364 = _1352;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1364) * 8.0)), _1364).xyyy, uint2(uint2(0u)));
                }
            }
            int _1373 = int(_1240 + 2u);
            int _1376 = int(_148 + 1u);
            int2 _1377 = int2(_147, _1376);
            uint2 _1378 = uint2(int2(_1239, _1373));
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            float4 _1401 = (((float4(sdk_hlsl_load(rw_img_mip_5, uint2(_1378)).x, 0.0, 0.0, 0.0) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1378 + uint2(0u, 1u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1378 + uint2(1u, 0u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1378 + uint2(1u)))).x, 0.0, 0.0, 0.0)) * 0.25;
            if (_1268)
            {
                uint2 _1404 = uint2(_1377);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1404)).x), uint2(_1404));
            }
            if (_1276)
            {
                if (all(_1377 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _1416 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _1417 = _1416.y;
                    float _1418 = _1401.x;
                    float _1430;
                    if (_1417 < 100000000.0)
                    {
                        _1430 = _1417 + ((_1418 - _1417) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _1430 = _1418;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1430) * 8.0)), _1430).xyyy, uint2(uint2(0u)));
                }
            }
            int2 _1439 = int2(_1310, _1376);
            uint2 _1440 = uint2(int2(_1307, _1373));
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            spvImageFence(rw_img_mip_5);
            float4 _1463 = (((float4(sdk_hlsl_load(rw_img_mip_5, uint2(_1440)).x, 0.0, 0.0, 0.0) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1440 + uint2(0u, 1u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1440 + uint2(1u, 0u)))).x, 0.0, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_img_mip_5, uint2((_1440 + uint2(1u)))).x, 0.0, 0.0, 0.0)) * 0.25;
            if (_1268)
            {
                uint2 _1466 = uint2(_1439);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1466)).x), uint2(_1466));
            }
            if (_1276)
            {
                if (all(_1439 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _1478 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _1479 = _1478.y;
                    float _1480 = _1463.x;
                    float _1492;
                    if (_1479 < 100000000.0)
                    {
                        _1492 = _1479 + ((_1480 - _1479) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _1492 = _1480;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1492) * 8.0)), _1492).xyyy, uint2(uint2(0u)));
                }
            }
            if (cbSPD.mips <= 7u)
            {
                break;
            }
            float4 _1506 = (((_1266 + _1335) + _1401) + _1463) * 0.25;
            if (7u == _259)
            {
                uint2 _1511 = uint2(_156);
                spvImageFence(rw_img_mip_shading_change);
                sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1511)).x), uint2(_1511));
            }
            if (7u == _269)
            {
                if (all(_156 == int2(0)))
                {
                    spvImageFence(rw_auto_exposure);
                    float4 _1524 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                    float _1525 = _1524.y;
                    float _1526 = _1506.x;
                    float _1538;
                    if (_1525 < 100000000.0)
                    {
                        _1538 = _1525 + ((_1526 - _1525) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                    }
                    else
                    {
                        _1538 = _1526;
                    }
                    sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1538) * 8.0)), _1538).xyyy, uint2(uint2(0u)));
                }
            }
            spdIntermediateR[_138][_141] = _1506.x;
            spdIntermediateG[_138][_141] = _1506.y;
            spdIntermediateB[_138][_141] = _1506.z;
            spdIntermediateA[_138][_141] = _1506.w;
            break;
        } while(false);
        do
        {
            if (cbSPD.mips <= 8u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float _1560 = spdIntermediateR[_138][_141];
            float _1562 = spdIntermediateG[_138][_141];
            float _1564 = spdIntermediateB[_138][_141];
            float4 _1567 = float4(_1560, _1562, _1564, spdIntermediateA[_138][_141]);
            float4 _1568 = spvQuadSwap(_1567, 0u);
            float4 _1569 = spvQuadSwap(_1567, 1u);
            float4 _1570 = spvQuadSwap(_1567, 2u);
            float4 _1574 = (((_1567 + _1568) + _1569) + _1570) * 0.25;
            bool _1576 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_1576)
            {
                uint _1581 = _141 / 2u;
                int2 _1583 = int2(int(_138 / 2u), int(_1581));
                if (8u == _259)
                {
                    uint2 _1588 = uint2(_1583);
                    spvImageFence(rw_img_mip_shading_change);
                    sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1588)).x), uint2(_1588));
                }
                if (8u == _269)
                {
                    if (all(_1583 == int2(0)))
                    {
                        spvImageFence(rw_auto_exposure);
                        float4 _1601 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                        float _1602 = _1601.y;
                        float _1603 = _1574.x;
                        float _1615;
                        if (_1602 < 100000000.0)
                        {
                            _1615 = _1602 + ((_1603 - _1602) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                        }
                        else
                        {
                            _1615 = _1603;
                        }
                        sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1615) * 8.0)), _1615).xyyy, uint2(uint2(0u)));
                    }
                }
                uint _1624 = _138 + (_1581 % 2u);
                spdIntermediateR[_1624][_141] = _1574.x;
                spdIntermediateG[_1624][_141] = _1574.y;
                spdIntermediateB[_1624][_141] = _1574.z;
                spdIntermediateA[_1624][_141] = _1574.w;
            }
            if (cbSPD.mips <= 9u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _1640 = _146 + (_141 % 2u);
                float _1642 = spdIntermediateR[_1640][_148];
                float _1644 = spdIntermediateG[_1640][_148];
                float _1646 = spdIntermediateB[_1640][_148];
                float4 _1649 = float4(_1642, _1644, _1646, spdIntermediateA[_1640][_148]);
                float4 _1650 = spvQuadSwap(_1649, 0u);
                float4 _1651 = spvQuadSwap(_1649, 1u);
                float4 _1652 = spvQuadSwap(_1649, 2u);
                float4 _1656 = (((_1649 + _1650) + _1651) + _1652) * 0.25;
                if (_1576)
                {
                    uint _1661 = _141 / 2u;
                    int2 _1663 = int2(int(_138 / 2u), int(_1661));
                    if (9u == _259)
                    {
                        uint2 _1668 = uint2(_1663);
                        spvImageFence(rw_img_mip_shading_change);
                        sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1668)).x), uint2(_1668));
                    }
                    if (9u == _269)
                    {
                        if (all(_1663 == int2(0)))
                        {
                            spvImageFence(rw_auto_exposure);
                            float4 _1681 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                            float _1682 = _1681.y;
                            float _1683 = _1656.x;
                            float _1695;
                            if (_1682 < 100000000.0)
                            {
                                _1695 = _1682 + ((_1683 - _1682) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                            }
                            else
                            {
                                _1695 = _1683;
                            }
                            sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1695) * 8.0)), _1695).xyyy, uint2(uint2(0u)));
                        }
                    }
                    uint _1703 = _146 + _1661;
                    spdIntermediateR[_1703][_148] = _1656.x;
                    spdIntermediateG[_1703][_148] = _1656.y;
                    spdIntermediateB[_1703][_148] = _1656.z;
                    spdIntermediateA[_1703][_148] = _1656.w;
                }
            }
            if (cbSPD.mips <= 10u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1718 = _1238 + _141;
                float _1720 = spdIntermediateR[_1718][_1240];
                float _1722 = spdIntermediateG[_1718][_1240];
                float _1724 = spdIntermediateB[_1718][_1240];
                float4 _1727 = float4(_1720, _1722, _1724, spdIntermediateA[_1718][_1240]);
                float4 _1728 = spvQuadSwap(_1727, 0u);
                float4 _1729 = spvQuadSwap(_1727, 1u);
                float4 _1730 = spvQuadSwap(_1727, 2u);
                float4 _1734 = (((_1727 + _1728) + _1729) + _1730) * 0.25;
                if (_1576)
                {
                    uint _1737 = _138 / 2u;
                    int2 _1741 = int2(int(_1737), int(_141 / 2u));
                    if (10u == _259)
                    {
                        uint2 _1746 = uint2(_1741);
                        spvImageFence(rw_img_mip_shading_change);
                        sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(_1746)).x), uint2(_1746));
                    }
                    if (10u == _269)
                    {
                        if (all(_1741 == int2(0)))
                        {
                            spvImageFence(rw_auto_exposure);
                            float4 _1759 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                            float _1760 = _1759.y;
                            float _1761 = _1734.x;
                            float _1773;
                            if (_1760 < 100000000.0)
                            {
                                _1773 = _1760 + ((_1761 - _1760) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                            }
                            else
                            {
                                _1773 = _1761;
                            }
                            sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1773) * 8.0)), _1773).xyyy, uint2(uint2(0u)));
                        }
                    }
                    uint _1781 = _1737 + _141;
                    spdIntermediateR[_1781][0u] = _1734.x;
                    spdIntermediateG[_1781][0u] = _1734.y;
                    spdIntermediateB[_1781][0u] = _1734.z;
                    spdIntermediateA[_1781][0u] = _1734.w;
                }
            }
            if (cbSPD.mips <= 11u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1804 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1805 = spvQuadSwap(_1804, 0u);
                float4 _1806 = spvQuadSwap(_1804, 1u);
                float4 _1807 = spvQuadSwap(_1804, 2u);
                float4 _1811 = (((_1804 + _1805) + _1806) + _1807) * 0.25;
                if (_1576)
                {
                    if (11u == _259)
                    {
                        spvImageFence(rw_img_mip_shading_change);
                        sdk_hlsl_store(rw_img_mip_shading_change, float4(sdk_hlsl_load(rw_img_mip_shading_change, uint2(uint2(0u))).x), uint2(uint2(0u)));
                    }
                    if (11u == _269)
                    {
                        if (all(bool2(true)))
                        {
                            spvImageFence(rw_auto_exposure);
                            float4 _1829 = sdk_hlsl_load(rw_auto_exposure, uint2(uint2(0u)));
                            float _1830 = _1829.y;
                            float _1831 = _1811.x;
                            float _1843;
                            if (_1830 < 100000000.0)
                            {
                                _1843 = _1830 + ((_1831 - _1830) * (1.0 - exp(-cbFSR2.fDeltaTime)));
                            }
                            else
                            {
                                _1843 = _1831;
                            }
                            sdk_hlsl_store(rw_auto_exposure, float2(0.833333313465118408203125 / powr(2.0, log2(exp(_1843) * 8.0)), _1843).xyyy, uint2(uint2(0u)));
                        }
                    }
                }
            }
            break;
        } while(false);
        break;
    } while(false);
}

