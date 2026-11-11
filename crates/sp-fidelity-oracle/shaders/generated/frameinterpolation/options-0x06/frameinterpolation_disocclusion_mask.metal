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

constant spvUnsafeArray<int2, 4> _79 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_dilated_depth [[texture(0)]], texture2d<uint> r_reconstructed_depth_previous_frame [[texture(1)]], texture2d<uint> r_reconstructed_depth_interpolated_frame [[texture(2)]], texture2d<uint> r_game_motion_vector_field_x [[texture(3)]], texture2d<uint> r_game_motion_vector_field_y [[texture(4)]], texture2d<float> r_inpainting_pyramid [[texture(5)]], texture2d<float> r_input_distortion_field [[texture(6)]], texture2d<float, access::write> rw_disocclusion_mask [[texture(7)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _91 = uint2(int3(gl_GlobalInvocationID).xy);
    float _95 = as_type<float>(sdk_hlsl_load(r_reconstructed_depth_interpolated_frame, uint2(_91), 0u).x);
    float2 _97 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _100 = float2(cbFI.renderSize);
    float2 _101 = _97 / _100;
    uint2 _103 = uint2(int2(_97));
    uint4 _105 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_103), 0u);
    uint _106 = _105.x;
    float _113 = float((_106 >> 21u) & 1023u) * 0.000977517105638980865478515625;
    float2 _193;
    if ((isunordered(_113, 0.0) || _113 <= 0.0))
    {
        float4 _125;
        int2 _128;
        _125 = float4(0.0);
        _128 = cbFI.renderSize;
        float4 _126;
        int2 _129;
        int _130 = 0;
        for (;;)
        {
            bool _139;
            if (_130 < 11)
            {
                _139 = _125.w == 0.0;
            }
            else
            {
                _139 = false;
            }
            if (_139)
            {
                _129 = _128 / int2(2);
                float2 _143 = (_101 * float2(_129)) - float2(0.5);
                float2 _144 = floor(_143);
                int2 _145 = int2(_144);
                float2 _146 = _143 - _144;
                float _147 = _146.x;
                float _148 = 1.0 - _147;
                float _149 = _146.y;
                float _150 = 1.0 - _149;
                spvUnsafeArray<float, 4> _155 = spvUnsafeArray<float, 4>({ _148 * _150, _147 * _150, _148 * _149, _147 * _149 });
                spvUnsafeArray<float, 4> _83 = _155;
                float4 _157;
                float _160;
                _157 = float4(0.0);
                _160 = 0.0;
                float4 _158;
                float _161;
                for (int _162 = 0; _162 < 4; _157 = _158, _160 = _161, _162++)
                {
                    uint2 _170 = uint2(_145 + _79[_162]);
                    if (all(_170 < uint2(_129)))
                    {
                        float4 _178 = sdk_hlsl_load(r_inpainting_pyramid, uint2(_170), uint(_130));
                        float _179 = _178.z;
                        float _185 = (_83[_162] * float(_179 > 0.0)) * _179;
                        _158 = _157 + (_178 * _185);
                        _161 = _160 + _185;
                    }
                    else
                    {
                        _158 = _157;
                        _161 = _160;
                    }
                }
                _126 = _157 / float4((_160 > 0.0) ? _160 : 1.0);
                _125 = _126;
                _128 = _129;
                _130++;
                continue;
            }
            else
            {
                break;
            }
        }
        _193 = _125.xy;
    }
    else
    {
        _193 = float2(float2(as_type<half2>(_106 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_103), 0u).x & 65535u)).x);
    }
    float _200 = cbFI.fDeviceToViewDepth.y / (_95 - cbFI.fDeviceToViewDepth.x);
    float2 _202 = ((_101 + _193) * _100) - float2(0.5);
    float2 _203 = floor(_202);
    int2 _204 = int2(_203);
    float2 _205 = _202 - _203;
    float _206 = _205.x;
    float _207 = 1.0 - _206;
    float _208 = _205.y;
    float _209 = 1.0 - _208;
    spvUnsafeArray<float, 4> _214 = spvUnsafeArray<float, 4>({ _207 * _209, _206 * _209, _207 * _208, _206 * _208 });
    spvUnsafeArray<float, 4> _85 = _214;
    float _216;
    float _219;
    _216 = 0.0;
    _219 = 0.0;
    float _217;
    float _220;
    for (int _221 = 0; _221 < 4; _216 = _217, _219 = _220, _221++)
    {
        int2 _228 = _204 + _79[_221];
        if (all(uint2(_228) < uint2(cbFI.renderSize)))
        {
            float _300;
            float _301;
            if (_85[_221] > 0.001000000047497451305389404296875)
            {
                float _255 = as_type<float>(sdk_hlsl_load(r_reconstructed_depth_previous_frame, uint2(uint2(_228 + int2(r_input_distortion_field.sample(s_LinearClamp, ((float2(_228) + float2(0.5)) / _100), level(0.0)).xy * _100))), 0u).x);
                float _257 = cbFI.fDeviceToViewDepth.y / (_255 - cbFI.fDeviceToViewDepth.x);
                float _258 = _200 - _257;
                float _298;
                float _299;
                if (_258 > 0.0)
                {
                    float _266 = cbFI.fDeviceToViewDepth.y / (precise::min(_255, _95) - cbFI.fDeviceToViewDepth.x);
                    float2 _270 = ((float2(int2(_100 * 0.5)) / _100) * float2(2.0, -2.0)) + float2(-1.0, 1.0);
                    _298 = _216 + (float(((((1.3699999726668465882539749145508e-05 * (length(float3((cbFI.fDeviceToViewDepth.z * (-1.0)) * _266, cbFI.fDeviceToViewDepth.w * _266, _266)) / length(float3((cbFI.fDeviceToViewDepth.z * _270.x) * _266, (cbFI.fDeviceToViewDepth.w * _270.y) * _266, _266)))) * length(_100)) * precise::min(_200, _257)) / _258) >= 1.0) * _85[_221]);
                    _299 = _219 + _85[_221];
                }
                else
                {
                    _298 = _216;
                    _299 = _219;
                }
                _300 = _298;
                _301 = _299;
            }
            else
            {
                _300 = _216;
                _301 = _219;
            }
            _217 = _300;
            _220 = _301;
        }
        else
        {
            _217 = _216;
            _220 = _219;
        }
    }
    float _309;
    if (_219 > 0.0)
    {
        _309 = fast::clamp(1.0 - (_216 / _219), 0.0, 1.0);
    }
    else
    {
        _309 = 0.0;
    }
    float2 _313 = ((_101 - _193) * _100) - float2(0.5);
    float2 _314 = floor(_313);
    int2 _315 = int2(_314);
    float2 _316 = _313 - _314;
    float _317 = _316.x;
    float _318 = 1.0 - _317;
    float _319 = _316.y;
    float _320 = 1.0 - _319;
    spvUnsafeArray<float, 4> _325 = spvUnsafeArray<float, 4>({ _318 * _320, _317 * _320, _318 * _319, _317 * _319 });
    spvUnsafeArray<float, 4> _87 = _325;
    float _327;
    float _330;
    _327 = 0.0;
    _330 = 0.0;
    float _328;
    float _331;
    for (int _332 = 0; _332 < 4; _327 = _328, _330 = _331, _332++)
    {
        int2 _339 = _315 + _79[_332];
        if (all(uint2(_339) < uint2(cbFI.renderSize)))
        {
            float _410;
            float _411;
            if (_87[_332] > 0.001000000047497451305389404296875)
            {
                float4 _364 = sdk_hlsl_load(r_dilated_depth, uint2(uint2(_339 + int2(r_input_distortion_field.sample(s_LinearClamp, ((float2(_339) + float2(0.5)) / _100), level(0.0)).xy * _100))), 0u);
                float _365 = _364.x;
                float _367 = cbFI.fDeviceToViewDepth.y / (_365 - cbFI.fDeviceToViewDepth.x);
                float _368 = _200 - _367;
                float _408;
                float _409;
                if (_368 > 0.0)
                {
                    float _376 = cbFI.fDeviceToViewDepth.y / (precise::min(_365, _95) - cbFI.fDeviceToViewDepth.x);
                    float2 _380 = ((float2(int2(_100 * 0.5)) / _100) * float2(2.0, -2.0)) + float2(-1.0, 1.0);
                    _408 = _327 + (float(((((1.3699999726668465882539749145508e-05 * (length(float3((cbFI.fDeviceToViewDepth.z * (-1.0)) * _376, cbFI.fDeviceToViewDepth.w * _376, _376)) / length(float3((cbFI.fDeviceToViewDepth.z * _380.x) * _376, (cbFI.fDeviceToViewDepth.w * _380.y) * _376, _376)))) * length(_100)) * precise::min(_200, _367)) / _368) >= 1.0) * _87[_332]);
                    _409 = _330 + _87[_332];
                }
                else
                {
                    _408 = _327;
                    _409 = _330;
                }
                _410 = _408;
                _411 = _409;
            }
            else
            {
                _410 = _327;
                _411 = _330;
            }
            _328 = _410;
            _331 = _411;
        }
        else
        {
            _328 = _327;
            _331 = _330;
        }
    }
    float _419;
    if (_330 > 0.0)
    {
        _419 = fast::clamp(1.0 - (_327 / _330), 0.0, 1.0);
    }
    else
    {
        _419 = 0.0;
    }
    float2 _423 = float2(float2(1.0 - _309, 1.0 - _419) >= float2(0.001000000047497451305389404296875));
    float2 _424 = _193 * 2.0;
    uint2 _430 = uint2(cbFI.renderSize);
    sdk_hlsl_store(rw_disocclusion_mask, float2(fast::clamp(_423.x + float(!all(uint2(int2((_101 + _424) * _100)) < _430)), 0.0, 1.0), fast::clamp(_423.y + float(!all(uint2(int2((_101 - _424) * _100)) < _430)), 0.0, 1.0)).xyyy, uint2(_91));
}

