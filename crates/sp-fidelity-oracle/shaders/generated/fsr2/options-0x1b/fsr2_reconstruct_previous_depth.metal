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

constant spvUnsafeArray<int2, 4> _85 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_depth [[texture(2)]], texture2d<float> r_input_exposure [[texture(3)]], texture2d<uint, access::read_write> rw_reconstructed_previous_nearest_depth [[texture(4)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(5)]], texture2d<float, access::write> rw_dilatedDepth [[texture(6)]], texture2d<float, access::write> rw_lock_input_luma [[texture(7)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _96 = uint2(int3(gl_GlobalInvocationID).xy);
    float4 _98 = sdk_hlsl_load(r_input_depth, uint2(_96), 0u);
    float _99 = _98.x;
    int2 _100 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _101 = uint2(_100);
    float4 _103 = sdk_hlsl_load(r_input_depth, uint2(_101), 0u);
    float _104 = _103.x;
    int2 _105 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _106 = uint2(_105);
    float4 _108 = sdk_hlsl_load(r_input_depth, uint2(_106), 0u);
    float _109 = _108.x;
    int2 _110 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _111 = uint2(_110);
    float4 _113 = sdk_hlsl_load(r_input_depth, uint2(_111), 0u);
    float _114 = _113.x;
    int2 _115 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _116 = uint2(_115);
    float4 _118 = sdk_hlsl_load(r_input_depth, uint2(_116), 0u);
    float _119 = _118.x;
    int2 _120 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _121 = uint2(_120);
    float4 _123 = sdk_hlsl_load(r_input_depth, uint2(_121), 0u);
    float _124 = _123.x;
    int2 _125 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _126 = uint2(_125);
    float4 _128 = sdk_hlsl_load(r_input_depth, uint2(_126), 0u);
    float _129 = _128.x;
    int2 _130 = int3(gl_GlobalInvocationID).xy + int2(-1);
    uint2 _131 = uint2(_130);
    float4 _133 = sdk_hlsl_load(r_input_depth, uint2(_131), 0u);
    float _134 = _133.x;
    int2 _135 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _136 = uint2(_135);
    float4 _138 = sdk_hlsl_load(r_input_depth, uint2(_136), 0u);
    float _139 = _138.x;
    uint2 _140 = uint2(cbFSR2.iRenderSize);
    float _149;
    int2 _150;
    if (all(_101 < _140))
    {
        bool _145 = _104 > _99;
        _149 = _145 ? _104 : _99;
        _150 = select(int3(gl_GlobalInvocationID).xy, _100, bool2(_145));
    }
    else
    {
        _149 = _99;
        _150 = int3(gl_GlobalInvocationID).xy;
    }
    float _159;
    int2 _160;
    if (all(_106 < _140))
    {
        bool _155 = _109 > _149;
        _159 = _155 ? _109 : _149;
        _160 = select(_150, _105, bool2(_155));
    }
    else
    {
        _159 = _149;
        _160 = _150;
    }
    float _169;
    int2 _170;
    if (all(_111 < _140))
    {
        bool _165 = _114 > _159;
        _169 = _165 ? _114 : _159;
        _170 = select(_160, _110, bool2(_165));
    }
    else
    {
        _169 = _159;
        _170 = _160;
    }
    float _179;
    int2 _180;
    if (all(_116 < _140))
    {
        bool _175 = _119 > _169;
        _179 = _175 ? _119 : _169;
        _180 = select(_170, _115, bool2(_175));
    }
    else
    {
        _179 = _169;
        _180 = _170;
    }
    float _189;
    int2 _190;
    if (all(_121 < _140))
    {
        bool _185 = _124 > _179;
        _189 = _185 ? _124 : _179;
        _190 = select(_180, _120, bool2(_185));
    }
    else
    {
        _189 = _179;
        _190 = _180;
    }
    float _199;
    int2 _200;
    if (all(_126 < _140))
    {
        bool _195 = _129 > _189;
        _199 = _195 ? _129 : _189;
        _200 = select(_190, _125, bool2(_195));
    }
    else
    {
        _199 = _189;
        _200 = _190;
    }
    float _209;
    int2 _210;
    if (all(_131 < _140))
    {
        bool _205 = _134 > _199;
        _209 = _205 ? _134 : _199;
        _210 = select(_200, _130, bool2(_205));
    }
    else
    {
        _209 = _199;
        _210 = _200;
    }
    float _219;
    int2 _220;
    if (all(_136 < _140))
    {
        bool _215 = _139 > _209;
        _219 = _215 ? _139 : _209;
        _220 = select(_210, _135, bool2(_215));
    }
    else
    {
        _219 = _209;
        _220 = _210;
    }
    float2 _226 = float2(cbFSR2.iRenderSize);
    float2 _230 = float2(cbFSR2.iDisplaySize);
    float2 _243 = (sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(int2(floor((((float2(_220) + float2(0.5)) - cbFSR2.fJitter) / _226) * _230)))), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
    sdk_hlsl_store(rw_dilatedDepth, float4(_219), uint2(_96));
    sdk_hlsl_store(rw_dilated_motion_vectors, _243.xyyy, uint2(_96));
    float2 _256 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _226) + (_243 * float(length(_243 * _230) > 0.100000001490116119384765625))) * _226) - float2(0.5);
    float2 _257 = floor(_256);
    int2 _258 = int2(_257);
    float2 _259 = _256 - _257;
    float _260 = _259.x;
    float _261 = 1.0 - _260;
    float _262 = _259.y;
    float _263 = 1.0 - _262;
    spvUnsafeArray<float, 4> _268 = spvUnsafeArray<float, 4>({ _261 * _263, _260 * _263, _261 * _262, _260 * _262 });
    spvUnsafeArray<float, 4> _90 = _268;
    for (int _270 = 0; _270 < 4; _270++)
    {
        if (_90[_270] > 0.00999999977648258209228515625)
        {
            uint2 _284 = uint2(_258 + _85[_270]);
            if (all(_284 < _140))
            {
                uint _291 = rw_reconstructed_previous_nearest_depth.atomic_fetch_max(_284, as_type<uint>(_219)).x;
            }
        }
    }
    float4 _301 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _302 = _301.x;
    float3 _305 = (precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_96), 0u).xyz) / float3(cbFSR2.fPreExposure)) * ((_302 == 0.0) ? 1.0 : _302);
    float _315 = dot(_305 / float3(precise::max(precise::max(0.0, _305.x), precise::max(_305.y, _305.z)) + 1.0), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float _324;
    if (_315 <= 0.008856452070176601409912109375)
    {
        _324 = _315 * 903.29632568359375;
    }
    else
    {
        _324 = (powr(_315, 0.3333333432674407958984375) * 116.0) - 16.0;
    }
    sdk_hlsl_store(rw_lock_input_luma, float4(powr(_324 * 0.00999999977648258209228515625, 0.16666667163372039794921875)), uint2(_96));
}

