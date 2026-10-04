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

constant spvUnsafeArray<int2, 4> _84 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_depth [[texture(2)]], texture2d<float> r_input_exposure [[texture(3)]], texture2d<uint, access::read_write> rw_reconstructed_previous_nearest_depth [[texture(4)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(5)]], texture2d<float, access::write> rw_dilatedDepth [[texture(6)]], texture2d<float, access::write> rw_lock_input_luma [[texture(7)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
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
    uint2 _139 = uint2(cbFSR2.iRenderSize);
    float _148;
    int2 _149;
    if (all(_100 < _139))
    {
        bool _144 = _103 > _98;
        _148 = _144 ? _103 : _98;
        _149 = select(int3(gl_GlobalInvocationID).xy, _99, bool2(_144));
    }
    else
    {
        _148 = _98;
        _149 = int3(gl_GlobalInvocationID).xy;
    }
    float _158;
    int2 _159;
    if (all(_105 < _139))
    {
        bool _154 = _108 > _148;
        _158 = _154 ? _108 : _148;
        _159 = select(_149, _104, bool2(_154));
    }
    else
    {
        _158 = _148;
        _159 = _149;
    }
    float _168;
    int2 _169;
    if (all(_110 < _139))
    {
        bool _164 = _113 > _158;
        _168 = _164 ? _113 : _158;
        _169 = select(_159, _109, bool2(_164));
    }
    else
    {
        _168 = _158;
        _169 = _159;
    }
    float _178;
    int2 _179;
    if (all(_115 < _139))
    {
        bool _174 = _118 > _168;
        _178 = _174 ? _118 : _168;
        _179 = select(_169, _114, bool2(_174));
    }
    else
    {
        _178 = _168;
        _179 = _169;
    }
    float _188;
    int2 _189;
    if (all(_120 < _139))
    {
        bool _184 = _123 > _178;
        _188 = _184 ? _123 : _178;
        _189 = select(_179, _119, bool2(_184));
    }
    else
    {
        _188 = _178;
        _189 = _179;
    }
    float _198;
    int2 _199;
    if (all(_125 < _139))
    {
        bool _194 = _128 > _188;
        _198 = _194 ? _128 : _188;
        _199 = select(_189, _124, bool2(_194));
    }
    else
    {
        _198 = _188;
        _199 = _189;
    }
    float _208;
    int2 _209;
    if (all(_130 < _139))
    {
        bool _204 = _133 > _198;
        _208 = _204 ? _133 : _198;
        _209 = select(_199, _129, bool2(_204));
    }
    else
    {
        _208 = _198;
        _209 = _199;
    }
    float _218;
    int2 _219;
    if (all(_135 < _139))
    {
        bool _214 = _138 > _208;
        _218 = _214 ? _138 : _208;
        _219 = select(_209, _134, bool2(_214));
    }
    else
    {
        _218 = _208;
        _219 = _209;
    }
    float2 _229 = (sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_219)), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
    sdk_hlsl_store(rw_dilatedDepth, float4(_218), uint2(_95));
    sdk_hlsl_store(rw_dilated_motion_vectors, _229.xyyy, uint2(_95));
    float2 _242 = float2(cbFSR2.iRenderSize);
    float2 _246 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _242) + (_229 * float(length(_229 * float2(cbFSR2.iDisplaySize)) > 0.100000001490116119384765625))) * _242) - float2(0.5);
    float2 _247 = floor(_246);
    int2 _248 = int2(_247);
    float2 _249 = _246 - _247;
    float _250 = _249.x;
    float _251 = 1.0 - _250;
    float _252 = _249.y;
    float _253 = 1.0 - _252;
    spvUnsafeArray<float, 4> _258 = spvUnsafeArray<float, 4>({ _251 * _253, _250 * _253, _251 * _252, _250 * _252 });
    spvUnsafeArray<float, 4> _89 = _258;
    for (int _260 = 0; _260 < 4; _260++)
    {
        if (_89[_260] > 0.00999999977648258209228515625)
        {
            uint2 _274 = uint2(_248 + _84[_260]);
            if (all(_274 < _139))
            {
                uint _281 = rw_reconstructed_previous_nearest_depth.atomic_fetch_max(_274, as_type<uint>(_218)).x;
            }
        }
    }
    float4 _291 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _292 = _291.x;
    float _296 = dot((precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_95), 0u).xyz) / float3(cbFSR2.fPreExposure)) * ((_292 == 0.0) ? 1.0 : _292), float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
    float _305;
    if (_296 <= 0.008856452070176601409912109375)
    {
        _305 = _296 * 903.29632568359375;
    }
    else
    {
        _305 = (powr(_296, 0.3333333432674407958984375) * 116.0) - 16.0;
    }
    sdk_hlsl_store(rw_lock_input_luma, float4(powr(_305 * 0.00999999977648258209228515625, 0.16666667163372039794921875)), uint2(_95));
}

