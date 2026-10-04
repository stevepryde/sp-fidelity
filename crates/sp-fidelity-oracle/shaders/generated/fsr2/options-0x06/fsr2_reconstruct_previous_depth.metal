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

constant spvUnsafeArray<int2, 4> _83 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_depth [[texture(2)]], texture2d<float> r_input_exposure [[texture(3)]], texture2d<uint, access::read_write> rw_reconstructed_previous_nearest_depth [[texture(4)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(5)]], texture2d<float, access::write> rw_dilatedDepth [[texture(6)]], texture2d<float, access::write> rw_lock_input_luma [[texture(7)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _94 = uint2(int3(gl_GlobalInvocationID).xy);
    float4 _96 = sdk_hlsl_load(r_input_depth, uint2(_94), 0u);
    float _97 = _96.x;
    int2 _98 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _99 = uint2(_98);
    float4 _101 = sdk_hlsl_load(r_input_depth, uint2(_99), 0u);
    float _102 = _101.x;
    int2 _103 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _104 = uint2(_103);
    float4 _106 = sdk_hlsl_load(r_input_depth, uint2(_104), 0u);
    float _107 = _106.x;
    int2 _108 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _109 = uint2(_108);
    float4 _111 = sdk_hlsl_load(r_input_depth, uint2(_109), 0u);
    float _112 = _111.x;
    int2 _113 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _114 = uint2(_113);
    float4 _116 = sdk_hlsl_load(r_input_depth, uint2(_114), 0u);
    float _117 = _116.x;
    int2 _118 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _119 = uint2(_118);
    float4 _121 = sdk_hlsl_load(r_input_depth, uint2(_119), 0u);
    float _122 = _121.x;
    int2 _123 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _124 = uint2(_123);
    float4 _126 = sdk_hlsl_load(r_input_depth, uint2(_124), 0u);
    float _127 = _126.x;
    int2 _128 = int3(gl_GlobalInvocationID).xy + int2(-1);
    uint2 _129 = uint2(_128);
    float4 _131 = sdk_hlsl_load(r_input_depth, uint2(_129), 0u);
    float _132 = _131.x;
    int2 _133 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _134 = uint2(_133);
    float4 _136 = sdk_hlsl_load(r_input_depth, uint2(_134), 0u);
    float _137 = _136.x;
    uint2 _138 = uint2(cbFSR2.iRenderSize);
    float _147;
    int2 _148;
    if (all(_99 < _138))
    {
        bool _143 = _102 < _97;
        _147 = _143 ? _102 : _97;
        _148 = select(int3(gl_GlobalInvocationID).xy, _98, bool2(_143));
    }
    else
    {
        _147 = _97;
        _148 = int3(gl_GlobalInvocationID).xy;
    }
    float _157;
    int2 _158;
    if (all(_104 < _138))
    {
        bool _153 = _107 < _147;
        _157 = _153 ? _107 : _147;
        _158 = select(_148, _103, bool2(_153));
    }
    else
    {
        _157 = _147;
        _158 = _148;
    }
    float _167;
    int2 _168;
    if (all(_109 < _138))
    {
        bool _163 = _112 < _157;
        _167 = _163 ? _112 : _157;
        _168 = select(_158, _108, bool2(_163));
    }
    else
    {
        _167 = _157;
        _168 = _158;
    }
    float _177;
    int2 _178;
    if (all(_114 < _138))
    {
        bool _173 = _117 < _167;
        _177 = _173 ? _117 : _167;
        _178 = select(_168, _113, bool2(_173));
    }
    else
    {
        _177 = _167;
        _178 = _168;
    }
    float _187;
    int2 _188;
    if (all(_119 < _138))
    {
        bool _183 = _122 < _177;
        _187 = _183 ? _122 : _177;
        _188 = select(_178, _118, bool2(_183));
    }
    else
    {
        _187 = _177;
        _188 = _178;
    }
    float _197;
    int2 _198;
    if (all(_124 < _138))
    {
        bool _193 = _127 < _187;
        _197 = _193 ? _127 : _187;
        _198 = select(_188, _123, bool2(_193));
    }
    else
    {
        _197 = _187;
        _198 = _188;
    }
    float _207;
    int2 _208;
    if (all(_129 < _138))
    {
        bool _203 = _132 < _197;
        _207 = _203 ? _132 : _197;
        _208 = select(_198, _128, bool2(_203));
    }
    else
    {
        _207 = _197;
        _208 = _198;
    }
    float _217;
    int2 _218;
    if (all(_134 < _138))
    {
        bool _213 = _137 < _207;
        _217 = _213 ? _137 : _207;
        _218 = select(_208, _133, bool2(_213));
    }
    else
    {
        _217 = _207;
        _218 = _208;
    }
    float2 _225 = sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_218)), 0u).xy * cbFSR2.fMotionVectorScale;
    sdk_hlsl_store(rw_dilatedDepth, float4(_217), uint2(_94));
    sdk_hlsl_store(rw_dilated_motion_vectors, _225.xyyy, uint2(_94));
    float2 _238 = float2(cbFSR2.iRenderSize);
    float2 _242 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _238) + (_225 * float(length(_225 * float2(cbFSR2.iDisplaySize)) > 0.100000001490116119384765625))) * _238) - float2(0.5);
    float2 _243 = floor(_242);
    int2 _244 = int2(_243);
    float2 _245 = _242 - _243;
    float _246 = _245.x;
    float _247 = 1.0 - _246;
    float _248 = _245.y;
    float _249 = 1.0 - _248;
    spvUnsafeArray<float, 4> _254 = spvUnsafeArray<float, 4>({ _247 * _249, _246 * _249, _247 * _248, _246 * _248 });
    spvUnsafeArray<float, 4> _88 = _254;
    for (int _256 = 0; _256 < 4; _256++)
    {
        if (_88[_256] > 0.00999999977648258209228515625)
        {
            uint2 _270 = uint2(_244 + _83[_256]);
            if (all(_270 < _138))
            {
                uint _277 = rw_reconstructed_previous_nearest_depth.atomic_fetch_min(_270, as_type<uint>(_217)).x;
            }
        }
    }
    float4 _287 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _288 = _287.x;
    float3 _291 = (precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_94), 0u).xyz) / float3(cbFSR2.fPreExposure)) * ((_288 == 0.0) ? 1.0 : _288);
    float _301 = dot(_291 / float3(precise::max(precise::max(0.0, _291.x), precise::max(_291.y, _291.z)) + 1.0), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float _310;
    if (_301 <= 0.008856452070176601409912109375)
    {
        _310 = _301 * 903.29632568359375;
    }
    else
    {
        _310 = (powr(_301, 0.3333333432674407958984375) * 116.0) - 16.0;
    }
    sdk_hlsl_store(rw_lock_input_luma, float4(powr(_310 * 0.00999999977648258209228515625, 0.16666667163372039794921875)), uint2(_94));
}

