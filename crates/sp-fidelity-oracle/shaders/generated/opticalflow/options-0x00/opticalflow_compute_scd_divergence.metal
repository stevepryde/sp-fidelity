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

template <typename ImageT>
void spvImageFence(ImageT img) { img.fence(); }

kernel void main0(texture2d<uint, access::read_write> rw_optical_flow_scd_histogram [[texture(0)]], texture2d<float, access::read_write> rw_optical_flow_scd_previous_histogram [[texture(1)]], texture2d<uint, access::read_write> rw_optical_flow_scd_temp [[texture(2)]], texture2d<uint, access::read_write> rw_optical_flow_scd_output [[texture(3)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup spvUnsafeArray<float, 256> sourceHistogram;
    threadgroup spvUnsafeArray<float, 256> filteredHistogram;
    threadgroup spvUnsafeArray<float, 256> tempBuffer;
    threadgroup spvUnsafeArray<float2, 256> tempBuffer2;
    uint2 _79 = uint2(int2(int(gl_GlobalInvocationID.x), 0));
    spvImageFence(rw_optical_flow_scd_histogram);
    sourceHistogram[int(gl_LocalInvocationIndex)] = float(sdk_hlsl_load(rw_optical_flow_scd_histogram, uint2(_79)).x);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    int _125 = int(gl_LocalInvocationIndex) + 1;
    int _132 = int(gl_LocalInvocationIndex) + 2;
    int _146 = int(gl_LocalInvocationIndex) + 4;
    float _159 = ((((((((((0.008812229149043560028076171875 * sourceHistogram[max(0, min(255, (int(gl_LocalInvocationIndex) + (-5))))]) + (0.02714357711374759674072265625 * sourceHistogram[max(0, min(255, (int(gl_LocalInvocationIndex) + (-4))))])) + (0.065114058554172515869140625 * sourceHistogram[max(0, min(255, (int(gl_LocalInvocationIndex) + (-3))))])) + (0.12164907157421112060546875 * sourceHistogram[max(0, min(255, (int(gl_LocalInvocationIndex) + (-2))))])) + (0.1769983470439910888671875 * sourceHistogram[max(0, min(255, (int(gl_LocalInvocationIndex) + (-1))))])) + (0.20056541264057159423828125 * sourceHistogram[max(0, min(255, int(gl_LocalInvocationIndex)))])) + (0.1769983470439910888671875 * sourceHistogram[max(0, min(255, _125))])) + (0.12164907157421112060546875 * sourceHistogram[max(0, min(255, _132))])) + (0.065114058554172515869140625 * sourceHistogram[max(0, min(255, (int(gl_LocalInvocationIndex) + 3)))])) + (0.02714357711374759674072265625 * sourceHistogram[max(0, min(255, _146))])) + (0.008812229149043560028076171875 * sourceHistogram[max(0, min(255, (int(gl_LocalInvocationIndex) + 5)))]);
    float _160 = _159 + 1.0;
    if (int(gl_GlobalInvocationID.y) == 0)
    {
        if (int(gl_LocalInvocationIndex) == 0)
        {
            filteredHistogram[255] = 1.0;
        }
        else
        {
            filteredHistogram[int(gl_LocalInvocationIndex) - 1] = _160;
        }
    }
    else
    {
        if (int(gl_GlobalInvocationID.y) == 1)
        {
            filteredHistogram[int(gl_LocalInvocationIndex)] = _160;
        }
        else
        {
            if (int(gl_GlobalInvocationID.y) == 2)
            {
                if (int(gl_LocalInvocationIndex) == 255)
                {
                    filteredHistogram[0] = 1.0;
                }
                else
                {
                    filteredHistogram[_125] = _160;
                }
            }
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    tempBuffer[int(gl_LocalInvocationIndex)] = filteredHistogram[int(gl_LocalInvocationIndex)];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    bool _191 = int(gl_LocalInvocationIndex) < 128;
    if (_191)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[int(gl_LocalInvocationIndex) + 128];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    bool _199 = int(gl_LocalInvocationIndex) < 64;
    if (_199)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[int(gl_LocalInvocationIndex) + 64];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    bool _207 = int(gl_LocalInvocationIndex) < 32;
    if (_207)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[int(gl_LocalInvocationIndex) + 32];
    }
    bool _215 = int(gl_LocalInvocationIndex) < 16;
    if (_215)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[int(gl_LocalInvocationIndex) + 16];
    }
    bool _223 = int(gl_LocalInvocationIndex) < 8;
    if (_223)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[int(gl_LocalInvocationIndex) + 8];
    }
    bool _231 = int(gl_LocalInvocationIndex) < 4;
    if (_231)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[_146];
    }
    bool _238 = int(gl_LocalInvocationIndex) < 2;
    if (_238)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[_132];
    }
    if (int(gl_LocalInvocationIndex) < 1)
    {
        tempBuffer[int(gl_LocalInvocationIndex)] += tempBuffer[_125];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    filteredHistogram[int(gl_LocalInvocationIndex)] /= tempBuffer[0];
    float _256 = filteredHistogram[int(gl_LocalInvocationIndex)];
    spvImageFence(rw_optical_flow_scd_previous_histogram);
    float4 _258 = sdk_hlsl_load(rw_optical_flow_scd_previous_histogram, uint2(_79));
    float _259 = _258.x;
    tempBuffer2[int(gl_LocalInvocationIndex)] = float2(_256 * log(_256 / _259), _259 * log(_259 / _256));
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (_191)
    {
        tempBuffer2[int(gl_LocalInvocationIndex)] += tempBuffer2[int(gl_LocalInvocationIndex) + 128];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (_199)
    {
        tempBuffer2[int(gl_LocalInvocationIndex)] += tempBuffer2[int(gl_LocalInvocationIndex) + 64];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (_207)
    {
        tempBuffer2[int(gl_LocalInvocationIndex)] += tempBuffer2[int(gl_LocalInvocationIndex) + 32];
    }
    if (_215)
    {
        tempBuffer2[int(gl_LocalInvocationIndex)] += tempBuffer2[int(gl_LocalInvocationIndex) + 16];
    }
    if (_223)
    {
        tempBuffer2[int(gl_LocalInvocationIndex)] += tempBuffer2[int(gl_LocalInvocationIndex) + 8];
    }
    if (_231)
    {
        tempBuffer2[int(gl_LocalInvocationIndex)] += tempBuffer2[_146];
    }
    if (_238)
    {
        tempBuffer2[int(gl_LocalInvocationIndex)] += tempBuffer2[_132];
    }
    if (int(gl_LocalInvocationIndex) == 0)
    {
        float2 _322 = tempBuffer2[0] + tempBuffer2[1];
        uint _336 = rw_optical_flow_scd_temp.atomic_fetch_add(uint2(int2(int(gl_GlobalInvocationID.y), 0)), uint((1.0 - exp(-(abs(_322.x) + abs(_322.y)))) * 111111.109375)).x;
        uint _338 = rw_optical_flow_scd_output.atomic_fetch_add(uint2(2u, 0u), 1u).x;
        if (_338 == 26u)
        {
            spvImageFence(rw_optical_flow_scd_temp);
            spvImageFence(rw_optical_flow_scd_temp);
            spvImageFence(rw_optical_flow_scd_temp);
            float _354 = float(min(sdk_hlsl_load(rw_optical_flow_scd_temp, uint2(uint2(0u))).x, min(sdk_hlsl_load(rw_optical_flow_scd_temp, uint2(uint2(1u, 0u))).x, sdk_hlsl_load(rw_optical_flow_scd_temp, uint2(uint2(2u, 0u))).x))) * 9.9999999747524270787835121154785e-07;
            spvImageFence(rw_optical_flow_scd_output);
            uint _358 = sdk_hlsl_load(rw_optical_flow_scd_output, uint2(uint2(1u, 0u))).x << 1u;
            uint _363;
            if (_354 > 0.449999988079071044921875)
            {
                _363 = _358 | 1u;
            }
            else
            {
                _363 = _358;
            }
            sdk_hlsl_store(rw_optical_flow_scd_output, uint4(as_type<uint>(_354)), uint2(uint2(0u)));
            sdk_hlsl_store(rw_optical_flow_scd_output, uint4(_363), uint2(uint2(1u, 0u)));
            sdk_hlsl_store(rw_optical_flow_scd_output, uint4(0u), uint2(uint2(2u, 0u)));
            sdk_hlsl_store(rw_optical_flow_scd_temp, uint4(0u), uint2(uint2(0u)));
            sdk_hlsl_store(rw_optical_flow_scd_temp, uint4(0u), uint2(uint2(1u, 0u)));
            sdk_hlsl_store(rw_optical_flow_scd_temp, uint4(0u), uint2(uint2(2u, 0u)));
        }
    }
    if (int(gl_GlobalInvocationID.y) == 1)
    {
        sdk_hlsl_store(rw_optical_flow_scd_previous_histogram, float4(_256), uint2(_79));
        sdk_hlsl_store(rw_optical_flow_scd_histogram, uint4(0u), uint2(_79));
    }
}

