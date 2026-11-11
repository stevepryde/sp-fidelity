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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(3)]], texture2d<float, access::write> rw_upscaled_output [[texture(4)]], texture2d<float> r_farthest_depth_mip1 [[texture(5)]], texture2d<float> r_luma_instability [[texture(6)]], texture2d<float, access::read_write> rw_new_locks [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _121 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _125 = _121 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _130 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _132 = _125 + (cbFSR3Upscaler.fJitter / _130);
    float2 _136 = _130 - float2(0.5);
    float2 _139 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _141 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _150 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_141), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _152 = length(_150 * float2(3840.0, 2160.0));
    float2 _153 = _125 + _150;
    float _154 = _153.x;
    bool _159;
    if (_154 >= 0.0)
    {
        _159 = _154 <= 1.0;
    }
    else
    {
        _159 = false;
    }
    bool _168;
    if (_159)
    {
        float _162 = _153.y;
        bool _167;
        if (_162 >= 0.0)
        {
            _167 = _162 <= 1.0;
        }
        else
        {
            _167 = false;
        }
        _168 = _167;
    }
    else
    {
        _168 = false;
    }
    uint2 _180 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _186 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _203;
    if (_168)
    {
        _203 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _203 = true;
    }
    float4 _207 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_132 * _130, _136)) / _139), level(0.0));
    float _209 = fast::clamp(_207.x, 0.0, 1.0);
    float _211 = fast::clamp(_207.y, 0.0, 1.0);
    float _213 = fast::clamp(_207.z, 0.0, 1.0);
    float _215 = fast::clamp(_207.w, 0.0, 1.0);
    float _220 = _215 * float(rint(_215 * 100.0) > 1.0);
    bool _224;
    if (_168)
    {
        _224 = !_203;
    }
    else
    {
        _224 = false;
    }
    float3 _780;
    float _781;
    if (_224)
    {
        float2 _231 = (_153 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _233 = _231 - floor(_231);
        int2 _248 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _231.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _231.y)))));
        int2 _249 = _248 + int2(-1);
        int _251 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _255 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _262 = _248 + int2(0, -1);
        int2 _273 = _248 + int2(1, -1);
        int2 _284 = _248 + int2(2, -1);
        int2 _295 = _248 + int2(-1, 0);
        float4 _315 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_248.x, _251)), max(1, min(_248.y, _255))))), 0u);
        int2 _316 = _248 + int2(1, 0);
        float4 _326 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_316.x, _251)), max(1, min(_316.y, _255))))), 0u);
        int2 _327 = _248 + int2(2, 0);
        int2 _338 = _248 + int2(-1, 1);
        int2 _349 = _248 + int2(0, 1);
        float4 _359 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_349.x, _251)), max(1, min(_349.y, _255))))), 0u);
        int2 _360 = _248 + int2(1);
        float4 _370 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_360.x, _251)), max(1, min(_360.y, _255))))), 0u);
        int2 _371 = _248 + int2(2, 1);
        int2 _382 = _248 + int2(-1, 2);
        int2 _393 = _248 + int2(0, 2);
        int2 _404 = _248 + int2(1, 2);
        int2 _415 = _248 + int2(2);
        float _426 = _233.x;
        float _429 = precise::min(abs((-1.0) - _426), 2.0);
        bool _431 = abs(_429) < 6.099999882280826568603515625e-05;
        float _442;
        if (_431)
        {
            _442 = 1.0;
        }
        else
        {
            float _435 = 3.1415927410125732421875 * _429;
            float _438 = 1.57079637050628662109375 * _429;
            _442 = (sin(_435) / _435) * (sin(_438) / _438);
        }
        float _445 = precise::min(abs(-_426), 2.0);
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
        float _461 = precise::min(abs(1.0 - _426), 2.0);
        bool _463 = abs(_461) < 6.099999882280826568603515625e-05;
        float _474;
        if (_463)
        {
            _474 = 1.0;
        }
        else
        {
            float _467 = 3.1415927410125732421875 * _461;
            float _470 = 1.57079637050628662109375 * _461;
            _474 = (sin(_467) / _467) * (sin(_470) / _470);
        }
        float _477 = precise::min(abs(2.0 - _426), 2.0);
        bool _479 = abs(_477) < 6.099999882280826568603515625e-05;
        float _490;
        if (_479)
        {
            _490 = 1.0;
        }
        else
        {
            float _483 = 3.1415927410125732421875 * _477;
            float _486 = 1.57079637050628662109375 * _477;
            _490 = (sin(_483) / _483) * (sin(_486) / _486);
        }
        float _513;
        if (_431)
        {
            _513 = 1.0;
        }
        else
        {
            float _506 = 3.1415927410125732421875 * _429;
            float _509 = 1.57079637050628662109375 * _429;
            _513 = (sin(_506) / _506) * (sin(_509) / _509);
        }
        float _524;
        if (_447)
        {
            _524 = 1.0;
        }
        else
        {
            float _517 = 3.1415927410125732421875 * _445;
            float _520 = 1.57079637050628662109375 * _445;
            _524 = (sin(_517) / _517) * (sin(_520) / _520);
        }
        float _535;
        if (_463)
        {
            _535 = 1.0;
        }
        else
        {
            float _528 = 3.1415927410125732421875 * _461;
            float _531 = 1.57079637050628662109375 * _461;
            _535 = (sin(_528) / _528) * (sin(_531) / _531);
        }
        float _546;
        if (_479)
        {
            _546 = 1.0;
        }
        else
        {
            float _539 = 3.1415927410125732421875 * _477;
            float _542 = 1.57079637050628662109375 * _477;
            _546 = (sin(_539) / _539) * (sin(_542) / _542);
        }
        float _569;
        if (_431)
        {
            _569 = 1.0;
        }
        else
        {
            float _562 = 3.1415927410125732421875 * _429;
            float _565 = 1.57079637050628662109375 * _429;
            _569 = (sin(_562) / _562) * (sin(_565) / _565);
        }
        float _580;
        if (_447)
        {
            _580 = 1.0;
        }
        else
        {
            float _573 = 3.1415927410125732421875 * _445;
            float _576 = 1.57079637050628662109375 * _445;
            _580 = (sin(_573) / _573) * (sin(_576) / _576);
        }
        float _591;
        if (_463)
        {
            _591 = 1.0;
        }
        else
        {
            float _584 = 3.1415927410125732421875 * _461;
            float _587 = 1.57079637050628662109375 * _461;
            _591 = (sin(_584) / _584) * (sin(_587) / _587);
        }
        float _602;
        if (_479)
        {
            _602 = 1.0;
        }
        else
        {
            float _595 = 3.1415927410125732421875 * _477;
            float _598 = 1.57079637050628662109375 * _477;
            _602 = (sin(_595) / _595) * (sin(_598) / _598);
        }
        float _625;
        if (_431)
        {
            _625 = 1.0;
        }
        else
        {
            float _618 = 3.1415927410125732421875 * _429;
            float _621 = 1.57079637050628662109375 * _429;
            _625 = (sin(_618) / _618) * (sin(_621) / _621);
        }
        float _636;
        if (_447)
        {
            _636 = 1.0;
        }
        else
        {
            float _629 = 3.1415927410125732421875 * _445;
            float _632 = 1.57079637050628662109375 * _445;
            _636 = (sin(_629) / _629) * (sin(_632) / _632);
        }
        float _647;
        if (_463)
        {
            _647 = 1.0;
        }
        else
        {
            float _640 = 3.1415927410125732421875 * _461;
            float _643 = 1.57079637050628662109375 * _461;
            _647 = (sin(_640) / _640) * (sin(_643) / _643);
        }
        float _658;
        if (_479)
        {
            _658 = 1.0;
        }
        else
        {
            float _651 = 3.1415927410125732421875 * _477;
            float _654 = 1.57079637050628662109375 * _477;
            _658 = (sin(_651) / _651) * (sin(_654) / _654);
        }
        float _671 = _233.y;
        float _674 = precise::min(abs((-1.0) - _671), 2.0);
        float _687;
        if (abs(_674) < 6.099999882280826568603515625e-05)
        {
            _687 = 1.0;
        }
        else
        {
            float _680 = 3.1415927410125732421875 * _674;
            float _683 = 1.57079637050628662109375 * _674;
            _687 = (sin(_680) / _680) * (sin(_683) / _683);
        }
        float _690 = precise::min(abs(-_671), 2.0);
        float _703;
        if (abs(_690) < 6.099999882280826568603515625e-05)
        {
            _703 = 1.0;
        }
        else
        {
            float _696 = 3.1415927410125732421875 * _690;
            float _699 = 1.57079637050628662109375 * _690;
            _703 = (sin(_696) / _696) * (sin(_699) / _699);
        }
        float _706 = precise::min(abs(1.0 - _671), 2.0);
        float _719;
        if (abs(_706) < 6.099999882280826568603515625e-05)
        {
            _719 = 1.0;
        }
        else
        {
            float _712 = 3.1415927410125732421875 * _706;
            float _715 = 1.57079637050628662109375 * _706;
            _719 = (sin(_712) / _712) * (sin(_715) / _715);
        }
        float _722 = precise::min(abs(2.0 - _671), 2.0);
        float _735;
        if (abs(_722) < 6.099999882280826568603515625e-05)
        {
            _735 = 1.0;
        }
        else
        {
            float _728 = 3.1415927410125732421875 * _722;
            float _731 = 1.57079637050628662109375 * _722;
            _735 = (sin(_728) / _728) * (sin(_731) / _731);
        }
        float4 _740 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_249.x, _251)), max(1, min(_249.y, _255))))), 0u) * _442) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_262.x, _251)), max(1, min(_262.y, _255))))), 0u) * _458)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_273.x, _251)), max(1, min(_273.y, _255))))), 0u) * _474)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_284.x, _251)), max(1, min(_284.y, _255))))), 0u) * _490)) / float4(((_442 + _458) + _474) + _490)) * _687) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_295.x, _251)), max(1, min(_295.y, _255))))), 0u) * _513) + (_315 * _524)) + (_326 * _535)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_327.x, _251)), max(1, min(_327.y, _255))))), 0u) * _546)) / float4(((_513 + _524) + _535) + _546)) * _703)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_338.x, _251)), max(1, min(_338.y, _255))))), 0u) * _569) + (_359 * _580)) + (_370 * _591)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_371.x, _251)), max(1, min(_371.y, _255))))), 0u) * _602)) / float4(((_569 + _580) + _591) + _602)) * _719);
        float4 _754 = fast::clamp((_740 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_382.x, _251)), max(1, min(_382.y, _255))))), 0u) * _625) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_393.x, _251)), max(1, min(_393.y, _255))))), 0u) * _636)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_404.x, _251)), max(1, min(_404.y, _255))))), 0u) * _647)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_415.x, _251)), max(1, min(_415.y, _255))))), 0u) * _658)) / float4(((_625 + _636) + _647) + _658)) * _735)) / float4(((_687 + _703) + _719) + _735), precise::min(precise::min(precise::min(_315, _326), _359), _370), precise::max(precise::max(precise::max(_315, _326), _359), _370));
        float4 _760 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _761 = _760.x;
        float3 _764 = (_754.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_761 == 0.0) ? 1.0 : _761);
        float _765 = _764.x;
        float _768 = 0.5 * _764.y;
        float _770 = _764.z;
        float _771 = 0.25 * _770;
        _780 = float3(((0.25 * _765) + _768) + _771, 0.5 * (_765 - _770), (((-0.25) * _765) + _768) - _771);
        _781 = _754.w;
    }
    else
    {
        _780 = float3(0.0);
        _781 = 0.0;
    }
    float _787 = precise::max(fast::clamp(_213, 0.0, 1.0), precise::max(_209, _211));
    float _790 = precise::max(0.0, (_781 * float(!_203)) - (_787 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _810 = _125 - _150;
    float _811 = _810.x;
    bool _816;
    if (_811 >= 0.0)
    {
        _816 = _811 <= 1.0;
    }
    else
    {
        _816 = false;
    }
    bool _825;
    if (_816)
    {
        float _819 = _810.y;
        bool _824;
        if (_819 >= 0.0)
        {
            _824 = _819 <= 1.0;
        }
        else
        {
            _824 = false;
        }
        _825 = _824;
    }
    else
    {
        _825 = false;
    }
    float _835 = precise::min(_220, mix(_220, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_152 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _838 = _121 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _840 = int2(floor(_838));
    float2 _843 = (float2(_840) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _844 = _843 - _838;
    bool _847 = _843.x > _838.x;
    bool _851 = _843.y > _838.y;
    int2 _853 = int2(_847 ? (-2) : (-1), _851 ? (-2) : (-1));
    float2 _854 = float2(_853);
    bool _855 = _220 == 0.0;
    int _856 = _847 ? 3 : 0;
    int _857 = _851 ? 3 : 0;
    int2 _858 = int2(_856, _857);
    int2 _859 = _840 + _853;
    int2 _860 = _859 + _858;
    int _863 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _868 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _878 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _879 = _878.x;
    float3 _882 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_860.x, _863)), max(0, min(_860.y, _868))))), 0u).xyz) * ((_879 == 0.0) ? 1.0 : _879);
    float _883 = _882.x;
    float _886 = 0.5 * _882.y;
    float _888 = _882.z;
    float _889 = 0.25 * _888;
    float3 _896 = float3(((0.25 * _883) + _886) + _889, 0.5 * (_883 - _888), (((-0.25) * _883) + _886) - _889);
    int _897 = _847 ? 2 : 1;
    int2 _898 = int2(_897, _857);
    int2 _899 = _859 + _898;
    float4 _913 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _914 = _913.x;
    float3 _917 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_899.x, _863)), max(0, min(_899.y, _868))))), 0u).xyz) * ((_914 == 0.0) ? 1.0 : _914);
    float _918 = _917.x;
    float _921 = 0.5 * _917.y;
    float _923 = _917.z;
    float _924 = 0.25 * _923;
    float3 _931 = float3(((0.25 * _918) + _921) + _924, 0.5 * (_918 - _923), (((-0.25) * _918) + _921) - _924);
    int _932 = _847 ? 1 : 2;
    int2 _933 = int2(_932, _857);
    int2 _934 = _859 + _933;
    float4 _948 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _949 = _948.x;
    float3 _952 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_934.x, _863)), max(0, min(_934.y, _868))))), 0u).xyz) * ((_949 == 0.0) ? 1.0 : _949);
    float _953 = _952.x;
    float _956 = 0.5 * _952.y;
    float _958 = _952.z;
    float _959 = 0.25 * _958;
    float3 _966 = float3(((0.25 * _953) + _956) + _959, 0.5 * (_953 - _958), (((-0.25) * _953) + _956) - _959);
    int _967 = _851 ? 2 : 1;
    int2 _968 = int2(_856, _967);
    int2 _969 = _859 + _968;
    float4 _983 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _984 = _983.x;
    float3 _987 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_969.x, _863)), max(0, min(_969.y, _868))))), 0u).xyz) * ((_984 == 0.0) ? 1.0 : _984);
    float _988 = _987.x;
    float _991 = 0.5 * _987.y;
    float _993 = _987.z;
    float _994 = 0.25 * _993;
    float3 _1001 = float3(((0.25 * _988) + _991) + _994, 0.5 * (_988 - _993), (((-0.25) * _988) + _991) - _994);
    int2 _1002 = int2(_897, _967);
    int2 _1003 = _859 + _1002;
    float4 _1017 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1018 = _1017.x;
    float3 _1021 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1003.x, _863)), max(0, min(_1003.y, _868))))), 0u).xyz) * ((_1018 == 0.0) ? 1.0 : _1018);
    float _1022 = _1021.x;
    float _1025 = 0.5 * _1021.y;
    float _1027 = _1021.z;
    float _1028 = 0.25 * _1027;
    float3 _1035 = float3(((0.25 * _1022) + _1025) + _1028, 0.5 * (_1022 - _1027), (((-0.25) * _1022) + _1025) - _1028);
    int2 _1036 = int2(_932, _967);
    int2 _1037 = _859 + _1036;
    float4 _1051 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1052 = _1051.x;
    float3 _1055 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1037.x, _863)), max(0, min(_1037.y, _868))))), 0u).xyz) * ((_1052 == 0.0) ? 1.0 : _1052);
    float _1056 = _1055.x;
    float _1059 = 0.5 * _1055.y;
    float _1061 = _1055.z;
    float _1062 = 0.25 * _1061;
    float3 _1069 = float3(((0.25 * _1056) + _1059) + _1062, 0.5 * (_1056 - _1061), (((-0.25) * _1056) + _1059) - _1062);
    int _1070 = _851 ? 1 : 2;
    int2 _1071 = int2(_856, _1070);
    int2 _1072 = _859 + _1071;
    float4 _1086 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1087 = _1086.x;
    float3 _1090 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1072.x, _863)), max(0, min(_1072.y, _868))))), 0u).xyz) * ((_1087 == 0.0) ? 1.0 : _1087);
    float _1091 = _1090.x;
    float _1094 = 0.5 * _1090.y;
    float _1096 = _1090.z;
    float _1097 = 0.25 * _1096;
    float3 _1104 = float3(((0.25 * _1091) + _1094) + _1097, 0.5 * (_1091 - _1096), (((-0.25) * _1091) + _1094) - _1097);
    int2 _1105 = int2(_897, _1070);
    int2 _1106 = _859 + _1105;
    float4 _1120 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1121 = _1120.x;
    float3 _1124 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1106.x, _863)), max(0, min(_1106.y, _868))))), 0u).xyz) * ((_1121 == 0.0) ? 1.0 : _1121);
    float _1125 = _1124.x;
    float _1128 = 0.5 * _1124.y;
    float _1130 = _1124.z;
    float _1131 = 0.25 * _1130;
    float3 _1138 = float3(((0.25 * _1125) + _1128) + _1131, 0.5 * (_1125 - _1130), (((-0.25) * _1125) + _1128) - _1131);
    int2 _1139 = int2(_932, _1070);
    int2 _1140 = _859 + _1139;
    float4 _1154 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1155 = _1154.x;
    float3 _1158 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1140.x, _863)), max(0, min(_1140.y, _868))))), 0u).xyz) * ((_1155 == 0.0) ? 1.0 : _1155);
    float _1159 = _1158.x;
    float _1162 = 0.5 * _1158.y;
    float _1164 = _1158.z;
    float _1165 = 0.25 * _1164;
    float3 _1172 = float3(((0.25 * _1159) + _1162) + _1165, 0.5 * (_1159 - _1164), (((-0.25) * _1159) + _1162) - _1165);
    float _1177 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1188 = mix(precise::max(1.0, (1.0 + _1177) * 0.300000011920928955078125), _1177, precise::min(1.0 - (_211 * 0.5), precise::min(1.0 - _213, fast::clamp(_835 * 5.0, 0.0, 1.0))));
    float2 _1191 = _844 + (_854 + float2(_858));
    uint2 _1193 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1196 = float(all(uint2(_860) < _1193));
    bool _1197 = !_855;
    float _1215;
    float3 _1216;
    if (_1197)
    {
        float2 _1201 = _1191 * float2(_1188);
        float _1203 = precise::min(dot(_1201, _1201), 4.0);
        float _1205 = (0.4000000059604644775390625 * _1203) - 1.0;
        float _1207 = (0.25 * _1203) - 1.0;
        float _1213 = _1196 * ((((1.5625 * _1205) * _1205) - 0.5625) * (_1207 * _1207));
        _1215 = _1213;
        _1216 = _896 * _1213;
    }
    else
    {
        _1215 = 0.0;
        _1216 = float3(0.0);
    }
    float _1220 = exp((-2.2999999523162841796875) * dot(_1191, _1191)) * _1196;
    float3 _1221 = _896 * _1220;
    float2 _1225 = _844 + (_854 + float2(_898));
    float _1229 = float(all(uint2(_899) < _1193));
    float _1249;
    float3 _1250;
    if (_1197)
    {
        float2 _1233 = _1225 * float2(_1188);
        float _1235 = precise::min(dot(_1233, _1233), 4.0);
        float _1237 = (0.4000000059604644775390625 * _1235) - 1.0;
        float _1239 = (0.25 * _1235) - 1.0;
        float _1245 = _1229 * ((((1.5625 * _1237) * _1237) - 0.5625) * (_1239 * _1239));
        _1249 = _1215 + _1245;
        _1250 = _1216 + (_931 * _1245);
    }
    else
    {
        _1249 = _1215;
        _1250 = _1216;
    }
    float _1254 = exp((-2.2999999523162841796875) * dot(_1225, _1225)) * _1229;
    float3 _1257 = _931 * _1254;
    float2 _1264 = _844 + (_854 + float2(_933));
    float _1268 = float(all(uint2(_934) < _1193));
    float _1288;
    float3 _1289;
    if (_1197)
    {
        float2 _1272 = _1264 * float2(_1188);
        float _1274 = precise::min(dot(_1272, _1272), 4.0);
        float _1276 = (0.4000000059604644775390625 * _1274) - 1.0;
        float _1278 = (0.25 * _1274) - 1.0;
        float _1284 = _1268 * ((((1.5625 * _1276) * _1276) - 0.5625) * (_1278 * _1278));
        _1288 = _1249 + _1284;
        _1289 = _1250 + (_966 * _1284);
    }
    else
    {
        _1288 = _1249;
        _1289 = _1250;
    }
    float _1293 = exp((-2.2999999523162841796875) * dot(_1264, _1264)) * _1268;
    float3 _1296 = _966 * _1293;
    float2 _1303 = _844 + (_854 + float2(_968));
    float _1307 = float(all(uint2(_969) < _1193));
    float _1327;
    float3 _1328;
    if (_1197)
    {
        float2 _1311 = _1303 * float2(_1188);
        float _1313 = precise::min(dot(_1311, _1311), 4.0);
        float _1315 = (0.4000000059604644775390625 * _1313) - 1.0;
        float _1317 = (0.25 * _1313) - 1.0;
        float _1323 = _1307 * ((((1.5625 * _1315) * _1315) - 0.5625) * (_1317 * _1317));
        _1327 = _1288 + _1323;
        _1328 = _1289 + (_1001 * _1323);
    }
    else
    {
        _1327 = _1288;
        _1328 = _1289;
    }
    float _1332 = exp((-2.2999999523162841796875) * dot(_1303, _1303)) * _1307;
    float3 _1335 = _1001 * _1332;
    float2 _1342 = _844 + (_854 + float2(_1002));
    float _1346 = float(all(uint2(_1003) < _1193));
    float _1366;
    float3 _1367;
    if (_1197)
    {
        float2 _1350 = _1342 * float2(_1188);
        float _1352 = precise::min(dot(_1350, _1350), 4.0);
        float _1354 = (0.4000000059604644775390625 * _1352) - 1.0;
        float _1356 = (0.25 * _1352) - 1.0;
        float _1362 = _1346 * ((((1.5625 * _1354) * _1354) - 0.5625) * (_1356 * _1356));
        _1366 = _1327 + _1362;
        _1367 = _1328 + (_1035 * _1362);
    }
    else
    {
        _1366 = _1327;
        _1367 = _1328;
    }
    float _1371 = exp((-2.2999999523162841796875) * dot(_1342, _1342)) * _1346;
    float3 _1374 = _1035 * _1371;
    float2 _1381 = _844 + (_854 + float2(_1036));
    float _1385 = float(all(uint2(_1037) < _1193));
    float _1405;
    float3 _1406;
    if (_1197)
    {
        float2 _1389 = _1381 * float2(_1188);
        float _1391 = precise::min(dot(_1389, _1389), 4.0);
        float _1393 = (0.4000000059604644775390625 * _1391) - 1.0;
        float _1395 = (0.25 * _1391) - 1.0;
        float _1401 = _1385 * ((((1.5625 * _1393) * _1393) - 0.5625) * (_1395 * _1395));
        _1405 = _1366 + _1401;
        _1406 = _1367 + (_1069 * _1401);
    }
    else
    {
        _1405 = _1366;
        _1406 = _1367;
    }
    float _1410 = exp((-2.2999999523162841796875) * dot(_1381, _1381)) * _1385;
    float3 _1413 = _1069 * _1410;
    float2 _1420 = _844 + (_854 + float2(_1071));
    float _1424 = float(all(uint2(_1072) < _1193));
    float _1444;
    float3 _1445;
    if (_1197)
    {
        float2 _1428 = _1420 * float2(_1188);
        float _1430 = precise::min(dot(_1428, _1428), 4.0);
        float _1432 = (0.4000000059604644775390625 * _1430) - 1.0;
        float _1434 = (0.25 * _1430) - 1.0;
        float _1440 = _1424 * ((((1.5625 * _1432) * _1432) - 0.5625) * (_1434 * _1434));
        _1444 = _1405 + _1440;
        _1445 = _1406 + (_1104 * _1440);
    }
    else
    {
        _1444 = _1405;
        _1445 = _1406;
    }
    float _1449 = exp((-2.2999999523162841796875) * dot(_1420, _1420)) * _1424;
    float3 _1452 = _1104 * _1449;
    float2 _1459 = _844 + (_854 + float2(_1105));
    float _1463 = float(all(uint2(_1106) < _1193));
    float _1483;
    float3 _1484;
    if (_1197)
    {
        float2 _1467 = _1459 * float2(_1188);
        float _1469 = precise::min(dot(_1467, _1467), 4.0);
        float _1471 = (0.4000000059604644775390625 * _1469) - 1.0;
        float _1473 = (0.25 * _1469) - 1.0;
        float _1479 = _1463 * ((((1.5625 * _1471) * _1471) - 0.5625) * (_1473 * _1473));
        _1483 = _1444 + _1479;
        _1484 = _1445 + (_1138 * _1479);
    }
    else
    {
        _1483 = _1444;
        _1484 = _1445;
    }
    float _1488 = exp((-2.2999999523162841796875) * dot(_1459, _1459)) * _1463;
    float3 _1491 = _1138 * _1488;
    float2 _1498 = _844 + (_854 + float2(_1139));
    float _1502 = float(all(uint2(_1140) < _1193));
    float _1522;
    float3 _1523;
    if (_1197)
    {
        float2 _1506 = _1498 * float2(_1188);
        float _1508 = precise::min(dot(_1506, _1506), 4.0);
        float _1510 = (0.4000000059604644775390625 * _1508) - 1.0;
        float _1512 = (0.25 * _1508) - 1.0;
        float _1518 = _1502 * ((((1.5625 * _1510) * _1510) - 0.5625) * (_1512 * _1512));
        _1522 = _1483 + _1518;
        _1523 = _1484 + (_1172 * _1518);
    }
    else
    {
        _1522 = _1483;
        _1523 = _1484;
    }
    float _1527 = exp((-2.2999999523162841796875) * dot(_1498, _1498)) * _1502;
    float3 _1530 = _1172 * _1527;
    float _1534 = (((((((_1220 + _1254) + _1293) + _1332) + _1371) + _1410) + _1449) + _1488) + _1527;
    float3 _1538 = float3((abs(_1534) > 1.1754943508222875079687365372222e-38) ? _1534 : 1.0);
    float3 _1539 = ((((((((_1221 + _1257) + _1296) + _1335) + _1374) + _1413) + _1452) + _1491) + _1530) / _1538;
    float _1547 = _1522 * float(_1522 > 6.099999882280826568603515625e-05);
    float3 _1555;
    float _1556;
    if (_1547 > 6.099999882280826568603515625e-05)
    {
        _1555 = fast::clamp(_1523 / float3(_1547), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_896, _931), _966), _1001), _1035), _1069), _1104), _1138), _1172), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_896, _931), _966), _1001), _1035), _1069), _1104), _1138), _1172));
        _1556 = _1547 * 0.04625000059604644775390625;
    }
    else
    {
        _1555 = _1523;
        _1556 = _1547;
    }
    float _1559 = _855 ? 1.0 : _1556;
    float _1560 = _855 ? 0.0 : _835;
    float3 _1574 = (sqrt(abs(((((((((((_896 * _1221) + (_931 * _1257)) + (_966 * _1296)) + (_1001 * _1335)) + (_1035 * _1374)) + (_1069 * _1413)) + (_1104 * _1452)) + (_1138 * _1491)) + (_1172 * _1530)) / _1538) - (_1539 * _1539))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_152 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_132 * _186, _186 - float2(0.5))) / float2(int2(int(_180.x), int(_180.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _220, precise::max(powr(_209, 0.5), _213)))));
    float3 _1577 = (_780 - _1539) / precise::max(_1574, float3(1.19299997436428384389728307724e-07));
    float3 _1592;
    if (length(_1577) > 1.0)
    {
        _1592 = mix((fast::normalize(_1577) * _1574) + _1539, _780, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_125 * _130, _136)) / _139), level(0.0)).x, fast::clamp(fast::clamp(_790 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _220) * (1.0 - _211), 0.0, 1.0)));
    }
    else
    {
        _1592 = _780;
    }
    float3 _1601 = mix(_1592, select(_1555, _1539, bool3(_855)), float3(fast::clamp(_1559 / precise::max(6.099999882280826568603515625e-05, (_1560 * float(_1560 > 6.099999882280826568603515625e-05)) + _1559), 0.0, 1.0)));
    float _1602 = _1601.x;
    float _1603 = _1601.y;
    float _1605 = _1601.z;
    float4 _1612 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1613 = _1612.x;
    float3 _1618 = precise::max(float3((_1602 + _1603) - _1605, _1602 + _1605, (_1602 - _1603) - _1605) / float3((_1613 == 0.0) ? 1.0 : _1613), float3(0.0));
    float _1619 = _1618.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1619, _1618.yz, precise::max(0.0, precise::max(0.0, precise::min(_790 + (sdk_hlsl_load(rw_new_locks, uint2(_141)).x * (1.0 - precise::max(0.0, _209))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _787))) * float(_825)), uint2(_141));
    sdk_hlsl_store(rw_upscaled_output, float4(_1619, _1618.yz, 1.0), uint2(_141));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_141));
}

