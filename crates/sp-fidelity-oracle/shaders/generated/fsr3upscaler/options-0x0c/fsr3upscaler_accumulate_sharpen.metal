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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_upscaled_output [[texture(3)]], texture2d<float> r_farthest_depth_mip1 [[texture(4)]], texture2d<float> r_luma_instability [[texture(5)]], texture2d<float, access::read_write> rw_new_locks [[texture(6)]], texture2d<float> r_dilated_motion_vectors [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_dilated_reactive_masks [[texture(9)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _119 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _123 = _119 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _128 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _130 = _123 + (cbFSR3Upscaler.fJitter / _128);
    float2 _134 = _128 - float2(0.5);
    float2 _137 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _139 = _123 * _128;
    float2 _144 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_139))), 0u).xy;
    float _146 = length(_144 * float2(3840.0, 2160.0));
    float2 _147 = _123 + _144;
    float _148 = _147.x;
    bool _153;
    if (_148 >= 0.0)
    {
        _153 = _148 <= 1.0;
    }
    else
    {
        _153 = false;
    }
    bool _162;
    if (_153)
    {
        float _156 = _147.y;
        bool _161;
        if (_156 >= 0.0)
        {
            _161 = _156 <= 1.0;
        }
        else
        {
            _161 = false;
        }
        _162 = _161;
    }
    else
    {
        _162 = false;
    }
    uint2 _173 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _179 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _196;
    if (_162)
    {
        _196 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _196 = true;
    }
    float4 _200 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_130 * _128, _134)) / _137), level(0.0));
    float _202 = fast::clamp(_200.x, 0.0, 1.0);
    float _204 = fast::clamp(_200.y, 0.0, 1.0);
    float _206 = fast::clamp(_200.z, 0.0, 1.0);
    float _208 = fast::clamp(_200.w, 0.0, 1.0);
    float _213 = _208 * float(rint(_208 * 100.0) > 1.0);
    bool _217;
    if (_162)
    {
        _217 = !_196;
    }
    else
    {
        _217 = false;
    }
    float3 _773;
    float _774;
    if (_217)
    {
        float2 _224 = (_147 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _226 = _224 - floor(_224);
        int2 _241 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _224.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _224.y)))));
        int2 _242 = _241 + int2(-1);
        int _244 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _248 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _255 = _241 + int2(0, -1);
        int2 _266 = _241 + int2(1, -1);
        int2 _277 = _241 + int2(2, -1);
        int2 _288 = _241 + int2(-1, 0);
        float4 _308 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_241.x, _244)), max(1, min(_241.y, _248))))), 0u);
        int2 _309 = _241 + int2(1, 0);
        float4 _319 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_309.x, _244)), max(1, min(_309.y, _248))))), 0u);
        int2 _320 = _241 + int2(2, 0);
        int2 _331 = _241 + int2(-1, 1);
        int2 _342 = _241 + int2(0, 1);
        float4 _352 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_342.x, _244)), max(1, min(_342.y, _248))))), 0u);
        int2 _353 = _241 + int2(1);
        float4 _363 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_353.x, _244)), max(1, min(_353.y, _248))))), 0u);
        int2 _364 = _241 + int2(2, 1);
        int2 _375 = _241 + int2(-1, 2);
        int2 _386 = _241 + int2(0, 2);
        int2 _397 = _241 + int2(1, 2);
        int2 _408 = _241 + int2(2);
        float _419 = _226.x;
        float _422 = precise::min(abs((-1.0) - _419), 2.0);
        bool _424 = abs(_422) < 6.099999882280826568603515625e-05;
        float _435;
        if (_424)
        {
            _435 = 1.0;
        }
        else
        {
            float _428 = 3.1415927410125732421875 * _422;
            float _431 = 1.57079637050628662109375 * _422;
            _435 = (sin(_428) / _428) * (sin(_431) / _431);
        }
        float _438 = precise::min(abs(-_419), 2.0);
        bool _440 = abs(_438) < 6.099999882280826568603515625e-05;
        float _451;
        if (_440)
        {
            _451 = 1.0;
        }
        else
        {
            float _444 = 3.1415927410125732421875 * _438;
            float _447 = 1.57079637050628662109375 * _438;
            _451 = (sin(_444) / _444) * (sin(_447) / _447);
        }
        float _454 = precise::min(abs(1.0 - _419), 2.0);
        bool _456 = abs(_454) < 6.099999882280826568603515625e-05;
        float _467;
        if (_456)
        {
            _467 = 1.0;
        }
        else
        {
            float _460 = 3.1415927410125732421875 * _454;
            float _463 = 1.57079637050628662109375 * _454;
            _467 = (sin(_460) / _460) * (sin(_463) / _463);
        }
        float _470 = precise::min(abs(2.0 - _419), 2.0);
        bool _472 = abs(_470) < 6.099999882280826568603515625e-05;
        float _483;
        if (_472)
        {
            _483 = 1.0;
        }
        else
        {
            float _476 = 3.1415927410125732421875 * _470;
            float _479 = 1.57079637050628662109375 * _470;
            _483 = (sin(_476) / _476) * (sin(_479) / _479);
        }
        float _506;
        if (_424)
        {
            _506 = 1.0;
        }
        else
        {
            float _499 = 3.1415927410125732421875 * _422;
            float _502 = 1.57079637050628662109375 * _422;
            _506 = (sin(_499) / _499) * (sin(_502) / _502);
        }
        float _517;
        if (_440)
        {
            _517 = 1.0;
        }
        else
        {
            float _510 = 3.1415927410125732421875 * _438;
            float _513 = 1.57079637050628662109375 * _438;
            _517 = (sin(_510) / _510) * (sin(_513) / _513);
        }
        float _528;
        if (_456)
        {
            _528 = 1.0;
        }
        else
        {
            float _521 = 3.1415927410125732421875 * _454;
            float _524 = 1.57079637050628662109375 * _454;
            _528 = (sin(_521) / _521) * (sin(_524) / _524);
        }
        float _539;
        if (_472)
        {
            _539 = 1.0;
        }
        else
        {
            float _532 = 3.1415927410125732421875 * _470;
            float _535 = 1.57079637050628662109375 * _470;
            _539 = (sin(_532) / _532) * (sin(_535) / _535);
        }
        float _562;
        if (_424)
        {
            _562 = 1.0;
        }
        else
        {
            float _555 = 3.1415927410125732421875 * _422;
            float _558 = 1.57079637050628662109375 * _422;
            _562 = (sin(_555) / _555) * (sin(_558) / _558);
        }
        float _573;
        if (_440)
        {
            _573 = 1.0;
        }
        else
        {
            float _566 = 3.1415927410125732421875 * _438;
            float _569 = 1.57079637050628662109375 * _438;
            _573 = (sin(_566) / _566) * (sin(_569) / _569);
        }
        float _584;
        if (_456)
        {
            _584 = 1.0;
        }
        else
        {
            float _577 = 3.1415927410125732421875 * _454;
            float _580 = 1.57079637050628662109375 * _454;
            _584 = (sin(_577) / _577) * (sin(_580) / _580);
        }
        float _595;
        if (_472)
        {
            _595 = 1.0;
        }
        else
        {
            float _588 = 3.1415927410125732421875 * _470;
            float _591 = 1.57079637050628662109375 * _470;
            _595 = (sin(_588) / _588) * (sin(_591) / _591);
        }
        float _618;
        if (_424)
        {
            _618 = 1.0;
        }
        else
        {
            float _611 = 3.1415927410125732421875 * _422;
            float _614 = 1.57079637050628662109375 * _422;
            _618 = (sin(_611) / _611) * (sin(_614) / _614);
        }
        float _629;
        if (_440)
        {
            _629 = 1.0;
        }
        else
        {
            float _622 = 3.1415927410125732421875 * _438;
            float _625 = 1.57079637050628662109375 * _438;
            _629 = (sin(_622) / _622) * (sin(_625) / _625);
        }
        float _640;
        if (_456)
        {
            _640 = 1.0;
        }
        else
        {
            float _633 = 3.1415927410125732421875 * _454;
            float _636 = 1.57079637050628662109375 * _454;
            _640 = (sin(_633) / _633) * (sin(_636) / _636);
        }
        float _651;
        if (_472)
        {
            _651 = 1.0;
        }
        else
        {
            float _644 = 3.1415927410125732421875 * _470;
            float _647 = 1.57079637050628662109375 * _470;
            _651 = (sin(_644) / _644) * (sin(_647) / _647);
        }
        float _664 = _226.y;
        float _667 = precise::min(abs((-1.0) - _664), 2.0);
        float _680;
        if (abs(_667) < 6.099999882280826568603515625e-05)
        {
            _680 = 1.0;
        }
        else
        {
            float _673 = 3.1415927410125732421875 * _667;
            float _676 = 1.57079637050628662109375 * _667;
            _680 = (sin(_673) / _673) * (sin(_676) / _676);
        }
        float _683 = precise::min(abs(-_664), 2.0);
        float _696;
        if (abs(_683) < 6.099999882280826568603515625e-05)
        {
            _696 = 1.0;
        }
        else
        {
            float _689 = 3.1415927410125732421875 * _683;
            float _692 = 1.57079637050628662109375 * _683;
            _696 = (sin(_689) / _689) * (sin(_692) / _692);
        }
        float _699 = precise::min(abs(1.0 - _664), 2.0);
        float _712;
        if (abs(_699) < 6.099999882280826568603515625e-05)
        {
            _712 = 1.0;
        }
        else
        {
            float _705 = 3.1415927410125732421875 * _699;
            float _708 = 1.57079637050628662109375 * _699;
            _712 = (sin(_705) / _705) * (sin(_708) / _708);
        }
        float _715 = precise::min(abs(2.0 - _664), 2.0);
        float _728;
        if (abs(_715) < 6.099999882280826568603515625e-05)
        {
            _728 = 1.0;
        }
        else
        {
            float _721 = 3.1415927410125732421875 * _715;
            float _724 = 1.57079637050628662109375 * _715;
            _728 = (sin(_721) / _721) * (sin(_724) / _724);
        }
        float4 _733 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_242.x, _244)), max(1, min(_242.y, _248))))), 0u) * _435) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_255.x, _244)), max(1, min(_255.y, _248))))), 0u) * _451)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_266.x, _244)), max(1, min(_266.y, _248))))), 0u) * _467)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_277.x, _244)), max(1, min(_277.y, _248))))), 0u) * _483)) / float4(((_435 + _451) + _467) + _483)) * _680) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_288.x, _244)), max(1, min(_288.y, _248))))), 0u) * _506) + (_308 * _517)) + (_319 * _528)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_320.x, _244)), max(1, min(_320.y, _248))))), 0u) * _539)) / float4(((_506 + _517) + _528) + _539)) * _696)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_331.x, _244)), max(1, min(_331.y, _248))))), 0u) * _562) + (_352 * _573)) + (_363 * _584)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_364.x, _244)), max(1, min(_364.y, _248))))), 0u) * _595)) / float4(((_562 + _573) + _584) + _595)) * _712);
        float4 _747 = fast::clamp((_733 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_375.x, _244)), max(1, min(_375.y, _248))))), 0u) * _618) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_386.x, _244)), max(1, min(_386.y, _248))))), 0u) * _629)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_397.x, _244)), max(1, min(_397.y, _248))))), 0u) * _640)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_408.x, _244)), max(1, min(_408.y, _248))))), 0u) * _651)) / float4(((_618 + _629) + _640) + _651)) * _728)) / float4(((_680 + _696) + _712) + _728), precise::min(precise::min(precise::min(_308, _319), _352), _363), precise::max(precise::max(precise::max(_308, _319), _352), _363));
        float4 _753 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _754 = _753.x;
        float3 _757 = (_747.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_754 == 0.0) ? 1.0 : _754);
        float _758 = _757.x;
        float _761 = 0.5 * _757.y;
        float _763 = _757.z;
        float _764 = 0.25 * _763;
        _773 = float3(((0.25 * _758) + _761) + _764, 0.5 * (_758 - _763), (((-0.25) * _758) + _761) - _764);
        _774 = _747.w;
    }
    else
    {
        _773 = float3(0.0);
        _774 = 0.0;
    }
    float _780 = precise::max(fast::clamp(_206, 0.0, 1.0), precise::max(_202, _204));
    float _783 = precise::max(0.0, (_774 * float(!_196)) - (_780 * 2.0));
    uint2 _787 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _804 = _123 - _144;
    float _805 = _804.x;
    bool _810;
    if (_805 >= 0.0)
    {
        _810 = _805 <= 1.0;
    }
    else
    {
        _810 = false;
    }
    bool _819;
    if (_810)
    {
        float _813 = _804.y;
        bool _818;
        if (_813 >= 0.0)
        {
            _818 = _813 <= 1.0;
        }
        else
        {
            _818 = false;
        }
        _819 = _818;
    }
    else
    {
        _819 = false;
    }
    float _829 = precise::min(_213, mix(_213, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_146 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _832 = _119 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _834 = int2(floor(_832));
    float2 _837 = (float2(_834) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _838 = _837 - _832;
    bool _841 = _837.x > _832.x;
    bool _845 = _837.y > _832.y;
    int2 _847 = int2(_841 ? (-2) : (-1), _845 ? (-2) : (-1));
    float2 _848 = float2(_847);
    bool _849 = _213 == 0.0;
    int _850 = _841 ? 3 : 0;
    int _851 = _845 ? 3 : 0;
    int2 _852 = int2(_850, _851);
    int2 _853 = _834 + _847;
    int2 _854 = _853 + _852;
    int _857 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _862 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _872 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _873 = _872.x;
    float3 _876 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_854.x, _857)), max(0, min(_854.y, _862))))), 0u).xyz) * ((_873 == 0.0) ? 1.0 : _873);
    float _877 = _876.x;
    float _880 = 0.5 * _876.y;
    float _882 = _876.z;
    float _883 = 0.25 * _882;
    float3 _890 = float3(((0.25 * _877) + _880) + _883, 0.5 * (_877 - _882), (((-0.25) * _877) + _880) - _883);
    int _891 = _841 ? 2 : 1;
    int2 _892 = int2(_891, _851);
    int2 _893 = _853 + _892;
    float4 _907 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _908 = _907.x;
    float3 _911 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_893.x, _857)), max(0, min(_893.y, _862))))), 0u).xyz) * ((_908 == 0.0) ? 1.0 : _908);
    float _912 = _911.x;
    float _915 = 0.5 * _911.y;
    float _917 = _911.z;
    float _918 = 0.25 * _917;
    float3 _925 = float3(((0.25 * _912) + _915) + _918, 0.5 * (_912 - _917), (((-0.25) * _912) + _915) - _918);
    int _926 = _841 ? 1 : 2;
    int2 _927 = int2(_926, _851);
    int2 _928 = _853 + _927;
    float4 _942 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _943 = _942.x;
    float3 _946 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_928.x, _857)), max(0, min(_928.y, _862))))), 0u).xyz) * ((_943 == 0.0) ? 1.0 : _943);
    float _947 = _946.x;
    float _950 = 0.5 * _946.y;
    float _952 = _946.z;
    float _953 = 0.25 * _952;
    float3 _960 = float3(((0.25 * _947) + _950) + _953, 0.5 * (_947 - _952), (((-0.25) * _947) + _950) - _953);
    int _961 = _845 ? 2 : 1;
    int2 _962 = int2(_850, _961);
    int2 _963 = _853 + _962;
    float4 _977 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _978 = _977.x;
    float3 _981 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_963.x, _857)), max(0, min(_963.y, _862))))), 0u).xyz) * ((_978 == 0.0) ? 1.0 : _978);
    float _982 = _981.x;
    float _985 = 0.5 * _981.y;
    float _987 = _981.z;
    float _988 = 0.25 * _987;
    float3 _995 = float3(((0.25 * _982) + _985) + _988, 0.5 * (_982 - _987), (((-0.25) * _982) + _985) - _988);
    int2 _996 = int2(_891, _961);
    int2 _997 = _853 + _996;
    float4 _1011 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1012 = _1011.x;
    float3 _1015 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_997.x, _857)), max(0, min(_997.y, _862))))), 0u).xyz) * ((_1012 == 0.0) ? 1.0 : _1012);
    float _1016 = _1015.x;
    float _1019 = 0.5 * _1015.y;
    float _1021 = _1015.z;
    float _1022 = 0.25 * _1021;
    float3 _1029 = float3(((0.25 * _1016) + _1019) + _1022, 0.5 * (_1016 - _1021), (((-0.25) * _1016) + _1019) - _1022);
    int2 _1030 = int2(_926, _961);
    int2 _1031 = _853 + _1030;
    float4 _1045 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1046 = _1045.x;
    float3 _1049 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1031.x, _857)), max(0, min(_1031.y, _862))))), 0u).xyz) * ((_1046 == 0.0) ? 1.0 : _1046);
    float _1050 = _1049.x;
    float _1053 = 0.5 * _1049.y;
    float _1055 = _1049.z;
    float _1056 = 0.25 * _1055;
    float3 _1063 = float3(((0.25 * _1050) + _1053) + _1056, 0.5 * (_1050 - _1055), (((-0.25) * _1050) + _1053) - _1056);
    int _1064 = _845 ? 1 : 2;
    int2 _1065 = int2(_850, _1064);
    int2 _1066 = _853 + _1065;
    float4 _1080 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1081 = _1080.x;
    float3 _1084 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1066.x, _857)), max(0, min(_1066.y, _862))))), 0u).xyz) * ((_1081 == 0.0) ? 1.0 : _1081);
    float _1085 = _1084.x;
    float _1088 = 0.5 * _1084.y;
    float _1090 = _1084.z;
    float _1091 = 0.25 * _1090;
    float3 _1098 = float3(((0.25 * _1085) + _1088) + _1091, 0.5 * (_1085 - _1090), (((-0.25) * _1085) + _1088) - _1091);
    int2 _1099 = int2(_891, _1064);
    int2 _1100 = _853 + _1099;
    float4 _1114 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1115 = _1114.x;
    float3 _1118 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1100.x, _857)), max(0, min(_1100.y, _862))))), 0u).xyz) * ((_1115 == 0.0) ? 1.0 : _1115);
    float _1119 = _1118.x;
    float _1122 = 0.5 * _1118.y;
    float _1124 = _1118.z;
    float _1125 = 0.25 * _1124;
    float3 _1132 = float3(((0.25 * _1119) + _1122) + _1125, 0.5 * (_1119 - _1124), (((-0.25) * _1119) + _1122) - _1125);
    int2 _1133 = int2(_926, _1064);
    int2 _1134 = _853 + _1133;
    float4 _1148 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1149 = _1148.x;
    float3 _1152 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1134.x, _857)), max(0, min(_1134.y, _862))))), 0u).xyz) * ((_1149 == 0.0) ? 1.0 : _1149);
    float _1153 = _1152.x;
    float _1156 = 0.5 * _1152.y;
    float _1158 = _1152.z;
    float _1159 = 0.25 * _1158;
    float3 _1166 = float3(((0.25 * _1153) + _1156) + _1159, 0.5 * (_1153 - _1158), (((-0.25) * _1153) + _1156) - _1159);
    float _1171 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1182 = mix(precise::max(1.0, (1.0 + _1171) * 0.300000011920928955078125), _1171, precise::min(1.0 - (_204 * 0.5), precise::min(1.0 - _206, fast::clamp(_829 * 5.0, 0.0, 1.0))));
    float2 _1185 = _838 + (_848 + float2(_852));
    uint2 _1187 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1190 = float(all(uint2(_854) < _1187));
    bool _1191 = !_849;
    float _1209;
    float3 _1210;
    if (_1191)
    {
        float2 _1195 = _1185 * float2(_1182);
        float _1197 = precise::min(dot(_1195, _1195), 4.0);
        float _1199 = (0.4000000059604644775390625 * _1197) - 1.0;
        float _1201 = (0.25 * _1197) - 1.0;
        float _1207 = _1190 * ((((1.5625 * _1199) * _1199) - 0.5625) * (_1201 * _1201));
        _1209 = _1207;
        _1210 = _890 * _1207;
    }
    else
    {
        _1209 = 0.0;
        _1210 = float3(0.0);
    }
    float _1214 = exp((-2.2999999523162841796875) * dot(_1185, _1185)) * _1190;
    float3 _1215 = _890 * _1214;
    float2 _1219 = _838 + (_848 + float2(_892));
    float _1223 = float(all(uint2(_893) < _1187));
    float _1243;
    float3 _1244;
    if (_1191)
    {
        float2 _1227 = _1219 * float2(_1182);
        float _1229 = precise::min(dot(_1227, _1227), 4.0);
        float _1231 = (0.4000000059604644775390625 * _1229) - 1.0;
        float _1233 = (0.25 * _1229) - 1.0;
        float _1239 = _1223 * ((((1.5625 * _1231) * _1231) - 0.5625) * (_1233 * _1233));
        _1243 = _1209 + _1239;
        _1244 = _1210 + (_925 * _1239);
    }
    else
    {
        _1243 = _1209;
        _1244 = _1210;
    }
    float _1248 = exp((-2.2999999523162841796875) * dot(_1219, _1219)) * _1223;
    float3 _1251 = _925 * _1248;
    float2 _1258 = _838 + (_848 + float2(_927));
    float _1262 = float(all(uint2(_928) < _1187));
    float _1282;
    float3 _1283;
    if (_1191)
    {
        float2 _1266 = _1258 * float2(_1182);
        float _1268 = precise::min(dot(_1266, _1266), 4.0);
        float _1270 = (0.4000000059604644775390625 * _1268) - 1.0;
        float _1272 = (0.25 * _1268) - 1.0;
        float _1278 = _1262 * ((((1.5625 * _1270) * _1270) - 0.5625) * (_1272 * _1272));
        _1282 = _1243 + _1278;
        _1283 = _1244 + (_960 * _1278);
    }
    else
    {
        _1282 = _1243;
        _1283 = _1244;
    }
    float _1287 = exp((-2.2999999523162841796875) * dot(_1258, _1258)) * _1262;
    float3 _1290 = _960 * _1287;
    float2 _1297 = _838 + (_848 + float2(_962));
    float _1301 = float(all(uint2(_963) < _1187));
    float _1321;
    float3 _1322;
    if (_1191)
    {
        float2 _1305 = _1297 * float2(_1182);
        float _1307 = precise::min(dot(_1305, _1305), 4.0);
        float _1309 = (0.4000000059604644775390625 * _1307) - 1.0;
        float _1311 = (0.25 * _1307) - 1.0;
        float _1317 = _1301 * ((((1.5625 * _1309) * _1309) - 0.5625) * (_1311 * _1311));
        _1321 = _1282 + _1317;
        _1322 = _1283 + (_995 * _1317);
    }
    else
    {
        _1321 = _1282;
        _1322 = _1283;
    }
    float _1326 = exp((-2.2999999523162841796875) * dot(_1297, _1297)) * _1301;
    float3 _1329 = _995 * _1326;
    float2 _1336 = _838 + (_848 + float2(_996));
    float _1340 = float(all(uint2(_997) < _1187));
    float _1360;
    float3 _1361;
    if (_1191)
    {
        float2 _1344 = _1336 * float2(_1182);
        float _1346 = precise::min(dot(_1344, _1344), 4.0);
        float _1348 = (0.4000000059604644775390625 * _1346) - 1.0;
        float _1350 = (0.25 * _1346) - 1.0;
        float _1356 = _1340 * ((((1.5625 * _1348) * _1348) - 0.5625) * (_1350 * _1350));
        _1360 = _1321 + _1356;
        _1361 = _1322 + (_1029 * _1356);
    }
    else
    {
        _1360 = _1321;
        _1361 = _1322;
    }
    float _1365 = exp((-2.2999999523162841796875) * dot(_1336, _1336)) * _1340;
    float3 _1368 = _1029 * _1365;
    float2 _1375 = _838 + (_848 + float2(_1030));
    float _1379 = float(all(uint2(_1031) < _1187));
    float _1399;
    float3 _1400;
    if (_1191)
    {
        float2 _1383 = _1375 * float2(_1182);
        float _1385 = precise::min(dot(_1383, _1383), 4.0);
        float _1387 = (0.4000000059604644775390625 * _1385) - 1.0;
        float _1389 = (0.25 * _1385) - 1.0;
        float _1395 = _1379 * ((((1.5625 * _1387) * _1387) - 0.5625) * (_1389 * _1389));
        _1399 = _1360 + _1395;
        _1400 = _1361 + (_1063 * _1395);
    }
    else
    {
        _1399 = _1360;
        _1400 = _1361;
    }
    float _1404 = exp((-2.2999999523162841796875) * dot(_1375, _1375)) * _1379;
    float3 _1407 = _1063 * _1404;
    float2 _1414 = _838 + (_848 + float2(_1065));
    float _1418 = float(all(uint2(_1066) < _1187));
    float _1438;
    float3 _1439;
    if (_1191)
    {
        float2 _1422 = _1414 * float2(_1182);
        float _1424 = precise::min(dot(_1422, _1422), 4.0);
        float _1426 = (0.4000000059604644775390625 * _1424) - 1.0;
        float _1428 = (0.25 * _1424) - 1.0;
        float _1434 = _1418 * ((((1.5625 * _1426) * _1426) - 0.5625) * (_1428 * _1428));
        _1438 = _1399 + _1434;
        _1439 = _1400 + (_1098 * _1434);
    }
    else
    {
        _1438 = _1399;
        _1439 = _1400;
    }
    float _1443 = exp((-2.2999999523162841796875) * dot(_1414, _1414)) * _1418;
    float3 _1446 = _1098 * _1443;
    float2 _1453 = _838 + (_848 + float2(_1099));
    float _1457 = float(all(uint2(_1100) < _1187));
    float _1477;
    float3 _1478;
    if (_1191)
    {
        float2 _1461 = _1453 * float2(_1182);
        float _1463 = precise::min(dot(_1461, _1461), 4.0);
        float _1465 = (0.4000000059604644775390625 * _1463) - 1.0;
        float _1467 = (0.25 * _1463) - 1.0;
        float _1473 = _1457 * ((((1.5625 * _1465) * _1465) - 0.5625) * (_1467 * _1467));
        _1477 = _1438 + _1473;
        _1478 = _1439 + (_1132 * _1473);
    }
    else
    {
        _1477 = _1438;
        _1478 = _1439;
    }
    float _1482 = exp((-2.2999999523162841796875) * dot(_1453, _1453)) * _1457;
    float3 _1485 = _1132 * _1482;
    float2 _1492 = _838 + (_848 + float2(_1133));
    float _1496 = float(all(uint2(_1134) < _1187));
    float _1516;
    float3 _1517;
    if (_1191)
    {
        float2 _1500 = _1492 * float2(_1182);
        float _1502 = precise::min(dot(_1500, _1500), 4.0);
        float _1504 = (0.4000000059604644775390625 * _1502) - 1.0;
        float _1506 = (0.25 * _1502) - 1.0;
        float _1512 = _1496 * ((((1.5625 * _1504) * _1504) - 0.5625) * (_1506 * _1506));
        _1516 = _1477 + _1512;
        _1517 = _1478 + (_1166 * _1512);
    }
    else
    {
        _1516 = _1477;
        _1517 = _1478;
    }
    float _1521 = exp((-2.2999999523162841796875) * dot(_1492, _1492)) * _1496;
    float3 _1524 = _1166 * _1521;
    float _1528 = (((((((_1214 + _1248) + _1287) + _1326) + _1365) + _1404) + _1443) + _1482) + _1521;
    float3 _1532 = float3((abs(_1528) > 1.1754943508222875079687365372222e-38) ? _1528 : 1.0);
    float3 _1533 = ((((((((_1215 + _1251) + _1290) + _1329) + _1368) + _1407) + _1446) + _1485) + _1524) / _1532;
    float _1541 = _1516 * float(_1516 > 6.099999882280826568603515625e-05);
    float3 _1549;
    float _1550;
    if (_1541 > 6.099999882280826568603515625e-05)
    {
        _1549 = fast::clamp(_1517 / float3(_1541), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_890, _925), _960), _995), _1029), _1063), _1098), _1132), _1166), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_890, _925), _960), _995), _1029), _1063), _1098), _1132), _1166));
        _1550 = _1541 * 0.04625000059604644775390625;
    }
    else
    {
        _1549 = _1517;
        _1550 = _1541;
    }
    float _1553 = _849 ? 1.0 : _1550;
    float _1554 = _849 ? 0.0 : _829;
    float3 _1568 = (sqrt(abs(((((((((((_890 * _1215) + (_925 * _1251)) + (_960 * _1290)) + (_995 * _1329)) + (_1029 * _1368)) + (_1063 * _1407)) + (_1098 * _1446)) + (_1132 * _1485)) + (_1166 * _1524)) / _1532) - (_1533 * _1533))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_146 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_130 * _179, _179 - float2(0.5))) / float2(int2(int(_173.x), int(_173.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _213, precise::max(powr(_202, 0.5), _206)))));
    float3 _1571 = (_773 - _1533) / precise::max(_1568, float3(1.19299997436428384389728307724e-07));
    float3 _1586;
    if (length(_1571) > 1.0)
    {
        _1586 = mix((fast::normalize(_1571) * _1568) + _1533, _773, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_139, _134)) / _137), level(0.0)).x, fast::clamp(fast::clamp(_783 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _213) * (1.0 - _204), 0.0, 1.0)));
    }
    else
    {
        _1586 = _773;
    }
    float3 _1595 = mix(_1586, select(_1549, _1533, bool3(_849)), float3(fast::clamp(_1553 / precise::max(6.099999882280826568603515625e-05, (_1554 * float(_1554 > 6.099999882280826568603515625e-05)) + _1553), 0.0, 1.0)));
    float _1596 = _1595.x;
    float _1597 = _1595.y;
    float _1599 = _1595.z;
    float4 _1606 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1607 = _1606.x;
    float3 _1612 = precise::max(float3((_1596 + _1597) - _1599, _1596 + _1599, (_1596 - _1597) - _1599) / float3((_1607 == 0.0) ? 1.0 : _1607), float3(0.0));
    float _1613 = _1612.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1613, _1612.yz, precise::max(0.0, precise::max(0.0, precise::min(_783 + (sdk_hlsl_load(rw_new_locks, uint2(_787)).x * (1.0 - precise::max(0.0, _202))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _780))) * float(_819)), uint2(_787));
    sdk_hlsl_store(rw_upscaled_output, float4(_1613, _1612.yz, 1.0), uint2(_787));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_787));
}

