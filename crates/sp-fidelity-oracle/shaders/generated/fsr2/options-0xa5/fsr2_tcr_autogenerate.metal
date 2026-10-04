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
    short2 _95 = short2(ushort2((gl_WorkGroupID.xy * uint2(8u)) + gl_LocalInvocationID.xy));
    half2 _101 = half2(short2(cbFSR2.iRenderSize));
    uint2 _104 = uint2(int2(_95));
    short2 _116 = short2(float2((((half2(_95) + half2(half(0.5))) / _101) + half2(sdk_hlsl_load(r_input_motion_vectors, uint2(_104), 0u).xy * cbFSR2.fMotionVectorScale)) * _101) - float2(0.5));
    float4 _126 = sdk_hlsl_load(r_input_opaque_only, uint2(_104), 0u);
    float4 _128 = sdk_hlsl_load(r_input_color_jittered, uint2(_104), 0u);
    uint2 _130 = uint2(int2(_116));
    float4 _132 = sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_130), 0u);
    float4 _134 = sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_130), 0u);
    float _135 = _126.x;
    float _138 = 0.5 * _126.y;
    float _140 = _126.z;
    float _141 = 0.25 * _140;
    float3 _148 = float3(((0.25 * _135) + _138) + _141, 0.5 * (_135 - _140), (((-0.25) * _135) + _138) - _141);
    float _149 = _128.x;
    float _152 = 0.5 * _128.y;
    float _154 = _128.z;
    float _155 = 0.25 * _154;
    float3 _162 = float3(((0.25 * _149) + _152) + _155, 0.5 * (_149 - _154), (((-0.25) * _149) + _152) - _155);
    float _163 = _132.x;
    float _166 = 0.5 * _132.y;
    float _168 = _132.z;
    float _169 = 0.25 * _168;
    float3 _176 = float3(((0.25 * _163) + _166) + _169, 0.5 * (_163 - _168), (((-0.25) * _163) + _166) - _169);
    float _177 = _134.x;
    float _180 = 0.5 * _134.y;
    float _182 = _134.z;
    float _183 = 0.25 * _182;
    float3 _190 = float3(((0.25 * _177) + _180) + _183, 0.5 * (_177 - _182), (((-0.25) * _177) + _180) - _183);
    float3 _200 = _162 - _190;
    float3 _208;
    if ((!any(abs(_162 - _148) > float3(0.00999999977648258209228515625))) ? any(abs(_190 - _176) > float3(0.00999999977648258209228515625)) : true)
    {
        _208 = _200 / precise::max(float3(0.00999999977648258209228515625), _148 - _176);
    }
    else
    {
        _208 = float3(0.0);
    }
    half _218 = clamp(half(precise::max(precise::max(_208.x, _208.y), _208.z)) * half(length(_200)), half(0.0), half(1.0));
    half _300;
    if (_218 > half(0.01000213623046875))
    {
        float4 _223 = sdk_hlsl_load(r_input_opaque_only, uint2(_104), 0u);
        float4 _225 = sdk_hlsl_load(r_input_color_jittered, uint2(_104), 0u);
        float4 _227 = sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_130), 0u);
        float4 _229 = sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_130), 0u);
        float _230 = _223.x;
        float _233 = 0.5 * _223.y;
        float _235 = _223.z;
        float _236 = 0.25 * _235;
        float _244 = _225.x;
        float _247 = 0.5 * _225.y;
        float _249 = _225.z;
        float _250 = 0.25 * _249;
        float _258 = _227.x;
        float _261 = 0.5 * _227.y;
        float _263 = _227.z;
        float _264 = 0.25 * _263;
        float _272 = _229.x;
        float _275 = 0.5 * _229.y;
        float _277 = _229.z;
        float _278 = 0.25 * _277;
        half _299 = (float(half(fast::clamp(dot(abs(abs(float3(((0.25 * _244) + _247) + _250, 0.5 * (_244 - _249), (((-0.25) * _244) + _247) - _250) - float3(((0.25 * _230) + _233) + _236, 0.5 * (_230 - _235), (((-0.25) * _230) + _233) - _236)) - abs(float3(((0.25 * _272) + _275) + _278, 0.5 * (_272 - _277), (((-0.25) * _272) + _275) - _278) - float3(((0.25 * _258) + _261) + _264, 0.5 * (_258 - _263), (((-0.25) * _258) + _261) - _264))), float3(1.0)), 0.0, 1.0))) < cbGenerateReactive.fTcThreshold) ? half(0.0) : half(1.0);
        _300 = _299;
    }
    else
    {
        _300 = _218;
    }
    half2 _301 = half2(half(0.0));
    _301.y = _300;
    half2 _455;
    if (float(_300) > 0.5)
    {
        int _307;
        _307 = -1;
        spvUnsafeArray<float, 9> _87;
        int _311;
        for (int _310 = 0; _307 < 2; _307++, _310 = _311)
        {
            _311 = _310;
            for (int _318 = -1; _318 < 2; )
            {
                short2 _324 = short2(short(_318), short(_307));
                uint2 _327 = uint2(int2(_95 + _324));
                uint2 _338 = uint2(int2(_116 + _324));
                _87[_311] = length(abs(sdk_hlsl_load(r_input_color_jittered, uint2(_327), 0u).xyz - sdk_hlsl_load(r_input_opaque_only, uint2(_327), 0u).xyz) - abs(sdk_hlsl_load(r_input_prev_color_post_alpha, uint2(_338), 0u).xyz - sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(_338), 0u).xyz));
                _311++;
                _318++;
                continue;
            }
        }
        int _378;
        _378 = -1;
        spvUnsafeArray<float, 9> _86;
        int _382;
        for (int _381 = 0; _378 < 2; _378++, _381 = _382)
        {
            _382 = _381;
            for (int _389 = -1; _389 < 2; )
            {
                short2 _395 = short2(short(_389), short(_378));
                _86[_382] = length(sdk_hlsl_load(r_input_opaque_only, uint2(uint2(int2(_95 + _395))), 0u).xyz - sdk_hlsl_load(r_input_prev_color_pre_alpha, uint2(uint2(int2(_116 + _395))), 0u).xyz);
                _382++;
                _389++;
                continue;
            }
        }
        half _439 = clamp(half(sqrt(sqrt((abs(_87[3] - _87[4]) * abs(_87[5] - _87[4])) * (abs(_87[1] - _87[4]) * abs(_87[7] - _87[4]))))) - half(sqrt(sqrt((abs(_86[3] - _86[4]) * abs(_86[5] - _86[4])) * (abs(_86[1] - _86[4]) * abs(_86[7] - _86[4]))))), half(0.0), half(1.0));
        half2 _440 = half2(_439, _300);
        half _444 = _439 * half(cbGenerateReactive.fReactiveScale);
        half _453;
        if (float(_444) < cbGenerateReactive.fReactiveMax)
        {
            _453 = _444;
        }
        else
        {
            _453 = half(cbGenerateReactive.fReactiveMax);
        }
        _440.x = _453;
        _455 = _440;
    }
    else
    {
        _455 = _301;
    }
    sdk_hlsl_store(rw_output_autoreactive, float4(float(max(_455.x, half(sdk_hlsl_load(r_reactive_mask, uint2(_104), 0u).x)))), uint2(_104));
    sdk_hlsl_store(rw_output_autocomposition, float4(float(max(_455.y * half(cbGenerateReactive.fTcScale), half(sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_104), 0u).x)))), uint2(_104));
    sdk_hlsl_store(rw_output_prev_color_pre_alpha, float3(half3(sdk_hlsl_load(r_input_opaque_only, uint2(_104), 0u).xyz)).xyzz, uint2(_104));
    sdk_hlsl_store(rw_output_prev_color_post_alpha, float3(half3(sdk_hlsl_load(r_input_color_jittered, uint2(_104), 0u).xyz)).xyzz, uint2(_104));
}

