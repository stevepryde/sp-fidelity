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

constant spvUnsafeArray<int2, 4> _88 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_depth [[texture(0)]], texture2d<float> r_input_color_jittered [[texture(1)]], texture2d<float> r_input_motion_vectors [[texture(2)]], texture2d<float, access::write> rw_farthest_depth [[texture(3)]], texture2d<float, access::write> rw_current_luma [[texture(4)]], texture2d<uint, access::read_write> rw_reconstructed_previous_nearest_depth [[texture(5)]], texture2d<float, access::write> rw_dilated_depth [[texture(6)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(7)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _95 = uint2(int3(gl_GlobalInvocationID).xy);
    float4 _97 = sdk_hlsl_load(r_input_depth, uint2(_95), 0u);
    float _98 = _97.x;
    int2 _99 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _100 = uint2(_99);
    float4 _102 = sdk_hlsl_load(r_input_depth, uint2(_100), 0u);
    float _103 = _102.x;
    int2 _104 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _105 = uint2(_104);
    float4 _107 = sdk_hlsl_load(r_input_depth, uint2(_105), 0u);
    float _108 = _107.x;
    int2 _109 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _110 = uint2(_109);
    float4 _112 = sdk_hlsl_load(r_input_depth, uint2(_110), 0u);
    float _113 = _112.x;
    int2 _114 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _115 = uint2(_114);
    float4 _117 = sdk_hlsl_load(r_input_depth, uint2(_115), 0u);
    float _118 = _117.x;
    int2 _119 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _120 = uint2(_119);
    float4 _122 = sdk_hlsl_load(r_input_depth, uint2(_120), 0u);
    float _123 = _122.x;
    int2 _124 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _125 = uint2(_124);
    float4 _127 = sdk_hlsl_load(r_input_depth, uint2(_125), 0u);
    float _128 = _127.x;
    int2 _129 = int3(gl_GlobalInvocationID).xy + int2(-1);
    uint2 _130 = uint2(_129);
    float4 _132 = sdk_hlsl_load(r_input_depth, uint2(_130), 0u);
    float _133 = _132.x;
    int2 _134 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _135 = uint2(_134);
    float4 _137 = sdk_hlsl_load(r_input_depth, uint2(_135), 0u);
    float _138 = _137.x;
    uint2 _141 = uint2(cbFSR3Upscaler.iRenderSize);
    float _154;
    int2 _155;
    float _156;
    if (all(_100 < _141))
    {
        bool _146 = _103 > _98;
        float _150;
        if (_146)
        {
            _150 = precise::min(_98, _103);
        }
        else
        {
            _150 = _98;
        }
        _154 = _146 ? _103 : _98;
        _155 = select(int3(gl_GlobalInvocationID).xy, _99, bool2(_146));
        _156 = _150;
    }
    else
    {
        _154 = _98;
        _155 = int3(gl_GlobalInvocationID).xy;
        _156 = _98;
    }
    float _169;
    int2 _170;
    float _171;
    if (all(_105 < _141))
    {
        bool _161 = _108 > _154;
        float _165;
        if (_161)
        {
            _165 = precise::min(_156, _108);
        }
        else
        {
            _165 = _156;
        }
        _169 = _161 ? _108 : _154;
        _170 = select(_155, _104, bool2(_161));
        _171 = _165;
    }
    else
    {
        _169 = _154;
        _170 = _155;
        _171 = _156;
    }
    float _184;
    int2 _185;
    float _186;
    if (all(_110 < _141))
    {
        bool _176 = _113 > _169;
        float _180;
        if (_176)
        {
            _180 = precise::min(_171, _113);
        }
        else
        {
            _180 = _171;
        }
        _184 = _176 ? _113 : _169;
        _185 = select(_170, _109, bool2(_176));
        _186 = _180;
    }
    else
    {
        _184 = _169;
        _185 = _170;
        _186 = _171;
    }
    float _199;
    int2 _200;
    float _201;
    if (all(_115 < _141))
    {
        bool _191 = _118 > _184;
        float _195;
        if (_191)
        {
            _195 = precise::min(_186, _118);
        }
        else
        {
            _195 = _186;
        }
        _199 = _191 ? _118 : _184;
        _200 = select(_185, _114, bool2(_191));
        _201 = _195;
    }
    else
    {
        _199 = _184;
        _200 = _185;
        _201 = _186;
    }
    float _214;
    int2 _215;
    float _216;
    if (all(_120 < _141))
    {
        bool _206 = _123 > _199;
        float _210;
        if (_206)
        {
            _210 = precise::min(_201, _123);
        }
        else
        {
            _210 = _201;
        }
        _214 = _206 ? _123 : _199;
        _215 = select(_200, _119, bool2(_206));
        _216 = _210;
    }
    else
    {
        _214 = _199;
        _215 = _200;
        _216 = _201;
    }
    float _229;
    int2 _230;
    float _231;
    if (all(_125 < _141))
    {
        bool _221 = _128 > _214;
        float _225;
        if (_221)
        {
            _225 = precise::min(_216, _128);
        }
        else
        {
            _225 = _216;
        }
        _229 = _221 ? _128 : _214;
        _230 = select(_215, _124, bool2(_221));
        _231 = _225;
    }
    else
    {
        _229 = _214;
        _230 = _215;
        _231 = _216;
    }
    float _244;
    int2 _245;
    float _246;
    if (all(_130 < _141))
    {
        bool _236 = _133 > _229;
        float _240;
        if (_236)
        {
            _240 = precise::min(_231, _133);
        }
        else
        {
            _240 = _231;
        }
        _244 = _236 ? _133 : _229;
        _245 = select(_230, _129, bool2(_236));
        _246 = _240;
    }
    else
    {
        _244 = _229;
        _245 = _230;
        _246 = _231;
    }
    float _259;
    int2 _260;
    float _261;
    if (all(_135 < _141))
    {
        bool _251 = _138 > _244;
        float _255;
        if (_251)
        {
            _255 = precise::min(_246, _138);
        }
        else
        {
            _255 = _246;
        }
        _259 = _251 ? _138 : _244;
        _260 = select(_245, _134, bool2(_251));
        _261 = _255;
    }
    else
    {
        _259 = _244;
        _260 = _245;
        _261 = _246;
    }
    float2 _267 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _284 = (sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(int2(floor((((float2(_260) + float2(0.5)) - cbFSR3Upscaler.fJitter) / _267) * float2(cbFSR3Upscaler.iUpscaleSize))))), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float2 _308 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _267) + (_284 * float(length(_284 * float2(3840.0, 2160.0)) > mix(0.25, 0.75, fast::clamp(precise::min((cbFSR3Upscaler.fDeviceToViewDepth.y / (_259 - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor, 65504.0) * 0.00999999977648258209228515625, 0.0, 1.0))))) * _267) - float2(0.5);
    float2 _309 = floor(_308);
    int2 _310 = int2(_309);
    float2 _311 = _308 - _309;
    float _312 = _311.x;
    float _313 = 1.0 - _312;
    float _314 = _311.y;
    float _315 = 1.0 - _314;
    spvUnsafeArray<float, 4> _320 = spvUnsafeArray<float, 4>({ _313 * _315, _312 * _315, _313 * _314, _312 * _314 });
    spvUnsafeArray<float, 4> _91 = _320;
    for (int _322 = 0; _322 < 4; _322++)
    {
        if (_91[_322] > 0.0006099999882280826568603515625)
        {
            uint2 _336 = uint2(_310 + _88[_322]);
            if (all(_336 < _141))
            {
                uint _343 = rw_reconstructed_previous_nearest_depth.atomic_fetch_max(_336, as_type<uint>(_259)).x;
            }
        }
    }
    sdk_hlsl_store(rw_dilated_motion_vectors, _284.xyyy, uint2(_95));
    sdk_hlsl_store(rw_dilated_depth, float4(_259), uint2(_95));
    sdk_hlsl_store(rw_farthest_depth, float4(precise::min((cbFSR3Upscaler.fDeviceToViewDepth.y / (_261 - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor, 65504.0)), uint2(_95));
    sdk_hlsl_store(rw_current_luma, float4(dot(precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_95), 0u).xyz), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875))), uint2(_95));
}

