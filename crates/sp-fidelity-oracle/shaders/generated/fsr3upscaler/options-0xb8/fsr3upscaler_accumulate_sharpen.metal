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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(3)]], texture2d<float> r_farthest_depth_mip1 [[texture(4)]], texture2d<float> r_luma_instability [[texture(5)]], texture2d<float, access::read_write> rw_new_locks [[texture(6)]], texture2d<float> r_input_exposure [[texture(7)]], texture2d<float> r_dilated_reactive_masks [[texture(8)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _124 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _127 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _128 = _124 / _127;
    float2 _133 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _135 = _128 + (cbFSR3Upscaler.fJitter / _133);
    float2 _139 = _133 - float2(0.5);
    float2 _142 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _144 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _153 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_144), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _155 = length(_153 * float2(3840.0, 2160.0));
    float2 _156 = _128 + _153;
    float _157 = _156.x;
    bool _162;
    if (_157 >= 0.0)
    {
        _162 = _157 <= 1.0;
    }
    else
    {
        _162 = false;
    }
    bool _171;
    if (_162)
    {
        float _165 = _156.y;
        bool _170;
        if (_165 >= 0.0)
        {
            _170 = _165 <= 1.0;
        }
        else
        {
            _170 = false;
        }
        _171 = _170;
    }
    else
    {
        _171 = false;
    }
    uint2 _183 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _189 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _206;
    if (_171)
    {
        _206 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _206 = true;
    }
    float4 _210 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _133, _139)) / _142), level(0.0));
    float _212 = fast::clamp(_210.x, 0.0, 1.0);
    float _214 = fast::clamp(_210.y, 0.0, 1.0);
    float _216 = fast::clamp(_210.z, 0.0, 1.0);
    float _218 = fast::clamp(_210.w, 0.0, 1.0);
    float _223 = _218 * float(rint(_218 * 100.0) > 1.0);
    bool _227;
    if (_171)
    {
        _227 = !_206;
    }
    else
    {
        _227 = false;
    }
    float3 _824;
    float _825;
    if (_227)
    {
        float2 _231 = (_156 * _127) - float2(0.5);
        half2 _234 = half2(_231 - floor(_231));
        int2 _247 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _231.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _231.y)))));
        int2 _248 = _247 + int2(-1);
        int _250 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _254 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _262 = _247 + int2(0, -1);
        int2 _274 = _247 + int2(1, -1);
        int2 _286 = _247 + int2(2, -1);
        int2 _298 = _247 + int2(-1, 0);
        half4 _320 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_247.x, _250)), max(1, min(_247.y, _254))))), 0u));
        int2 _321 = _247 + int2(1, 0);
        half4 _332 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_321.x, _250)), max(1, min(_321.y, _254))))), 0u));
        int2 _333 = _247 + int2(2, 0);
        int2 _345 = _247 + int2(-1, 1);
        int2 _357 = _247 + int2(0, 1);
        half4 _368 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_357.x, _250)), max(1, min(_357.y, _254))))), 0u));
        int2 _369 = _247 + int2(1);
        half4 _380 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_369.x, _250)), max(1, min(_369.y, _254))))), 0u));
        int2 _381 = _247 + int2(2, 1);
        int2 _393 = _247 + int2(-1, 2);
        int2 _405 = _247 + int2(0, 2);
        int2 _417 = _247 + int2(1, 2);
        int2 _429 = _247 + int2(2);
        half _441 = _234.x;
        float _445 = float(min(abs(half(-1.0) - _441), half(2.0)));
        bool _447 = abs(_445) < 6.099999882280826568603515625e-05;
        float _458;
        if (_447)
        {
            _458 = 1.0;
        }
        else
        {
            float _451 = 3.1415927410125732421875 * _445;
            float _454 = 1.57079637050628662109375 * _445;
            _458 = (sin(_451) / _451) * (sin(_454) / _454);
        }
        half _459 = half(_458);
        float _463 = float(min(abs(half(-0.0) - _441), half(2.0)));
        bool _465 = abs(_463) < 6.099999882280826568603515625e-05;
        float _476;
        if (_465)
        {
            _476 = 1.0;
        }
        else
        {
            float _469 = 3.1415927410125732421875 * _463;
            float _472 = 1.57079637050628662109375 * _463;
            _476 = (sin(_469) / _469) * (sin(_472) / _472);
        }
        half _477 = half(_476);
        float _481 = float(min(abs(half(1.0) - _441), half(2.0)));
        bool _483 = abs(_481) < 6.099999882280826568603515625e-05;
        float _494;
        if (_483)
        {
            _494 = 1.0;
        }
        else
        {
            float _487 = 3.1415927410125732421875 * _481;
            float _490 = 1.57079637050628662109375 * _481;
            _494 = (sin(_487) / _487) * (sin(_490) / _490);
        }
        half _495 = half(_494);
        float _499 = float(min(abs(half(2.0) - _441), half(2.0)));
        bool _501 = abs(_499) < 6.099999882280826568603515625e-05;
        float _512;
        if (_501)
        {
            _512 = 1.0;
        }
        else
        {
            float _505 = 3.1415927410125732421875 * _499;
            float _508 = 1.57079637050628662109375 * _499;
            _512 = (sin(_505) / _505) * (sin(_508) / _508);
        }
        half _513 = half(_512);
        float _536;
        if (_447)
        {
            _536 = 1.0;
        }
        else
        {
            float _529 = 3.1415927410125732421875 * _445;
            float _532 = 1.57079637050628662109375 * _445;
            _536 = (sin(_529) / _529) * (sin(_532) / _532);
        }
        half _537 = half(_536);
        float _548;
        if (_465)
        {
            _548 = 1.0;
        }
        else
        {
            float _541 = 3.1415927410125732421875 * _463;
            float _544 = 1.57079637050628662109375 * _463;
            _548 = (sin(_541) / _541) * (sin(_544) / _544);
        }
        half _549 = half(_548);
        float _560;
        if (_483)
        {
            _560 = 1.0;
        }
        else
        {
            float _553 = 3.1415927410125732421875 * _481;
            float _556 = 1.57079637050628662109375 * _481;
            _560 = (sin(_553) / _553) * (sin(_556) / _556);
        }
        half _561 = half(_560);
        float _572;
        if (_501)
        {
            _572 = 1.0;
        }
        else
        {
            float _565 = 3.1415927410125732421875 * _499;
            float _568 = 1.57079637050628662109375 * _499;
            _572 = (sin(_565) / _565) * (sin(_568) / _568);
        }
        half _573 = half(_572);
        float _596;
        if (_447)
        {
            _596 = 1.0;
        }
        else
        {
            float _589 = 3.1415927410125732421875 * _445;
            float _592 = 1.57079637050628662109375 * _445;
            _596 = (sin(_589) / _589) * (sin(_592) / _592);
        }
        half _597 = half(_596);
        float _608;
        if (_465)
        {
            _608 = 1.0;
        }
        else
        {
            float _601 = 3.1415927410125732421875 * _463;
            float _604 = 1.57079637050628662109375 * _463;
            _608 = (sin(_601) / _601) * (sin(_604) / _604);
        }
        half _609 = half(_608);
        float _620;
        if (_483)
        {
            _620 = 1.0;
        }
        else
        {
            float _613 = 3.1415927410125732421875 * _481;
            float _616 = 1.57079637050628662109375 * _481;
            _620 = (sin(_613) / _613) * (sin(_616) / _616);
        }
        half _621 = half(_620);
        float _632;
        if (_501)
        {
            _632 = 1.0;
        }
        else
        {
            float _625 = 3.1415927410125732421875 * _499;
            float _628 = 1.57079637050628662109375 * _499;
            _632 = (sin(_625) / _625) * (sin(_628) / _628);
        }
        half _633 = half(_632);
        float _656;
        if (_447)
        {
            _656 = 1.0;
        }
        else
        {
            float _649 = 3.1415927410125732421875 * _445;
            float _652 = 1.57079637050628662109375 * _445;
            _656 = (sin(_649) / _649) * (sin(_652) / _652);
        }
        half _657 = half(_656);
        float _668;
        if (_465)
        {
            _668 = 1.0;
        }
        else
        {
            float _661 = 3.1415927410125732421875 * _463;
            float _664 = 1.57079637050628662109375 * _463;
            _668 = (sin(_661) / _661) * (sin(_664) / _664);
        }
        half _669 = half(_668);
        float _680;
        if (_483)
        {
            _680 = 1.0;
        }
        else
        {
            float _673 = 3.1415927410125732421875 * _481;
            float _676 = 1.57079637050628662109375 * _481;
            _680 = (sin(_673) / _673) * (sin(_676) / _676);
        }
        half _681 = half(_680);
        float _692;
        if (_501)
        {
            _692 = 1.0;
        }
        else
        {
            float _685 = 3.1415927410125732421875 * _499;
            float _688 = 1.57079637050628662109375 * _499;
            _692 = (sin(_685) / _685) * (sin(_688) / _688);
        }
        half _693 = half(_692);
        half _706 = _234.y;
        float _710 = float(min(abs(half(-1.0) - _706), half(2.0)));
        float _723;
        if (abs(_710) < 6.099999882280826568603515625e-05)
        {
            _723 = 1.0;
        }
        else
        {
            float _716 = 3.1415927410125732421875 * _710;
            float _719 = 1.57079637050628662109375 * _710;
            _723 = (sin(_716) / _716) * (sin(_719) / _719);
        }
        half _724 = half(_723);
        float _728 = float(min(abs(half(-0.0) - _706), half(2.0)));
        float _741;
        if (abs(_728) < 6.099999882280826568603515625e-05)
        {
            _741 = 1.0;
        }
        else
        {
            float _734 = 3.1415927410125732421875 * _728;
            float _737 = 1.57079637050628662109375 * _728;
            _741 = (sin(_734) / _734) * (sin(_737) / _737);
        }
        half _742 = half(_741);
        float _746 = float(min(abs(half(1.0) - _706), half(2.0)));
        float _759;
        if (abs(_746) < 6.099999882280826568603515625e-05)
        {
            _759 = 1.0;
        }
        else
        {
            float _752 = 3.1415927410125732421875 * _746;
            float _755 = 1.57079637050628662109375 * _746;
            _759 = (sin(_752) / _752) * (sin(_755) / _755);
        }
        half _760 = half(_759);
        float _764 = float(min(abs(half(2.0) - _706), half(2.0)));
        float _777;
        if (abs(_764) < 6.099999882280826568603515625e-05)
        {
            _777 = 1.0;
        }
        else
        {
            float _770 = 3.1415927410125732421875 * _764;
            float _773 = 1.57079637050628662109375 * _764;
            _777 = (sin(_770) / _770) * (sin(_773) / _773);
        }
        half _778 = half(_777);
        half4 _783 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_248.x, _250)), max(1, min(_248.y, _254))))), 0u)) * _459) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_262.x, _250)), max(1, min(_262.y, _254))))), 0u)) * _477)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_274.x, _250)), max(1, min(_274.y, _254))))), 0u)) * _495)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_286.x, _250)), max(1, min(_286.y, _254))))), 0u)) * _513)) / half4(((_459 + _477) + _495) + _513)) * _724) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_298.x, _250)), max(1, min(_298.y, _254))))), 0u)) * _537) + (_320 * _549)) + (_332 * _561)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_333.x, _250)), max(1, min(_333.y, _254))))), 0u)) * _573)) / half4(((_537 + _549) + _561) + _573)) * _742)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_345.x, _250)), max(1, min(_345.y, _254))))), 0u)) * _597) + (_368 * _609)) + (_380 * _621)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_381.x, _250)), max(1, min(_381.y, _254))))), 0u)) * _633)) / half4(((_597 + _609) + _621) + _633)) * _760);
        half4 _790 = (_783 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_393.x, _250)), max(1, min(_393.y, _254))))), 0u)) * _657) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_405.x, _250)), max(1, min(_405.y, _254))))), 0u)) * _669)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_417.x, _250)), max(1, min(_417.y, _254))))), 0u)) * _681)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_429.x, _250)), max(1, min(_429.y, _254))))), 0u)) * _693)) / half4(((_657 + _669) + _681) + _693)) * _778)) / half4(((_724 + _742) + _760) + _778);
        float4 _798 = float4(clamp(_790, min(min(min(_320, _332), _368), _380), max(max(max(_320, _332), _368), _380)));
        float4 _804 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _805 = _804.x;
        float3 _808 = (_798.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_805 == 0.0) ? 1.0 : _805);
        float _812 = 0.5 * _808.y;
        float _815 = 0.25 * _808.z;
        _824 = float3(((0.25 * _808.x) + _812) + _815, 0.5 * (_808.x - _808.z), (((-0.25) * _808.x) + _812) - _815);
        _825 = _798.w;
    }
    else
    {
        _824 = float3(0.0);
        _825 = 0.0;
    }
    float _831 = precise::max(fast::clamp(_216, 0.0, 1.0), precise::max(_212, _214));
    float _834 = precise::max(0.0, (_825 * float(!_206)) - (_831 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _854 = _128 - _153;
    float _855 = _854.x;
    bool _860;
    if (_855 >= 0.0)
    {
        _860 = _855 <= 1.0;
    }
    else
    {
        _860 = false;
    }
    bool _869;
    if (_860)
    {
        float _863 = _854.y;
        bool _868;
        if (_863 >= 0.0)
        {
            _868 = _863 <= 1.0;
        }
        else
        {
            _868 = false;
        }
        _869 = _868;
    }
    else
    {
        _869 = false;
    }
    float _879 = precise::min(_223, mix(_223, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_155 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _882 = _124 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _884 = int2(floor(_882));
    float2 _887 = (float2(_884) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _888 = _887 - _882;
    bool _891 = _887.x > _882.x;
    bool _895 = _887.y > _882.y;
    int2 _897 = int2(_891 ? (-2) : (-1), _895 ? (-2) : (-1));
    float2 _898 = float2(_897);
    bool _899 = _223 == 0.0;
    int _900 = _891 ? 3 : 0;
    int _901 = _895 ? 3 : 0;
    int2 _902 = int2(_900, _901);
    int2 _903 = _884 + _897;
    int2 _904 = _903 + _902;
    int _907 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _912 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _922 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _923 = _922.x;
    float3 _926 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_904.x, _907)), max(0, min(_904.y, _912))))), 0u).xyz) * ((_923 == 0.0) ? 1.0 : _923);
    float _927 = _926.x;
    float _930 = 0.5 * _926.y;
    float _932 = _926.z;
    float _933 = 0.25 * _932;
    float3 _940 = float3(((0.25 * _927) + _930) + _933, 0.5 * (_927 - _932), (((-0.25) * _927) + _930) - _933);
    int _941 = _891 ? 2 : 1;
    int2 _942 = int2(_941, _901);
    int2 _943 = _903 + _942;
    float4 _957 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _958 = _957.x;
    float3 _961 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_943.x, _907)), max(0, min(_943.y, _912))))), 0u).xyz) * ((_958 == 0.0) ? 1.0 : _958);
    float _962 = _961.x;
    float _965 = 0.5 * _961.y;
    float _967 = _961.z;
    float _968 = 0.25 * _967;
    float3 _975 = float3(((0.25 * _962) + _965) + _968, 0.5 * (_962 - _967), (((-0.25) * _962) + _965) - _968);
    int _976 = _891 ? 1 : 2;
    int2 _977 = int2(_976, _901);
    int2 _978 = _903 + _977;
    float4 _992 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _993 = _992.x;
    float3 _996 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_978.x, _907)), max(0, min(_978.y, _912))))), 0u).xyz) * ((_993 == 0.0) ? 1.0 : _993);
    float _997 = _996.x;
    float _1000 = 0.5 * _996.y;
    float _1002 = _996.z;
    float _1003 = 0.25 * _1002;
    float3 _1010 = float3(((0.25 * _997) + _1000) + _1003, 0.5 * (_997 - _1002), (((-0.25) * _997) + _1000) - _1003);
    int _1011 = _895 ? 2 : 1;
    int2 _1012 = int2(_900, _1011);
    int2 _1013 = _903 + _1012;
    float4 _1027 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1028 = _1027.x;
    float3 _1031 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1013.x, _907)), max(0, min(_1013.y, _912))))), 0u).xyz) * ((_1028 == 0.0) ? 1.0 : _1028);
    float _1032 = _1031.x;
    float _1035 = 0.5 * _1031.y;
    float _1037 = _1031.z;
    float _1038 = 0.25 * _1037;
    float3 _1045 = float3(((0.25 * _1032) + _1035) + _1038, 0.5 * (_1032 - _1037), (((-0.25) * _1032) + _1035) - _1038);
    int2 _1046 = int2(_941, _1011);
    int2 _1047 = _903 + _1046;
    float4 _1061 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1062 = _1061.x;
    float3 _1065 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1047.x, _907)), max(0, min(_1047.y, _912))))), 0u).xyz) * ((_1062 == 0.0) ? 1.0 : _1062);
    float _1066 = _1065.x;
    float _1069 = 0.5 * _1065.y;
    float _1071 = _1065.z;
    float _1072 = 0.25 * _1071;
    float3 _1079 = float3(((0.25 * _1066) + _1069) + _1072, 0.5 * (_1066 - _1071), (((-0.25) * _1066) + _1069) - _1072);
    int2 _1080 = int2(_976, _1011);
    int2 _1081 = _903 + _1080;
    float4 _1095 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1096 = _1095.x;
    float3 _1099 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1081.x, _907)), max(0, min(_1081.y, _912))))), 0u).xyz) * ((_1096 == 0.0) ? 1.0 : _1096);
    float _1100 = _1099.x;
    float _1103 = 0.5 * _1099.y;
    float _1105 = _1099.z;
    float _1106 = 0.25 * _1105;
    float3 _1113 = float3(((0.25 * _1100) + _1103) + _1106, 0.5 * (_1100 - _1105), (((-0.25) * _1100) + _1103) - _1106);
    int _1114 = _895 ? 1 : 2;
    int2 _1115 = int2(_900, _1114);
    int2 _1116 = _903 + _1115;
    float4 _1130 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1131 = _1130.x;
    float3 _1134 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1116.x, _907)), max(0, min(_1116.y, _912))))), 0u).xyz) * ((_1131 == 0.0) ? 1.0 : _1131);
    float _1135 = _1134.x;
    float _1138 = 0.5 * _1134.y;
    float _1140 = _1134.z;
    float _1141 = 0.25 * _1140;
    float3 _1148 = float3(((0.25 * _1135) + _1138) + _1141, 0.5 * (_1135 - _1140), (((-0.25) * _1135) + _1138) - _1141);
    int2 _1149 = int2(_941, _1114);
    int2 _1150 = _903 + _1149;
    float4 _1164 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1165 = _1164.x;
    float3 _1168 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1150.x, _907)), max(0, min(_1150.y, _912))))), 0u).xyz) * ((_1165 == 0.0) ? 1.0 : _1165);
    float _1169 = _1168.x;
    float _1172 = 0.5 * _1168.y;
    float _1174 = _1168.z;
    float _1175 = 0.25 * _1174;
    float3 _1182 = float3(((0.25 * _1169) + _1172) + _1175, 0.5 * (_1169 - _1174), (((-0.25) * _1169) + _1172) - _1175);
    int2 _1183 = int2(_976, _1114);
    int2 _1184 = _903 + _1183;
    float4 _1198 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1199 = _1198.x;
    float3 _1202 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1184.x, _907)), max(0, min(_1184.y, _912))))), 0u).xyz) * ((_1199 == 0.0) ? 1.0 : _1199);
    float _1203 = _1202.x;
    float _1206 = 0.5 * _1202.y;
    float _1208 = _1202.z;
    float _1209 = 0.25 * _1208;
    float3 _1216 = float3(((0.25 * _1203) + _1206) + _1209, 0.5 * (_1203 - _1208), (((-0.25) * _1203) + _1206) - _1209);
    float _1221 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1232 = mix(precise::max(1.0, (1.0 + _1221) * 0.300000011920928955078125), _1221, precise::min(1.0 - (_214 * 0.5), precise::min(1.0 - _216, fast::clamp(_879 * 5.0, 0.0, 1.0))));
    float2 _1235 = _888 + (_898 + float2(_902));
    uint2 _1237 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1240 = float(all(uint2(_904) < _1237));
    bool _1241 = !_899;
    float _1259;
    float3 _1260;
    if (_1241)
    {
        float2 _1245 = _1235 * float2(_1232);
        float _1247 = precise::min(dot(_1245, _1245), 4.0);
        float _1249 = (0.4000000059604644775390625 * _1247) - 1.0;
        float _1251 = (0.25 * _1247) - 1.0;
        float _1257 = _1240 * ((((1.5625 * _1249) * _1249) - 0.5625) * (_1251 * _1251));
        _1259 = _1257;
        _1260 = _940 * _1257;
    }
    else
    {
        _1259 = 0.0;
        _1260 = float3(0.0);
    }
    float _1264 = exp((-2.2999999523162841796875) * dot(_1235, _1235)) * _1240;
    float3 _1265 = _940 * _1264;
    float2 _1269 = _888 + (_898 + float2(_942));
    float _1273 = float(all(uint2(_943) < _1237));
    float _1293;
    float3 _1294;
    if (_1241)
    {
        float2 _1277 = _1269 * float2(_1232);
        float _1279 = precise::min(dot(_1277, _1277), 4.0);
        float _1281 = (0.4000000059604644775390625 * _1279) - 1.0;
        float _1283 = (0.25 * _1279) - 1.0;
        float _1289 = _1273 * ((((1.5625 * _1281) * _1281) - 0.5625) * (_1283 * _1283));
        _1293 = _1259 + _1289;
        _1294 = _1260 + (_975 * _1289);
    }
    else
    {
        _1293 = _1259;
        _1294 = _1260;
    }
    float _1298 = exp((-2.2999999523162841796875) * dot(_1269, _1269)) * _1273;
    float3 _1301 = _975 * _1298;
    float2 _1308 = _888 + (_898 + float2(_977));
    float _1312 = float(all(uint2(_978) < _1237));
    float _1332;
    float3 _1333;
    if (_1241)
    {
        float2 _1316 = _1308 * float2(_1232);
        float _1318 = precise::min(dot(_1316, _1316), 4.0);
        float _1320 = (0.4000000059604644775390625 * _1318) - 1.0;
        float _1322 = (0.25 * _1318) - 1.0;
        float _1328 = _1312 * ((((1.5625 * _1320) * _1320) - 0.5625) * (_1322 * _1322));
        _1332 = _1293 + _1328;
        _1333 = _1294 + (_1010 * _1328);
    }
    else
    {
        _1332 = _1293;
        _1333 = _1294;
    }
    float _1337 = exp((-2.2999999523162841796875) * dot(_1308, _1308)) * _1312;
    float3 _1340 = _1010 * _1337;
    float2 _1347 = _888 + (_898 + float2(_1012));
    float _1351 = float(all(uint2(_1013) < _1237));
    float _1371;
    float3 _1372;
    if (_1241)
    {
        float2 _1355 = _1347 * float2(_1232);
        float _1357 = precise::min(dot(_1355, _1355), 4.0);
        float _1359 = (0.4000000059604644775390625 * _1357) - 1.0;
        float _1361 = (0.25 * _1357) - 1.0;
        float _1367 = _1351 * ((((1.5625 * _1359) * _1359) - 0.5625) * (_1361 * _1361));
        _1371 = _1332 + _1367;
        _1372 = _1333 + (_1045 * _1367);
    }
    else
    {
        _1371 = _1332;
        _1372 = _1333;
    }
    float _1376 = exp((-2.2999999523162841796875) * dot(_1347, _1347)) * _1351;
    float3 _1379 = _1045 * _1376;
    float2 _1386 = _888 + (_898 + float2(_1046));
    float _1390 = float(all(uint2(_1047) < _1237));
    float _1410;
    float3 _1411;
    if (_1241)
    {
        float2 _1394 = _1386 * float2(_1232);
        float _1396 = precise::min(dot(_1394, _1394), 4.0);
        float _1398 = (0.4000000059604644775390625 * _1396) - 1.0;
        float _1400 = (0.25 * _1396) - 1.0;
        float _1406 = _1390 * ((((1.5625 * _1398) * _1398) - 0.5625) * (_1400 * _1400));
        _1410 = _1371 + _1406;
        _1411 = _1372 + (_1079 * _1406);
    }
    else
    {
        _1410 = _1371;
        _1411 = _1372;
    }
    float _1415 = exp((-2.2999999523162841796875) * dot(_1386, _1386)) * _1390;
    float3 _1418 = _1079 * _1415;
    float2 _1425 = _888 + (_898 + float2(_1080));
    float _1429 = float(all(uint2(_1081) < _1237));
    float _1449;
    float3 _1450;
    if (_1241)
    {
        float2 _1433 = _1425 * float2(_1232);
        float _1435 = precise::min(dot(_1433, _1433), 4.0);
        float _1437 = (0.4000000059604644775390625 * _1435) - 1.0;
        float _1439 = (0.25 * _1435) - 1.0;
        float _1445 = _1429 * ((((1.5625 * _1437) * _1437) - 0.5625) * (_1439 * _1439));
        _1449 = _1410 + _1445;
        _1450 = _1411 + (_1113 * _1445);
    }
    else
    {
        _1449 = _1410;
        _1450 = _1411;
    }
    float _1454 = exp((-2.2999999523162841796875) * dot(_1425, _1425)) * _1429;
    float3 _1457 = _1113 * _1454;
    float2 _1464 = _888 + (_898 + float2(_1115));
    float _1468 = float(all(uint2(_1116) < _1237));
    float _1488;
    float3 _1489;
    if (_1241)
    {
        float2 _1472 = _1464 * float2(_1232);
        float _1474 = precise::min(dot(_1472, _1472), 4.0);
        float _1476 = (0.4000000059604644775390625 * _1474) - 1.0;
        float _1478 = (0.25 * _1474) - 1.0;
        float _1484 = _1468 * ((((1.5625 * _1476) * _1476) - 0.5625) * (_1478 * _1478));
        _1488 = _1449 + _1484;
        _1489 = _1450 + (_1148 * _1484);
    }
    else
    {
        _1488 = _1449;
        _1489 = _1450;
    }
    float _1493 = exp((-2.2999999523162841796875) * dot(_1464, _1464)) * _1468;
    float3 _1496 = _1148 * _1493;
    float2 _1503 = _888 + (_898 + float2(_1149));
    float _1507 = float(all(uint2(_1150) < _1237));
    float _1527;
    float3 _1528;
    if (_1241)
    {
        float2 _1511 = _1503 * float2(_1232);
        float _1513 = precise::min(dot(_1511, _1511), 4.0);
        float _1515 = (0.4000000059604644775390625 * _1513) - 1.0;
        float _1517 = (0.25 * _1513) - 1.0;
        float _1523 = _1507 * ((((1.5625 * _1515) * _1515) - 0.5625) * (_1517 * _1517));
        _1527 = _1488 + _1523;
        _1528 = _1489 + (_1182 * _1523);
    }
    else
    {
        _1527 = _1488;
        _1528 = _1489;
    }
    float _1532 = exp((-2.2999999523162841796875) * dot(_1503, _1503)) * _1507;
    float3 _1535 = _1182 * _1532;
    float2 _1542 = _888 + (_898 + float2(_1183));
    float _1546 = float(all(uint2(_1184) < _1237));
    float _1566;
    float3 _1567;
    if (_1241)
    {
        float2 _1550 = _1542 * float2(_1232);
        float _1552 = precise::min(dot(_1550, _1550), 4.0);
        float _1554 = (0.4000000059604644775390625 * _1552) - 1.0;
        float _1556 = (0.25 * _1552) - 1.0;
        float _1562 = _1546 * ((((1.5625 * _1554) * _1554) - 0.5625) * (_1556 * _1556));
        _1566 = _1527 + _1562;
        _1567 = _1528 + (_1216 * _1562);
    }
    else
    {
        _1566 = _1527;
        _1567 = _1528;
    }
    float _1571 = exp((-2.2999999523162841796875) * dot(_1542, _1542)) * _1546;
    float3 _1574 = _1216 * _1571;
    float _1578 = (((((((_1264 + _1298) + _1337) + _1376) + _1415) + _1454) + _1493) + _1532) + _1571;
    float3 _1582 = float3((abs(_1578) > 1.1754943508222875079687365372222e-38) ? _1578 : 1.0);
    float3 _1583 = ((((((((_1265 + _1301) + _1340) + _1379) + _1418) + _1457) + _1496) + _1535) + _1574) / _1582;
    float _1591 = _1566 * float(_1566 > 6.099999882280826568603515625e-05);
    float3 _1599;
    float _1600;
    if (_1591 > 6.099999882280826568603515625e-05)
    {
        _1599 = fast::clamp(_1567 / float3(_1591), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_940, _975), _1010), _1045), _1079), _1113), _1148), _1182), _1216), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_940, _975), _1010), _1045), _1079), _1113), _1148), _1182), _1216));
        _1600 = _1591 * 0.04625000059604644775390625;
    }
    else
    {
        _1599 = _1567;
        _1600 = _1591;
    }
    float _1603 = _899 ? 1.0 : _1600;
    float _1604 = _899 ? 0.0 : _879;
    float3 _1618 = (sqrt(abs(((((((((((_940 * _1265) + (_975 * _1301)) + (_1010 * _1340)) + (_1045 * _1379)) + (_1079 * _1418)) + (_1113 * _1457)) + (_1148 * _1496)) + (_1182 * _1535)) + (_1216 * _1574)) / _1582) - (_1583 * _1583))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_155 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_135 * _189, _189 - float2(0.5))) / float2(int2(int(_183.x), int(_183.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _223, precise::max(powr(_212, 0.5), _216)))));
    float3 _1621 = (_824 - _1583) / precise::max(_1618, float3(1.19299997436428384389728307724e-07));
    float3 _1636;
    if (length(_1621) > 1.0)
    {
        _1636 = mix((fast::normalize(_1621) * _1618) + _1583, _824, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_128 * _133, _139)) / _142), level(0.0)).x, fast::clamp(fast::clamp(_834 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _223) * (1.0 - _214), 0.0, 1.0)));
    }
    else
    {
        _1636 = _824;
    }
    float3 _1645 = mix(_1636, select(_1599, _1583, bool3(_899)), float3(fast::clamp(_1603 / precise::max(6.099999882280826568603515625e-05, (_1604 * float(_1604 > 6.099999882280826568603515625e-05)) + _1603), 0.0, 1.0)));
    float _1646 = _1645.x;
    float _1647 = _1645.y;
    float _1649 = _1645.z;
    float4 _1656 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1657 = _1656.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max(float3((_1646 + _1647) - _1649, _1646 + _1649, (_1646 - _1647) - _1649) / float3((_1657 == 0.0) ? 1.0 : _1657), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_834 + (sdk_hlsl_load(rw_new_locks, uint2(_144)).x * (1.0 - precise::max(0.0, _212))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _831))) * float(_869)), uint2(_144));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_144));
}

