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

kernel void main0(texture2d<uint> rw_optical_flow_input [[texture(0)]], texture2d<uint, access::write> rw_optical_flow_input_level_1 [[texture(1)]], texture2d<uint, access::write> rw_optical_flow_input_level_2 [[texture(2)]], texture2d<uint, access::write> rw_optical_flow_input_level_3 [[texture(3)]], texture2d<uint, access::write> rw_optical_flow_input_level_4 [[texture(4)]], texture2d<uint, access::write> rw_optical_flow_input_level_5 [[texture(5)]], texture2d<uint, access::write> rw_optical_flow_input_level_6 [[texture(6)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateR;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateG;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateB;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateA;
    uint2 _62 = uint2(int3(gl_WorkGroupID).xy);
    uint _63 = uint(int(gl_LocalInvocationIndex));
    uint _64 = _63 % 64u;
    uint _77 = ((_64 & 1u) | ((_64 >> 2u) & 6u)) + (8u * ((_63 >> 6u) % 2u));
    uint _80 = (((_64 >> 1u) & 3u) | ((_64 >> 3u) & 4u)) + (8u * (_63 >> 7u));
    int2 _82 = int2(_62 * uint2(64u));
    uint _83 = _77 * 2u;
    int _84 = int(_83);
    uint _85 = _80 * 2u;
    int _86 = int(_85);
    int2 _88 = _82 + int2(_84, _86);
    int2 _90 = int2(_62 * uint2(32u));
    int _91 = int(_77);
    int _92 = int(_80);
    uint2 _95 = uint2(_88);
    float4 _137 = (((float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(_88))))).x), 0.0, 0.0, 0.0) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_95 + uint2(0u, 1u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_95 + uint2(1u, 0u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_95 + uint2(1u))))))).x), 0.0, 0.0, 0.0)) * 0.25;
    sdk_hlsl_store(rw_optical_flow_input_level_1, uint4(uint(_137.x)), uint2(uint2(_90 + int2(_91, _92))));
    int _143 = int(_83 + 32u);
    int2 _145 = _82 + int2(_143, _86);
    int _147 = int(_77 + 16u);
    uint2 _150 = uint2(_145);
    float4 _192 = (((float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(_145))))).x), 0.0, 0.0, 0.0) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_150 + uint2(0u, 1u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_150 + uint2(1u, 0u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_150 + uint2(1u))))))).x), 0.0, 0.0, 0.0)) * 0.25;
    sdk_hlsl_store(rw_optical_flow_input_level_1, uint4(uint(_192.x)), uint2(uint2(_90 + int2(_147, _92))));
    int _198 = int(_85 + 32u);
    int2 _200 = _82 + int2(_84, _198);
    int _202 = int(_80 + 16u);
    uint2 _205 = uint2(_200);
    float4 _247 = (((float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(_200))))).x), 0.0, 0.0, 0.0) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_205 + uint2(0u, 1u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_205 + uint2(1u, 0u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_205 + uint2(1u))))))).x), 0.0, 0.0, 0.0)) * 0.25;
    sdk_hlsl_store(rw_optical_flow_input_level_1, uint4(uint(_247.x)), uint2(uint2(_90 + int2(_91, _202))));
    int2 _253 = _82 + int2(_143, _198);
    uint2 _256 = uint2(_253);
    float4 _298 = (((float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(_253))))).x), 0.0, 0.0, 0.0) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_256 + uint2(0u, 1u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_256 + uint2(1u, 0u))))))).x), 0.0, 0.0, 0.0)) + float4(float(sdk_hlsl_load(rw_optical_flow_input, uint2(uint2(int2(float2(int2(_256 + uint2(1u))))))).x), 0.0, 0.0, 0.0)) * 0.25;
    sdk_hlsl_store(rw_optical_flow_input_level_1, uint4(uint(_298.x)), uint2(uint2(_90 + int2(_147, _202))));
    float4 _303 = spvQuadSwap(_137, 0u);
    float4 _304 = spvQuadSwap(_137, 1u);
    float4 _305 = spvQuadSwap(_137, 2u);
    float4 _309 = (((_137 + _303) + _304) + _305) * 0.25;
    float4 _310 = spvQuadSwap(_192, 0u);
    float4 _311 = spvQuadSwap(_192, 1u);
    float4 _312 = spvQuadSwap(_192, 2u);
    float4 _316 = (((_192 + _310) + _311) + _312) * 0.25;
    float4 _317 = spvQuadSwap(_247, 0u);
    float4 _318 = spvQuadSwap(_247, 1u);
    float4 _319 = spvQuadSwap(_247, 2u);
    float4 _323 = (((_247 + _317) + _318) + _319) * 0.25;
    float4 _324 = spvQuadSwap(_298, 0u);
    float4 _325 = spvQuadSwap(_298, 1u);
    float4 _326 = spvQuadSwap(_298, 2u);
    float4 _330 = (((_298 + _324) + _325) + _326) * 0.25;
    bool _332 = (_63 % 4u) == 0u;
    if (_332)
    {
        int2 _336 = int2(_62 * uint2(16u));
        uint _337 = _77 / 2u;
        int _338 = int(_337);
        uint _339 = _80 / 2u;
        int _340 = int(_339);
        float _343 = _309.x;
        sdk_hlsl_store(rw_optical_flow_input_level_2, uint4(uint(_343)), uint2(uint2(_336 + int2(_338, _340))));
        spdIntermediateR[_337][_339] = _343;
        spdIntermediateG[_337][_339] = _309.y;
        spdIntermediateB[_337][_339] = _309.z;
        spdIntermediateA[_337][_339] = _309.w;
        uint _354 = _337 + 8u;
        int _355 = int(_354);
        float _358 = _316.x;
        sdk_hlsl_store(rw_optical_flow_input_level_2, uint4(uint(_358)), uint2(uint2(_336 + int2(_355, _340))));
        spdIntermediateR[_354][_339] = _358;
        spdIntermediateG[_354][_339] = _316.y;
        spdIntermediateB[_354][_339] = _316.z;
        spdIntermediateA[_354][_339] = _316.w;
        uint _369 = _339 + 8u;
        int _370 = int(_369);
        float _373 = _323.x;
        sdk_hlsl_store(rw_optical_flow_input_level_2, uint4(uint(_373)), uint2(uint2(_336 + int2(_338, _370))));
        spdIntermediateR[_337][_369] = _373;
        spdIntermediateG[_337][_369] = _323.y;
        spdIntermediateB[_337][_369] = _323.z;
        spdIntermediateA[_337][_369] = _323.w;
        float _386 = _330.x;
        sdk_hlsl_store(rw_optical_flow_input_level_2, uint4(uint(_386)), uint2(uint2(_336 + int2(_355, _370))));
        spdIntermediateR[_354][_369] = _386;
        spdIntermediateG[_354][_369] = _330.y;
        spdIntermediateB[_354][_369] = _330.z;
        spdIntermediateA[_354][_369] = _330.w;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    float _398 = spdIntermediateR[_77][_80];
    float _400 = spdIntermediateG[_77][_80];
    float _402 = spdIntermediateB[_77][_80];
    float4 _405 = float4(_398, _400, _402, spdIntermediateA[_77][_80]);
    float4 _406 = spvQuadSwap(_405, 0u);
    float4 _407 = spvQuadSwap(_405, 1u);
    float4 _408 = spvQuadSwap(_405, 2u);
    float4 _412 = (((_405 + _406) + _407) + _408) * 0.25;
    if (_332)
    {
        uint _419 = _80 / 2u;
        float _423 = _412.x;
        sdk_hlsl_store(rw_optical_flow_input_level_3, uint4(uint(_423)), uint2(uint2(int2(_62 * uint2(8u)) + int2(int(_77 / 2u), int(_419)))));
        uint _428 = _77 + (_419 % 2u);
        spdIntermediateR[_428][_80] = _423;
        spdIntermediateG[_428][_80] = _412.y;
        spdIntermediateB[_428][_80] = _412.z;
        spdIntermediateA[_428][_80] = _412.w;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (_63 < 64u)
    {
        uint _440 = _83 + (_80 % 2u);
        float _442 = spdIntermediateR[_440][_85];
        float _444 = spdIntermediateG[_440][_85];
        float _446 = spdIntermediateB[_440][_85];
        float4 _449 = float4(_442, _444, _446, spdIntermediateA[_440][_85]);
        float4 _450 = spvQuadSwap(_449, 0u);
        float4 _451 = spvQuadSwap(_449, 1u);
        float4 _452 = spvQuadSwap(_449, 2u);
        float4 _456 = (((_449 + _450) + _451) + _452) * 0.25;
        if (_332)
        {
            uint _463 = _80 / 2u;
            float _467 = _456.x;
            sdk_hlsl_store(rw_optical_flow_input_level_4, uint4(uint(_467)), uint2(uint2(int2(_62 * uint2(4u)) + int2(int(_77 / 2u), int(_463)))));
            uint _471 = _83 + _463;
            spdIntermediateR[_471][_85] = _467;
            spdIntermediateG[_471][_85] = _456.y;
            spdIntermediateB[_471][_85] = _456.z;
            spdIntermediateA[_471][_85] = _456.w;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (_63 < 16u)
    {
        uint _483 = (_77 * 4u) + _80;
        uint _484 = _80 * 4u;
        float _486 = spdIntermediateR[_483][_484];
        float _488 = spdIntermediateG[_483][_484];
        float _490 = spdIntermediateB[_483][_484];
        float4 _493 = float4(_486, _488, _490, spdIntermediateA[_483][_484]);
        float4 _494 = spvQuadSwap(_493, 0u);
        float4 _495 = spvQuadSwap(_493, 1u);
        float4 _496 = spvQuadSwap(_493, 2u);
        float4 _500 = (((_493 + _494) + _495) + _496) * 0.25;
        if (_332)
        {
            uint _505 = _77 / 2u;
            float _511 = _500.x;
            sdk_hlsl_store(rw_optical_flow_input_level_5, uint4(uint(_511)), uint2(uint2(int2(_62 * uint2(2u)) + int2(int(_505), int(_80 / 2u)))));
            uint _515 = _505 + _80;
            spdIntermediateR[_515][0u] = _511;
            spdIntermediateG[_515][0u] = _500.y;
            spdIntermediateB[_515][0u] = _500.z;
            spdIntermediateA[_515][0u] = _500.w;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (_63 < 4u)
    {
        float4 _534 = float4(spdIntermediateR[_63][0u], spdIntermediateG[_63][0u], spdIntermediateB[_63][0u], spdIntermediateA[_63][0u]);
        float4 _535 = spvQuadSwap(_534, 0u);
        float4 _536 = spvQuadSwap(_534, 1u);
        float4 _537 = spvQuadSwap(_534, 2u);
        if (_332)
        {
            sdk_hlsl_store(rw_optical_flow_input_level_6, uint4(uint(((((_534 + _535) + _536) + _537) * 0.25).x)), uint2(_62));
        }
    }
}

