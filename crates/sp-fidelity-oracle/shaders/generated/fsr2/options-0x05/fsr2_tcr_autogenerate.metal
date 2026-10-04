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

struct type_cbGenerateReactive
{
    float fTcThreshold;
    float fTcScale;
    float fReactiveScale;
    float fReactiveMax;
};

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], constant type_cbGenerateReactive& cbGenerateReactive [[buffer(1)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_opaque_only [[texture(1)]], texture2d<float> r_input_motion_vectors [[texture(2)]], texture2d<float> r_reactive_mask [[texture(3)]], texture2d<float> r_transparency_and_composition_mask [[texture(4)]], texture2d<float> r_input_prev_color_pre_alpha [[texture(5)]], texture2d<float> r_input_prev_color_post_alpha [[texture(6)]], texture2d<float, access::write> rw_output_autoreactive [[texture(7)]], texture2d<float, access::write> rw_output_autocomposition [[texture(8)]], texture2d<float, access::write> rw_output_prev_color_pre_alpha [[texture(9)]], texture2d<float, access::write> rw_output_prev_color_post_alpha [[texture(10)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _81 = (gl_WorkGroupID.xy * uint2(8u)) + gl_LocalInvocationID.xy;
    int2 _82 = int2(_81);
    float2 _87 = float2(cbFSR2.iRenderSize);
    int2 _98 = int2(((((float2(_82) + float2(0.5)) / _87) + (sdk_hlsl_load(r_input_motion_vectors, uint2(_81), 0u).xy * cbFSR2.fMotionVectorScale)) * _87) - float2(0.5));
    float4 _106 = sdk_hlsl_load(r_input_opaque_only, uint2(_81), 0u);
    float4 _108 = sdk_hlsl_load(r_input_color_jittered, uint2(_81), 0u);
    uint2 _109 = uint2(_98);
    float4 _111 = sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_109), 0u);
    float4 _113 = sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_109), 0u);
    float _114 = _106.x;
    float _117 = 0.5 * _106.y;
    float _119 = _106.z;
    float _120 = 0.25 * _119;
    float3 _127 = float3(((0.25 * _114) + _117) + _120, 0.5 * (_114 - _119), (((-0.25) * _114) + _117) - _120);
    float _128 = _108.x;
    float _131 = 0.5 * _108.y;
    float _133 = _108.z;
    float _134 = 0.25 * _133;
    float3 _141 = float3(((0.25 * _128) + _131) + _134, 0.5 * (_128 - _133), (((-0.25) * _128) + _131) - _134);
    float _142 = _111.x;
    float _145 = 0.5 * _111.y;
    float _147 = _111.z;
    float _148 = 0.25 * _147;
    float3 _155 = float3(((0.25 * _142) + _145) + _148, 0.5 * (_142 - _147), (((-0.25) * _142) + _145) - _148);
    float _156 = _113.x;
    float _159 = 0.5 * _113.y;
    float _161 = _113.z;
    float _162 = 0.25 * _161;
    float3 _169 = float3(((0.25 * _156) + _159) + _162, 0.5 * (_156 - _161), (((-0.25) * _156) + _159) - _162);
    float3 _179 = _141 - _169;
    float3 _187;
    if ((!any(abs(_141 - _127) > float3(0.00999999977648258209228515625))) ? any(abs(_169 - _155) > float3(0.00999999977648258209228515625)) : true)
    {
        _187 = _179 / precise::max(float3(0.00999999977648258209228515625), _127 - _155);
    }
    else
    {
        _187 = float3(0.0);
    }
    float _195 = fast::clamp(precise::max(precise::max(_187.x, _187.y), _187.z) * length(_179), 0.0, 1.0);
    float _275;
    if (_195 > 0.00999999977648258209228515625)
    {
        float4 _200 = sdk_hlsl_load(r_input_opaque_only, uint2(_81), 0u);
        float4 _202 = sdk_hlsl_load(r_input_color_jittered, uint2(_81), 0u);
        float4 _204 = sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_109), 0u);
        float4 _206 = sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_109), 0u);
        float _207 = _200.x;
        float _210 = 0.5 * _200.y;
        float _212 = _200.z;
        float _213 = 0.25 * _212;
        float _221 = _202.x;
        float _224 = 0.5 * _202.y;
        float _226 = _202.z;
        float _227 = 0.25 * _226;
        float _235 = _204.x;
        float _238 = 0.5 * _204.y;
        float _240 = _204.z;
        float _241 = 0.25 * _240;
        float _249 = _206.x;
        float _252 = 0.5 * _206.y;
        float _254 = _206.z;
        float _255 = 0.25 * _254;
        _275 = (fast::clamp(dot(abs(abs(float3(((0.25 * _221) + _224) + _227, 0.5 * (_221 - _226), (((-0.25) * _221) + _224) - _227) - float3(((0.25 * _207) + _210) + _213, 0.5 * (_207 - _212), (((-0.25) * _207) + _210) - _213)) - abs(float3(((0.25 * _249) + _252) + _255, 0.5 * (_249 - _254), (((-0.25) * _249) + _252) - _255) - float3(((0.25 * _235) + _238) + _241, 0.5 * (_235 - _240), (((-0.25) * _235) + _238) - _241))), float3(1.0)), 0.0, 1.0) < cbGenerateReactive.fTcThreshold) ? 0.0 : 1.0;
    }
    else
    {
        _275 = _195;
    }
    float2 _276 = float2(0.0);
    _276.y = _275;
    float2 _413;
    if (_275 > 0.5)
    {
        int _281;
        _281 = -1;
        spvUnsafeArray<float, 9> _75;
        int _285;
        for (int _284 = 0; _281 < 2; _281++, _284 = _285)
        {
            _285 = _284;
            for (int _292 = -1; _292 < 2; )
            {
                int2 _296 = int2(_292, _281);
                uint2 _298 = uint2(_82 + _296);
                uint2 _308 = uint2(_98 + _296);
                _75[_285] = length(abs(sdk_hlsl_load(r_input_color_jittered, uint2(_298), 0u).xyz - sdk_hlsl_load(r_input_opaque_only, uint2(_298), 0u).xyz) - abs(sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_308), 0u).xyz - sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_308), 0u).xyz));
                _285++;
                _292++;
                continue;
            }
        }
        int _347;
        _347 = -1;
        spvUnsafeArray<float, 9> _74;
        int _351;
        for (int _350 = 0; _347 < 2; _347++, _350 = _351)
        {
            _351 = _350;
            for (int _358 = -1; _358 < 2; )
            {
                int2 _362 = int2(_358, _347);
                _74[_351] = length(sdk_hlsl_load(r_input_opaque_only, uint2(uint2(_82 + _362)), 0u).xyz - sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(uint2(_98 + _362)), 0u).xyz);
                _351++;
                _358++;
                continue;
            }
        }
        float _403 = fast::clamp(sqrt(sqrt((abs(_75[3] - _75[4]) * abs(_75[5] - _75[4])) * (abs(_75[1] - _75[4]) * abs(_75[7] - _75[4])))) - sqrt(sqrt((abs(_74[3] - _74[4]) * abs(_74[5] - _74[4])) * (abs(_74[1] - _74[4]) * abs(_74[7] - _74[4])))), 0.0, 1.0);
        float2 _404 = float2(_403, _275);
        float _407 = _403 * cbGenerateReactive.fReactiveScale;
        _404.x = (_407 < cbGenerateReactive.fReactiveMax) ? _407 : cbGenerateReactive.fReactiveMax;
        _413 = _404;
    }
    else
    {
        _413 = _276;
    }
    sdk_hlsl_store(rw_output_autoreactive, float4(precise::max(_413.x, sdk_hlsl_load(r_reactive_mask, uint2(_81), 0u).x)), uint2(_81));
    sdk_hlsl_store(rw_output_autocomposition, float4(precise::max(_413.y * cbGenerateReactive.fTcScale, sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_81), 0u).x)), uint2(_81));
    sdk_hlsl_store(rw_output_prev_color_pre_alpha, sdk_hlsl_load(r_input_opaque_only, uint2(_81), 0u).xyz.xyzz, uint2(_81));
    sdk_hlsl_store(rw_output_prev_color_post_alpha, sdk_hlsl_load(r_input_color_jittered, uint2(_81), 0u).xyz.xyzz, uint2(_81));
}

