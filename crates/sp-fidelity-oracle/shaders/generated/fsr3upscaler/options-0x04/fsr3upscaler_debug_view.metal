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

struct FfxDebugViewport
{
    int2 offset;
    int2 size;
};

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_internal_upscaled_color [[texture(0)]], texture2d<float, access::write> rw_upscaled_output [[texture(1)]], texture2d<float> r_dilated_motion_vectors [[texture(2)]], texture2d<float> r_dilated_depth [[texture(3)]], texture2d<float> r_dilated_reactive_masks [[texture(4)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    int2 _65 = int2(float2(cbFSR3Upscaler.iUpscaleSize) * float2(0.3333333432674407958984375));
    int _67;
    _67 = 0;
    spvUnsafeArray<spvUnsafeArray<FfxDebugViewport, 3>, 3> _58;
    for (; _67 < 3; _67++)
    {
        for (int _74 = 0; _74 < 3; )
        {
            _58[_67][_74].offset = _65 * int2(_74, _67);
            _58[_67][_74].size = _65;
            _74++;
            continue;
        }
    }
    int2 _87 = _58[0][0].offset + _58[0][0].size;
    bool _95;
    if (int3(gl_GlobalInvocationID).x >= _58[0][0].offset.x)
    {
        _95 = int3(gl_GlobalInvocationID).x < _87.x;
    }
    else
    {
        _95 = false;
    }
    bool _106;
    if (_95)
    {
        bool _105;
        if (int3(gl_GlobalInvocationID).y >= _58[0][0].offset.y)
        {
            _105 = int3(gl_GlobalInvocationID).y < _87.y;
        }
        else
        {
            _105 = false;
        }
        _106 = _105;
    }
    else
    {
        _106 = false;
    }
    if (_106)
    {
        float2 _121 = float2(cbFSR3Upscaler.iRenderSize);
        sdk_hlsl_store(rw_upscaled_output, float4(float2(0.5) + ((r_dilated_motion_vectors.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(((float2(int3(gl_GlobalInvocationID).xy - _58[0][0].offset) + float2(0.5)) / float2(_58[0][0].size)) * _121, _121 - float2(0.5))) / float2(cbFSR3Upscaler.iMaxRenderSize)), level(0.0)).xy * _121) * 0.5), 0.5, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _145 = _58[0][1].offset + _58[0][1].size;
    bool _152;
    if (int3(gl_GlobalInvocationID).x >= _58[0][1].offset.x)
    {
        _152 = int3(gl_GlobalInvocationID).x < _145.x;
    }
    else
    {
        _152 = false;
    }
    bool _163;
    if (_152)
    {
        bool _162;
        if (int3(gl_GlobalInvocationID).y >= _58[0][1].offset.y)
        {
            _162 = int3(gl_GlobalInvocationID).y < _145.y;
        }
        else
        {
            _162 = false;
        }
        _163 = _162;
    }
    else
    {
        _163 = false;
    }
    if (_163)
    {
        sdk_hlsl_store(rw_upscaled_output, float4(fast::clamp(r_internal_upscaled_color.sample(s_LinearClamp, ((float2(int3(gl_GlobalInvocationID).xy - _58[0][1].offset) + float2(0.5)) / float2(_58[0][1].size)), level(0.0)).w - 1.0, 0.0, 1.0), 0.0, 0.0, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _188 = _58[0][2].offset + _58[0][2].size;
    bool _195;
    if (int3(gl_GlobalInvocationID).x >= _58[0][2].offset.x)
    {
        _195 = int3(gl_GlobalInvocationID).x < _188.x;
    }
    else
    {
        _195 = false;
    }
    bool _206;
    if (_195)
    {
        bool _205;
        if (int3(gl_GlobalInvocationID).y >= _58[0][2].offset.y)
        {
            _205 = int3(gl_GlobalInvocationID).y < _188.y;
        }
        else
        {
            _205 = false;
        }
        _206 = _205;
    }
    else
    {
        _206 = false;
    }
    if (_206)
    {
        float2 _221 = float2(cbFSR3Upscaler.iRenderSize);
        sdk_hlsl_store(rw_upscaled_output, float4(fast::clamp(((cbFSR3Upscaler.fDeviceToViewDepth.y / (r_dilated_depth.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(((float2(int3(gl_GlobalInvocationID).xy - _58[0][2].offset) + float2(0.5)) / float2(_58[0][2].size)) * _221, _221 - float2(0.5))) / float2(cbFSR3Upscaler.iMaxRenderSize)), level(0.0)).x - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor) * 0.039999999105930328369140625, 0.0, 1.0), 0.0, 0.0, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _251 = _58[2][0].offset + _58[2][0].size;
    bool _258;
    if (int3(gl_GlobalInvocationID).x >= _58[2][0].offset.x)
    {
        _258 = int3(gl_GlobalInvocationID).x < _251.x;
    }
    else
    {
        _258 = false;
    }
    bool _269;
    if (_258)
    {
        bool _268;
        if (int3(gl_GlobalInvocationID).y >= _58[2][0].offset.y)
        {
            _268 = int3(gl_GlobalInvocationID).y < _251.y;
        }
        else
        {
            _268 = false;
        }
        _269 = _268;
    }
    else
    {
        _269 = false;
    }
    if (_269)
    {
        float2 _284 = float2(cbFSR3Upscaler.iRenderSize);
        sdk_hlsl_store(rw_upscaled_output, float4(0.0, fast::clamp(r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(((float2(int3(gl_GlobalInvocationID).xy - _58[2][0].offset) + float2(0.5)) / float2(_58[2][0].size)) * _284, _284 - float2(0.5))) / float2(cbFSR3Upscaler.iMaxRenderSize)), level(0.0)).y, 0.0, 1.0), 0.0, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _304 = _58[2][1].offset + _58[2][1].size;
    bool _311;
    if (int3(gl_GlobalInvocationID).x >= _58[2][1].offset.x)
    {
        _311 = int3(gl_GlobalInvocationID).x < _304.x;
    }
    else
    {
        _311 = false;
    }
    bool _322;
    if (_311)
    {
        bool _321;
        if (int3(gl_GlobalInvocationID).y >= _58[2][1].offset.y)
        {
            _321 = int3(gl_GlobalInvocationID).y < _304.y;
        }
        else
        {
            _321 = false;
        }
        _322 = _321;
    }
    else
    {
        _322 = false;
    }
    if (_322)
    {
        float2 _337 = float2(cbFSR3Upscaler.iRenderSize);
        sdk_hlsl_store(rw_upscaled_output, float4(0.0, fast::clamp(r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(((float2(int3(gl_GlobalInvocationID).xy - _58[2][1].offset) + float2(0.5)) / float2(_58[2][1].size)) * _337, _337 - float2(0.5))) / float2(cbFSR3Upscaler.iMaxRenderSize)), level(0.0)).z, 0.0, 1.0), 0.0, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _357 = _58[2][2].offset + _58[2][2].size;
    bool _364;
    if (int3(gl_GlobalInvocationID).x >= _58[2][2].offset.x)
    {
        _364 = int3(gl_GlobalInvocationID).x < _357.x;
    }
    else
    {
        _364 = false;
    }
    bool _375;
    if (_364)
    {
        bool _374;
        if (int3(gl_GlobalInvocationID).y >= _58[2][2].offset.y)
        {
            _374 = int3(gl_GlobalInvocationID).y < _357.y;
        }
        else
        {
            _374 = false;
        }
        _375 = _374;
    }
    else
    {
        _375 = false;
    }
    if (_375)
    {
        float2 _390 = float2(cbFSR3Upscaler.iRenderSize);
        sdk_hlsl_store(rw_upscaled_output, float4(0.0, fast::clamp(r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(((float2(int3(gl_GlobalInvocationID).xy - _58[2][2].offset) + float2(0.5)) / float2(_58[2][2].size)) * _390, _390 - float2(0.5))) / float2(cbFSR3Upscaler.iMaxRenderSize)), level(0.0)).x, 0.0, 1.0), 0.0, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
}

