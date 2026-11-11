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

struct type_cbFI
{
    int2 renderSize;
    int2 displaySize;
    float2 displaySizeRcp;
    float cameraNear;
    float cameraFar;
    int2 upscalerTargetSize;
    int Mode;
    int reset;
    float4 fDeviceToViewDepth;
    float deltaTime;
    int HUDLessAttachedFactor;
    int2 distortionFieldSize;
    float2 opticalFlowScale;
    int opticalFlowBlockSize;
    uint dispatchFlags;
    int2 maxRenderSize;
    int opticalFlowHalfResMode;
    int NumInstances;
    int2 interpolationRectBase;
    int2 interpolationRectSize;
    packed_float3 debugBarColor;
    uint backBufferTransferFunction;
    float2 minMaxLuminance;
    float fTanHalfFOV;
    int _pad1;
    float2 fJitter;
    float2 fMotionVectorScale;
};

struct type_cbInpaintingPyramid
{
    uint mips;
    uint numWorkGroups;
    uint2 workGroupOffset;
};

struct type_RWStructuredBuffer_uint
{
    uint _m0[1];
};

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], constant type_cbInpaintingPyramid& cbInpaintingPyramid [[buffer(1)]], volatile device type_RWStructuredBuffer_uint& rw_counters [[buffer(2)]], texture2d<uint> r_game_motion_vector_field_x [[texture(0)]], texture2d<uint> r_game_motion_vector_field_y [[texture(1)]], texture2d<float, access::write> rw_inpainting_pyramid0 [[texture(2)]], texture2d<float, access::write> rw_inpainting_pyramid1 [[texture(3)]], texture2d<float, access::write> rw_inpainting_pyramid2 [[texture(4)]], texture2d<float, access::write> rw_inpainting_pyramid3 [[texture(5)]], texture2d<float, access::write> rw_inpainting_pyramid4 [[texture(6)]], texture2d<float, access::read_write> rw_inpainting_pyramid5 [[texture(7)]], texture2d<float, access::write> rw_inpainting_pyramid6 [[texture(8)]], texture2d<float, access::write> rw_inpainting_pyramid7 [[texture(9)]], texture2d<float, access::write> rw_inpainting_pyramid8 [[texture(10)]], texture2d<float, access::write> rw_inpainting_pyramid9 [[texture(11)]], texture2d<float, access::write> rw_inpainting_pyramid10 [[texture(12)]], texture2d<float, access::write> rw_inpainting_pyramid11 [[texture(13)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup uint spdCounter;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateR;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateG;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateB;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateA;
    uint2 _114 = uint2(int3(gl_WorkGroupID).xy) + cbInpaintingPyramid.workGroupOffset;
    do
    {
        uint _138;
        int _139;
        uint _140;
        int _141;
        int2 _142;
        int2 _148;
        uint _117 = gl_LocalInvocationIndex % 64u;
        uint _130 = ((_117 & 1u) | ((_117 >> 2u) & 6u)) + (8u * ((gl_LocalInvocationIndex >> 6u) % 2u));
        uint _133 = (((_117 >> 1u) & 3u) | ((_117 >> 3u) & 4u)) + (8u * (gl_LocalInvocationIndex >> 7u));
        do
        {
            int2 _137 = int2(_114 * uint2(64u));
            _138 = _130 * 2u;
            _139 = int(_138);
            _140 = _133 * 2u;
            _141 = int(_140);
            _142 = int2(_139, _141);
            int2 _145 = int2(_114 * uint2(32u));
            int _146 = int(_130);
            int _147 = int(_133);
            _148 = int2(_146, _147);
            uint2 _150 = uint2(_137 + _142);
            uint2 _151 = _150 + uint2(0u, 1u);
            uint2 _152 = _150 + uint2(1u, 0u);
            uint2 _153 = _150 + uint2(1u);
            uint4 _155 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_150), 0u);
            uint _156 = _155.x;
            float _163 = float((_156 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _173;
            if (_163 > 0.0)
            {
                _173 = (_156 & 2147483648u) == 0u;
            }
            else
            {
                _173 = false;
            }
            float _177;
            if (_173)
            {
                _177 = 1.0 - _163;
            }
            else
            {
                _177 = _163;
            }
            float _189 = float(cbFI.displaySize.x > 0);
            float4 _190 = float4(float2(as_type<half2>(_156 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_150), 0u).x & 65535u)).x, _177, float((_156 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _192 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_151), 0u);
            uint _193 = _192.x;
            float _200 = float((_193 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _210;
            if (_200 > 0.0)
            {
                _210 = (_193 & 2147483648u) == 0u;
            }
            else
            {
                _210 = false;
            }
            float _214;
            if (_210)
            {
                _214 = 1.0 - _200;
            }
            else
            {
                _214 = _200;
            }
            float4 _222 = float4(float2(as_type<half2>(_193 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_151), 0u).x & 65535u)).x, _214, float((_193 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _224 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_152), 0u);
            uint _225 = _224.x;
            float _232 = float((_225 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _242;
            if (_232 > 0.0)
            {
                _242 = (_225 & 2147483648u) == 0u;
            }
            else
            {
                _242 = false;
            }
            float _246;
            if (_242)
            {
                _246 = 1.0 - _232;
            }
            else
            {
                _246 = _232;
            }
            float4 _254 = float4(float2(as_type<half2>(_225 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_152), 0u).x & 65535u)).x, _246, float((_225 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _256 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_153), 0u);
            uint _257 = _256.x;
            float _264 = float((_257 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _274;
            if (_264 > 0.0)
            {
                _274 = (_257 & 2147483648u) == 0u;
            }
            else
            {
                _274 = false;
            }
            float _278;
            if (_274)
            {
                _278 = 1.0 - _264;
            }
            else
            {
                _278 = _264;
            }
            float4 _286 = float4(float2(as_type<half2>(_257 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_153), 0u).x & 65535u)).x, _278, float((_257 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            float _289 = float(_190.z > 0.0);
            float _293 = float(_222.z > 0.0);
            float _299 = float(_254.z > 0.0);
            float _305 = float(_286.z > 0.0);
            float _308 = ((_289 + _293) + _299) + _305;
            float4 _312 = ((((_190 * _289) + (_222 * _293)) + (_254 * _299)) + (_286 * _305)) / float4((_308 > 0.001000000047497451305389404296875) ? _308 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid0, _312, uint2(uint2(_145 + _148)));
            int _316 = int(_138 + 32u);
            int _320 = int(_130 + 16u);
            uint2 _323 = uint2(_137 + int2(_316, _141));
            uint2 _324 = _323 + uint2(0u, 1u);
            uint2 _325 = _323 + uint2(1u, 0u);
            uint2 _326 = _323 + uint2(1u);
            uint4 _328 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_323), 0u);
            uint _329 = _328.x;
            float _336 = float((_329 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _346;
            if (_336 > 0.0)
            {
                _346 = (_329 & 2147483648u) == 0u;
            }
            else
            {
                _346 = false;
            }
            float _350;
            if (_346)
            {
                _350 = 1.0 - _336;
            }
            else
            {
                _350 = _336;
            }
            float4 _358 = float4(float2(as_type<half2>(_329 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_323), 0u).x & 65535u)).x, _350, float((_329 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _360 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_324), 0u);
            uint _361 = _360.x;
            float _368 = float((_361 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _378;
            if (_368 > 0.0)
            {
                _378 = (_361 & 2147483648u) == 0u;
            }
            else
            {
                _378 = false;
            }
            float _382;
            if (_378)
            {
                _382 = 1.0 - _368;
            }
            else
            {
                _382 = _368;
            }
            float4 _390 = float4(float2(as_type<half2>(_361 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_324), 0u).x & 65535u)).x, _382, float((_361 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _392 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_325), 0u);
            uint _393 = _392.x;
            float _400 = float((_393 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _410;
            if (_400 > 0.0)
            {
                _410 = (_393 & 2147483648u) == 0u;
            }
            else
            {
                _410 = false;
            }
            float _414;
            if (_410)
            {
                _414 = 1.0 - _400;
            }
            else
            {
                _414 = _400;
            }
            float4 _422 = float4(float2(as_type<half2>(_393 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_325), 0u).x & 65535u)).x, _414, float((_393 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _424 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_326), 0u);
            uint _425 = _424.x;
            float _432 = float((_425 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _442;
            if (_432 > 0.0)
            {
                _442 = (_425 & 2147483648u) == 0u;
            }
            else
            {
                _442 = false;
            }
            float _446;
            if (_442)
            {
                _446 = 1.0 - _432;
            }
            else
            {
                _446 = _432;
            }
            float4 _454 = float4(float2(as_type<half2>(_425 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_326), 0u).x & 65535u)).x, _446, float((_425 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            float _457 = float(_358.z > 0.0);
            float _461 = float(_390.z > 0.0);
            float _467 = float(_422.z > 0.0);
            float _473 = float(_454.z > 0.0);
            float _476 = ((_457 + _461) + _467) + _473;
            float4 _480 = ((((_358 * _457) + (_390 * _461)) + (_422 * _467)) + (_454 * _473)) / float4((_476 > 0.001000000047497451305389404296875) ? _476 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid0, _480, uint2(uint2(_145 + int2(_320, _147))));
            int _484 = int(_140 + 32u);
            int _488 = int(_133 + 16u);
            uint2 _491 = uint2(_137 + int2(_139, _484));
            uint2 _492 = _491 + uint2(0u, 1u);
            uint2 _493 = _491 + uint2(1u, 0u);
            uint2 _494 = _491 + uint2(1u);
            uint4 _496 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_491), 0u);
            uint _497 = _496.x;
            float _504 = float((_497 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _514;
            if (_504 > 0.0)
            {
                _514 = (_497 & 2147483648u) == 0u;
            }
            else
            {
                _514 = false;
            }
            float _518;
            if (_514)
            {
                _518 = 1.0 - _504;
            }
            else
            {
                _518 = _504;
            }
            float4 _526 = float4(float2(as_type<half2>(_497 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_491), 0u).x & 65535u)).x, _518, float((_497 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _528 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_492), 0u);
            uint _529 = _528.x;
            float _536 = float((_529 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _546;
            if (_536 > 0.0)
            {
                _546 = (_529 & 2147483648u) == 0u;
            }
            else
            {
                _546 = false;
            }
            float _550;
            if (_546)
            {
                _550 = 1.0 - _536;
            }
            else
            {
                _550 = _536;
            }
            float4 _558 = float4(float2(as_type<half2>(_529 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_492), 0u).x & 65535u)).x, _550, float((_529 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _560 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_493), 0u);
            uint _561 = _560.x;
            float _568 = float((_561 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _578;
            if (_568 > 0.0)
            {
                _578 = (_561 & 2147483648u) == 0u;
            }
            else
            {
                _578 = false;
            }
            float _582;
            if (_578)
            {
                _582 = 1.0 - _568;
            }
            else
            {
                _582 = _568;
            }
            float4 _590 = float4(float2(as_type<half2>(_561 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_493), 0u).x & 65535u)).x, _582, float((_561 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _592 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_494), 0u);
            uint _593 = _592.x;
            float _600 = float((_593 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _610;
            if (_600 > 0.0)
            {
                _610 = (_593 & 2147483648u) == 0u;
            }
            else
            {
                _610 = false;
            }
            float _614;
            if (_610)
            {
                _614 = 1.0 - _600;
            }
            else
            {
                _614 = _600;
            }
            float4 _622 = float4(float2(as_type<half2>(_593 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_494), 0u).x & 65535u)).x, _614, float((_593 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            float _625 = float(_526.z > 0.0);
            float _629 = float(_558.z > 0.0);
            float _635 = float(_590.z > 0.0);
            float _641 = float(_622.z > 0.0);
            float _644 = ((_625 + _629) + _635) + _641;
            float4 _648 = ((((_526 * _625) + (_558 * _629)) + (_590 * _635)) + (_622 * _641)) / float4((_644 > 0.001000000047497451305389404296875) ? _644 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid0, _648, uint2(uint2(_145 + int2(_146, _488))));
            uint2 _655 = uint2(_137 + int2(_316, _484));
            uint2 _656 = _655 + uint2(0u, 1u);
            uint2 _657 = _655 + uint2(1u, 0u);
            uint2 _658 = _655 + uint2(1u);
            uint4 _660 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_655), 0u);
            uint _661 = _660.x;
            float _668 = float((_661 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _678;
            if (_668 > 0.0)
            {
                _678 = (_661 & 2147483648u) == 0u;
            }
            else
            {
                _678 = false;
            }
            float _682;
            if (_678)
            {
                _682 = 1.0 - _668;
            }
            else
            {
                _682 = _668;
            }
            float4 _690 = float4(float2(as_type<half2>(_661 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_655), 0u).x & 65535u)).x, _682, float((_661 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _692 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_656), 0u);
            uint _693 = _692.x;
            float _700 = float((_693 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _710;
            if (_700 > 0.0)
            {
                _710 = (_693 & 2147483648u) == 0u;
            }
            else
            {
                _710 = false;
            }
            float _714;
            if (_710)
            {
                _714 = 1.0 - _700;
            }
            else
            {
                _714 = _700;
            }
            float4 _722 = float4(float2(as_type<half2>(_693 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_656), 0u).x & 65535u)).x, _714, float((_693 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _724 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_657), 0u);
            uint _725 = _724.x;
            float _732 = float((_725 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _742;
            if (_732 > 0.0)
            {
                _742 = (_725 & 2147483648u) == 0u;
            }
            else
            {
                _742 = false;
            }
            float _746;
            if (_742)
            {
                _746 = 1.0 - _732;
            }
            else
            {
                _746 = _732;
            }
            float4 _754 = float4(float2(as_type<half2>(_725 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_657), 0u).x & 65535u)).x, _746, float((_725 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            uint4 _756 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_658), 0u);
            uint _757 = _756.x;
            float _764 = float((_757 >> 21u) & 1023u) * 0.000977517105638980865478515625;
            bool _774;
            if (_764 > 0.0)
            {
                _774 = (_757 & 2147483648u) == 0u;
            }
            else
            {
                _774 = false;
            }
            float _778;
            if (_774)
            {
                _778 = 1.0 - _764;
            }
            else
            {
                _778 = _764;
            }
            float4 _786 = float4(float2(as_type<half2>(_757 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_658), 0u).x & 65535u)).x, _778, float((_757 >> 16u) & 31u) * 0.0322580635547637939453125) * _189;
            float _789 = float(_690.z > 0.0);
            float _793 = float(_722.z > 0.0);
            float _799 = float(_754.z > 0.0);
            float _805 = float(_786.z > 0.0);
            float _808 = ((_789 + _793) + _799) + _805;
            float4 _812 = ((((_690 * _789) + (_722 * _793)) + (_754 * _799)) + (_786 * _805)) / float4((_808 > 0.001000000047497451305389404296875) ? _808 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid0, _812, uint2(uint2(_145 + int2(_320, _488))));
            if (cbInpaintingPyramid.mips <= 1u)
            {
                break;
            }
            float4 _818 = spvQuadSwap(_312, 0u);
            float4 _819 = spvQuadSwap(_312, 1u);
            float4 _820 = spvQuadSwap(_312, 2u);
            float _823 = float(_312.z > 0.0);
            float _827 = float(_818.z > 0.0);
            float _833 = float(_819.z > 0.0);
            float _839 = float(_820.z > 0.0);
            float _842 = ((_823 + _827) + _833) + _839;
            float4 _846 = ((((_312 * _823) + (_818 * _827)) + (_819 * _833)) + (_820 * _839)) / float4((_842 > 0.001000000047497451305389404296875) ? _842 : 1.0);
            float4 _847 = spvQuadSwap(_480, 0u);
            float4 _848 = spvQuadSwap(_480, 1u);
            float4 _849 = spvQuadSwap(_480, 2u);
            float _852 = float(_480.z > 0.0);
            float _856 = float(_847.z > 0.0);
            float _862 = float(_848.z > 0.0);
            float _868 = float(_849.z > 0.0);
            float _871 = ((_852 + _856) + _862) + _868;
            float4 _875 = ((((_480 * _852) + (_847 * _856)) + (_848 * _862)) + (_849 * _868)) / float4((_871 > 0.001000000047497451305389404296875) ? _871 : 1.0);
            float4 _876 = spvQuadSwap(_648, 0u);
            float4 _877 = spvQuadSwap(_648, 1u);
            float4 _878 = spvQuadSwap(_648, 2u);
            float _881 = float(_648.z > 0.0);
            float _885 = float(_876.z > 0.0);
            float _891 = float(_877.z > 0.0);
            float _897 = float(_878.z > 0.0);
            float _900 = ((_881 + _885) + _891) + _897;
            float4 _904 = ((((_648 * _881) + (_876 * _885)) + (_877 * _891)) + (_878 * _897)) / float4((_900 > 0.001000000047497451305389404296875) ? _900 : 1.0);
            float4 _905 = spvQuadSwap(_812, 0u);
            float4 _906 = spvQuadSwap(_812, 1u);
            float4 _907 = spvQuadSwap(_812, 2u);
            float _910 = float(_812.z > 0.0);
            float _914 = float(_905.z > 0.0);
            float _920 = float(_906.z > 0.0);
            float _926 = float(_907.z > 0.0);
            float _929 = ((_910 + _914) + _920) + _926;
            float4 _933 = ((((_812 * _910) + (_905 * _914)) + (_906 * _920)) + (_907 * _926)) / float4((_929 > 0.001000000047497451305389404296875) ? _929 : 1.0);
            if ((gl_LocalInvocationIndex % 4u) == 0u)
            {
                int2 _939 = int2(_114 * uint2(16u));
                uint _940 = _130 / 2u;
                int _941 = int(_940);
                uint _942 = _133 / 2u;
                int _943 = int(_942);
                sdk_hlsl_store(rw_inpainting_pyramid1, _846, uint2(uint2(_939 + int2(_941, _943))));
                spdIntermediateR[_940][_942] = _846.x;
                spdIntermediateG[_940][_942] = _846.y;
                spdIntermediateB[_940][_942] = _846.z;
                spdIntermediateA[_940][_942] = _846.w;
                uint _956 = _940 + 8u;
                int _957 = int(_956);
                sdk_hlsl_store(rw_inpainting_pyramid1, _875, uint2(uint2(_939 + int2(_957, _943))));
                spdIntermediateR[_956][_942] = _875.x;
                spdIntermediateG[_956][_942] = _875.y;
                spdIntermediateB[_956][_942] = _875.z;
                spdIntermediateA[_956][_942] = _875.w;
                uint _970 = _942 + 8u;
                int _971 = int(_970);
                sdk_hlsl_store(rw_inpainting_pyramid1, _904, uint2(uint2(_939 + int2(_941, _971))));
                spdIntermediateR[_940][_970] = _904.x;
                spdIntermediateG[_940][_970] = _904.y;
                spdIntermediateB[_940][_970] = _904.z;
                spdIntermediateA[_940][_970] = _904.w;
                sdk_hlsl_store(rw_inpainting_pyramid1, _933, uint2(uint2(_939 + int2(_957, _971))));
                spdIntermediateR[_956][_970] = _933.x;
                spdIntermediateG[_956][_970] = _933.y;
                spdIntermediateB[_956][_970] = _933.z;
                spdIntermediateA[_956][_970] = _933.w;
            }
            break;
        } while(false);
        do
        {
            if (cbInpaintingPyramid.mips <= 2u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float _1002 = spdIntermediateR[_130][_133];
            float _1004 = spdIntermediateG[_130][_133];
            float _1006 = spdIntermediateB[_130][_133];
            float4 _1009 = float4(_1002, _1004, _1006, spdIntermediateA[_130][_133]);
            float4 _1010 = spvQuadSwap(_1009, 0u);
            float4 _1011 = spvQuadSwap(_1009, 1u);
            float4 _1012 = spvQuadSwap(_1009, 2u);
            float _1014 = float(_1006 > 0.0);
            float _1018 = float(_1010.z > 0.0);
            float _1024 = float(_1011.z > 0.0);
            float _1030 = float(_1012.z > 0.0);
            float _1033 = ((_1014 + _1018) + _1024) + _1030;
            float4 _1037 = ((((_1009 * _1014) + (_1010 * _1018)) + (_1011 * _1024)) + (_1012 * _1030)) / float4((_1033 > 0.001000000047497451305389404296875) ? _1033 : 1.0);
            bool _1039 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_1039)
            {
                uint _1046 = _133 / 2u;
                sdk_hlsl_store(rw_inpainting_pyramid2, _1037, uint2(uint2(int2(_114 * uint2(8u)) + int2(int(_130 / 2u), int(_1046)))));
                uint _1053 = _130 + (_1046 % 2u);
                spdIntermediateR[_1053][_133] = _1037.x;
                spdIntermediateG[_1053][_133] = _1037.y;
                spdIntermediateB[_1053][_133] = _1037.z;
                spdIntermediateA[_1053][_133] = _1037.w;
            }
            if (cbInpaintingPyramid.mips <= 3u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _1069 = _138 + (_133 % 2u);
                float _1071 = spdIntermediateR[_1069][_140];
                float _1073 = spdIntermediateG[_1069][_140];
                float _1075 = spdIntermediateB[_1069][_140];
                float4 _1078 = float4(_1071, _1073, _1075, spdIntermediateA[_1069][_140]);
                float4 _1079 = spvQuadSwap(_1078, 0u);
                float4 _1080 = spvQuadSwap(_1078, 1u);
                float4 _1081 = spvQuadSwap(_1078, 2u);
                float _1083 = float(_1075 > 0.0);
                float _1087 = float(_1079.z > 0.0);
                float _1093 = float(_1080.z > 0.0);
                float _1099 = float(_1081.z > 0.0);
                float _1102 = ((_1083 + _1087) + _1093) + _1099;
                float4 _1106 = ((((_1078 * _1083) + (_1079 * _1087)) + (_1080 * _1093)) + (_1081 * _1099)) / float4((_1102 > 0.001000000047497451305389404296875) ? _1102 : 1.0);
                if (_1039)
                {
                    uint _1113 = _133 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid3, _1106, uint2(uint2(int2(_114 * uint2(4u)) + int2(int(_130 / 2u), int(_1113)))));
                    uint _1119 = _138 + _1113;
                    spdIntermediateR[_1119][_140] = _1106.x;
                    spdIntermediateG[_1119][_140] = _1106.y;
                    spdIntermediateB[_1119][_140] = _1106.z;
                    spdIntermediateA[_1119][_140] = _1106.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 4u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1135 = (_130 * 4u) + _133;
                uint _1136 = _133 * 4u;
                float _1138 = spdIntermediateR[_1135][_1136];
                float _1140 = spdIntermediateG[_1135][_1136];
                float _1142 = spdIntermediateB[_1135][_1136];
                float4 _1145 = float4(_1138, _1140, _1142, spdIntermediateA[_1135][_1136]);
                float4 _1146 = spvQuadSwap(_1145, 0u);
                float4 _1147 = spvQuadSwap(_1145, 1u);
                float4 _1148 = spvQuadSwap(_1145, 2u);
                float _1150 = float(_1142 > 0.0);
                float _1154 = float(_1146.z > 0.0);
                float _1160 = float(_1147.z > 0.0);
                float _1166 = float(_1148.z > 0.0);
                float _1169 = ((_1150 + _1154) + _1160) + _1166;
                float4 _1173 = ((((_1145 * _1150) + (_1146 * _1154)) + (_1147 * _1160)) + (_1148 * _1166)) / float4((_1169 > 0.001000000047497451305389404296875) ? _1169 : 1.0);
                if (_1039)
                {
                    uint _1178 = _130 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid4, _1173, uint2(uint2(int2(_114 * uint2(2u)) + int2(int(_1178), int(_133 / 2u)))));
                    uint _1186 = _1178 + _133;
                    spdIntermediateR[_1186][0u] = _1173.x;
                    spdIntermediateG[_1186][0u] = _1173.y;
                    spdIntermediateB[_1186][0u] = _1173.z;
                    spdIntermediateA[_1186][0u] = _1173.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 5u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1209 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1210 = spvQuadSwap(_1209, 0u);
                float4 _1211 = spvQuadSwap(_1209, 1u);
                float4 _1212 = spvQuadSwap(_1209, 2u);
                float _1214 = float(spdIntermediateB[gl_LocalInvocationIndex][0u] > 0.0);
                float _1218 = float(_1210.z > 0.0);
                float _1224 = float(_1211.z > 0.0);
                float _1230 = float(_1212.z > 0.0);
                float _1233 = ((_1214 + _1218) + _1224) + _1230;
                if (_1039)
                {
                    sdk_hlsl_store(rw_inpainting_pyramid5, ((((_1209 * _1214) + (_1210 * _1218)) + (_1211 * _1224)) + (_1212 * _1230)) / float4((_1233 > 0.001000000047497451305389404296875) ? _1233 : 1.0), uint2(_114));
                }
            }
            break;
        } while(false);
        if (cbInpaintingPyramid.mips <= 6u)
        {
            break;
        }
        if (gl_LocalInvocationIndex == 0u)
        {
            uint _1248 = atomic_fetch_add_explicit((volatile device atomic_uint*)&rw_counters._m0[0u], 1u, memory_order_relaxed);
            spdCounter = _1248;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (spdCounter != (cbInpaintingPyramid.numWorkGroups - 1u))
        {
            break;
        }
        uint _1257;
        uint _1259;
        rw_counters._m0[0u] = 0u;
        do
        {
            _1257 = _130 * 4u;
            int _1258 = int(_1257);
            _1259 = _133 * 4u;
            int _1260 = int(_1259);
            uint2 _1262 = uint2(int2(_1258, _1260));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1267 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1262));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1269 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1262 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1271 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1262 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1273 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1262 + uint2(1u))));
            float _1276 = float(_1267.z > 0.0);
            float _1280 = float(_1269.z > 0.0);
            float _1286 = float(_1271.z > 0.0);
            float _1292 = float(_1273.z > 0.0);
            float _1295 = ((_1276 + _1280) + _1286) + _1292;
            float4 _1299 = ((((_1267 * _1276) + (_1269 * _1280)) + (_1271 * _1286)) + (_1273 * _1292)) / float4((_1295 > 0.001000000047497451305389404296875) ? _1295 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1299, uint2(uint2(_142)));
            int _1303 = int(_1257 + 2u);
            int _1306 = int(_138 + 1u);
            uint2 _1308 = uint2(int2(_1303, _1260));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1313 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1308));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1315 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1308 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1317 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1308 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1319 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1308 + uint2(1u))));
            float _1322 = float(_1313.z > 0.0);
            float _1326 = float(_1315.z > 0.0);
            float _1332 = float(_1317.z > 0.0);
            float _1338 = float(_1319.z > 0.0);
            float _1341 = ((_1322 + _1326) + _1332) + _1338;
            float4 _1345 = ((((_1313 * _1322) + (_1315 * _1326)) + (_1317 * _1332)) + (_1319 * _1338)) / float4((_1341 > 0.001000000047497451305389404296875) ? _1341 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1345, uint2(uint2(int2(_1306, _141))));
            int _1349 = int(_1259 + 2u);
            int _1352 = int(_140 + 1u);
            uint2 _1354 = uint2(int2(_1258, _1349));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1359 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1354));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1361 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1354 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1363 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1354 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1365 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1354 + uint2(1u))));
            float _1368 = float(_1359.z > 0.0);
            float _1372 = float(_1361.z > 0.0);
            float _1378 = float(_1363.z > 0.0);
            float _1384 = float(_1365.z > 0.0);
            float _1387 = ((_1368 + _1372) + _1378) + _1384;
            float4 _1391 = ((((_1359 * _1368) + (_1361 * _1372)) + (_1363 * _1378)) + (_1365 * _1384)) / float4((_1387 > 0.001000000047497451305389404296875) ? _1387 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1391, uint2(uint2(int2(_139, _1352))));
            uint2 _1396 = uint2(int2(_1303, _1349));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1401 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1396));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1403 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1396 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1405 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1396 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1407 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1396 + uint2(1u))));
            float _1410 = float(_1401.z > 0.0);
            float _1414 = float(_1403.z > 0.0);
            float _1420 = float(_1405.z > 0.0);
            float _1426 = float(_1407.z > 0.0);
            float _1429 = ((_1410 + _1414) + _1420) + _1426;
            float4 _1433 = ((((_1401 * _1410) + (_1403 * _1414)) + (_1405 * _1420)) + (_1407 * _1426)) / float4((_1429 > 0.001000000047497451305389404296875) ? _1429 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1433, uint2(uint2(int2(_1306, _1352))));
            if (cbInpaintingPyramid.mips <= 7u)
            {
                break;
            }
            float _1441 = float(_1299.z > 0.0);
            float _1445 = float(_1345.z > 0.0);
            float _1451 = float(_1391.z > 0.0);
            float _1457 = float(_1433.z > 0.0);
            float _1460 = ((_1441 + _1445) + _1451) + _1457;
            float4 _1464 = ((((_1299 * _1441) + (_1345 * _1445)) + (_1391 * _1451)) + (_1433 * _1457)) / float4((_1460 > 0.001000000047497451305389404296875) ? _1460 : 1.0);
            sdk_hlsl_store(rw_inpainting_pyramid7, _1464, uint2(uint2(_148)));
            spdIntermediateR[_130][_133] = _1464.x;
            spdIntermediateG[_130][_133] = _1464.y;
            spdIntermediateB[_130][_133] = _1464.z;
            spdIntermediateA[_130][_133] = _1464.w;
            break;
        } while(false);
        do
        {
            if (cbInpaintingPyramid.mips <= 8u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float _1481 = spdIntermediateR[_130][_133];
            float _1483 = spdIntermediateG[_130][_133];
            float _1485 = spdIntermediateB[_130][_133];
            float4 _1488 = float4(_1481, _1483, _1485, spdIntermediateA[_130][_133]);
            float4 _1489 = spvQuadSwap(_1488, 0u);
            float4 _1490 = spvQuadSwap(_1488, 1u);
            float4 _1491 = spvQuadSwap(_1488, 2u);
            float _1493 = float(_1485 > 0.0);
            float _1497 = float(_1489.z > 0.0);
            float _1503 = float(_1490.z > 0.0);
            float _1509 = float(_1491.z > 0.0);
            float _1512 = ((_1493 + _1497) + _1503) + _1509;
            float4 _1516 = ((((_1488 * _1493) + (_1489 * _1497)) + (_1490 * _1503)) + (_1491 * _1509)) / float4((_1512 > 0.001000000047497451305389404296875) ? _1512 : 1.0);
            bool _1518 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_1518)
            {
                uint _1523 = _133 / 2u;
                sdk_hlsl_store(rw_inpainting_pyramid8, _1516, uint2(uint2(int2(int(_130 / 2u), int(_1523)))));
                uint _1529 = _130 + (_1523 % 2u);
                spdIntermediateR[_1529][_133] = _1516.x;
                spdIntermediateG[_1529][_133] = _1516.y;
                spdIntermediateB[_1529][_133] = _1516.z;
                spdIntermediateA[_1529][_133] = _1516.w;
            }
            if (cbInpaintingPyramid.mips <= 9u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _1545 = _138 + (_133 % 2u);
                float _1547 = spdIntermediateR[_1545][_140];
                float _1549 = spdIntermediateG[_1545][_140];
                float _1551 = spdIntermediateB[_1545][_140];
                float4 _1554 = float4(_1547, _1549, _1551, spdIntermediateA[_1545][_140]);
                float4 _1555 = spvQuadSwap(_1554, 0u);
                float4 _1556 = spvQuadSwap(_1554, 1u);
                float4 _1557 = spvQuadSwap(_1554, 2u);
                float _1559 = float(_1551 > 0.0);
                float _1563 = float(_1555.z > 0.0);
                float _1569 = float(_1556.z > 0.0);
                float _1575 = float(_1557.z > 0.0);
                float _1578 = ((_1559 + _1563) + _1569) + _1575;
                float4 _1582 = ((((_1554 * _1559) + (_1555 * _1563)) + (_1556 * _1569)) + (_1557 * _1575)) / float4((_1578 > 0.001000000047497451305389404296875) ? _1578 : 1.0);
                if (_1518)
                {
                    uint _1587 = _133 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid9, _1582, uint2(uint2(int2(int(_130 / 2u), int(_1587)))));
                    uint _1592 = _138 + _1587;
                    spdIntermediateR[_1592][_140] = _1582.x;
                    spdIntermediateG[_1592][_140] = _1582.y;
                    spdIntermediateB[_1592][_140] = _1582.z;
                    spdIntermediateA[_1592][_140] = _1582.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 10u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1607 = _1257 + _133;
                float _1609 = spdIntermediateR[_1607][_1259];
                float _1611 = spdIntermediateG[_1607][_1259];
                float _1613 = spdIntermediateB[_1607][_1259];
                float4 _1616 = float4(_1609, _1611, _1613, spdIntermediateA[_1607][_1259]);
                float4 _1617 = spvQuadSwap(_1616, 0u);
                float4 _1618 = spvQuadSwap(_1616, 1u);
                float4 _1619 = spvQuadSwap(_1616, 2u);
                float _1621 = float(_1613 > 0.0);
                float _1625 = float(_1617.z > 0.0);
                float _1631 = float(_1618.z > 0.0);
                float _1637 = float(_1619.z > 0.0);
                float _1640 = ((_1621 + _1625) + _1631) + _1637;
                float4 _1644 = ((((_1616 * _1621) + (_1617 * _1625)) + (_1618 * _1631)) + (_1619 * _1637)) / float4((_1640 > 0.001000000047497451305389404296875) ? _1640 : 1.0);
                if (_1518)
                {
                    uint _1647 = _130 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid10, _1644, uint2(uint2(int2(int(_1647), int(_133 / 2u)))));
                    uint _1654 = _1647 + _133;
                    spdIntermediateR[_1654][0u] = _1644.x;
                    spdIntermediateG[_1654][0u] = _1644.y;
                    spdIntermediateB[_1654][0u] = _1644.z;
                    spdIntermediateA[_1654][0u] = _1644.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 11u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1677 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1678 = spvQuadSwap(_1677, 0u);
                float4 _1679 = spvQuadSwap(_1677, 1u);
                float4 _1680 = spvQuadSwap(_1677, 2u);
                float _1682 = float(spdIntermediateB[gl_LocalInvocationIndex][0u] > 0.0);
                float _1686 = float(_1678.z > 0.0);
                float _1692 = float(_1679.z > 0.0);
                float _1698 = float(_1680.z > 0.0);
                float _1701 = ((_1682 + _1686) + _1692) + _1698;
                if (_1518)
                {
                    sdk_hlsl_store(rw_inpainting_pyramid11, ((((_1677 * _1682) + (_1678 * _1686)) + (_1679 * _1692)) + (_1680 * _1698)) / float4((_1701 > 0.001000000047497451305389404296875) ? _1701 : 1.0), uint2(uint2(0u)));
                }
            }
            break;
        } while(false);
        break;
    } while(false);
}

