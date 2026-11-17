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

template<typename T>
inline T spvQuadSwap(T value, uint dir)
{
    return quad_shuffle_xor(value, dir + 1);
}

template<>
inline bool spvQuadSwap(bool value, uint dir)
{
    return !!quad_shuffle_xor((ushort)value, dir + 1);
}

template<uint N>
inline vec<bool, N> spvQuadSwap(vec<bool, N> value, uint dir)
{
    return (vec<bool, N>)quad_shuffle_xor((vec<ushort, N>)value, dir + 1);
}

template <typename ImageT>
void spvImageFence(ImageT img) { img.fence(); }

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

struct type_cbSPD
{
    uint mips;
    uint numWorkGroups;
    uint2 workGroupOffset;
    uint2 renderSize;
};

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], constant type_cbSPD& cbSPD [[buffer(1)]], texture2d<float> r_farthest_depth [[texture(0)]], texture2d<float, access::write> rw_farthest_depth_mip1 [[texture(1)]], texture2d<float> r_current_luma [[texture(2)]], texture2d<float, access::read_write> rw_frame_info [[texture(3)]], texture2d<float, access::read_write> rw_spd_mip5 [[texture(4)]], texture2d<uint, access::read_write> rw_spd_global_atomic [[texture(5)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup uint spdCounter;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateR;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateG;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateB;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateA;
    uint2 _108 = gl_WorkGroupID.xy + cbSPD.workGroupOffset;
    do
    {
        uint _132;
        int _133;
        uint _134;
        int _135;
        int2 _136;
        int2 _142;
        uint _248;
        uint _111 = gl_LocalInvocationIndex % 64u;
        uint _124 = ((_111 & 1u) | ((_111 >> 2u) & 6u)) + (8u * ((gl_LocalInvocationIndex >> 6u) % 2u));
        uint _127 = (((_111 >> 1u) & 3u) | ((_111 >> 3u) & 4u)) + (8u * (gl_LocalInvocationIndex >> 7u));
        do
        {
            int2 _131 = int2(_108 * uint2(64u));
            _132 = _124 * 2u;
            _133 = int(_132);
            _134 = _127 * 2u;
            _135 = int(_134);
            _136 = int2(_133, _135);
            int2 _137 = _131 + _136;
            int2 _139 = int2(_108 * uint2(32u));
            int _140 = int(_124);
            int _141 = int(_127);
            _142 = int2(_140, _141);
            int2 _143 = _139 + _142;
            uint2 _144 = uint2(_137);
            int2 _149 = int2(float2(_137));
            int _154 = cbFSR3Upscaler.iRenderSize.x - 1;
            int _159 = cbFSR3Upscaler.iRenderSize.y - 1;
            uint2 _163 = uint2(int2(max(0, min(_149.x, _154)), max(0, min(_149.y, _159))));
            float4 _165 = sdk_hlsl_load(r_current_luma, uint2(_163), 0u);
            float _166 = _165.x;
            float4 _172 = float4(0.0);
            _172.x = precise::max(6.099999882280826568603515625e-05, log(_166));
            _172.y = _166;
            _172.z = sdk_hlsl_load(r_farthest_depth, uint2(_163), 0u).x;
            int2 _177 = int2(float2(int2(_144 + uint2(0u, 1u))));
            uint2 _185 = uint2(int2(max(0, min(_177.x, _154)), max(0, min(_177.y, _159))));
            float4 _187 = sdk_hlsl_load(r_current_luma, uint2(_185), 0u);
            float _188 = _187.x;
            float4 _194 = float4(0.0);
            _194.x = precise::max(6.099999882280826568603515625e-05, log(_188));
            _194.y = _188;
            _194.z = sdk_hlsl_load(r_farthest_depth, uint2(_185), 0u).x;
            int2 _199 = int2(float2(int2(_144 + uint2(1u, 0u))));
            uint2 _207 = uint2(int2(max(0, min(_199.x, _154)), max(0, min(_199.y, _159))));
            float4 _209 = sdk_hlsl_load(r_current_luma, uint2(_207), 0u);
            float _210 = _209.x;
            float4 _216 = float4(0.0);
            _216.x = precise::max(6.099999882280826568603515625e-05, log(_210));
            _216.y = _210;
            _216.z = sdk_hlsl_load(r_farthest_depth, uint2(_207), 0u).x;
            int2 _221 = int2(float2(int2(_144 + uint2(1u))));
            uint2 _229 = uint2(int2(max(0, min(_221.x, _154)), max(0, min(_221.y, _159))));
            float4 _231 = sdk_hlsl_load(r_current_luma, uint2(_229), 0u);
            float _232 = _231.x;
            float4 _238 = float4(0.0);
            _238.x = precise::max(6.099999882280826568603515625e-05, log(_232));
            _238.y = _232;
            _238.z = sdk_hlsl_load(r_farthest_depth, uint2(_229), 0u).x;
            float4 _244 = (((_172 + _194) + _216) + _238) * 0.25;
            sdk_hlsl_store(rw_farthest_depth_mip1, float4(_244.z), uint2(uint2(_143)));
            _248 = cbSPD.mips - 1u;
            bool _249 = 0u == _248;
            if (_249)
            {
                if (all(_143 == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _257 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _259 = _257.y;
                    float _260 = _244.x;
                    float _273;
                    if (_259 < 10000.0)
                    {
                        _273 = precise::max(0.0, _259 + ((_260 - _259) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _273 = _260;
                    }
                    _257.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_273) * 8.0));
                    _257.y = _273;
                    _257.z = _244.y;
                    sdk_hlsl_store(rw_frame_info, _257, uint2(uint2(0u)));
                }
            }
            int _284 = int(_132 + 32u);
            int2 _286 = _131 + int2(_284, _135);
            int _288 = int(_124 + 16u);
            int2 _290 = _139 + int2(_288, _141);
            uint2 _291 = uint2(_286);
            int2 _296 = int2(float2(_286));
            uint2 _304 = uint2(int2(max(0, min(_296.x, _154)), max(0, min(_296.y, _159))));
            float4 _306 = sdk_hlsl_load(r_current_luma, uint2(_304), 0u);
            float _307 = _306.x;
            float4 _313 = float4(0.0);
            _313.x = precise::max(6.099999882280826568603515625e-05, log(_307));
            _313.y = _307;
            _313.z = sdk_hlsl_load(r_farthest_depth, uint2(_304), 0u).x;
            int2 _318 = int2(float2(int2(_291 + uint2(0u, 1u))));
            uint2 _326 = uint2(int2(max(0, min(_318.x, _154)), max(0, min(_318.y, _159))));
            float4 _328 = sdk_hlsl_load(r_current_luma, uint2(_326), 0u);
            float _329 = _328.x;
            float4 _335 = float4(0.0);
            _335.x = precise::max(6.099999882280826568603515625e-05, log(_329));
            _335.y = _329;
            _335.z = sdk_hlsl_load(r_farthest_depth, uint2(_326), 0u).x;
            int2 _340 = int2(float2(int2(_291 + uint2(1u, 0u))));
            uint2 _348 = uint2(int2(max(0, min(_340.x, _154)), max(0, min(_340.y, _159))));
            float4 _350 = sdk_hlsl_load(r_current_luma, uint2(_348), 0u);
            float _351 = _350.x;
            float4 _357 = float4(0.0);
            _357.x = precise::max(6.099999882280826568603515625e-05, log(_351));
            _357.y = _351;
            _357.z = sdk_hlsl_load(r_farthest_depth, uint2(_348), 0u).x;
            int2 _362 = int2(float2(int2(_291 + uint2(1u))));
            uint2 _370 = uint2(int2(max(0, min(_362.x, _154)), max(0, min(_362.y, _159))));
            float4 _372 = sdk_hlsl_load(r_current_luma, uint2(_370), 0u);
            float _373 = _372.x;
            float4 _379 = float4(0.0);
            _379.x = precise::max(6.099999882280826568603515625e-05, log(_373));
            _379.y = _373;
            _379.z = sdk_hlsl_load(r_farthest_depth, uint2(_370), 0u).x;
            float4 _385 = (((_313 + _335) + _357) + _379) * 0.25;
            sdk_hlsl_store(rw_farthest_depth_mip1, float4(_385.z), uint2(uint2(_290)));
            if (_249)
            {
                if (all(_290 == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _396 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _398 = _396.y;
                    float _399 = _385.x;
                    float _412;
                    if (_398 < 10000.0)
                    {
                        _412 = precise::max(0.0, _398 + ((_399 - _398) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _412 = _399;
                    }
                    _396.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_412) * 8.0));
                    _396.y = _412;
                    _396.z = _385.y;
                    sdk_hlsl_store(rw_frame_info, _396, uint2(uint2(0u)));
                }
            }
            int _423 = int(_134 + 32u);
            int2 _425 = _131 + int2(_133, _423);
            int _427 = int(_127 + 16u);
            int2 _429 = _139 + int2(_140, _427);
            uint2 _430 = uint2(_425);
            int2 _435 = int2(float2(_425));
            uint2 _443 = uint2(int2(max(0, min(_435.x, _154)), max(0, min(_435.y, _159))));
            float4 _445 = sdk_hlsl_load(r_current_luma, uint2(_443), 0u);
            float _446 = _445.x;
            float4 _452 = float4(0.0);
            _452.x = precise::max(6.099999882280826568603515625e-05, log(_446));
            _452.y = _446;
            _452.z = sdk_hlsl_load(r_farthest_depth, uint2(_443), 0u).x;
            int2 _457 = int2(float2(int2(_430 + uint2(0u, 1u))));
            uint2 _465 = uint2(int2(max(0, min(_457.x, _154)), max(0, min(_457.y, _159))));
            float4 _467 = sdk_hlsl_load(r_current_luma, uint2(_465), 0u);
            float _468 = _467.x;
            float4 _474 = float4(0.0);
            _474.x = precise::max(6.099999882280826568603515625e-05, log(_468));
            _474.y = _468;
            _474.z = sdk_hlsl_load(r_farthest_depth, uint2(_465), 0u).x;
            int2 _479 = int2(float2(int2(_430 + uint2(1u, 0u))));
            uint2 _487 = uint2(int2(max(0, min(_479.x, _154)), max(0, min(_479.y, _159))));
            float4 _489 = sdk_hlsl_load(r_current_luma, uint2(_487), 0u);
            float _490 = _489.x;
            float4 _496 = float4(0.0);
            _496.x = precise::max(6.099999882280826568603515625e-05, log(_490));
            _496.y = _490;
            _496.z = sdk_hlsl_load(r_farthest_depth, uint2(_487), 0u).x;
            int2 _501 = int2(float2(int2(_430 + uint2(1u))));
            uint2 _509 = uint2(int2(max(0, min(_501.x, _154)), max(0, min(_501.y, _159))));
            float4 _511 = sdk_hlsl_load(r_current_luma, uint2(_509), 0u);
            float _512 = _511.x;
            float4 _518 = float4(0.0);
            _518.x = precise::max(6.099999882280826568603515625e-05, log(_512));
            _518.y = _512;
            _518.z = sdk_hlsl_load(r_farthest_depth, uint2(_509), 0u).x;
            float4 _524 = (((_452 + _474) + _496) + _518) * 0.25;
            sdk_hlsl_store(rw_farthest_depth_mip1, float4(_524.z), uint2(uint2(_429)));
            if (_249)
            {
                if (all(_429 == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _535 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _537 = _535.y;
                    float _538 = _524.x;
                    float _551;
                    if (_537 < 10000.0)
                    {
                        _551 = precise::max(0.0, _537 + ((_538 - _537) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _551 = _538;
                    }
                    _535.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_551) * 8.0));
                    _535.y = _551;
                    _535.z = _524.y;
                    sdk_hlsl_store(rw_frame_info, _535, uint2(uint2(0u)));
                }
            }
            int2 _562 = _131 + int2(_284, _423);
            int2 _564 = _139 + int2(_288, _427);
            uint2 _565 = uint2(_562);
            int2 _570 = int2(float2(_562));
            uint2 _578 = uint2(int2(max(0, min(_570.x, _154)), max(0, min(_570.y, _159))));
            float4 _580 = sdk_hlsl_load(r_current_luma, uint2(_578), 0u);
            float _581 = _580.x;
            float4 _587 = float4(0.0);
            _587.x = precise::max(6.099999882280826568603515625e-05, log(_581));
            _587.y = _581;
            _587.z = sdk_hlsl_load(r_farthest_depth, uint2(_578), 0u).x;
            int2 _592 = int2(float2(int2(_565 + uint2(0u, 1u))));
            uint2 _600 = uint2(int2(max(0, min(_592.x, _154)), max(0, min(_592.y, _159))));
            float4 _602 = sdk_hlsl_load(r_current_luma, uint2(_600), 0u);
            float _603 = _602.x;
            float4 _609 = float4(0.0);
            _609.x = precise::max(6.099999882280826568603515625e-05, log(_603));
            _609.y = _603;
            _609.z = sdk_hlsl_load(r_farthest_depth, uint2(_600), 0u).x;
            int2 _614 = int2(float2(int2(_565 + uint2(1u, 0u))));
            uint2 _622 = uint2(int2(max(0, min(_614.x, _154)), max(0, min(_614.y, _159))));
            float4 _624 = sdk_hlsl_load(r_current_luma, uint2(_622), 0u);
            float _625 = _624.x;
            float4 _631 = float4(0.0);
            _631.x = precise::max(6.099999882280826568603515625e-05, log(_625));
            _631.y = _625;
            _631.z = sdk_hlsl_load(r_farthest_depth, uint2(_622), 0u).x;
            int2 _636 = int2(float2(int2(_565 + uint2(1u))));
            uint2 _644 = uint2(int2(max(0, min(_636.x, _154)), max(0, min(_636.y, _159))));
            float4 _646 = sdk_hlsl_load(r_current_luma, uint2(_644), 0u);
            float _647 = _646.x;
            float4 _653 = float4(0.0);
            _653.x = precise::max(6.099999882280826568603515625e-05, log(_647));
            _653.y = _647;
            _653.z = sdk_hlsl_load(r_farthest_depth, uint2(_644), 0u).x;
            float4 _659 = (((_587 + _609) + _631) + _653) * 0.25;
            sdk_hlsl_store(rw_farthest_depth_mip1, float4(_659.z), uint2(uint2(_564)));
            if (_249)
            {
                if (all(_564 == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _670 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _672 = _670.y;
                    float _673 = _659.x;
                    float _686;
                    if (_672 < 10000.0)
                    {
                        _686 = precise::max(0.0, _672 + ((_673 - _672) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _686 = _673;
                    }
                    _670.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_686) * 8.0));
                    _670.y = _686;
                    _670.z = _659.y;
                    sdk_hlsl_store(rw_frame_info, _670, uint2(uint2(0u)));
                }
            }
            if (cbSPD.mips <= 1u)
            {
                break;
            }
            float4 _699 = spvQuadSwap(_244, 0u);
            float4 _700 = spvQuadSwap(_244, 1u);
            float4 _701 = spvQuadSwap(_244, 2u);
            float4 _705 = (((_244 + _699) + _700) + _701) * 0.25;
            float4 _706 = spvQuadSwap(_385, 0u);
            float4 _707 = spvQuadSwap(_385, 1u);
            float4 _708 = spvQuadSwap(_385, 2u);
            float4 _712 = (((_385 + _706) + _707) + _708) * 0.25;
            float4 _713 = spvQuadSwap(_524, 0u);
            float4 _714 = spvQuadSwap(_524, 1u);
            float4 _715 = spvQuadSwap(_524, 2u);
            float4 _719 = (((_524 + _713) + _714) + _715) * 0.25;
            float4 _720 = spvQuadSwap(_659, 0u);
            float4 _721 = spvQuadSwap(_659, 1u);
            float4 _722 = spvQuadSwap(_659, 2u);
            float4 _726 = (((_659 + _720) + _721) + _722) * 0.25;
            if ((gl_LocalInvocationIndex % 4u) == 0u)
            {
                int2 _732 = int2(_108 * uint2(16u));
                uint _733 = _124 / 2u;
                int _734 = int(_733);
                uint _735 = _127 / 2u;
                int _736 = int(_735);
                bool _739 = 1u == _248;
                if (_739)
                {
                    if (all((_732 + int2(_734, _736)) == int2(0)))
                    {
                        spvImageFence(rw_frame_info);
                        float4 _747 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                        float _749 = _747.y;
                        float _750 = _705.x;
                        float _763;
                        if (_749 < 10000.0)
                        {
                            _763 = precise::max(0.0, _749 + ((_750 - _749) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                        }
                        else
                        {
                            _763 = _750;
                        }
                        _747.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_763) * 8.0));
                        _747.y = _763;
                        _747.z = _705.y;
                        sdk_hlsl_store(rw_frame_info, _747, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_733][_735] = _705.x;
                spdIntermediateG[_733][_735] = _705.y;
                spdIntermediateB[_733][_735] = _705.z;
                spdIntermediateA[_733][_735] = _705.w;
                uint _781 = _733 + 8u;
                int _782 = int(_781);
                if (_739)
                {
                    if (all((_732 + int2(_782, _736)) == int2(0)))
                    {
                        spvImageFence(rw_frame_info);
                        float4 _792 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                        float _794 = _792.y;
                        float _795 = _712.x;
                        float _808;
                        if (_794 < 10000.0)
                        {
                            _808 = precise::max(0.0, _794 + ((_795 - _794) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                        }
                        else
                        {
                            _808 = _795;
                        }
                        _792.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_808) * 8.0));
                        _792.y = _808;
                        _792.z = _712.y;
                        sdk_hlsl_store(rw_frame_info, _792, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_781][_735] = _712.x;
                spdIntermediateG[_781][_735] = _712.y;
                spdIntermediateB[_781][_735] = _712.z;
                spdIntermediateA[_781][_735] = _712.w;
                uint _826 = _735 + 8u;
                int _827 = int(_826);
                if (_739)
                {
                    if (all((_732 + int2(_734, _827)) == int2(0)))
                    {
                        spvImageFence(rw_frame_info);
                        float4 _837 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                        float _839 = _837.y;
                        float _840 = _719.x;
                        float _853;
                        if (_839 < 10000.0)
                        {
                            _853 = precise::max(0.0, _839 + ((_840 - _839) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                        }
                        else
                        {
                            _853 = _840;
                        }
                        _837.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_853) * 8.0));
                        _837.y = _853;
                        _837.z = _719.y;
                        sdk_hlsl_store(rw_frame_info, _837, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_733][_826] = _719.x;
                spdIntermediateG[_733][_826] = _719.y;
                spdIntermediateB[_733][_826] = _719.z;
                spdIntermediateA[_733][_826] = _719.w;
                if (_739)
                {
                    if (all((_732 + int2(_782, _827)) == int2(0)))
                    {
                        spvImageFence(rw_frame_info);
                        float4 _880 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                        float _882 = _880.y;
                        float _883 = _726.x;
                        float _896;
                        if (_882 < 10000.0)
                        {
                            _896 = precise::max(0.0, _882 + ((_883 - _882) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                        }
                        else
                        {
                            _896 = _883;
                        }
                        _880.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_896) * 8.0));
                        _880.y = _896;
                        _880.z = _726.y;
                        sdk_hlsl_store(rw_frame_info, _880, uint2(uint2(0u)));
                    }
                }
                spdIntermediateR[_781][_826] = _726.x;
                spdIntermediateG[_781][_826] = _726.y;
                spdIntermediateB[_781][_826] = _726.z;
                spdIntermediateA[_781][_826] = _726.w;
            }
            break;
        } while(false);
        do
        {
            if (cbSPD.mips <= 2u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float _920 = spdIntermediateR[_124][_127];
            float _922 = spdIntermediateG[_124][_127];
            float _924 = spdIntermediateB[_124][_127];
            float4 _927 = float4(_920, _922, _924, spdIntermediateA[_124][_127]);
            float4 _928 = spvQuadSwap(_927, 0u);
            float4 _929 = spvQuadSwap(_927, 1u);
            float4 _930 = spvQuadSwap(_927, 2u);
            float4 _934 = (((_927 + _928) + _929) + _930) * 0.25;
            bool _936 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_936)
            {
                uint _943 = _127 / 2u;
                if (2u == _248)
                {
                    if (all((int2(_108 * uint2(8u)) + int2(int(_124 / 2u), int(_943))) == int2(0)))
                    {
                        spvImageFence(rw_frame_info);
                        float4 _955 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                        float _957 = _955.y;
                        float _958 = _934.x;
                        float _971;
                        if (_957 < 10000.0)
                        {
                            _971 = precise::max(0.0, _957 + ((_958 - _957) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                        }
                        else
                        {
                            _971 = _958;
                        }
                        _955.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_971) * 8.0));
                        _955.y = _971;
                        _955.z = _934.y;
                        sdk_hlsl_store(rw_frame_info, _955, uint2(uint2(0u)));
                    }
                }
                uint _982 = _124 + (_943 % 2u);
                spdIntermediateR[_982][_127] = _934.x;
                spdIntermediateG[_982][_127] = _934.y;
                spdIntermediateB[_982][_127] = _934.z;
                spdIntermediateA[_982][_127] = _934.w;
            }
            if (cbSPD.mips <= 3u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _998 = _132 + (_127 % 2u);
                float _1000 = spdIntermediateR[_998][_134];
                float _1002 = spdIntermediateG[_998][_134];
                float _1004 = spdIntermediateB[_998][_134];
                float4 _1007 = float4(_1000, _1002, _1004, spdIntermediateA[_998][_134]);
                float4 _1008 = spvQuadSwap(_1007, 0u);
                float4 _1009 = spvQuadSwap(_1007, 1u);
                float4 _1010 = spvQuadSwap(_1007, 2u);
                float4 _1014 = (((_1007 + _1008) + _1009) + _1010) * 0.25;
                if (_936)
                {
                    uint _1021 = _127 / 2u;
                    if (3u == _248)
                    {
                        if (all((int2(_108 * uint2(4u)) + int2(int(_124 / 2u), int(_1021))) == int2(0)))
                        {
                            spvImageFence(rw_frame_info);
                            float4 _1033 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                            float _1035 = _1033.y;
                            float _1036 = _1014.x;
                            float _1049;
                            if (_1035 < 10000.0)
                            {
                                _1049 = precise::max(0.0, _1035 + ((_1036 - _1035) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                            }
                            else
                            {
                                _1049 = _1036;
                            }
                            _1033.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1049) * 8.0));
                            _1033.y = _1049;
                            _1033.z = _1014.y;
                            sdk_hlsl_store(rw_frame_info, _1033, uint2(uint2(0u)));
                        }
                    }
                    uint _1059 = _132 + _1021;
                    spdIntermediateR[_1059][_134] = _1014.x;
                    spdIntermediateG[_1059][_134] = _1014.y;
                    spdIntermediateB[_1059][_134] = _1014.z;
                    spdIntermediateA[_1059][_134] = _1014.w;
                }
            }
            if (cbSPD.mips <= 4u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1075 = (_124 * 4u) + _127;
                uint _1076 = _127 * 4u;
                float _1078 = spdIntermediateR[_1075][_1076];
                float _1080 = spdIntermediateG[_1075][_1076];
                float _1082 = spdIntermediateB[_1075][_1076];
                float4 _1085 = float4(_1078, _1080, _1082, spdIntermediateA[_1075][_1076]);
                float4 _1086 = spvQuadSwap(_1085, 0u);
                float4 _1087 = spvQuadSwap(_1085, 1u);
                float4 _1088 = spvQuadSwap(_1085, 2u);
                float4 _1092 = (((_1085 + _1086) + _1087) + _1088) * 0.25;
                if (_936)
                {
                    uint _1097 = _124 / 2u;
                    if (4u == _248)
                    {
                        if (all((int2(_108 * uint2(2u)) + int2(int(_1097), int(_127 / 2u))) == int2(0)))
                        {
                            spvImageFence(rw_frame_info);
                            float4 _1111 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                            float _1113 = _1111.y;
                            float _1114 = _1092.x;
                            float _1127;
                            if (_1113 < 10000.0)
                            {
                                _1127 = precise::max(0.0, _1113 + ((_1114 - _1113) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                            }
                            else
                            {
                                _1127 = _1114;
                            }
                            _1111.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1127) * 8.0));
                            _1111.y = _1127;
                            _1111.z = _1092.y;
                            sdk_hlsl_store(rw_frame_info, _1111, uint2(uint2(0u)));
                        }
                    }
                    uint _1137 = _1097 + _127;
                    spdIntermediateR[_1137][0u] = _1092.x;
                    spdIntermediateG[_1137][0u] = _1092.y;
                    spdIntermediateB[_1137][0u] = _1092.z;
                    spdIntermediateA[_1137][0u] = _1092.w;
                }
            }
            if (cbSPD.mips <= 5u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1160 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1161 = spvQuadSwap(_1160, 0u);
                float4 _1162 = spvQuadSwap(_1160, 1u);
                float4 _1163 = spvQuadSwap(_1160, 2u);
                float4 _1167 = (((_1160 + _1161) + _1162) + _1163) * 0.25;
                if (_936)
                {
                    sdk_hlsl_store(rw_spd_mip5, _1167.xy.xyyy, uint2(_108));
                    if (5u == _248)
                    {
                        if (all(int2(_108) == int2(0)))
                        {
                            spvImageFence(rw_frame_info);
                            float4 _1181 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                            float _1183 = _1181.y;
                            float _1184 = _1167.x;
                            float _1197;
                            if (_1183 < 10000.0)
                            {
                                _1197 = precise::max(0.0, _1183 + ((_1184 - _1183) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                            }
                            else
                            {
                                _1197 = _1184;
                            }
                            _1181.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1197) * 8.0));
                            _1181.y = _1197;
                            _1181.z = _1167.y;
                            sdk_hlsl_store(rw_frame_info, _1181, uint2(uint2(0u)));
                        }
                    }
                }
            }
            break;
        } while(false);
        if (cbSPD.mips <= 6u)
        {
            break;
        }
        if (gl_LocalInvocationIndex == 0u)
        {
            uint _1214 = rw_spd_global_atomic.atomic_fetch_add(uint2(0u), 1u).x;
            spdCounter = _1214;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (spdCounter != (cbSPD.numWorkGroups - 1u))
        {
            break;
        }
        uint _1223;
        uint _1225;
        sdk_hlsl_store(rw_spd_global_atomic, uint4(0u), uint2(uint2(0u)));
        do
        {
            _1223 = _124 * 4u;
            int _1224 = int(_1223);
            _1225 = _127 * 4u;
            int _1226 = int(_1225);
            uint2 _1228 = uint2(int2(_1224, _1226));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            float4 _1255 = (((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_1228)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1228 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1228 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1228 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25;
            bool _1256 = 6u == _248;
            if (_1256)
            {
                if (all(_136 == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _1264 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _1266 = _1264.y;
                    float _1267 = _1255.x;
                    float _1280;
                    if (_1266 < 10000.0)
                    {
                        _1280 = precise::max(0.0, _1266 + ((_1267 - _1266) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _1280 = _1267;
                    }
                    _1264.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1280) * 8.0));
                    _1264.y = _1280;
                    _1264.z = _1255.y;
                    sdk_hlsl_store(rw_frame_info, _1264, uint2(uint2(0u)));
                }
            }
            int _1291 = int(_1223 + 2u);
            int _1294 = int(_132 + 1u);
            uint2 _1296 = uint2(int2(_1291, _1226));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            float4 _1323 = (((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_1296)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1296 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1296 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1296 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25;
            if (_1256)
            {
                if (all(int2(_1294, _135) == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _1331 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _1333 = _1331.y;
                    float _1334 = _1323.x;
                    float _1347;
                    if (_1333 < 10000.0)
                    {
                        _1347 = precise::max(0.0, _1333 + ((_1334 - _1333) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _1347 = _1334;
                    }
                    _1331.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1347) * 8.0));
                    _1331.y = _1347;
                    _1331.z = _1323.y;
                    sdk_hlsl_store(rw_frame_info, _1331, uint2(uint2(0u)));
                }
            }
            int _1358 = int(_1225 + 2u);
            int _1361 = int(_134 + 1u);
            uint2 _1363 = uint2(int2(_1224, _1358));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            float4 _1390 = (((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_1363)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1363 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1363 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1363 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25;
            if (_1256)
            {
                if (all(int2(_133, _1361) == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _1398 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _1400 = _1398.y;
                    float _1401 = _1390.x;
                    float _1414;
                    if (_1400 < 10000.0)
                    {
                        _1414 = precise::max(0.0, _1400 + ((_1401 - _1400) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _1414 = _1401;
                    }
                    _1398.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1414) * 8.0));
                    _1398.y = _1414;
                    _1398.z = _1390.y;
                    sdk_hlsl_store(rw_frame_info, _1398, uint2(uint2(0u)));
                }
            }
            uint2 _1426 = uint2(int2(_1291, _1358));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            float4 _1453 = (((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_1426)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1426 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1426 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_1426 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25;
            if (_1256)
            {
                if (all(int2(_1294, _1361) == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _1461 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _1463 = _1461.y;
                    float _1464 = _1453.x;
                    float _1477;
                    if (_1463 < 10000.0)
                    {
                        _1477 = precise::max(0.0, _1463 + ((_1464 - _1463) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _1477 = _1464;
                    }
                    _1461.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1477) * 8.0));
                    _1461.y = _1477;
                    _1461.z = _1453.y;
                    sdk_hlsl_store(rw_frame_info, _1461, uint2(uint2(0u)));
                }
            }
            if (cbSPD.mips <= 7u)
            {
                break;
            }
            float4 _1493 = (((_1255 + _1323) + _1390) + _1453) * 0.25;
            if (7u == _248)
            {
                if (all(_142 == int2(0)))
                {
                    spvImageFence(rw_frame_info);
                    float4 _1502 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                    float _1504 = _1502.y;
                    float _1505 = _1493.x;
                    float _1518;
                    if (_1504 < 10000.0)
                    {
                        _1518 = precise::max(0.0, _1504 + ((_1505 - _1504) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                    }
                    else
                    {
                        _1518 = _1505;
                    }
                    _1502.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1518) * 8.0));
                    _1502.y = _1518;
                    _1502.z = _1493.y;
                    sdk_hlsl_store(rw_frame_info, _1502, uint2(uint2(0u)));
                }
            }
            spdIntermediateR[_124][_127] = _1493.x;
            spdIntermediateG[_124][_127] = _1493.y;
            spdIntermediateB[_124][_127] = _1493.z;
            spdIntermediateA[_124][_127] = _1493.w;
            break;
        } while(false);
        do
        {
            if (cbSPD.mips <= 8u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float _1542 = spdIntermediateR[_124][_127];
            float _1544 = spdIntermediateG[_124][_127];
            float _1546 = spdIntermediateB[_124][_127];
            float4 _1549 = float4(_1542, _1544, _1546, spdIntermediateA[_124][_127]);
            float4 _1550 = spvQuadSwap(_1549, 0u);
            float4 _1551 = spvQuadSwap(_1549, 1u);
            float4 _1552 = spvQuadSwap(_1549, 2u);
            float4 _1556 = (((_1549 + _1550) + _1551) + _1552) * 0.25;
            bool _1558 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_1558)
            {
                uint _1563 = _127 / 2u;
                if (8u == _248)
                {
                    if (all(int2(int(_124 / 2u), int(_1563)) == int2(0)))
                    {
                        spvImageFence(rw_frame_info);
                        float4 _1574 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                        float _1576 = _1574.y;
                        float _1577 = _1556.x;
                        float _1590;
                        if (_1576 < 10000.0)
                        {
                            _1590 = precise::max(0.0, _1576 + ((_1577 - _1576) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                        }
                        else
                        {
                            _1590 = _1577;
                        }
                        _1574.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1590) * 8.0));
                        _1574.y = _1590;
                        _1574.z = _1556.y;
                        sdk_hlsl_store(rw_frame_info, _1574, uint2(uint2(0u)));
                    }
                }
                uint _1601 = _124 + (_1563 % 2u);
                spdIntermediateR[_1601][_127] = _1556.x;
                spdIntermediateG[_1601][_127] = _1556.y;
                spdIntermediateB[_1601][_127] = _1556.z;
                spdIntermediateA[_1601][_127] = _1556.w;
            }
            if (cbSPD.mips <= 9u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _1617 = _132 + (_127 % 2u);
                float _1619 = spdIntermediateR[_1617][_134];
                float _1621 = spdIntermediateG[_1617][_134];
                float _1623 = spdIntermediateB[_1617][_134];
                float4 _1626 = float4(_1619, _1621, _1623, spdIntermediateA[_1617][_134]);
                float4 _1627 = spvQuadSwap(_1626, 0u);
                float4 _1628 = spvQuadSwap(_1626, 1u);
                float4 _1629 = spvQuadSwap(_1626, 2u);
                float4 _1633 = (((_1626 + _1627) + _1628) + _1629) * 0.25;
                if (_1558)
                {
                    uint _1638 = _127 / 2u;
                    if (9u == _248)
                    {
                        if (all(int2(int(_124 / 2u), int(_1638)) == int2(0)))
                        {
                            spvImageFence(rw_frame_info);
                            float4 _1649 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                            float _1651 = _1649.y;
                            float _1652 = _1633.x;
                            float _1665;
                            if (_1651 < 10000.0)
                            {
                                _1665 = precise::max(0.0, _1651 + ((_1652 - _1651) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                            }
                            else
                            {
                                _1665 = _1652;
                            }
                            _1649.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1665) * 8.0));
                            _1649.y = _1665;
                            _1649.z = _1633.y;
                            sdk_hlsl_store(rw_frame_info, _1649, uint2(uint2(0u)));
                        }
                    }
                    uint _1675 = _132 + _1638;
                    spdIntermediateR[_1675][_134] = _1633.x;
                    spdIntermediateG[_1675][_134] = _1633.y;
                    spdIntermediateB[_1675][_134] = _1633.z;
                    spdIntermediateA[_1675][_134] = _1633.w;
                }
            }
            if (cbSPD.mips <= 10u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1690 = _1223 + _127;
                float _1692 = spdIntermediateR[_1690][_1225];
                float _1694 = spdIntermediateG[_1690][_1225];
                float _1696 = spdIntermediateB[_1690][_1225];
                float4 _1699 = float4(_1692, _1694, _1696, spdIntermediateA[_1690][_1225]);
                float4 _1700 = spvQuadSwap(_1699, 0u);
                float4 _1701 = spvQuadSwap(_1699, 1u);
                float4 _1702 = spvQuadSwap(_1699, 2u);
                float4 _1706 = (((_1699 + _1700) + _1701) + _1702) * 0.25;
                if (_1558)
                {
                    uint _1709 = _124 / 2u;
                    if (10u == _248)
                    {
                        if (all(int2(int(_1709), int(_127 / 2u)) == int2(0)))
                        {
                            spvImageFence(rw_frame_info);
                            float4 _1722 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                            float _1724 = _1722.y;
                            float _1725 = _1706.x;
                            float _1738;
                            if (_1724 < 10000.0)
                            {
                                _1738 = precise::max(0.0, _1724 + ((_1725 - _1724) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                            }
                            else
                            {
                                _1738 = _1725;
                            }
                            _1722.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1738) * 8.0));
                            _1722.y = _1738;
                            _1722.z = _1706.y;
                            sdk_hlsl_store(rw_frame_info, _1722, uint2(uint2(0u)));
                        }
                    }
                    uint _1748 = _1709 + _127;
                    spdIntermediateR[_1748][0u] = _1706.x;
                    spdIntermediateG[_1748][0u] = _1706.y;
                    spdIntermediateB[_1748][0u] = _1706.z;
                    spdIntermediateA[_1748][0u] = _1706.w;
                }
            }
            if (cbSPD.mips <= 11u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1771 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1772 = spvQuadSwap(_1771, 0u);
                float4 _1773 = spvQuadSwap(_1771, 1u);
                float4 _1774 = spvQuadSwap(_1771, 2u);
                float4 _1778 = (((_1771 + _1772) + _1773) + _1774) * 0.25;
                if (_1558)
                {
                    if (11u == _248)
                    {
                        if (all(bool2(true)))
                        {
                            spvImageFence(rw_frame_info);
                            float4 _1788 = sdk_hlsl_load(rw_frame_info, uint2(uint2(0u)));
                            float _1790 = _1788.y;
                            float _1791 = _1778.x;
                            float _1804;
                            if (_1790 < 10000.0)
                            {
                                _1804 = precise::max(0.0, _1790 + ((_1791 - _1790) * (1.0 - exp(-cbFSR3Upscaler.fDeltaTime))));
                            }
                            else
                            {
                                _1804 = _1791;
                            }
                            _1788.x = 0.833333313465118408203125 / powr(2.0, log2(exp(_1804) * 8.0));
                            _1788.y = _1804;
                            _1788.z = _1778.y;
                            sdk_hlsl_store(rw_frame_info, _1788, uint2(uint2(0u)));
                        }
                    }
                }
            }
            break;
        } while(false);
        break;
    } while(false);
}

