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

constant bool _57 = {};

constant spvUnsafeArray<uint, 4> _62 = spvUnsafeArray<uint, 4>({ 27u, 54u, 216u, 432u });

kernel void main0(constant type_cbFSR2& cbFSR2 [[buffer(0)]], texture2d<float> r_lock_input_luma [[texture(0)]], texture2d<uint, access::write> rw_reconstructed_previous_nearest_depth [[texture(1)]], texture2d<float, access::write> rw_new_locks [[texture(2)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    uint2 _70 = (gl_WorkGroupID.xy * uint2(8u)) + gl_LocalInvocationID.xy;
    int2 _71 = int2(_70);
    bool _197;
    do
    {
        float4 _75 = sdk_hlsl_load(r_lock_input_luma, uint2(_70), 0u);
        float _76 = _75.x;
        uint _78;
        float _81;
        float _83;
        _78 = 16u;
        _81 = 3.4028234663852885981170418348452e+38;
        _83 = 0.0;
        uint _79;
        float _82;
        float _84;
        int _88;
        for (int _85 = -1, _87 = 0; _85 <= 1; _78 = _79, _81 = _82, _83 = _84, _85++, _87 = _88)
        {
            _79 = _78;
            _88 = _87;
            _84 = _83;
            _82 = _81;
            uint _93;
            float _96;
            float _97;
            for (int _98 = -1; _98 <= 1; _79 = _93, _88++, _84 = _96, _82 = _97, _98++)
            {
                bool _107;
                if (_98 == 0)
                {
                    _107 = _85 == 0;
                }
                else
                {
                    _107 = false;
                }
                if (_107)
                {
                    _93 = _79;
                    _96 = _84;
                    _97 = _82;
                    continue;
                }
                int2 _113 = _71 + int2(_98, _85);
                int _121;
                if (_98 < 0)
                {
                    _121 = max(_113.x, 0);
                }
                else
                {
                    _121 = _113.x;
                }
                int _129;
                if (_98 > 0)
                {
                    _129 = min(_121, (cbFSR2.iRenderSize.x - 1));
                }
                else
                {
                    _129 = _121;
                }
                int _137;
                if (_85 < 0)
                {
                    _137 = max(_113.y, 0);
                }
                else
                {
                    _137 = _113.y;
                }
                int2 _138 = int2(_129, _137);
                int _146;
                if (_85 > 0)
                {
                    _146 = min(_137, (cbFSR2.iRenderSize.y - 1));
                }
                else
                {
                    _146 = _137;
                }
                _138.y = _146;
                float4 _150 = sdk_hlsl_load(r_lock_input_luma, uint2(uint2(_138)), 0u);
                float _151 = _150.x;
                float _154 = precise::max(_151, _76) / precise::min(_151, _76);
                bool _159;
                if (_154 > 0.0)
                {
                    _159 = _154 < 1.0499999523162841796875;
                }
                else
                {
                    _159 = false;
                }
                uint _169;
                float _170;
                float _171;
                if (_159)
                {
                    _169 = _79 | (1u << (uint(_88) & 31u));
                    _170 = _84;
                    _171 = _82;
                }
                else
                {
                    _169 = _79;
                    _170 = precise::max(_84, _151);
                    _171 = precise::min(_82, _151);
                }
                _93 = _169;
                _96 = _170;
                _97 = _171;
            }
        }
        bool _176;
        if ((isunordered(_76, _83) || _76 <= _83))
        {
            _176 = _76 < _81;
        }
        else
        {
            _176 = true;
        }
        if (!_176)
        {
            _197 = false;
            break;
        }
        bool _194;
        bool _195;
        int _181 = 0;
        for (;;)
        {
            if (_181 < 4)
            {
                if ((_78 & _62[_181]) == _62[_181])
                {
                    _194 = false;
                    _195 = true;
                    break;
                }
                _181++;
                continue;
            }
            else
            {
                _194 = _57;
                _195 = false;
                break;
            }
        }
        if (_195)
        {
            _197 = _194;
            break;
        }
        _197 = true;
        break;
    } while(false);
    if (_197)
    {
        sdk_hlsl_store(rw_new_locks, float4(1.0), uint2(uint2(int2(floor((((float2(_71) + float2(0.5)) - cbFSR2.fJitter) / float2(cbFSR2.iRenderSize)) * float2(cbFSR2.iDisplaySize))))));
    }
    if (all(_71 < cbFSR2.iRenderSize))
    {
        sdk_hlsl_store(rw_reconstructed_previous_nearest_depth, uint4(1065353216u), uint2(_70));
    }
}

