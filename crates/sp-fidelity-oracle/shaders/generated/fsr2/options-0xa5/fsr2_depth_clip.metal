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

constant spvUnsafeArray<int2, 4> _100 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_exposure [[texture(2)]], texture2d<float> r_reactive_mask [[texture(3)]], texture2d<float> r_transparency_and_composition_mask [[texture(4)]], texture2d<uint> r_reconstructed_previous_nearest_depth [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_previous_dilated_motion_vectors [[texture(7)]], texture2d<float> r_dilatedDepth [[texture(8)]], texture2d<float, access::write> rw_prepared_input_color [[texture(9)]], texture2d<float, access::write> rw_dilated_reactive_masks [[texture(10)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _124 = float2(cbFSR2.iRenderSize);
    float2 _125 = (float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _124;
    uint2 _126 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _129 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_126), 0u).xy;
    float2 _132 = float2(cbFSR2.iDisplaySize);
    float4 _140 = sdk_hlsl_load(r_dilatedDepth, uint2(_126), 0u);
    float _141 = _140.x;
    float _147 = cbFSR2.fDeviceToViewDepth.y / (_141 - cbFSR2.fDeviceToViewDepth.x);
    float2 _149 = ((_125 + (_129 * float(length(_129 * _132) > 0.00999999977648258209228515625))) * _124) - float2(0.5);
    float2 _150 = floor(_149);
    int2 _151 = int2(_150);
    float2 _152 = _149 - _150;
    float _153 = _152.x;
    float _154 = 1.0 - _153;
    float _155 = _152.y;
    float _156 = 1.0 - _155;
    spvUnsafeArray<float, 4> _161 = spvUnsafeArray<float, 4>({ _154 * _156, _153 * _156, _154 * _155, _153 * _155 });
    spvUnsafeArray<float, 4> _113 = _161;
    float _163;
    float _166;
    _163 = 0.0;
    _166 = 0.0;
    float _164;
    float _167;
    for (int _168 = 0; _168 < 4; _163 = _164, _166 = _167, _168++)
    {
        uint2 _176 = uint2(_151 + _100[_168]);
        if (all(_176 < uint2(cbFSR2.iRenderSize)))
        {
            float _239;
            float _240;
            if (_113[_168] > 0.00999999977648258209228515625)
            {
                float _190 = as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(_176), 0u).x);
                float _192 = cbFSR2.fDeviceToViewDepth.y / (_190 - cbFSR2.fDeviceToViewDepth.x);
                float _193 = _147 - _192;
                float _237;
                float _238;
                if (_193 > 0.0)
                {
                    float _201 = cbFSR2.fDeviceToViewDepth.y / (precise::max(_190, _141) - cbFSR2.fDeviceToViewDepth.x);
                    float2 _205 = ((float2(int2(_124 * 0.5)) / _124) * float2(2.0, -2.0)) + float2(-1.0, 1.0);
                    float _219 = length(_124);
                    _237 = _163 + (powr(fast::clamp((((1.3699999726668465882539749145508e-05 * (length(float3((cbFSR2.fDeviceToViewDepth.z * (-1.0)) * _201, cbFSR2.fDeviceToViewDepth.w * _201, _201)) / length(float3((cbFSR2.fDeviceToViewDepth.z * _205.x) * _201, (cbFSR2.fDeviceToViewDepth.w * _205.y) * _201, _201)))) * _219) * precise::max(_147, _192)) / _193, 0.0, 1.0), mix(1.0, 3.0, fast::clamp(_219 / length(float2(1920.0, 1080.0)), 0.0, 1.0))) * _113[_168]);
                    _238 = _166 + _113[_168];
                }
                else
                {
                    _237 = _163;
                    _238 = _166;
                }
                _239 = _237;
                _240 = _238;
            }
            else
            {
                _239 = _163;
                _240 = _166;
            }
            _164 = _239;
            _167 = _240;
        }
        else
        {
            _164 = _163;
            _167 = _166;
        }
    }
    float _248;
    if (_166 > 0.0)
    {
        _248 = fast::clamp(1.0 - (_163 / _166), 0.0, 1.0);
    }
    else
    {
        _248 = 0.0;
    }
    int2 _249 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    float _262 = cbFSR2.fDeviceToViewDepth.y / (as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(_126), 0u).x) - cbFSR2.fDeviceToViewDepth.x);
    int2 _263 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    float _270 = cbFSR2.fDeviceToViewDepth.y / (as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(uint2(_263)), 0u).x) - cbFSR2.fDeviceToViewDepth.x);
    bool _279;
    if (((cbFSR2.fDeviceToViewDepth.y / (as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(uint2(_249)), 0u).x) - cbFSR2.fDeviceToViewDepth.x)) - _262) > (_262 * 0.00999999977648258209228515625))
    {
        _279 = (_262 - _270) > (_270 * 0.00999999977648258209228515625);
    }
    else
    {
        _279 = false;
    }
    float4 _287 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _288 = _287.x;
    float3 _296 = fast::clamp((precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(_126), 0u).xyz) / float3(cbFSR2.fPreExposure)) * ((_288 == 0.0) ? 1.0 : _288), float3(0.0), float3(65504.0));
    float _297 = _296.x;
    float _300 = 0.5 * _296.y;
    float _302 = _296.z;
    float _303 = 0.25 * _302;
    sdk_hlsl_store(rw_prepared_input_color, float4(((0.25 * _297) + _300) + _303, 0.5 * (_297 - _302), (((-0.25) * _297) + _300) - _303, _248 * (_279 ? 0.0 : 1.0)), uint2(_126));
    float2 _317 = sdk_hlsl_load(r_input_motion_vectors, uint2(_126), 0u).xy * cbFSR2.fMotionVectorScale;
    float _320 = length(_317);
    float _391;
    float _392;
    if (length(_317 * _124) > 0.00999999977648258209228515625)
    {
        float _325;
        float _328;
        _325 = _320;
        _328 = 1.0;
        float _326;
        float _329;
        for (int _330 = -1; _330 <= 1; _325 = _326, _328 = _329, _330++)
        {
            _329 = _328;
            _326 = _325;
            float _336;
            float _338;
            for (int _339 = -1; _339 <= 1; _329 = _336, _326 = _338, _339++)
            {
                int2 _345 = int3(gl_GlobalInvocationID).xy + int2(_339, _330);
                int _353;
                if (_339 < 0)
                {
                    _353 = max(_345.x, 0);
                }
                else
                {
                    _353 = _345.x;
                }
                int _361;
                if (_339 > 0)
                {
                    _361 = min(_353, (cbFSR2.iRenderSize.x - 1));
                }
                else
                {
                    _361 = _353;
                }
                int _369;
                if (_330 < 0)
                {
                    _369 = max(_345.y, 0);
                }
                else
                {
                    _369 = _345.y;
                }
                int2 _370 = int2(_361, _369);
                int _378;
                if (_330 > 0)
                {
                    _378 = min(_369, (cbFSR2.iRenderSize.y - 1));
                }
                else
                {
                    _378 = _369;
                }
                _370.y = _378;
                float2 _384 = sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_370)), 0u).xy * cbFSR2.fMotionVectorScale;
                float _385 = length(_384);
                _338 = precise::max(_385, _326);
                float2 _387 = float2(precise::max(_385, _338));
                _336 = precise::min(_329, dot(_384 / _387, _317 / _387));
            }
        }
        _391 = _325;
        _392 = _328;
    }
    else
    {
        _391 = _320;
        _392 = 1.0;
    }
    float2 _400 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_126), 0u).xy;
    float _416 = length(_400 * _132);
    float _430;
    if (_416 > 1.0)
    {
        _430 = mix(0.0, 1.0 - fast::clamp(length(r_previous_dilated_motion_vectors.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_125 + _400) * _124, _124 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize)), level(0.0)).xy) / length(_400), 0.0, 1.0), fast::clamp(powr(_416 * 0.0500000007450580596923828125, 3.0), 0.0, 1.0));
    }
    else
    {
        _430 = 0.0;
    }
    float _435 = (cbFSR2.fDeviceToViewDepth.y / (1.0 - cbFSR2.fDeviceToViewDepth.x)) * cbFSR2.fViewSpaceToMetersFactor;
    int _437;
    float _440;
    float _442;
    int _444;
    _437 = 0;
    _440 = 0.0;
    _442 = _435;
    _444 = -1;
    int _438;
    float _441;
    float _443;
    for (; _444 < 2; _437 = _438, _440 = _441, _442 = _443, _444++)
    {
        _441 = _440;
        _443 = _442;
        _438 = _437;
        for (int _454 = -1; _454 < 2; )
        {
            uint2 _460 = uint2(int3(gl_GlobalInvocationID).xy + int2(_454, _444));
            float _471 = ((cbFSR2.fDeviceToViewDepth.y / (sdk_hlsl_load(r_dilatedDepth, uint2(_460), 0u).x - cbFSR2.fDeviceToViewDepth.x)) * cbFSR2.fViewSpaceToMetersFactor) * float(all(_460 < uint2(cbFSR2.iRenderSize)));
            _441 = precise::max(_441, _471);
            _443 = precise::min(_443, _471);
            _438 |= int(_435 == _471);
            _454++;
            continue;
        }
    }
    float3 _484 = sdk_hlsl_load(r_input_color_jittered, uint2(_126), 0u).xyz;
    float2 _485 = float2(0.0, precise::max(fast::clamp(_430 - ((1.0 - (_442 / _440)) * ((_437 != 0) ? 0.0 : 1.0)), 0.0, 1.0), fast::clamp(1.0 - _392, 0.0, 1.0) * fast::clamp(_391 * 100.0, 0.0, 1.0)));
    int2 _486 = int3(gl_GlobalInvocationID).xy + int2(-1);
    int _490 = max(_486.y, 0);
    int2 _491 = int2(max(_486.x, 0), _490);
    _491.y = _490;
    uint2 _493 = uint2(_491);
    float4 _498 = sdk_hlsl_load(r_reactive_mask, uint2(_493), 0u);
    float _499 = _498.x;
    float4 _501 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_493), 0u);
    float _502 = _501.x;
    spvUnsafeArray<float3, 9> _115;
    _115[0] = sdk_hlsl_load(r_input_color_jittered, uint2(_493), 0u).xyz;
    spvUnsafeArray<float, 9> _116;
    _116[0] = _499;
    spvUnsafeArray<float, 9> _117;
    _117[0] = _502;
    int _509 = max(_249.y, 0);
    int2 _510 = int2(_249.x, _509);
    _510.y = _509;
    uint2 _512 = uint2(_510);
    float4 _517 = sdk_hlsl_load(r_reactive_mask, uint2(_512), 0u);
    float _518 = _517.x;
    float4 _520 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_512), 0u);
    float _521 = _520.x;
    _115[1] = sdk_hlsl_load(r_input_color_jittered, uint2(_512), 0u).xyz;
    _116[1] = _518;
    _117[1] = _521;
    int2 _527 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    int _530 = cbFSR2.iRenderSize.x - 1;
    int _533 = max(_527.y, 0);
    int2 _534 = int2(min(_527.x, _530), _533);
    _534.y = _533;
    uint2 _536 = uint2(_534);
    float4 _541 = sdk_hlsl_load(r_reactive_mask, uint2(_536), 0u);
    float _542 = _541.x;
    float4 _544 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_536), 0u);
    float _545 = _544.x;
    _115[2] = sdk_hlsl_load(r_input_color_jittered, uint2(_536), 0u).xyz;
    _116[2] = _542;
    _117[2] = _545;
    int2 _551 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    int _554 = _551.y;
    int2 _555 = int2(max(_551.x, 0), _554);
    _555.y = _554;
    uint2 _557 = uint2(_555);
    float4 _562 = sdk_hlsl_load(r_reactive_mask, uint2(_557), 0u);
    float _563 = _562.x;
    float4 _565 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_557), 0u);
    float _566 = _565.x;
    _115[3] = sdk_hlsl_load(r_input_color_jittered, uint2(_557), 0u).xyz;
    _116[3] = _563;
    _117[3] = _566;
    int2 _574 = int2(int3(gl_GlobalInvocationID).xy);
    _574.y = int3(gl_GlobalInvocationID).y;
    uint2 _576 = uint2(_574);
    float4 _581 = sdk_hlsl_load(r_reactive_mask, uint2(_576), 0u);
    float _582 = _581.x;
    float4 _584 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_576), 0u);
    float _585 = _584.x;
    _115[4] = sdk_hlsl_load(r_input_color_jittered, uint2(_576), 0u).xyz;
    _116[4] = _582;
    _117[4] = _585;
    int2 _591 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    int _594 = _591.y;
    int2 _595 = int2(min(_591.x, _530), _594);
    _595.y = _594;
    uint2 _597 = uint2(_595);
    float4 _602 = sdk_hlsl_load(r_reactive_mask, uint2(_597), 0u);
    float _603 = _602.x;
    float4 _605 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_597), 0u);
    float _606 = _605.x;
    _115[5] = sdk_hlsl_load(r_input_color_jittered, uint2(_597), 0u).xyz;
    _116[5] = _603;
    _117[5] = _606;
    int2 _612 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    int _615 = _612.y;
    int2 _616 = int2(max(_612.x, 0), _615);
    int _618 = cbFSR2.iRenderSize.y - 1;
    _616.y = min(_615, _618);
    uint2 _621 = uint2(_616);
    float4 _626 = sdk_hlsl_load(r_reactive_mask, uint2(_621), 0u);
    float _627 = _626.x;
    float4 _629 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_621), 0u);
    float _630 = _629.x;
    _115[6] = sdk_hlsl_load(r_input_color_jittered, uint2(_621), 0u).xyz;
    _116[6] = _627;
    _117[6] = _630;
    _263.y = min(_263.y, _618);
    uint2 _639 = uint2(_263);
    float4 _644 = sdk_hlsl_load(r_reactive_mask, uint2(_639), 0u);
    float _645 = _644.x;
    float4 _647 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_639), 0u);
    float _648 = _647.x;
    _115[7] = sdk_hlsl_load(r_input_color_jittered, uint2(_639), 0u).xyz;
    _116[7] = _645;
    _117[7] = _648;
    int2 _654 = int3(gl_GlobalInvocationID).xy + int2(1);
    int _657 = _654.y;
    int2 _658 = int2(min(_654.x, _530), _657);
    _658.y = min(_657, _618);
    uint2 _661 = uint2(_658);
    float4 _666 = sdk_hlsl_load(r_reactive_mask, uint2(_661), 0u);
    float _667 = _666.x;
    float4 _669 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_661), 0u);
    float _670 = _669.x;
    _115[8] = sdk_hlsl_load(r_input_color_jittered, uint2(_661), 0u).xyz;
    _116[8] = _667;
    _117[8] = _670;
    float2 _703;
    if ((((((((((_499 + _502) + (_518 + _521)) + (_542 + _545)) + (_563 + _566)) + (_582 + _585)) + (_603 + _606)) + (_627 + _630)) + (_645 + _648)) + (_667 + _670)) > 0.0)
    {
        float2 _680;
        _680 = _485;
        for (int _683 = 0; _683 < 9; )
        {
            float _699 = 7.0 - ((dot(_484, _115[_683]) / precise::max(dot(_484, _484), dot(_115[_683], _115[_683]))) * 6.0);
            _680 = precise::max(_680, float2(powr(_116[_683], _699), powr(_117[_683], _699)));
            _683++;
            continue;
        }
        _703 = _680;
    }
    else
    {
        _703 = _485;
    }
    sdk_hlsl_store(rw_dilated_reactive_masks, _703.xyyy, uint2(_126));
}

