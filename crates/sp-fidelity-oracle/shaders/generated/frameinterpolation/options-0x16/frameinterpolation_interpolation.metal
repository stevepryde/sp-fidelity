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

struct type_StructuredBuffer_uint
{
    uint _m0[1];
};

constant spvUnsafeArray<int2, 4> _88 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], const device type_StructuredBuffer_uint& r_counters [[buffer(1)]], texture2d<float> r_previous_interpolation_source [[texture(0)]], texture2d<float> r_current_interpolation_source [[texture(1)]], texture2d<float> r_disocclusion_mask [[texture(2)]], texture2d<uint> r_game_motion_vector_field_x [[texture(3)]], texture2d<uint> r_game_motion_vector_field_y [[texture(4)]], texture2d<uint> r_optical_flow_motion_vector_field_x [[texture(5)]], texture2d<uint> r_optical_flow_motion_vector_field_y [[texture(6)]], texture2d<float> r_inpainting_pyramid [[texture(7)]], texture2d<float, access::write> rw_output [[texture(8)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    bool _118;
    if (int3(gl_GlobalInvocationID).x >= cbFI.interpolationRectBase.x)
    {
        _118 = int3(gl_GlobalInvocationID).x < (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
    }
    else
    {
        _118 = false;
    }
    bool _124;
    if (_118)
    {
        _124 = int3(gl_GlobalInvocationID).y >= cbFI.interpolationRectBase.y;
    }
    else
    {
        _124 = false;
    }
    bool _132;
    if (_124)
    {
        _132 = int3(gl_GlobalInvocationID).y < (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
    }
    else
    {
        _132 = false;
    }
    bool _138;
    if (_132)
    {
        _138 = r_counters._m0[1u] == 0u;
    }
    else
    {
        _138 = true;
    }
    float _743;
    float3 _744;
    if (_138)
    {
        _743 = 0.0;
        _744 = sdk_hlsl_load(r_current_interpolation_source, uint2(uint2(int3(gl_GlobalInvocationID).xy)), 0u).xyz;
    }
    else
    {
        uint2 _142 = uint2(int3(gl_GlobalInvocationID).xy);
        float2 _147 = float2(cbFI.interpolationRectSize);
        float2 _148 = (float2(_142 - uint2(cbFI.interpolationRectBase)) + float2(0.5)) / _147;
        float2 _153 = float2(cbFI.displaySize);
        float2 _154 = (float2(_142) + float2(0.5)) / _153;
        float2 _157 = float2(cbFI.renderSize);
        float2 _163 = _147 / _153;
        uint2 _166 = uint2(int2(_148 * _157));
        uint4 _168 = sdk_hlsl_load(r_game_motion_vector_field_x, uint2(_166), 0u);
        uint _169 = _168.x;
        float _176 = float((_169 >> 21u) & 1023u) * 0.000977517105638980865478515625;
        float2 _256;
        if ((isunordered(_176, 0.0) || _176 <= 0.0))
        {
            int2 _188;
            float4 _191;
            _188 = cbFI.renderSize;
            _191 = float4(0.0);
            int2 _189;
            float4 _192;
            int _193 = 0;
            for (;;)
            {
                bool _202;
                if (_193 < 11)
                {
                    _202 = _191.w == 0.0;
                }
                else
                {
                    _202 = false;
                }
                if (_202)
                {
                    _189 = _188 / int2(2);
                    float2 _206 = (_148 * float2(_189)) - float2(0.5);
                    float2 _207 = floor(_206);
                    int2 _208 = int2(_207);
                    float2 _209 = _206 - _207;
                    float _210 = _209.x;
                    float _211 = 1.0 - _210;
                    float _212 = _209.y;
                    float _213 = 1.0 - _212;
                    spvUnsafeArray<float, 4> _218 = spvUnsafeArray<float, 4>({ _211 * _213, _210 * _213, _211 * _212, _210 * _212 });
                    spvUnsafeArray<float, 4> _92 = _218;
                    float4 _220;
                    float _223;
                    _220 = float4(0.0);
                    _223 = 0.0;
                    float4 _221;
                    float _224;
                    for (int _225 = 0; _225 < 4; _220 = _221, _223 = _224, _225++)
                    {
                        uint2 _233 = uint2(_208 + _88[_225]);
                        if (all(_233 < uint2(_189)))
                        {
                            float4 _241 = sdk_hlsl_load(r_inpainting_pyramid, uint2(_233), uint(_193));
                            float _242 = _241.z;
                            float _248 = (_92[_225] * float(_242 > 0.0)) * _242;
                            _221 = _220 + (_241 * _248);
                            _224 = _223 + _248;
                        }
                        else
                        {
                            _221 = _220;
                            _224 = _223;
                        }
                    }
                    _192 = _220 / float4((_223 > 0.0) ? _223 : 1.0);
                    _188 = _189;
                    _191 = _192;
                    _193++;
                    continue;
                }
                else
                {
                    break;
                }
            }
            _256 = _191.xy;
        }
        else
        {
            _256 = float2(float2(as_type<half2>(_169 & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_game_motion_vector_field_y, uint2(_166), 0u).x & 65535u)).x);
        }
        float2 _257 = _148 - _256;
        float _258 = _257.x;
        bool _263;
        if (_258 > 0.0)
        {
            _263 = _258 < 1.0;
        }
        else
        {
            _263 = false;
        }
        bool _272;
        if (_263)
        {
            float _266 = _257.y;
            bool _271;
            if (_266 > 0.0)
            {
                _271 = _266 < 1.0;
            }
            else
            {
                _271 = false;
            }
            _272 = _271;
        }
        else
        {
            _272 = false;
        }
        float2 _273 = _148 + _256;
        float _274 = _273.x;
        bool _279;
        if (_274 > 0.0)
        {
            _279 = _274 < 1.0;
        }
        else
        {
            _279 = false;
        }
        bool _288;
        if (_279)
        {
            float _282 = _273.y;
            bool _287;
            if (_282 > 0.0)
            {
                _287 = _282 < 1.0;
            }
            else
            {
                _287 = false;
            }
            _288 = _287;
        }
        else
        {
            _288 = false;
        }
        int2 _301 = int2(float2(int2((float2(1.0) / cbFI.opticalFlowScale) / float2(int2(cbFI.opticalFlowBlockSize))) * int2(1)) * 1.0);
        float2 _304 = (_154 * float2(_301)) - float2(0.5);
        float2 _305 = floor(_304);
        int2 _306 = int2(_305);
        float2 _307 = _304 - _305;
        float _308 = _307.x;
        float _309 = 1.0 - _308;
        float _310 = _307.y;
        float _311 = 1.0 - _310;
        spvUnsafeArray<float, 4> _316 = spvUnsafeArray<float, 4>({ _309 * _311, _308 * _311, _309 * _310, _308 * _310 });
        spvUnsafeArray<float, 4> _94 = _316;
        float2 _318;
        float _321;
        _318 = float2(0.0);
        _321 = 0.0;
        float2 _319;
        float _322;
        for (int _323 = 0; _323 < 4; _318 = _319, _321 = _322, _323++)
        {
            uint2 _331 = uint2(_306 + _88[_323]);
            if (all(_331 < uint2(_301)))
            {
                _319 = _318 + (float2(float2(as_type<half2>(sdk_hlsl_load(r_optical_flow_motion_vector_field_x, uint2(_331), 0u).x & 65535u)).x, float2(as_type<half2>(sdk_hlsl_load(r_optical_flow_motion_vector_field_y, uint2(_331), 0u).x & 65535u)).x) * _94[_323]);
                _322 = _321 + _94[_323];
            }
            else
            {
                _319 = _318;
                _322 = _321;
            }
        }
        float2 _360;
        if (_321 > 0.0)
        {
            _360 = _318 / float2(_321);
        }
        else
        {
            _360 = _318;
        }
        float2 _368 = float2(fast::clamp(r_disocclusion_mask.sample(s_LinearClamp, (_148 * (_157 / float2(cbFI.maxRenderSize))), level(0.0)).xy, float2(0.0), float2(1.0)) == float2(1.0));
        float2 _372 = ((_154 + (_256 * _163)) * _153) - float2(0.5);
        float2 _373 = floor(_372);
        int2 _374 = int2(_373);
        float2 _375 = _372 - _373;
        float _376 = _375.x;
        float _377 = 1.0 - _376;
        float _378 = _375.y;
        float _379 = 1.0 - _378;
        spvUnsafeArray<float, 4> _384 = spvUnsafeArray<float, 4>({ _377 * _379, _376 * _379, _377 * _378, _376 * _378 });
        spvUnsafeArray<float, 4> _96 = _384;
        float3 _386;
        float _389;
        _386 = float3(0.0);
        _389 = 0.0;
        float3 _387;
        float _390;
        for (int _391 = 0; _391 < 4; _386 = _387, _389 = _390, _391++)
        {
            int2 _398 = _374 + _88[_391];
            int _399 = _398.x;
            bool _406;
            if (_399 >= cbFI.interpolationRectBase.x)
            {
                _406 = _399 < (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _406 = false;
            }
            bool _412;
            if (_406)
            {
                _412 = _398.y >= cbFI.interpolationRectBase.y;
            }
            else
            {
                _412 = false;
            }
            bool _420;
            if (_412)
            {
                _420 = _398.y < (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _420 = false;
            }
            if (_420)
            {
                _387 = _386 + (sdk_hlsl_load(r_previous_interpolation_source, uint2(uint2(_398)), 0u).xyz * _96[_391]);
                _390 = _389 + _96[_391];
            }
            else
            {
                _387 = _386;
                _390 = _389;
            }
        }
        float3 _438;
        if (_389 != 0.0)
        {
            _438 = _386 / float3(_389);
        }
        else
        {
            _438 = float3(0.0);
        }
        float2 _443 = ((_154 + ((-_256) * _163)) * _153) - float2(0.5);
        float2 _444 = floor(_443);
        int2 _445 = int2(_444);
        float2 _446 = _443 - _444;
        float _447 = _446.x;
        float _448 = 1.0 - _447;
        float _449 = _446.y;
        float _450 = 1.0 - _449;
        spvUnsafeArray<float, 4> _455 = spvUnsafeArray<float, 4>({ _448 * _450, _447 * _450, _448 * _449, _447 * _449 });
        spvUnsafeArray<float, 4> _98 = _455;
        float3 _457;
        float _460;
        _457 = float3(0.0);
        _460 = 0.0;
        float3 _458;
        float _461;
        for (int _462 = 0; _462 < 4; _457 = _458, _460 = _461, _462++)
        {
            int2 _469 = _445 + _88[_462];
            int _470 = _469.x;
            bool _477;
            if (_470 >= cbFI.interpolationRectBase.x)
            {
                _477 = _470 < (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _477 = false;
            }
            bool _483;
            if (_477)
            {
                _483 = _469.y >= cbFI.interpolationRectBase.y;
            }
            else
            {
                _483 = false;
            }
            bool _491;
            if (_483)
            {
                _491 = _469.y < (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _491 = false;
            }
            if (_491)
            {
                _458 = _457 + (sdk_hlsl_load(r_current_interpolation_source, uint2(uint2(_469)), 0u).xyz * _98[_462]);
                _461 = _460 + _98[_462];
            }
            else
            {
                _458 = _457;
                _461 = _460;
            }
        }
        float3 _509;
        if (_460 != 0.0)
        {
            _509 = _457 / float3(_460);
        }
        else
        {
            _509 = float3(0.0);
        }
        float2 _513 = ((_154 + (_360 * _163)) * _153) - float2(0.5);
        float2 _514 = floor(_513);
        int2 _515 = int2(_514);
        float2 _516 = _513 - _514;
        float _517 = _516.x;
        float _518 = 1.0 - _517;
        float _519 = _516.y;
        float _520 = 1.0 - _519;
        spvUnsafeArray<float, 4> _525 = spvUnsafeArray<float, 4>({ _518 * _520, _517 * _520, _518 * _519, _517 * _519 });
        spvUnsafeArray<float, 4> _100 = _525;
        float3 _527;
        float _530;
        _527 = float3(0.0);
        _530 = 0.0;
        float3 _528;
        float _531;
        for (int _532 = 0; _532 < 4; _527 = _528, _530 = _531, _532++)
        {
            int2 _539 = _515 + _88[_532];
            int _540 = _539.x;
            bool _547;
            if (_540 >= cbFI.interpolationRectBase.x)
            {
                _547 = _540 < (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _547 = false;
            }
            bool _553;
            if (_547)
            {
                _553 = _539.y >= cbFI.interpolationRectBase.y;
            }
            else
            {
                _553 = false;
            }
            bool _561;
            if (_553)
            {
                _561 = _539.y < (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _561 = false;
            }
            if (_561)
            {
                _528 = _527 + (sdk_hlsl_load(r_previous_interpolation_source, uint2(uint2(_539)), 0u).xyz * _100[_532]);
                _531 = _530 + _100[_532];
            }
            else
            {
                _528 = _527;
                _531 = _530;
            }
        }
        float3 _579;
        if (_530 != 0.0)
        {
            _579 = _527 / float3(_530);
        }
        else
        {
            _579 = float3(0.0);
        }
        float2 _584 = ((_154 + ((-_360) * _163)) * _153) - float2(0.5);
        float2 _585 = floor(_584);
        int2 _586 = int2(_585);
        float2 _587 = _584 - _585;
        float _588 = _587.x;
        float _589 = 1.0 - _588;
        float _590 = _587.y;
        float _591 = 1.0 - _590;
        spvUnsafeArray<float, 4> _596 = spvUnsafeArray<float, 4>({ _589 * _591, _588 * _591, _589 * _590, _588 * _590 });
        spvUnsafeArray<float, 4> _102 = _596;
        float3 _598;
        float _601;
        _598 = float3(0.0);
        _601 = 0.0;
        float3 _599;
        float _602;
        for (int _603 = 0; _603 < 4; _598 = _599, _601 = _602, _603++)
        {
            int2 _610 = _586 + _88[_603];
            int _611 = _610.x;
            bool _618;
            if (_611 >= cbFI.interpolationRectBase.x)
            {
                _618 = _611 < (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _618 = false;
            }
            bool _624;
            if (_618)
            {
                _624 = _610.y >= cbFI.interpolationRectBase.y;
            }
            else
            {
                _624 = false;
            }
            bool _632;
            if (_624)
            {
                _632 = _610.y < (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _632 = false;
            }
            if (_632)
            {
                _599 = _598 + (sdk_hlsl_load(r_current_interpolation_source, uint2(uint2(_610)), 0u).xyz * _102[_603]);
                _602 = _601 + _102[_603];
            }
            else
            {
                _599 = _598;
                _602 = _601;
            }
        }
        float3 _650;
        if (_601 != 0.0)
        {
            _650 = _598 / float3(_601);
        }
        else
        {
            _650 = float3(0.0);
        }
        float _653 = _368.x * float(_288);
        float _656 = _368.y * float(_272);
        bool _675 = _389 == 0.0;
        float3 _682;
        if (_675)
        {
            _682 = _509;
        }
        else
        {
            _682 = select(mix(_438, _509, float3(fast::clamp((0.5 + (0.5 * (1.0 - _653))) - (0.5 * (1.0 - _656)), 0.0, 1.0))), _438, bool3(_460 == 0.0));
        }
        bool _686;
        if (_675)
        {
            _686 = _460 == 0.0;
        }
        else
        {
            _686 = false;
        }
        bool _688 = _530 > 0.0;
        bool _692;
        if (_688)
        {
            _692 = _601 > 0.0;
        }
        else
        {
            _692 = false;
        }
        float _697;
        if (_692)
        {
            _697 = 0.5;
        }
        else
        {
            _697 = _688 ? 0.0 : 1.0;
        }
        float _702 = precise::max(length(_579), length(_650));
        float _711;
        if (_702 > 0.0)
        {
            float3 _707 = float3(_702);
            _711 = dot(_579 / _707, _650 / _707);
        }
        else
        {
            _711 = 1.0;
        }
        float _714 = precise::max(length(_438), length(_509));
        float _723;
        if (_714 > 0.0)
        {
            float3 _719 = float3(_714);
            _723 = dot(_438 / _719, _509 / _719);
        }
        else
        {
            _723 = 1.0;
        }
        _743 = _686 ? 1.0 : fast::clamp(precise::max(0.0, float(length(float2(_653, _656)) <= 0.001000000047497451305389404296875)), 0.0, 1.0);
        _744 = mix(mix(_579, _650, float3(_697)), _682, float3(fast::clamp(mix(powr(fast::clamp(mix(precise::max(0.001000000047497451305389404296875, _723), 1.0, fast::clamp(fast::clamp(1.0 - precise::min(_653, _656), 0.0, 1.0), 0.0, 1.0)) / precise::max(0.001000000047497451305389404296875, _711), 0.0, 1.0), 1.0), 1.0, float(r_counters._m0[1u] < 10u)), 0.0, 1.0)));
    }
    sdk_hlsl_store(rw_output, float4(_744, _743), uint2(uint2(int3(gl_GlobalInvocationID).xy)));
}

