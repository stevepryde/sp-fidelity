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

constant spvUnsafeArray<int2, 4> _101 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_exposure [[texture(2)]], texture2d<float> r_reactive_mask [[texture(3)]], texture2d<float> r_transparency_and_composition_mask [[texture(4)]], texture2d<uint> r_reconstructed_previous_nearest_depth [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_previous_dilated_motion_vectors [[texture(7)]], texture2d<float> r_dilatedDepth [[texture(8)]], texture2d<float, access::write> rw_prepared_input_color [[texture(9)]], texture2d<float, access::write> rw_dilated_reactive_masks [[texture(10)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _125 = float2(cbFSR2.iRenderSize);
    float2 _126 = (float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _125;
    uint2 _127 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _130 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_127), 0u).xy;
    float2 _133 = float2(cbFSR2.iDisplaySize);
    float4 _141 = sdk_hlsl_load(r_dilatedDepth, uint2(_127), 0u);
    float _142 = _141.x;
    float _148 = cbFSR2.fDeviceToViewDepth.y / (_142 - cbFSR2.fDeviceToViewDepth.x);
    float2 _150 = ((_126 + (_130 * float(length(_130 * _133) > 0.00999999977648258209228515625))) * _125) - float2(0.5);
    float2 _151 = floor(_150);
    int2 _152 = int2(_151);
    float2 _153 = _150 - _151;
    float _154 = _153.x;
    float _155 = 1.0 - _154;
    float _156 = _153.y;
    float _157 = 1.0 - _156;
    spvUnsafeArray<float, 4> _162 = spvUnsafeArray<float, 4>({ _155 * _157, _154 * _157, _155 * _156, _154 * _156 });
    spvUnsafeArray<float, 4> _114 = _162;
    float _164;
    float _167;
    _164 = 0.0;
    _167 = 0.0;
    float _165;
    float _168;
    for (int _169 = 0; _169 < 4; _164 = _165, _167 = _168, _169++)
    {
        uint2 _177 = uint2(_152 + _101[_169]);
        if (all(_177 < uint2(cbFSR2.iRenderSize)))
        {
            float _240;
            float _241;
            if (_114[_169] > 0.00999999977648258209228515625)
            {
                float _191 = as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(_177), 0u).x);
                float _193 = cbFSR2.fDeviceToViewDepth.y / (_191 - cbFSR2.fDeviceToViewDepth.x);
                float _194 = _148 - _193;
                float _238;
                float _239;
                if (_194 > 0.0)
                {
                    float _202 = cbFSR2.fDeviceToViewDepth.y / (precise::min(_191, _142) - cbFSR2.fDeviceToViewDepth.x);
                    float2 _206 = ((float2(int2(_125 * 0.5)) / _125) * float2(2.0, -2.0)) + float2(-1.0, 1.0);
                    float _220 = length(_125);
                    _238 = _164 + (powr(fast::clamp((((1.3699999726668465882539749145508e-05 * (length(float3((cbFSR2.fDeviceToViewDepth.z * (-1.0)) * _202, cbFSR2.fDeviceToViewDepth.w * _202, _202)) / length(float3((cbFSR2.fDeviceToViewDepth.z * _206.x) * _202, (cbFSR2.fDeviceToViewDepth.w * _206.y) * _202, _202)))) * _220) * precise::max(_148, _193)) / _194, 0.0, 1.0), mix(1.0, 3.0, fast::clamp(_220 / length(float2(1920.0, 1080.0)), 0.0, 1.0))) * _114[_169]);
                    _239 = _167 + _114[_169];
                }
                else
                {
                    _238 = _164;
                    _239 = _167;
                }
                _240 = _238;
                _241 = _239;
            }
            else
            {
                _240 = _164;
                _241 = _167;
            }
            _165 = _240;
            _168 = _241;
        }
        else
        {
            _165 = _164;
            _168 = _167;
        }
    }
    float _249;
    if (_167 > 0.0)
    {
        _249 = fast::clamp(1.0 - (_164 / _167), 0.0, 1.0);
    }
    else
    {
        _249 = 0.0;
    }
    int2 _250 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    float _263 = cbFSR2.fDeviceToViewDepth.y / (as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(_127), 0u).x) - cbFSR2.fDeviceToViewDepth.x);
    int2 _264 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    float _271 = cbFSR2.fDeviceToViewDepth.y / (as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(uint2(_264)), 0u).x) - cbFSR2.fDeviceToViewDepth.x);
    bool _280;
    if (((cbFSR2.fDeviceToViewDepth.y / (as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(uint2(_250)), 0u).x) - cbFSR2.fDeviceToViewDepth.x)) - _263) > (_263 * 0.00999999977648258209228515625))
    {
        _280 = (_263 - _271) > (_271 * 0.00999999977648258209228515625);
    }
    else
    {
        _280 = false;
    }
    float4 _288 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _289 = _288.x;
    float3 _297 = fast::clamp((precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_127), 0u).xyz) / float3(cbFSR2.fPreExposure)) * ((_289 == 0.0) ? 1.0 : _289), float3(0.0), float3(65504.0));
    float _298 = _297.x;
    float _301 = 0.5 * _297.y;
    float _303 = _297.z;
    float _304 = 0.25 * _303;
    sdk_hlsl_store(rw_prepared_input_color, float4(((0.25 * _298) + _301) + _304, 0.5 * (_298 - _303), (((-0.25) * _298) + _301) - _304, _249 * (_280 ? 0.0 : 1.0)), uint2(_127));
    float2 _321 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_127), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
    float _324 = length(_321);
    float _396;
    float _397;
    if (length(_321 * _125) > 0.00999999977648258209228515625)
    {
        float _329;
        float _332;
        _329 = _324;
        _332 = 1.0;
        float _330;
        float _333;
        for (int _334 = -1; _334 <= 1; _329 = _330, _332 = _333, _334++)
        {
            _333 = _332;
            _330 = _329;
            float _340;
            float _342;
            for (int _343 = -1; _343 <= 1; _333 = _340, _330 = _342, _343++)
            {
                int2 _349 = int3(gl_GlobalInvocationID).xy + int2(_343, _334);
                int _357;
                if (_343 < 0)
                {
                    _357 = max(_349.x, 0);
                }
                else
                {
                    _357 = _349.x;
                }
                int _365;
                if (_343 > 0)
                {
                    _365 = min(_357, (cbFSR2.iRenderSize.x - 1));
                }
                else
                {
                    _365 = _357;
                }
                int _373;
                if (_334 < 0)
                {
                    _373 = max(_349.y, 0);
                }
                else
                {
                    _373 = _349.y;
                }
                int2 _374 = int2(_365, _373);
                int _382;
                if (_334 > 0)
                {
                    _382 = min(_373, (cbFSR2.iRenderSize.y - 1));
                }
                else
                {
                    _382 = _373;
                }
                _374.y = _382;
                float2 _389 = (sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_374)), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
                float _390 = length(_389);
                _342 = precise::max(_390, _330);
                float2 _392 = float2(precise::max(_390, _342));
                _340 = precise::min(_333, dot(_389 / _392, _321 / _392));
            }
        }
        _396 = _329;
        _397 = _332;
    }
    else
    {
        _396 = _324;
        _397 = 1.0;
    }
    float2 _405 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_127), 0u).xy;
    float _421 = length(_405 * _133);
    float _435;
    if (_421 > 1.0)
    {
        _435 = mix(0.0, 1.0 - fast::clamp(length(r_previous_dilated_motion_vectors.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_126 + _405) * _125, _125 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize)), level(0.0)).xy) / length(_405), 0.0, 1.0), fast::clamp(powr(_421 * 0.0500000007450580596923828125, 3.0), 0.0, 1.0));
    }
    else
    {
        _435 = 0.0;
    }
    float _440 = (cbFSR2.fDeviceToViewDepth.y / (-cbFSR2.fDeviceToViewDepth.x)) * cbFSR2.fViewSpaceToMetersFactor;
    int _442;
    float _445;
    float _447;
    int _449;
    _442 = 0;
    _445 = 0.0;
    _447 = _440;
    _449 = -1;
    int _443;
    float _446;
    float _448;
    for (; _449 < 2; _442 = _443, _445 = _446, _447 = _448, _449++)
    {
        _446 = _445;
        _448 = _447;
        _443 = _442;
        for (int _459 = -1; _459 < 2; )
        {
            uint2 _465 = uint2(int3(gl_GlobalInvocationID).xy + int2(_459, _449));
            float _476 = ((cbFSR2.fDeviceToViewDepth.y / (sdk_hlsl_load(r_dilatedDepth, uint2(_465), 0u).x - cbFSR2.fDeviceToViewDepth.x)) * cbFSR2.fViewSpaceToMetersFactor) * float(all(_465 < uint2(cbFSR2.iRenderSize)));
            _446 = precise::max(_446, _476);
            _448 = precise::min(_448, _476);
            _443 |= int(_440 == _476);
            _459++;
            continue;
        }
    }
    float3 _489 = sdk_hlsl_load(r_input_color_jittered, uint2(_127), 0u).xyz;
    float2 _490 = float2(0.0, precise::max(fast::clamp(_435 - ((1.0 - (_447 / _445)) * ((_442 != 0) ? 0.0 : 1.0)), 0.0, 1.0), fast::clamp(1.0 - _397, 0.0, 1.0) * fast::clamp(_396 * 100.0, 0.0, 1.0)));
    int2 _491 = int3(gl_GlobalInvocationID).xy + int2(-1);
    int _495 = max(_491.y, 0);
    int2 _496 = int2(max(_491.x, 0), _495);
    _496.y = _495;
    uint2 _498 = uint2(_496);
    float4 _503 = sdk_hlsl_load(r_reactive_mask, uint2(_498), 0u);
    float _504 = _503.x;
    float4 _506 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_498), 0u);
    float _507 = _506.x;
    spvUnsafeArray<float3, 9> _116;
    _116[0] = sdk_hlsl_load(r_input_color_jittered, uint2(_498), 0u).xyz;
    spvUnsafeArray<float, 9> _117;
    _117[0] = _504;
    spvUnsafeArray<float, 9> _118;
    _118[0] = _507;
    int _514 = max(_250.y, 0);
    int2 _515 = int2(_250.x, _514);
    _515.y = _514;
    uint2 _517 = uint2(_515);
    float4 _522 = sdk_hlsl_load(r_reactive_mask, uint2(_517), 0u);
    float _523 = _522.x;
    float4 _525 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_517), 0u);
    float _526 = _525.x;
    _116[1] = sdk_hlsl_load(r_input_color_jittered, uint2(_517), 0u).xyz;
    _117[1] = _523;
    _118[1] = _526;
    int2 _532 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    int _535 = cbFSR2.iRenderSize.x - 1;
    int _538 = max(_532.y, 0);
    int2 _539 = int2(min(_532.x, _535), _538);
    _539.y = _538;
    uint2 _541 = uint2(_539);
    float4 _546 = sdk_hlsl_load(r_reactive_mask, uint2(_541), 0u);
    float _547 = _546.x;
    float4 _549 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_541), 0u);
    float _550 = _549.x;
    _116[2] = sdk_hlsl_load(r_input_color_jittered, uint2(_541), 0u).xyz;
    _117[2] = _547;
    _118[2] = _550;
    int2 _556 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    int _559 = _556.y;
    int2 _560 = int2(max(_556.x, 0), _559);
    _560.y = _559;
    uint2 _562 = uint2(_560);
    float4 _567 = sdk_hlsl_load(r_reactive_mask, uint2(_562), 0u);
    float _568 = _567.x;
    float4 _570 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_562), 0u);
    float _571 = _570.x;
    _116[3] = sdk_hlsl_load(r_input_color_jittered, uint2(_562), 0u).xyz;
    _117[3] = _568;
    _118[3] = _571;
    int2 _579 = int2(int3(gl_GlobalInvocationID).xy);
    _579.y = int3(gl_GlobalInvocationID).y;
    uint2 _581 = uint2(_579);
    float4 _586 = sdk_hlsl_load(r_reactive_mask, uint2(_581), 0u);
    float _587 = _586.x;
    float4 _589 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_581), 0u);
    float _590 = _589.x;
    _116[4] = sdk_hlsl_load(r_input_color_jittered, uint2(_581), 0u).xyz;
    _117[4] = _587;
    _118[4] = _590;
    int2 _596 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    int _599 = _596.y;
    int2 _600 = int2(min(_596.x, _535), _599);
    _600.y = _599;
    uint2 _602 = uint2(_600);
    float4 _607 = sdk_hlsl_load(r_reactive_mask, uint2(_602), 0u);
    float _608 = _607.x;
    float4 _610 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_602), 0u);
    float _611 = _610.x;
    _116[5] = sdk_hlsl_load(r_input_color_jittered, uint2(_602), 0u).xyz;
    _117[5] = _608;
    _118[5] = _611;
    int2 _617 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    int _620 = _617.y;
    int2 _621 = int2(max(_617.x, 0), _620);
    int _623 = cbFSR2.iRenderSize.y - 1;
    _621.y = min(_620, _623);
    uint2 _626 = uint2(_621);
    float4 _631 = sdk_hlsl_load(r_reactive_mask, uint2(_626), 0u);
    float _632 = _631.x;
    float4 _634 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_626), 0u);
    float _635 = _634.x;
    _116[6] = sdk_hlsl_load(r_input_color_jittered, uint2(_626), 0u).xyz;
    _117[6] = _632;
    _118[6] = _635;
    _264.y = min(_264.y, _623);
    uint2 _644 = uint2(_264);
    float4 _649 = sdk_hlsl_load(r_reactive_mask, uint2(_644), 0u);
    float _650 = _649.x;
    float4 _652 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_644), 0u);
    float _653 = _652.x;
    _116[7] = sdk_hlsl_load(r_input_color_jittered, uint2(_644), 0u).xyz;
    _117[7] = _650;
    _118[7] = _653;
    int2 _659 = int3(gl_GlobalInvocationID).xy + int2(1);
    int _662 = _659.y;
    int2 _663 = int2(min(_659.x, _535), _662);
    _663.y = min(_662, _623);
    uint2 _666 = uint2(_663);
    float4 _671 = sdk_hlsl_load(r_reactive_mask, uint2(_666), 0u);
    float _672 = _671.x;
    float4 _674 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_666), 0u);
    float _675 = _674.x;
    _116[8] = sdk_hlsl_load(r_input_color_jittered, uint2(_666), 0u).xyz;
    _117[8] = _672;
    _118[8] = _675;
    float2 _708;
    if ((((((((((_504 + _507) + (_523 + _526)) + (_547 + _550)) + (_568 + _571)) + (_587 + _590)) + (_608 + _611)) + (_632 + _635)) + (_650 + _653)) + (_672 + _675)) > 0.0)
    {
        float2 _685;
        _685 = _490;
        for (int _688 = 0; _688 < 9; )
        {
            float _704 = 7.0 - ((dot(_489, _116[_688]) / precise::max(dot(_489, _489), dot(_116[_688], _116[_688]))) * 6.0);
            _685 = precise::max(_685, float2(powr(_117[_688], _704), powr(_118[_688], _704)));
            _688++;
            continue;
        }
        _708 = _685;
    }
    else
    {
        _708 = _490;
    }
    sdk_hlsl_store(rw_dilated_reactive_masks, _708.xyyy, uint2(_127));
}

