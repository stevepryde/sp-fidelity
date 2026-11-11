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

struct type_cbOF
{
    int2 iInputLumaResolution;
    uint uOpticalFlowPyramidLevel;
    uint uOpticalFlowPyramidLevelCount;
    uint iFrameIndex;
    uint backbufferTransferFunction;
    float2 minMaxLuminance;
};

constant int2 _98 = {};

kernel void main0(constant type_cbOF& cbOF [[buffer(0)]], texture2d<uint> r_optical_flow_input [[texture(0)]], texture2d<uint> r_optical_flow_previous_input [[texture(1)]], texture2d<int, access::read_write> rw_optical_flow [[texture(2)]], texture2d<uint> rw_optical_flow_scd_output [[texture(3)]], uint3 gl_WorkGroupID [[threadgroup_position_in_grid]], uint gl_LocalInvocationIndex [[thread_index_in_threadgroup]], uint gl_SubgroupSize [[threads_per_simdgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 2>, 8> pixels;
    threadgroup spvUnsafeArray<spvUnsafeArray<uint, 144>, 1> searchBuffer;
    threadgroup spvUnsafeArray<spvUnsafeArray<spvUnsafeArray<uint, 5>, 16>, 4> sadMapBuffer;
    threadgroup spvUnsafeArray<uint, 2> sWaveSad;
    threadgroup spvUnsafeArray<uint, 2> sWaveMin;
    do
    {
        uint _106 = uint(int(gl_LocalInvocationIndex));
        int _108 = int(_106 & 3u);
        int _111 = int((_106 >> 2u) & 15u);
        int _119 = int(((_106 >> 1u) & 1u) | (((_106 >> 5u) & 1u) << 1u));
        int2 _120 = int3(gl_WorkGroupID).xy << int2(4);
        int2 _122 = _120 + (int2(_108, _111) * int2(4, 1));
        bool _137;
        do
        {
            if (cbOF.iFrameIndex <= 5u)
            {
                _137 = true;
                break;
            }
            else
            {
                _137 = (sdk_hlsl_load(rw_optical_flow_scd_output, uint2(uint2(1u, 0u))).x & 15u) != 0u;
                break;
            }
            break; // unreachable workaround
        } while(false);
        if (_137)
        {
            bool _146;
            if ((_111 & 7) == 0)
            {
                _146 = (_108 & 1) == 0;
            }
            else
            {
                _146 = false;
            }
            if (_146)
            {
                sdk_hlsl_store(rw_optical_flow, int2(0).xyyy, uint2(uint2(_122 >> int2(3))));
            }
            break;
        }
        uint _155 = cbOF.uOpticalFlowPyramidLevelCount - 1u;
        int _160 = int(cbOF.uOpticalFlowPyramidLevel) & 31;
        int _161 = cbOF.iInputLumaResolution.x >> _160;
        int _164 = _161 - 4;
        int _165 = _122.x;
        int _168 = (cbOF.iInputLumaResolution.y >> _160) - 1;
        int2 _172 = int2(max(0, min(_164, _165)), max(0, min(_168, _122.y)));
        uint2 _173 = uint2(_172);
        uint2 _178 = uint2(_172 + int2(1, 0));
        uint2 _183 = uint2(_172 + int2(2, 0));
        uint2 _188 = uint2(_172 + int2(3, 0));
        uint _197 = ((sdk_hlsl_load(r_optical_flow_input, uint2(_173), 0u).x | (sdk_hlsl_load(r_optical_flow_input, uint2(_178), 0u).x << 8u)) | (sdk_hlsl_load(r_optical_flow_input, uint2(_183), 0u).x << 16u)) | (sdk_hlsl_load(r_optical_flow_input, uint2(_188), 0u).x << 24u);
        bool _198 = _165 < 0;
        uint _247;
        if (_198)
        {
            uint _228 = _197 & 255u;
            uint _234;
            if (_165 <= (-1))
            {
                _234 = (_197 << 8u) | _228;
            }
            else
            {
                _234 = _197;
            }
            uint _240;
            if (_165 <= (-2))
            {
                _240 = (_234 << 8u) | _228;
            }
            else
            {
                _240 = _234;
            }
            uint _246;
            if (_165 <= (-3))
            {
                _246 = (_240 << 8u) | _228;
            }
            else
            {
                _246 = _240;
            }
            _247 = _246;
        }
        else
        {
            uint _227;
            if (_165 > _164)
            {
                uint _205 = _197 & 4278190080u;
                uint _212;
                if (_165 >= (_161 - 3))
                {
                    _212 = (_197 >> 8u) | _205;
                }
                else
                {
                    _212 = _197;
                }
                uint _219;
                if (_165 >= (_161 - 2))
                {
                    _219 = (_212 >> 8u) | _205;
                }
                else
                {
                    _219 = _212;
                }
                uint _226;
                if (_165 >= (_161 - 1))
                {
                    _226 = (_219 >> 8u) | _205;
                }
                else
                {
                    _226 = _219;
                }
                _227 = _226;
            }
            else
            {
                _227 = _197;
            }
            _247 = _227;
        }
        uint _265 = ((sdk_hlsl_load(r_optical_flow_previous_input, uint2(_173), 0u).x | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(_178), 0u).x << 8u)) | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(_183), 0u).x << 16u)) | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(_188), 0u).x << 24u);
        uint _314;
        if (_198)
        {
            uint _295 = _265 & 255u;
            uint _301;
            if (_165 <= (-1))
            {
                _301 = (_265 << 8u) | _295;
            }
            else
            {
                _301 = _265;
            }
            uint _307;
            if (_165 <= (-2))
            {
                _307 = (_301 << 8u) | _295;
            }
            else
            {
                _307 = _301;
            }
            uint _313;
            if (_165 <= (-3))
            {
                _313 = (_307 << 8u) | _295;
            }
            else
            {
                _313 = _307;
            }
            _314 = _313;
        }
        else
        {
            uint _294;
            if (_165 > _164)
            {
                uint _272 = _265 & 4278190080u;
                uint _279;
                if (_165 >= (_161 - 3))
                {
                    _279 = (_265 >> 8u) | _272;
                }
                else
                {
                    _279 = _265;
                }
                uint _286;
                if (_165 >= (_161 - 2))
                {
                    _286 = (_279 >> 8u) | _272;
                }
                else
                {
                    _286 = _279;
                }
                uint _293;
                if (_165 >= (_161 - 1))
                {
                    _293 = (_286 >> 8u) | _272;
                }
                else
                {
                    _293 = _286;
                }
                _294 = _293;
            }
            else
            {
                _294 = _265;
            }
            _314 = _294;
        }
        uint _315 = _247 & 255u;
        uint _317 = _314 & 255u;
        uint _321 = _247 >> 8u;
        uint _324 = _314 >> 8u;
        uint _330 = _247 >> 16u;
        uint _333 = _314 >> 16u;
        uint _339 = _247 >> 24u;
        uint _342 = _314 >> 24u;
        uint _348 = uint(((abs(int(_315) - int(_317)) + abs(int(_321 & 255u) - int(_324 & 255u))) + abs(int(_330 & 255u) - int(_333 & 255u))) + abs(int(_339 & 255u) - int(_342 & 255u)));
        int2 _349 = int3(gl_WorkGroupID).xy << int2(1);
        int2 _350;
        _350.y = 0;
        int2 _352;
        _352 = _350;
        int2 _353;
        int2 _361;
        for (; _352.y < 2; _353 = _361, _353.y = _361.y + 1, _352 = _353)
        {
            int2 _359 = _352;
            _359.x = 0;
            _361 = _359;
            int2 _362;
            int _364;
            for (;;)
            {
                _364 = _361.x;
                if (_364 < 2)
                {
                    int2 _368 = _349 + _361;
                    uint2 _369 = uint2(_368);
                    spvImageFence(rw_optical_flow);
                    int2 _375 = select(sdk_hlsl_load(rw_optical_flow, uint2(_369)).xy, int2(0), bool2(cbOF.uOpticalFlowPyramidLevel == _155));
                    int _376 = _361.y;
                    int _378 = (_376 * 2) + _364;
                    if (_119 == _378)
                    {
                        pixels[_111 & 7][_108 & 1] = _247;
                    }
                    int2 _387 = (_120 + (_361 * int2(8))) + _375;
                    int _389 = _387.x - 8;
                    int _391 = _387.y - 8;
                    for (int _393 = int(gl_LocalInvocationIndex); _393 < 144; _393 += 64)
                    {
                        int _402 = _389 + ((_393 - 6 * (_393 / 6)) * 4);
                        int2 _408 = int2(max(0, min(_164, _402)), max(0, min(_168, (_391 + (_393 / 6)))));
                        uint _433 = ((sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_408)), 0u).x | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_408 + int2(1, 0))), 0u).x << 8u)) | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_408 + int2(2, 0))), 0u).x << 16u)) | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_408 + int2(3, 0))), 0u).x << 24u);
                        uint _483;
                        if (_402 < 0)
                        {
                            uint _464 = _433 & 255u;
                            uint _470;
                            if (_402 <= (-1))
                            {
                                _470 = (_433 << 8u) | _464;
                            }
                            else
                            {
                                _470 = _433;
                            }
                            uint _476;
                            if (_402 <= (-2))
                            {
                                _476 = (_470 << 8u) | _464;
                            }
                            else
                            {
                                _476 = _470;
                            }
                            uint _482;
                            if (_402 <= (-3))
                            {
                                _482 = (_476 << 8u) | _464;
                            }
                            else
                            {
                                _482 = _476;
                            }
                            _483 = _482;
                        }
                        else
                        {
                            uint _463;
                            if (_402 > _164)
                            {
                                uint _441 = _433 & 4278190080u;
                                uint _448;
                                if (_402 >= (_161 - 3))
                                {
                                    _448 = (_433 >> 8u) | _441;
                                }
                                else
                                {
                                    _448 = _433;
                                }
                                uint _455;
                                if (_402 >= (_161 - 2))
                                {
                                    _455 = (_448 >> 8u) | _441;
                                }
                                else
                                {
                                    _455 = _448;
                                }
                                uint _462;
                                if (_402 >= (_161 - 1))
                                {
                                    _462 = (_455 >> 8u) | _441;
                                }
                                else
                                {
                                    _462 = _455;
                                }
                                _463 = _462;
                            }
                            else
                            {
                                _463 = _433;
                            }
                            _483 = _463;
                        }
                        searchBuffer[0][_393] = _483;
                    }
                    threadgroup_barrier(mem_flags::mem_threadgroup);
                    uint4 _486;
                    _486 = uint4(0u);
                    for (int _489 = 0; _489 < 8; )
                    {
                        int _495 = ((_111 + _489) * 6) + _108;
                        int _498 = _495 + 1;
                        int _501 = _495 + 2;
                        int _509 = int(pixels[_489][0] & 255u);
                        uint _512 = searchBuffer[0][_495] >> 8u;
                        int _517 = int((pixels[_489][0] >> 8u) & 255u);
                        int _526 = int((pixels[_489][0] >> 16u) & 255u);
                        int _535 = int((pixels[_489][0] >> 24u) & 255u);
                        uint _540 = searchBuffer[0][_498] & 255u;
                        uint _542 = _512 | (_540 << 24u);
                        uint _543 = searchBuffer[0][_498] >> 8u;
                        uint _548 = _542 >> 8u;
                        uint _567 = _543 & 255u;
                        uint _569 = _548 | (_567 << 24u);
                        uint _575 = _569 >> 8u;
                        uint _596 = _575 | (((_543 >> 8u) & 255u) << 24u);
                        uint4 _621 = _486 + uint4(uint(((abs(int(searchBuffer[0][_495] & 255u) - _509) + abs(int(_512 & 255u) - _517)) + abs(int((searchBuffer[0][_495] >> 16u) & 255u) - _526)) + abs(int((searchBuffer[0][_495] >> 24u) & 255u) - _535)), uint(((abs(int(_542 & 255u) - _509) + abs(int(_548 & 255u) - _517)) + abs(int((_542 >> 16u) & 255u) - _526)) + abs(int((_542 >> 24u) & 255u) - _535)), uint(((abs(int(_569 & 255u) - _509) + abs(int(_575 & 255u) - _517)) + abs(int((_569 >> 16u) & 255u) - _526)) + abs(int((_569 >> 24u) & 255u) - _535)), uint(((abs(int(_596 & 255u) - _509) + abs(int((_596 >> 8u) & 255u) - _517)) + abs(int((_596 >> 16u) & 255u) - _526)) + abs(int((_596 >> 24u) & 255u) - _535)));
                        int _626 = int(pixels[_489][1] & 255u);
                        int _632 = int((pixels[_489][1] >> 8u) & 255u);
                        int _641 = int((pixels[_489][1] >> 16u) & 255u);
                        int _650 = int((pixels[_489][1] >> 24u) & 255u);
                        uint _657 = _543 | ((searchBuffer[0][_501] & 255u) << 24u);
                        uint _658 = searchBuffer[0][_501] >> 8u;
                        uint _663 = _657 >> 8u;
                        uint _684 = _663 | ((_658 & 255u) << 24u);
                        uint _690 = _684 >> 8u;
                        uint _711 = _690 | (((_658 >> 8u) & 255u) << 24u);
                        uint4 _487 = _621 + uint4(uint(((abs(int(_540) - _626) + abs(int(_567) - _632)) + abs(int((searchBuffer[0][_498] >> 16u) & 255u) - _641)) + abs(int((searchBuffer[0][_498] >> 24u) & 255u) - _650)), uint(((abs(int(_657 & 255u) - _626) + abs(int(_663 & 255u) - _632)) + abs(int((_657 >> 16u) & 255u) - _641)) + abs(int((_657 >> 24u) & 255u) - _650)), uint(((abs(int(_684 & 255u) - _626) + abs(int(_690 & 255u) - _632)) + abs(int((_684 >> 16u) & 255u) - _641)) + abs(int((_684 >> 24u) & 255u) - _650)), uint(((abs(int(_711 & 255u) - _626) + abs(int((_711 >> 8u) & 255u) - _632)) + abs(int((_711 >> 16u) & 255u) - _641)) + abs(int((_711 >> 24u) & 255u) - _650)));
                        _486 = _487;
                        _489++;
                        continue;
                    }
                    int _738 = _108 * 4;
                    int2 _740 = int2(_738, _111) - int2(8);
                    int2 _741 = _740 >> int2(31);
                    uint2 _744 = uint2((_740 + _741) ^ _741);
                    uint _751 = uint(_111 << 4);
                    sadMapBuffer[0][_111][_108] = (_486.x << 16u) | ((((_744.y << 12u) | (_744.x << 8u)) | _751) | uint(_738));
                    int _759 = _738 + 1;
                    int2 _761 = int2(_759, _111) - int2(8);
                    int2 _762 = _761 >> int2(31);
                    uint2 _765 = uint2((_761 + _762) ^ _762);
                    sadMapBuffer[1][_111][_108] = (_486.y << 16u) | ((((_765.y << 12u) | (_765.x << 8u)) | _751) | uint(_759));
                    int _778 = _738 + 2;
                    int2 _780 = int2(_778, _111) - int2(8);
                    int2 _781 = _780 >> int2(31);
                    uint2 _784 = uint2((_780 + _781) ^ _781);
                    sadMapBuffer[2][_111][_108] = (_486.z << 16u) | ((((_784.y << 12u) | (_784.x << 8u)) | _751) | uint(_778));
                    int _797 = _738 + 3;
                    int2 _799 = int2(_797, _111) - int2(8);
                    int2 _800 = _799 >> int2(31);
                    uint2 _803 = uint2((_799 + _800) ^ _800);
                    sadMapBuffer[3][_111][_108] = (_486.w << 16u) | ((((_803.y << 12u) | (_803.x << 8u)) | _751) | uint(_797));
                    threadgroup_barrier(mem_flags::mem_threadgroup);
                    uint _814 = sadMapBuffer[0][_111][_108];
                    uint _815 = sadMapBuffer[1][_111][_108];
                    uint _817 = sadMapBuffer[2][_111][_108];
                    uint _818 = sadMapBuffer[3][_111][_108];
                    uint _821 = simd_min(min(min(_814, _815), min(_817, _818)));
                    bool _823 = gl_SubgroupSize == 32u;
                    uint _835;
                    if (_823)
                    {
                        int _826 = int(gl_LocalInvocationIndex) >> 5;
                        bool _827 = simd_is_first();
                        if (_827)
                        {
                            sWaveMin[_826] = _821;
                        }
                        threadgroup_barrier(mem_flags::mem_threadgroup);
                        _835 = min(_821, sWaveMin[_826 ^ 1]);
                    }
                    else
                    {
                        _835 = _821;
                    }
                    uint _836 = _835 & 15u;
                    uint _839 = _835 >> 4u;
                    uint _847 = simd_sum((_119 != _378) ? 0u : _348);
                    uint _859;
                    if (_823)
                    {
                        int _850 = int(gl_LocalInvocationIndex) >> 5;
                        bool _851 = simd_is_first();
                        if (_851)
                        {
                            sWaveSad[_850] = _847;
                        }
                        threadgroup_barrier(mem_flags::mem_threadgroup);
                        _859 = _847 + sWaveSad[_850 ^ 1];
                    }
                    else
                    {
                        _859 = _847;
                    }
                    bool _865;
                    if (cbOF.uOpticalFlowPyramidLevel == 0u)
                    {
                        _865 = _859 <= (_835 >> 16u);
                    }
                    else
                    {
                        _865 = false;
                    }
                    sdk_hlsl_store(rw_optical_flow, select(_375 + int2(int(_836) - 8, int(_839 & 15u) - 8), int2(0), bool2(_865)).xyyy, uint2(_369));
                    _362 = _361;
                    _362.x = _364 + 1;
                    _361 = _362;
                    continue;
                }
                else
                {
                    break;
                }
            }
        }
        break;
    } while(false);
}

