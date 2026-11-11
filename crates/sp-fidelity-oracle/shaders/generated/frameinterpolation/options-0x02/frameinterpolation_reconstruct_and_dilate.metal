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

constant spvUnsafeArray<int2, 4> _67 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_input_depth [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float, access::write> rw_dilated_motion_vectors [[texture(2)]], texture2d<float, access::write> rw_dilated_depth [[texture(3)]], texture2d<uint, access::read_write> rw_reconstructed_depth_previous_frame [[texture(4)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _75 = uint2(int3(gl_GlobalInvocationID).xy);
    float4 _77 = sdk_hlsl_load(r_input_depth, uint2(_75), 0u);
    float _78 = _77.x;
    int2 _79 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _80 = uint2(_79);
    float4 _82 = sdk_hlsl_load(r_input_depth, uint2(_80), 0u);
    float _83 = _82.x;
    int2 _84 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _85 = uint2(_84);
    float4 _87 = sdk_hlsl_load(r_input_depth, uint2(_85), 0u);
    float _88 = _87.x;
    int2 _89 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _90 = uint2(_89);
    float4 _92 = sdk_hlsl_load(r_input_depth, uint2(_90), 0u);
    float _93 = _92.x;
    int2 _94 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _95 = uint2(_94);
    float4 _97 = sdk_hlsl_load(r_input_depth, uint2(_95), 0u);
    float _98 = _97.x;
    int2 _99 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _100 = uint2(_99);
    float4 _102 = sdk_hlsl_load(r_input_depth, uint2(_100), 0u);
    float _103 = _102.x;
    int2 _104 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _105 = uint2(_104);
    float4 _107 = sdk_hlsl_load(r_input_depth, uint2(_105), 0u);
    float _108 = _107.x;
    int2 _109 = int3(gl_GlobalInvocationID).xy + int2(-1);
    uint2 _110 = uint2(_109);
    float4 _112 = sdk_hlsl_load(r_input_depth, uint2(_110), 0u);
    float _113 = _112.x;
    int2 _114 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _115 = uint2(_114);
    float4 _117 = sdk_hlsl_load(r_input_depth, uint2(_115), 0u);
    float _118 = _117.x;
    uint2 _119 = uint2(cbFI.renderSize);
    float _128;
    int2 _129;
    if (all(_80 < _119))
    {
        bool _124 = _83 < _78;
        _128 = _124 ? _83 : _78;
        _129 = select(int3(gl_GlobalInvocationID).xy, _79, bool2(_124));
    }
    else
    {
        _128 = _78;
        _129 = int3(gl_GlobalInvocationID).xy;
    }
    float _138;
    int2 _139;
    if (all(_85 < _119))
    {
        bool _134 = _88 < _128;
        _138 = _134 ? _88 : _128;
        _139 = select(_129, _84, bool2(_134));
    }
    else
    {
        _138 = _128;
        _139 = _129;
    }
    float _148;
    int2 _149;
    if (all(_90 < _119))
    {
        bool _144 = _93 < _138;
        _148 = _144 ? _93 : _138;
        _149 = select(_139, _89, bool2(_144));
    }
    else
    {
        _148 = _138;
        _149 = _139;
    }
    float _158;
    int2 _159;
    if (all(_95 < _119))
    {
        bool _154 = _98 < _148;
        _158 = _154 ? _98 : _148;
        _159 = select(_149, _94, bool2(_154));
    }
    else
    {
        _158 = _148;
        _159 = _149;
    }
    float _168;
    int2 _169;
    if (all(_100 < _119))
    {
        bool _164 = _103 < _158;
        _168 = _164 ? _103 : _158;
        _169 = select(_159, _99, bool2(_164));
    }
    else
    {
        _168 = _158;
        _169 = _159;
    }
    float _178;
    int2 _179;
    if (all(_105 < _119))
    {
        bool _174 = _108 < _168;
        _178 = _174 ? _108 : _168;
        _179 = select(_169, _104, bool2(_174));
    }
    else
    {
        _178 = _168;
        _179 = _169;
    }
    float _188;
    int2 _189;
    if (all(_110 < _119))
    {
        bool _184 = _113 < _178;
        _188 = _184 ? _113 : _178;
        _189 = select(_179, _109, bool2(_184));
    }
    else
    {
        _188 = _178;
        _189 = _179;
    }
    float _198;
    int2 _199;
    if (all(_115 < _119))
    {
        bool _194 = _118 < _188;
        _198 = _194 ? _118 : _188;
        _199 = select(_189, _114, bool2(_194));
    }
    else
    {
        _198 = _188;
        _199 = _189;
    }
    float2 _205 = float2(cbFI.renderSize);
    float2 _209 = float2(cbFI.displaySize);
    float2 _219 = sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(int2(floor((((float2(_199) + float2(0.5)) - cbFI.fJitter) / _205) * _209)))), 0u).xy * cbFI.fMotionVectorScale;
    sdk_hlsl_store(rw_dilated_depth, float4(_198), uint2(_75));
    sdk_hlsl_store(rw_dilated_motion_vectors, _219.xyyy, uint2(_75));
    float2 _232 = ((((float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _205) + (_219 * float(length(_219 * _209) > 0.100000001490116119384765625))) * _205) - float2(0.5);
    float2 _233 = floor(_232);
    int2 _234 = int2(_233);
    float2 _235 = _232 - _233;
    float _236 = _235.x;
    float _237 = 1.0 - _236;
    float _238 = _235.y;
    float _239 = 1.0 - _238;
    spvUnsafeArray<float, 4> _244 = spvUnsafeArray<float, 4>({ _237 * _239, _236 * _239, _237 * _238, _236 * _238 });
    spvUnsafeArray<float, 4> _69 = _244;
    for (int _246 = 0; _246 < 4; _246++)
    {
        if (_69[_246] > 0.001000000047497451305389404296875)
        {
            uint2 _260 = uint2(_234 + _67[_246]);
            if (all(_260 < _119))
            {
                uint _267 = rw_reconstructed_depth_previous_frame.atomic_fetch_min(_260, as_type<uint>(_198)).x;
            }
        }
    }
}

