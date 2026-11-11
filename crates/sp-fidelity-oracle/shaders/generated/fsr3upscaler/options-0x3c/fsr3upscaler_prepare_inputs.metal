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

constant spvUnsafeArray<int2, 4> _86 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_depth [[texture(0)]], texture2d<float> r_input_color_jittered [[texture(1)]], texture2d<float> r_input_motion_vectors [[texture(2)]], texture2d<float, access::write> rw_farthest_depth [[texture(3)]], texture2d<float, access::write> rw_current_luma [[texture(4)]], texture2d<uint, access::read_write> rw_reconstructed_previous_nearest_depth [[texture(5)]], texture2d<float, access::write> rw_dilated_depth [[texture(6)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(7)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _93 = uint2(int3(gl_GlobalInvocationID).xy);
    float4 _95 = sdk_hlsl_load(r_input_depth, uint2(_93), 0u);
    float _96 = _95.x;
    int2 _97 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _98 = uint2(_97);
    float4 _100 = sdk_hlsl_load(r_input_depth, uint2(_98), 0u);
    float _101 = _100.x;
    int2 _102 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _103 = uint2(_102);
    float4 _105 = sdk_hlsl_load(r_input_depth, uint2(_103), 0u);
    float _106 = _105.x;
    int2 _107 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _108 = uint2(_107);
    float4 _110 = sdk_hlsl_load(r_input_depth, uint2(_108), 0u);
    float _111 = _110.x;
    int2 _112 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _113 = uint2(_112);
    float4 _115 = sdk_hlsl_load(r_input_depth, uint2(_113), 0u);
    float _116 = _115.x;
    int2 _117 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _118 = uint2(_117);
    float4 _120 = sdk_hlsl_load(r_input_depth, uint2(_118), 0u);
    float _121 = _120.x;
    int2 _122 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _123 = uint2(_122);
    float4 _125 = sdk_hlsl_load(r_input_depth, uint2(_123), 0u);
    float _126 = _125.x;
    int2 _127 = int3(gl_GlobalInvocationID).xy + int2(-1);
    uint2 _128 = uint2(_127);
    float4 _130 = sdk_hlsl_load(r_input_depth, uint2(_128), 0u);
    float _131 = _130.x;
    int2 _132 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _133 = uint2(_132);
    float4 _135 = sdk_hlsl_load(r_input_depth, uint2(_133), 0u);
    float _136 = _135.x;
    uint2 _139 = uint2(cbFSR3Upscaler.iRenderSize);
    float _152;
    int2 _153;
    float _154;
    if (all(_98 < _139))
    {
        bool _144 = _101 > _96;
        float _148;
        if (_144)
        {
            _148 = precise::min(_96, _101);
        }
        else
        {
            _148 = _96;
        }
        _152 = _144 ? _101 : _96;
        _153 = select(int3(gl_GlobalInvocationID).xy, _97, bool2(_144));
        _154 = _148;
    }
    else
    {
        _152 = _96;
        _153 = int3(gl_GlobalInvocationID).xy;
        _154 = _96;
    }
    float _167;
    int2 _168;
    float _169;
    if (all(_103 < _139))
    {
        bool _159 = _106 > _152;
        float _163;
        if (_159)
        {
            _163 = precise::min(_154, _106);
        }
        else
        {
            _163 = _154;
        }
        _167 = _159 ? _106 : _152;
        _168 = select(_153, _102, bool2(_159));
        _169 = _163;
    }
    else
    {
        _167 = _152;
        _168 = _153;
        _169 = _154;
    }
    float _182;
    int2 _183;
    float _184;
    if (all(_108 < _139))
    {
        bool _174 = _111 > _167;
        float _178;
        if (_174)
        {
            _178 = precise::min(_169, _111);
        }
        else
        {
            _178 = _169;
        }
        _182 = _174 ? _111 : _167;
        _183 = select(_168, _107, bool2(_174));
        _184 = _178;
    }
    else
    {
        _182 = _167;
        _183 = _168;
        _184 = _169;
    }
    float _197;
    int2 _198;
    float _199;
    if (all(_113 < _139))
    {
        bool _189 = _116 > _182;
        float _193;
        if (_189)
        {
            _193 = precise::min(_184, _116);
        }
        else
        {
            _193 = _184;
        }
        _197 = _189 ? _116 : _182;
        _198 = select(_183, _112, bool2(_189));
        _199 = _193;
    }
    else
    {
        _197 = _182;
        _198 = _183;
        _199 = _184;
    }
    float _212;
    int2 _213;
    float _214;
    if (all(_118 < _139))
    {
        bool _204 = _121 > _197;
        float _208;
        if (_204)
        {
            _208 = precise::min(_199, _121);
        }
        else
        {
            _208 = _199;
        }
        _212 = _204 ? _121 : _197;
        _213 = select(_198, _117, bool2(_204));
        _214 = _208;
    }
    else
    {
        _212 = _197;
        _213 = _198;
        _214 = _199;
    }
    float _227;
    int2 _228;
    float _229;
    if (all(_123 < _139))
    {
        bool _219 = _126 > _212;
        float _223;
        if (_219)
        {
            _223 = precise::min(_214, _126);
        }
        else
        {
            _223 = _214;
        }
        _227 = _219 ? _126 : _212;
        _228 = select(_213, _122, bool2(_219));
        _229 = _223;
    }
    else
    {
        _227 = _212;
        _228 = _213;
        _229 = _214;
    }
    float _242;
    int2 _243;
    float _244;
    if (all(_128 < _139))
    {
        bool _234 = _131 > _227;
        float _238;
        if (_234)
        {
            _238 = precise::min(_229, _131);
        }
        else
        {
            _238 = _229;
        }
        _242 = _234 ? _131 : _227;
        _243 = select(_228, _127, bool2(_234));
        _244 = _238;
    }
    else
    {
        _242 = _227;
        _243 = _228;
        _244 = _229;
    }
    float _257;
    int2 _258;
    float _259;
    if (all(_133 < _139))
    {
        bool _249 = _136 > _242;
        float _253;
        if (_249)
        {
            _253 = precise::min(_244, _136);
        }
        else
        {
            _253 = _244;
        }
        _257 = _249 ? _136 : _242;
        _258 = select(_243, _132, bool2(_249));
        _259 = _253;
    }
    else
    {
        _257 = _242;
        _258 = _243;
        _259 = _244;
    }
    float2 _269 = (sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_258)), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float2 _290 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _294 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _290) + (_269 * float(length(_269 * float2(3840.0, 2160.0)) > mix(0.25, 0.75, fast::clamp(precise::min((cbFSR3Upscaler.fDeviceToViewDepth.y / (_257 - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor, 65504.0) * 0.00999999977648258209228515625, 0.0, 1.0))))) * _290) - float2(0.5);
    float2 _295 = floor(_294);
    int2 _296 = int2(_295);
    float2 _297 = _294 - _295;
    float _298 = _297.x;
    float _299 = 1.0 - _298;
    float _300 = _297.y;
    float _301 = 1.0 - _300;
    spvUnsafeArray<float, 4> _306 = spvUnsafeArray<float, 4>({ _299 * _301, _298 * _301, _299 * _300, _298 * _300 });
    spvUnsafeArray<float, 4> _89 = _306;
    for (int _308 = 0; _308 < 4; _308++)
    {
        if (_89[_308] > 0.0006099999882280826568603515625)
        {
            uint2 _322 = uint2(_296 + _86[_308]);
            if (all(_322 < _139))
            {
                uint _329 = rw_reconstructed_previous_nearest_depth.atomic_fetch_max(_322, as_type<uint>(_257)).x;
            }
        }
    }
    sdk_hlsl_store(rw_dilated_motion_vectors, _269.xyyy, uint2(_93));
    sdk_hlsl_store(rw_dilated_depth, float4(_257), uint2(_93));
    sdk_hlsl_store(rw_farthest_depth, float4(precise::min((cbFSR3Upscaler.fDeviceToViewDepth.y / (_259 - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor, 65504.0)), uint2(_93));
    sdk_hlsl_store(rw_current_luma, float4(dot(precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_93), 0u).xyz), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875))), uint2(_93));
}

