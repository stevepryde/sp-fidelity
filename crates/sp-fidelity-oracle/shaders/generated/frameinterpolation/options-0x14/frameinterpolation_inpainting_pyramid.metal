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

struct type_cbInpaintingPyramid
{
    uint mips;
    uint numWorkGroups;
    uint2 workGroupOffset;
};

struct type_RWStructuredBuffer_uint
{
    uint _m0[1];
};

kernel void main0(constant type_cbFI& cbFI [[buffer(0)]], constant type_cbInpaintingPyramid& cbInpaintingPyramid [[buffer(1)]], volatile device type_RWStructuredBuffer_uint& rw_counters [[buffer(2)]], texture2d<float> r_output [[texture(0)]], texture2d<float, access::write> rw_inpainting_pyramid0 [[texture(1)]], texture2d<float, access::write> rw_inpainting_pyramid1 [[texture(2)]], texture2d<float, access::write> rw_inpainting_pyramid2 [[texture(3)]], texture2d<float, access::write> rw_inpainting_pyramid3 [[texture(4)]], texture2d<float, access::write> rw_inpainting_pyramid4 [[texture(5)]], texture2d<float, access::read_write> rw_inpainting_pyramid5 [[texture(6)]], texture2d<float, access::write> rw_inpainting_pyramid6 [[texture(7)]], texture2d<float, access::write> rw_inpainting_pyramid7 [[texture(8)]], texture2d<float, access::write> rw_inpainting_pyramid8 [[texture(9)]], texture2d<float, access::write> rw_inpainting_pyramid9 [[texture(10)]], texture2d<float, access::write> rw_inpainting_pyramid10 [[texture(11)]], texture2d<float, access::write> rw_inpainting_pyramid11 [[texture(12)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup uint spdCounter;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateR;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateG;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateB;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateA;
    uint2 _107 = uint2(int3(gl_WorkGroupID).xy) + cbInpaintingPyramid.workGroupOffset;
    do
    {
        uint _131;
        int _132;
        uint _133;
        int _134;
        int2 _135;
        int2 _141;
        uint _110 = gl_LocalInvocationIndex % 64u;
        uint _123 = ((_110 & 1u) | ((_110 >> 2u) & 6u)) + (8u * ((gl_LocalInvocationIndex >> 6u) % 2u));
        uint _126 = (((_110 >> 1u) & 3u) | ((_110 >> 3u) & 4u)) + (8u * (gl_LocalInvocationIndex >> 7u));
        do
        {
            int2 _130 = int2(_107 * uint2(64u));
            _131 = _123 * 2u;
            _132 = int(_131);
            _133 = _126 * 2u;
            _134 = int(_133);
            _135 = int2(_132, _134);
            int2 _136 = _130 + _135;
            int2 _138 = int2(_107 * uint2(32u));
            int _139 = int(_123);
            int _140 = int(_126);
            _141 = int2(_139, _140);
            uint2 _143 = uint2(_136);
            uint2 _144 = _143 + uint2(0u, 1u);
            uint2 _145 = _143 + uint2(1u, 0u);
            uint2 _146 = _143 + uint2(1u);
            float _153 = float(cbFI.displaySize.x > 0);
            float4 _154 = sdk_hlsl_load(r_output, uint2(_143), 0u) * _153;
            _154.w = fast::clamp(1.0 - _154.w, 0.0, 1.0);
            int _159 = _136.x;
            bool _171;
            if (_159 >= cbFI.interpolationRectBase.x)
            {
                _171 = _159 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _171 = true;
            }
            bool _178;
            if (!_171)
            {
                _178 = _136.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _178 = true;
            }
            bool _189;
            if (!_178)
            {
                _189 = _136.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _189 = true;
            }
            float4 _193;
            if (_189)
            {
                float4 _192 = _154;
                _192.w = 0.0;
                _193 = _192;
            }
            else
            {
                _193 = _154;
            }
            int2 _194 = int2(_144);
            float4 _197 = sdk_hlsl_load(r_output, uint2(_144), 0u) * _153;
            _197.w = fast::clamp(1.0 - _197.w, 0.0, 1.0);
            int _202 = _194.x;
            bool _211;
            if (_202 >= cbFI.interpolationRectBase.x)
            {
                _211 = _202 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _211 = true;
            }
            bool _218;
            if (!_211)
            {
                _218 = _194.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _218 = true;
            }
            bool _229;
            if (!_218)
            {
                _229 = _194.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _229 = true;
            }
            float4 _233;
            if (_229)
            {
                float4 _232 = _197;
                _232.w = 0.0;
                _233 = _232;
            }
            else
            {
                _233 = _197;
            }
            int2 _234 = int2(_145);
            float4 _237 = sdk_hlsl_load(r_output, uint2(_145), 0u) * _153;
            _237.w = fast::clamp(1.0 - _237.w, 0.0, 1.0);
            int _242 = _234.x;
            bool _251;
            if (_242 >= cbFI.interpolationRectBase.x)
            {
                _251 = _242 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _251 = true;
            }
            bool _258;
            if (!_251)
            {
                _258 = _234.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _258 = true;
            }
            bool _269;
            if (!_258)
            {
                _269 = _234.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _269 = true;
            }
            float4 _273;
            if (_269)
            {
                float4 _272 = _237;
                _272.w = 0.0;
                _273 = _272;
            }
            else
            {
                _273 = _237;
            }
            int2 _274 = int2(_146);
            float4 _277 = sdk_hlsl_load(r_output, uint2(_146), 0u) * _153;
            _277.w = fast::clamp(1.0 - _277.w, 0.0, 1.0);
            int _282 = _274.x;
            bool _291;
            if (_282 >= cbFI.interpolationRectBase.x)
            {
                _291 = _282 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _291 = true;
            }
            bool _298;
            if (!_291)
            {
                _298 = _274.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _298 = true;
            }
            bool _309;
            if (!_298)
            {
                _309 = _274.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _309 = true;
            }
            float4 _313;
            if (_309)
            {
                float4 _312 = _277;
                _312.w = 0.0;
                _313 = _312;
            }
            else
            {
                _313 = _277;
            }
            float4 _335;
            do
            {
                float _322 = ((_193.w + _233.w) + _273.w) + _313.w;
                if (_322 == 0.0)
                {
                    _335 = float4(0.0);
                    break;
                }
                _335 = ((((_193 * _193.w) + (_233 * _233.w)) + (_273 * _273.w)) + (_313 * _313.w)) / float4(_322);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid0, _335, uint2(uint2(_138 + _141)));
            int _339 = int(_131 + 32u);
            int2 _341 = _130 + int2(_339, _134);
            int _343 = int(_123 + 16u);
            uint2 _346 = uint2(_341);
            uint2 _347 = _346 + uint2(0u, 1u);
            uint2 _348 = _346 + uint2(1u, 0u);
            uint2 _349 = _346 + uint2(1u);
            float4 _352 = sdk_hlsl_load(r_output, uint2(_346), 0u) * _153;
            _352.w = fast::clamp(1.0 - _352.w, 0.0, 1.0);
            int _357 = _341.x;
            bool _366;
            if (_357 >= cbFI.interpolationRectBase.x)
            {
                _366 = _357 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _366 = true;
            }
            bool _373;
            if (!_366)
            {
                _373 = _341.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _373 = true;
            }
            bool _384;
            if (!_373)
            {
                _384 = _341.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _384 = true;
            }
            float4 _388;
            if (_384)
            {
                float4 _387 = _352;
                _387.w = 0.0;
                _388 = _387;
            }
            else
            {
                _388 = _352;
            }
            int2 _389 = int2(_347);
            float4 _392 = sdk_hlsl_load(r_output, uint2(_347), 0u) * _153;
            _392.w = fast::clamp(1.0 - _392.w, 0.0, 1.0);
            int _397 = _389.x;
            bool _406;
            if (_397 >= cbFI.interpolationRectBase.x)
            {
                _406 = _397 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _406 = true;
            }
            bool _413;
            if (!_406)
            {
                _413 = _389.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _413 = true;
            }
            bool _424;
            if (!_413)
            {
                _424 = _389.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _424 = true;
            }
            float4 _428;
            if (_424)
            {
                float4 _427 = _392;
                _427.w = 0.0;
                _428 = _427;
            }
            else
            {
                _428 = _392;
            }
            int2 _429 = int2(_348);
            float4 _432 = sdk_hlsl_load(r_output, uint2(_348), 0u) * _153;
            _432.w = fast::clamp(1.0 - _432.w, 0.0, 1.0);
            int _437 = _429.x;
            bool _446;
            if (_437 >= cbFI.interpolationRectBase.x)
            {
                _446 = _437 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _446 = true;
            }
            bool _453;
            if (!_446)
            {
                _453 = _429.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _453 = true;
            }
            bool _464;
            if (!_453)
            {
                _464 = _429.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _464 = true;
            }
            float4 _468;
            if (_464)
            {
                float4 _467 = _432;
                _467.w = 0.0;
                _468 = _467;
            }
            else
            {
                _468 = _432;
            }
            int2 _469 = int2(_349);
            float4 _472 = sdk_hlsl_load(r_output, uint2(_349), 0u) * _153;
            _472.w = fast::clamp(1.0 - _472.w, 0.0, 1.0);
            int _477 = _469.x;
            bool _486;
            if (_477 >= cbFI.interpolationRectBase.x)
            {
                _486 = _477 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _486 = true;
            }
            bool _493;
            if (!_486)
            {
                _493 = _469.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _493 = true;
            }
            bool _504;
            if (!_493)
            {
                _504 = _469.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _504 = true;
            }
            float4 _508;
            if (_504)
            {
                float4 _507 = _472;
                _507.w = 0.0;
                _508 = _507;
            }
            else
            {
                _508 = _472;
            }
            float4 _530;
            do
            {
                float _517 = ((_388.w + _428.w) + _468.w) + _508.w;
                if (_517 == 0.0)
                {
                    _530 = float4(0.0);
                    break;
                }
                _530 = ((((_388 * _388.w) + (_428 * _428.w)) + (_468 * _468.w)) + (_508 * _508.w)) / float4(_517);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid0, _530, uint2(uint2(_138 + int2(_343, _140))));
            int _534 = int(_133 + 32u);
            int2 _536 = _130 + int2(_132, _534);
            int _538 = int(_126 + 16u);
            uint2 _541 = uint2(_536);
            uint2 _542 = _541 + uint2(0u, 1u);
            uint2 _543 = _541 + uint2(1u, 0u);
            uint2 _544 = _541 + uint2(1u);
            float4 _547 = sdk_hlsl_load(r_output, uint2(_541), 0u) * _153;
            _547.w = fast::clamp(1.0 - _547.w, 0.0, 1.0);
            int _552 = _536.x;
            bool _561;
            if (_552 >= cbFI.interpolationRectBase.x)
            {
                _561 = _552 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _561 = true;
            }
            bool _568;
            if (!_561)
            {
                _568 = _536.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _568 = true;
            }
            bool _579;
            if (!_568)
            {
                _579 = _536.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _579 = true;
            }
            float4 _583;
            if (_579)
            {
                float4 _582 = _547;
                _582.w = 0.0;
                _583 = _582;
            }
            else
            {
                _583 = _547;
            }
            int2 _584 = int2(_542);
            float4 _587 = sdk_hlsl_load(r_output, uint2(_542), 0u) * _153;
            _587.w = fast::clamp(1.0 - _587.w, 0.0, 1.0);
            int _592 = _584.x;
            bool _601;
            if (_592 >= cbFI.interpolationRectBase.x)
            {
                _601 = _592 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _601 = true;
            }
            bool _608;
            if (!_601)
            {
                _608 = _584.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _608 = true;
            }
            bool _619;
            if (!_608)
            {
                _619 = _584.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _619 = true;
            }
            float4 _623;
            if (_619)
            {
                float4 _622 = _587;
                _622.w = 0.0;
                _623 = _622;
            }
            else
            {
                _623 = _587;
            }
            int2 _624 = int2(_543);
            float4 _627 = sdk_hlsl_load(r_output, uint2(_543), 0u) * _153;
            _627.w = fast::clamp(1.0 - _627.w, 0.0, 1.0);
            int _632 = _624.x;
            bool _641;
            if (_632 >= cbFI.interpolationRectBase.x)
            {
                _641 = _632 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _641 = true;
            }
            bool _648;
            if (!_641)
            {
                _648 = _624.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _648 = true;
            }
            bool _659;
            if (!_648)
            {
                _659 = _624.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _659 = true;
            }
            float4 _663;
            if (_659)
            {
                float4 _662 = _627;
                _662.w = 0.0;
                _663 = _662;
            }
            else
            {
                _663 = _627;
            }
            int2 _664 = int2(_544);
            float4 _667 = sdk_hlsl_load(r_output, uint2(_544), 0u) * _153;
            _667.w = fast::clamp(1.0 - _667.w, 0.0, 1.0);
            int _672 = _664.x;
            bool _681;
            if (_672 >= cbFI.interpolationRectBase.x)
            {
                _681 = _672 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _681 = true;
            }
            bool _688;
            if (!_681)
            {
                _688 = _664.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _688 = true;
            }
            bool _699;
            if (!_688)
            {
                _699 = _664.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _699 = true;
            }
            float4 _703;
            if (_699)
            {
                float4 _702 = _667;
                _702.w = 0.0;
                _703 = _702;
            }
            else
            {
                _703 = _667;
            }
            float4 _725;
            do
            {
                float _712 = ((_583.w + _623.w) + _663.w) + _703.w;
                if (_712 == 0.0)
                {
                    _725 = float4(0.0);
                    break;
                }
                _725 = ((((_583 * _583.w) + (_623 * _623.w)) + (_663 * _663.w)) + (_703 * _703.w)) / float4(_712);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid0, _725, uint2(uint2(_138 + int2(_139, _538))));
            int2 _729 = _130 + int2(_339, _534);
            uint2 _732 = uint2(_729);
            uint2 _733 = _732 + uint2(0u, 1u);
            uint2 _734 = _732 + uint2(1u, 0u);
            uint2 _735 = _732 + uint2(1u);
            float4 _738 = sdk_hlsl_load(r_output, uint2(_732), 0u) * _153;
            _738.w = fast::clamp(1.0 - _738.w, 0.0, 1.0);
            int _743 = _729.x;
            bool _752;
            if (_743 >= cbFI.interpolationRectBase.x)
            {
                _752 = _743 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _752 = true;
            }
            bool _759;
            if (!_752)
            {
                _759 = _729.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _759 = true;
            }
            bool _770;
            if (!_759)
            {
                _770 = _729.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _770 = true;
            }
            float4 _774;
            if (_770)
            {
                float4 _773 = _738;
                _773.w = 0.0;
                _774 = _773;
            }
            else
            {
                _774 = _738;
            }
            int2 _775 = int2(_733);
            float4 _778 = sdk_hlsl_load(r_output, uint2(_733), 0u) * _153;
            _778.w = fast::clamp(1.0 - _778.w, 0.0, 1.0);
            int _783 = _775.x;
            bool _792;
            if (_783 >= cbFI.interpolationRectBase.x)
            {
                _792 = _783 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _792 = true;
            }
            bool _799;
            if (!_792)
            {
                _799 = _775.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _799 = true;
            }
            bool _810;
            if (!_799)
            {
                _810 = _775.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _810 = true;
            }
            float4 _814;
            if (_810)
            {
                float4 _813 = _778;
                _813.w = 0.0;
                _814 = _813;
            }
            else
            {
                _814 = _778;
            }
            int2 _815 = int2(_734);
            float4 _818 = sdk_hlsl_load(r_output, uint2(_734), 0u) * _153;
            _818.w = fast::clamp(1.0 - _818.w, 0.0, 1.0);
            int _823 = _815.x;
            bool _832;
            if (_823 >= cbFI.interpolationRectBase.x)
            {
                _832 = _823 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _832 = true;
            }
            bool _839;
            if (!_832)
            {
                _839 = _815.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _839 = true;
            }
            bool _850;
            if (!_839)
            {
                _850 = _815.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _850 = true;
            }
            float4 _854;
            if (_850)
            {
                float4 _853 = _818;
                _853.w = 0.0;
                _854 = _853;
            }
            else
            {
                _854 = _818;
            }
            int2 _855 = int2(_735);
            float4 _858 = sdk_hlsl_load(r_output, uint2(_735), 0u) * _153;
            _858.w = fast::clamp(1.0 - _858.w, 0.0, 1.0);
            int _863 = _855.x;
            bool _872;
            if (_863 >= cbFI.interpolationRectBase.x)
            {
                _872 = _863 >= (cbFI.interpolationRectSize.x + cbFI.interpolationRectBase.x);
            }
            else
            {
                _872 = true;
            }
            bool _879;
            if (!_872)
            {
                _879 = _855.y < cbFI.interpolationRectBase.y;
            }
            else
            {
                _879 = true;
            }
            bool _890;
            if (!_879)
            {
                _890 = _855.y >= (cbFI.interpolationRectSize.y + cbFI.interpolationRectBase.y);
            }
            else
            {
                _890 = true;
            }
            float4 _894;
            if (_890)
            {
                float4 _893 = _858;
                _893.w = 0.0;
                _894 = _893;
            }
            else
            {
                _894 = _858;
            }
            float4 _916;
            do
            {
                float _903 = ((_774.w + _814.w) + _854.w) + _894.w;
                if (_903 == 0.0)
                {
                    _916 = float4(0.0);
                    break;
                }
                _916 = ((((_774 * _774.w) + (_814 * _814.w)) + (_854 * _854.w)) + (_894 * _894.w)) / float4(_903);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid0, _916, uint2(uint2(_138 + int2(_343, _538))));
            if (cbInpaintingPyramid.mips <= 1u)
            {
                break;
            }
            float4 _922 = spvQuadSwap(_335, 0u);
            float4 _923 = spvQuadSwap(_335, 1u);
            float4 _924 = spvQuadSwap(_335, 2u);
            float4 _946;
            do
            {
                float _928 = _922.w;
                float _929 = _923.w;
                float _930 = _924.w;
                float _933 = ((_335.w + _928) + _929) + _930;
                if (_933 == 0.0)
                {
                    _946 = float4(0.0);
                    break;
                }
                _946 = ((((_335 * _335.w) + (_922 * _928)) + (_923 * _929)) + (_924 * _930)) / float4(_933);
                break;
            } while(false);
            float4 _947 = spvQuadSwap(_530, 0u);
            float4 _948 = spvQuadSwap(_530, 1u);
            float4 _949 = spvQuadSwap(_530, 2u);
            float4 _971;
            do
            {
                float _953 = _947.w;
                float _954 = _948.w;
                float _955 = _949.w;
                float _958 = ((_530.w + _953) + _954) + _955;
                if (_958 == 0.0)
                {
                    _971 = float4(0.0);
                    break;
                }
                _971 = ((((_530 * _530.w) + (_947 * _953)) + (_948 * _954)) + (_949 * _955)) / float4(_958);
                break;
            } while(false);
            float4 _972 = spvQuadSwap(_725, 0u);
            float4 _973 = spvQuadSwap(_725, 1u);
            float4 _974 = spvQuadSwap(_725, 2u);
            float4 _996;
            do
            {
                float _978 = _972.w;
                float _979 = _973.w;
                float _980 = _974.w;
                float _983 = ((_725.w + _978) + _979) + _980;
                if (_983 == 0.0)
                {
                    _996 = float4(0.0);
                    break;
                }
                _996 = ((((_725 * _725.w) + (_972 * _978)) + (_973 * _979)) + (_974 * _980)) / float4(_983);
                break;
            } while(false);
            float4 _997 = spvQuadSwap(_916, 0u);
            float4 _998 = spvQuadSwap(_916, 1u);
            float4 _999 = spvQuadSwap(_916, 2u);
            float4 _1021;
            do
            {
                float _1003 = _997.w;
                float _1004 = _998.w;
                float _1005 = _999.w;
                float _1008 = ((_916.w + _1003) + _1004) + _1005;
                if (_1008 == 0.0)
                {
                    _1021 = float4(0.0);
                    break;
                }
                _1021 = ((((_916 * _916.w) + (_997 * _1003)) + (_998 * _1004)) + (_999 * _1005)) / float4(_1008);
                break;
            } while(false);
            if ((gl_LocalInvocationIndex % 4u) == 0u)
            {
                int2 _1027 = int2(_107 * uint2(16u));
                uint _1028 = _123 / 2u;
                int _1029 = int(_1028);
                uint _1030 = _126 / 2u;
                int _1031 = int(_1030);
                sdk_hlsl_store(rw_inpainting_pyramid1, _946, uint2(uint2(_1027 + int2(_1029, _1031))));
                spdIntermediateR[_1028][_1030] = _946.x;
                spdIntermediateG[_1028][_1030] = _946.y;
                spdIntermediateB[_1028][_1030] = _946.z;
                spdIntermediateA[_1028][_1030] = _946.w;
                uint _1044 = _1028 + 8u;
                int _1045 = int(_1044);
                sdk_hlsl_store(rw_inpainting_pyramid1, _971, uint2(uint2(_1027 + int2(_1045, _1031))));
                spdIntermediateR[_1044][_1030] = _971.x;
                spdIntermediateG[_1044][_1030] = _971.y;
                spdIntermediateB[_1044][_1030] = _971.z;
                spdIntermediateA[_1044][_1030] = _971.w;
                uint _1058 = _1030 + 8u;
                int _1059 = int(_1058);
                sdk_hlsl_store(rw_inpainting_pyramid1, _996, uint2(uint2(_1027 + int2(_1029, _1059))));
                spdIntermediateR[_1028][_1058] = _996.x;
                spdIntermediateG[_1028][_1058] = _996.y;
                spdIntermediateB[_1028][_1058] = _996.z;
                spdIntermediateA[_1028][_1058] = _996.w;
                sdk_hlsl_store(rw_inpainting_pyramid1, _1021, uint2(uint2(_1027 + int2(_1045, _1059))));
                spdIntermediateR[_1044][_1058] = _1021.x;
                spdIntermediateG[_1044][_1058] = _1021.y;
                spdIntermediateB[_1044][_1058] = _1021.z;
                spdIntermediateA[_1044][_1058] = _1021.w;
            }
            break;
        } while(false);
        do
        {
            if (cbInpaintingPyramid.mips <= 2u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float4 _1097 = float4(spdIntermediateR[_123][_126], spdIntermediateG[_123][_126], spdIntermediateB[_123][_126], spdIntermediateA[_123][_126]);
            float4 _1098 = spvQuadSwap(_1097, 0u);
            float4 _1099 = spvQuadSwap(_1097, 1u);
            float4 _1100 = spvQuadSwap(_1097, 2u);
            float4 _1121;
            do
            {
                float _1103 = _1098.w;
                float _1104 = _1099.w;
                float _1105 = _1100.w;
                float _1108 = ((spdIntermediateA[_123][_126] + _1103) + _1104) + _1105;
                if (_1108 == 0.0)
                {
                    _1121 = float4(0.0);
                    break;
                }
                _1121 = ((((_1097 * spdIntermediateA[_123][_126]) + (_1098 * _1103)) + (_1099 * _1104)) + (_1100 * _1105)) / float4(_1108);
                break;
            } while(false);
            bool _1123 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_1123)
            {
                uint _1130 = _126 / 2u;
                sdk_hlsl_store(rw_inpainting_pyramid2, _1121, uint2(uint2(int2(_107 * uint2(8u)) + int2(int(_123 / 2u), int(_1130)))));
                uint _1137 = _123 + (_1130 % 2u);
                spdIntermediateR[_1137][_126] = _1121.x;
                spdIntermediateG[_1137][_126] = _1121.y;
                spdIntermediateB[_1137][_126] = _1121.z;
                spdIntermediateA[_1137][_126] = _1121.w;
            }
            if (cbInpaintingPyramid.mips <= 3u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _1153 = _131 + (_126 % 2u);
                float4 _1162 = float4(spdIntermediateR[_1153][_133], spdIntermediateG[_1153][_133], spdIntermediateB[_1153][_133], spdIntermediateA[_1153][_133]);
                float4 _1163 = spvQuadSwap(_1162, 0u);
                float4 _1164 = spvQuadSwap(_1162, 1u);
                float4 _1165 = spvQuadSwap(_1162, 2u);
                float4 _1186;
                do
                {
                    float _1168 = _1163.w;
                    float _1169 = _1164.w;
                    float _1170 = _1165.w;
                    float _1173 = ((spdIntermediateA[_1153][_133] + _1168) + _1169) + _1170;
                    if (_1173 == 0.0)
                    {
                        _1186 = float4(0.0);
                        break;
                    }
                    _1186 = ((((_1162 * spdIntermediateA[_1153][_133]) + (_1163 * _1168)) + (_1164 * _1169)) + (_1165 * _1170)) / float4(_1173);
                    break;
                } while(false);
                if (_1123)
                {
                    uint _1193 = _126 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid3, _1186, uint2(uint2(int2(_107 * uint2(4u)) + int2(int(_123 / 2u), int(_1193)))));
                    uint _1199 = _131 + _1193;
                    spdIntermediateR[_1199][_133] = _1186.x;
                    spdIntermediateG[_1199][_133] = _1186.y;
                    spdIntermediateB[_1199][_133] = _1186.z;
                    spdIntermediateA[_1199][_133] = _1186.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 4u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1215 = (_123 * 4u) + _126;
                uint _1216 = _126 * 4u;
                float4 _1225 = float4(spdIntermediateR[_1215][_1216], spdIntermediateG[_1215][_1216], spdIntermediateB[_1215][_1216], spdIntermediateA[_1215][_1216]);
                float4 _1226 = spvQuadSwap(_1225, 0u);
                float4 _1227 = spvQuadSwap(_1225, 1u);
                float4 _1228 = spvQuadSwap(_1225, 2u);
                float4 _1249;
                do
                {
                    float _1231 = _1226.w;
                    float _1232 = _1227.w;
                    float _1233 = _1228.w;
                    float _1236 = ((spdIntermediateA[_1215][_1216] + _1231) + _1232) + _1233;
                    if (_1236 == 0.0)
                    {
                        _1249 = float4(0.0);
                        break;
                    }
                    _1249 = ((((_1225 * spdIntermediateA[_1215][_1216]) + (_1226 * _1231)) + (_1227 * _1232)) + (_1228 * _1233)) / float4(_1236);
                    break;
                } while(false);
                if (_1123)
                {
                    uint _1254 = _123 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid4, _1249, uint2(uint2(int2(_107 * uint2(2u)) + int2(int(_1254), int(_126 / 2u)))));
                    uint _1262 = _1254 + _126;
                    spdIntermediateR[_1262][0u] = _1249.x;
                    spdIntermediateG[_1262][0u] = _1249.y;
                    spdIntermediateB[_1262][0u] = _1249.z;
                    spdIntermediateA[_1262][0u] = _1249.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 5u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1285 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1286 = spvQuadSwap(_1285, 0u);
                float4 _1287 = spvQuadSwap(_1285, 1u);
                float4 _1288 = spvQuadSwap(_1285, 2u);
                float4 _1309;
                do
                {
                    float _1291 = _1286.w;
                    float _1292 = _1287.w;
                    float _1293 = _1288.w;
                    float _1296 = ((spdIntermediateA[gl_LocalInvocationIndex][0u] + _1291) + _1292) + _1293;
                    if (_1296 == 0.0)
                    {
                        _1309 = float4(0.0);
                        break;
                    }
                    _1309 = ((((_1285 * spdIntermediateA[gl_LocalInvocationIndex][0u]) + (_1286 * _1291)) + (_1287 * _1292)) + (_1288 * _1293)) / float4(_1296);
                    break;
                } while(false);
                if (_1123)
                {
                    sdk_hlsl_store(rw_inpainting_pyramid5, _1309, uint2(_107));
                }
            }
            break;
        } while(false);
        if (cbInpaintingPyramid.mips <= 6u)
        {
            break;
        }
        if (gl_LocalInvocationIndex == 0u)
        {
            uint _1320 = atomic_fetch_add_explicit((volatile device atomic_uint*)&rw_counters._m0[0u], 1u, memory_order_relaxed);
            spdCounter = _1320;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (spdCounter != (cbInpaintingPyramid.numWorkGroups - 1u))
        {
            break;
        }
        uint _1329;
        uint _1331;
        rw_counters._m0[0u] = 0u;
        do
        {
            _1329 = _123 * 4u;
            int _1330 = int(_1329);
            _1331 = _126 * 4u;
            int _1332 = int(_1331);
            uint2 _1334 = uint2(int2(_1330, _1332));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1339 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1334));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1341 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1334 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1343 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1334 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1345 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1334 + uint2(1u))));
            float4 _1367;
            do
            {
                float _1348 = _1339.w;
                float _1349 = _1341.w;
                float _1350 = _1343.w;
                float _1351 = _1345.w;
                float _1354 = ((_1348 + _1349) + _1350) + _1351;
                if (_1354 == 0.0)
                {
                    _1367 = float4(0.0);
                    break;
                }
                _1367 = ((((_1339 * _1348) + (_1341 * _1349)) + (_1343 * _1350)) + (_1345 * _1351)) / float4(_1354);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1367, uint2(uint2(_135)));
            int _1371 = int(_1329 + 2u);
            int _1374 = int(_131 + 1u);
            uint2 _1376 = uint2(int2(_1371, _1332));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1381 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1376));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1383 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1376 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1385 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1376 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1387 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1376 + uint2(1u))));
            float4 _1409;
            do
            {
                float _1390 = _1381.w;
                float _1391 = _1383.w;
                float _1392 = _1385.w;
                float _1393 = _1387.w;
                float _1396 = ((_1390 + _1391) + _1392) + _1393;
                if (_1396 == 0.0)
                {
                    _1409 = float4(0.0);
                    break;
                }
                _1409 = ((((_1381 * _1390) + (_1383 * _1391)) + (_1385 * _1392)) + (_1387 * _1393)) / float4(_1396);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1409, uint2(uint2(int2(_1374, _134))));
            int _1413 = int(_1331 + 2u);
            int _1416 = int(_133 + 1u);
            uint2 _1418 = uint2(int2(_1330, _1413));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1423 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1418));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1425 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1418 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1427 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1418 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1429 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1418 + uint2(1u))));
            float4 _1451;
            do
            {
                float _1432 = _1423.w;
                float _1433 = _1425.w;
                float _1434 = _1427.w;
                float _1435 = _1429.w;
                float _1438 = ((_1432 + _1433) + _1434) + _1435;
                if (_1438 == 0.0)
                {
                    _1451 = float4(0.0);
                    break;
                }
                _1451 = ((((_1423 * _1432) + (_1425 * _1433)) + (_1427 * _1434)) + (_1429 * _1435)) / float4(_1438);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1451, uint2(uint2(int2(_132, _1416))));
            uint2 _1456 = uint2(int2(_1371, _1413));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1461 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2(_1456));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1463 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1456 + uint2(0u, 1u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1465 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1456 + uint2(1u, 0u))));
            spvImageFence(rw_inpainting_pyramid5);
            float4 _1467 = sdk_hlsl_load(rw_inpainting_pyramid5, uint2((_1456 + uint2(1u))));
            float4 _1489;
            do
            {
                float _1470 = _1461.w;
                float _1471 = _1463.w;
                float _1472 = _1465.w;
                float _1473 = _1467.w;
                float _1476 = ((_1470 + _1471) + _1472) + _1473;
                if (_1476 == 0.0)
                {
                    _1489 = float4(0.0);
                    break;
                }
                _1489 = ((((_1461 * _1470) + (_1463 * _1471)) + (_1465 * _1472)) + (_1467 * _1473)) / float4(_1476);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid6, _1489, uint2(uint2(int2(_1374, _1416))));
            if (cbInpaintingPyramid.mips <= 7u)
            {
                break;
            }
            float4 _1516;
            do
            {
                float _1503 = ((_1367.w + _1409.w) + _1451.w) + _1489.w;
                if (_1503 == 0.0)
                {
                    _1516 = float4(0.0);
                    break;
                }
                _1516 = ((((_1367 * _1367.w) + (_1409 * _1409.w)) + (_1451 * _1451.w)) + (_1489 * _1489.w)) / float4(_1503);
                break;
            } while(false);
            sdk_hlsl_store(rw_inpainting_pyramid7, _1516, uint2(uint2(_141)));
            spdIntermediateR[_123][_126] = _1516.x;
            spdIntermediateG[_123][_126] = _1516.y;
            spdIntermediateB[_123][_126] = _1516.z;
            spdIntermediateA[_123][_126] = _1516.w;
            break;
        } while(false);
        do
        {
            if (cbInpaintingPyramid.mips <= 8u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float4 _1540 = float4(spdIntermediateR[_123][_126], spdIntermediateG[_123][_126], spdIntermediateB[_123][_126], spdIntermediateA[_123][_126]);
            float4 _1541 = spvQuadSwap(_1540, 0u);
            float4 _1542 = spvQuadSwap(_1540, 1u);
            float4 _1543 = spvQuadSwap(_1540, 2u);
            float4 _1564;
            do
            {
                float _1546 = _1541.w;
                float _1547 = _1542.w;
                float _1548 = _1543.w;
                float _1551 = ((spdIntermediateA[_123][_126] + _1546) + _1547) + _1548;
                if (_1551 == 0.0)
                {
                    _1564 = float4(0.0);
                    break;
                }
                _1564 = ((((_1540 * spdIntermediateA[_123][_126]) + (_1541 * _1546)) + (_1542 * _1547)) + (_1543 * _1548)) / float4(_1551);
                break;
            } while(false);
            bool _1566 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_1566)
            {
                uint _1571 = _126 / 2u;
                sdk_hlsl_store(rw_inpainting_pyramid8, _1564, uint2(uint2(int2(int(_123 / 2u), int(_1571)))));
                uint _1577 = _123 + (_1571 % 2u);
                spdIntermediateR[_1577][_126] = _1564.x;
                spdIntermediateG[_1577][_126] = _1564.y;
                spdIntermediateB[_1577][_126] = _1564.z;
                spdIntermediateA[_1577][_126] = _1564.w;
            }
            if (cbInpaintingPyramid.mips <= 9u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _1593 = _131 + (_126 % 2u);
                float4 _1602 = float4(spdIntermediateR[_1593][_133], spdIntermediateG[_1593][_133], spdIntermediateB[_1593][_133], spdIntermediateA[_1593][_133]);
                float4 _1603 = spvQuadSwap(_1602, 0u);
                float4 _1604 = spvQuadSwap(_1602, 1u);
                float4 _1605 = spvQuadSwap(_1602, 2u);
                float4 _1626;
                do
                {
                    float _1608 = _1603.w;
                    float _1609 = _1604.w;
                    float _1610 = _1605.w;
                    float _1613 = ((spdIntermediateA[_1593][_133] + _1608) + _1609) + _1610;
                    if (_1613 == 0.0)
                    {
                        _1626 = float4(0.0);
                        break;
                    }
                    _1626 = ((((_1602 * spdIntermediateA[_1593][_133]) + (_1603 * _1608)) + (_1604 * _1609)) + (_1605 * _1610)) / float4(_1613);
                    break;
                } while(false);
                if (_1566)
                {
                    uint _1631 = _126 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid9, _1626, uint2(uint2(int2(int(_123 / 2u), int(_1631)))));
                    uint _1636 = _131 + _1631;
                    spdIntermediateR[_1636][_133] = _1626.x;
                    spdIntermediateG[_1636][_133] = _1626.y;
                    spdIntermediateB[_1636][_133] = _1626.z;
                    spdIntermediateA[_1636][_133] = _1626.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 10u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _1651 = _1329 + _126;
                float4 _1660 = float4(spdIntermediateR[_1651][_1331], spdIntermediateG[_1651][_1331], spdIntermediateB[_1651][_1331], spdIntermediateA[_1651][_1331]);
                float4 _1661 = spvQuadSwap(_1660, 0u);
                float4 _1662 = spvQuadSwap(_1660, 1u);
                float4 _1663 = spvQuadSwap(_1660, 2u);
                float4 _1684;
                do
                {
                    float _1666 = _1661.w;
                    float _1667 = _1662.w;
                    float _1668 = _1663.w;
                    float _1671 = ((spdIntermediateA[_1651][_1331] + _1666) + _1667) + _1668;
                    if (_1671 == 0.0)
                    {
                        _1684 = float4(0.0);
                        break;
                    }
                    _1684 = ((((_1660 * spdIntermediateA[_1651][_1331]) + (_1661 * _1666)) + (_1662 * _1667)) + (_1663 * _1668)) / float4(_1671);
                    break;
                } while(false);
                if (_1566)
                {
                    uint _1687 = _123 / 2u;
                    sdk_hlsl_store(rw_inpainting_pyramid10, _1684, uint2(uint2(int2(int(_1687), int(_126 / 2u)))));
                    uint _1694 = _1687 + _126;
                    spdIntermediateR[_1694][0u] = _1684.x;
                    spdIntermediateG[_1694][0u] = _1684.y;
                    spdIntermediateB[_1694][0u] = _1684.z;
                    spdIntermediateA[_1694][0u] = _1684.w;
                }
            }
            if (cbInpaintingPyramid.mips <= 11u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _1717 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _1718 = spvQuadSwap(_1717, 0u);
                float4 _1719 = spvQuadSwap(_1717, 1u);
                float4 _1720 = spvQuadSwap(_1717, 2u);
                float4 _1741;
                do
                {
                    float _1723 = _1718.w;
                    float _1724 = _1719.w;
                    float _1725 = _1720.w;
                    float _1728 = ((spdIntermediateA[gl_LocalInvocationIndex][0u] + _1723) + _1724) + _1725;
                    if (_1728 == 0.0)
                    {
                        _1741 = float4(0.0);
                        break;
                    }
                    _1741 = ((((_1717 * spdIntermediateA[gl_LocalInvocationIndex][0u]) + (_1718 * _1723)) + (_1719 * _1724)) + (_1720 * _1725)) / float4(_1728);
                    break;
                } while(false);
                if (_1566)
                {
                    sdk_hlsl_store(rw_inpainting_pyramid11, _1741, uint2(uint2(0u)));
                }
            }
            break;
        } while(false);
        break;
    } while(false);
}

