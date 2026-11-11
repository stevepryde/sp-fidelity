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

struct type_cbOF
{
    int2 iInputLumaResolution;
    uint uOpticalFlowPyramidLevel;
    uint uOpticalFlowPyramidLevelCount;
    uint iFrameIndex;
    uint backbufferTransferFunction;
    float2 minMaxLuminance;
};

kernel void main0(constant type_cbOF& cbOF [[buffer(0)]], texture2d<uint> r_optical_flow_input [[texture(0)]], texture2d<uint, access::read_write> rw_optical_flow_scd_histogram [[texture(1)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup spvUnsafeArray<uint, 2560> scdBuffer;
    uint _57 = uint(cbOF.iInputLumaResolution.x) / 3u;
    uint _60 = uint(cbOF.iInputLumaResolution.y) / 3u;
    uint _63 = uint(int(gl_GlobalInvocationID.z));
    uint _66 = _57 * (_63 % 3u);
    uint _67 = _60 * (_63 / 3u);
    uint _69 = _67 + _60;
    uint _71 = uint(int(gl_LocalInvocationIndex) * 10);
    for (int _73 = 0; _73 < 10; )
    {
        scdBuffer[_71 + uint(_73)] = 0u;
        _73++;
        continue;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint _85 = _66 + uint(4 * int(gl_GlobalInvocationID.x));
    if (_85 < (_66 + _57))
    {
        int2 _97;
        _97 = int2(int(_85), int(_67 + uint(int(gl_GlobalInvocationID.y))));
        for (; uint(_97.y) < _69; )
        {
            uint4 _124 = uint4(sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_97)), 0u).x, sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_97 + int2(1, 0))), 0u).x, sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_97 + int2(2, 0))), 0u).x, sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_97 + int2(3, 0))), 0u).x) * uint4(10u);
            uint _126 = uint(int(gl_LocalInvocationIndex) - 10 * (int(gl_LocalInvocationIndex) / 10));
            uint _130 = atomic_fetch_add_explicit((threadgroup atomic_uint*)&scdBuffer[_124.x + _126], 1u, memory_order_relaxed);
            uint _134 = atomic_fetch_add_explicit((threadgroup atomic_uint*)&scdBuffer[_124.y + _126], 1u, memory_order_relaxed);
            uint _138 = atomic_fetch_add_explicit((threadgroup atomic_uint*)&scdBuffer[_124.z + _126], 1u, memory_order_relaxed);
            uint _142 = atomic_fetch_add_explicit((threadgroup atomic_uint*)&scdBuffer[_124.w + _126], 1u, memory_order_relaxed);
            int2 _98 = _97;
            _98.y = _97.y + 128;
            _97 = _98;
            continue;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    uint _145;
    _145 = 0u;
    for (int _148 = 0; _148 < 10; )
    {
        _145 += scdBuffer[_71 + uint(_148)];
        _148++;
        continue;
    }
    uint _164 = rw_optical_flow_scd_histogram.atomic_fetch_add(uint2(int2(int(uint(256 * int(gl_GlobalInvocationID.z)) + uint(int(gl_LocalInvocationIndex))), 0)), _145).x;
}

