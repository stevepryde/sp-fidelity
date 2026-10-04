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
    uint2 _82 = (gl_WorkGroupID.xy * uint2(8u)) + gl_LocalInvocationID.xy;
    int2 _83 = int2(_82);
    float2 _88 = float2(cbFSR2.iRenderSize);
    int2 _102 = int2(((((float2(_83) + float2(0.5)) / _88) + ((sdk_hlsl_load(r_input_motion_vectors, uint2(_82), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation)) * _88) - float2(0.5));
    float4 _110 = sdk_hlsl_load(r_input_opaque_only, uint2(_82), 0u);
    float4 _112 = sdk_hlsl_load(r_input_color_jittered, uint2(_82), 0u);
    uint2 _113 = uint2(_102);
    float4 _115 = sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_113), 0u);
    float4 _117 = sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_113), 0u);
    float _118 = _110.x;
    float _121 = 0.5 * _110.y;
    float _123 = _110.z;
    float _124 = 0.25 * _123;
    float3 _131 = float3(((0.25 * _118) + _121) + _124, 0.5 * (_118 - _123), (((-0.25) * _118) + _121) - _124);
    float _132 = _112.x;
    float _135 = 0.5 * _112.y;
    float _137 = _112.z;
    float _138 = 0.25 * _137;
    float3 _145 = float3(((0.25 * _132) + _135) + _138, 0.5 * (_132 - _137), (((-0.25) * _132) + _135) - _138);
    float _146 = _115.x;
    float _149 = 0.5 * _115.y;
    float _151 = _115.z;
    float _152 = 0.25 * _151;
    float3 _159 = float3(((0.25 * _146) + _149) + _152, 0.5 * (_146 - _151), (((-0.25) * _146) + _149) - _152);
    float _160 = _117.x;
    float _163 = 0.5 * _117.y;
    float _165 = _117.z;
    float _166 = 0.25 * _165;
    float3 _173 = float3(((0.25 * _160) + _163) + _166, 0.5 * (_160 - _165), (((-0.25) * _160) + _163) - _166);
    float3 _183 = _145 - _173;
    float3 _191;
    if ((!any(abs(_145 - _131) > float3(0.00999999977648258209228515625))) ? any(abs(_173 - _159) > float3(0.00999999977648258209228515625)) : true)
    {
        _191 = _183 / precise::max(float3(0.00999999977648258209228515625), _131 - _159);
    }
    else
    {
        _191 = float3(0.0);
    }
    float _199 = fast::clamp(precise::max(precise::max(_191.x, _191.y), _191.z) * length(_183), 0.0, 1.0);
    float _279;
    if (_199 > 0.00999999977648258209228515625)
    {
        float4 _204 = sdk_hlsl_load(r_input_opaque_only, uint2(_82), 0u);
        float4 _206 = sdk_hlsl_load(r_input_color_jittered, uint2(_82), 0u);
        float4 _208 = sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_113), 0u);
        float4 _210 = sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_113), 0u);
        float _211 = _204.x;
        float _214 = 0.5 * _204.y;
        float _216 = _204.z;
        float _217 = 0.25 * _216;
        float _225 = _206.x;
        float _228 = 0.5 * _206.y;
        float _230 = _206.z;
        float _231 = 0.25 * _230;
        float _239 = _208.x;
        float _242 = 0.5 * _208.y;
        float _244 = _208.z;
        float _245 = 0.25 * _244;
        float _253 = _210.x;
        float _256 = 0.5 * _210.y;
        float _258 = _210.z;
        float _259 = 0.25 * _258;
        _279 = (fast::clamp(dot(abs(abs(float3(((0.25 * _225) + _228) + _231, 0.5 * (_225 - _230), (((-0.25) * _225) + _228) - _231) - float3(((0.25 * _211) + _214) + _217, 0.5 * (_211 - _216), (((-0.25) * _211) + _214) - _217)) - abs(float3(((0.25 * _253) + _256) + _259, 0.5 * (_253 - _258), (((-0.25) * _253) + _256) - _259) - float3(((0.25 * _239) + _242) + _245, 0.5 * (_239 - _244), (((-0.25) * _239) + _242) - _245))), float3(1.0)), 0.0, 1.0) < cbGenerateReactive.fTcThreshold) ? 0.0 : 1.0;
    }
    else
    {
        _279 = _199;
    }
    float2 _280 = float2(0.0);
    _280.y = _279;
    float2 _417;
    if (_279 > 0.5)
    {
        int _285;
        _285 = -1;
        spvUnsafeArray<float, 9> _76;
        int _289;
        for (int _288 = 0; _285 < 2; _285++, _288 = _289)
        {
            _289 = _288;
            for (int _296 = -1; _296 < 2; )
            {
                int2 _300 = int2(_296, _285);
                uint2 _302 = uint2(_83 + _300);
                uint2 _312 = uint2(_102 + _300);
                _76[_289] = length(abs(sdk_hlsl_load(r_input_color_jittered, uint2(_302), 0u).xyz - sdk_hlsl_load(r_input_opaque_only, uint2(_302), 0u).xyz) - abs(sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_312), 0u).xyz - sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_312), 0u).xyz));
                _289++;
                _296++;
                continue;
            }
        }
        int _351;
        _351 = -1;
        spvUnsafeArray<float, 9> _75;
        int _355;
        for (int _354 = 0; _351 < 2; _351++, _354 = _355)
        {
            _355 = _354;
            for (int _362 = -1; _362 < 2; )
            {
                int2 _366 = int2(_362, _351);
                _75[_355] = length(sdk_hlsl_load(r_input_opaque_only, uint2(uint2(_83 + _366)), 0u).xyz - sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(uint2(_102 + _366)), 0u).xyz);
                _355++;
                _362++;
                continue;
            }
        }
        float _407 = fast::clamp(sqrt(sqrt((abs(_76[3] - _76[4]) * abs(_76[5] - _76[4])) * (abs(_76[1] - _76[4]) * abs(_76[7] - _76[4])))) - sqrt(sqrt((abs(_75[3] - _75[4]) * abs(_75[5] - _75[4])) * (abs(_75[1] - _75[4]) * abs(_75[7] - _75[4])))), 0.0, 1.0);
        float2 _408 = float2(_407, _279);
        float _411 = _407 * cbGenerateReactive.fReactiveScale;
        _408.x = (_411 < cbGenerateReactive.fReactiveMax) ? _411 : cbGenerateReactive.fReactiveMax;
        _417 = _408;
    }
    else
    {
        _417 = _280;
    }
    sdk_hlsl_store(rw_output_autoreactive, float4(precise::max(_417.x, sdk_hlsl_load(r_reactive_mask, uint2(_82), 0u).x)), uint2(_82));
    sdk_hlsl_store(rw_output_autocomposition, float4(precise::max(_417.y * cbGenerateReactive.fTcScale, sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_82), 0u).x)), uint2(_82));
    sdk_hlsl_store(rw_output_prev_color_pre_alpha, sdk_hlsl_load(r_input_opaque_only, uint2(_82), 0u).xyz.xyzz, uint2(_82));
    sdk_hlsl_store(rw_output_prev_color_post_alpha, sdk_hlsl_load(r_input_color_jittered, uint2(_82), 0u).xyz.xyzz, uint2(_82));
}

