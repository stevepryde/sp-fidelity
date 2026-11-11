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

constant float3 _99 = {};

constant spvUnsafeArray<int2, 4> _111 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_previous_interpolation_source [[texture(0)]], texture2d<float> r_current_interpolation_source [[texture(1)]], texture2d<int> r_optical_flow [[texture(2)]], texture2d<uint, access::read_write> rw_optical_flow_motion_vector_field_x [[texture(3)]], texture2d<uint, access::read_write> rw_optical_flow_motion_vector_field_y [[texture(4)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _120;
    float _123;
    int _125;
    _120 = float2(0.0);
    _123 = 0.0;
    _125 = -1;
    float2 _121;
    float _124;
    for (; _125 <= 1; _120 = _121, _123 = _124, _125++)
    {
        _124 = _123;
        _121 = _120;
        for (int _134 = -1; _134 <= 1; )
        {
            float2 _147 = float2(sdk_hlsl_load(r_optical_flow, uint2(uint2(int3(gl_GlobalInvocationID).xy + int2(_134, _125))), 0u).xy) * cbFI.opticalFlowScale;
            float _152 = length(_147 * float2(cbFI.interpolationRectSize));
            float _157 = precise::max(0.0, 512.0 - _152) * float(_152 > 1.0);
            _124 += _157;
            _121 += (_147 * _157);
            _134++;
            continue;
        }
    }
    float2 _160 = _120 / float2(_123);
    float2 _162;
    float _165;
    int _167;
    _162 = float2(0.0);
    _165 = 0.0;
    _167 = -1;
    float2 _163;
    float _166;
    for (; _167 <= 1; _162 = _163, _165 = _166, _167++)
    {
        _166 = _165;
        _163 = _162;
        for (int _176 = -1; _176 <= 1; )
        {
            float2 _189 = float2(sdk_hlsl_load(r_optical_flow, uint2(uint2(int3(gl_GlobalInvocationID).xy + int2(_176, _167))), 0u).xy) * cbFI.opticalFlowScale;
            float _194 = length(_189 * float2(cbFI.interpolationRectSize));
            float _203 = precise::max(0.0, powr(dot(_160, _189), 1.25)) * (precise::max(0.0, 512.0 - _194) * float(_194 > 1.0));
            _166 += _203;
            _163 += (_189 * _203);
            _176++;
            continue;
        }
    }
    float2 _210;
    if (_165 > 0.001000000047497451305389404296875)
    {
        _210 = _162 / float2(_165);
    }
    else
    {
        _210 = _162;
    }
    int2 _223 = int2((float2(1.0) / cbFI.opticalFlowScale) / float2(int2(cbFI.opticalFlowBlockSize))) * int2(1);
    float2 _224 = float2(_223);
    float2 _225 = (float2(uint2(int3(gl_GlobalInvocationID).xy)) + float2(0.5)) / _224;
    float2 _226 = _210 * 0.5;
    float2 _227 = _225 + _210;
    float3 _232 = r_previous_interpolation_source.sample(s_LinearClamp, _227, level(0.0)).xyz;
    float3 _237 = r_current_interpolation_source.sample(s_LinearClamp, _225, level(0.0)).xyz;
    float _371;
    switch (cbFI.backBufferTransferFunction)
    {
        case 0u:
        {
            float3 _282;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _250 = fast::clamp((_232 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _254 = powr((_232 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _282 = (_250 * (_232 * float3(0.077399380505084991455078125))) + (((-_250) * _254) + _254);
                    break;
                }
                case 1u:
                {
                    float3 _260 = powr(_232, float3(0.01268330030143260955810546875));
                    _282 = powr(fast::clamp(_260 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _260)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _282 = (_232 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _282 = _99;
                    break;
                }
            }
            _371 = dot(_282, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        case 1u:
        {
            float3 _322;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _290 = fast::clamp((_232 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _294 = powr((_232 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _322 = (_290 * (_232 * float3(0.077399380505084991455078125))) + (((-_290) * _294) + _294);
                    break;
                }
                case 1u:
                {
                    float3 _300 = powr(_232, float3(0.01268330030143260955810546875));
                    _322 = powr(fast::clamp(_300 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _300)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _322 = (_232 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _322 = _99;
                    break;
                }
            }
            _371 = ((0.2626999914646148681640625 * _322.x) + (0.677999973297119140625 * _322.y)) + (0.0593000017106533050537109375 * _322.z);
            break;
        }
        case 2u:
        {
            float3 _369;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _337 = fast::clamp((_232 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _341 = powr((_232 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _369 = (_337 * (_232 * float3(0.077399380505084991455078125))) + (((-_337) * _341) + _341);
                    break;
                }
                case 1u:
                {
                    float3 _347 = powr(_232, float3(0.01268330030143260955810546875));
                    _369 = powr(fast::clamp(_347 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _347)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _369 = (_232 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _369 = _99;
                    break;
                }
            }
            _371 = dot(_369, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        default:
        {
            _371 = 0.0;
            break;
        }
    }
    float _372 = 0.001000000047497451305389404296875 + _371;
    float _504;
    switch (cbFI.backBufferTransferFunction)
    {
        case 0u:
        {
            float3 _415;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _383 = fast::clamp((_237 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _387 = powr((_237 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _415 = (_383 * (_237 * float3(0.077399380505084991455078125))) + (((-_383) * _387) + _387);
                    break;
                }
                case 1u:
                {
                    float3 _393 = powr(_237, float3(0.01268330030143260955810546875));
                    _415 = powr(fast::clamp(_393 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _393)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _415 = (_237 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _415 = _99;
                    break;
                }
            }
            _504 = dot(_415, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        case 1u:
        {
            float3 _455;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _423 = fast::clamp((_237 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _427 = powr((_237 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _455 = (_423 * (_237 * float3(0.077399380505084991455078125))) + (((-_423) * _427) + _427);
                    break;
                }
                case 1u:
                {
                    float3 _433 = powr(_237, float3(0.01268330030143260955810546875));
                    _455 = powr(fast::clamp(_433 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _433)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _455 = (_237 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _455 = _99;
                    break;
                }
            }
            _504 = ((0.2626999914646148681640625 * _455.x) + (0.677999973297119140625 * _455.y)) + (0.0593000017106533050537109375 * _455.z);
            break;
        }
        case 2u:
        {
            float3 _502;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _470 = fast::clamp((_237 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _474 = powr((_237 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _502 = (_470 * (_237 * float3(0.077399380505084991455078125))) + (((-_470) * _474) + _474);
                    break;
                }
                case 1u:
                {
                    float3 _480 = powr(_237, float3(0.01268330030143260955810546875));
                    _502 = powr(fast::clamp(_480 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _480)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _502 = (_237 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _502 = _99;
                    break;
                }
            }
            _504 = dot(_502, float3(0.2125999927520751953125, 0.715200006961822509765625, 0.072200000286102294921875));
            break;
        }
        default:
        {
            _504 = 0.0;
            break;
        }
    }
    float _505 = 0.001000000047497451305389404296875 + _504;
    float2 _508 = float2(cbFI.interpolationRectSize);
    float _510 = length(_210 * _508);
    uint _519 = uint(_510 > 1.0) * uint(fast::clamp(_510 / length(_508 * 0.0500000007450580596923828125), 0.0, 1.0) * 1023.0);
    if (_519 > 0u)
    {
        float _523 = precise::max(_372, _505);
        float _530;
        if (_523 != 0.0)
        {
            _530 = precise::min(_372, _505) / _523;
        }
        else
        {
            _530 = 0.0;
        }
        float _535 = _227.x;
        bool _540;
        if (_535 > 0.0)
        {
            _540 = _535 < 1.0;
        }
        else
        {
            _540 = false;
        }
        bool _549;
        if (_540)
        {
            float _543 = _227.y;
            bool _548;
            if (_543 > 0.0)
            {
                _548 = _543 < 1.0;
            }
            else
            {
                _548 = false;
            }
            _549 = _548;
        }
        else
        {
            _549 = false;
        }
        uint _557 = (2147483648u | ((_519 & 1023u) << 21u)) | (((uint(rint(powr(_530, 1.0) * 31.0)) * uint(_549)) & 31u) << 16u);
        uint _561 = _557 | as_type<uint>(half2(float2(_226.x, 0.0)));
        uint _565 = _557 | as_type<uint>(half2(float2(_226.y, 0.0)));
        int2 _570 = int2(floor(((_225 + _226) * _224) - float2(0.5)));
        for (int _572 = 0; _572 < 4; _572++)
        {
            uint2 _581 = uint2(_570 + _111[_572]);
            if (all(_581 < uint2(_223)))
            {
                uint _588 = rw_optical_flow_motion_vector_field_x.atomic_fetch_max(_581, _561).x;
                uint _590 = rw_optical_flow_motion_vector_field_y.atomic_fetch_max(_581, _565).x;
            }
        }
    }
}

