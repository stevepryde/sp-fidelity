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

constant spvUnsafeArray<int2, 5> _113 = spvUnsafeArray<int2, 5>({ int2(0), int2(-1, 0), int2(1, 0), int2(0, -1), int2(0, 1) });

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], constant type_cbSPD& cbSPD [[buffer(1)]], texture2d<float> r_current_luma [[texture(0)]], texture2d<float> r_previous_luma [[texture(1)]], texture2d<float> r_dilated_motion_vectors [[texture(2)]], texture2d<float> r_input_exposure [[texture(3)]], texture2d<float, access::write> rw_spd_mip0 [[texture(4)]], texture2d<float, access::write> rw_spd_mip1 [[texture(5)]], texture2d<float, access::write> rw_spd_mip2 [[texture(6)]], texture2d<float, access::write> rw_spd_mip3 [[texture(7)]], texture2d<float, access::write> rw_spd_mip4 [[texture(8)]], texture2d<float, access::read_write> rw_spd_mip5 [[texture(9)]], texture2d<uint, access::read_write> rw_spd_global_atomic [[texture(10)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]])
{
    threadgroup uint spdCounter;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateR;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateG;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateB;
    threadgroup spvUnsafeArray<spvUnsafeArray<float, 16>, 16> spdIntermediateA;
    uint2 _191 = gl_WorkGroupID.xy + cbSPD.workGroupOffset;
    do
    {
        uint _215;
        uint _217;
        uint _194 = gl_LocalInvocationIndex % 64u;
        uint _207 = ((_194 & 1u) | ((_194 >> 2u) & 6u)) + (8u * ((gl_LocalInvocationIndex >> 6u) % 2u));
        uint _210 = (((_194 >> 1u) & 3u) | ((_194 >> 3u) & 4u)) + (8u * (gl_LocalInvocationIndex >> 7u));
        do
        {
            int2 _214 = int2(_191 * uint2(64u));
            _215 = _207 * 2u;
            int _216 = int(_215);
            _217 = _210 * 2u;
            int _218 = int(_217);
            int2 _220 = _214 + int2(_216, _218);
            int2 _222 = int2(_191 * uint2(32u));
            int _223 = int(_207);
            int _224 = int(_210);
            uint2 _227 = uint2(_220);
            int2 _232 = int2(float2(_220));
            int _237 = cbFSR3Upscaler.iRenderSize.x - 1;
            int _242 = cbFSR3Upscaler.iRenderSize.y - 1;
            int2 _245 = int2(max(0, min(_232.x, _237)), max(0, min(_232.y, _242)));
            float2 _252 = float2(cbFSR3Upscaler.iRenderSize);
            float2 _253 = (float2(_245) + float2(0.5)) / _252;
            float2 _256 = cbFSR3Upscaler.fJitter / _252;
            int2 _260 = int2(floor((_253 + _256) * _252));
            spvUnsafeArray<float, 5> _136;
            for (int _262 = 0; _262 < 5; )
            {
                int2 _269 = _260 + _113[_262];
                float4 _282 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _283 = _282.x;
                _136[_262] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_269.x, _237)), max(0, min(_269.y, _242))))), 0u).x * ((_283 == 0.0) ? 1.0 : _283);
                _136[_262] = powr(_136[_262], 1.0);
                _136[_262] = precise::max(_136[_262], 6.099999882280826568603515625e-05);
                _262++;
                continue;
            }
            float2 _297 = float2(cbFSR3Upscaler.iPreviousFrameRenderSize);
            float2 _298 = cbFSR3Upscaler.fPreviousFrameJitter / _297;
            float2 _300 = (_253 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_245)), 0u).xy;
            float _301 = _300.x;
            bool _306;
            if (_301 >= 0.0)
            {
                _306 = _301 <= 1.0;
            }
            else
            {
                _306 = false;
            }
            bool _315;
            if (_306)
            {
                float _309 = _300.y;
                bool _314;
                if (_309 >= 0.0)
                {
                    _314 = _309 <= 1.0;
                }
                else
                {
                    _314 = false;
                }
                _315 = _314;
            }
            else
            {
                _315 = false;
            }
            spvUnsafeArray<float, 5> _118;
            if (_315)
            {
                int2 _320 = int2(floor(_300 * _297));
                for (int _322 = 0; _322 < 5; )
                {
                    int2 _329 = _320 + _113[_322];
                    float4 _349 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _350 = _349.x;
                    _118[_322] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_329.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_329.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_350 == 0.0) ? 1.0 : _350);
                    _118[_322] = powr(_118[_322], 1.0);
                    _118[_322] = precise::max(_118[_322], 6.099999882280826568603515625e-05);
                    _322++;
                    continue;
                }
            }
            float _548;
            if (_315)
            {
                spvUnsafeArray<float, 5> _135 = _136;
                spvUnsafeArray<float, 5> _134 = _118;
                float _363 = _135[0];
                float _365 = _135[3];
                _135[3] = precise::max(_135[0], _135[3]);
                _135[0] = precise::min(_363, _365);
                float _371 = _135[1];
                float _373 = _135[4];
                _135[4] = precise::max(_135[1], _135[4]);
                _135[1] = precise::min(_371, _373);
                float _378 = _135[0];
                float _380 = _135[2];
                _135[2] = precise::max(_135[0], _135[2]);
                _135[0] = precise::min(_378, _380);
                float _385 = _135[1];
                float _386 = _135[3];
                _135[3] = precise::max(_135[1], _135[3]);
                _135[1] = precise::min(_385, _386);
                float _391 = _135[0];
                float _392 = _135[1];
                _135[1] = precise::max(_135[0], _135[1]);
                _135[0] = precise::min(_391, _392);
                float _397 = _135[2];
                float _398 = _135[4];
                _135[4] = precise::max(_135[2], _135[4]);
                _135[2] = precise::min(_397, _398);
                float _403 = _135[1];
                float _404 = _135[2];
                _135[2] = precise::max(_135[1], _135[2]);
                _135[1] = precise::min(_403, _404);
                float _409 = _135[3];
                float _410 = _135[4];
                _135[4] = precise::max(_135[3], _135[4]);
                _135[3] = precise::min(_409, _410);
                float _415 = _135[2];
                float _416 = _135[3];
                _135[3] = precise::max(_135[2], _135[3]);
                _135[2] = precise::min(_415, _416);
                float _422 = _134[0];
                float _424 = _134[3];
                _134[3] = precise::max(_134[0], _134[3]);
                _134[0] = precise::min(_422, _424);
                float _430 = _134[1];
                float _432 = _134[4];
                _134[4] = precise::max(_134[1], _134[4]);
                _134[1] = precise::min(_430, _432);
                float _437 = _134[0];
                float _439 = _134[2];
                _134[2] = precise::max(_134[0], _134[2]);
                _134[0] = precise::min(_437, _439);
                float _444 = _134[1];
                float _445 = _134[3];
                _134[3] = precise::max(_134[1], _134[3]);
                _134[1] = precise::min(_444, _445);
                float _450 = _134[0];
                float _451 = _134[1];
                _134[1] = precise::max(_134[0], _134[1]);
                _134[0] = precise::min(_450, _451);
                float _456 = _134[2];
                float _457 = _134[4];
                _134[4] = precise::max(_134[2], _134[4]);
                _134[2] = precise::min(_456, _457);
                float _462 = _134[1];
                float _463 = _134[2];
                _134[2] = precise::max(_134[1], _134[2]);
                _134[1] = precise::min(_462, _463);
                float _468 = _134[3];
                float _469 = _134[4];
                _134[4] = precise::max(_134[3], _134[4]);
                _134[3] = precise::min(_468, _469);
                float _474 = _134[2];
                float _475 = _134[3];
                _134[3] = precise::max(_134[2], _134[3]);
                _134[2] = precise::min(_474, _475);
                float _544;
                if (precise::min(_135[4], _134[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _492;
                    _492 = 65503.0;
                    int _488;
                    int _491;
                    float _493;
                    int _487 = 0;
                    int _490 = 0;
                    int _494 = 0;
                    for (;;)
                    {
                        bool _502;
                        if (_494 < 5)
                        {
                            _502 = _492 < 65504.0;
                        }
                        else
                        {
                            _502 = false;
                        }
                        if (_502)
                        {
                            float _508 = _135[_490] - _134[_487];
                            if (abs(_508) > 6.099999882280826568603515625e-05)
                            {
                                float _519 = precise::max(_135[_490], _134[_487]);
                                float _526;
                                if (_519 != 0.0)
                                {
                                    _526 = precise::min(_135[_490], _134[_487]) / _519;
                                }
                                else
                                {
                                    _526 = 0.0;
                                }
                                float _528 = float(int(sign(_508))) * (1.0 - _526);
                                int _537 = _490 + int(_135[_490] < _134[_487]);
                                _488 = _487 + int(_135[_537] >= _134[_487]);
                                _491 = _537;
                                _493 = (abs(_528) < abs(_492)) ? _528 : _492;
                            }
                            else
                            {
                                _488 = _487;
                                _491 = _490;
                                _493 = 65504.0;
                            }
                            _487 = _488;
                            _490 = _491;
                            _492 = _493;
                            _494++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _544 = _492;
                }
                else
                {
                    _544 = 65503.0;
                }
                _548 = _544 * float(_544 < 65503.0);
            }
            else
            {
                _548 = 0.0;
            }
            float4 _549 = float4(0.0);
            _549.x = _548;
            float _557;
            if (_548 != 0.0)
            {
                _557 = float(int(sign(_548)));
            }
            else
            {
                _557 = 0.0;
            }
            _549.y = _557;
            _549.z = 1.0;
            int2 _562 = int2(float2(int2(_227 + uint2(0u, 1u))));
            int2 _569 = int2(max(0, min(_562.x, _237)), max(0, min(_562.y, _242)));
            float2 _576 = (float2(_569) + float2(0.5)) / _252;
            int2 _580 = int2(floor((_576 + _256) * _252));
            spvUnsafeArray<float, 5> _139;
            for (int _582 = 0; _582 < 5; )
            {
                int2 _589 = _580 + _113[_582];
                float4 _602 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _603 = _602.x;
                _139[_582] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_589.x, _237)), max(0, min(_589.y, _242))))), 0u).x * ((_603 == 0.0) ? 1.0 : _603);
                _139[_582] = powr(_139[_582], 1.0);
                _139[_582] = precise::max(_139[_582], 6.099999882280826568603515625e-05);
                _582++;
                continue;
            }
            float2 _614 = (_576 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_569)), 0u).xy;
            float _615 = _614.x;
            bool _620;
            if (_615 >= 0.0)
            {
                _620 = _615 <= 1.0;
            }
            else
            {
                _620 = false;
            }
            bool _629;
            if (_620)
            {
                float _623 = _614.y;
                bool _628;
                if (_623 >= 0.0)
                {
                    _628 = _623 <= 1.0;
                }
                else
                {
                    _628 = false;
                }
                _629 = _628;
            }
            else
            {
                _629 = false;
            }
            spvUnsafeArray<float, 5> _119;
            if (_629)
            {
                int2 _634 = int2(floor(_614 * _297));
                for (int _636 = 0; _636 < 5; )
                {
                    int2 _643 = _634 + _113[_636];
                    float4 _663 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _664 = _663.x;
                    _119[_636] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_643.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_643.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_664 == 0.0) ? 1.0 : _664);
                    _119[_636] = powr(_119[_636], 1.0);
                    _119[_636] = precise::max(_119[_636], 6.099999882280826568603515625e-05);
                    _636++;
                    continue;
                }
            }
            float _862;
            if (_629)
            {
                spvUnsafeArray<float, 5> _138 = _139;
                spvUnsafeArray<float, 5> _137 = _119;
                float _677 = _138[0];
                float _679 = _138[3];
                _138[3] = precise::max(_138[0], _138[3]);
                _138[0] = precise::min(_677, _679);
                float _685 = _138[1];
                float _687 = _138[4];
                _138[4] = precise::max(_138[1], _138[4]);
                _138[1] = precise::min(_685, _687);
                float _692 = _138[0];
                float _694 = _138[2];
                _138[2] = precise::max(_138[0], _138[2]);
                _138[0] = precise::min(_692, _694);
                float _699 = _138[1];
                float _700 = _138[3];
                _138[3] = precise::max(_138[1], _138[3]);
                _138[1] = precise::min(_699, _700);
                float _705 = _138[0];
                float _706 = _138[1];
                _138[1] = precise::max(_138[0], _138[1]);
                _138[0] = precise::min(_705, _706);
                float _711 = _138[2];
                float _712 = _138[4];
                _138[4] = precise::max(_138[2], _138[4]);
                _138[2] = precise::min(_711, _712);
                float _717 = _138[1];
                float _718 = _138[2];
                _138[2] = precise::max(_138[1], _138[2]);
                _138[1] = precise::min(_717, _718);
                float _723 = _138[3];
                float _724 = _138[4];
                _138[4] = precise::max(_138[3], _138[4]);
                _138[3] = precise::min(_723, _724);
                float _729 = _138[2];
                float _730 = _138[3];
                _138[3] = precise::max(_138[2], _138[3]);
                _138[2] = precise::min(_729, _730);
                float _736 = _137[0];
                float _738 = _137[3];
                _137[3] = precise::max(_137[0], _137[3]);
                _137[0] = precise::min(_736, _738);
                float _744 = _137[1];
                float _746 = _137[4];
                _137[4] = precise::max(_137[1], _137[4]);
                _137[1] = precise::min(_744, _746);
                float _751 = _137[0];
                float _753 = _137[2];
                _137[2] = precise::max(_137[0], _137[2]);
                _137[0] = precise::min(_751, _753);
                float _758 = _137[1];
                float _759 = _137[3];
                _137[3] = precise::max(_137[1], _137[3]);
                _137[1] = precise::min(_758, _759);
                float _764 = _137[0];
                float _765 = _137[1];
                _137[1] = precise::max(_137[0], _137[1]);
                _137[0] = precise::min(_764, _765);
                float _770 = _137[2];
                float _771 = _137[4];
                _137[4] = precise::max(_137[2], _137[4]);
                _137[2] = precise::min(_770, _771);
                float _776 = _137[1];
                float _777 = _137[2];
                _137[2] = precise::max(_137[1], _137[2]);
                _137[1] = precise::min(_776, _777);
                float _782 = _137[3];
                float _783 = _137[4];
                _137[4] = precise::max(_137[3], _137[4]);
                _137[3] = precise::min(_782, _783);
                float _788 = _137[2];
                float _789 = _137[3];
                _137[3] = precise::max(_137[2], _137[3]);
                _137[2] = precise::min(_788, _789);
                float _858;
                if (precise::min(_138[4], _137[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _806;
                    _806 = 65503.0;
                    int _802;
                    int _805;
                    float _807;
                    int _801 = 0;
                    int _804 = 0;
                    int _808 = 0;
                    for (;;)
                    {
                        bool _816;
                        if (_808 < 5)
                        {
                            _816 = _806 < 65504.0;
                        }
                        else
                        {
                            _816 = false;
                        }
                        if (_816)
                        {
                            float _822 = _138[_804] - _137[_801];
                            if (abs(_822) > 6.099999882280826568603515625e-05)
                            {
                                float _833 = precise::max(_138[_804], _137[_801]);
                                float _840;
                                if (_833 != 0.0)
                                {
                                    _840 = precise::min(_138[_804], _137[_801]) / _833;
                                }
                                else
                                {
                                    _840 = 0.0;
                                }
                                float _842 = float(int(sign(_822))) * (1.0 - _840);
                                int _851 = _804 + int(_138[_804] < _137[_801]);
                                _802 = _801 + int(_138[_851] >= _137[_801]);
                                _805 = _851;
                                _807 = (abs(_842) < abs(_806)) ? _842 : _806;
                            }
                            else
                            {
                                _802 = _801;
                                _805 = _804;
                                _807 = 65504.0;
                            }
                            _801 = _802;
                            _804 = _805;
                            _806 = _807;
                            _808++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _858 = _806;
                }
                else
                {
                    _858 = 65503.0;
                }
                _862 = _858 * float(_858 < 65503.0);
            }
            else
            {
                _862 = 0.0;
            }
            float4 _863 = float4(0.0);
            _863.x = _862;
            float _871;
            if (_862 != 0.0)
            {
                _871 = float(int(sign(_862)));
            }
            else
            {
                _871 = 0.0;
            }
            _863.y = _871;
            _863.z = 1.0;
            int2 _876 = int2(float2(int2(_227 + uint2(1u, 0u))));
            int2 _883 = int2(max(0, min(_876.x, _237)), max(0, min(_876.y, _242)));
            float2 _890 = (float2(_883) + float2(0.5)) / _252;
            int2 _894 = int2(floor((_890 + _256) * _252));
            spvUnsafeArray<float, 5> _142;
            for (int _896 = 0; _896 < 5; )
            {
                int2 _903 = _894 + _113[_896];
                float4 _916 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _917 = _916.x;
                _142[_896] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_903.x, _237)), max(0, min(_903.y, _242))))), 0u).x * ((_917 == 0.0) ? 1.0 : _917);
                _142[_896] = powr(_142[_896], 1.0);
                _142[_896] = precise::max(_142[_896], 6.099999882280826568603515625e-05);
                _896++;
                continue;
            }
            float2 _928 = (_890 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_883)), 0u).xy;
            float _929 = _928.x;
            bool _934;
            if (_929 >= 0.0)
            {
                _934 = _929 <= 1.0;
            }
            else
            {
                _934 = false;
            }
            bool _943;
            if (_934)
            {
                float _937 = _928.y;
                bool _942;
                if (_937 >= 0.0)
                {
                    _942 = _937 <= 1.0;
                }
                else
                {
                    _942 = false;
                }
                _943 = _942;
            }
            else
            {
                _943 = false;
            }
            spvUnsafeArray<float, 5> _120;
            if (_943)
            {
                int2 _948 = int2(floor(_928 * _297));
                for (int _950 = 0; _950 < 5; )
                {
                    int2 _957 = _948 + _113[_950];
                    float4 _977 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _978 = _977.x;
                    _120[_950] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_957.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_957.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_978 == 0.0) ? 1.0 : _978);
                    _120[_950] = powr(_120[_950], 1.0);
                    _120[_950] = precise::max(_120[_950], 6.099999882280826568603515625e-05);
                    _950++;
                    continue;
                }
            }
            float _1176;
            if (_943)
            {
                spvUnsafeArray<float, 5> _141 = _142;
                spvUnsafeArray<float, 5> _140 = _120;
                float _991 = _141[0];
                float _993 = _141[3];
                _141[3] = precise::max(_141[0], _141[3]);
                _141[0] = precise::min(_991, _993);
                float _999 = _141[1];
                float _1001 = _141[4];
                _141[4] = precise::max(_141[1], _141[4]);
                _141[1] = precise::min(_999, _1001);
                float _1006 = _141[0];
                float _1008 = _141[2];
                _141[2] = precise::max(_141[0], _141[2]);
                _141[0] = precise::min(_1006, _1008);
                float _1013 = _141[1];
                float _1014 = _141[3];
                _141[3] = precise::max(_141[1], _141[3]);
                _141[1] = precise::min(_1013, _1014);
                float _1019 = _141[0];
                float _1020 = _141[1];
                _141[1] = precise::max(_141[0], _141[1]);
                _141[0] = precise::min(_1019, _1020);
                float _1025 = _141[2];
                float _1026 = _141[4];
                _141[4] = precise::max(_141[2], _141[4]);
                _141[2] = precise::min(_1025, _1026);
                float _1031 = _141[1];
                float _1032 = _141[2];
                _141[2] = precise::max(_141[1], _141[2]);
                _141[1] = precise::min(_1031, _1032);
                float _1037 = _141[3];
                float _1038 = _141[4];
                _141[4] = precise::max(_141[3], _141[4]);
                _141[3] = precise::min(_1037, _1038);
                float _1043 = _141[2];
                float _1044 = _141[3];
                _141[3] = precise::max(_141[2], _141[3]);
                _141[2] = precise::min(_1043, _1044);
                float _1050 = _140[0];
                float _1052 = _140[3];
                _140[3] = precise::max(_140[0], _140[3]);
                _140[0] = precise::min(_1050, _1052);
                float _1058 = _140[1];
                float _1060 = _140[4];
                _140[4] = precise::max(_140[1], _140[4]);
                _140[1] = precise::min(_1058, _1060);
                float _1065 = _140[0];
                float _1067 = _140[2];
                _140[2] = precise::max(_140[0], _140[2]);
                _140[0] = precise::min(_1065, _1067);
                float _1072 = _140[1];
                float _1073 = _140[3];
                _140[3] = precise::max(_140[1], _140[3]);
                _140[1] = precise::min(_1072, _1073);
                float _1078 = _140[0];
                float _1079 = _140[1];
                _140[1] = precise::max(_140[0], _140[1]);
                _140[0] = precise::min(_1078, _1079);
                float _1084 = _140[2];
                float _1085 = _140[4];
                _140[4] = precise::max(_140[2], _140[4]);
                _140[2] = precise::min(_1084, _1085);
                float _1090 = _140[1];
                float _1091 = _140[2];
                _140[2] = precise::max(_140[1], _140[2]);
                _140[1] = precise::min(_1090, _1091);
                float _1096 = _140[3];
                float _1097 = _140[4];
                _140[4] = precise::max(_140[3], _140[4]);
                _140[3] = precise::min(_1096, _1097);
                float _1102 = _140[2];
                float _1103 = _140[3];
                _140[3] = precise::max(_140[2], _140[3]);
                _140[2] = precise::min(_1102, _1103);
                float _1172;
                if (precise::min(_141[4], _140[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _1120;
                    _1120 = 65503.0;
                    int _1116;
                    int _1119;
                    float _1121;
                    int _1115 = 0;
                    int _1118 = 0;
                    int _1122 = 0;
                    for (;;)
                    {
                        bool _1130;
                        if (_1122 < 5)
                        {
                            _1130 = _1120 < 65504.0;
                        }
                        else
                        {
                            _1130 = false;
                        }
                        if (_1130)
                        {
                            float _1136 = _141[_1118] - _140[_1115];
                            if (abs(_1136) > 6.099999882280826568603515625e-05)
                            {
                                float _1147 = precise::max(_141[_1118], _140[_1115]);
                                float _1154;
                                if (_1147 != 0.0)
                                {
                                    _1154 = precise::min(_141[_1118], _140[_1115]) / _1147;
                                }
                                else
                                {
                                    _1154 = 0.0;
                                }
                                float _1156 = float(int(sign(_1136))) * (1.0 - _1154);
                                int _1165 = _1118 + int(_141[_1118] < _140[_1115]);
                                _1116 = _1115 + int(_141[_1165] >= _140[_1115]);
                                _1119 = _1165;
                                _1121 = (abs(_1156) < abs(_1120)) ? _1156 : _1120;
                            }
                            else
                            {
                                _1116 = _1115;
                                _1119 = _1118;
                                _1121 = 65504.0;
                            }
                            _1115 = _1116;
                            _1118 = _1119;
                            _1120 = _1121;
                            _1122++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _1172 = _1120;
                }
                else
                {
                    _1172 = 65503.0;
                }
                _1176 = _1172 * float(_1172 < 65503.0);
            }
            else
            {
                _1176 = 0.0;
            }
            float4 _1177 = float4(0.0);
            _1177.x = _1176;
            float _1185;
            if (_1176 != 0.0)
            {
                _1185 = float(int(sign(_1176)));
            }
            else
            {
                _1185 = 0.0;
            }
            _1177.y = _1185;
            _1177.z = 1.0;
            int2 _1190 = int2(float2(int2(_227 + uint2(1u))));
            int2 _1197 = int2(max(0, min(_1190.x, _237)), max(0, min(_1190.y, _242)));
            float2 _1204 = (float2(_1197) + float2(0.5)) / _252;
            int2 _1208 = int2(floor((_1204 + _256) * _252));
            spvUnsafeArray<float, 5> _145;
            for (int _1210 = 0; _1210 < 5; )
            {
                int2 _1217 = _1208 + _113[_1210];
                float4 _1230 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _1231 = _1230.x;
                _145[_1210] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_1217.x, _237)), max(0, min(_1217.y, _242))))), 0u).x * ((_1231 == 0.0) ? 1.0 : _1231);
                _145[_1210] = powr(_145[_1210], 1.0);
                _145[_1210] = precise::max(_145[_1210], 6.099999882280826568603515625e-05);
                _1210++;
                continue;
            }
            float2 _1242 = (_1204 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_1197)), 0u).xy;
            float _1243 = _1242.x;
            bool _1248;
            if (_1243 >= 0.0)
            {
                _1248 = _1243 <= 1.0;
            }
            else
            {
                _1248 = false;
            }
            bool _1257;
            if (_1248)
            {
                float _1251 = _1242.y;
                bool _1256;
                if (_1251 >= 0.0)
                {
                    _1256 = _1251 <= 1.0;
                }
                else
                {
                    _1256 = false;
                }
                _1257 = _1256;
            }
            else
            {
                _1257 = false;
            }
            spvUnsafeArray<float, 5> _121;
            if (_1257)
            {
                int2 _1262 = int2(floor(_1242 * _297));
                for (int _1264 = 0; _1264 < 5; )
                {
                    int2 _1271 = _1262 + _113[_1264];
                    float4 _1291 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _1292 = _1291.x;
                    _121[_1264] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_1271.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_1271.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_1292 == 0.0) ? 1.0 : _1292);
                    _121[_1264] = powr(_121[_1264], 1.0);
                    _121[_1264] = precise::max(_121[_1264], 6.099999882280826568603515625e-05);
                    _1264++;
                    continue;
                }
            }
            float _1490;
            if (_1257)
            {
                spvUnsafeArray<float, 5> _144 = _145;
                spvUnsafeArray<float, 5> _143 = _121;
                float _1305 = _144[0];
                float _1307 = _144[3];
                _144[3] = precise::max(_144[0], _144[3]);
                _144[0] = precise::min(_1305, _1307);
                float _1313 = _144[1];
                float _1315 = _144[4];
                _144[4] = precise::max(_144[1], _144[4]);
                _144[1] = precise::min(_1313, _1315);
                float _1320 = _144[0];
                float _1322 = _144[2];
                _144[2] = precise::max(_144[0], _144[2]);
                _144[0] = precise::min(_1320, _1322);
                float _1327 = _144[1];
                float _1328 = _144[3];
                _144[3] = precise::max(_144[1], _144[3]);
                _144[1] = precise::min(_1327, _1328);
                float _1333 = _144[0];
                float _1334 = _144[1];
                _144[1] = precise::max(_144[0], _144[1]);
                _144[0] = precise::min(_1333, _1334);
                float _1339 = _144[2];
                float _1340 = _144[4];
                _144[4] = precise::max(_144[2], _144[4]);
                _144[2] = precise::min(_1339, _1340);
                float _1345 = _144[1];
                float _1346 = _144[2];
                _144[2] = precise::max(_144[1], _144[2]);
                _144[1] = precise::min(_1345, _1346);
                float _1351 = _144[3];
                float _1352 = _144[4];
                _144[4] = precise::max(_144[3], _144[4]);
                _144[3] = precise::min(_1351, _1352);
                float _1357 = _144[2];
                float _1358 = _144[3];
                _144[3] = precise::max(_144[2], _144[3]);
                _144[2] = precise::min(_1357, _1358);
                float _1364 = _143[0];
                float _1366 = _143[3];
                _143[3] = precise::max(_143[0], _143[3]);
                _143[0] = precise::min(_1364, _1366);
                float _1372 = _143[1];
                float _1374 = _143[4];
                _143[4] = precise::max(_143[1], _143[4]);
                _143[1] = precise::min(_1372, _1374);
                float _1379 = _143[0];
                float _1381 = _143[2];
                _143[2] = precise::max(_143[0], _143[2]);
                _143[0] = precise::min(_1379, _1381);
                float _1386 = _143[1];
                float _1387 = _143[3];
                _143[3] = precise::max(_143[1], _143[3]);
                _143[1] = precise::min(_1386, _1387);
                float _1392 = _143[0];
                float _1393 = _143[1];
                _143[1] = precise::max(_143[0], _143[1]);
                _143[0] = precise::min(_1392, _1393);
                float _1398 = _143[2];
                float _1399 = _143[4];
                _143[4] = precise::max(_143[2], _143[4]);
                _143[2] = precise::min(_1398, _1399);
                float _1404 = _143[1];
                float _1405 = _143[2];
                _143[2] = precise::max(_143[1], _143[2]);
                _143[1] = precise::min(_1404, _1405);
                float _1410 = _143[3];
                float _1411 = _143[4];
                _143[4] = precise::max(_143[3], _143[4]);
                _143[3] = precise::min(_1410, _1411);
                float _1416 = _143[2];
                float _1417 = _143[3];
                _143[3] = precise::max(_143[2], _143[3]);
                _143[2] = precise::min(_1416, _1417);
                float _1486;
                if (precise::min(_144[4], _143[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _1434;
                    _1434 = 65503.0;
                    int _1430;
                    int _1433;
                    float _1435;
                    int _1429 = 0;
                    int _1432 = 0;
                    int _1436 = 0;
                    for (;;)
                    {
                        bool _1444;
                        if (_1436 < 5)
                        {
                            _1444 = _1434 < 65504.0;
                        }
                        else
                        {
                            _1444 = false;
                        }
                        if (_1444)
                        {
                            float _1450 = _144[_1432] - _143[_1429];
                            if (abs(_1450) > 6.099999882280826568603515625e-05)
                            {
                                float _1461 = precise::max(_144[_1432], _143[_1429]);
                                float _1468;
                                if (_1461 != 0.0)
                                {
                                    _1468 = precise::min(_144[_1432], _143[_1429]) / _1461;
                                }
                                else
                                {
                                    _1468 = 0.0;
                                }
                                float _1470 = float(int(sign(_1450))) * (1.0 - _1468);
                                int _1479 = _1432 + int(_144[_1432] < _143[_1429]);
                                _1430 = _1429 + int(_144[_1479] >= _143[_1429]);
                                _1433 = _1479;
                                _1435 = (abs(_1470) < abs(_1434)) ? _1470 : _1434;
                            }
                            else
                            {
                                _1430 = _1429;
                                _1433 = _1432;
                                _1435 = 65504.0;
                            }
                            _1429 = _1430;
                            _1432 = _1433;
                            _1434 = _1435;
                            _1436++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _1486 = _1434;
                }
                else
                {
                    _1486 = 65503.0;
                }
                _1490 = _1486 * float(_1486 < 65503.0);
            }
            else
            {
                _1490 = 0.0;
            }
            float4 _1491 = float4(0.0);
            _1491.x = _1490;
            float _1499;
            if (_1490 != 0.0)
            {
                _1499 = float(int(sign(_1490)));
            }
            else
            {
                _1499 = 0.0;
            }
            _1491.y = _1499;
            _1491.z = 1.0;
            float4 _1505 = (((_549 + _863) + _1177) + _1491) * 0.25;
            sdk_hlsl_store(rw_spd_mip0, _1505.xy.xyyy, uint2(uint2(_222 + int2(_223, _224))));
            int _1510 = int(_215 + 32u);
            int2 _1512 = _214 + int2(_1510, _218);
            int _1514 = int(_207 + 16u);
            uint2 _1517 = uint2(_1512);
            int2 _1522 = int2(float2(_1512));
            int2 _1529 = int2(max(0, min(_1522.x, _237)), max(0, min(_1522.y, _242)));
            float2 _1536 = (float2(_1529) + float2(0.5)) / _252;
            int2 _1540 = int2(floor((_1536 + _256) * _252));
            spvUnsafeArray<float, 5> _148;
            for (int _1542 = 0; _1542 < 5; )
            {
                int2 _1549 = _1540 + _113[_1542];
                float4 _1562 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _1563 = _1562.x;
                _148[_1542] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_1549.x, _237)), max(0, min(_1549.y, _242))))), 0u).x * ((_1563 == 0.0) ? 1.0 : _1563);
                _148[_1542] = powr(_148[_1542], 1.0);
                _148[_1542] = precise::max(_148[_1542], 6.099999882280826568603515625e-05);
                _1542++;
                continue;
            }
            float2 _1574 = (_1536 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_1529)), 0u).xy;
            float _1575 = _1574.x;
            bool _1580;
            if (_1575 >= 0.0)
            {
                _1580 = _1575 <= 1.0;
            }
            else
            {
                _1580 = false;
            }
            bool _1589;
            if (_1580)
            {
                float _1583 = _1574.y;
                bool _1588;
                if (_1583 >= 0.0)
                {
                    _1588 = _1583 <= 1.0;
                }
                else
                {
                    _1588 = false;
                }
                _1589 = _1588;
            }
            else
            {
                _1589 = false;
            }
            spvUnsafeArray<float, 5> _122;
            if (_1589)
            {
                int2 _1594 = int2(floor(_1574 * _297));
                for (int _1596 = 0; _1596 < 5; )
                {
                    int2 _1603 = _1594 + _113[_1596];
                    float4 _1623 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _1624 = _1623.x;
                    _122[_1596] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_1603.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_1603.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_1624 == 0.0) ? 1.0 : _1624);
                    _122[_1596] = powr(_122[_1596], 1.0);
                    _122[_1596] = precise::max(_122[_1596], 6.099999882280826568603515625e-05);
                    _1596++;
                    continue;
                }
            }
            float _1822;
            if (_1589)
            {
                spvUnsafeArray<float, 5> _147 = _148;
                spvUnsafeArray<float, 5> _146 = _122;
                float _1637 = _147[0];
                float _1639 = _147[3];
                _147[3] = precise::max(_147[0], _147[3]);
                _147[0] = precise::min(_1637, _1639);
                float _1645 = _147[1];
                float _1647 = _147[4];
                _147[4] = precise::max(_147[1], _147[4]);
                _147[1] = precise::min(_1645, _1647);
                float _1652 = _147[0];
                float _1654 = _147[2];
                _147[2] = precise::max(_147[0], _147[2]);
                _147[0] = precise::min(_1652, _1654);
                float _1659 = _147[1];
                float _1660 = _147[3];
                _147[3] = precise::max(_147[1], _147[3]);
                _147[1] = precise::min(_1659, _1660);
                float _1665 = _147[0];
                float _1666 = _147[1];
                _147[1] = precise::max(_147[0], _147[1]);
                _147[0] = precise::min(_1665, _1666);
                float _1671 = _147[2];
                float _1672 = _147[4];
                _147[4] = precise::max(_147[2], _147[4]);
                _147[2] = precise::min(_1671, _1672);
                float _1677 = _147[1];
                float _1678 = _147[2];
                _147[2] = precise::max(_147[1], _147[2]);
                _147[1] = precise::min(_1677, _1678);
                float _1683 = _147[3];
                float _1684 = _147[4];
                _147[4] = precise::max(_147[3], _147[4]);
                _147[3] = precise::min(_1683, _1684);
                float _1689 = _147[2];
                float _1690 = _147[3];
                _147[3] = precise::max(_147[2], _147[3]);
                _147[2] = precise::min(_1689, _1690);
                float _1696 = _146[0];
                float _1698 = _146[3];
                _146[3] = precise::max(_146[0], _146[3]);
                _146[0] = precise::min(_1696, _1698);
                float _1704 = _146[1];
                float _1706 = _146[4];
                _146[4] = precise::max(_146[1], _146[4]);
                _146[1] = precise::min(_1704, _1706);
                float _1711 = _146[0];
                float _1713 = _146[2];
                _146[2] = precise::max(_146[0], _146[2]);
                _146[0] = precise::min(_1711, _1713);
                float _1718 = _146[1];
                float _1719 = _146[3];
                _146[3] = precise::max(_146[1], _146[3]);
                _146[1] = precise::min(_1718, _1719);
                float _1724 = _146[0];
                float _1725 = _146[1];
                _146[1] = precise::max(_146[0], _146[1]);
                _146[0] = precise::min(_1724, _1725);
                float _1730 = _146[2];
                float _1731 = _146[4];
                _146[4] = precise::max(_146[2], _146[4]);
                _146[2] = precise::min(_1730, _1731);
                float _1736 = _146[1];
                float _1737 = _146[2];
                _146[2] = precise::max(_146[1], _146[2]);
                _146[1] = precise::min(_1736, _1737);
                float _1742 = _146[3];
                float _1743 = _146[4];
                _146[4] = precise::max(_146[3], _146[4]);
                _146[3] = precise::min(_1742, _1743);
                float _1748 = _146[2];
                float _1749 = _146[3];
                _146[3] = precise::max(_146[2], _146[3]);
                _146[2] = precise::min(_1748, _1749);
                float _1818;
                if (precise::min(_147[4], _146[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _1766;
                    _1766 = 65503.0;
                    int _1762;
                    int _1765;
                    float _1767;
                    int _1761 = 0;
                    int _1764 = 0;
                    int _1768 = 0;
                    for (;;)
                    {
                        bool _1776;
                        if (_1768 < 5)
                        {
                            _1776 = _1766 < 65504.0;
                        }
                        else
                        {
                            _1776 = false;
                        }
                        if (_1776)
                        {
                            float _1782 = _147[_1764] - _146[_1761];
                            if (abs(_1782) > 6.099999882280826568603515625e-05)
                            {
                                float _1793 = precise::max(_147[_1764], _146[_1761]);
                                float _1800;
                                if (_1793 != 0.0)
                                {
                                    _1800 = precise::min(_147[_1764], _146[_1761]) / _1793;
                                }
                                else
                                {
                                    _1800 = 0.0;
                                }
                                float _1802 = float(int(sign(_1782))) * (1.0 - _1800);
                                int _1811 = _1764 + int(_147[_1764] < _146[_1761]);
                                _1762 = _1761 + int(_147[_1811] >= _146[_1761]);
                                _1765 = _1811;
                                _1767 = (abs(_1802) < abs(_1766)) ? _1802 : _1766;
                            }
                            else
                            {
                                _1762 = _1761;
                                _1765 = _1764;
                                _1767 = 65504.0;
                            }
                            _1761 = _1762;
                            _1764 = _1765;
                            _1766 = _1767;
                            _1768++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _1818 = _1766;
                }
                else
                {
                    _1818 = 65503.0;
                }
                _1822 = _1818 * float(_1818 < 65503.0);
            }
            else
            {
                _1822 = 0.0;
            }
            float4 _1823 = float4(0.0);
            _1823.x = _1822;
            float _1831;
            if (_1822 != 0.0)
            {
                _1831 = float(int(sign(_1822)));
            }
            else
            {
                _1831 = 0.0;
            }
            _1823.y = _1831;
            _1823.z = 1.0;
            int2 _1836 = int2(float2(int2(_1517 + uint2(0u, 1u))));
            int2 _1843 = int2(max(0, min(_1836.x, _237)), max(0, min(_1836.y, _242)));
            float2 _1850 = (float2(_1843) + float2(0.5)) / _252;
            int2 _1854 = int2(floor((_1850 + _256) * _252));
            spvUnsafeArray<float, 5> _151;
            for (int _1856 = 0; _1856 < 5; )
            {
                int2 _1863 = _1854 + _113[_1856];
                float4 _1876 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _1877 = _1876.x;
                _151[_1856] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_1863.x, _237)), max(0, min(_1863.y, _242))))), 0u).x * ((_1877 == 0.0) ? 1.0 : _1877);
                _151[_1856] = powr(_151[_1856], 1.0);
                _151[_1856] = precise::max(_151[_1856], 6.099999882280826568603515625e-05);
                _1856++;
                continue;
            }
            float2 _1888 = (_1850 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_1843)), 0u).xy;
            float _1889 = _1888.x;
            bool _1894;
            if (_1889 >= 0.0)
            {
                _1894 = _1889 <= 1.0;
            }
            else
            {
                _1894 = false;
            }
            bool _1903;
            if (_1894)
            {
                float _1897 = _1888.y;
                bool _1902;
                if (_1897 >= 0.0)
                {
                    _1902 = _1897 <= 1.0;
                }
                else
                {
                    _1902 = false;
                }
                _1903 = _1902;
            }
            else
            {
                _1903 = false;
            }
            spvUnsafeArray<float, 5> _123;
            if (_1903)
            {
                int2 _1908 = int2(floor(_1888 * _297));
                for (int _1910 = 0; _1910 < 5; )
                {
                    int2 _1917 = _1908 + _113[_1910];
                    float4 _1937 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _1938 = _1937.x;
                    _123[_1910] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_1917.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_1917.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_1938 == 0.0) ? 1.0 : _1938);
                    _123[_1910] = powr(_123[_1910], 1.0);
                    _123[_1910] = precise::max(_123[_1910], 6.099999882280826568603515625e-05);
                    _1910++;
                    continue;
                }
            }
            float _2136;
            if (_1903)
            {
                spvUnsafeArray<float, 5> _150 = _151;
                spvUnsafeArray<float, 5> _149 = _123;
                float _1951 = _150[0];
                float _1953 = _150[3];
                _150[3] = precise::max(_150[0], _150[3]);
                _150[0] = precise::min(_1951, _1953);
                float _1959 = _150[1];
                float _1961 = _150[4];
                _150[4] = precise::max(_150[1], _150[4]);
                _150[1] = precise::min(_1959, _1961);
                float _1966 = _150[0];
                float _1968 = _150[2];
                _150[2] = precise::max(_150[0], _150[2]);
                _150[0] = precise::min(_1966, _1968);
                float _1973 = _150[1];
                float _1974 = _150[3];
                _150[3] = precise::max(_150[1], _150[3]);
                _150[1] = precise::min(_1973, _1974);
                float _1979 = _150[0];
                float _1980 = _150[1];
                _150[1] = precise::max(_150[0], _150[1]);
                _150[0] = precise::min(_1979, _1980);
                float _1985 = _150[2];
                float _1986 = _150[4];
                _150[4] = precise::max(_150[2], _150[4]);
                _150[2] = precise::min(_1985, _1986);
                float _1991 = _150[1];
                float _1992 = _150[2];
                _150[2] = precise::max(_150[1], _150[2]);
                _150[1] = precise::min(_1991, _1992);
                float _1997 = _150[3];
                float _1998 = _150[4];
                _150[4] = precise::max(_150[3], _150[4]);
                _150[3] = precise::min(_1997, _1998);
                float _2003 = _150[2];
                float _2004 = _150[3];
                _150[3] = precise::max(_150[2], _150[3]);
                _150[2] = precise::min(_2003, _2004);
                float _2010 = _149[0];
                float _2012 = _149[3];
                _149[3] = precise::max(_149[0], _149[3]);
                _149[0] = precise::min(_2010, _2012);
                float _2018 = _149[1];
                float _2020 = _149[4];
                _149[4] = precise::max(_149[1], _149[4]);
                _149[1] = precise::min(_2018, _2020);
                float _2025 = _149[0];
                float _2027 = _149[2];
                _149[2] = precise::max(_149[0], _149[2]);
                _149[0] = precise::min(_2025, _2027);
                float _2032 = _149[1];
                float _2033 = _149[3];
                _149[3] = precise::max(_149[1], _149[3]);
                _149[1] = precise::min(_2032, _2033);
                float _2038 = _149[0];
                float _2039 = _149[1];
                _149[1] = precise::max(_149[0], _149[1]);
                _149[0] = precise::min(_2038, _2039);
                float _2044 = _149[2];
                float _2045 = _149[4];
                _149[4] = precise::max(_149[2], _149[4]);
                _149[2] = precise::min(_2044, _2045);
                float _2050 = _149[1];
                float _2051 = _149[2];
                _149[2] = precise::max(_149[1], _149[2]);
                _149[1] = precise::min(_2050, _2051);
                float _2056 = _149[3];
                float _2057 = _149[4];
                _149[4] = precise::max(_149[3], _149[4]);
                _149[3] = precise::min(_2056, _2057);
                float _2062 = _149[2];
                float _2063 = _149[3];
                _149[3] = precise::max(_149[2], _149[3]);
                _149[2] = precise::min(_2062, _2063);
                float _2132;
                if (precise::min(_150[4], _149[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _2080;
                    _2080 = 65503.0;
                    int _2076;
                    int _2079;
                    float _2081;
                    int _2075 = 0;
                    int _2078 = 0;
                    int _2082 = 0;
                    for (;;)
                    {
                        bool _2090;
                        if (_2082 < 5)
                        {
                            _2090 = _2080 < 65504.0;
                        }
                        else
                        {
                            _2090 = false;
                        }
                        if (_2090)
                        {
                            float _2096 = _150[_2078] - _149[_2075];
                            if (abs(_2096) > 6.099999882280826568603515625e-05)
                            {
                                float _2107 = precise::max(_150[_2078], _149[_2075]);
                                float _2114;
                                if (_2107 != 0.0)
                                {
                                    _2114 = precise::min(_150[_2078], _149[_2075]) / _2107;
                                }
                                else
                                {
                                    _2114 = 0.0;
                                }
                                float _2116 = float(int(sign(_2096))) * (1.0 - _2114);
                                int _2125 = _2078 + int(_150[_2078] < _149[_2075]);
                                _2076 = _2075 + int(_150[_2125] >= _149[_2075]);
                                _2079 = _2125;
                                _2081 = (abs(_2116) < abs(_2080)) ? _2116 : _2080;
                            }
                            else
                            {
                                _2076 = _2075;
                                _2079 = _2078;
                                _2081 = 65504.0;
                            }
                            _2075 = _2076;
                            _2078 = _2079;
                            _2080 = _2081;
                            _2082++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _2132 = _2080;
                }
                else
                {
                    _2132 = 65503.0;
                }
                _2136 = _2132 * float(_2132 < 65503.0);
            }
            else
            {
                _2136 = 0.0;
            }
            float4 _2137 = float4(0.0);
            _2137.x = _2136;
            float _2145;
            if (_2136 != 0.0)
            {
                _2145 = float(int(sign(_2136)));
            }
            else
            {
                _2145 = 0.0;
            }
            _2137.y = _2145;
            _2137.z = 1.0;
            int2 _2150 = int2(float2(int2(_1517 + uint2(1u, 0u))));
            int2 _2157 = int2(max(0, min(_2150.x, _237)), max(0, min(_2150.y, _242)));
            float2 _2164 = (float2(_2157) + float2(0.5)) / _252;
            int2 _2168 = int2(floor((_2164 + _256) * _252));
            spvUnsafeArray<float, 5> _154;
            for (int _2170 = 0; _2170 < 5; )
            {
                int2 _2177 = _2168 + _113[_2170];
                float4 _2190 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _2191 = _2190.x;
                _154[_2170] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_2177.x, _237)), max(0, min(_2177.y, _242))))), 0u).x * ((_2191 == 0.0) ? 1.0 : _2191);
                _154[_2170] = powr(_154[_2170], 1.0);
                _154[_2170] = precise::max(_154[_2170], 6.099999882280826568603515625e-05);
                _2170++;
                continue;
            }
            float2 _2202 = (_2164 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_2157)), 0u).xy;
            float _2203 = _2202.x;
            bool _2208;
            if (_2203 >= 0.0)
            {
                _2208 = _2203 <= 1.0;
            }
            else
            {
                _2208 = false;
            }
            bool _2217;
            if (_2208)
            {
                float _2211 = _2202.y;
                bool _2216;
                if (_2211 >= 0.0)
                {
                    _2216 = _2211 <= 1.0;
                }
                else
                {
                    _2216 = false;
                }
                _2217 = _2216;
            }
            else
            {
                _2217 = false;
            }
            spvUnsafeArray<float, 5> _124;
            if (_2217)
            {
                int2 _2222 = int2(floor(_2202 * _297));
                for (int _2224 = 0; _2224 < 5; )
                {
                    int2 _2231 = _2222 + _113[_2224];
                    float4 _2251 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _2252 = _2251.x;
                    _124[_2224] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_2231.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_2231.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_2252 == 0.0) ? 1.0 : _2252);
                    _124[_2224] = powr(_124[_2224], 1.0);
                    _124[_2224] = precise::max(_124[_2224], 6.099999882280826568603515625e-05);
                    _2224++;
                    continue;
                }
            }
            float _2450;
            if (_2217)
            {
                spvUnsafeArray<float, 5> _153 = _154;
                spvUnsafeArray<float, 5> _152 = _124;
                float _2265 = _153[0];
                float _2267 = _153[3];
                _153[3] = precise::max(_153[0], _153[3]);
                _153[0] = precise::min(_2265, _2267);
                float _2273 = _153[1];
                float _2275 = _153[4];
                _153[4] = precise::max(_153[1], _153[4]);
                _153[1] = precise::min(_2273, _2275);
                float _2280 = _153[0];
                float _2282 = _153[2];
                _153[2] = precise::max(_153[0], _153[2]);
                _153[0] = precise::min(_2280, _2282);
                float _2287 = _153[1];
                float _2288 = _153[3];
                _153[3] = precise::max(_153[1], _153[3]);
                _153[1] = precise::min(_2287, _2288);
                float _2293 = _153[0];
                float _2294 = _153[1];
                _153[1] = precise::max(_153[0], _153[1]);
                _153[0] = precise::min(_2293, _2294);
                float _2299 = _153[2];
                float _2300 = _153[4];
                _153[4] = precise::max(_153[2], _153[4]);
                _153[2] = precise::min(_2299, _2300);
                float _2305 = _153[1];
                float _2306 = _153[2];
                _153[2] = precise::max(_153[1], _153[2]);
                _153[1] = precise::min(_2305, _2306);
                float _2311 = _153[3];
                float _2312 = _153[4];
                _153[4] = precise::max(_153[3], _153[4]);
                _153[3] = precise::min(_2311, _2312);
                float _2317 = _153[2];
                float _2318 = _153[3];
                _153[3] = precise::max(_153[2], _153[3]);
                _153[2] = precise::min(_2317, _2318);
                float _2324 = _152[0];
                float _2326 = _152[3];
                _152[3] = precise::max(_152[0], _152[3]);
                _152[0] = precise::min(_2324, _2326);
                float _2332 = _152[1];
                float _2334 = _152[4];
                _152[4] = precise::max(_152[1], _152[4]);
                _152[1] = precise::min(_2332, _2334);
                float _2339 = _152[0];
                float _2341 = _152[2];
                _152[2] = precise::max(_152[0], _152[2]);
                _152[0] = precise::min(_2339, _2341);
                float _2346 = _152[1];
                float _2347 = _152[3];
                _152[3] = precise::max(_152[1], _152[3]);
                _152[1] = precise::min(_2346, _2347);
                float _2352 = _152[0];
                float _2353 = _152[1];
                _152[1] = precise::max(_152[0], _152[1]);
                _152[0] = precise::min(_2352, _2353);
                float _2358 = _152[2];
                float _2359 = _152[4];
                _152[4] = precise::max(_152[2], _152[4]);
                _152[2] = precise::min(_2358, _2359);
                float _2364 = _152[1];
                float _2365 = _152[2];
                _152[2] = precise::max(_152[1], _152[2]);
                _152[1] = precise::min(_2364, _2365);
                float _2370 = _152[3];
                float _2371 = _152[4];
                _152[4] = precise::max(_152[3], _152[4]);
                _152[3] = precise::min(_2370, _2371);
                float _2376 = _152[2];
                float _2377 = _152[3];
                _152[3] = precise::max(_152[2], _152[3]);
                _152[2] = precise::min(_2376, _2377);
                float _2446;
                if (precise::min(_153[4], _152[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _2394;
                    _2394 = 65503.0;
                    int _2390;
                    int _2393;
                    float _2395;
                    int _2389 = 0;
                    int _2392 = 0;
                    int _2396 = 0;
                    for (;;)
                    {
                        bool _2404;
                        if (_2396 < 5)
                        {
                            _2404 = _2394 < 65504.0;
                        }
                        else
                        {
                            _2404 = false;
                        }
                        if (_2404)
                        {
                            float _2410 = _153[_2392] - _152[_2389];
                            if (abs(_2410) > 6.099999882280826568603515625e-05)
                            {
                                float _2421 = precise::max(_153[_2392], _152[_2389]);
                                float _2428;
                                if (_2421 != 0.0)
                                {
                                    _2428 = precise::min(_153[_2392], _152[_2389]) / _2421;
                                }
                                else
                                {
                                    _2428 = 0.0;
                                }
                                float _2430 = float(int(sign(_2410))) * (1.0 - _2428);
                                int _2439 = _2392 + int(_153[_2392] < _152[_2389]);
                                _2390 = _2389 + int(_153[_2439] >= _152[_2389]);
                                _2393 = _2439;
                                _2395 = (abs(_2430) < abs(_2394)) ? _2430 : _2394;
                            }
                            else
                            {
                                _2390 = _2389;
                                _2393 = _2392;
                                _2395 = 65504.0;
                            }
                            _2389 = _2390;
                            _2392 = _2393;
                            _2394 = _2395;
                            _2396++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _2446 = _2394;
                }
                else
                {
                    _2446 = 65503.0;
                }
                _2450 = _2446 * float(_2446 < 65503.0);
            }
            else
            {
                _2450 = 0.0;
            }
            float4 _2451 = float4(0.0);
            _2451.x = _2450;
            float _2459;
            if (_2450 != 0.0)
            {
                _2459 = float(int(sign(_2450)));
            }
            else
            {
                _2459 = 0.0;
            }
            _2451.y = _2459;
            _2451.z = 1.0;
            int2 _2464 = int2(float2(int2(_1517 + uint2(1u))));
            int2 _2471 = int2(max(0, min(_2464.x, _237)), max(0, min(_2464.y, _242)));
            float2 _2478 = (float2(_2471) + float2(0.5)) / _252;
            int2 _2482 = int2(floor((_2478 + _256) * _252));
            spvUnsafeArray<float, 5> _157;
            for (int _2484 = 0; _2484 < 5; )
            {
                int2 _2491 = _2482 + _113[_2484];
                float4 _2504 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _2505 = _2504.x;
                _157[_2484] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_2491.x, _237)), max(0, min(_2491.y, _242))))), 0u).x * ((_2505 == 0.0) ? 1.0 : _2505);
                _157[_2484] = powr(_157[_2484], 1.0);
                _157[_2484] = precise::max(_157[_2484], 6.099999882280826568603515625e-05);
                _2484++;
                continue;
            }
            float2 _2516 = (_2478 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_2471)), 0u).xy;
            float _2517 = _2516.x;
            bool _2522;
            if (_2517 >= 0.0)
            {
                _2522 = _2517 <= 1.0;
            }
            else
            {
                _2522 = false;
            }
            bool _2531;
            if (_2522)
            {
                float _2525 = _2516.y;
                bool _2530;
                if (_2525 >= 0.0)
                {
                    _2530 = _2525 <= 1.0;
                }
                else
                {
                    _2530 = false;
                }
                _2531 = _2530;
            }
            else
            {
                _2531 = false;
            }
            spvUnsafeArray<float, 5> _125;
            if (_2531)
            {
                int2 _2536 = int2(floor(_2516 * _297));
                for (int _2538 = 0; _2538 < 5; )
                {
                    int2 _2545 = _2536 + _113[_2538];
                    float4 _2565 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _2566 = _2565.x;
                    _125[_2538] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_2545.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_2545.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_2566 == 0.0) ? 1.0 : _2566);
                    _125[_2538] = powr(_125[_2538], 1.0);
                    _125[_2538] = precise::max(_125[_2538], 6.099999882280826568603515625e-05);
                    _2538++;
                    continue;
                }
            }
            float _2764;
            if (_2531)
            {
                spvUnsafeArray<float, 5> _156 = _157;
                spvUnsafeArray<float, 5> _155 = _125;
                float _2579 = _156[0];
                float _2581 = _156[3];
                _156[3] = precise::max(_156[0], _156[3]);
                _156[0] = precise::min(_2579, _2581);
                float _2587 = _156[1];
                float _2589 = _156[4];
                _156[4] = precise::max(_156[1], _156[4]);
                _156[1] = precise::min(_2587, _2589);
                float _2594 = _156[0];
                float _2596 = _156[2];
                _156[2] = precise::max(_156[0], _156[2]);
                _156[0] = precise::min(_2594, _2596);
                float _2601 = _156[1];
                float _2602 = _156[3];
                _156[3] = precise::max(_156[1], _156[3]);
                _156[1] = precise::min(_2601, _2602);
                float _2607 = _156[0];
                float _2608 = _156[1];
                _156[1] = precise::max(_156[0], _156[1]);
                _156[0] = precise::min(_2607, _2608);
                float _2613 = _156[2];
                float _2614 = _156[4];
                _156[4] = precise::max(_156[2], _156[4]);
                _156[2] = precise::min(_2613, _2614);
                float _2619 = _156[1];
                float _2620 = _156[2];
                _156[2] = precise::max(_156[1], _156[2]);
                _156[1] = precise::min(_2619, _2620);
                float _2625 = _156[3];
                float _2626 = _156[4];
                _156[4] = precise::max(_156[3], _156[4]);
                _156[3] = precise::min(_2625, _2626);
                float _2631 = _156[2];
                float _2632 = _156[3];
                _156[3] = precise::max(_156[2], _156[3]);
                _156[2] = precise::min(_2631, _2632);
                float _2638 = _155[0];
                float _2640 = _155[3];
                _155[3] = precise::max(_155[0], _155[3]);
                _155[0] = precise::min(_2638, _2640);
                float _2646 = _155[1];
                float _2648 = _155[4];
                _155[4] = precise::max(_155[1], _155[4]);
                _155[1] = precise::min(_2646, _2648);
                float _2653 = _155[0];
                float _2655 = _155[2];
                _155[2] = precise::max(_155[0], _155[2]);
                _155[0] = precise::min(_2653, _2655);
                float _2660 = _155[1];
                float _2661 = _155[3];
                _155[3] = precise::max(_155[1], _155[3]);
                _155[1] = precise::min(_2660, _2661);
                float _2666 = _155[0];
                float _2667 = _155[1];
                _155[1] = precise::max(_155[0], _155[1]);
                _155[0] = precise::min(_2666, _2667);
                float _2672 = _155[2];
                float _2673 = _155[4];
                _155[4] = precise::max(_155[2], _155[4]);
                _155[2] = precise::min(_2672, _2673);
                float _2678 = _155[1];
                float _2679 = _155[2];
                _155[2] = precise::max(_155[1], _155[2]);
                _155[1] = precise::min(_2678, _2679);
                float _2684 = _155[3];
                float _2685 = _155[4];
                _155[4] = precise::max(_155[3], _155[4]);
                _155[3] = precise::min(_2684, _2685);
                float _2690 = _155[2];
                float _2691 = _155[3];
                _155[3] = precise::max(_155[2], _155[3]);
                _155[2] = precise::min(_2690, _2691);
                float _2760;
                if (precise::min(_156[4], _155[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _2708;
                    _2708 = 65503.0;
                    int _2704;
                    int _2707;
                    float _2709;
                    int _2703 = 0;
                    int _2706 = 0;
                    int _2710 = 0;
                    for (;;)
                    {
                        bool _2718;
                        if (_2710 < 5)
                        {
                            _2718 = _2708 < 65504.0;
                        }
                        else
                        {
                            _2718 = false;
                        }
                        if (_2718)
                        {
                            float _2724 = _156[_2706] - _155[_2703];
                            if (abs(_2724) > 6.099999882280826568603515625e-05)
                            {
                                float _2735 = precise::max(_156[_2706], _155[_2703]);
                                float _2742;
                                if (_2735 != 0.0)
                                {
                                    _2742 = precise::min(_156[_2706], _155[_2703]) / _2735;
                                }
                                else
                                {
                                    _2742 = 0.0;
                                }
                                float _2744 = float(int(sign(_2724))) * (1.0 - _2742);
                                int _2753 = _2706 + int(_156[_2706] < _155[_2703]);
                                _2704 = _2703 + int(_156[_2753] >= _155[_2703]);
                                _2707 = _2753;
                                _2709 = (abs(_2744) < abs(_2708)) ? _2744 : _2708;
                            }
                            else
                            {
                                _2704 = _2703;
                                _2707 = _2706;
                                _2709 = 65504.0;
                            }
                            _2703 = _2704;
                            _2706 = _2707;
                            _2708 = _2709;
                            _2710++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _2760 = _2708;
                }
                else
                {
                    _2760 = 65503.0;
                }
                _2764 = _2760 * float(_2760 < 65503.0);
            }
            else
            {
                _2764 = 0.0;
            }
            float4 _2765 = float4(0.0);
            _2765.x = _2764;
            float _2773;
            if (_2764 != 0.0)
            {
                _2773 = float(int(sign(_2764)));
            }
            else
            {
                _2773 = 0.0;
            }
            _2765.y = _2773;
            _2765.z = 1.0;
            float4 _2779 = (((_1823 + _2137) + _2451) + _2765) * 0.25;
            sdk_hlsl_store(rw_spd_mip0, _2779.xy.xyyy, uint2(uint2(_222 + int2(_1514, _224))));
            int _2784 = int(_217 + 32u);
            int2 _2786 = _214 + int2(_216, _2784);
            int _2788 = int(_210 + 16u);
            uint2 _2791 = uint2(_2786);
            int2 _2796 = int2(float2(_2786));
            int2 _2803 = int2(max(0, min(_2796.x, _237)), max(0, min(_2796.y, _242)));
            float2 _2810 = (float2(_2803) + float2(0.5)) / _252;
            int2 _2814 = int2(floor((_2810 + _256) * _252));
            spvUnsafeArray<float, 5> _160;
            for (int _2816 = 0; _2816 < 5; )
            {
                int2 _2823 = _2814 + _113[_2816];
                float4 _2836 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _2837 = _2836.x;
                _160[_2816] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_2823.x, _237)), max(0, min(_2823.y, _242))))), 0u).x * ((_2837 == 0.0) ? 1.0 : _2837);
                _160[_2816] = powr(_160[_2816], 1.0);
                _160[_2816] = precise::max(_160[_2816], 6.099999882280826568603515625e-05);
                _2816++;
                continue;
            }
            float2 _2848 = (_2810 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_2803)), 0u).xy;
            float _2849 = _2848.x;
            bool _2854;
            if (_2849 >= 0.0)
            {
                _2854 = _2849 <= 1.0;
            }
            else
            {
                _2854 = false;
            }
            bool _2863;
            if (_2854)
            {
                float _2857 = _2848.y;
                bool _2862;
                if (_2857 >= 0.0)
                {
                    _2862 = _2857 <= 1.0;
                }
                else
                {
                    _2862 = false;
                }
                _2863 = _2862;
            }
            else
            {
                _2863 = false;
            }
            spvUnsafeArray<float, 5> _126;
            if (_2863)
            {
                int2 _2868 = int2(floor(_2848 * _297));
                for (int _2870 = 0; _2870 < 5; )
                {
                    int2 _2877 = _2868 + _113[_2870];
                    float4 _2897 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _2898 = _2897.x;
                    _126[_2870] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_2877.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_2877.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_2898 == 0.0) ? 1.0 : _2898);
                    _126[_2870] = powr(_126[_2870], 1.0);
                    _126[_2870] = precise::max(_126[_2870], 6.099999882280826568603515625e-05);
                    _2870++;
                    continue;
                }
            }
            float _3096;
            if (_2863)
            {
                spvUnsafeArray<float, 5> _159 = _160;
                spvUnsafeArray<float, 5> _158 = _126;
                float _2911 = _159[0];
                float _2913 = _159[3];
                _159[3] = precise::max(_159[0], _159[3]);
                _159[0] = precise::min(_2911, _2913);
                float _2919 = _159[1];
                float _2921 = _159[4];
                _159[4] = precise::max(_159[1], _159[4]);
                _159[1] = precise::min(_2919, _2921);
                float _2926 = _159[0];
                float _2928 = _159[2];
                _159[2] = precise::max(_159[0], _159[2]);
                _159[0] = precise::min(_2926, _2928);
                float _2933 = _159[1];
                float _2934 = _159[3];
                _159[3] = precise::max(_159[1], _159[3]);
                _159[1] = precise::min(_2933, _2934);
                float _2939 = _159[0];
                float _2940 = _159[1];
                _159[1] = precise::max(_159[0], _159[1]);
                _159[0] = precise::min(_2939, _2940);
                float _2945 = _159[2];
                float _2946 = _159[4];
                _159[4] = precise::max(_159[2], _159[4]);
                _159[2] = precise::min(_2945, _2946);
                float _2951 = _159[1];
                float _2952 = _159[2];
                _159[2] = precise::max(_159[1], _159[2]);
                _159[1] = precise::min(_2951, _2952);
                float _2957 = _159[3];
                float _2958 = _159[4];
                _159[4] = precise::max(_159[3], _159[4]);
                _159[3] = precise::min(_2957, _2958);
                float _2963 = _159[2];
                float _2964 = _159[3];
                _159[3] = precise::max(_159[2], _159[3]);
                _159[2] = precise::min(_2963, _2964);
                float _2970 = _158[0];
                float _2972 = _158[3];
                _158[3] = precise::max(_158[0], _158[3]);
                _158[0] = precise::min(_2970, _2972);
                float _2978 = _158[1];
                float _2980 = _158[4];
                _158[4] = precise::max(_158[1], _158[4]);
                _158[1] = precise::min(_2978, _2980);
                float _2985 = _158[0];
                float _2987 = _158[2];
                _158[2] = precise::max(_158[0], _158[2]);
                _158[0] = precise::min(_2985, _2987);
                float _2992 = _158[1];
                float _2993 = _158[3];
                _158[3] = precise::max(_158[1], _158[3]);
                _158[1] = precise::min(_2992, _2993);
                float _2998 = _158[0];
                float _2999 = _158[1];
                _158[1] = precise::max(_158[0], _158[1]);
                _158[0] = precise::min(_2998, _2999);
                float _3004 = _158[2];
                float _3005 = _158[4];
                _158[4] = precise::max(_158[2], _158[4]);
                _158[2] = precise::min(_3004, _3005);
                float _3010 = _158[1];
                float _3011 = _158[2];
                _158[2] = precise::max(_158[1], _158[2]);
                _158[1] = precise::min(_3010, _3011);
                float _3016 = _158[3];
                float _3017 = _158[4];
                _158[4] = precise::max(_158[3], _158[4]);
                _158[3] = precise::min(_3016, _3017);
                float _3022 = _158[2];
                float _3023 = _158[3];
                _158[3] = precise::max(_158[2], _158[3]);
                _158[2] = precise::min(_3022, _3023);
                float _3092;
                if (precise::min(_159[4], _158[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _3040;
                    _3040 = 65503.0;
                    int _3036;
                    int _3039;
                    float _3041;
                    int _3035 = 0;
                    int _3038 = 0;
                    int _3042 = 0;
                    for (;;)
                    {
                        bool _3050;
                        if (_3042 < 5)
                        {
                            _3050 = _3040 < 65504.0;
                        }
                        else
                        {
                            _3050 = false;
                        }
                        if (_3050)
                        {
                            float _3056 = _159[_3038] - _158[_3035];
                            if (abs(_3056) > 6.099999882280826568603515625e-05)
                            {
                                float _3067 = precise::max(_159[_3038], _158[_3035]);
                                float _3074;
                                if (_3067 != 0.0)
                                {
                                    _3074 = precise::min(_159[_3038], _158[_3035]) / _3067;
                                }
                                else
                                {
                                    _3074 = 0.0;
                                }
                                float _3076 = float(int(sign(_3056))) * (1.0 - _3074);
                                int _3085 = _3038 + int(_159[_3038] < _158[_3035]);
                                _3036 = _3035 + int(_159[_3085] >= _158[_3035]);
                                _3039 = _3085;
                                _3041 = (abs(_3076) < abs(_3040)) ? _3076 : _3040;
                            }
                            else
                            {
                                _3036 = _3035;
                                _3039 = _3038;
                                _3041 = 65504.0;
                            }
                            _3035 = _3036;
                            _3038 = _3039;
                            _3040 = _3041;
                            _3042++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _3092 = _3040;
                }
                else
                {
                    _3092 = 65503.0;
                }
                _3096 = _3092 * float(_3092 < 65503.0);
            }
            else
            {
                _3096 = 0.0;
            }
            float4 _3097 = float4(0.0);
            _3097.x = _3096;
            float _3105;
            if (_3096 != 0.0)
            {
                _3105 = float(int(sign(_3096)));
            }
            else
            {
                _3105 = 0.0;
            }
            _3097.y = _3105;
            _3097.z = 1.0;
            int2 _3110 = int2(float2(int2(_2791 + uint2(0u, 1u))));
            int2 _3117 = int2(max(0, min(_3110.x, _237)), max(0, min(_3110.y, _242)));
            float2 _3124 = (float2(_3117) + float2(0.5)) / _252;
            int2 _3128 = int2(floor((_3124 + _256) * _252));
            spvUnsafeArray<float, 5> _163;
            for (int _3130 = 0; _3130 < 5; )
            {
                int2 _3137 = _3128 + _113[_3130];
                float4 _3150 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _3151 = _3150.x;
                _163[_3130] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_3137.x, _237)), max(0, min(_3137.y, _242))))), 0u).x * ((_3151 == 0.0) ? 1.0 : _3151);
                _163[_3130] = powr(_163[_3130], 1.0);
                _163[_3130] = precise::max(_163[_3130], 6.099999882280826568603515625e-05);
                _3130++;
                continue;
            }
            float2 _3162 = (_3124 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_3117)), 0u).xy;
            float _3163 = _3162.x;
            bool _3168;
            if (_3163 >= 0.0)
            {
                _3168 = _3163 <= 1.0;
            }
            else
            {
                _3168 = false;
            }
            bool _3177;
            if (_3168)
            {
                float _3171 = _3162.y;
                bool _3176;
                if (_3171 >= 0.0)
                {
                    _3176 = _3171 <= 1.0;
                }
                else
                {
                    _3176 = false;
                }
                _3177 = _3176;
            }
            else
            {
                _3177 = false;
            }
            spvUnsafeArray<float, 5> _127;
            if (_3177)
            {
                int2 _3182 = int2(floor(_3162 * _297));
                for (int _3184 = 0; _3184 < 5; )
                {
                    int2 _3191 = _3182 + _113[_3184];
                    float4 _3211 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _3212 = _3211.x;
                    _127[_3184] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_3191.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_3191.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_3212 == 0.0) ? 1.0 : _3212);
                    _127[_3184] = powr(_127[_3184], 1.0);
                    _127[_3184] = precise::max(_127[_3184], 6.099999882280826568603515625e-05);
                    _3184++;
                    continue;
                }
            }
            float _3410;
            if (_3177)
            {
                spvUnsafeArray<float, 5> _162 = _163;
                spvUnsafeArray<float, 5> _161 = _127;
                float _3225 = _162[0];
                float _3227 = _162[3];
                _162[3] = precise::max(_162[0], _162[3]);
                _162[0] = precise::min(_3225, _3227);
                float _3233 = _162[1];
                float _3235 = _162[4];
                _162[4] = precise::max(_162[1], _162[4]);
                _162[1] = precise::min(_3233, _3235);
                float _3240 = _162[0];
                float _3242 = _162[2];
                _162[2] = precise::max(_162[0], _162[2]);
                _162[0] = precise::min(_3240, _3242);
                float _3247 = _162[1];
                float _3248 = _162[3];
                _162[3] = precise::max(_162[1], _162[3]);
                _162[1] = precise::min(_3247, _3248);
                float _3253 = _162[0];
                float _3254 = _162[1];
                _162[1] = precise::max(_162[0], _162[1]);
                _162[0] = precise::min(_3253, _3254);
                float _3259 = _162[2];
                float _3260 = _162[4];
                _162[4] = precise::max(_162[2], _162[4]);
                _162[2] = precise::min(_3259, _3260);
                float _3265 = _162[1];
                float _3266 = _162[2];
                _162[2] = precise::max(_162[1], _162[2]);
                _162[1] = precise::min(_3265, _3266);
                float _3271 = _162[3];
                float _3272 = _162[4];
                _162[4] = precise::max(_162[3], _162[4]);
                _162[3] = precise::min(_3271, _3272);
                float _3277 = _162[2];
                float _3278 = _162[3];
                _162[3] = precise::max(_162[2], _162[3]);
                _162[2] = precise::min(_3277, _3278);
                float _3284 = _161[0];
                float _3286 = _161[3];
                _161[3] = precise::max(_161[0], _161[3]);
                _161[0] = precise::min(_3284, _3286);
                float _3292 = _161[1];
                float _3294 = _161[4];
                _161[4] = precise::max(_161[1], _161[4]);
                _161[1] = precise::min(_3292, _3294);
                float _3299 = _161[0];
                float _3301 = _161[2];
                _161[2] = precise::max(_161[0], _161[2]);
                _161[0] = precise::min(_3299, _3301);
                float _3306 = _161[1];
                float _3307 = _161[3];
                _161[3] = precise::max(_161[1], _161[3]);
                _161[1] = precise::min(_3306, _3307);
                float _3312 = _161[0];
                float _3313 = _161[1];
                _161[1] = precise::max(_161[0], _161[1]);
                _161[0] = precise::min(_3312, _3313);
                float _3318 = _161[2];
                float _3319 = _161[4];
                _161[4] = precise::max(_161[2], _161[4]);
                _161[2] = precise::min(_3318, _3319);
                float _3324 = _161[1];
                float _3325 = _161[2];
                _161[2] = precise::max(_161[1], _161[2]);
                _161[1] = precise::min(_3324, _3325);
                float _3330 = _161[3];
                float _3331 = _161[4];
                _161[4] = precise::max(_161[3], _161[4]);
                _161[3] = precise::min(_3330, _3331);
                float _3336 = _161[2];
                float _3337 = _161[3];
                _161[3] = precise::max(_161[2], _161[3]);
                _161[2] = precise::min(_3336, _3337);
                float _3406;
                if (precise::min(_162[4], _161[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _3354;
                    _3354 = 65503.0;
                    int _3350;
                    int _3353;
                    float _3355;
                    int _3349 = 0;
                    int _3352 = 0;
                    int _3356 = 0;
                    for (;;)
                    {
                        bool _3364;
                        if (_3356 < 5)
                        {
                            _3364 = _3354 < 65504.0;
                        }
                        else
                        {
                            _3364 = false;
                        }
                        if (_3364)
                        {
                            float _3370 = _162[_3352] - _161[_3349];
                            if (abs(_3370) > 6.099999882280826568603515625e-05)
                            {
                                float _3381 = precise::max(_162[_3352], _161[_3349]);
                                float _3388;
                                if (_3381 != 0.0)
                                {
                                    _3388 = precise::min(_162[_3352], _161[_3349]) / _3381;
                                }
                                else
                                {
                                    _3388 = 0.0;
                                }
                                float _3390 = float(int(sign(_3370))) * (1.0 - _3388);
                                int _3399 = _3352 + int(_162[_3352] < _161[_3349]);
                                _3350 = _3349 + int(_162[_3399] >= _161[_3349]);
                                _3353 = _3399;
                                _3355 = (abs(_3390) < abs(_3354)) ? _3390 : _3354;
                            }
                            else
                            {
                                _3350 = _3349;
                                _3353 = _3352;
                                _3355 = 65504.0;
                            }
                            _3349 = _3350;
                            _3352 = _3353;
                            _3354 = _3355;
                            _3356++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _3406 = _3354;
                }
                else
                {
                    _3406 = 65503.0;
                }
                _3410 = _3406 * float(_3406 < 65503.0);
            }
            else
            {
                _3410 = 0.0;
            }
            float4 _3411 = float4(0.0);
            _3411.x = _3410;
            float _3419;
            if (_3410 != 0.0)
            {
                _3419 = float(int(sign(_3410)));
            }
            else
            {
                _3419 = 0.0;
            }
            _3411.y = _3419;
            _3411.z = 1.0;
            int2 _3424 = int2(float2(int2(_2791 + uint2(1u, 0u))));
            int2 _3431 = int2(max(0, min(_3424.x, _237)), max(0, min(_3424.y, _242)));
            float2 _3438 = (float2(_3431) + float2(0.5)) / _252;
            int2 _3442 = int2(floor((_3438 + _256) * _252));
            spvUnsafeArray<float, 5> _166;
            for (int _3444 = 0; _3444 < 5; )
            {
                int2 _3451 = _3442 + _113[_3444];
                float4 _3464 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _3465 = _3464.x;
                _166[_3444] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_3451.x, _237)), max(0, min(_3451.y, _242))))), 0u).x * ((_3465 == 0.0) ? 1.0 : _3465);
                _166[_3444] = powr(_166[_3444], 1.0);
                _166[_3444] = precise::max(_166[_3444], 6.099999882280826568603515625e-05);
                _3444++;
                continue;
            }
            float2 _3476 = (_3438 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_3431)), 0u).xy;
            float _3477 = _3476.x;
            bool _3482;
            if (_3477 >= 0.0)
            {
                _3482 = _3477 <= 1.0;
            }
            else
            {
                _3482 = false;
            }
            bool _3491;
            if (_3482)
            {
                float _3485 = _3476.y;
                bool _3490;
                if (_3485 >= 0.0)
                {
                    _3490 = _3485 <= 1.0;
                }
                else
                {
                    _3490 = false;
                }
                _3491 = _3490;
            }
            else
            {
                _3491 = false;
            }
            spvUnsafeArray<float, 5> _128;
            if (_3491)
            {
                int2 _3496 = int2(floor(_3476 * _297));
                for (int _3498 = 0; _3498 < 5; )
                {
                    int2 _3505 = _3496 + _113[_3498];
                    float4 _3525 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _3526 = _3525.x;
                    _128[_3498] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_3505.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_3505.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_3526 == 0.0) ? 1.0 : _3526);
                    _128[_3498] = powr(_128[_3498], 1.0);
                    _128[_3498] = precise::max(_128[_3498], 6.099999882280826568603515625e-05);
                    _3498++;
                    continue;
                }
            }
            float _3724;
            if (_3491)
            {
                spvUnsafeArray<float, 5> _165 = _166;
                spvUnsafeArray<float, 5> _164 = _128;
                float _3539 = _165[0];
                float _3541 = _165[3];
                _165[3] = precise::max(_165[0], _165[3]);
                _165[0] = precise::min(_3539, _3541);
                float _3547 = _165[1];
                float _3549 = _165[4];
                _165[4] = precise::max(_165[1], _165[4]);
                _165[1] = precise::min(_3547, _3549);
                float _3554 = _165[0];
                float _3556 = _165[2];
                _165[2] = precise::max(_165[0], _165[2]);
                _165[0] = precise::min(_3554, _3556);
                float _3561 = _165[1];
                float _3562 = _165[3];
                _165[3] = precise::max(_165[1], _165[3]);
                _165[1] = precise::min(_3561, _3562);
                float _3567 = _165[0];
                float _3568 = _165[1];
                _165[1] = precise::max(_165[0], _165[1]);
                _165[0] = precise::min(_3567, _3568);
                float _3573 = _165[2];
                float _3574 = _165[4];
                _165[4] = precise::max(_165[2], _165[4]);
                _165[2] = precise::min(_3573, _3574);
                float _3579 = _165[1];
                float _3580 = _165[2];
                _165[2] = precise::max(_165[1], _165[2]);
                _165[1] = precise::min(_3579, _3580);
                float _3585 = _165[3];
                float _3586 = _165[4];
                _165[4] = precise::max(_165[3], _165[4]);
                _165[3] = precise::min(_3585, _3586);
                float _3591 = _165[2];
                float _3592 = _165[3];
                _165[3] = precise::max(_165[2], _165[3]);
                _165[2] = precise::min(_3591, _3592);
                float _3598 = _164[0];
                float _3600 = _164[3];
                _164[3] = precise::max(_164[0], _164[3]);
                _164[0] = precise::min(_3598, _3600);
                float _3606 = _164[1];
                float _3608 = _164[4];
                _164[4] = precise::max(_164[1], _164[4]);
                _164[1] = precise::min(_3606, _3608);
                float _3613 = _164[0];
                float _3615 = _164[2];
                _164[2] = precise::max(_164[0], _164[2]);
                _164[0] = precise::min(_3613, _3615);
                float _3620 = _164[1];
                float _3621 = _164[3];
                _164[3] = precise::max(_164[1], _164[3]);
                _164[1] = precise::min(_3620, _3621);
                float _3626 = _164[0];
                float _3627 = _164[1];
                _164[1] = precise::max(_164[0], _164[1]);
                _164[0] = precise::min(_3626, _3627);
                float _3632 = _164[2];
                float _3633 = _164[4];
                _164[4] = precise::max(_164[2], _164[4]);
                _164[2] = precise::min(_3632, _3633);
                float _3638 = _164[1];
                float _3639 = _164[2];
                _164[2] = precise::max(_164[1], _164[2]);
                _164[1] = precise::min(_3638, _3639);
                float _3644 = _164[3];
                float _3645 = _164[4];
                _164[4] = precise::max(_164[3], _164[4]);
                _164[3] = precise::min(_3644, _3645);
                float _3650 = _164[2];
                float _3651 = _164[3];
                _164[3] = precise::max(_164[2], _164[3]);
                _164[2] = precise::min(_3650, _3651);
                float _3720;
                if (precise::min(_165[4], _164[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _3668;
                    _3668 = 65503.0;
                    int _3664;
                    int _3667;
                    float _3669;
                    int _3663 = 0;
                    int _3666 = 0;
                    int _3670 = 0;
                    for (;;)
                    {
                        bool _3678;
                        if (_3670 < 5)
                        {
                            _3678 = _3668 < 65504.0;
                        }
                        else
                        {
                            _3678 = false;
                        }
                        if (_3678)
                        {
                            float _3684 = _165[_3666] - _164[_3663];
                            if (abs(_3684) > 6.099999882280826568603515625e-05)
                            {
                                float _3695 = precise::max(_165[_3666], _164[_3663]);
                                float _3702;
                                if (_3695 != 0.0)
                                {
                                    _3702 = precise::min(_165[_3666], _164[_3663]) / _3695;
                                }
                                else
                                {
                                    _3702 = 0.0;
                                }
                                float _3704 = float(int(sign(_3684))) * (1.0 - _3702);
                                int _3713 = _3666 + int(_165[_3666] < _164[_3663]);
                                _3664 = _3663 + int(_165[_3713] >= _164[_3663]);
                                _3667 = _3713;
                                _3669 = (abs(_3704) < abs(_3668)) ? _3704 : _3668;
                            }
                            else
                            {
                                _3664 = _3663;
                                _3667 = _3666;
                                _3669 = 65504.0;
                            }
                            _3663 = _3664;
                            _3666 = _3667;
                            _3668 = _3669;
                            _3670++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _3720 = _3668;
                }
                else
                {
                    _3720 = 65503.0;
                }
                _3724 = _3720 * float(_3720 < 65503.0);
            }
            else
            {
                _3724 = 0.0;
            }
            float4 _3725 = float4(0.0);
            _3725.x = _3724;
            float _3733;
            if (_3724 != 0.0)
            {
                _3733 = float(int(sign(_3724)));
            }
            else
            {
                _3733 = 0.0;
            }
            _3725.y = _3733;
            _3725.z = 1.0;
            int2 _3738 = int2(float2(int2(_2791 + uint2(1u))));
            int2 _3745 = int2(max(0, min(_3738.x, _237)), max(0, min(_3738.y, _242)));
            float2 _3752 = (float2(_3745) + float2(0.5)) / _252;
            int2 _3756 = int2(floor((_3752 + _256) * _252));
            spvUnsafeArray<float, 5> _169;
            for (int _3758 = 0; _3758 < 5; )
            {
                int2 _3765 = _3756 + _113[_3758];
                float4 _3778 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _3779 = _3778.x;
                _169[_3758] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_3765.x, _237)), max(0, min(_3765.y, _242))))), 0u).x * ((_3779 == 0.0) ? 1.0 : _3779);
                _169[_3758] = powr(_169[_3758], 1.0);
                _169[_3758] = precise::max(_169[_3758], 6.099999882280826568603515625e-05);
                _3758++;
                continue;
            }
            float2 _3790 = (_3752 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_3745)), 0u).xy;
            float _3791 = _3790.x;
            bool _3796;
            if (_3791 >= 0.0)
            {
                _3796 = _3791 <= 1.0;
            }
            else
            {
                _3796 = false;
            }
            bool _3805;
            if (_3796)
            {
                float _3799 = _3790.y;
                bool _3804;
                if (_3799 >= 0.0)
                {
                    _3804 = _3799 <= 1.0;
                }
                else
                {
                    _3804 = false;
                }
                _3805 = _3804;
            }
            else
            {
                _3805 = false;
            }
            spvUnsafeArray<float, 5> _129;
            if (_3805)
            {
                int2 _3810 = int2(floor(_3790 * _297));
                for (int _3812 = 0; _3812 < 5; )
                {
                    int2 _3819 = _3810 + _113[_3812];
                    float4 _3839 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _3840 = _3839.x;
                    _129[_3812] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_3819.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_3819.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_3840 == 0.0) ? 1.0 : _3840);
                    _129[_3812] = powr(_129[_3812], 1.0);
                    _129[_3812] = precise::max(_129[_3812], 6.099999882280826568603515625e-05);
                    _3812++;
                    continue;
                }
            }
            float _4038;
            if (_3805)
            {
                spvUnsafeArray<float, 5> _168 = _169;
                spvUnsafeArray<float, 5> _167 = _129;
                float _3853 = _168[0];
                float _3855 = _168[3];
                _168[3] = precise::max(_168[0], _168[3]);
                _168[0] = precise::min(_3853, _3855);
                float _3861 = _168[1];
                float _3863 = _168[4];
                _168[4] = precise::max(_168[1], _168[4]);
                _168[1] = precise::min(_3861, _3863);
                float _3868 = _168[0];
                float _3870 = _168[2];
                _168[2] = precise::max(_168[0], _168[2]);
                _168[0] = precise::min(_3868, _3870);
                float _3875 = _168[1];
                float _3876 = _168[3];
                _168[3] = precise::max(_168[1], _168[3]);
                _168[1] = precise::min(_3875, _3876);
                float _3881 = _168[0];
                float _3882 = _168[1];
                _168[1] = precise::max(_168[0], _168[1]);
                _168[0] = precise::min(_3881, _3882);
                float _3887 = _168[2];
                float _3888 = _168[4];
                _168[4] = precise::max(_168[2], _168[4]);
                _168[2] = precise::min(_3887, _3888);
                float _3893 = _168[1];
                float _3894 = _168[2];
                _168[2] = precise::max(_168[1], _168[2]);
                _168[1] = precise::min(_3893, _3894);
                float _3899 = _168[3];
                float _3900 = _168[4];
                _168[4] = precise::max(_168[3], _168[4]);
                _168[3] = precise::min(_3899, _3900);
                float _3905 = _168[2];
                float _3906 = _168[3];
                _168[3] = precise::max(_168[2], _168[3]);
                _168[2] = precise::min(_3905, _3906);
                float _3912 = _167[0];
                float _3914 = _167[3];
                _167[3] = precise::max(_167[0], _167[3]);
                _167[0] = precise::min(_3912, _3914);
                float _3920 = _167[1];
                float _3922 = _167[4];
                _167[4] = precise::max(_167[1], _167[4]);
                _167[1] = precise::min(_3920, _3922);
                float _3927 = _167[0];
                float _3929 = _167[2];
                _167[2] = precise::max(_167[0], _167[2]);
                _167[0] = precise::min(_3927, _3929);
                float _3934 = _167[1];
                float _3935 = _167[3];
                _167[3] = precise::max(_167[1], _167[3]);
                _167[1] = precise::min(_3934, _3935);
                float _3940 = _167[0];
                float _3941 = _167[1];
                _167[1] = precise::max(_167[0], _167[1]);
                _167[0] = precise::min(_3940, _3941);
                float _3946 = _167[2];
                float _3947 = _167[4];
                _167[4] = precise::max(_167[2], _167[4]);
                _167[2] = precise::min(_3946, _3947);
                float _3952 = _167[1];
                float _3953 = _167[2];
                _167[2] = precise::max(_167[1], _167[2]);
                _167[1] = precise::min(_3952, _3953);
                float _3958 = _167[3];
                float _3959 = _167[4];
                _167[4] = precise::max(_167[3], _167[4]);
                _167[3] = precise::min(_3958, _3959);
                float _3964 = _167[2];
                float _3965 = _167[3];
                _167[3] = precise::max(_167[2], _167[3]);
                _167[2] = precise::min(_3964, _3965);
                float _4034;
                if (precise::min(_168[4], _167[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _3982;
                    _3982 = 65503.0;
                    int _3978;
                    int _3981;
                    float _3983;
                    int _3977 = 0;
                    int _3980 = 0;
                    int _3984 = 0;
                    for (;;)
                    {
                        bool _3992;
                        if (_3984 < 5)
                        {
                            _3992 = _3982 < 65504.0;
                        }
                        else
                        {
                            _3992 = false;
                        }
                        if (_3992)
                        {
                            float _3998 = _168[_3980] - _167[_3977];
                            if (abs(_3998) > 6.099999882280826568603515625e-05)
                            {
                                float _4009 = precise::max(_168[_3980], _167[_3977]);
                                float _4016;
                                if (_4009 != 0.0)
                                {
                                    _4016 = precise::min(_168[_3980], _167[_3977]) / _4009;
                                }
                                else
                                {
                                    _4016 = 0.0;
                                }
                                float _4018 = float(int(sign(_3998))) * (1.0 - _4016);
                                int _4027 = _3980 + int(_168[_3980] < _167[_3977]);
                                _3978 = _3977 + int(_168[_4027] >= _167[_3977]);
                                _3981 = _4027;
                                _3983 = (abs(_4018) < abs(_3982)) ? _4018 : _3982;
                            }
                            else
                            {
                                _3978 = _3977;
                                _3981 = _3980;
                                _3983 = 65504.0;
                            }
                            _3977 = _3978;
                            _3980 = _3981;
                            _3982 = _3983;
                            _3984++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _4034 = _3982;
                }
                else
                {
                    _4034 = 65503.0;
                }
                _4038 = _4034 * float(_4034 < 65503.0);
            }
            else
            {
                _4038 = 0.0;
            }
            float4 _4039 = float4(0.0);
            _4039.x = _4038;
            float _4047;
            if (_4038 != 0.0)
            {
                _4047 = float(int(sign(_4038)));
            }
            else
            {
                _4047 = 0.0;
            }
            _4039.y = _4047;
            _4039.z = 1.0;
            float4 _4053 = (((_3097 + _3411) + _3725) + _4039) * 0.25;
            sdk_hlsl_store(rw_spd_mip0, _4053.xy.xyyy, uint2(uint2(_222 + int2(_223, _2788))));
            int2 _4058 = _214 + int2(_1510, _2784);
            uint2 _4061 = uint2(_4058);
            int2 _4066 = int2(float2(_4058));
            int2 _4073 = int2(max(0, min(_4066.x, _237)), max(0, min(_4066.y, _242)));
            float2 _4080 = (float2(_4073) + float2(0.5)) / _252;
            int2 _4084 = int2(floor((_4080 + _256) * _252));
            spvUnsafeArray<float, 5> _172;
            for (int _4086 = 0; _4086 < 5; )
            {
                int2 _4093 = _4084 + _113[_4086];
                float4 _4106 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _4107 = _4106.x;
                _172[_4086] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_4093.x, _237)), max(0, min(_4093.y, _242))))), 0u).x * ((_4107 == 0.0) ? 1.0 : _4107);
                _172[_4086] = powr(_172[_4086], 1.0);
                _172[_4086] = precise::max(_172[_4086], 6.099999882280826568603515625e-05);
                _4086++;
                continue;
            }
            float2 _4118 = (_4080 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_4073)), 0u).xy;
            float _4119 = _4118.x;
            bool _4124;
            if (_4119 >= 0.0)
            {
                _4124 = _4119 <= 1.0;
            }
            else
            {
                _4124 = false;
            }
            bool _4133;
            if (_4124)
            {
                float _4127 = _4118.y;
                bool _4132;
                if (_4127 >= 0.0)
                {
                    _4132 = _4127 <= 1.0;
                }
                else
                {
                    _4132 = false;
                }
                _4133 = _4132;
            }
            else
            {
                _4133 = false;
            }
            spvUnsafeArray<float, 5> _130;
            if (_4133)
            {
                int2 _4138 = int2(floor(_4118 * _297));
                for (int _4140 = 0; _4140 < 5; )
                {
                    int2 _4147 = _4138 + _113[_4140];
                    float4 _4167 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _4168 = _4167.x;
                    _130[_4140] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_4147.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_4147.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_4168 == 0.0) ? 1.0 : _4168);
                    _130[_4140] = powr(_130[_4140], 1.0);
                    _130[_4140] = precise::max(_130[_4140], 6.099999882280826568603515625e-05);
                    _4140++;
                    continue;
                }
            }
            float _4366;
            if (_4133)
            {
                spvUnsafeArray<float, 5> _171 = _172;
                spvUnsafeArray<float, 5> _170 = _130;
                float _4181 = _171[0];
                float _4183 = _171[3];
                _171[3] = precise::max(_171[0], _171[3]);
                _171[0] = precise::min(_4181, _4183);
                float _4189 = _171[1];
                float _4191 = _171[4];
                _171[4] = precise::max(_171[1], _171[4]);
                _171[1] = precise::min(_4189, _4191);
                float _4196 = _171[0];
                float _4198 = _171[2];
                _171[2] = precise::max(_171[0], _171[2]);
                _171[0] = precise::min(_4196, _4198);
                float _4203 = _171[1];
                float _4204 = _171[3];
                _171[3] = precise::max(_171[1], _171[3]);
                _171[1] = precise::min(_4203, _4204);
                float _4209 = _171[0];
                float _4210 = _171[1];
                _171[1] = precise::max(_171[0], _171[1]);
                _171[0] = precise::min(_4209, _4210);
                float _4215 = _171[2];
                float _4216 = _171[4];
                _171[4] = precise::max(_171[2], _171[4]);
                _171[2] = precise::min(_4215, _4216);
                float _4221 = _171[1];
                float _4222 = _171[2];
                _171[2] = precise::max(_171[1], _171[2]);
                _171[1] = precise::min(_4221, _4222);
                float _4227 = _171[3];
                float _4228 = _171[4];
                _171[4] = precise::max(_171[3], _171[4]);
                _171[3] = precise::min(_4227, _4228);
                float _4233 = _171[2];
                float _4234 = _171[3];
                _171[3] = precise::max(_171[2], _171[3]);
                _171[2] = precise::min(_4233, _4234);
                float _4240 = _170[0];
                float _4242 = _170[3];
                _170[3] = precise::max(_170[0], _170[3]);
                _170[0] = precise::min(_4240, _4242);
                float _4248 = _170[1];
                float _4250 = _170[4];
                _170[4] = precise::max(_170[1], _170[4]);
                _170[1] = precise::min(_4248, _4250);
                float _4255 = _170[0];
                float _4257 = _170[2];
                _170[2] = precise::max(_170[0], _170[2]);
                _170[0] = precise::min(_4255, _4257);
                float _4262 = _170[1];
                float _4263 = _170[3];
                _170[3] = precise::max(_170[1], _170[3]);
                _170[1] = precise::min(_4262, _4263);
                float _4268 = _170[0];
                float _4269 = _170[1];
                _170[1] = precise::max(_170[0], _170[1]);
                _170[0] = precise::min(_4268, _4269);
                float _4274 = _170[2];
                float _4275 = _170[4];
                _170[4] = precise::max(_170[2], _170[4]);
                _170[2] = precise::min(_4274, _4275);
                float _4280 = _170[1];
                float _4281 = _170[2];
                _170[2] = precise::max(_170[1], _170[2]);
                _170[1] = precise::min(_4280, _4281);
                float _4286 = _170[3];
                float _4287 = _170[4];
                _170[4] = precise::max(_170[3], _170[4]);
                _170[3] = precise::min(_4286, _4287);
                float _4292 = _170[2];
                float _4293 = _170[3];
                _170[3] = precise::max(_170[2], _170[3]);
                _170[2] = precise::min(_4292, _4293);
                float _4362;
                if (precise::min(_171[4], _170[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _4310;
                    _4310 = 65503.0;
                    int _4306;
                    int _4309;
                    float _4311;
                    int _4305 = 0;
                    int _4308 = 0;
                    int _4312 = 0;
                    for (;;)
                    {
                        bool _4320;
                        if (_4312 < 5)
                        {
                            _4320 = _4310 < 65504.0;
                        }
                        else
                        {
                            _4320 = false;
                        }
                        if (_4320)
                        {
                            float _4326 = _171[_4308] - _170[_4305];
                            if (abs(_4326) > 6.099999882280826568603515625e-05)
                            {
                                float _4337 = precise::max(_171[_4308], _170[_4305]);
                                float _4344;
                                if (_4337 != 0.0)
                                {
                                    _4344 = precise::min(_171[_4308], _170[_4305]) / _4337;
                                }
                                else
                                {
                                    _4344 = 0.0;
                                }
                                float _4346 = float(int(sign(_4326))) * (1.0 - _4344);
                                int _4355 = _4308 + int(_171[_4308] < _170[_4305]);
                                _4306 = _4305 + int(_171[_4355] >= _170[_4305]);
                                _4309 = _4355;
                                _4311 = (abs(_4346) < abs(_4310)) ? _4346 : _4310;
                            }
                            else
                            {
                                _4306 = _4305;
                                _4309 = _4308;
                                _4311 = 65504.0;
                            }
                            _4305 = _4306;
                            _4308 = _4309;
                            _4310 = _4311;
                            _4312++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _4362 = _4310;
                }
                else
                {
                    _4362 = 65503.0;
                }
                _4366 = _4362 * float(_4362 < 65503.0);
            }
            else
            {
                _4366 = 0.0;
            }
            float4 _4367 = float4(0.0);
            _4367.x = _4366;
            float _4375;
            if (_4366 != 0.0)
            {
                _4375 = float(int(sign(_4366)));
            }
            else
            {
                _4375 = 0.0;
            }
            _4367.y = _4375;
            _4367.z = 1.0;
            int2 _4380 = int2(float2(int2(_4061 + uint2(0u, 1u))));
            int2 _4387 = int2(max(0, min(_4380.x, _237)), max(0, min(_4380.y, _242)));
            float2 _4394 = (float2(_4387) + float2(0.5)) / _252;
            int2 _4398 = int2(floor((_4394 + _256) * _252));
            spvUnsafeArray<float, 5> _175;
            for (int _4400 = 0; _4400 < 5; )
            {
                int2 _4407 = _4398 + _113[_4400];
                float4 _4420 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _4421 = _4420.x;
                _175[_4400] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_4407.x, _237)), max(0, min(_4407.y, _242))))), 0u).x * ((_4421 == 0.0) ? 1.0 : _4421);
                _175[_4400] = powr(_175[_4400], 1.0);
                _175[_4400] = precise::max(_175[_4400], 6.099999882280826568603515625e-05);
                _4400++;
                continue;
            }
            float2 _4432 = (_4394 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_4387)), 0u).xy;
            float _4433 = _4432.x;
            bool _4438;
            if (_4433 >= 0.0)
            {
                _4438 = _4433 <= 1.0;
            }
            else
            {
                _4438 = false;
            }
            bool _4447;
            if (_4438)
            {
                float _4441 = _4432.y;
                bool _4446;
                if (_4441 >= 0.0)
                {
                    _4446 = _4441 <= 1.0;
                }
                else
                {
                    _4446 = false;
                }
                _4447 = _4446;
            }
            else
            {
                _4447 = false;
            }
            spvUnsafeArray<float, 5> _131;
            if (_4447)
            {
                int2 _4452 = int2(floor(_4432 * _297));
                for (int _4454 = 0; _4454 < 5; )
                {
                    int2 _4461 = _4452 + _113[_4454];
                    float4 _4481 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _4482 = _4481.x;
                    _131[_4454] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_4461.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_4461.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_4482 == 0.0) ? 1.0 : _4482);
                    _131[_4454] = powr(_131[_4454], 1.0);
                    _131[_4454] = precise::max(_131[_4454], 6.099999882280826568603515625e-05);
                    _4454++;
                    continue;
                }
            }
            float _4680;
            if (_4447)
            {
                spvUnsafeArray<float, 5> _174 = _175;
                spvUnsafeArray<float, 5> _173 = _131;
                float _4495 = _174[0];
                float _4497 = _174[3];
                _174[3] = precise::max(_174[0], _174[3]);
                _174[0] = precise::min(_4495, _4497);
                float _4503 = _174[1];
                float _4505 = _174[4];
                _174[4] = precise::max(_174[1], _174[4]);
                _174[1] = precise::min(_4503, _4505);
                float _4510 = _174[0];
                float _4512 = _174[2];
                _174[2] = precise::max(_174[0], _174[2]);
                _174[0] = precise::min(_4510, _4512);
                float _4517 = _174[1];
                float _4518 = _174[3];
                _174[3] = precise::max(_174[1], _174[3]);
                _174[1] = precise::min(_4517, _4518);
                float _4523 = _174[0];
                float _4524 = _174[1];
                _174[1] = precise::max(_174[0], _174[1]);
                _174[0] = precise::min(_4523, _4524);
                float _4529 = _174[2];
                float _4530 = _174[4];
                _174[4] = precise::max(_174[2], _174[4]);
                _174[2] = precise::min(_4529, _4530);
                float _4535 = _174[1];
                float _4536 = _174[2];
                _174[2] = precise::max(_174[1], _174[2]);
                _174[1] = precise::min(_4535, _4536);
                float _4541 = _174[3];
                float _4542 = _174[4];
                _174[4] = precise::max(_174[3], _174[4]);
                _174[3] = precise::min(_4541, _4542);
                float _4547 = _174[2];
                float _4548 = _174[3];
                _174[3] = precise::max(_174[2], _174[3]);
                _174[2] = precise::min(_4547, _4548);
                float _4554 = _173[0];
                float _4556 = _173[3];
                _173[3] = precise::max(_173[0], _173[3]);
                _173[0] = precise::min(_4554, _4556);
                float _4562 = _173[1];
                float _4564 = _173[4];
                _173[4] = precise::max(_173[1], _173[4]);
                _173[1] = precise::min(_4562, _4564);
                float _4569 = _173[0];
                float _4571 = _173[2];
                _173[2] = precise::max(_173[0], _173[2]);
                _173[0] = precise::min(_4569, _4571);
                float _4576 = _173[1];
                float _4577 = _173[3];
                _173[3] = precise::max(_173[1], _173[3]);
                _173[1] = precise::min(_4576, _4577);
                float _4582 = _173[0];
                float _4583 = _173[1];
                _173[1] = precise::max(_173[0], _173[1]);
                _173[0] = precise::min(_4582, _4583);
                float _4588 = _173[2];
                float _4589 = _173[4];
                _173[4] = precise::max(_173[2], _173[4]);
                _173[2] = precise::min(_4588, _4589);
                float _4594 = _173[1];
                float _4595 = _173[2];
                _173[2] = precise::max(_173[1], _173[2]);
                _173[1] = precise::min(_4594, _4595);
                float _4600 = _173[3];
                float _4601 = _173[4];
                _173[4] = precise::max(_173[3], _173[4]);
                _173[3] = precise::min(_4600, _4601);
                float _4606 = _173[2];
                float _4607 = _173[3];
                _173[3] = precise::max(_173[2], _173[3]);
                _173[2] = precise::min(_4606, _4607);
                float _4676;
                if (precise::min(_174[4], _173[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _4624;
                    _4624 = 65503.0;
                    int _4620;
                    int _4623;
                    float _4625;
                    int _4619 = 0;
                    int _4622 = 0;
                    int _4626 = 0;
                    for (;;)
                    {
                        bool _4634;
                        if (_4626 < 5)
                        {
                            _4634 = _4624 < 65504.0;
                        }
                        else
                        {
                            _4634 = false;
                        }
                        if (_4634)
                        {
                            float _4640 = _174[_4622] - _173[_4619];
                            if (abs(_4640) > 6.099999882280826568603515625e-05)
                            {
                                float _4651 = precise::max(_174[_4622], _173[_4619]);
                                float _4658;
                                if (_4651 != 0.0)
                                {
                                    _4658 = precise::min(_174[_4622], _173[_4619]) / _4651;
                                }
                                else
                                {
                                    _4658 = 0.0;
                                }
                                float _4660 = float(int(sign(_4640))) * (1.0 - _4658);
                                int _4669 = _4622 + int(_174[_4622] < _173[_4619]);
                                _4620 = _4619 + int(_174[_4669] >= _173[_4619]);
                                _4623 = _4669;
                                _4625 = (abs(_4660) < abs(_4624)) ? _4660 : _4624;
                            }
                            else
                            {
                                _4620 = _4619;
                                _4623 = _4622;
                                _4625 = 65504.0;
                            }
                            _4619 = _4620;
                            _4622 = _4623;
                            _4624 = _4625;
                            _4626++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _4676 = _4624;
                }
                else
                {
                    _4676 = 65503.0;
                }
                _4680 = _4676 * float(_4676 < 65503.0);
            }
            else
            {
                _4680 = 0.0;
            }
            float4 _4681 = float4(0.0);
            _4681.x = _4680;
            float _4689;
            if (_4680 != 0.0)
            {
                _4689 = float(int(sign(_4680)));
            }
            else
            {
                _4689 = 0.0;
            }
            _4681.y = _4689;
            _4681.z = 1.0;
            int2 _4694 = int2(float2(int2(_4061 + uint2(1u, 0u))));
            int2 _4701 = int2(max(0, min(_4694.x, _237)), max(0, min(_4694.y, _242)));
            float2 _4708 = (float2(_4701) + float2(0.5)) / _252;
            int2 _4712 = int2(floor((_4708 + _256) * _252));
            spvUnsafeArray<float, 5> _178;
            for (int _4714 = 0; _4714 < 5; )
            {
                int2 _4721 = _4712 + _113[_4714];
                float4 _4734 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _4735 = _4734.x;
                _178[_4714] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_4721.x, _237)), max(0, min(_4721.y, _242))))), 0u).x * ((_4735 == 0.0) ? 1.0 : _4735);
                _178[_4714] = powr(_178[_4714], 1.0);
                _178[_4714] = precise::max(_178[_4714], 6.099999882280826568603515625e-05);
                _4714++;
                continue;
            }
            float2 _4746 = (_4708 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_4701)), 0u).xy;
            float _4747 = _4746.x;
            bool _4752;
            if (_4747 >= 0.0)
            {
                _4752 = _4747 <= 1.0;
            }
            else
            {
                _4752 = false;
            }
            bool _4761;
            if (_4752)
            {
                float _4755 = _4746.y;
                bool _4760;
                if (_4755 >= 0.0)
                {
                    _4760 = _4755 <= 1.0;
                }
                else
                {
                    _4760 = false;
                }
                _4761 = _4760;
            }
            else
            {
                _4761 = false;
            }
            spvUnsafeArray<float, 5> _132;
            if (_4761)
            {
                int2 _4766 = int2(floor(_4746 * _297));
                for (int _4768 = 0; _4768 < 5; )
                {
                    int2 _4775 = _4766 + _113[_4768];
                    float4 _4795 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _4796 = _4795.x;
                    _132[_4768] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_4775.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_4775.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_4796 == 0.0) ? 1.0 : _4796);
                    _132[_4768] = powr(_132[_4768], 1.0);
                    _132[_4768] = precise::max(_132[_4768], 6.099999882280826568603515625e-05);
                    _4768++;
                    continue;
                }
            }
            float _4994;
            if (_4761)
            {
                spvUnsafeArray<float, 5> _177 = _178;
                spvUnsafeArray<float, 5> _176 = _132;
                float _4809 = _177[0];
                float _4811 = _177[3];
                _177[3] = precise::max(_177[0], _177[3]);
                _177[0] = precise::min(_4809, _4811);
                float _4817 = _177[1];
                float _4819 = _177[4];
                _177[4] = precise::max(_177[1], _177[4]);
                _177[1] = precise::min(_4817, _4819);
                float _4824 = _177[0];
                float _4826 = _177[2];
                _177[2] = precise::max(_177[0], _177[2]);
                _177[0] = precise::min(_4824, _4826);
                float _4831 = _177[1];
                float _4832 = _177[3];
                _177[3] = precise::max(_177[1], _177[3]);
                _177[1] = precise::min(_4831, _4832);
                float _4837 = _177[0];
                float _4838 = _177[1];
                _177[1] = precise::max(_177[0], _177[1]);
                _177[0] = precise::min(_4837, _4838);
                float _4843 = _177[2];
                float _4844 = _177[4];
                _177[4] = precise::max(_177[2], _177[4]);
                _177[2] = precise::min(_4843, _4844);
                float _4849 = _177[1];
                float _4850 = _177[2];
                _177[2] = precise::max(_177[1], _177[2]);
                _177[1] = precise::min(_4849, _4850);
                float _4855 = _177[3];
                float _4856 = _177[4];
                _177[4] = precise::max(_177[3], _177[4]);
                _177[3] = precise::min(_4855, _4856);
                float _4861 = _177[2];
                float _4862 = _177[3];
                _177[3] = precise::max(_177[2], _177[3]);
                _177[2] = precise::min(_4861, _4862);
                float _4868 = _176[0];
                float _4870 = _176[3];
                _176[3] = precise::max(_176[0], _176[3]);
                _176[0] = precise::min(_4868, _4870);
                float _4876 = _176[1];
                float _4878 = _176[4];
                _176[4] = precise::max(_176[1], _176[4]);
                _176[1] = precise::min(_4876, _4878);
                float _4883 = _176[0];
                float _4885 = _176[2];
                _176[2] = precise::max(_176[0], _176[2]);
                _176[0] = precise::min(_4883, _4885);
                float _4890 = _176[1];
                float _4891 = _176[3];
                _176[3] = precise::max(_176[1], _176[3]);
                _176[1] = precise::min(_4890, _4891);
                float _4896 = _176[0];
                float _4897 = _176[1];
                _176[1] = precise::max(_176[0], _176[1]);
                _176[0] = precise::min(_4896, _4897);
                float _4902 = _176[2];
                float _4903 = _176[4];
                _176[4] = precise::max(_176[2], _176[4]);
                _176[2] = precise::min(_4902, _4903);
                float _4908 = _176[1];
                float _4909 = _176[2];
                _176[2] = precise::max(_176[1], _176[2]);
                _176[1] = precise::min(_4908, _4909);
                float _4914 = _176[3];
                float _4915 = _176[4];
                _176[4] = precise::max(_176[3], _176[4]);
                _176[3] = precise::min(_4914, _4915);
                float _4920 = _176[2];
                float _4921 = _176[3];
                _176[3] = precise::max(_176[2], _176[3]);
                _176[2] = precise::min(_4920, _4921);
                float _4990;
                if (precise::min(_177[4], _176[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _4938;
                    _4938 = 65503.0;
                    int _4934;
                    int _4937;
                    float _4939;
                    int _4933 = 0;
                    int _4936 = 0;
                    int _4940 = 0;
                    for (;;)
                    {
                        bool _4948;
                        if (_4940 < 5)
                        {
                            _4948 = _4938 < 65504.0;
                        }
                        else
                        {
                            _4948 = false;
                        }
                        if (_4948)
                        {
                            float _4954 = _177[_4936] - _176[_4933];
                            if (abs(_4954) > 6.099999882280826568603515625e-05)
                            {
                                float _4965 = precise::max(_177[_4936], _176[_4933]);
                                float _4972;
                                if (_4965 != 0.0)
                                {
                                    _4972 = precise::min(_177[_4936], _176[_4933]) / _4965;
                                }
                                else
                                {
                                    _4972 = 0.0;
                                }
                                float _4974 = float(int(sign(_4954))) * (1.0 - _4972);
                                int _4983 = _4936 + int(_177[_4936] < _176[_4933]);
                                _4934 = _4933 + int(_177[_4983] >= _176[_4933]);
                                _4937 = _4983;
                                _4939 = (abs(_4974) < abs(_4938)) ? _4974 : _4938;
                            }
                            else
                            {
                                _4934 = _4933;
                                _4937 = _4936;
                                _4939 = 65504.0;
                            }
                            _4933 = _4934;
                            _4936 = _4937;
                            _4938 = _4939;
                            _4940++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _4990 = _4938;
                }
                else
                {
                    _4990 = 65503.0;
                }
                _4994 = _4990 * float(_4990 < 65503.0);
            }
            else
            {
                _4994 = 0.0;
            }
            float4 _4995 = float4(0.0);
            _4995.x = _4994;
            float _5003;
            if (_4994 != 0.0)
            {
                _5003 = float(int(sign(_4994)));
            }
            else
            {
                _5003 = 0.0;
            }
            _4995.y = _5003;
            _4995.z = 1.0;
            int2 _5008 = int2(float2(int2(_4061 + uint2(1u))));
            int2 _5015 = int2(max(0, min(_5008.x, _237)), max(0, min(_5008.y, _242)));
            float2 _5022 = (float2(_5015) + float2(0.5)) / _252;
            int2 _5026 = int2(floor((_5022 + _256) * _252));
            spvUnsafeArray<float, 5> _181;
            for (int _5028 = 0; _5028 < 5; )
            {
                int2 _5035 = _5026 + _113[_5028];
                float4 _5048 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                float _5049 = _5048.x;
                _181[_5028] = sdk_hlsl_load(r_current_luma, uint2(uint2(int2(max(0, min(_5035.x, _237)), max(0, min(_5035.y, _242))))), 0u).x * ((_5049 == 0.0) ? 1.0 : _5049);
                _181[_5028] = powr(_181[_5028], 1.0);
                _181[_5028] = precise::max(_181[_5028], 6.099999882280826568603515625e-05);
                _5028++;
                continue;
            }
            float2 _5060 = (_5022 + _298) + sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(_5015)), 0u).xy;
            float _5061 = _5060.x;
            bool _5066;
            if (_5061 >= 0.0)
            {
                _5066 = _5061 <= 1.0;
            }
            else
            {
                _5066 = false;
            }
            bool _5075;
            if (_5066)
            {
                float _5069 = _5060.y;
                bool _5074;
                if (_5069 >= 0.0)
                {
                    _5074 = _5069 <= 1.0;
                }
                else
                {
                    _5074 = false;
                }
                _5075 = _5074;
            }
            else
            {
                _5075 = false;
            }
            spvUnsafeArray<float, 5> _133;
            if (_5075)
            {
                int2 _5080 = int2(floor(_5060 * _297));
                for (int _5082 = 0; _5082 < 5; )
                {
                    int2 _5089 = _5080 + _113[_5082];
                    float4 _5109 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
                    float _5110 = _5109.x;
                    _133[_5082] = (sdk_hlsl_load(r_previous_luma, uint2(uint2(int2(max(0, min(_5089.x, (cbFSR3Upscaler.iPreviousFrameRenderSize.x - 1))), max(0, min(_5089.y, (cbFSR3Upscaler.iPreviousFrameRenderSize.y - 1)))))), 0u).x * cbFSR3Upscaler.fDeltaPreExposure) * ((_5110 == 0.0) ? 1.0 : _5110);
                    _133[_5082] = powr(_133[_5082], 1.0);
                    _133[_5082] = precise::max(_133[_5082], 6.099999882280826568603515625e-05);
                    _5082++;
                    continue;
                }
            }
            float _5308;
            if (_5075)
            {
                spvUnsafeArray<float, 5> _180 = _181;
                spvUnsafeArray<float, 5> _179 = _133;
                float _5123 = _180[0];
                float _5125 = _180[3];
                _180[3] = precise::max(_180[0], _180[3]);
                _180[0] = precise::min(_5123, _5125);
                float _5131 = _180[1];
                float _5133 = _180[4];
                _180[4] = precise::max(_180[1], _180[4]);
                _180[1] = precise::min(_5131, _5133);
                float _5138 = _180[0];
                float _5140 = _180[2];
                _180[2] = precise::max(_180[0], _180[2]);
                _180[0] = precise::min(_5138, _5140);
                float _5145 = _180[1];
                float _5146 = _180[3];
                _180[3] = precise::max(_180[1], _180[3]);
                _180[1] = precise::min(_5145, _5146);
                float _5151 = _180[0];
                float _5152 = _180[1];
                _180[1] = precise::max(_180[0], _180[1]);
                _180[0] = precise::min(_5151, _5152);
                float _5157 = _180[2];
                float _5158 = _180[4];
                _180[4] = precise::max(_180[2], _180[4]);
                _180[2] = precise::min(_5157, _5158);
                float _5163 = _180[1];
                float _5164 = _180[2];
                _180[2] = precise::max(_180[1], _180[2]);
                _180[1] = precise::min(_5163, _5164);
                float _5169 = _180[3];
                float _5170 = _180[4];
                _180[4] = precise::max(_180[3], _180[4]);
                _180[3] = precise::min(_5169, _5170);
                float _5175 = _180[2];
                float _5176 = _180[3];
                _180[3] = precise::max(_180[2], _180[3]);
                _180[2] = precise::min(_5175, _5176);
                float _5182 = _179[0];
                float _5184 = _179[3];
                _179[3] = precise::max(_179[0], _179[3]);
                _179[0] = precise::min(_5182, _5184);
                float _5190 = _179[1];
                float _5192 = _179[4];
                _179[4] = precise::max(_179[1], _179[4]);
                _179[1] = precise::min(_5190, _5192);
                float _5197 = _179[0];
                float _5199 = _179[2];
                _179[2] = precise::max(_179[0], _179[2]);
                _179[0] = precise::min(_5197, _5199);
                float _5204 = _179[1];
                float _5205 = _179[3];
                _179[3] = precise::max(_179[1], _179[3]);
                _179[1] = precise::min(_5204, _5205);
                float _5210 = _179[0];
                float _5211 = _179[1];
                _179[1] = precise::max(_179[0], _179[1]);
                _179[0] = precise::min(_5210, _5211);
                float _5216 = _179[2];
                float _5217 = _179[4];
                _179[4] = precise::max(_179[2], _179[4]);
                _179[2] = precise::min(_5216, _5217);
                float _5222 = _179[1];
                float _5223 = _179[2];
                _179[2] = precise::max(_179[1], _179[2]);
                _179[1] = precise::min(_5222, _5223);
                float _5228 = _179[3];
                float _5229 = _179[4];
                _179[4] = precise::max(_179[3], _179[4]);
                _179[3] = precise::min(_5228, _5229);
                float _5234 = _179[2];
                float _5235 = _179[3];
                _179[3] = precise::max(_179[2], _179[3]);
                _179[2] = precise::min(_5234, _5235);
                float _5304;
                if (precise::min(_180[4], _179[4]) > 1.1754943508222875079687365372222e-38)
                {
                    float _5252;
                    _5252 = 65503.0;
                    int _5248;
                    int _5251;
                    float _5253;
                    int _5247 = 0;
                    int _5250 = 0;
                    int _5254 = 0;
                    for (;;)
                    {
                        bool _5262;
                        if (_5254 < 5)
                        {
                            _5262 = _5252 < 65504.0;
                        }
                        else
                        {
                            _5262 = false;
                        }
                        if (_5262)
                        {
                            float _5268 = _180[_5250] - _179[_5247];
                            if (abs(_5268) > 6.099999882280826568603515625e-05)
                            {
                                float _5279 = precise::max(_180[_5250], _179[_5247]);
                                float _5286;
                                if (_5279 != 0.0)
                                {
                                    _5286 = precise::min(_180[_5250], _179[_5247]) / _5279;
                                }
                                else
                                {
                                    _5286 = 0.0;
                                }
                                float _5288 = float(int(sign(_5268))) * (1.0 - _5286);
                                int _5297 = _5250 + int(_180[_5250] < _179[_5247]);
                                _5248 = _5247 + int(_180[_5297] >= _179[_5247]);
                                _5251 = _5297;
                                _5253 = (abs(_5288) < abs(_5252)) ? _5288 : _5252;
                            }
                            else
                            {
                                _5248 = _5247;
                                _5251 = _5250;
                                _5253 = 65504.0;
                            }
                            _5247 = _5248;
                            _5250 = _5251;
                            _5252 = _5253;
                            _5254++;
                            continue;
                        }
                        else
                        {
                            break;
                        }
                    }
                    _5304 = _5252;
                }
                else
                {
                    _5304 = 65503.0;
                }
                _5308 = _5304 * float(_5304 < 65503.0);
            }
            else
            {
                _5308 = 0.0;
            }
            float4 _5309 = float4(0.0);
            _5309.x = _5308;
            float _5317;
            if (_5308 != 0.0)
            {
                _5317 = float(int(sign(_5308)));
            }
            else
            {
                _5317 = 0.0;
            }
            _5309.y = _5317;
            _5309.z = 1.0;
            float4 _5323 = (((_4367 + _4681) + _4995) + _5309) * 0.25;
            sdk_hlsl_store(rw_spd_mip0, _5323.xy.xyyy, uint2(uint2(_222 + int2(_1514, _2788))));
            if (cbSPD.mips <= 1u)
            {
                break;
            }
            float4 _5330 = spvQuadSwap(_1505, 0u);
            float4 _5331 = spvQuadSwap(_1505, 1u);
            float4 _5332 = spvQuadSwap(_1505, 2u);
            float4 _5336 = (((_1505 + _5330) + _5331) + _5332) * 0.25;
            float4 _5337 = spvQuadSwap(_2779, 0u);
            float4 _5338 = spvQuadSwap(_2779, 1u);
            float4 _5339 = spvQuadSwap(_2779, 2u);
            float4 _5343 = (((_2779 + _5337) + _5338) + _5339) * 0.25;
            float4 _5344 = spvQuadSwap(_4053, 0u);
            float4 _5345 = spvQuadSwap(_4053, 1u);
            float4 _5346 = spvQuadSwap(_4053, 2u);
            float4 _5350 = (((_4053 + _5344) + _5345) + _5346) * 0.25;
            float4 _5351 = spvQuadSwap(_5323, 0u);
            float4 _5352 = spvQuadSwap(_5323, 1u);
            float4 _5353 = spvQuadSwap(_5323, 2u);
            float4 _5357 = (((_5323 + _5351) + _5352) + _5353) * 0.25;
            if ((gl_LocalInvocationIndex % 4u) == 0u)
            {
                int2 _5363 = int2(_191 * uint2(16u));
                uint _5364 = _207 / 2u;
                int _5365 = int(_5364);
                uint _5366 = _210 / 2u;
                int _5367 = int(_5366);
                sdk_hlsl_store(rw_spd_mip1, _5336.xy.xyyy, uint2(uint2(_5363 + int2(_5365, _5367))));
                spdIntermediateR[_5364][_5366] = _5336.x;
                spdIntermediateG[_5364][_5366] = _5336.y;
                spdIntermediateB[_5364][_5366] = _5336.z;
                spdIntermediateA[_5364][_5366] = _5336.w;
                uint _5381 = _5364 + 8u;
                int _5382 = int(_5381);
                sdk_hlsl_store(rw_spd_mip1, _5343.xy.xyyy, uint2(uint2(_5363 + int2(_5382, _5367))));
                spdIntermediateR[_5381][_5366] = _5343.x;
                spdIntermediateG[_5381][_5366] = _5343.y;
                spdIntermediateB[_5381][_5366] = _5343.z;
                spdIntermediateA[_5381][_5366] = _5343.w;
                uint _5396 = _5366 + 8u;
                int _5397 = int(_5396);
                sdk_hlsl_store(rw_spd_mip1, _5350.xy.xyyy, uint2(uint2(_5363 + int2(_5365, _5397))));
                spdIntermediateR[_5364][_5396] = _5350.x;
                spdIntermediateG[_5364][_5396] = _5350.y;
                spdIntermediateB[_5364][_5396] = _5350.z;
                spdIntermediateA[_5364][_5396] = _5350.w;
                sdk_hlsl_store(rw_spd_mip1, _5357.xy.xyyy, uint2(uint2(_5363 + int2(_5382, _5397))));
                spdIntermediateR[_5381][_5396] = _5357.x;
                spdIntermediateG[_5381][_5396] = _5357.y;
                spdIntermediateB[_5381][_5396] = _5357.z;
                spdIntermediateA[_5381][_5396] = _5357.w;
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
            float _5430 = spdIntermediateR[_207][_210];
            float _5432 = spdIntermediateG[_207][_210];
            float _5434 = spdIntermediateB[_207][_210];
            float4 _5437 = float4(_5430, _5432, _5434, spdIntermediateA[_207][_210]);
            float4 _5438 = spvQuadSwap(_5437, 0u);
            float4 _5439 = spvQuadSwap(_5437, 1u);
            float4 _5440 = spvQuadSwap(_5437, 2u);
            float4 _5444 = (((_5437 + _5438) + _5439) + _5440) * 0.25;
            bool _5446 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_5446)
            {
                uint _5453 = _210 / 2u;
                sdk_hlsl_store(rw_spd_mip2, _5444.xy.xyyy, uint2(uint2(int2(_191 * uint2(8u)) + int2(int(_207 / 2u), int(_5453)))));
                uint _5461 = _207 + (_5453 % 2u);
                spdIntermediateR[_5461][_210] = _5444.x;
                spdIntermediateG[_5461][_210] = _5444.y;
                spdIntermediateB[_5461][_210] = _5444.z;
                spdIntermediateA[_5461][_210] = _5444.w;
            }
            if (cbSPD.mips <= 3u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _5477 = _215 + (_210 % 2u);
                float _5479 = spdIntermediateR[_5477][_217];
                float _5481 = spdIntermediateG[_5477][_217];
                float _5483 = spdIntermediateB[_5477][_217];
                float4 _5486 = float4(_5479, _5481, _5483, spdIntermediateA[_5477][_217]);
                float4 _5487 = spvQuadSwap(_5486, 0u);
                float4 _5488 = spvQuadSwap(_5486, 1u);
                float4 _5489 = spvQuadSwap(_5486, 2u);
                float4 _5493 = (((_5486 + _5487) + _5488) + _5489) * 0.25;
                if (_5446)
                {
                    uint _5500 = _210 / 2u;
                    sdk_hlsl_store(rw_spd_mip3, _5493.xy.xyyy, uint2(uint2(int2(_191 * uint2(4u)) + int2(int(_207 / 2u), int(_5500)))));
                    uint _5507 = _215 + _5500;
                    spdIntermediateR[_5507][_217] = _5493.x;
                    spdIntermediateG[_5507][_217] = _5493.y;
                    spdIntermediateB[_5507][_217] = _5493.z;
                    spdIntermediateA[_5507][_217] = _5493.w;
                }
            }
            if (cbSPD.mips <= 4u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _5523 = (_207 * 4u) + _210;
                uint _5524 = _210 * 4u;
                float _5526 = spdIntermediateR[_5523][_5524];
                float _5528 = spdIntermediateG[_5523][_5524];
                float _5530 = spdIntermediateB[_5523][_5524];
                float4 _5533 = float4(_5526, _5528, _5530, spdIntermediateA[_5523][_5524]);
                float4 _5534 = spvQuadSwap(_5533, 0u);
                float4 _5535 = spvQuadSwap(_5533, 1u);
                float4 _5536 = spvQuadSwap(_5533, 2u);
                float4 _5540 = (((_5533 + _5534) + _5535) + _5536) * 0.25;
                if (_5446)
                {
                    uint _5545 = _207 / 2u;
                    sdk_hlsl_store(rw_spd_mip4, _5540.xy.xyyy, uint2(uint2(int2(_191 * uint2(2u)) + int2(int(_5545), int(_210 / 2u)))));
                    uint _5554 = _5545 + _210;
                    spdIntermediateR[_5554][0u] = _5540.x;
                    spdIntermediateG[_5554][0u] = _5540.y;
                    spdIntermediateB[_5554][0u] = _5540.z;
                    spdIntermediateA[_5554][0u] = _5540.w;
                }
            }
            if (cbSPD.mips <= 5u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _5577 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
                float4 _5578 = spvQuadSwap(_5577, 0u);
                float4 _5579 = spvQuadSwap(_5577, 1u);
                float4 _5580 = spvQuadSwap(_5577, 2u);
                if (_5446)
                {
                    sdk_hlsl_store(rw_spd_mip5, ((((_5577 + _5578) + _5579) + _5580) * 0.25).xy.xyyy, uint2(_191));
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
            uint _5596 = rw_spd_global_atomic.atomic_fetch_add(uint2(0u), 1u).x;
            spdCounter = _5596;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (spdCounter != (cbSPD.numWorkGroups - 1u))
        {
            break;
        }
        uint _5605;
        uint _5607;
        sdk_hlsl_store(rw_spd_global_atomic, uint4(0u), uint2(uint2(0u)));
        do
        {
            _5605 = _207 * 4u;
            int _5606 = int(_5605);
            _5607 = _210 * 4u;
            int _5608 = int(_5607);
            uint2 _5610 = uint2(int2(_5606, _5608));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            int _5639 = int(_5605 + 2u);
            uint2 _5641 = uint2(int2(_5639, _5608));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            int _5670 = int(_5607 + 2u);
            uint2 _5672 = uint2(int2(_5606, _5670));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            uint2 _5701 = uint2(int2(_5639, _5670));
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            spvImageFence(rw_spd_mip5);
            if (cbSPD.mips <= 7u)
            {
                break;
            }
            float4 _5734 = ((((((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_5610)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5610 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5610 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5610 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25) + ((((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_5641)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5641 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5641 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5641 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25)) + ((((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_5672)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5672 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5672 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5672 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25)) + ((((float4(sdk_hlsl_load(rw_spd_mip5, uint2(_5701)).xy, 0.0, 0.0) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5701 + uint2(0u, 1u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5701 + uint2(1u, 0u)))).xy, 0.0, 0.0)) + float4(sdk_hlsl_load(rw_spd_mip5, uint2((_5701 + uint2(1u)))).xy, 0.0, 0.0)) * 0.25);
            float4 _5735 = _5734 * 0.25;
            spdIntermediateR[_207][_210] = _5735.x;
            spdIntermediateG[_207][_210] = _5735.y;
            spdIntermediateB[_207][_210] = _5735.z;
            spdIntermediateA[_207][_210] = _5735.w;
            break;
        } while(false);
        do
        {
            if (cbSPD.mips <= 8u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            float _5750 = spdIntermediateR[_207][_210];
            float _5752 = spdIntermediateG[_207][_210];
            float _5754 = spdIntermediateB[_207][_210];
            float4 _5757 = float4(_5750, _5752, _5754, spdIntermediateA[_207][_210]);
            float4 _5758 = spvQuadSwap(_5757, 0u);
            float4 _5759 = spvQuadSwap(_5757, 1u);
            float4 _5760 = spvQuadSwap(_5757, 2u);
            float4 _5764 = (((_5757 + _5758) + _5759) + _5760) * 0.25;
            bool _5766 = (gl_LocalInvocationIndex % 4u) == 0u;
            if (_5766)
            {
                uint _5771 = _207 + ((_210 / 2u) % 2u);
                spdIntermediateR[_5771][_210] = _5764.x;
                spdIntermediateG[_5771][_210] = _5764.y;
                spdIntermediateB[_5771][_210] = _5764.z;
                spdIntermediateA[_5771][_210] = _5764.w;
            }
            if (cbSPD.mips <= 9u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 64u)
            {
                uint _5787 = _215 + (_210 % 2u);
                float _5789 = spdIntermediateR[_5787][_217];
                float _5791 = spdIntermediateG[_5787][_217];
                float _5793 = spdIntermediateB[_5787][_217];
                float4 _5796 = float4(_5789, _5791, _5793, spdIntermediateA[_5787][_217]);
                float4 _5797 = spvQuadSwap(_5796, 0u);
                float4 _5798 = spvQuadSwap(_5796, 1u);
                float4 _5799 = spvQuadSwap(_5796, 2u);
                float4 _5803 = (((_5796 + _5797) + _5798) + _5799) * 0.25;
                if (_5766)
                {
                    uint _5807 = _215 + (_210 / 2u);
                    spdIntermediateR[_5807][_217] = _5803.x;
                    spdIntermediateG[_5807][_217] = _5803.y;
                    spdIntermediateB[_5807][_217] = _5803.z;
                    spdIntermediateA[_5807][_217] = _5803.w;
                }
            }
            if (cbSPD.mips <= 10u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 16u)
            {
                uint _5822 = _5605 + _210;
                float _5824 = spdIntermediateR[_5822][_5607];
                float _5826 = spdIntermediateG[_5822][_5607];
                float _5828 = spdIntermediateB[_5822][_5607];
                float4 _5831 = float4(_5824, _5826, _5828, spdIntermediateA[_5822][_5607]);
                float4 _5832 = spvQuadSwap(_5831, 0u);
                float4 _5833 = spvQuadSwap(_5831, 1u);
                float4 _5834 = spvQuadSwap(_5831, 2u);
                float4 _5838 = (((_5831 + _5832) + _5833) + _5834) * 0.25;
                if (_5766)
                {
                    uint _5842 = (_207 / 2u) + _210;
                    spdIntermediateR[_5842][0u] = _5838.x;
                    spdIntermediateG[_5842][0u] = _5838.y;
                    spdIntermediateB[_5842][0u] = _5838.z;
                    spdIntermediateA[_5842][0u] = _5838.w;
                }
            }
            if (cbSPD.mips <= 11u)
            {
                break;
            }
            threadgroup_barrier(mem_flags::mem_threadgroup);
            if (gl_LocalInvocationIndex < 4u)
            {
                float4 _5865 = float4(spdIntermediateR[gl_LocalInvocationIndex][0u], spdIntermediateG[gl_LocalInvocationIndex][0u], spdIntermediateB[gl_LocalInvocationIndex][0u], spdIntermediateA[gl_LocalInvocationIndex][0u]);
            }
            break;
        } while(false);
        break;
    } while(false);
}

