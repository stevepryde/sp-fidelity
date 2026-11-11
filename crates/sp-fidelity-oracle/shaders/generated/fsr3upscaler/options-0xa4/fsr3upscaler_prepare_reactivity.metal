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

constant float _103 = {};

constant spvUnsafeArray<int2, 4> _104 = spvUnsafeArray<int2, 4>({ int2(0), int2(1, 0), int2(0, 1), int2(1) });
constant spvUnsafeArray<uint, 4> _114 = spvUnsafeArray<uint, 4>({ 23u, 45u, 209u, 417u });

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_reactive_mask [[texture(0)]], texture2d<float> r_transparency_and_composition_mask [[texture(1)]], texture2d<float> r_accumulation [[texture(2)]], texture2d<float, access::write> rw_accumulation [[texture(3)]], texture2d<float> r_shading_change [[texture(4)]], texture2d<float> r_current_luma [[texture(5)]], texture2d<float, access::write> rw_new_locks [[texture(6)]], texture2d<uint> r_reconstructed_previous_nearest_depth [[texture(7)]], texture2d<float> r_dilated_motion_vectors [[texture(8)]], texture2d<float> r_dilated_depth [[texture(9)]], texture2d<float> r_input_exposure [[texture(10)]], texture2d<float, access::write> rw_dilated_reactive_masks [[texture(11)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _126 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _129 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _130 = _126 / _129;
    uint2 _131 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _134 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(_131), 0u).xy;
    float _143 = cbFSR3Upscaler.fDeviceToViewDepth.y / (sdk_hlsl_load(r_dilated_depth, uint2(_131), 0u).x - cbFSR3Upscaler.fDeviceToViewDepth.x);
    float _146 = _143 * cbFSR3Upscaler.fViewSpaceToMetersFactor;
    float _152 = length(_134 * float2(3840.0, 2160.0));
    float2 _158 = ((_130 + (_134 * float(_152 > mix(0.25, 0.75, fast::clamp(precise::min(_146, 65504.0) * 0.00999999977648258209228515625, 0.0, 1.0))))) * _129) - float2(0.5);
    float2 _159 = floor(_158);
    int2 _160 = int2(_159);
    float2 _161 = _158 - _159;
    float _162 = _161.x;
    float _163 = 1.0 - _162;
    float _164 = _161.y;
    float _165 = 1.0 - _164;
    spvUnsafeArray<float, 4> _170 = spvUnsafeArray<float, 4>({ _163 * _165, _162 * _165, _163 * _164, _162 * _164 });
    spvUnsafeArray<float, 4> _120 = _170;
    float _172;
    float _175;
    bool _177;
    _172 = 0.0;
    _175 = 0.0;
    _177 = true;
    float _173;
    float _176;
    bool _178;
    for (int _179 = 0; (_179 < 4) ? _177 : false; _172 = _173, _175 = _176, _177 = _178, _179++)
    {
        int2 _187 = _160 + _104[_179];
        uint2 _199 = uint2(int2(max(0, min(_187.x, (cbFSR3Upscaler.iRenderSize.x - 1))), max(0, min(_187.y, (cbFSR3Upscaler.iRenderSize.y - 1)))));
        if (all(_199 < uint2(cbFSR3Upscaler.iRenderSize)))
        {
            float _235;
            float _236;
            bool _237;
            if (_120[_179] > 0.0006099999882280826568603515625)
            {
                float _215 = cbFSR3Upscaler.fDeviceToViewDepth.y / (as_type<float>(sdk_hlsl_load(r_reconstructed_previous_nearest_depth, uint2(_199), 0u).x) - cbFSR3Upscaler.fDeviceToViewDepth.x);
                float _216 = _143 - _215;
                bool _220;
                if (_177)
                {
                    _220 = _216 > 1.1754943508222875079687365372222e-38;
                }
                else
                {
                    _220 = false;
                }
                float _233;
                float _234;
                if (_220)
                {
                    _233 = _172 + (fast::clamp(((1.3699999726668465882539749145508e-05 * length(_129 * 0.5)) * precise::max(_143, _215)) / _216, 0.0, 1.0) * _120[_179]);
                    _234 = _175 + _120[_179];
                }
                else
                {
                    _233 = _172;
                    _234 = _175;
                }
                _235 = _233;
                _236 = _234;
                _237 = _220;
            }
            else
            {
                _235 = _172;
                _236 = _175;
                _237 = _177;
            }
            _173 = _235;
            _176 = _236;
            _178 = _237;
        }
        else
        {
            _173 = _172;
            _176 = _175;
            _178 = _177;
        }
    }
    bool _241;
    if (_177)
    {
        _241 = _175 > 0.0;
    }
    else
    {
        _241 = false;
    }
    float _248;
    if (_241)
    {
        _248 = fast::clamp(1.0 - (_172 / _175), 0.0, 1.0);
    }
    else
    {
        _248 = 0.0;
    }
    int2 _249 = int3(gl_GlobalInvocationID).xy + int2(-1);
    int _252 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _257 = cbFSR3Upscaler.iRenderSize.y - 1;
    uint2 _261 = uint2(int2(max(0, min(_249.x, _252)), max(0, min(_249.y, _257))));
    int2 _269 = int3(gl_GlobalInvocationID).xy + int2(0, -1);
    uint2 _277 = uint2(int2(max(0, min(_269.x, _252)), max(0, min(_269.y, _257))));
    int2 _283 = int3(gl_GlobalInvocationID).xy + int2(1, -1);
    uint2 _291 = uint2(int2(max(0, min(_283.x, _252)), max(0, min(_283.y, _257))));
    int2 _297 = int3(gl_GlobalInvocationID).xy + int2(-1, 0);
    uint2 _305 = uint2(int2(max(0, min(_297.x, _252)), max(0, min(_297.y, _257))));
    uint2 _318 = uint2(int2(max(0, min(int3(gl_GlobalInvocationID).x, _252)), max(0, min(int3(gl_GlobalInvocationID).y, _257))));
    int2 _324 = int3(gl_GlobalInvocationID).xy + int2(1, 0);
    uint2 _332 = uint2(int2(max(0, min(_324.x, _252)), max(0, min(_324.y, _257))));
    int2 _338 = int3(gl_GlobalInvocationID).xy + int2(-1, 1);
    uint2 _346 = uint2(int2(max(0, min(_338.x, _252)), max(0, min(_338.y, _257))));
    int2 _352 = int3(gl_GlobalInvocationID).xy + int2(0, 1);
    uint2 _360 = uint2(int2(max(0, min(_352.x, _252)), max(0, min(_352.y, _257))));
    int2 _366 = int3(gl_GlobalInvocationID).xy + int2(1);
    uint2 _374 = uint2(int2(max(0, min(_366.x, _252)), max(0, min(_366.y, _257))));
    float2 _388 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _391 = float2(int2(_129 * 0.5));
    float _407 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(0.0, sdk_hlsl_load(r_reactive_mask, uint2(_261), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_277), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_291), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_305), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_318), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_332), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_346), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_360), 0u).x * cbFSR3Upscaler.fReactivenessScale), sdk_hlsl_load(r_reactive_mask, uint2(_374), 0u).x * cbFSR3Upscaler.fReactivenessScale), fast::clamp(r_shading_change.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min((_130 - (cbFSR3Upscaler.fJitter / _129)) * _391, _391 - float2(0.5))) / float2(int2(_388 * 0.5))), level(0.0)).x * cbFSR3Upscaler.fShadingChangeScale, 0.0, 1.0));
    float2 _408 = _130 + _134;
    uint2 _411 = uint2(int2(_408 * _129));
    float _422 = (cbFSR3Upscaler.fDeviceToViewDepth.y / (sdk_hlsl_load(r_dilated_depth, uint2(_411), 0u).x - cbFSR3Upscaler.fDeviceToViewDepth.x)) * cbFSR3Upscaler.fViewSpaceToMetersFactor;
    float _423 = precise::max(_422, _146);
    float _430;
    if (_423 != 0.0)
    {
        _430 = precise::min(_422, _146) / _423;
    }
    else
    {
        _430 = 0.0;
    }
    uint2 _439 = uint2(r_transparency_and_composition_mask.get_width(), r_transparency_and_composition_mask.get_height());
    float _456 = _408.x;
    bool _461;
    if (_456 >= 0.0)
    {
        _461 = _456 <= 1.0;
    }
    else
    {
        _461 = false;
    }
    bool _470;
    if (_461)
    {
        float _464 = _408.y;
        bool _469;
        if (_464 >= 0.0)
        {
            _469 = _464 <= 1.0;
        }
        else
        {
            _469 = false;
        }
        _470 = _469;
    }
    else
    {
        _470 = false;
    }
    float _487;
    if (_470)
    {
        float2 _475 = float2(cbFSR3Upscaler.iPreviousFrameRenderSize);
        _487 = fast::clamp(r_accumulation.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_408 * _475, _475 - float2(0.5))) / _388), level(0.0)).x, 0.0, 1.0);
    }
    else
    {
        _487 = 0.0;
    }
    float _490 = mix(_487, 0.0, _407);
    float _494 = mix(_490, precise::min(cbFSR3Upscaler.fMinDisocclusionAccumulation, _490), _248);
    float _499 = _494 * float(rint(_494 * 100.0) > 1.0);
    sdk_hlsl_store(rw_accumulation, float4(fast::clamp(_499 + cbFSR3Upscaler.fAccumulationAddedPerFrame, 0.0, 1.0)), uint2(_131));
    sdk_hlsl_store(rw_dilated_reactive_masks, float4(precise::max(((1.0 - fast::clamp(length(sdk_hlsl_load(r_dilated_motion_vectors, uint2(_411), 0u).xy * float2(3840.0, 2160.0)) / _152, 0.0, 1.0)) * _430) * fast::clamp(_152 * 0.100000001490116119384765625, 0.0, 1.0), r_transparency_and_composition_mask.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_126, _129 - float2(0.5))) / float2(int2(int(_439.x), int(_439.y)))), level(0.0)).x), _248, _407, _499), uint2(_131));
    float _740;
    do
    {
        float4 _511 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _512 = _511.x;
        float _515 = sdk_hlsl_load(r_current_luma, uint2(_318), 0u).x * ((_512 == 0.0) ? 1.0 : _512);
        float4 _522 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _523 = _522.x;
        float _526 = sdk_hlsl_load(r_current_luma, uint2(_261), 0u).x * ((_523 == 0.0) ? 1.0 : _523);
        float4 _533 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _534 = _533.x;
        float _537 = sdk_hlsl_load(r_current_luma, uint2(_277), 0u).x * ((_534 == 0.0) ? 1.0 : _534);
        float4 _544 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _545 = _544.x;
        float _548 = sdk_hlsl_load(r_current_luma, uint2(_291), 0u).x * ((_545 == 0.0) ? 1.0 : _545);
        float4 _555 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _556 = _555.x;
        float _559 = sdk_hlsl_load(r_current_luma, uint2(_305), 0u).x * ((_556 == 0.0) ? 1.0 : _556);
        float4 _566 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _567 = _566.x;
        float _570 = sdk_hlsl_load(r_current_luma, uint2(_332), 0u).x * ((_567 == 0.0) ? 1.0 : _567);
        float4 _577 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _578 = _577.x;
        float _581 = sdk_hlsl_load(r_current_luma, uint2(_346), 0u).x * ((_578 == 0.0) ? 1.0 : _578);
        float4 _588 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _589 = _588.x;
        float _592 = sdk_hlsl_load(r_current_luma, uint2(_360), 0u).x * ((_589 == 0.0) ? 1.0 : _589);
        float4 _599 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _600 = _599.x;
        float _603 = sdk_hlsl_load(r_current_luma, uint2(_374), 0u).x * ((_600 == 0.0) ? 1.0 : _600);
        float _604 = precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(3.4028234663852885981170418348452e+38, _515), _526), _537), _548), _559), _570), _581), _592), _603);
        float _605 = precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(1.1754943508222875079687365372222e-38, _515), _526), _537), _548), _559), _570), _581), _592), _603);
        float _608 = _605 - _604;
        bool _610 = (abs(_526 - _515) / _608) < 0.89999997615814208984375;
        float _616;
        float _617;
        if (_610)
        {
            _616 = 3.4028234663852885981170418348452e+38;
            _617 = 0.0;
        }
        else
        {
            _616 = precise::min(3.4028234663852885981170418348452e+38, _526);
            _617 = precise::max(0.0, _526);
        }
        uint _631;
        float _632;
        float _633;
        if ((abs(_537 - _515) / _608) < 0.89999997615814208984375)
        {
            uint _628 = 7u;
            uint _629 = 5u;
            _631 = _610 ? 7u : 5u;
            _632 = _616;
            _633 = _617;
        }
        else
        {
            _631 = _610 ? 3u : 1u;
            _632 = precise::min(_616, _537);
            _633 = precise::max(_617, _537);
        }
        uint _644;
        float _645;
        float _646;
        if ((abs(_548 - _515) / _608) < 0.89999997615814208984375)
        {
            _644 = _631 | 8u;
            _645 = _632;
            _646 = _633;
        }
        else
        {
            _644 = _631;
            _645 = precise::min(_632, _548);
            _646 = precise::max(_633, _548);
        }
        uint _657;
        float _658;
        float _659;
        if ((abs(_559 - _515) / _608) < 0.89999997615814208984375)
        {
            _657 = _644 | 16u;
            _658 = _645;
            _659 = _646;
        }
        else
        {
            _657 = _644;
            _658 = precise::min(_645, _559);
            _659 = precise::max(_646, _559);
        }
        uint _670;
        float _671;
        float _672;
        if ((abs(_570 - _515) / _608) < 0.89999997615814208984375)
        {
            _670 = _657 | 32u;
            _671 = _658;
            _672 = _659;
        }
        else
        {
            _670 = _657;
            _671 = precise::min(_658, _570);
            _672 = precise::max(_659, _570);
        }
        uint _683;
        float _684;
        float _685;
        if ((abs(_581 - _515) / _608) < 0.89999997615814208984375)
        {
            _683 = _670 | 64u;
            _684 = _671;
            _685 = _672;
        }
        else
        {
            _683 = _670;
            _684 = precise::min(_671, _581);
            _685 = precise::max(_672, _581);
        }
        uint _696;
        float _697;
        float _698;
        if ((abs(_592 - _515) / _608) < 0.89999997615814208984375)
        {
            _696 = _683 | 128u;
            _697 = _684;
            _698 = _685;
        }
        else
        {
            _696 = _683;
            _697 = precise::min(_684, _592);
            _698 = precise::max(_685, _592);
        }
        uint _709;
        float _710;
        float _711;
        if ((abs(_603 - _515) / _608) < 0.89999997615814208984375)
        {
            _709 = _696 | 256u;
            _710 = _697;
            _711 = _698;
        }
        else
        {
            _709 = _696;
            _710 = precise::min(_697, _603);
            _711 = precise::max(_698, _603);
        }
        bool _716;
        if ((isunordered(_515, _711) || _515 <= _711))
        {
            _716 = _515 < _710;
        }
        else
        {
            _716 = true;
        }
        if (!_716)
        {
            _740 = 0.0;
            break;
        }
        float _735;
        bool _736;
        int _721 = 0;
        for (;;)
        {
            if (uint(_721) < 4u)
            {
                if ((_709 & _114[_721]) == _114[_721])
                {
                    _735 = 0.0;
                    _736 = true;
                    break;
                }
                _721++;
                continue;
            }
            else
            {
                _735 = _103;
                _736 = false;
                break;
            }
        }
        if (_736)
        {
            _740 = _735;
            break;
        }
        _740 = 1.0 - (_604 / _605);
        break;
    } while(false);
    if (_740 > 0.00999999977648258209228515625)
    {
        sdk_hlsl_store(rw_new_locks, float4(_740), uint2(uint2(int2(floor(((_126 - cbFSR3Upscaler.fJitter) / _129) * float2(cbFSR3Upscaler.iUpscaleSize))))));
    }
}

