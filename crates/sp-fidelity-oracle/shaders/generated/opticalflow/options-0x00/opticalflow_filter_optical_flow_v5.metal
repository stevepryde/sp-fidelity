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

kernel void main0(texture2d<int> r_optical_flow_previous [[texture(0)]], texture2d<int, access::write> rw_optical_flow [[texture(1)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    int _38;
    _38 = -1;
    spvUnsafeArray<int2, 9> _34;
    int _42;
    for (int _41 = 0; _38 < 2; _38++, _41 = _42)
    {
        _42 = _41;
        for (int _49 = -1; _49 < 2; )
        {
            _34[_42] = sdk_hlsl_load(r_optical_flow_previous, uint2(uint2(int3(gl_GlobalInvocationID).xy + int2(_38, _49))), 0u).xy;
            _42++;
            _49++;
            continue;
        }
    }
    uint _61;
    int _64;
    _61 = 4294967295u;
    _64 = 0;
    uint _62;
    for (; _64 < 9; _61 = _62, _64++)
    {
        uint _70;
        _70 = 0u;
        for (int _73 = 0; _73 < 9; )
        {
            int2 _81 = _34[_64] - _34[_73];
            int _82 = _81.x;
            int _85 = _81.y;
            _70 = uint(_82 * _82) + (uint(_85 * _85) + _70);
            _73++;
            continue;
        }
        _62 = min(((_70 << 4u) | uint(_64)), _61);
    }
    sdk_hlsl_store(rw_optical_flow, _34[_61 & 15u].xyyy, uint2(uint2(int3(gl_GlobalInvocationID).xy)));
}

