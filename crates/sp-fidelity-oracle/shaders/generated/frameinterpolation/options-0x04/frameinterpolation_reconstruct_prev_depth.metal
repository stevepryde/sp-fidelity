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

constant spvUnsafeArray<int2, 4> _56 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_dilated_motion_vectors [[texture(0)]], texture2d<float> r_dilated_depth [[texture(1)]], texture2d<float> r_input_distortion_field [[texture(2)]], texture2d<uint, access::read_write> rw_reconstructed_depth_interpolated_frame [[texture(3)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _66 = float2(cbFI.renderSize);
    float2 _67 = (float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _66;
    uint2 _76 = uint2(int3(gl_GlobalInvocationID).xy + int2(r_input_distortion_field.sample(s_LinearClamp, _67, level(0.0)).xy * _66));
    float4 _81 = sdk_hlsl_load(r_dilated_depth, uint2(_76), 0u);
    float _82 = _81.x;
    float2 _86 = ((_67 + (sdk_hlsl_load(r_dilated_motion_vectors, uint2(_76), 0u).xy * 0.5)) * _66) - float2(0.5);
    float2 _87 = floor(_86);
    int2 _88 = int2(_87);
    float2 _89 = _86 - _87;
    float _90 = _89.x;
    float _91 = 1.0 - _90;
    float _92 = _89.y;
    float _93 = 1.0 - _92;
    spvUnsafeArray<float, 4> _98 = spvUnsafeArray<float, 4>({ _91 * _93, _90 * _93, _91 * _92, _90 * _92 });
    spvUnsafeArray<float, 4> _58 = _98;
    for (int _100 = 0; _100 < 4; _100++)
    {
        if (_58[_100] > 0.001000000047497451305389404296875)
        {
            uint2 _114 = uint2(_88 + _56[_100]);
            if (all(_114 < uint2(cbFI.renderSize)))
            {
                uint _122 = rw_reconstructed_depth_interpolated_frame.atomic_fetch_max(_114, as_type<uint>(_82)).x;
            }
        }
    }
}

