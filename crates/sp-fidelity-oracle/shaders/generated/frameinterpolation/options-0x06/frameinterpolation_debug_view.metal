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

struct FfxFrameInterpolationDebugViewport
{
    int2 offset;
    int2 size;
};

constant spvUnsafeArray<int2, 4> _90 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_current_interpolation_source [[texture(0)]], texture2d<float> r_disocclusion_mask [[texture(1)]], texture2d<uint> r_game_motion_vector_field_x [[texture(2)]], texture2d<uint> r_game_motion_vector_field_y [[texture(3)]], texture2d<uint> r_optical_flow_motion_vector_field_x [[texture(4)]], texture2d<uint> r_optical_flow_motion_vector_field_y [[texture(5)]], texture2d<float> r_inpainting_pyramid [[texture(6)]], texture2d<float> r_present_backbuffer [[texture(7)]], texture2d<float> r_input_distortion_field [[texture(8)]], texture2d<float, access::write> rw_output [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _104 = float2(cbFI.displaySize);
    int2 _106 = int2(_104 * float2(0.3333333432674407958984375));
    int _108;
    _108 = 0;
    spvUnsafeArray<spvUnsafeArray<FfxFrameInterpolationDebugViewport, 3>, 3> _99;
    for (; _108 < 3; _108++)
    {
        for (int _115 = 0; _115 < 3; )
        {
            _99[_108][_115].offset = _106 * int2(_115, _108);
            _99[_108][_115].size = _106;
            _115++;
            continue;
        }
    }
    int2 _128 = _99[0][0].offset + _99[0][0].size;
    bool _136;
    if (int3(gl_GlobalInvocationID).x >= _99[0][0].offset.x)
    {
        _136 = int3(gl_GlobalInvocationID).x < _128.x;
    }
    else
    {
        _136 = false;
    }
    bool _147;
    if (_136)
    {
        bool _146;
        if (int3(gl_GlobalInvocationID).y >= _99[0][0].offset.y)
        {
            _146 = int3(gl_GlobalInvocationID).y < _128.y;
        }
        else
        {
            _146 = false;
        }
        _147 = _146;
    }
    else
    {
        _147 = false;
    }
    if (_147)
    {
        float2 _157 = (float2(int3(gl_GlobalInvocationID).xy - _99[0][0].offset) + float2(0.5)) / float2(_99[0][0].size);
        uint2 _163 = uint2(int2(_157 * float2(cbFI.renderSize)));
        uint4 _165 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_163), 0u);
        uint _166 = _165.x;
        float _173 = float((_166 >> 21u) & 1023u) * 0.000977517105638980865478515625;
        float2 _253;
        if ((isunordered(_173, 0.0) || _173 <= 0.0))
        {
            int2 _185;
            float4 _188;
            _185 = cbFI.renderSize;
            _188 = float4(0.0);
            int2 _186;
            float4 _189;
            int _190 = 0;
            for (;;)
            {
                bool _199;
                if (_190 < 11)
                {
                    _199 = _188.w == 0.0;
                }
                else
                {
                    _199 = false;
                }
                if (_199)
                {
                    _186 = _185 / int2(2);
                    float2 _203 = (_157 * float2(_186)) - float2(0.5);
                    float2 _204 = floor(_203);
                    int2 _205 = int2(_204);
                    float2 _206 = _203 - _204;
                    float _207 = _206.x;
                    float _208 = 1.0 - _207;
                    float _209 = _206.y;
                    float _210 = 1.0 - _209;
                    spvUnsafeArray<float, 4> _215 = spvUnsafeArray<float, 4>({ _208 * _210, _207 * _210, _208 * _209, _207 * _209 });
                    spvUnsafeArray<float, 4> _93 = _215;
                    float4 _217;
                    float _220;
                    _217 = float4(0.0);
                    _220 = 0.0;
                    float4 _218;
                    float _221;
                    for (int _222 = 0; _222 < 4; _217 = _218, _220 = _221, _222++)
                    {
                        uint2 _230 = uint2(_205 + _90[_222]);
                        if (all(_230 < uint2(_186)))
                        {
                            float4 _238 = sdk_hlsl_load(r_inpainting_pyramid, uint2(_230), uint(_190));
                            float _239 = _238.z;
                            float _245 = (_93[_222] * float(_239 > 0.0)) * _239;
                            _218 = _217 + (_238 * _245);
                            _221 = _220 + _245;
                        }
                        else
                        {
                            _218 = _217;
                            _221 = _220;
                        }
                    }
                    _189 = _217 / float4((_220 > 0.0) ? _220 : 1.0);
                    _185 = _186;
                    _188 = _189;
                    _190++;
                    continue;
                }
                else
                {
                    break;
                }
            }
            _253 = _188.xy;
        }
        else
        {
            _253 = float2(float2(as_type<half2>(_166 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_163), 0u).x & 65535u)).x);
        }
        sdk_hlsl_store(rw_output, float4(float2(0.5) + ((_253 * _104) * 0.100000001490116119384765625), 0.5, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _266 = _99[0][1].offset + _99[0][1].size;
    bool _273;
    if (int3(gl_GlobalInvocationID).x >= _99[0][1].offset.x)
    {
        _273 = int3(gl_GlobalInvocationID).x < _266.x;
    }
    else
    {
        _273 = false;
    }
    bool _284;
    if (_273)
    {
        bool _283;
        if (int3(gl_GlobalInvocationID).y >= _99[0][1].offset.y)
        {
            _283 = int3(gl_GlobalInvocationID).y < _266.y;
        }
        else
        {
            _283 = false;
        }
        _284 = _283;
    }
    else
    {
        _284 = false;
    }
    if (_284)
    {
        float2 _294 = (float2(int3(gl_GlobalInvocationID).xy - _99[0][1].offset) + float2(0.5)) / float2(_99[0][1].size);
        uint4 _302 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(uint2(int2(_294 * float2(cbFI.renderSize)))), 0u);
        uint _303 = _302.x;
        float _307 = float((_303 >> 21u) & 1023u) * 0.000977517105638980865478515625;
        bool _309 = _307 > 0.0;
        bool _313;
        if (_309)
        {
            _313 = (_303 & 2147483648u) == 0u;
        }
        else
        {
            _313 = false;
        }
        float _317;
        if (_313)
        {
            _317 = 1.0 - _307;
        }
        else
        {
            _317 = _307;
        }
        float _390;
        if (!_309)
        {
            int2 _322;
            float4 _325;
            _322 = cbFI.renderSize;
            _325 = float4(0.0);
            int2 _323;
            float4 _326;
            int _327 = 0;
            for (;;)
            {
                bool _336;
                if (_327 < 11)
                {
                    _336 = _325.w == 0.0;
                }
                else
                {
                    _336 = false;
                }
                if (_336)
                {
                    _323 = _322 / int2(2);
                    float2 _340 = (_294 * float2(_323)) - float2(0.5);
                    float2 _341 = floor(_340);
                    int2 _342 = int2(_341);
                    float2 _343 = _340 - _341;
                    float _344 = _343.x;
                    float _345 = 1.0 - _344;
                    float _346 = _343.y;
                    float _347 = 1.0 - _346;
                    spvUnsafeArray<float, 4> _352 = spvUnsafeArray<float, 4>({ _345 * _347, _344 * _347, _345 * _346, _344 * _346 });
                    spvUnsafeArray<float, 4> _95 = _352;
                    float4 _354;
                    float _357;
                    _354 = float4(0.0);
                    _357 = 0.0;
                    float4 _355;
                    float _358;
                    for (int _359 = 0; _359 < 4; _354 = _355, _357 = _358, _359++)
                    {
                        uint2 _367 = uint2(_342 + _90[_359]);
                        if (all(_367 < uint2(_323)))
                        {
                            float4 _375 = sdk_hlsl_load(r_inpainting_pyramid, uint2(_367), uint(_327));
                            float _376 = _375.z;
                            float _382 = (_95[_359] * float(_376 > 0.0)) * _376;
                            _355 = _354 + (_375 * _382);
                            _358 = _357 + _382;
                        }
                        else
                        {
                            _355 = _354;
                            _358 = _357;
                        }
                    }
                    _326 = _354 / float4((_357 > 0.0) ? _357 : 1.0);
                    _322 = _323;
                    _325 = _326;
                    _327++;
                    continue;
                }
                else
                {
                    break;
                }
            }
            _390 = _325.z;
        }
        else
        {
            _390 = _317;
        }
        sdk_hlsl_store(rw_output, float4(0.0, _390, 0.0, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _398 = _99[0][2].offset + _99[0][2].size;
    bool _405;
    if (int3(gl_GlobalInvocationID).x >= _99[0][2].offset.x)
    {
        _405 = int3(gl_GlobalInvocationID).x < _398.x;
    }
    else
    {
        _405 = false;
    }
    bool _416;
    if (_405)
    {
        bool _415;
        if (int3(gl_GlobalInvocationID).y >= _99[0][2].offset.y)
        {
            _415 = int3(gl_GlobalInvocationID).y < _398.y;
        }
        else
        {
            _415 = false;
        }
        _416 = _415;
    }
    else
    {
        _416 = false;
    }
    if (_416)
    {
        int2 _439 = int2(float2(int2((float2(1.0) / cbFI.opticalFlowScale) / float2(int2(cbFI.opticalFlowBlockSize))) * int2(1)) * 1.0);
        float2 _442 = (((float2(int3(gl_GlobalInvocationID).xy - _99[0][2].offset) + float2(0.5)) / float2(_99[0][2].size)) * float2(_439)) - float2(0.5);
        float2 _443 = floor(_442);
        int2 _444 = int2(_443);
        float2 _445 = _442 - _443;
        float _446 = _445.x;
        float _447 = 1.0 - _446;
        float _448 = _445.y;
        float _449 = 1.0 - _448;
        spvUnsafeArray<float, 4> _454 = spvUnsafeArray<float, 4>({ _447 * _449, _446 * _449, _447 * _448, _446 * _448 });
        spvUnsafeArray<float, 4> _97 = _454;
        float2 _456;
        float _459;
        _456 = float2(0.0);
        _459 = 0.0;
        float2 _457;
        float _460;
        for (int _461 = 0; _461 < 4; _456 = _457, _459 = _460, _461++)
        {
            uint2 _469 = uint2(_444 + _90[_461]);
            if (all(_469 < uint2(_439)))
            {
                _457 = _456 + (float2(float2(as_type<half2>(sdk_hlsl_load(r_optical_flow_motion_vector_field_x, uint2(_469), 0u).x & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_optical_flow_motion_vector_field_y, uint2(_469), 0u).x & 65535u)).x) * _97[_461]);
                _460 = _459 + _97[_461];
            }
            else
            {
                _457 = _456;
                _460 = _459;
            }
        }
        float2 _498;
        if (_459 > 0.0)
        {
            _498 = _456 / float2(_459);
        }
        else
        {
            _498 = _456;
        }
        sdk_hlsl_store(rw_output, float4(float2(0.5) + ((_498 * _104) * 0.100000001490116119384765625), 0.5, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _511 = _99[2][0].offset + _99[2][0].size;
    bool _518;
    if (int3(gl_GlobalInvocationID).x >= _99[2][0].offset.x)
    {
        _518 = int3(gl_GlobalInvocationID).x < _511.x;
    }
    else
    {
        _518 = false;
    }
    bool _529;
    if (_518)
    {
        bool _528;
        if (int3(gl_GlobalInvocationID).y >= _99[2][0].offset.y)
        {
            _528 = int3(gl_GlobalInvocationID).y < _511.y;
        }
        else
        {
            _528 = false;
        }
        _529 = _528;
    }
    else
    {
        _529 = false;
    }
    if (_529)
    {
        sdk_hlsl_store(rw_output, float4(fast::clamp(r_disocclusion_mask.sample(s_LinearClamp, (((float2(int3(gl_GlobalInvocationID).xy - _99[2][0].offset) + float2(0.5)) / float2(_99[2][0].size)) * (float2(cbFI.renderSize) / float2(cbFI.maxRenderSize))), level(0.0)).xy, float2(0.0), float2(1.0)), 0.0, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _563 = _99[2][1].offset + _99[2][1].size;
    bool _570;
    if (int3(gl_GlobalInvocationID).x >= _99[2][1].offset.x)
    {
        _570 = int3(gl_GlobalInvocationID).x < _563.x;
    }
    else
    {
        _570 = false;
    }
    bool _581;
    if (_570)
    {
        bool _580;
        if (int3(gl_GlobalInvocationID).y >= _99[2][1].offset.y)
        {
            _580 = int3(gl_GlobalInvocationID).y < _563.y;
        }
        else
        {
            _580 = false;
        }
        _581 = _580;
    }
    else
    {
        _581 = false;
    }
    if (_581)
    {
        sdk_hlsl_store(rw_output, float4(r_current_interpolation_source.sample(s_LinearClamp, ((float2(int3(gl_GlobalInvocationID).xy - _99[2][1].offset) + float2(0.5)) / float2(_99[2][1].size)), level(0.0)).xyz, 1.0), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
    int2 _606 = _99[2][2].offset + _99[2][2].size;
    bool _613;
    if (int3(gl_GlobalInvocationID).x >= _99[2][2].offset.x)
    {
        _613 = int3(gl_GlobalInvocationID).x < _606.x;
    }
    else
    {
        _613 = false;
    }
    bool _624;
    if (_613)
    {
        bool _623;
        if (int3(gl_GlobalInvocationID).y >= _99[2][2].offset.y)
        {
            _623 = int3(gl_GlobalInvocationID).y < _606.y;
        }
        else
        {
            _623 = false;
        }
        _624 = _623;
    }
    else
    {
        _624 = false;
    }
    if (_624)
    {
        float2 _634 = (float2(int3(gl_GlobalInvocationID).xy - _99[2][2].offset) + float2(0.5)) / float2(_99[2][2].size);
        float4 _654;
        if (cbFI.HUDLessAttachedFactor == 1)
        {
            _654 = r_present_backbuffer.sample(s_LinearClamp, _634, level(0.0));
        }
        else
        {
            _654 = float4(abs(r_input_distortion_field.sample(s_LinearClamp, _634, level(0.0)).xy) * 10.0, 0.0, 1.0);
        }
        sdk_hlsl_store(rw_output, _654, uint2(uint2(int3(gl_GlobalInvocationID).xy)));
    }
}

