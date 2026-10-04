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

constant bool _56 = {};

constant spvUnsafeArray<uint, 4> _61 = spvUnsafeArray<uint, 4>({ 27u, 54u, 216u, 432u });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_lock_input_luma [[texture(0)]], texture2d<uint, access::write> rw_reconstructed_previous_nearest_depth [[texture(1)]], texture2d<float, access::write> rw_new_locks [[texture(2)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _69 = (gl_WorkGroupID.xy * uint2(8u)) + gl_LocalInvocationID.xy;
    int2 _70 = int2(_69);
    bool _196;
    do
    {
        float4 _74 = sdk_hlsl_load(r_lock_input_luma, uint2(_69), 0u);
        float _75 = _74.x;
        uint _77;
        float _80;
        float _82;
        _77 = 16u;
        _80 = 3.4028234663852885981170418348452e+38;
        _82 = 0.0;
        uint _78;
        float _81;
        float _83;
        int _87;
        for (int _84 = -1, _86 = 0; _84 <= 1; _77 = _78, _80 = _81, _82 = _83, _84++, _86 = _87)
        {
            _78 = _77;
            _87 = _86;
            _83 = _82;
            _81 = _80;
            uint _92;
            float _95;
            float _96;
            for (int _97 = -1; _97 <= 1; _78 = _92, _87++, _83 = _95, _81 = _96, _97++)
            {
                bool _106;
                if (_97 == 0)
                {
                    _106 = _84 == 0;
                }
                else
                {
                    _106 = false;
                }
                if (_106)
                {
                    _92 = _78;
                    _95 = _83;
                    _96 = _81;
                    continue;
                }
                int2 _112 = _70 + int2(_97, _84);
                int _120;
                if (_97 < 0)
                {
                    _120 = max(_112.x, 0);
                }
                else
                {
                    _120 = _112.x;
                }
                int _128;
                if (_97 > 0)
                {
                    _128 = min(_120, (cbFSR2.iRenderSize.x - 1));
                }
                else
                {
                    _128 = _120;
                }
                int _136;
                if (_84 < 0)
                {
                    _136 = max(_112.y, 0);
                }
                else
                {
                    _136 = _112.y;
                }
                int2 _137 = int2(_128, _136);
                int _145;
                if (_84 > 0)
                {
                    _145 = min(_136, (cbFSR2.iRenderSize.y - 1));
                }
                else
                {
                    _145 = _136;
                }
                _137.y = _145;
                float4 _149 = sdk_hlsl_load(r_lock_input_luma, uint2(uint2(_137)), 0u);
                float _150 = _149.x;
                float _153 = precise::max(_150, _75) / precise::min(_150, _75);
                bool _158;
                if (_153 > 0.0)
                {
                    _158 = _153 < 1.0499999523162841796875;
                }
                else
                {
                    _158 = false;
                }
                uint _168;
                float _169;
                float _170;
                if (_158)
                {
                    _168 = _78 | (1u << (uint(_87) & 31u));
                    _169 = _83;
                    _170 = _81;
                }
                else
                {
                    _168 = _78;
                    _169 = precise::max(_83, _150);
                    _170 = precise::min(_81, _150);
                }
                _92 = _168;
                _95 = _169;
                _96 = _170;
            }
        }
        bool _175;
        if ((isunordered(_75, _82) || _75 <= _82))
        {
            _175 = _75 < _80;
        }
        else
        {
            _175 = true;
        }
        if (!_175)
        {
            _196 = false;
            break;
        }
        bool _193;
        bool _194;
        int _180 = 0;
        for (;;)
        {
            if (_180 < 4)
            {
                if ((_77 & _61[_180]) == _61[_180])
                {
                    _193 = false;
                    _194 = true;
                    break;
                }
                _180++;
                continue;
            }
            else
            {
                _193 = _56;
                _194 = false;
                break;
            }
        }
        if (_194)
        {
            _196 = _193;
            break;
        }
        _196 = true;
        break;
    } while(false);
    if (_196)
    {
        sdk_hlsl_store(rw_new_locks, float4(1.0), uint2(uint2(int2(floor((((float2(_70) + float2(0.5)) - cbFSR2.fJitter) / float2(cbFSR2.iRenderSize)) * float2(cbFSR2.iDisplaySize))))));
    }
    if (all(_70 < cbFSR2.iRenderSize))
    {
        sdk_hlsl_store(rw_reconstructed_previous_nearest_depth, uint4(0u), uint2(_69));
    }
}

