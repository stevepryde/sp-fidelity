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
    float2 _118 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _122 = _118 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _127 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _129 = _122 + (cbFSR3Upscaler.fJitter / _127);
    float2 _133 = _127 - float2(0.5);
    float2 _136 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _138 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _147 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_138), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _149 = length(_147 * float2(3840.0, 2160.0));
    float2 _150 = _122 + _147;
    float _151 = _150.x;
    bool _156;
    if (_151 >= 0.0)
    {
        _156 = _151 <= 1.0;
    }
    else
    {
        _156 = false;
    }
    bool _165;
    if (_156)
    {
        float _159 = _150.y;
        bool _164;
        if (_159 >= 0.0)
        {
            _164 = _159 <= 1.0;
        }
        else
        {
            _164 = false;
        }
        _165 = _164;
    }
    else
    {
        _165 = false;
    }
    uint2 _177 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _183 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _200;
    if (_165)
    {
        _200 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _200 = true;
    }
    float4 _204 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_129 * _127, _133)) / _136), level(0.0));
    float _206 = fast::clamp(_204.x, 0.0, 1.0);
    float _208 = fast::clamp(_204.y, 0.0, 1.0);
    float _210 = fast::clamp(_204.z, 0.0, 1.0);
    float _212 = fast::clamp(_204.w, 0.0, 1.0);
    float _217 = _212 * float(rint(_212 * 100.0) > 1.0);
    bool _221;
    if (_165)
    {
        _221 = !_200;
    }
    else
    {
        _221 = false;
    }
    float3 _777;
    float _778;
    if (_221)
    {
        float2 _228 = (_150 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _230 = _228 - floor(_228);
        int2 _245 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _228.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _228.y)))));
        int2 _246 = _245 + int2(-1);
        int _248 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _252 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _259 = _245 + int2(0, -1);
        int2 _270 = _245 + int2(1, -1);
        int2 _281 = _245 + int2(2, -1);
        int2 _292 = _245 + int2(-1, 0);
        float4 _312 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_245.x, _248)), max(1, min(_245.y, _252))))), 0u);
        int2 _313 = _245 + int2(1, 0);
        float4 _323 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_313.x, _248)), max(1, min(_313.y, _252))))), 0u);
        int2 _324 = _245 + int2(2, 0);
        int2 _335 = _245 + int2(-1, 1);
        int2 _346 = _245 + int2(0, 1);
        float4 _356 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_346.x, _248)), max(1, min(_346.y, _252))))), 0u);
        int2 _357 = _245 + int2(1);
        float4 _367 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_357.x, _248)), max(1, min(_357.y, _252))))), 0u);
        int2 _368 = _245 + int2(2, 1);
        int2 _379 = _245 + int2(-1, 2);
        int2 _390 = _245 + int2(0, 2);
        int2 _401 = _245 + int2(1, 2);
        int2 _412 = _245 + int2(2);
        float _423 = _230.x;
        float _426 = precise::min(abs((-1.0) - _423), 2.0);
        bool _428 = abs(_426) < 6.099999882280826568603515625e-05;
        float _439;
        if (_428)
        {
            _439 = 1.0;
        }
        else
        {
            float _432 = 3.1415927410125732421875 * _426;
            float _435 = 1.57079637050628662109375 * _426;
            _439 = (sin(_432) / _432) * (sin(_435) / _435);
        }
        float _442 = precise::min(abs(-_423), 2.0);
        bool _444 = abs(_442) < 6.099999882280826568603515625e-05;
        float _455;
        if (_444)
        {
            _455 = 1.0;
        }
        else
        {
            float _448 = 3.1415927410125732421875 * _442;
            float _451 = 1.57079637050628662109375 * _442;
            _455 = (sin(_448) / _448) * (sin(_451) / _451);
        }
        float _458 = precise::min(abs(1.0 - _423), 2.0);
        bool _460 = abs(_458) < 6.099999882280826568603515625e-05;
        float _471;
        if (_460)
        {
            _471 = 1.0;
        }
        else
        {
            float _464 = 3.1415927410125732421875 * _458;
            float _467 = 1.57079637050628662109375 * _458;
            _471 = (sin(_464) / _464) * (sin(_467) / _467);
        }
        float _474 = precise::min(abs(2.0 - _423), 2.0);
        bool _476 = abs(_474) < 6.099999882280826568603515625e-05;
        float _487;
        if (_476)
        {
            _487 = 1.0;
        }
        else
        {
            float _480 = 3.1415927410125732421875 * _474;
            float _483 = 1.57079637050628662109375 * _474;
            _487 = (sin(_480) / _480) * (sin(_483) / _483);
        }
        float _510;
        if (_428)
        {
            _510 = 1.0;
        }
        else
        {
            float _503 = 3.1415927410125732421875 * _426;
            float _506 = 1.57079637050628662109375 * _426;
            _510 = (sin(_503) / _503) * (sin(_506) / _506);
        }
        float _521;
        if (_444)
        {
            _521 = 1.0;
        }
        else
        {
            float _514 = 3.1415927410125732421875 * _442;
            float _517 = 1.57079637050628662109375 * _442;
            _521 = (sin(_514) / _514) * (sin(_517) / _517);
        }
        float _532;
        if (_460)
        {
            _532 = 1.0;
        }
        else
        {
            float _525 = 3.1415927410125732421875 * _458;
            float _528 = 1.57079637050628662109375 * _458;
            _532 = (sin(_525) / _525) * (sin(_528) / _528);
        }
        float _543;
        if (_476)
        {
            _543 = 1.0;
        }
        else
        {
            float _536 = 3.1415927410125732421875 * _474;
            float _539 = 1.57079637050628662109375 * _474;
            _543 = (sin(_536) / _536) * (sin(_539) / _539);
        }
        float _566;
        if (_428)
        {
            _566 = 1.0;
        }
        else
        {
            float _559 = 3.1415927410125732421875 * _426;
            float _562 = 1.57079637050628662109375 * _426;
            _566 = (sin(_559) / _559) * (sin(_562) / _562);
        }
        float _577;
        if (_444)
        {
            _577 = 1.0;
        }
        else
        {
            float _570 = 3.1415927410125732421875 * _442;
            float _573 = 1.57079637050628662109375 * _442;
            _577 = (sin(_570) / _570) * (sin(_573) / _573);
        }
        float _588;
        if (_460)
        {
            _588 = 1.0;
        }
        else
        {
            float _581 = 3.1415927410125732421875 * _458;
            float _584 = 1.57079637050628662109375 * _458;
            _588 = (sin(_581) / _581) * (sin(_584) / _584);
        }
        float _599;
        if (_476)
        {
            _599 = 1.0;
        }
        else
        {
            float _592 = 3.1415927410125732421875 * _474;
            float _595 = 1.57079637050628662109375 * _474;
            _599 = (sin(_592) / _592) * (sin(_595) / _595);
        }
        float _622;
        if (_428)
        {
            _622 = 1.0;
        }
        else
        {
            float _615 = 3.1415927410125732421875 * _426;
            float _618 = 1.57079637050628662109375 * _426;
            _622 = (sin(_615) / _615) * (sin(_618) / _618);
        }
        float _633;
        if (_444)
        {
            _633 = 1.0;
        }
        else
        {
            float _626 = 3.1415927410125732421875 * _442;
            float _629 = 1.57079637050628662109375 * _442;
            _633 = (sin(_626) / _626) * (sin(_629) / _629);
        }
        float _644;
        if (_460)
        {
            _644 = 1.0;
        }
        else
        {
            float _637 = 3.1415927410125732421875 * _458;
            float _640 = 1.57079637050628662109375 * _458;
            _644 = (sin(_637) / _637) * (sin(_640) / _640);
        }
        float _655;
        if (_476)
        {
            _655 = 1.0;
        }
        else
        {
            float _648 = 3.1415927410125732421875 * _474;
            float _651 = 1.57079637050628662109375 * _474;
            _655 = (sin(_648) / _648) * (sin(_651) / _651);
        }
        float _668 = _230.y;
        float _671 = precise::min(abs((-1.0) - _668), 2.0);
        float _684;
        if (abs(_671) < 6.099999882280826568603515625e-05)
        {
            _684 = 1.0;
        }
        else
        {
            float _677 = 3.1415927410125732421875 * _671;
            float _680 = 1.57079637050628662109375 * _671;
            _684 = (sin(_677) / _677) * (sin(_680) / _680);
        }
        float _687 = precise::min(abs(-_668), 2.0);
        float _700;
        if (abs(_687) < 6.099999882280826568603515625e-05)
        {
            _700 = 1.0;
        }
        else
        {
            float _693 = 3.1415927410125732421875 * _687;
            float _696 = 1.57079637050628662109375 * _687;
            _700 = (sin(_693) / _693) * (sin(_696) / _696);
        }
        float _703 = precise::min(abs(1.0 - _668), 2.0);
        float _716;
        if (abs(_703) < 6.099999882280826568603515625e-05)
        {
            _716 = 1.0;
        }
        else
        {
            float _709 = 3.1415927410125732421875 * _703;
            float _712 = 1.57079637050628662109375 * _703;
            _716 = (sin(_709) / _709) * (sin(_712) / _712);
        }
        float _719 = precise::min(abs(2.0 - _668), 2.0);
        float _732;
        if (abs(_719) < 6.099999882280826568603515625e-05)
        {
            _732 = 1.0;
        }
        else
        {
            float _725 = 3.1415927410125732421875 * _719;
            float _728 = 1.57079637050628662109375 * _719;
            _732 = (sin(_725) / _725) * (sin(_728) / _728);
        }
        float4 _737 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_246.x, _248)), max(1, min(_246.y, _252))))), 0u) * _439) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_259.x, _248)), max(1, min(_259.y, _252))))), 0u) * _455)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_270.x, _248)), max(1, min(_270.y, _252))))), 0u) * _471)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_281.x, _248)), max(1, min(_281.y, _252))))), 0u) * _487)) / float4(((_439 + _455) + _471) + _487)) * _684) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_292.x, _248)), max(1, min(_292.y, _252))))), 0u) * _510) + (_312 * _521)) + (_323 * _532)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_324.x, _248)), max(1, min(_324.y, _252))))), 0u) * _543)) / float4(((_510 + _521) + _532) + _543)) * _700)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_335.x, _248)), max(1, min(_335.y, _252))))), 0u) * _566) + (_356 * _577)) + (_367 * _588)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_368.x, _248)), max(1, min(_368.y, _252))))), 0u) * _599)) / float4(((_566 + _577) + _588) + _599)) * _716);
        float4 _751 = fast::clamp((_737 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_379.x, _248)), max(1, min(_379.y, _252))))), 0u) * _622) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_390.x, _248)), max(1, min(_390.y, _252))))), 0u) * _633)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_401.x, _248)), max(1, min(_401.y, _252))))), 0u) * _644)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_412.x, _248)), max(1, min(_412.y, _252))))), 0u) * _655)) / float4(((_622 + _633) + _644) + _655)) * _732)) / float4(((_684 + _700) + _716) + _732), precise::min(precise::min(precise::min(_312, _323), _356), _367), precise::max(precise::max(precise::max(_312, _323), _356), _367));
        float4 _757 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _758 = _757.x;
        float3 _761 = (_751.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_758 == 0.0) ? 1.0 : _758);
        float _762 = _761.x;
        float _765 = 0.5 * _761.y;
        float _767 = _761.z;
        float _768 = 0.25 * _767;
        _777 = float3(((0.25 * _762) + _765) + _768, 0.5 * (_762 - _767), (((-0.25) * _762) + _765) - _768);
        _778 = _751.w;
    }
    else
    {
        _777 = float3(0.0);
        _778 = 0.0;
    }
    float _784 = precise::max(fast::clamp(_210, 0.0, 1.0), precise::max(_206, _208));
    float _787 = precise::max(0.0, (_778 * float(!_200)) - (_784 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _807 = _122 - _147;
    float _808 = _807.x;
    bool _813;
    if (_808 >= 0.0)
    {
        _813 = _808 <= 1.0;
    }
    else
    {
        _813 = false;
    }
    bool _822;
    if (_813)
    {
        float _816 = _807.y;
        bool _821;
        if (_816 >= 0.0)
        {
            _821 = _816 <= 1.0;
        }
        else
        {
            _821 = false;
        }
        _822 = _821;
    }
    else
    {
        _822 = false;
    }
    float _832 = precise::min(_217, mix(_217, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_149 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _835 = _118 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _837 = int2(floor(_835));
    float2 _840 = (float2(_837) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _841 = _840 - _835;
    bool _844 = _840.x > _835.x;
    bool _848 = _840.y > _835.y;
    int2 _850 = int2(_844 ? (-2) : (-1), _848 ? (-2) : (-1));
    float2 _851 = float2(_850);
    bool _852 = _217 == 0.0;
    int _853 = _844 ? 3 : 0;
    int _854 = _848 ? 3 : 0;
    int2 _855 = int2(_853, _854);
    int2 _856 = _837 + _850;
    int2 _857 = _856 + _855;
    int _860 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _865 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _875 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _876 = _875.x;
    float3 _879 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_857.x, _860)), max(0, min(_857.y, _865))))), 0u).xyz) * ((_876 == 0.0) ? 1.0 : _876);
    float _880 = _879.x;
    float _883 = 0.5 * _879.y;
    float _885 = _879.z;
    float _886 = 0.25 * _885;
    float3 _893 = float3(((0.25 * _880) + _883) + _886, 0.5 * (_880 - _885), (((-0.25) * _880) + _883) - _886);
    int _894 = _844 ? 2 : 1;
    int2 _895 = int2(_894, _854);
    int2 _896 = _856 + _895;
    float4 _910 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _911 = _910.x;
    float3 _914 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_896.x, _860)), max(0, min(_896.y, _865))))), 0u).xyz) * ((_911 == 0.0) ? 1.0 : _911);
    float _915 = _914.x;
    float _918 = 0.5 * _914.y;
    float _920 = _914.z;
    float _921 = 0.25 * _920;
    float3 _928 = float3(((0.25 * _915) + _918) + _921, 0.5 * (_915 - _920), (((-0.25) * _915) + _918) - _921);
    int _929 = _844 ? 1 : 2;
    int2 _930 = int2(_929, _854);
    int2 _931 = _856 + _930;
    float4 _945 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _946 = _945.x;
    float3 _949 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_931.x, _860)), max(0, min(_931.y, _865))))), 0u).xyz) * ((_946 == 0.0) ? 1.0 : _946);
    float _950 = _949.x;
    float _953 = 0.5 * _949.y;
    float _955 = _949.z;
    float _956 = 0.25 * _955;
    float3 _963 = float3(((0.25 * _950) + _953) + _956, 0.5 * (_950 - _955), (((-0.25) * _950) + _953) - _956);
    int _964 = _848 ? 2 : 1;
    int2 _965 = int2(_853, _964);
    int2 _966 = _856 + _965;
    float4 _980 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _981 = _980.x;
    float3 _984 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_966.x, _860)), max(0, min(_966.y, _865))))), 0u).xyz) * ((_981 == 0.0) ? 1.0 : _981);
    float _985 = _984.x;
    float _988 = 0.5 * _984.y;
    float _990 = _984.z;
    float _991 = 0.25 * _990;
    float3 _998 = float3(((0.25 * _985) + _988) + _991, 0.5 * (_985 - _990), (((-0.25) * _985) + _988) - _991);
    int2 _999 = int2(_894, _964);
    int2 _1000 = _856 + _999;
    float4 _1014 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1015 = _1014.x;
    float3 _1018 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1000.x, _860)), max(0, min(_1000.y, _865))))), 0u).xyz) * ((_1015 == 0.0) ? 1.0 : _1015);
    float _1019 = _1018.x;
    float _1022 = 0.5 * _1018.y;
    float _1024 = _1018.z;
    float _1025 = 0.25 * _1024;
    float3 _1032 = float3(((0.25 * _1019) + _1022) + _1025, 0.5 * (_1019 - _1024), (((-0.25) * _1019) + _1022) - _1025);
    int2 _1033 = int2(_929, _964);
    int2 _1034 = _856 + _1033;
    float4 _1048 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1049 = _1048.x;
    float3 _1052 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1034.x, _860)), max(0, min(_1034.y, _865))))), 0u).xyz) * ((_1049 == 0.0) ? 1.0 : _1049);
    float _1053 = _1052.x;
    float _1056 = 0.5 * _1052.y;
    float _1058 = _1052.z;
    float _1059 = 0.25 * _1058;
    float3 _1066 = float3(((0.25 * _1053) + _1056) + _1059, 0.5 * (_1053 - _1058), (((-0.25) * _1053) + _1056) - _1059);
    int _1067 = _848 ? 1 : 2;
    int2 _1068 = int2(_853, _1067);
    int2 _1069 = _856 + _1068;
    float4 _1083 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1084 = _1083.x;
    float3 _1087 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1069.x, _860)), max(0, min(_1069.y, _865))))), 0u).xyz) * ((_1084 == 0.0) ? 1.0 : _1084);
    float _1088 = _1087.x;
    float _1091 = 0.5 * _1087.y;
    float _1093 = _1087.z;
    float _1094 = 0.25 * _1093;
    float3 _1101 = float3(((0.25 * _1088) + _1091) + _1094, 0.5 * (_1088 - _1093), (((-0.25) * _1088) + _1091) - _1094);
    int2 _1102 = int2(_894, _1067);
    int2 _1103 = _856 + _1102;
    float4 _1117 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1118 = _1117.x;
    float3 _1121 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1103.x, _860)), max(0, min(_1103.y, _865))))), 0u).xyz) * ((_1118 == 0.0) ? 1.0 : _1118);
    float _1122 = _1121.x;
    float _1125 = 0.5 * _1121.y;
    float _1127 = _1121.z;
    float _1128 = 0.25 * _1127;
    float3 _1135 = float3(((0.25 * _1122) + _1125) + _1128, 0.5 * (_1122 - _1127), (((-0.25) * _1122) + _1125) - _1128);
    int2 _1136 = int2(_929, _1067);
    int2 _1137 = _856 + _1136;
    float4 _1151 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1152 = _1151.x;
    float3 _1155 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1137.x, _860)), max(0, min(_1137.y, _865))))), 0u).xyz) * ((_1152 == 0.0) ? 1.0 : _1152);
    float _1156 = _1155.x;
    float _1159 = 0.5 * _1155.y;
    float _1161 = _1155.z;
    float _1162 = 0.25 * _1161;
    float3 _1169 = float3(((0.25 * _1156) + _1159) + _1162, 0.5 * (_1156 - _1161), (((-0.25) * _1156) + _1159) - _1162);
    float _1174 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1185 = mix(precise::max(1.0, (1.0 + _1174) * 0.300000011920928955078125), _1174, precise::min(1.0 - (_208 * 0.5), precise::min(1.0 - _210, fast::clamp(_832 * 5.0, 0.0, 1.0))));
    float2 _1188 = _841 + (_851 + float2(_855));
    uint2 _1190 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1193 = float(all(uint2(_857) < _1190));
    bool _1194 = !_852;
    float _1212;
    float3 _1213;
    if (_1194)
    {
        float2 _1198 = _1188 * float2(_1185);
        float _1200 = precise::min(dot(_1198, _1198), 4.0);
        float _1202 = (0.4000000059604644775390625 * _1200) - 1.0;
        float _1204 = (0.25 * _1200) - 1.0;
        float _1210 = _1193 * ((((1.5625 * _1202) * _1202) - 0.5625) * (_1204 * _1204));
        _1212 = _1210;
        _1213 = _893 * _1210;
    }
    else
    {
        _1212 = 0.0;
        _1213 = float3(0.0);
    }
    float _1217 = exp((-2.2999999523162841796875) * dot(_1188, _1188)) * _1193;
    float3 _1218 = _893 * _1217;
    float2 _1222 = _841 + (_851 + float2(_895));
    float _1226 = float(all(uint2(_896) < _1190));
    float _1246;
    float3 _1247;
    if (_1194)
    {
        float2 _1230 = _1222 * float2(_1185);
        float _1232 = precise::min(dot(_1230, _1230), 4.0);
        float _1234 = (0.4000000059604644775390625 * _1232) - 1.0;
        float _1236 = (0.25 * _1232) - 1.0;
        float _1242 = _1226 * ((((1.5625 * _1234) * _1234) - 0.5625) * (_1236 * _1236));
        _1246 = _1212 + _1242;
        _1247 = _1213 + (_928 * _1242);
    }
    else
    {
        _1246 = _1212;
        _1247 = _1213;
    }
    float _1251 = exp((-2.2999999523162841796875) * dot(_1222, _1222)) * _1226;
    float3 _1254 = _928 * _1251;
    float2 _1261 = _841 + (_851 + float2(_930));
    float _1265 = float(all(uint2(_931) < _1190));
    float _1285;
    float3 _1286;
    if (_1194)
    {
        float2 _1269 = _1261 * float2(_1185);
        float _1271 = precise::min(dot(_1269, _1269), 4.0);
        float _1273 = (0.4000000059604644775390625 * _1271) - 1.0;
        float _1275 = (0.25 * _1271) - 1.0;
        float _1281 = _1265 * ((((1.5625 * _1273) * _1273) - 0.5625) * (_1275 * _1275));
        _1285 = _1246 + _1281;
        _1286 = _1247 + (_963 * _1281);
    }
    else
    {
        _1285 = _1246;
        _1286 = _1247;
    }
    float _1290 = exp((-2.2999999523162841796875) * dot(_1261, _1261)) * _1265;
    float3 _1293 = _963 * _1290;
    float2 _1300 = _841 + (_851 + float2(_965));
    float _1304 = float(all(uint2(_966) < _1190));
    float _1324;
    float3 _1325;
    if (_1194)
    {
        float2 _1308 = _1300 * float2(_1185);
        float _1310 = precise::min(dot(_1308, _1308), 4.0);
        float _1312 = (0.4000000059604644775390625 * _1310) - 1.0;
        float _1314 = (0.25 * _1310) - 1.0;
        float _1320 = _1304 * ((((1.5625 * _1312) * _1312) - 0.5625) * (_1314 * _1314));
        _1324 = _1285 + _1320;
        _1325 = _1286 + (_998 * _1320);
    }
    else
    {
        _1324 = _1285;
        _1325 = _1286;
    }
    float _1329 = exp((-2.2999999523162841796875) * dot(_1300, _1300)) * _1304;
    float3 _1332 = _998 * _1329;
    float2 _1339 = _841 + (_851 + float2(_999));
    float _1343 = float(all(uint2(_1000) < _1190));
    float _1363;
    float3 _1364;
    if (_1194)
    {
        float2 _1347 = _1339 * float2(_1185);
        float _1349 = precise::min(dot(_1347, _1347), 4.0);
        float _1351 = (0.4000000059604644775390625 * _1349) - 1.0;
        float _1353 = (0.25 * _1349) - 1.0;
        float _1359 = _1343 * ((((1.5625 * _1351) * _1351) - 0.5625) * (_1353 * _1353));
        _1363 = _1324 + _1359;
        _1364 = _1325 + (_1032 * _1359);
    }
    else
    {
        _1363 = _1324;
        _1364 = _1325;
    }
    float _1368 = exp((-2.2999999523162841796875) * dot(_1339, _1339)) * _1343;
    float3 _1371 = _1032 * _1368;
    float2 _1378 = _841 + (_851 + float2(_1033));
    float _1382 = float(all(uint2(_1034) < _1190));
    float _1402;
    float3 _1403;
    if (_1194)
    {
        float2 _1386 = _1378 * float2(_1185);
        float _1388 = precise::min(dot(_1386, _1386), 4.0);
        float _1390 = (0.4000000059604644775390625 * _1388) - 1.0;
        float _1392 = (0.25 * _1388) - 1.0;
        float _1398 = _1382 * ((((1.5625 * _1390) * _1390) - 0.5625) * (_1392 * _1392));
        _1402 = _1363 + _1398;
        _1403 = _1364 + (_1066 * _1398);
    }
    else
    {
        _1402 = _1363;
        _1403 = _1364;
    }
    float _1407 = exp((-2.2999999523162841796875) * dot(_1378, _1378)) * _1382;
    float3 _1410 = _1066 * _1407;
    float2 _1417 = _841 + (_851 + float2(_1068));
    float _1421 = float(all(uint2(_1069) < _1190));
    float _1441;
    float3 _1442;
    if (_1194)
    {
        float2 _1425 = _1417 * float2(_1185);
        float _1427 = precise::min(dot(_1425, _1425), 4.0);
        float _1429 = (0.4000000059604644775390625 * _1427) - 1.0;
        float _1431 = (0.25 * _1427) - 1.0;
        float _1437 = _1421 * ((((1.5625 * _1429) * _1429) - 0.5625) * (_1431 * _1431));
        _1441 = _1402 + _1437;
        _1442 = _1403 + (_1101 * _1437);
    }
    else
    {
        _1441 = _1402;
        _1442 = _1403;
    }
    float _1446 = exp((-2.2999999523162841796875) * dot(_1417, _1417)) * _1421;
    float3 _1449 = _1101 * _1446;
    float2 _1456 = _841 + (_851 + float2(_1102));
    float _1460 = float(all(uint2(_1103) < _1190));
    float _1480;
    float3 _1481;
    if (_1194)
    {
        float2 _1464 = _1456 * float2(_1185);
        float _1466 = precise::min(dot(_1464, _1464), 4.0);
        float _1468 = (0.4000000059604644775390625 * _1466) - 1.0;
        float _1470 = (0.25 * _1466) - 1.0;
        float _1476 = _1460 * ((((1.5625 * _1468) * _1468) - 0.5625) * (_1470 * _1470));
        _1480 = _1441 + _1476;
        _1481 = _1442 + (_1135 * _1476);
    }
    else
    {
        _1480 = _1441;
        _1481 = _1442;
    }
    float _1485 = exp((-2.2999999523162841796875) * dot(_1456, _1456)) * _1460;
    float3 _1488 = _1135 * _1485;
    float2 _1495 = _841 + (_851 + float2(_1136));
    float _1499 = float(all(uint2(_1137) < _1190));
    float _1519;
    float3 _1520;
    if (_1194)
    {
        float2 _1503 = _1495 * float2(_1185);
        float _1505 = precise::min(dot(_1503, _1503), 4.0);
        float _1507 = (0.4000000059604644775390625 * _1505) - 1.0;
        float _1509 = (0.25 * _1505) - 1.0;
        float _1515 = _1499 * ((((1.5625 * _1507) * _1507) - 0.5625) * (_1509 * _1509));
        _1519 = _1480 + _1515;
        _1520 = _1481 + (_1169 * _1515);
    }
    else
    {
        _1519 = _1480;
        _1520 = _1481;
    }
    float _1524 = exp((-2.2999999523162841796875) * dot(_1495, _1495)) * _1499;
    float3 _1527 = _1169 * _1524;
    float _1531 = (((((((_1217 + _1251) + _1290) + _1329) + _1368) + _1407) + _1446) + _1485) + _1524;
    float3 _1535 = float3((abs(_1531) > 1.1754943508222875079687365372222e-38) ? _1531 : 1.0);
    float3 _1536 = ((((((((_1218 + _1254) + _1293) + _1332) + _1371) + _1410) + _1449) + _1488) + _1527) / _1535;
    float _1544 = _1519 * float(_1519 > 6.099999882280826568603515625e-05);
    float3 _1552;
    float _1553;
    if (_1544 > 6.099999882280826568603515625e-05)
    {
        _1552 = fast::clamp(_1520 / float3(_1544), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_893, _928), _963), _998), _1032), _1066), _1101), _1135), _1169), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_893, _928), _963), _998), _1032), _1066), _1101), _1135), _1169));
        _1553 = _1544 * 0.04625000059604644775390625;
    }
    else
    {
        _1552 = _1520;
        _1553 = _1544;
    }
    float _1556 = _852 ? 1.0 : _1553;
    float _1557 = _852 ? 0.0 : _832;
    float3 _1571 = (sqrt(abs(((((((((((_893 * _1218) + (_928 * _1254)) + (_963 * _1293)) + (_998 * _1332)) + (_1032 * _1371)) + (_1066 * _1410)) + (_1101 * _1449)) + (_1135 * _1488)) + (_1169 * _1527)) / _1535) - (_1536 * _1536))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_149 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_129 * _183, _183 - float2(0.5))) / float2(int2(int(_177.x), int(_177.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _217, precise::max(powr(_206, 0.5), _210)))));
    float3 _1574 = (_777 - _1536) / precise::max(_1571, float3(1.19299997436428384389728307724e-07));
    float3 _1589;
    if (length(_1574) > 1.0)
    {
        _1589 = mix((fast::normalize(_1574) * _1571) + _1536, _777, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_122 * _127, _133)) / _136), level(0.0)).x, fast::clamp(fast::clamp(_787 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _217) * (1.0 - _208), 0.0, 1.0)));
    }
    else
    {
        _1589 = _777;
    }
    float3 _1598 = mix(_1589, select(_1552, _1536, bool3(_852)), float3(fast::clamp(_1556 / precise::max(6.099999882280826568603515625e-05, (_1557 * float(_1557 > 6.099999882280826568603515625e-05)) + _1556), 0.0, 1.0)));
    float _1599 = _1598.x;
    float _1600 = _1598.y;
    float _1602 = _1598.z;
    float4 _1609 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1610 = _1609.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(precise::max(float3((_1599 + _1600) - _1602, _1599 + _1602, (_1599 - _1600) - _1602) / float3((_1610 == 0.0) ? 1.0 : _1610), float3(0.0)), precise::max(0.0, precise::max(0.0, precise::min(_787 + (sdk_hlsl_load(rw_new_locks, uint2(_138)).x * (1.0 - precise::max(0.0, _206))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _784))) * float(_822)), uint2(_138));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_138));
}

