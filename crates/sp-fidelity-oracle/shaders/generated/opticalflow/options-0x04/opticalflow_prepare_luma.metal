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


struct type_cbOF
{
    int2 iInputLumaResolution;
    uint uOpticalFlowPyramidLevel;
    uint uOpticalFlowPyramidLevelCount;
    uint iFrameIndex;
    uint backbufferTransferFunction;
    float2 minMaxLuminance;
};

kernel void main0(constant type_cbOF& cbOF [[buffer(0)]], texture2d<float> r_input_color [[texture(0)]], texture2d<uint, access::write> rw_optical_flow_input [[texture(1)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    for (int _70 = 0; _70 < 2; _70++)
    {
        for (int _77 = 0; _77 < 2; _77++)
        {
            uint2 _86 = uint2((int3(gl_GlobalInvocationID).xy * int2(2)) + int2(_77, _70));
            float4 _88 = sdk_hlsl_load(r_input_color, uint2(_86), 0u);
            float3 _89 = _88.xyz;
            float _172;
            if (cbOF.backbufferTransferFunction == 0u)
            {
                _172 = ((0.2125999927520751953125 * _88.x) + (0.715200006961822509765625 * _88.y)) + (0.072200000286102294921875 * _88.z);
            }
            else
            {
                float _171;
                if (cbOF.backbufferTransferFunction == 1u)
                {
                    float3 _111 = powr(_89, float3(0.01268330030143260955810546875));
                    float3 _119 = powr(fast::clamp(_111 - float3(0.835937976837158203125), float3(0.0), float3(1.0)) / (float3(18.85160064697265625) - (float3(18.6875) * _111)), float3(6.277390003204345703125)) * (10000.0 / cbOF.minMaxLuminance.y);
                    float _127 = ((0.2626999914646148681640625 * _119.x) + (0.677999973297119140625 * _119.y)) + (0.0593000017106533050537109375 * _119.z);
                    float _136;
                    if (_127 <= 0.008856452070176601409912109375)
                    {
                        _136 = _127 * 903.29632568359375;
                    }
                    else
                    {
                        _136 = (powr(_127, 0.3333333432674407958984375) * 116.0) - 16.0;
                    }
                    _171 = _136 * 0.00999999977648258209228515625;
                }
                else
                {
                    float _170;
                    if (cbOF.backbufferTransferFunction == 2u)
                    {
                        float3 _151 = (_89 - float3(cbOF.minMaxLuminance.x * 0.012500000186264514923095703125)) / float3((cbOF.minMaxLuminance.y - cbOF.minMaxLuminance.x) * 0.012500000186264514923095703125);
                        float _159 = ((0.2125999927520751953125 * _151.x) + (0.715200006961822509765625 * _151.y)) + (0.072200000286102294921875 * _151.z);
                        float _168;
                        if (_159 <= 0.008856452070176601409912109375)
                        {
                            _168 = _159 * 903.29632568359375;
                        }
                        else
                        {
                            _168 = (powr(_159, 0.3333333432674407958984375) * 116.0) - 16.0;
                        }
                        _170 = _168 * 0.00999999977648258209228515625;
                    }
                    else
                    {
                        _170 = 0.0;
                    }
                    _171 = _170;
                }
                _172 = _171;
            }
            sdk_hlsl_store(rw_optical_flow_input, uint4(uint(_172 * 255.0)), uint2(_86));
        }
    }
}

