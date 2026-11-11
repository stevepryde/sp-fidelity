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


struct type_cbFSR3Upscaler
{
    int2 iRenderSize;
    int2 iPreviousFrameRenderSize;
    int2 iUpscaleSize;
    int2 iPreviousFrameUpscaleSize;
    int2 iMaxRenderSize;
    int2 iMaxUpscaleSize;
    float4 fDeviceToViewDepth;
    float2 fJitter;
    float2 fPreviousFrameJitter;
    float2 fMotionVectorScale;
    float2 fDownscaleFactor;
    float2 fMotionVectorJitterCancellation;
    float fTanHalfFOV;
    float fJitterSequenceLength;
    float fDeltaTime;
    float fDeltaPreExposure;
    float fViewSpaceToMetersFactor;
    float fFrameIndex;
    float fVelocityFactor;
    float fReactivenessScale;
    float fShadingChangeScale;
    float fAccumulationAddedPerFrame;
    float fMinDisocclusionAccumulation;
};

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float, access::write> rw_luma_history [[texture(0)]], texture2d<float> r_luma_history [[texture(1)]], texture2d<float> r_current_luma [[texture(2)]], texture2d<float, access::write> rw_luma_instability [[texture(3)]], texture2d<float> r_dilated_motion_vectors [[texture(4)]], texture2d<float> r_input_exposure [[texture(5)]], texture2d<float> r_dilated_reactive_masks [[texture(6)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    uint2 _68 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _71 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_68), 0u).xy;
    float2 _76 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _77 = (float2(int3(gl_GlobalInvocationID).xy) + float2(0.5)) / _76;
    float2 _86 = float2(cbFSR3Upscaler.iPreviousFrameRenderSize);
    float2 _89 = (_77 + (cbFSR3Upscaler.fPreviousFrameJitter / _86)) + _71;
    float _90 = _89.x;
    bool _95;
    if (_90 >= 0.0)
    {
        _95 = _90 <= 1.0;
    }
    else
    {
        _95 = false;
    }
    bool _104;
    if (_95)
    {
        float _98 = _89.y;
        bool _103;
        if (_98 >= 0.0)
        {
            _103 = _98 <= 1.0;
        }
        else
        {
            _103 = false;
        }
        _104 = _103;
    }
    else
    {
        _104 = false;
    }
    float _239;
    float4 _240;
    if (_104)
    {
        float2 _113 = float2(cbFSR3Upscaler.iMaxRenderSize);
        float2 _114 = precise::max(float2(0.5), precise::min((_77 + (cbFSR3Upscaler.fJitter / _76)) * _76, _76 - float2(0.5))) / _113;
        float4 _118 = r_dilated_reactive_masks.sample(s_LinearClamp, _114, level(0.0));
        float _237;
        float4 _238;
        if (fast::clamp(_118.w, 0.0, 1.0) > 0.89999997615814208984375)
        {
            float4 _136 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
            float _137 = _136.x;
            float _140 = r_current_luma.sample(s_LinearClamp, _114, level(0.0)).x * ((_137 == 0.0) ? 1.0 : _137);
            float4 _154 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
            float _155 = _154.x;
            float4 _65 = (r_luma_history.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_89 * _86, _86 - float2(0.5))) / _113), level(0.0)) * cbFSR3Upscaler.fDeltaPreExposure) * ((_155 == 0.0) ? 1.0 : _155);
            float _161 = _140 - _65.x;
            float _163 = precise::max(_140, _65.x);
            float _170;
            if (_163 != 0.0)
            {
                _170 = precise::min(_140, _65.x) / _163;
            }
            else
            {
                _170 = 1.0;
            }
            float _206;
            if (_170 < 1.0)
            {
                float _175;
                _175 = _170;
                float _176;
                for (int _178 = 1; _178 <= 3; _175 = _176, _178++)
                {
                    uint _183 = uint(_178);
                    float _188 = precise::max(_140, _65[_183]);
                    float _195;
                    if (_188 != 0.0)
                    {
                        _195 = precise::min(_140, _65[_183]) / _188;
                    }
                    else
                    {
                        _195 = 0.0;
                    }
                    if (int(sign(_161)) == int(sign(_140 - _65[_183])))
                    {
                        _176 = precise::max(_175, _195);
                    }
                    else
                    {
                        _176 = _175;
                    }
                }
                _206 = float(_175 > _170);
            }
            else
            {
                _206 = 0.0;
            }
            _65.w = _65.z;
            _65.z = _65.y;
            _65.y = _65.x;
            _65.x = _140;
            float4 _214 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
            float _215 = _214.x;
            float4 _219 = _65;
            float4 _220 = _219 / float4((_215 == 0.0) ? 1.0 : _215);
            _65 = _220;
            _237 = (_206 * float(_65.w != 0.0)) * ((((1.0 - fast::clamp(length(_71 * float2(3840.0, 2160.0)) * 0.0500000007450580596923828125, 0.0, 1.0)) * (1.0 - fast::clamp(_118.y, 0.0, 1.0))) * (1.0 - fast::clamp(_118.x, 0.0, 1.0))) * (1.0 - fast::clamp(_118.z, 0.0, 1.0)));
            _238 = _220;
        }
        else
        {
            _237 = 0.0;
            _238 = float4(0.0);
        }
        _239 = _237;
        _240 = _238;
    }
    else
    {
        _239 = 0.0;
        _240 = float4(0.0);
    }
    sdk_hlsl_store(rw_luma_history, _240, uint2(_68));
    sdk_hlsl_store(rw_luma_instability, float4(_239), uint2(_68));
}

