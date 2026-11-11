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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_spd_mips [[texture(0)]], texture2d<float, access::write> rw_shading_change [[texture(1)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _45 = float2(cbFSR3Upscaler.iRenderSize);
    int2 _47 = int2(_45 * 0.5);
    uint2 _48 = uint2(int3(gl_GlobalInvocationID).xy);
    if (all(_48 < uint2(_47)))
    {
        float2 _56 = float2(_47);
        uint2 _63 = uint2(r_spd_mips.get_width(0u), r_spd_mips.get_height(0u));
        float2 _74 = precise::max(float2(0.5), precise::min((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _56) + (cbFSR3Upscaler.fJitter / _45)) * _56, _56 - float2(0.5))) / float2(int2(int(_63.x), int(_63.y)));
        float4 _78 = r_spd_mips.sample(s_LinearClamp, _74, level(0.0));
        float _82 = abs(_78.x * _78.y);
        float4 _86 = r_spd_mips.sample(s_LinearClamp, _74, level(1.0));
        float _90 = abs(_86.x * _86.y);
        float4 _94 = r_spd_mips.sample(s_LinearClamp, _74, level(2.0));
        float _98 = abs(_94.x * _94.y);
        float _103;
        if (_82 > 0.0)
        {
            _103 = precise::max(0.0, _82);
        }
        else
        {
            _103 = 0.0;
        }
        float _108;
        if (_90 > 0.0)
        {
            _108 = precise::max(_103, _90);
        }
        else
        {
            _108 = _103;
        }
        float _113;
        if (_98 > 0.0)
        {
            _113 = precise::max(_108, _98);
        }
        else
        {
            _113 = _108;
        }
        sdk_hlsl_store(rw_shading_change, float4(fast::clamp(_113, 0.0, 1.0)), uint2(_48));
    }
}

