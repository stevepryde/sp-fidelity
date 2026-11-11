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

constant spvUnsafeArray<int2, 4> _85 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_depth [[texture(0)]], texture2d<float> r_input_color_jittered [[texture(1)]], texture2d<float> r_input_motion_vectors [[texture(2)]], texture2d<float, access::write> rw_farthest_depth [[texture(3)]], texture2d<float, access::write> rw_current_luma [[texture(4)]], texture2d<uint, access::read_write> rw_reconstructed_previous_nearest_depth [[texture(5)]], texture2d<float, access::write> rw_dilated_depth [[texture(6)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(7)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _92 = uint2(int3(gl_GlobalInvocationID).xy);
    float4 _94 = sdk_hlsl_load(r_input_depth, uint2(_92), 0u);
    float _95 = _94.x;
    int2 _96 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _97 = uint2(_96);
    float4 _99 = sdk_hlsl_load(r_input_depth, uint2(_97), 0u);
    float _100 = _99.x;
    int2 _101 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _102 = uint2(_101);
    float4 _104 = sdk_hlsl_load(r_input_depth, uint2(_102), 0u);
    float _105 = _104.x;
    int2 _106 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _107 = uint2(_106);
    float4 _109 = sdk_hlsl_load(r_input_depth, uint2(_107), 0u);
    float _110 = _109.x;
    int2 _111 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _112 = uint2(_111);
    float4 _114 = sdk_hlsl_load(r_input_depth, uint2(_112), 0u);
    float _115 = _114.x;
    int2 _116 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _117 = uint2(_116);
    float4 _119 = sdk_hlsl_load(r_input_depth, uint2(_117), 0u);
    float _120 = _119.x;
    int2 _121 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _122 = uint2(_121);
    float4 _124 = sdk_hlsl_load(r_input_depth, uint2(_122), 0u);
    float _125 = _124.x;
    int2 _126 = int3(gl_GlobalInvocationID).xy + int2(-1);
    uint2 _127 = uint2(_126);
    float4 _129 = sdk_hlsl_load(r_input_depth, uint2(_127), 0u);
    float _130 = _129.x;
    int2 _131 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _132 = uint2(_131);
    float4 _134 = sdk_hlsl_load(r_input_depth, uint2(_132), 0u);
    float _135 = _134.x;
    uint2 _138 = uint2(cbFSR3Upscaler.iRenderSize);
    float _151;
    int2 _152;
    float _153;
    if (all(_97 < _138))
    {
        bool _143 = _100 < _95;
        float _147;
        if (_143)
        {
            _147 = precise::max(_95, _100);
        }
        else
        {
            _147 = _95;
        }
        _151 = _143 ? _100 : _95;
        _152 = select(int3(gl_GlobalInvocationID).xy, _96, bool2(_143));
        _153 = _147;
    }
    else
    {
        _151 = _95;
        _152 = int3(gl_GlobalInvocationID).xy;
        _153 = _95;
    }
    float _166;
    int2 _167;
    float _168;
    if (all(_102 < _138))
    {
        bool _158 = _105 < _151;
        float _162;
        if (_158)
        {
            _162 = precise::max(_153, _105);
        }
        else
        {
            _162 = _153;
        }
        _166 = _158 ? _105 : _151;
        _167 = select(_152, _101, bool2(_158));
        _168 = _162;
    }
    else
    {
        _166 = _151;
        _167 = _152;
        _168 = _153;
    }
    float _181;
    int2 _182;
    float _183;
    if (all(_107 < _138))
    {
        bool _173 = _110 < _166;
        float _177;
        if (_173)
        {
            _177 = precise::max(_168, _110);
        }
        else
        {
            _177 = _168;
        }
        _181 = _173 ? _110 : _166;
        _182 = select(_167, _106, bool2(_173));
        _183 = _177;
    }
    else
    {
        _181 = _166;
        _182 = _167;
        _183 = _168;
    }
    float _196;
    int2 _197;
    float _198;
    if (all(_112 < _138))
    {
        bool _188 = _115 < _181;
        float _192;
        if (_188)
        {
            _192 = precise::max(_183, _115);
        }
        else
        {
            _192 = _183;
        }
        _196 = _188 ? _115 : _181;
        _197 = select(_182, _111, bool2(_188));
        _198 = _192;
    }
    else
    {
        _196 = _181;
        _197 = _182;
        _198 = _183;
    }
    float _211;
    int2 _212;
    float _213;
    if (all(_117 < _138))
    {
        bool _203 = _120 < _196;
        float _207;
        if (_203)
        {
            _207 = precise::max(_198, _120);
        }
        else
        {
            _207 = _198;
        }
        _211 = _203 ? _120 : _196;
        _212 = select(_197, _116, bool2(_203));
        _213 = _207;
    }
    else
    {
        _211 = _196;
        _212 = _197;
        _213 = _198;
    }
    float _226;
    int2 _227;
    float _228;
    if (all(_122 < _138))
    {
        bool _218 = _125 < _211;
        float _222;
        if (_218)
        {
            _222 = precise::max(_213, _125);
        }
        else
        {
            _222 = _213;
        }
        _226 = _218 ? _125 : _211;
        _227 = select(_212, _121, bool2(_218));
        _228 = _222;
    }
    else
    {
        _226 = _211;
        _227 = _212;
        _228 = _213;
    }
    float _241;
    int2 _242;
    float _243;
    if (all(_127 < _138))
    {
        bool _233 = _130 < _226;
        float _237;
        if (_233)
        {
            _237 = precise::max(_228, _130);
        }
        else
        {
            _237 = _228;
        }
        _241 = _233 ? _130 : _226;
        _242 = select(_227, _126, bool2(_233));
        _243 = _237;
    }
    else
    {
        _241 = _226;
        _242 = _227;
        _243 = _228;
    }
    float _256;
    int2 _257;
    float _258;
    if (all(_132 < _138))
    {
        bool _248 = _135 < _241;
        float _252;
        if (_248)
        {
            _252 = precise::max(_243, _135);
        }
        else
        {
            _252 = _243;
        }
        _256 = _248 ? _135 : _241;
        _257 = select(_242, _131, bool2(_248));
        _258 = _252;
    }
    else
    {
        _256 = _241;
        _257 = _242;
        _258 = _243;
    }
    float2 _265 = sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_257)), 0u).xy * cbFSR3Upscaler.fMotionVectorScale;
    float2 _286 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _290 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _286) + (_265 * float(length(_265 * float2(3840.0, 2160.0)) > mix(0.25, 0.75, fast::clamp(precise::min((cbFSR3Upscaler.fDeviceToViewDepth.y / (_256 - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor, 65504.0) * 0.00999999977648258209228515625, 0.0, 1.0))))) * _286) - float2(0.5);
    float2 _291 = floor(_290);
    int2 _292 = int2(_291);
    float2 _293 = _290 - _291;
    float _294 = _293.x;
    float _295 = 1.0 - _294;
    float _296 = _293.y;
    float _297 = 1.0 - _296;
    spvUnsafeArray<float, 4> _302 = spvUnsafeArray<float, 4>({ _295 * _297, _294 * _297, _295 * _296, _294 * _296 });
    spvUnsafeArray<float, 4> _88 = _302;
    for (int _304 = 0; _304 < 4; _304++)
    {
        if (_88[_304] > 0.0006099999882280826568603515625)
        {
            uint2 _318 = uint2(_292 + _85[_304]);
            if (all(_318 < _138))
            {
                uint _325 = rw_reconstructed_previous_nearest_depth.atomic_fetch_min(_318, as_type<uint>(_256)).x;
            }
        }
    }
    sdk_hlsl_store(rw_dilated_motion_vectors, _265.xyyy, uint2(_92));
    sdk_hlsl_store(rw_dilated_depth, float4(_256), uint2(_92));
    sdk_hlsl_store(rw_farthest_depth, float4(precise::min((cbFSR3Upscaler.fDeviceToViewDepth.y / (_258 - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor, 65504.0)), uint2(_92));
    sdk_hlsl_store(rw_current_luma, float4(dot(precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_92), 0u).xyz), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875))), uint2(_92));
}

