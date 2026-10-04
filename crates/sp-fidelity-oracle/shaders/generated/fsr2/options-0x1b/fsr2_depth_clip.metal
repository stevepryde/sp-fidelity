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

constant spvUnsafeArray<int2, 4> _102 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_input_exposure [[texture(2)]], texture2d<float> r_reactive_mask [[texture(3)]], texture2d<float> r_transparency_and_composition_mask [[texture(4)]], texture2d<uint> r_reconstructed_previous_nearest_depth [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_previous_dilated_motion_vectors [[texture(7)]], texture2d<float> r_dilatedDepth [[texture(8)]], texture2d<float, access::write> rw_prepared_input_color [[texture(9)]], texture2d<float, access::write> rw_dilated_reactive_masks [[texture(10)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _122 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _125 = float2(cbFSR2.iRenderSize);
    float2 _126 = _122 / _125;
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
        uint2 _177 = uint2(_152 + _102[_169]);
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
    int2 _319 = int2(floor(((_122 - cbFSR2.fJitter) / _125) * _133));
    float2 _329 = (sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_319)), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
    float _332 = length(_329);
    float _404;
    float _405;
    if (length(_329 * _125) > 0.00999999977648258209228515625)
    {
        float _337;
        float _340;
        _337 = _332;
        _340 = 1.0;
        float _338;
        float _341;
        for (int _342 = -1; _342 <= 1; _337 = _338, _340 = _341, _342++)
        {
            _341 = _340;
            _338 = _337;
            float _348;
            float _350;
            for (int _351 = -1; _351 <= 1; _341 = _348, _338 = _350, _351++)
            {
                int2 _357 = _319 + int2(_351, _342);
                int _365;
                if (_351 < 0)
                {
                    _365 = max(_357.x, 0);
                }
                else
                {
                    _365 = _357.x;
                }
                int _373;
                if (_351 > 0)
                {
                    _373 = min(_365, (cbFSR2.iRenderSize.x - 1));
                }
                else
                {
                    _373 = _365;
                }
                int _381;
                if (_342 < 0)
                {
                    _381 = max(_357.y, 0);
                }
                else
                {
                    _381 = _357.y;
                }
                int2 _382 = int2(_373, _381);
                int _390;
                if (_342 > 0)
                {
                    _390 = min(_381, (cbFSR2.iRenderSize.y - 1));
                }
                else
                {
                    _390 = _381;
                }
                _382.y = _390;
                float2 _397 = (sdk_hlsl_load(r_input_motion_vectors, uint2(uint2(_382)), 0u).xy * cbFSR2.fMotionVectorScale) - cbFSR2.fMotionVectorJitterCancellation;
                float _398 = length(_397);
                _350 = precise::max(_398, _338);
                float2 _400 = float2(precise::max(_398, _350));
                _348 = precise::min(_341, dot(_397 / _400, _329 / _400));
            }
        }
        _404 = _337;
        _405 = _340;
    }
    else
    {
        _404 = _332;
        _405 = 1.0;
    }
    float2 _413 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_127), 0u).xy;
    float _429 = length(_413 * _133);
    float _443;
    if (_429 > 1.0)
    {
        _443 = mix(0.0, 1.0 - fast::clamp(length(r_previous_dilated_motion_vectors.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_126 + _413) * _125, _125 - float2(0.5))) / float2(cbFSR2.iMaxRenderSize)), level(0.0)).xy) / length(_413), 0.0, 1.0), fast::clamp(powr(_429 * 0.0500000007450580596923828125, 3.0), 0.0, 1.0));
    }
    else
    {
        _443 = 0.0;
    }
    float _448 = (cbFSR2.fDeviceToViewDepth.y / (-cbFSR2.fDeviceToViewDepth.x)) * cbFSR2.fViewSpaceToMetersFactor;
    int _450;
    float _453;
    float _455;
    int _457;
    _450 = 0;
    _453 = 0.0;
    _455 = _448;
    _457 = -1;
    int _451;
    float _454;
    float _456;
    for (; _457 < 2; _450 = _451, _453 = _454, _455 = _456, _457++)
    {
        _454 = _453;
        _456 = _455;
        _451 = _450;
        for (int _467 = -1; _467 < 2; )
        {
            uint2 _473 = uint2(int3(gl_GlobalInvocationID).xy + int2(_467, _457));
            float _484 = ((cbFSR2.fDeviceToViewDepth.y / (sdk_hlsl_load(r_dilatedDepth, uint2(_473), 0u).x - cbFSR2.fDeviceToViewDepth.x)) * cbFSR2.fViewSpaceToMetersFactor) * float(all(_473 < uint2(cbFSR2.iRenderSize)));
            _454 = precise::max(_454, _484);
            _456 = precise::min(_456, _484);
            _451 |= int(_448 == _484);
            _467++;
            continue;
        }
    }
    float3 _497 = sdk_hlsl_load(r_input_color_jittered, uint2(_127), 0u).xyz;
    float2 _498 = float2(0.0, precise::max(fast::clamp(_443 - ((1.0 - (_455 / _453)) * ((_450 != 0) ? 0.0 : 1.0)), 0.0, 1.0), fast::clamp(1.0 - _405, 0.0, 1.0) * fast::clamp(_404 * 100.0, 0.0, 1.0)));
    int2 _499 = int3(gl_GlobalInvocationID).xy + int2(-1);
    int _503 = max(_499.y, 0);
    int2 _504 = int2(max(_499.x, 0), _503);
    _504.y = _503;
    uint2 _506 = uint2(_504);
    float4 _511 = sdk_hlsl_load(r_reactive_mask, uint2(_506), 0u);
    float _512 = _511.x;
    float4 _514 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_506), 0u);
    float _515 = _514.x;
    spvUnsafeArray<float3, 9> _116;
    _116[0] = sdk_hlsl_load(r_input_color_jittered, uint2(_506), 0u).xyz;
    spvUnsafeArray<float, 9> _117;
    _117[0] = _512;
    spvUnsafeArray<float, 9> _118;
    _118[0] = _515;
    int _522 = max(_250.y, 0);
    int2 _523 = int2(_250.x, _522);
    _523.y = _522;
    uint2 _525 = uint2(_523);
    float4 _530 = sdk_hlsl_load(r_reactive_mask, uint2(_525), 0u);
    float _531 = _530.x;
    float4 _533 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_525), 0u);
    float _534 = _533.x;
    _116[1] = sdk_hlsl_load(r_input_color_jittered, uint2(_525), 0u).xyz;
    _117[1] = _531;
    _118[1] = _534;
    int2 _540 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    int _543 = cbFSR2.iRenderSize.x - 1;
    int _546 = max(_540.y, 0);
    int2 _547 = int2(min(_540.x, _543), _546);
    _547.y = _546;
    uint2 _549 = uint2(_547);
    float4 _554 = sdk_hlsl_load(r_reactive_mask, uint2(_549), 0u);
    float _555 = _554.x;
    float4 _557 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_549), 0u);
    float _558 = _557.x;
    _116[2] = sdk_hlsl_load(r_input_color_jittered, uint2(_549), 0u).xyz;
    _117[2] = _555;
    _118[2] = _558;
    int2 _564 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    int _567 = _564.y;
    int2 _568 = int2(max(_564.x, 0), _567);
    _568.y = _567;
    uint2 _570 = uint2(_568);
    float4 _575 = sdk_hlsl_load(r_reactive_mask, uint2(_570), 0u);
    float _576 = _575.x;
    float4 _578 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_570), 0u);
    float _579 = _578.x;
    _116[3] = sdk_hlsl_load(r_input_color_jittered, uint2(_570), 0u).xyz;
    _117[3] = _576;
    _118[3] = _579;
    int2 _587 = int2(int3(gl_GlobalInvocationID).xy);
    _587.y = int3(gl_GlobalInvocationID).y;
    uint2 _589 = uint2(_587);
    float4 _594 = sdk_hlsl_load(r_reactive_mask, uint2(_589), 0u);
    float _595 = _594.x;
    float4 _597 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_589), 0u);
    float _598 = _597.x;
    _116[4] = sdk_hlsl_load(r_input_color_jittered, uint2(_589), 0u).xyz;
    _117[4] = _595;
    _118[4] = _598;
    int2 _604 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    int _607 = _604.y;
    int2 _608 = int2(min(_604.x, _543), _607);
    _608.y = _607;
    uint2 _610 = uint2(_608);
    float4 _615 = sdk_hlsl_load(r_reactive_mask, uint2(_610), 0u);
    float _616 = _615.x;
    float4 _618 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_610), 0u);
    float _619 = _618.x;
    _116[5] = sdk_hlsl_load(r_input_color_jittered, uint2(_610), 0u).xyz;
    _117[5] = _616;
    _118[5] = _619;
    int2 _625 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    int _628 = _625.y;
    int2 _629 = int2(max(_625.x, 0), _628);
    int _631 = cbFSR2.iRenderSize.y - 1;
    _629.y = min(_628, _631);
    uint2 _634 = uint2(_629);
    float4 _639 = sdk_hlsl_load(r_reactive_mask, uint2(_634), 0u);
    float _640 = _639.x;
    float4 _642 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_634), 0u);
    float _643 = _642.x;
    _116[6] = sdk_hlsl_load(r_input_color_jittered, uint2(_634), 0u).xyz;
    _117[6] = _640;
    _118[6] = _643;
    _264.y = min(_264.y, _631);
    uint2 _652 = uint2(_264);
    float4 _657 = sdk_hlsl_load(r_reactive_mask, uint2(_652), 0u);
    float _658 = _657.x;
    float4 _660 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_652), 0u);
    float _661 = _660.x;
    _116[7] = sdk_hlsl_load(r_input_color_jittered, uint2(_652), 0u).xyz;
    _117[7] = _658;
    _118[7] = _661;
    int2 _667 = int3(gl_GlobalInvocationID).xy + int2(1);
    int _670 = _667.y;
    int2 _671 = int2(min(_667.x, _543), _670);
    _671.y = min(_670, _631);
    uint2 _674 = uint2(_671);
    float4 _679 = sdk_hlsl_load(r_reactive_mask, uint2(_674), 0u);
    float _680 = _679.x;
    float4 _682 = sdk_hlsl_load(r_transparency_and_composition_mask, uint2(_674), 0u);
    float _683 = _682.x;
    _116[8] = sdk_hlsl_load(r_input_color_jittered, uint2(_674), 0u).xyz;
    _117[8] = _680;
    _118[8] = _683;
    float2 _716;
    if ((((((((((_512 + _515) + (_531 + _534)) + (_555 + _558)) + (_576 + _579)) + (_595 + _598)) + (_616 + _619)) + (_640 + _643)) + (_658 + _661)) + (_680 + _683)) > 0.0)
    {
        float2 _693;
        _693 = _498;
        for (int _696 = 0; _696 < 9; )
        {
            float _712 = 7.0 - ((dot(_497, _116[_696]) / precise::max(dot(_497, _497), dot(_116[_696], _116[_696]))) * 6.0);
            _693 = precise::max(_693, float2(powr(_117[_696], _712), powr(_118[_696], _712)));
            _696++;
            continue;
        }
        _716 = _693;
    }
    else
    {
        _716 = _498;
    }
    sdk_hlsl_store(rw_dilated_reactive_masks, _716.xyyy, uint2(_127));
}

