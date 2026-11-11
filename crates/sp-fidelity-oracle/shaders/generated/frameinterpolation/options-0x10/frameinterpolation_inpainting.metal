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

template <typename ImageT>
void spvImageFence(ImageT img) { img.fence(); }

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

constant float3 _93 = {};

constant spvUnsafeArray<int2, 4> _94 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], texture2d<float> r_current_interpolation_source [[texture(0)]], texture2d<uint> r_optical_flow_scd [[texture(1)]], texture2d<float> r_inpainting_pyramid [[texture(2)]], texture2d<float> r_present_backbuffer [[texture(3)]], texture2d<float, access::read_write> rw_output [[texture(4)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _113 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_output);
    float4 _115 = sdk_hlsl_load(rw_output, uint2(_113));
    float _116 = _115.w;
    bool _117 = _116 > 0.001000000047497451305389404296875;
    float4 _216;
    if (_117)
    {
        float2 _126 = (float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / float2(cbFI.displaySize);
        int2 _128;
        float4 _131;
        _128 = cbFI.displaySize;
        _131 = float4(0.0);
        int2 _129;
        float4 _132;
        for (int _133 = 0; _133 < 10; _128 = _129, _131 = _132, _133++)
        {
            _129 = _128 / int2(2);
            float2 _140 = (_126 * float2(_129)) - float2(0.5);
            float2 _141 = floor(_140);
            int2 _142 = int2(_141);
            float2 _143 = _140 - _141;
            float _144 = _143.x;
            float _145 = 1.0 - _144;
            float _146 = _143.y;
            float _147 = 1.0 - _146;
            spvUnsafeArray<float, 4> _152 = spvUnsafeArray<float, 4>({ _145 * _147, _144 * _147, _145 * _146, _144 * _146 });
            spvUnsafeArray<float, 4> _109 = _152;
            float4 _154;
            _154 = float4(0.0);
            float4 _155;
            for (int _157 = 0; _157 < 4; _154 = _155, _157++)
            {
                uint2 _165 = uint2(_142 + _94[_157]);
                if (all(_165 < uint2(_129)))
                {
                    float4 _173 = sdk_hlsl_load(r_inpainting_pyramid, uint2(_165), uint(_133));
                    float _179 = _109[_157] * float(_173.w > 0.0);
                    _155 = _154 + float4(_173.xyz * _179, _179);
                }
                else
                {
                    _155 = _154;
                }
            }
            if (_154.w > 0.0)
            {
                _132 = _131 + (float4(_154.xyz / float3(_154.w), 1.0) * (powr(1.0 - (float(_133) * 0.100000001490116119384765625), 3.0) * _154.w));
            }
            else
            {
                _132 = _131;
            }
        }
        float3 _214 = mix(_115.xyz, (_131.xyz / float3(_131.w)) * float(cbFI.displaySize.x > 0), float3(_116));
        _216 = float4(_214.x, _214.y, _214.z, _115.w);
    }
    else
    {
        _216 = _115;
    }
    bool _371;
    float4 _372;
    if (cbFI.HUDLessAttachedFactor == 1)
    {
        float3 _224 = sdk_hlsl_load(r_current_interpolation_source, uint2(_113), 0u).xyz;
        float3 _227 = sdk_hlsl_load(r_present_backbuffer, uint2(_113), 0u).xyz;
        bool _369;
        float4 _370;
        if (any(abs(_224 - _227) > float3(0.0)))
        {
            float3 _274;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _242 = fast::clamp((_224 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _246 = powr((_224 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _274 = (_242 * (_224 * float3(0.077399380505084991455078125))) + (((-_242) * _246) + _246);
                    break;
                }
                case 1u:
                {
                    float3 _252 = powr(_224, float3(0.01268330030143260955810546875));
                    _274 = powr(fast::clamp(_252 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _252)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _274 = (_224 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _274 = _93;
                    break;
                }
            }
            float3 _313;
            switch (cbFI.backBufferTransferFunction)
            {
                case 0u:
                {
                    float3 _281 = fast::clamp((_227 - float3(0.040449999272823333740234375)) * float3(as_type<float>(0xff800000u /* -inf */)), float3(0.0), float3(1.0));
                    float3 _285 = powr((_227 * float3(0.94786727428436279296875)) + float3(0.0521326996386051177978515625), float3(2.400000095367431640625));
                    _313 = (_281 * (_227 * float3(0.077399380505084991455078125))) + (((-_281) * _285) + _285);
                    break;
                }
                case 1u:
                {
                    float3 _291 = powr(_227, float3(0.01268330030143260955810546875));
                    _313 = powr(fast::clamp(_291 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _291)), float3(6.277390003204345703125)) * (10000.0 / cbFI.minMaxLuminance.y);
                    break;
                }
                case 2u:
                {
                    _313 = (_227 - float3(cbFI.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbFI.minMaxLuminance.y - cbFI.minMaxLuminance.x) * 0.012500000186264514923095703125);
                    break;
                }
                default:
                {
                    _313 = _93;
                    break;
                }
            }
            float _316 = precise::max(_274.x, _313.x);
            float _323;
            if (_316 != 0.0)
            {
                _323 = precise::min(_274.x, _313.x) / _316;
            }
            else
            {
                _323 = 0.0;
            }
            float _329 = precise::max(_274.y, _313.y);
            float _336;
            if (_329 != 0.0)
            {
                _336 = precise::min(_274.y, _313.y) / _329;
            }
            else
            {
                _336 = 0.0;
            }
            float _342 = precise::max(_274.z, _313.z);
            float _349;
            if (_342 != 0.0)
            {
                _349 = precise::min(_274.z, _313.z) / _342;
            }
            else
            {
                _349 = 0.0;
            }
            float3 _354 = fast::clamp(float3(fast::clamp((1.0 - _323) * 10.0, 0.0, 1.0), fast::clamp((1.0 - _336) * 10.0, 0.0, 1.0), fast::clamp((1.0 - _349) * 10.0, 0.0, 1.0)), float3(0.0), float3(1.0));
            float _359 = precise::max(_354.x, precise::max(_354.y, _354.z));
            bool _360 = _359 > 0.001000000047497451305389404296875;
            float4 _367;
            if (_360)
            {
                float3 _365 = mix(_216.xyz, _227, float3(_359));
                _367 = float4(_365.x, _365.y, _365.z, _216.w);
            }
            else
            {
                _367 = _216;
            }
            _369 = _360 ? true : _117;
            _370 = _367;
        }
        else
        {
            _369 = _117;
            _370 = _216;
        }
        _371 = _369;
        _372 = _370;
    }
    else
    {
        _371 = _117;
        _372 = _216;
    }
    bool _401;
    float4 _402;
    if ((cbFI.dispatchFlags & 1u) != 0u)
    {
        float3 _379 = _372.xyz;
        bool _398;
        float3 _399;
        if (int3(gl_GlobalInvocationID).x < 16)
        {
            float3 _385 = _379;
            _385.y = 1.0;
            _398 = true;
            _399 = _385;
        }
        else
        {
            bool _390 = int3(gl_GlobalInvocationID).x > (cbFI.displaySize.x - 16);
            float3 _396;
            if (_390)
            {
                _396 = _379 + float3(cbFI.debugBarColor);
            }
            else
            {
                _396 = _379;
            }
            _398 = _390 ? true : _371;
            _399 = _396;
        }
        _401 = _398;
        _402 = float4(_399.x, _399.y, _399.z, _372.w);
    }
    else
    {
        _401 = _371;
        _402 = _372;
    }
    float4 _441;
    bool _442;
    if ((cbFI.dispatchFlags & 2u) != 0u)
    {
        float3 _407 = _402.xyz;
        bool _415;
        if (int3(gl_GlobalInvocationID).y < 32)
        {
            _415 = cbFI.reset == 1;
        }
        else
        {
            _415 = false;
        }
        bool _438;
        float3 _439;
        if (_415)
        {
            float3 _419 = _407;
            _419.x = 1.0;
            _438 = true;
            _439 = _419;
        }
        else
        {
            bool _424;
            if (int3(gl_GlobalInvocationID).y > 32)
            {
                _424 = int3(gl_GlobalInvocationID).y < 64;
            }
            else
            {
                _424 = false;
            }
            bool _432;
            if (_424)
            {
                _432 = (sdk_hlsl_load(r_optical_flow_scd, uint2(uint2(1u, 0u)), 0u).x & 15u) != 0u;
            }
            else
            {
                _432 = false;
            }
            float3 _436;
            if (_432)
            {
                float3 _435 = _407;
                _435.z = 1.0;
                _436 = _435;
            }
            else
            {
                _436 = _407;
            }
            _438 = _432 ? true : _401;
            _439 = _436;
        }
        _441 = float4(_439.x, _439.y, _439.z, _402.w);
        _442 = _438;
    }
    else
    {
        _441 = _402;
        _442 = _401;
    }
    if (_442)
    {
        sdk_hlsl_store(rw_output, float4(_441.xyz, 1.0), uint2(_113));
    }
}

