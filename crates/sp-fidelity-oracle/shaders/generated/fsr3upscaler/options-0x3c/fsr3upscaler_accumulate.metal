#pragma clang diagnostic ignored "-Wmissing-prototypes"

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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float> r_farthest_depth_mip1 [[texture(3)]], texture2d<float> r_luma_instability [[texture(4)]], texture2d<float, access::read_write> rw_new_locks [[texture(5)]], texture2d<float> r_dilated_motion_vectors [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _116 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _120 = _116 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _125 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _127 = _120 + (cbFSR3Upscaler.fJitter / _125);
    float2 _131 = _125 - float2(0.5);
    float2 _134 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _136 = _120 * _125;
    float2 _141 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_136))), 0u).xy;
    float _143 = length(_141 * float2(3840.0, 2160.0));
    float2 _144 = _120 + _141;
    float _145 = _144.x;
    bool _150;
    if (_145 >= 0.0)
    {
        _150 = _145 <= 1.0;
    }
    else
    {
        _150 = false;
    }
    bool _159;
    if (_150)
    {
        float _153 = _144.y;
        bool _158;
        if (_153 >= 0.0)
        {
            _158 = _153 <= 1.0;
        }
        else
        {
            _158 = false;
        }
        _159 = _158;
    }
    else
    {
        _159 = false;
    }
    uint2 _170 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _176 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _193;
    if (_159)
    {
        _193 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _193 = true;
    }
    float4 _197 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_127 * _125, _131)) / _134), level(0.0));
    float _199 = fast::clamp(_197.x, 0.0, 1.0);
    float _201 = fast::clamp(_197.y, 0.0, 1.0);
    float _203 = fast::clamp(_197.z, 0.0, 1.0);
    float _205 = fast::clamp(_197.w, 0.0, 1.0);
    float _210 = _205 * float(rint(_205 * 100.0) > 1.0);
    bool _214;
    if (_159)
    {
        _214 = !_193;
    }
    else
    {
        _214 = false;
    }
    float3 _770;
    float _771;
    if (_214)
    {
        float2 _221 = (_144 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _223 = _221 - floor(_221);
        int2 _238 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _221.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _221.y)))));
        int2 _239 = _238 + int2(-1);
        int _241 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _245 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _252 = _238 + int2(0, -1);
        int2 _263 = _238 + int2(1, -1);
        int2 _274 = _238 + int2(2, -1);
        int2 _285 = _238 + int2(-1, 0);
        float4 _305 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_238.x, _241)), max(1, min(_238.y, _245))))), 0u);
        int2 _306 = _238 + int2(1, 0);
        float4 _316 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_306.x, _241)), max(1, min(_306.y, _245))))), 0u);
        int2 _317 = _238 + int2(2, 0);
        int2 _328 = _238 + int2(-1, 1);
        int2 _339 = _238 + int2(0, 1);
        float4 _349 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_339.x, _241)), max(1, min(_339.y, _245))))), 0u);
        int2 _350 = _238 + int2(1);
        float4 _360 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_350.x, _241)), max(1, min(_350.y, _245))))), 0u);
        int2 _361 = _238 + int2(2, 1);
        int2 _372 = _238 + int2(-1, 2);
        int2 _383 = _238 + int2(0, 2);
        int2 _394 = _238 + int2(1, 2);
        int2 _405 = _238 + int2(2);
        float _416 = _223.x;
        float _419 = precise::min(abs((-1.0) - _416), 2.0);
        bool _421 = abs(_419) < 6.099999882280826568603515625e-05;
        float _432;
        if (_421)
        {
            _432 = 1.0;
        }
        else
        {
            float _425 = 3.1415927410125732421875 * _419;
            float _428 = 1.57079637050628662109375 * _419;
            _432 = (sin(_425) / _425) * (sin(_428) / _428);
        }
        float _435 = precise::min(abs(-_416), 2.0);
        bool _437 = abs(_435) < 6.099999882280826568603515625e-05;
        float _448;
        if (_437)
        {
            _448 = 1.0;
        }
        else
        {
            float _441 = 3.1415927410125732421875 * _435;
            float _444 = 1.57079637050628662109375 * _435;
            _448 = (sin(_441) / _441) * (sin(_444) / _444);
        }
        float _451 = precise::min(abs(1.0 - _416), 2.0);
        bool _453 = abs(_451) < 6.099999882280826568603515625e-05;
        float _464;
        if (_453)
        {
            _464 = 1.0;
        }
        else
        {
            float _457 = 3.1415927410125732421875 * _451;
            float _460 = 1.57079637050628662109375 * _451;
            _464 = (sin(_457) / _457) * (sin(_460) / _460);
        }
        float _467 = precise::min(abs(2.0 - _416), 2.0);
        bool _469 = abs(_467) < 6.099999882280826568603515625e-05;
        float _480;
        if (_469)
        {
            _480 = 1.0;
        }
        else
        {
            float _473 = 3.1415927410125732421875 * _467;
            float _476 = 1.57079637050628662109375 * _467;
            _480 = (sin(_473) / _473) * (sin(_476) / _476);
        }
        float _503;
        if (_421)
        {
            _503 = 1.0;
        }
        else
        {
            float _496 = 3.1415927410125732421875 * _419;
            float _499 = 1.57079637050628662109375 * _419;
            _503 = (sin(_496) / _496) * (sin(_499) / _499);
        }
        float _514;
        if (_437)
        {
            _514 = 1.0;
        }
        else
        {
            float _507 = 3.1415927410125732421875 * _435;
            float _510 = 1.57079637050628662109375 * _435;
            _514 = (sin(_507) / _507) * (sin(_510) / _510);
        }
        float _525;
        if (_453)
        {
            _525 = 1.0;
        }
        else
        {
            float _518 = 3.1415927410125732421875 * _451;
            float _521 = 1.57079637050628662109375 * _451;
            _525 = (sin(_518) / _518) * (sin(_521) / _521);
        }
        float _536;
        if (_469)
        {
            _536 = 1.0;
        }
        else
        {
            float _529 = 3.1415927410125732421875 * _467;
            float _532 = 1.57079637050628662109375 * _467;
            _536 = (sin(_529) / _529) * (sin(_532) / _532);
        }
        float _559;
        if (_421)
        {
            _559 = 1.0;
        }
        else
        {
            float _552 = 3.1415927410125732421875 * _419;
            float _555 = 1.57079637050628662109375 * _419;
            _559 = (sin(_552) / _552) * (sin(_555) / _555);
        }
        float _570;
        if (_437)
        {
            _570 = 1.0;
        }
        else
        {
            float _563 = 3.1415927410125732421875 * _435;
            float _566 = 1.57079637050628662109375 * _435;
            _570 = (sin(_563) / _563) * (sin(_566) / _566);
        }
        float _581;
        if (_453)
        {
            _581 = 1.0;
        }
        else
        {
            float _574 = 3.1415927410125732421875 * _451;
            float _577 = 1.57079637050628662109375 * _451;
            _581 = (sin(_574) / _574) * (sin(_577) / _577);
        }
        float _592;
        if (_469)
        {
            _592 = 1.0;
        }
        else
        {
            float _585 = 3.1415927410125732421875 * _467;
            float _588 = 1.57079637050628662109375 * _467;
            _592 = (sin(_585) / _585) * (sin(_588) / _588);
        }
        float _615;
        if (_421)
        {
            _615 = 1.0;
        }
        else
        {
            float _608 = 3.1415927410125732421875 * _419;
            float _611 = 1.57079637050628662109375 * _419;
            _615 = (sin(_608) / _608) * (sin(_611) / _611);
        }
        float _626;
        if (_437)
        {
            _626 = 1.0;
        }
        else
        {
            float _619 = 3.1415927410125732421875 * _435;
            float _622 = 1.57079637050628662109375 * _435;
            _626 = (sin(_619) / _619) * (sin(_622) / _622);
        }
        float _637;
        if (_453)
        {
            _637 = 1.0;
        }
        else
        {
            float _630 = 3.1415927410125732421875 * _451;
            float _633 = 1.57079637050628662109375 * _451;
            _637 = (sin(_630) / _630) * (sin(_633) / _633);
        }
        float _648;
        if (_469)
        {
            _648 = 1.0;
        }
        else
        {
            float _641 = 3.1415927410125732421875 * _467;
            float _644 = 1.57079637050628662109375 * _467;
            _648 = (sin(_641) / _641) * (sin(_644) / _644);
        }
        float _661 = _223.y;
        float _664 = precise::min(abs((-1.0) - _661), 2.0);
        float _677;
        if (abs(_664) < 6.099999882280826568603515625e-05)
        {
            _677 = 1.0;
        }
        else
        {
            float _670 = 3.1415927410125732421875 * _664;
            float _673 = 1.57079637050628662109375 * _664;
            _677 = (sin(_670) / _670) * (sin(_673) / _673);
        }
        float _680 = precise::min(abs(-_661), 2.0);
        float _693;
        if (abs(_680) < 6.099999882280826568603515625e-05)
        {
            _693 = 1.0;
        }
        else
        {
            float _686 = 3.1415927410125732421875 * _680;
            float _689 = 1.57079637050628662109375 * _680;
            _693 = (sin(_686) / _686) * (sin(_689) / _689);
        }
        float _696 = precise::min(abs(1.0 - _661), 2.0);
        float _709;
        if (abs(_696) < 6.099999882280826568603515625e-05)
        {
            _709 = 1.0;
        }
        else
        {
            float _702 = 3.1415927410125732421875 * _696;
            float _705 = 1.57079637050628662109375 * _696;
            _709 = (sin(_702) / _702) * (sin(_705) / _705);
        }
        float _712 = precise::min(abs(2.0 - _661), 2.0);
        float _725;
        if (abs(_712) < 6.099999882280826568603515625e-05)
        {
            _725 = 1.0;
        }
        else
        {
            float _718 = 3.1415927410125732421875 * _712;
            float _721 = 1.57079637050628662109375 * _712;
            _725 = (sin(_718) / _718) * (sin(_721) / _721);
        }
        float4 _730 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_239.x, _241)), max(1, min(_239.y, _245))))), 0u) * _432) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_252.x, _241)), max(1, min(_252.y, _245))))), 0u) * _448)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_263.x, _241)), max(1, min(_263.y, _245))))), 0u) * _464)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_274.x, _241)), max(1, min(_274.y, _245))))), 0u) * _480)) / float4(((_432 + _448) + _464) + _480)) * _677) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_285.x, _241)), max(1, min(_285.y, _245))))), 0u) * _503) + (_305 * _514)) + (_316 * _525)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_317.x, _241)), max(1, min(_317.y, _245))))), 0u) * _536)) / float4(((_503 + _514) + _525) + _536)) * _693)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_328.x, _241)), max(1, min(_328.y, _245))))), 0u) * _559) + (_349 * _570)) + (_360 * _581)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_361.x, _241)), max(1, min(_361.y, _245))))), 0u) * _592)) / float4(((_559 + _570) + _581) + _592)) * _709);
        float4 _744 = fast::clamp((_730 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_372.x, _241)), max(1, min(_372.y, _245))))), 0u) * _615) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_383.x, _241)), max(1, min(_383.y, _245))))), 0u) * _626)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_394.x, _241)), max(1, min(_394.y, _245))))), 0u) * _637)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_405.x, _241)), max(1, min(_405.y, _245))))), 0u) * _648)) / float4(((_615 + _626) + _637) + _648)) * _725)) / float4(((_677 + _693) + _709) + _725), precise::min(precise::min(precise::min(_305, _316), _349), _360), precise::max(precise::max(precise::max(_305, _316), _349), _360));
        float4 _750 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _751 = _750.x;
        float3 _754 = (_744.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_751 == 0.0) ? 1.0 : _751);
        float _755 = _754.x;
        float _758 = 0.5 * _754.y;
        float _760 = _754.z;
        float _761 = 0.25 * _760;
        _770 = float3(((0.25 * _755) + _758) + _761, 0.5 * (_755 - _760), (((-0.25) * _755) + _758) - _761);
        _771 = _744.w;
    }
    else
    {
        _770 = float3(0.0);
        _771 = 0.0;
    }
    float _777 = precise::max(fast::clamp(_203, 0.0, 1.0), precise::max(_199, _201));
    float _780 = precise::max(0.0, (_771 * float(!_193)) - (_777 * 2.0));
    uint2 _784 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _801 = _120 - _141;
    float _802 = _801.x;
    bool _807;
    if (_802 >= 0.0)
    {
        _807 = _802 <= 1.0;
    }
    else
    {
        _807 = false;
    }
    bool _816;
    if (_807)
    {
        float _810 = _801.y;
        bool _815;
        if (_810 >= 0.0)
        {
            _815 = _810 <= 1.0;
        }
        else
        {
            _815 = false;
        }
        _816 = _815;
    }
    else
    {
        _816 = false;
    }
    float _826 = precise::min(_210, mix(_210, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_143 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _829 = _116 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _831 = int2(floor(_829));
    float2 _834 = (float2(_831) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _835 = _834 - _829;
    bool _838 = _834.x > _829.x;
    bool _842 = _834.y > _829.y;
    int2 _844 = int2(_838 ? (-2) : (-1), _842 ? (-2) : (-1));
    float2 _845 = float2(_844);
    bool _846 = _210 == 0.0;
    int _847 = _838 ? 3 : 0;
    int _848 = _842 ? 3 : 0;
    int2 _849 = int2(_847, _848);
    int2 _850 = _831 + _844;
    int2 _851 = _850 + _849;
    int _854 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _859 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _869 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _870 = _869.x;
    float3 _873 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_851.x, _854)), max(0, min(_851.y, _859))))), 0u).xyz) * ((_870 == 0.0) ? 1.0 : _870);
    float _874 = _873.x;
    float _877 = 0.5 * _873.y;
    float _879 = _873.z;
    float _880 = 0.25 * _879;
    float3 _887 = float3(((0.25 * _874) + _877) + _880, 0.5 * (_874 - _879), (((-0.25) * _874) + _877) - _880);
    int _888 = _838 ? 2 : 1;
    int2 _889 = int2(_888, _848);
    int2 _890 = _850 + _889;
    float4 _904 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _905 = _904.x;
    float3 _908 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_890.x, _854)), max(0, min(_890.y, _859))))), 0u).xyz) * ((_905 == 0.0) ? 1.0 : _905);
    float _909 = _908.x;
    float _912 = 0.5 * _908.y;
    float _914 = _908.z;
    float _915 = 0.25 * _914;
    float3 _922 = float3(((0.25 * _909) + _912) + _915, 0.5 * (_909 - _914), (((-0.25) * _909) + _912) - _915);
    int _923 = _838 ? 1 : 2;
    int2 _924 = int2(_923, _848);
    int2 _925 = _850 + _924;
    float4 _939 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _940 = _939.x;
    float3 _943 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_925.x, _854)), max(0, min(_925.y, _859))))), 0u).xyz) * ((_940 == 0.0) ? 1.0 : _940);
    float _944 = _943.x;
    float _947 = 0.5 * _943.y;
    float _949 = _943.z;
    float _950 = 0.25 * _949;
    float3 _957 = float3(((0.25 * _944) + _947) + _950, 0.5 * (_944 - _949), (((-0.25) * _944) + _947) - _950);
    int _958 = _842 ? 2 : 1;
    int2 _959 = int2(_847, _958);
    int2 _960 = _850 + _959;
    float4 _974 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _975 = _974.x;
    float3 _978 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_960.x, _854)), max(0, min(_960.y, _859))))), 0u).xyz) * ((_975 == 0.0) ? 1.0 : _975);
    float _979 = _978.x;
    float _982 = 0.5 * _978.y;
    float _984 = _978.z;
    float _985 = 0.25 * _984;
    float3 _992 = float3(((0.25 * _979) + _982) + _985, 0.5 * (_979 - _984), (((-0.25) * _979) + _982) - _985);
    int2 _993 = int2(_888, _958);
    int2 _994 = _850 + _993;
    float4 _1008 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1009 = _1008.x;
    float3 _1012 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_994.x, _854)), max(0, min(_994.y, _859))))), 0u).xyz) * ((_1009 == 0.0) ? 1.0 : _1009);
    float _1013 = _1012.x;
    float _1016 = 0.5 * _1012.y;
    float _1018 = _1012.z;
    float _1019 = 0.25 * _1018;
    float3 _1026 = float3(((0.25 * _1013) + _1016) + _1019, 0.5 * (_1013 - _1018), (((-0.25) * _1013) + _1016) - _1019);
    int2 _1027 = int2(_923, _958);
    int2 _1028 = _850 + _1027;
    float4 _1042 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1043 = _1042.x;
    float3 _1046 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1028.x, _854)), max(0, min(_1028.y, _859))))), 0u).xyz) * ((_1043 == 0.0) ? 1.0 : _1043);
    float _1047 = _1046.x;
    float _1050 = 0.5 * _1046.y;
    float _1052 = _1046.z;
    float _1053 = 0.25 * _1052;
    float3 _1060 = float3(((0.25 * _1047) + _1050) + _1053, 0.5 * (_1047 - _1052), (((-0.25) * _1047) + _1050) - _1053);
    int _1061 = _842 ? 1 : 2;
    int2 _1062 = int2(_847, _1061);
    int2 _1063 = _850 + _1062;
    float4 _1077 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1078 = _1077.x;
    float3 _1081 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1063.x, _854)), max(0, min(_1063.y, _859))))), 0u).xyz) * ((_1078 == 0.0) ? 1.0 : _1078);
    float _1082 = _1081.x;
    float _1085 = 0.5 * _1081.y;
    float _1087 = _1081.z;
    float _1088 = 0.25 * _1087;
    float3 _1095 = float3(((0.25 * _1082) + _1085) + _1088, 0.5 * (_1082 - _1087), (((-0.25) * _1082) + _1085) - _1088);
    int2 _1096 = int2(_888, _1061);
    int2 _1097 = _850 + _1096;
    float4 _1111 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1112 = _1111.x;
    float3 _1115 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1097.x, _854)), max(0, min(_1097.y, _859))))), 0u).xyz) * ((_1112 == 0.0) ? 1.0 : _1112);
    float _1116 = _1115.x;
    float _1119 = 0.5 * _1115.y;
    float _1121 = _1115.z;
    float _1122 = 0.25 * _1121;
    float3 _1129 = float3(((0.25 * _1116) + _1119) + _1122, 0.5 * (_1116 - _1121), (((-0.25) * _1116) + _1119) - _1122);
    int2 _1130 = int2(_923, _1061);
    int2 _1131 = _850 + _1130;
    float4 _1145 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1146 = _1145.x;
    float3 _1149 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1131.x, _854)), max(0, min(_1131.y, _859))))), 0u).xyz) * ((_1146 == 0.0) ? 1.0 : _1146);
    float _1150 = _1149.x;
    float _1153 = 0.5 * _1149.y;
    float _1155 = _1149.z;
    float _1156 = 0.25 * _1155;
    float3 _1163 = float3(((0.25 * _1150) + _1153) + _1156, 0.5 * (_1150 - _1155), (((-0.25) * _1150) + _1153) - _1156);
    float _1168 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1179 = mix(precise::max(1.0, (1.0 + _1168) * 0.300000011920928955078125), _1168, precise::min(1.0 - (_201 * 0.5), precise::min(1.0 - _203, fast::clamp(_826 * 5.0, 0.0, 1.0))));
    float2 _1182 = _835 + (_845 + float2(_849));
    uint2 _1184 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1187 = float(all(uint2(_851) < _1184));
    bool _1188 = !_846;
    float _1206;
    float3 _1207;
    if (_1188)
    {
        float2 _1192 = _1182 * float2(_1179);
        float _1194 = precise::min(dot(_1192, _1192), 4.0);
        float _1196 = (0.4000000059604644775390625 * _1194) - 1.0;
        float _1198 = (0.25 * _1194) - 1.0;
        float _1204 = _1187 * ((((1.5625 * _1196) * _1196) - 0.5625) * (_1198 * _1198));
        _1206 = _1204;
        _1207 = _887 * _1204;
    }
    else
    {
        _1206 = 0.0;
        _1207 = float3(0.0);
    }
    float _1211 = exp((-2.2999999523162841796875) * dot(_1182, _1182)) * _1187;
    float3 _1212 = _887 * _1211;
    float2 _1216 = _835 + (_845 + float2(_889));
    float _1220 = float(all(uint2(_890) < _1184));
    float _1240;
    float3 _1241;
    if (_1188)
    {
        float2 _1224 = _1216 * float2(_1179);
        float _1226 = precise::min(dot(_1224, _1224), 4.0);
        float _1228 = (0.4000000059604644775390625 * _1226) - 1.0;
        float _1230 = (0.25 * _1226) - 1.0;
        float _1236 = _1220 * ((((1.5625 * _1228) * _1228) - 0.5625) * (_1230 * _1230));
        _1240 = _1206 + _1236;
        _1241 = _1207 + (_922 * _1236);
    }
    else
    {
        _1240 = _1206;
        _1241 = _1207;
    }
    float _1245 = exp((-2.2999999523162841796875) * dot(_1216, _1216)) * _1220;
    float3 _1248 = _922 * _1245;
    float2 _1255 = _835 + (_845 + float2(_924));
    float _1259 = float(all(uint2(_925) < _1184));
    float _1279;
    float3 _1280;
    if (_1188)
    {
        float2 _1263 = _1255 * float2(_1179);
        float _1265 = precise::min(dot(_1263, _1263), 4.0);
        float _1267 = (0.4000000059604644775390625 * _1265) - 1.0;
        float _1269 = (0.25 * _1265) - 1.0;
        float _1275 = _1259 * ((((1.5625 * _1267) * _1267) - 0.5625) * (_1269 * _1269));
        _1279 = _1240 + _1275;
        _1280 = _1241 + (_957 * _1275);
    }
    else
    {
        _1279 = _1240;
        _1280 = _1241;
    }
    float _1284 = exp((-2.2999999523162841796875) * dot(_1255, _1255)) * _1259;
    float3 _1287 = _957 * _1284;
    float2 _1294 = _835 + (_845 + float2(_959));
    float _1298 = float(all(uint2(_960) < _1184));
    float _1318;
    float3 _1319;
    if (_1188)
    {
        float2 _1302 = _1294 * float2(_1179);
        float _1304 = precise::min(dot(_1302, _1302), 4.0);
        float _1306 = (0.4000000059604644775390625 * _1304) - 1.0;
        float _1308 = (0.25 * _1304) - 1.0;
        float _1314 = _1298 * ((((1.5625 * _1306) * _1306) - 0.5625) * (_1308 * _1308));
        _1318 = _1279 + _1314;
        _1319 = _1280 + (_992 * _1314);
    }
    else
    {
        _1318 = _1279;
        _1319 = _1280;
    }
    float _1323 = exp((-2.2999999523162841796875) * dot(_1294, _1294)) * _1298;
    float3 _1326 = _992 * _1323;
    float2 _1333 = _835 + (_845 + float2(_993));
    float _1337 = float(all(uint2(_994) < _1184));
    float _1357;
    float3 _1358;
    if (_1188)
    {
        float2 _1341 = _1333 * float2(_1179);
        float _1343 = precise::min(dot(_1341, _1341), 4.0);
        float _1345 = (0.4000000059604644775390625 * _1343) - 1.0;
        float _1347 = (0.25 * _1343) - 1.0;
        float _1353 = _1337 * ((((1.5625 * _1345) * _1345) - 0.5625) * (_1347 * _1347));
        _1357 = _1318 + _1353;
        _1358 = _1319 + (_1026 * _1353);
    }
    else
    {
        _1357 = _1318;
        _1358 = _1319;
    }
    float _1362 = exp((-2.2999999523162841796875) * dot(_1333, _1333)) * _1337;
    float3 _1365 = _1026 * _1362;
    float2 _1372 = _835 + (_845 + float2(_1027));
    float _1376 = float(all(uint2(_1028) < _1184));
    float _1396;
    float3 _1397;
    if (_1188)
    {
        float2 _1380 = _1372 * float2(_1179);
        float _1382 = precise::min(dot(_1380, _1380), 4.0);
        float _1384 = (0.4000000059604644775390625 * _1382) - 1.0;
        float _1386 = (0.25 * _1382) - 1.0;
        float _1392 = _1376 * ((((1.5625 * _1384) * _1384) - 0.5625) * (_1386 * _1386));
        _1396 = _1357 + _1392;
        _1397 = _1358 + (_1060 * _1392);
    }
    else
    {
        _1396 = _1357;
        _1397 = _1358;
    }
    float _1401 = exp((-2.2999999523162841796875) * dot(_1372, _1372)) * _1376;
    float3 _1404 = _1060 * _1401;
    float2 _1411 = _835 + (_845 + float2(_1062));
    float _1415 = float(all(uint2(_1063) < _1184));
    float _1435;
    float3 _1436;
    if (_1188)
    {
        float2 _1419 = _1411 * float2(_1179);
        float _1421 = precise::min(dot(_1419, _1419), 4.0);
        float _1423 = (0.4000000059604644775390625 * _1421) - 1.0;
        float _1425 = (0.25 * _1421) - 1.0;
        float _1431 = _1415 * ((((1.5625 * _1423) * _1423) - 0.5625) * (_1425 * _1425));
        _1435 = _1396 + _1431;
        _1436 = _1397 + (_1095 * _1431);
    }
    else
    {
        _1435 = _1396;
        _1436 = _1397;
    }
    float _1440 = exp((-2.2999999523162841796875) * dot(_1411, _1411)) * _1415;
    float3 _1443 = _1095 * _1440;
    float2 _1450 = _835 + (_845 + float2(_1096));
    float _1454 = float(all(uint2(_1097) < _1184));
    float _1474;
    float3 _1475;
    if (_1188)
    {
        float2 _1458 = _1450 * float2(_1179);
        float _1460 = precise::min(dot(_1458, _1458), 4.0);
        float _1462 = (0.4000000059604644775390625 * _1460) - 1.0;
        float _1464 = (0.25 * _1460) - 1.0;
        float _1470 = _1454 * ((((1.5625 * _1462) * _1462) - 0.5625) * (_1464 * _1464));
        _1474 = _1435 + _1470;
        _1475 = _1436 + (_1129 * _1470);
    }
    else
    {
        _1474 = _1435;
        _1475 = _1436;
    }
    float _1479 = exp((-2.2999999523162841796875) * dot(_1450, _1450)) * _1454;
    float3 _1482 = _1129 * _1479;
    float2 _1489 = _835 + (_845 + float2(_1130));
    float _1493 = float(all(uint2(_1131) < _1184));
    float _1513;
    float3 _1514;
    if (_1188)
    {
        float2 _1497 = _1489 * float2(_1179);
        float _1499 = precise::min(dot(_1497, _1497), 4.0);
        float _1501 = (0.4000000059604644775390625 * _1499) - 1.0;
        float _1503 = (0.25 * _1499) - 1.0;
        float _1509 = _1493 * ((((1.5625 * _1501) * _1501) - 0.5625) * (_1503 * _1503));
        _1513 = _1474 + _1509;
        _1514 = _1475 + (_1163 * _1509);
    }
    else
    {
        _1513 = _1474;
        _1514 = _1475;
    }
    float _1518 = exp((-2.2999999523162841796875) * dot(_1489, _1489)) * _1493;
    float3 _1521 = _1163 * _1518;
    float _1525 = (((((((_1211 + _1245) + _1284) + _1323) + _1362) + _1401) + _1440) + _1479) + _1518;
    float3 _1529 = float3((abs(_1525) > 1.1754943508222875079687365372222e-38) ? _1525 : 1.0);
    float3 _1530 = ((((((((_1212 + _1248) + _1287) + _1326) + _1365) + _1404) + _1443) + _1482) + _1521) / _1529;
    float _1538 = _1513 * float(_1513 > 6.099999882280826568603515625e-05);
    float3 _1546;
    float _1547;
    if (_1538 > 6.099999882280826568603515625e-05)
    {
        _1546 = fast::clamp(_1514 / float3(_1538), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_887, _922), _957), _992), _1026), _1060), _1095), _1129), _1163), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_887, _922), _957), _992), _1026), _1060), _1095), _1129), _1163));
        _1547 = _1538 * 0.04625000059604644775390625;
    }
    else
    {
        _1546 = _1514;
        _1547 = _1538;
    }
    float _1550 = _846 ? 1.0 : _1547;
    float _1551 = _846 ? 0.0 : _826;
    float3 _1565 = (sqrt(abs(((((((((((_887 * _1212) + (_922 * _1248)) + (_957 * _1287)) + (_992 * _1326)) + (_1026 * _1365)) + (_1060 * _1404)) + (_1095 * _1443)) + (_1129 * _1482)) + (_1163 * _1521)) / _1529) - (_1530 * _1530))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_143 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_127 * _176, _176 - float2(0.5))) / float2(int2(int(_170.x), int(_170.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _210, precise::max(powr(_199, 0.5), _203)))));
    float3 _1568 = (_770 - _1530) / precise::max(_1565, float3(1.19299997436428384389728307724e-07));
    float3 _1583;
    if (length(_1568) > 1.0)
    {
        _1583 = mix((fast::normalize(_1568) * _1565) + _1530, _770, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_136, _131)) / _134), level(0.0)).x, fast::clamp(fast::clamp(_780 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _210) * (1.0 - _201), 0.0, 1.0)));
    }
    else
    {
        _1583 = _770;
    }
    float3 _1592 = mix(_1583, select(_1546, _1530, bool3(_846)), float3(fast::clamp(_1550 / precise::max(6.099999882280826568603515625e-05, (_1551 * float(_1551 > 6.099999882280826568603515625e-05)) + _1550), 0.0, 1.0)));
    float _1593 = _1592.x;
    float _1594 = _1592.y;
    float _1596 = _1592.z;
    float4 _1603 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1604 = _1603.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max(float3((_1593 + _1594) - _1596, _1593 + _1596, (_1593 - _1594) - _1596) / float3((_1604 == 0.0) ? 1.0 : _1604), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_780 + (sdk_hlsl_load(rw_new_locks, uint2(_784)).x * (1.0 - precise::max(0.0, _199))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _777))) * float(_816)), uint2(_784));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_784));
}

