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

struct type_cbFI
{
    int2 renderSize;
    int2 displaySize;
    float2 displaySizeRcp;
    float cameraNear;
    float cameraFar;
    int2 upscalerTargetSize;
    int Mode;
    int reset;
    float4 fDeviceToViewDepth;
    float deltaTime;
    int HUDLessAttachedFactor;
    int2 distortionFieldSize;
    float2 opticalFlowScale;
    int opticalFlowBlockSize;
    uint dispatchFlags;
    int2 maxRenderSize;
    int opticalFlowHalfResMode;
    int NumInstances;
    int2 interpolationRectBase;
    int2 interpolationRectSize;
    packed_float3 debugBarColor;
    uint backBufferTransferFunction;
    float2 minMaxLuminance;
    float fTanHalfFOV;
    int _pad1;
    float2 fJitter;
    float2 fMotionVectorScale;
};

constant spvUnsafeArray<int2, 4> _66 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_input_depth [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(2)]], texture2d<float, access::write> rw_dilated_depth [[texture(3)]], texture2d<uint, access::read_write> rw_reconstructed_depth_previous_frame [[texture(4)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _74 = uint2(int3(gl_GlobalInvocationID).xy);
    float4 _76 = sdk_hlsl_load(r_input_depth, uint2(_74), 0u);
    float _77 = _76.x;
    int2 _78 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _79 = uint2(_78);
    float4 _81 = sdk_hlsl_load(r_input_depth, uint2(_79), 0u);
    float _82 = _81.x;
    int2 _83 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _84 = uint2(_83);
    float4 _86 = sdk_hlsl_load(r_input_depth, uint2(_84), 0u);
    float _87 = _86.x;
    int2 _88 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _89 = uint2(_88);
    float4 _91 = sdk_hlsl_load(r_input_depth, uint2(_89), 0u);
    float _92 = _91.x;
    int2 _93 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _94 = uint2(_93);
    float4 _96 = sdk_hlsl_load(r_input_depth, uint2(_94), 0u);
    float _97 = _96.x;
    int2 _98 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _99 = uint2(_98);
    float4 _101 = sdk_hlsl_load(r_input_depth, uint2(_99), 0u);
    float _102 = _101.x;
    int2 _103 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _104 = uint2(_103);
    float4 _106 = sdk_hlsl_load(r_input_depth, uint2(_104), 0u);
    float _107 = _106.x;
    int2 _108 = int3(gl_GlobalInvocationID).xy + int2(-1);
    uint2 _109 = uint2(_108);
    float4 _111 = sdk_hlsl_load(r_input_depth, uint2(_109), 0u);
    float _112 = _111.x;
    int2 _113 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _114 = uint2(_113);
    float4 _116 = sdk_hlsl_load(r_input_depth, uint2(_114), 0u);
    float _117 = _116.x;
    uint2 _118 = uint2(cbFI.renderSize);
    float _127;
    int2 _128;
    if (all(_79 < _118))
    {
        bool _123 = _82 > _77;
        _127 = _123 ? _82 : _77;
        _128 = select(int3(gl_GlobalInvocationID).xy, _78, bool2(_123));
    }
    else
    {
        _127 = _77;
        _128 = int3(gl_GlobalInvocationID).xy;
    }
    float _137;
    int2 _138;
    if (all(_84 < _118))
    {
        bool _133 = _87 > _127;
        _137 = _133 ? _87 : _127;
        _138 = select(_128, _83, bool2(_133));
    }
    else
    {
        _137 = _127;
        _138 = _128;
    }
    float _147;
    int2 _148;
    if (all(_89 < _118))
    {
        bool _143 = _92 > _137;
        _147 = _143 ? _92 : _137;
        _148 = select(_138, _88, bool2(_143));
    }
    else
    {
        _147 = _137;
        _148 = _138;
    }
    float _157;
    int2 _158;
    if (all(_94 < _118))
    {
        bool _153 = _97 > _147;
        _157 = _153 ? _97 : _147;
        _158 = select(_148, _93, bool2(_153));
    }
    else
    {
        _157 = _147;
        _158 = _148;
    }
    float _167;
    int2 _168;
    if (all(_99 < _118))
    {
        bool _163 = _102 > _157;
        _167 = _163 ? _102 : _157;
        _168 = select(_158, _98, bool2(_163));
    }
    else
    {
        _167 = _157;
        _168 = _158;
    }
    float _177;
    int2 _178;
    if (all(_104 < _118))
    {
        bool _173 = _107 > _167;
        _177 = _173 ? _107 : _167;
        _178 = select(_168, _103, bool2(_173));
    }
    else
    {
        _177 = _167;
        _178 = _168;
    }
    float _187;
    int2 _188;
    if (all(_109 < _118))
    {
        bool _183 = _112 > _177;
        _187 = _183 ? _112 : _177;
        _188 = select(_178, _108, bool2(_183));
    }
    else
    {
        _187 = _177;
        _188 = _178;
    }
    float _197;
    int2 _198;
    if (all(_114 < _118))
    {
        bool _193 = _117 > _187;
        _197 = _193 ? _117 : _187;
        _198 = select(_188, _113, bool2(_193));
    }
    else
    {
        _197 = _187;
        _198 = _188;
    }
    float2 _205 = sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_198)), 0u).xy * cbFI.fMotionVectorScale;
    sdk_hlsl_store(rw_dilated_depth, float4(_197), uint2(_74));
    sdk_hlsl_store(rw_dilated_motion_vectors, _205.xyyy, uint2(_74));
    float2 _218 = float2(cbFI.renderSize);
    float2 _222 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _218) + (_205 * float(length(_205 * float2(cbFI.displaySize)) > 0.100000001490116119384765625))) * _218) - float2(0.5);
    float2 _223 = floor(_222);
    int2 _224 = int2(_223);
    float2 _225 = _222 - _223;
    float _226 = _225.x;
    float _227 = 1.0 - _226;
    float _228 = _225.y;
    float _229 = 1.0 - _228;
    spvUnsafeArray<float, 4> _234 = spvUnsafeArray<float, 4>({ _227 * _229, _226 * _229, _227 * _228, _226 * _228 });
    spvUnsafeArray<float, 4> _68 = _234;
    for (int _236 = 0; _236 < 4; _236++)
    {
        if (_68[_236] > 0.001000000047497451305389404296875)
        {
            uint2 _250 = uint2(_224 + _66[_236]);
            if (all(_250 < _118))
            {
                uint _257 = rw_reconstructed_depth_previous_frame.atomic_fetch_max(_250, as_type<uint>(_197)).x;
            }
        }
    }
}

