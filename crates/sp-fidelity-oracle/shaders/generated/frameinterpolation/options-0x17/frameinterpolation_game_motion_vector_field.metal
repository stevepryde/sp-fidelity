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

constant float3 _96 = {};

constant spvUnsafeArray<int2, 4> _107 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_previous_interpolation_source [[texture(0)]], texture2d<float> r_current_interpolation_source [[texture(1)]], texture2d<float> r_dilated_motion_vectors [[texture(2)]], texture2d<float> r_dilated_depth [[texture(3)]], texture2d<float> r_input_distortion_field [[texture(4)]], texture2d<uint, access::read_write> rw_game_motion_vector_field_x [[texture(5)]], texture2d<uint, access::read_write> rw_game_motion_vector_field_y [[texture(6)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _120 = float2(cbFI.renderSize);
    float2 _121 = (float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _120;
    float2 _134 = float2(cbFI.displaySize);
    float2 _139 = float2(cbFI.interpolationRectSize) / _134;
    float2 _141 = (float2(cbFI.interpolationRectBase) / _134) + (_121 * _139);
    uint2 _143 = uint2(int3(gl_GlobalInvocationID).xy + int2(r_input_distortion_field.sample(s_LinearClamp, _121, level(0.0)).xy * _120));
    float2 _149 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_143), 0u).xy;
    float2 _150 = _149 * 0.5;
    float2 _151 = _121 + _150;
    float _158 = powr(cbFI.fDeviceToViewDepth.y / (sdk_hlsl_load(r_dilated_depth, uint2(_143), 0u).x - cbFI.fDeviceToViewDepth.x), 0.3300000131130218505859375);
    uint _165 = max(1u, uint((1.0 - (_158 * (1.0 / (1.0 + _158)))) * 1023.0));
    float2 _167 = _141 + (_149 * _139);
    float3 _172 = r_previous_interpolation_source.sample(s_LinearClamp, _167, level(0.0)).xyz;
    float3 _177 = r_current_interpolation_source.sample(s_LinearClamp, _141, level(0.0)).xyz;
    float _311;
    switch (cbFI.backBufferTransferFunction)
    {
        case 0u:
        {
            float3 _222;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _190 = fast::clamp((_172 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _194 = powr((_172 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _222 = (_190 * (_172 * float3(0.077399380505084991455078125))) + (((-_190) * _194) + _194);
                    break;
                }
                case 1u:
                {
                    float3 _200 = powr(_172, float3(0.01268330030143260955810546875));
                    _222 = powr(fast::clamp(_200 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _200)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _222 = (_172 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _222 = _96;
                    break;
                }
            }
            _311 = dot(_222, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        case 1u:
        {
            float3 _262;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _230 = fast::clamp((_172 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _234 = powr((_172 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _262 = (_230 * (_172 * float3(0.077399380505084991455078125))) + (((-_230) * _234) + _234);
                    break;
                }
                case 1u:
                {
                    float3 _240 = powr(_172, float3(0.01268330030143260955810546875));
                    _262 = powr(fast::clamp(_240 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _240)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _262 = (_172 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _262 = _96;
                    break;
                }
            }
            _311 = ((0.2626999914646148681640625 * _262.x) + (0.677999973297119140625 * _262.y)) + (0.0593000017106533050537109375 * _262.z);
            break;
        }
        case 2u:
        {
            float3 _309;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _277 = fast::clamp((_172 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _281 = powr((_172 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _309 = (_277 * (_172 * float3(0.077399380505084991455078125))) + (((-_277) * _281) + _281);
                    break;
                }
                case 1u:
                {
                    float3 _287 = powr(_172, float3(0.01268330030143260955810546875));
                    _309 = powr(fast::clamp(_287 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _287)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _309 = (_172 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _309 = _96;
                    break;
                }
            }
            _311 = dot(_309, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        default:
        {
            _311 = 0.0;
            break;
        }
    }
    float _312 = 0.001000000047497451305389404296875 + _311;
    float _444;
    switch (cbFI.backBufferTransferFunction)
    {
        case 0u:
        {
            float3 _355;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _323 = fast::clamp((_177 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _327 = powr((_177 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _355 = (_323 * (_177 * float3(0.077399380505084991455078125))) + (((-_323) * _327) + _327);
                    break;
                }
                case 1u:
                {
                    float3 _333 = powr(_177, float3(0.01268330030143260955810546875));
                    _355 = powr(fast::clamp(_333 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _333)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _355 = (_177 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _355 = _96;
                    break;
                }
            }
            _444 = dot(_355, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        case 1u:
        {
            float3 _395;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _363 = fast::clamp((_177 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _367 = powr((_177 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _395 = (_363 * (_177 * float3(0.077399380505084991455078125))) + (((-_363) * _367) + _367);
                    break;
                }
                case 1u:
                {
                    float3 _373 = powr(_177, float3(0.01268330030143260955810546875));
                    _395 = powr(fast::clamp(_373 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _373)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _395 = (_177 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _395 = _96;
                    break;
                }
            }
            _444 = ((0.2626999914646148681640625 * _395.x) + (0.677999973297119140625 * _395.y)) + (0.0593000017106533050537109375 * _395.z);
            break;
        }
        case 2u:
        {
            float3 _442;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _410 = fast::clamp((_177 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _414 = powr((_177 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _442 = (_410 * (_177 * float3(0.077399380505084991455078125))) + (((-_410) * _414) + _414);
                    break;
                }
                case 1u:
                {
                    float3 _420 = powr(_177, float3(0.01268330030143260955810546875));
                    _442 = powr(fast::clamp(_420 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _420)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _442 = (_177 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _442 = _96;
                    break;
                }
            }
            _444 = dot(_442, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        default:
        {
            _444 = 0.0;
            break;
        }
    }
    float _445 = 0.001000000047497451305389404296875 + _444;
    float _446 = precise::max(_312, _445);
    float _453;
    if (_446 != 0.0)
    {
        _453 = precise::min(_312, _445) / _446;
    }
    else
    {
        _453 = 0.0;
    }
    float _458 = _167.x;
    bool _463;
    if (_458 > 0.0)
    {
        _463 = _458 < 1.0;
    }
    else
    {
        _463 = false;
    }
    bool _472;
    if (_463)
    {
        float _466 = _167.y;
        bool _471;
        if (_466 > 0.0)
        {
            _471 = _466 < 1.0;
        }
        else
        {
            _471 = false;
        }
        _472 = _471;
    }
    else
    {
        _472 = false;
    }
    uint _480 = (2147483648u | ((_165 & 1023u) << 21u)) | (((uint(rint(powr(_453, 1.0) * 31.0)) * uint(_472)) & 31u) << 16u);
    uint _483 = as_type<uint>(half2(float2(_150.x, 0.0)));
    uint _484 = _480 | _483;
    uint _487 = as_type<uint>(half2(float2(_150.y, 0.0)));
    uint _488 = _480 | _487;
    int2 _492 = int2(floor((_151 * _120) - float2(0.5)));
    for (int _494 = 0; _494 < 4; _494++)
    {
        uint2 _503 = uint2(_492 + _107[_494]);
        if (all(_503 < uint2(cbFI.renderSize)))
        {
            uint _510 = rw_game_motion_vector_field_x.atomic_fetch_max(_503, _484).x;
            uint _512 = rw_game_motion_vector_field_y.atomic_fetch_max(_503, _488).x;
        }
    }
    if (length(_150 * _120) > 0.001000000047497451305389404296875)
    {
        float _519 = length(float2(1.0) / _120);
        float2 _520 = fast::normalize(_149);
        float _523 = precise::min(length(_150), length(float2(0.5)));
        bool _526;
        uint _531;
        bool _525 = true;
        float _528 = _519;
        uint _530 = 0u;
        for (; (_528 <= _523) ? _525 : false; _525 = _526, _528 += _519, _530 = _531)
        {
            float2 _537 = _151 - (_520 * _528);
            int2 _541 = int2(floor((_537 * _120) - float2(0.5)));
            uint _554 = ((max(1u, (1023u - _165)) & 1023u) << 21u) | ((uint(precise::max(0.0, dot(fast::normalize(float2(0.5) - _537), _520)) * 31.0) & 31u) << 16u);
            uint _555 = _554 | _483;
            uint _556 = _554 | _487;
            _531 = _530;
            _526 = _525;
            uint _558;
            bool _560;
            for (int _561 = 0; _561 < 1; _531 = _558, _526 = _560, _561++)
            {
                int2 _568 = _541 + _107[_561];
                bool _575;
                if (_526)
                {
                    _575 = all(uint2(_568) < uint2(cbFI.renderSize));
                }
                else
                {
                    _575 = false;
                }
                if (_575)
                {
                    uint2 _578 = uint2(_568);
                    uint _580 = rw_game_motion_vector_field_x.atomic_fetch_max(_578, _555).x;
                    uint _582 = rw_game_motion_vector_field_y.atomic_fetch_max(_578, _556).x;
                    uint _587 = _531 + uint((max(_580, _582) & 2147483648u) != 0u);
                    bool _591;
                    if (_575)
                    {
                        _591 = _587 <= 3u;
                    }
                    else
                    {
                        _591 = false;
                    }
                    _558 = _587;
                    _560 = _591;
                }
                else
                {
                    _558 = _531;
                    _560 = _575;
                }
            }
        }
    }
}

