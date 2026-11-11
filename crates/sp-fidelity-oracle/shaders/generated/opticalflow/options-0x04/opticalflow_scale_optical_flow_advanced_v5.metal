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

struct type_cbOF
{
    int2 iInputLumaResolution;
    uint uOpticalFlowPyramidLevel;
    uint uOpticalFlowPyramidLevelCount;
    uint iFrameIndex;
    uint backbufferTransferFunction;
    float2 minMaxLuminance;
};

kernel void main0(constant type_cbOF& cbOF [[buffer(0)]], texture2d<uint> r_optical_flow_input [[texture(0)]], texture2d<uint> r_optical_flow_previous_input [[texture(1)]], texture2d<int> r_optical_flow [[texture(2)]], texture2d<int, access::write> rw_optical_flow_next_level [[texture(3)]], texture2d<uint> rw_optical_flow_scd_output [[texture(4)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]], uint3 gl_LocalInvocationID [[thread_position_in_threadgroup]])
{
    threadgroup spvUnsafeArray<spvUnsafeArray<spvUnsafeArray<int2, 4>, 4>, 4> nearestVectors;
    threadgroup spvUnsafeArray<spvUnsafeArray<spvUnsafeArray<uint, 4>, 4>, 4> localRegion;
    threadgroup spvUnsafeArray<spvUnsafeArray<spvUnsafeArray<uint, 4>, 4>, 4> sads;
    do
    {
        bool _96;
        do
        {
            if (cbOF.iFrameIndex <= 5u)
            {
                _96 = true;
                break;
            }
            else
            {
                _96 = (sdk_hlsl_load(rw_optical_flow_scd_output, uint2(uint2(1u, 0u))).x & 15u) != 0u;
                break;
            }
            break; // unreachable workaround
        } while(false);
        if (_96)
        {
            sdk_hlsl_store(rw_optical_flow_next_level, int2(0).xyyy, uint2(uint2(int3(gl_GlobalInvocationID).xy)));
            break;
        }
        int2 _124 = sdk_hlsl_load(r_optical_flow, uint2(uint2(int2((int(gl_GlobalInvocationID.x) / 2) + (((int(gl_LocalInvocationID.z) - 2 * (int(gl_LocalInvocationID.z) / 2)) - 1) + (int(gl_GlobalInvocationID.x) - 2 * (int(gl_GlobalInvocationID.x) / 2))), (int(gl_GlobalInvocationID.y) / 2) + (((int(gl_LocalInvocationID.z) / 2) - 1) + (int(gl_GlobalInvocationID.y) - 2 * (int(gl_GlobalInvocationID.y) / 2)))))), 0u).xy;
        nearestVectors[int(gl_LocalInvocationID.z)][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] = _124 * int2(2);
        for (int _132 = int(gl_LocalInvocationID.z); _132 < 4; _132 += 4)
        {
            int _138 = int(gl_GlobalInvocationID.x) * 4;
            int _147 = int(cbOF.uOpticalFlowPyramidLevel) & 31;
            int _148 = cbOF.iInputLumaResolution.x >> _147;
            int _151 = _148 - 4;
            int2 _157 = int2(max(0, min(_151, _138)), max(0, min(((cbOF.iInputLumaResolution.y >> _147) - 1), ((int(gl_GlobalInvocationID.y) * 4) + _132))));
            uint _182 = ((sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_157)), 0u).x | (sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_157 + int2(1, 0))), 0u).x << 8u)) | (sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_157 + int2(2, 0))), 0u).x << 16u)) | (sdk_hlsl_load(r_optical_flow_input, uint2(uint2(_157 + int2(3, 0))), 0u).x << 24u);
            uint _232;
            if (_138 < 0)
            {
                uint _213 = _182 & 255u;
                uint _219;
                if (_138 <= (-1))
                {
                    _219 = (_182 << 8u) | _213;
                }
                else
                {
                    _219 = _182;
                }
                uint _225;
                if (_138 <= (-2))
                {
                    _225 = (_219 << 8u) | _213;
                }
                else
                {
                    _225 = _219;
                }
                uint _231;
                if (_138 <= (-3))
                {
                    _231 = (_225 << 8u) | _213;
                }
                else
                {
                    _231 = _225;
                }
                _232 = _231;
            }
            else
            {
                uint _212;
                if (_138 > _151)
                {
                    uint _190 = _182 & 4278190080u;
                    uint _197;
                    if (_138 >= (_148 - 3))
                    {
                        _197 = (_182 >> 8u) | _190;
                    }
                    else
                    {
                        _197 = _182;
                    }
                    uint _204;
                    if (_138 >= (_148 - 2))
                    {
                        _204 = (_197 >> 8u) | _190;
                    }
                    else
                    {
                        _204 = _197;
                    }
                    uint _211;
                    if (_138 >= (_148 - 1))
                    {
                        _211 = (_204 >> 8u) | _190;
                    }
                    else
                    {
                        _211 = _204;
                    }
                    _212 = _211;
                }
                else
                {
                    _212 = _182;
                }
                _232 = _212;
            }
            localRegion[_132][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] = _232;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        uint _235;
        _235 = 0u;
        uint _236;
        for (int _238 = 0; _238 < 4; _235 = _236, _238++)
        {
            int2 _247 = int2(int(gl_GlobalInvocationID.x) * 4, (int(gl_GlobalInvocationID.y) * 4) + _238) + _124;
            int _254 = int(cbOF.uOpticalFlowPyramidLevel) & 31;
            int _255 = cbOF.iInputLumaResolution.x >> _254;
            int _258 = _255 - 4;
            int _259 = _247.x;
            int2 _266 = int2(max(0, min(_258, _259)), max(0, min(((cbOF.iInputLumaResolution.y >> _254) - 1), _247.y)));
            uint _291 = ((sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_266)), 0u).x | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_266 + int2(1, 0))), 0u).x << 8u)) | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_266 + int2(2, 0))), 0u).x << 16u)) | (sdk_hlsl_load(r_optical_flow_previous_input, uint2(uint2(_266 + int2(3, 0))), 0u).x << 24u);
            uint _341;
            if (_259 < 0)
            {
                uint _322 = _291 & 255u;
                uint _328;
                if (_259 <= (-1))
                {
                    _328 = (_291 << 8u) | _322;
                }
                else
                {
                    _328 = _291;
                }
                uint _334;
                if (_259 <= (-2))
                {
                    _334 = (_328 << 8u) | _322;
                }
                else
                {
                    _334 = _328;
                }
                uint _340;
                if (_259 <= (-3))
                {
                    _340 = (_334 << 8u) | _322;
                }
                else
                {
                    _340 = _334;
                }
                _341 = _340;
            }
            else
            {
                uint _321;
                if (_259 > _258)
                {
                    uint _299 = _291 & 4278190080u;
                    uint _306;
                    if (_259 >= (_255 - 3))
                    {
                        _306 = (_291 >> 8u) | _299;
                    }
                    else
                    {
                        _306 = _291;
                    }
                    uint _313;
                    if (_259 >= (_255 - 2))
                    {
                        _313 = (_306 >> 8u) | _299;
                    }
                    else
                    {
                        _313 = _306;
                    }
                    uint _320;
                    if (_259 >= (_255 - 1))
                    {
                        _320 = (_313 >> 8u) | _299;
                    }
                    else
                    {
                        _320 = _313;
                    }
                    _321 = _320;
                }
                else
                {
                    _321 = _291;
                }
                _341 = _321;
            }
            _236 = _235 + uint(((abs(int(localRegion[_238][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] & 255u) - int(_341 & 255u)) + abs(int((localRegion[_238][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] >> 8u) & 255u) - int((_341 >> 8u) & 255u))) + abs(int((localRegion[_238][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] >> 16u) & 255u) - int((_341 >> 16u) & 255u))) + abs(int((localRegion[_238][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] >> 24u) & 255u) - int((_341 >> 24u) & 255u)));
        }
        sads[int(gl_LocalInvocationID.z)][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] = _235;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (int(gl_LocalInvocationID.z) == 0)
        {
            uint _386;
            _386 = 0u;
            uint _384;
            uint _387;
            uint _383 = 4294967295u;
            int _388 = 0;
            for (; _388 < 4; _383 = _384, _386 = _387, _388++)
            {
                if (sads[_388][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)] < _383)
                {
                    _384 = sads[_388][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)];
                    _387 = uint(_388);
                }
                else
                {
                    _384 = _383;
                    _387 = _386;
                }
            }
            sdk_hlsl_store(rw_optical_flow_next_level, nearestVectors[_386][int(gl_LocalInvocationID.y)][int(gl_LocalInvocationID.x)].xyyy, uint2(uint2(int3(gl_GlobalInvocationID).xy)));
        }
        break;
    } while(false);
}

