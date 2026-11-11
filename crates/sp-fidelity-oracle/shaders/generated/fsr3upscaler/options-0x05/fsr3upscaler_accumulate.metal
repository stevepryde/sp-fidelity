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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_internal_upscaled_color [[texture(1)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_upscaled_output [[texture(3)]], texture2d<float> r_farthest_depth_mip1 [[texture(4)]], texture2d<float> r_luma_instability [[texture(5)]], texture2d<float, access::read_write> rw_new_locks [[texture(6)]], texture2d<float> r_dilated_motion_vectors [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_lanczos_lut [[texture(9)]], texture2d<float> r_dilated_reactive_masks [[texture(10)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _118 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _122 = _118 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _127 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _129 = _122 + (cbFSR3Upscaler.fJitter / _127);
    float2 _133 = _127 - float2(0.5);
    float2 _136 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _138 = _122 * _127;
    float2 _143 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_138))), 0u).xy;
    float _145 = length(_143 * float2(3840.0, 2160.0));
    float2 _146 = _122 + _143;
    float _147 = _146.x;
    bool _152;
    if (_147 >= 0.0)
    {
        _152 = _147 <= 1.0;
    }
    else
    {
        _152 = false;
    }
    bool _161;
    if (_152)
    {
        float _155 = _146.y;
        bool _160;
        if (_155 >= 0.0)
        {
            _160 = _155 <= 1.0;
        }
        else
        {
            _160 = false;
        }
        _161 = _160;
    }
    else
    {
        _161 = false;
    }
    uint2 _172 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _178 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _195;
    if (_161)
    {
        _195 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _195 = true;
    }
    float4 _199 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_129 * _127, _133)) / _136), level(0.0));
    float _201 = fast::clamp(_199.x, 0.0, 1.0);
    float _203 = fast::clamp(_199.y, 0.0, 1.0);
    float _205 = fast::clamp(_199.z, 0.0, 1.0);
    float _207 = fast::clamp(_199.w, 0.0, 1.0);
    float _212 = _207 * float(rint(_207 * 100.0) > 1.0);
    bool _216;
    if (_161)
    {
        _216 = !_195;
    }
    else
    {
        _216 = false;
    }
    float3 _644;
    float _645;
    if (_216)
    {
        float2 _223 = (_146 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _225 = _223 - floor(_223);
        int2 _240 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _223.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _223.y)))));
        int2 _241 = _240 + int2(-1);
        int _243 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _247 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _254 = _240 + int2(0, -1);
        int2 _265 = _240 + int2(1, -1);
        int2 _276 = _240 + int2(2, -1);
        int2 _287 = _240 + int2(-1, 0);
        float4 _307 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_240.x, _243)), max(1, min(_240.y, _247))))), 0u);
        int2 _308 = _240 + int2(1, 0);
        float4 _318 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_308.x, _243)), max(1, min(_308.y, _247))))), 0u);
        int2 _319 = _240 + int2(2, 0);
        int2 _330 = _240 + int2(-1, 1);
        int2 _341 = _240 + int2(0, 1);
        float4 _351 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_341.x, _243)), max(1, min(_341.y, _247))))), 0u);
        int2 _352 = _240 + int2(1);
        float4 _362 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_352.x, _243)), max(1, min(_352.y, _247))))), 0u);
        int2 _363 = _240 + int2(2, 1);
        int2 _374 = _240 + int2(-1, 2);
        int2 _385 = _240 + int2(0, 2);
        int2 _396 = _240 + int2(1, 2);
        int2 _407 = _240 + int2(2);
        float _418 = _225.x;
        float2 _424 = float2(abs((-1.0) - _418) * 0.5, 0.5);
        float4 _426 = r_lanczos_lut.sample(s_LinearClamp, _424, level(0.0));
        float _427 = _426.x;
        float2 _433 = float2(abs(-_418) * 0.5, 0.5);
        float4 _435 = r_lanczos_lut.sample(s_LinearClamp, _433, level(0.0));
        float _436 = _435.x;
        float2 _442 = float2(abs(1.0 - _418) * 0.5, 0.5);
        float4 _444 = r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0));
        float _445 = _444.x;
        float2 _451 = float2(abs(2.0 - _418) * 0.5, 0.5);
        float4 _453 = r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0));
        float _454 = _453.x;
        float4 _470 = r_lanczos_lut.sample(s_LinearClamp, _424, level(0.0));
        float _471 = _470.x;
        float4 _475 = r_lanczos_lut.sample(s_LinearClamp, _433, level(0.0));
        float _476 = _475.x;
        float4 _480 = r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0));
        float _481 = _480.x;
        float4 _485 = r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0));
        float _486 = _485.x;
        float4 _502 = r_lanczos_lut.sample(s_LinearClamp, _424, level(0.0));
        float _503 = _502.x;
        float4 _507 = r_lanczos_lut.sample(s_LinearClamp, _433, level(0.0));
        float _508 = _507.x;
        float4 _512 = r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0));
        float _513 = _512.x;
        float4 _517 = r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0));
        float _518 = _517.x;
        float4 _534 = r_lanczos_lut.sample(s_LinearClamp, _424, level(0.0));
        float _535 = _534.x;
        float4 _539 = r_lanczos_lut.sample(s_LinearClamp, _433, level(0.0));
        float _540 = _539.x;
        float4 _544 = r_lanczos_lut.sample(s_LinearClamp, _442, level(0.0));
        float _545 = _544.x;
        float4 _549 = r_lanczos_lut.sample(s_LinearClamp, _451, level(0.0));
        float _550 = _549.x;
        float _563 = _225.y;
        float4 _571 = r_lanczos_lut.sample(s_LinearClamp, float2(abs((-1.0) - _563) * 0.5, 0.5), level(0.0));
        float _572 = _571.x;
        float4 _580 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(-_563) * 0.5, 0.5), level(0.0));
        float _581 = _580.x;
        float4 _589 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(1.0 - _563) * 0.5, 0.5), level(0.0));
        float _590 = _589.x;
        float4 _598 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(2.0 - _563) * 0.5, 0.5), level(0.0));
        float _599 = _598.x;
        float4 _604 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_241.x, _243)), max(1, min(_241.y, _247))))), 0u) * _427) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_254.x, _243)), max(1, min(_254.y, _247))))), 0u) * _436)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_265.x, _243)), max(1, min(_265.y, _247))))), 0u) * _445)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_276.x, _243)), max(1, min(_276.y, _247))))), 0u) * _454)) / float4(((_427 + _436) + _445) + _454)) * _572) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_287.x, _243)), max(1, min(_287.y, _247))))), 0u) * _471) + (_307 * _476)) + (_318 * _481)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_319.x, _243)), max(1, min(_319.y, _247))))), 0u) * _486)) / float4(((_471 + _476) + _481) + _486)) * _581)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_330.x, _243)), max(1, min(_330.y, _247))))), 0u) * _503) + (_351 * _508)) + (_362 * _513)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_363.x, _243)), max(1, min(_363.y, _247))))), 0u) * _518)) / float4(((_503 + _508) + _513) + _518)) * _590);
        float4 _618 = fast::clamp((_604 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_374.x, _243)), max(1, min(_374.y, _247))))), 0u) * _535) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_385.x, _243)), max(1, min(_385.y, _247))))), 0u) * _540)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_396.x, _243)), max(1, min(_396.y, _247))))), 0u) * _545)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_407.x, _243)), max(1, min(_407.y, _247))))), 0u) * _550)) / float4(((_535 + _540) + _545) + _550)) * _599)) / float4(((_572 + _581) + _590) + _599), precise::min(precise::min(precise::min(_307, _318), _351), _362), precise::max(precise::max(precise::max(_307, _318), _351), _362));
        float4 _624 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _625 = _624.x;
        float3 _628 = (_618.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_625 == 0.0) ? 1.0 : _625);
        float _629 = _628.x;
        float _632 = 0.5 * _628.y;
        float _634 = _628.z;
        float _635 = 0.25 * _634;
        _644 = float3(((0.25 * _629) + _632) + _635, 0.5 * (_629 - _634), (((-0.25) * _629) + _632) - _635);
        _645 = _618.w;
    }
    else
    {
        _644 = float3(0.0);
        _645 = 0.0;
    }
    float _651 = precise::max(fast::clamp(_205, 0.0, 1.0), precise::max(_201, _203));
    float _654 = precise::max(0.0, (_645 * float(!_195)) - (_651 * 2.0));
    uint2 _658 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _675 = _122 - _143;
    float _676 = _675.x;
    bool _681;
    if (_676 >= 0.0)
    {
        _681 = _676 <= 1.0;
    }
    else
    {
        _681 = false;
    }
    bool _690;
    if (_681)
    {
        float _684 = _675.y;
        bool _689;
        if (_684 >= 0.0)
        {
            _689 = _684 <= 1.0;
        }
        else
        {
            _689 = false;
        }
        _690 = _689;
    }
    else
    {
        _690 = false;
    }
    float _700 = precise::min(_212, mix(_212, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_145 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _703 = _118 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _705 = int2(floor(_703));
    float2 _708 = (float2(_705) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _709 = _708 - _703;
    bool _712 = _708.x > _703.x;
    bool _716 = _708.y > _703.y;
    int2 _718 = int2(_712 ? (-2) : (-1), _716 ? (-2) : (-1));
    float2 _719 = float2(_718);
    bool _720 = _212 == 0.0;
    int _721 = _712 ? 3 : 0;
    int _722 = _716 ? 3 : 0;
    int2 _723 = int2(_721, _722);
    int2 _724 = _705 + _718;
    int2 _725 = _724 + _723;
    int _728 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _733 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _743 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _744 = _743.x;
    float3 _747 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_725.x, _728)), max(0, min(_725.y, _733))))), 0u).xyz) * ((_744 == 0.0) ? 1.0 : _744);
    float _748 = _747.x;
    float _751 = 0.5 * _747.y;
    float _753 = _747.z;
    float _754 = 0.25 * _753;
    float3 _761 = float3(((0.25 * _748) + _751) + _754, 0.5 * (_748 - _753), (((-0.25) * _748) + _751) - _754);
    int _762 = _712 ? 2 : 1;
    int2 _763 = int2(_762, _722);
    int2 _764 = _724 + _763;
    float4 _778 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _779 = _778.x;
    float3 _782 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_764.x, _728)), max(0, min(_764.y, _733))))), 0u).xyz) * ((_779 == 0.0) ? 1.0 : _779);
    float _783 = _782.x;
    float _786 = 0.5 * _782.y;
    float _788 = _782.z;
    float _789 = 0.25 * _788;
    float3 _796 = float3(((0.25 * _783) + _786) + _789, 0.5 * (_783 - _788), (((-0.25) * _783) + _786) - _789);
    int _797 = _712 ? 1 : 2;
    int2 _798 = int2(_797, _722);
    int2 _799 = _724 + _798;
    float4 _813 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _814 = _813.x;
    float3 _817 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_799.x, _728)), max(0, min(_799.y, _733))))), 0u).xyz) * ((_814 == 0.0) ? 1.0 : _814);
    float _818 = _817.x;
    float _821 = 0.5 * _817.y;
    float _823 = _817.z;
    float _824 = 0.25 * _823;
    float3 _831 = float3(((0.25 * _818) + _821) + _824, 0.5 * (_818 - _823), (((-0.25) * _818) + _821) - _824);
    int _832 = _716 ? 2 : 1;
    int2 _833 = int2(_721, _832);
    int2 _834 = _724 + _833;
    float4 _848 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _849 = _848.x;
    float3 _852 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_834.x, _728)), max(0, min(_834.y, _733))))), 0u).xyz) * ((_849 == 0.0) ? 1.0 : _849);
    float _853 = _852.x;
    float _856 = 0.5 * _852.y;
    float _858 = _852.z;
    float _859 = 0.25 * _858;
    float3 _866 = float3(((0.25 * _853) + _856) + _859, 0.5 * (_853 - _858), (((-0.25) * _853) + _856) - _859);
    int2 _867 = int2(_762, _832);
    int2 _868 = _724 + _867;
    float4 _882 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _883 = _882.x;
    float3 _886 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_868.x, _728)), max(0, min(_868.y, _733))))), 0u).xyz) * ((_883 == 0.0) ? 1.0 : _883);
    float _887 = _886.x;
    float _890 = 0.5 * _886.y;
    float _892 = _886.z;
    float _893 = 0.25 * _892;
    float3 _900 = float3(((0.25 * _887) + _890) + _893, 0.5 * (_887 - _892), (((-0.25) * _887) + _890) - _893);
    int2 _901 = int2(_797, _832);
    int2 _902 = _724 + _901;
    float4 _916 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _917 = _916.x;
    float3 _920 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_902.x, _728)), max(0, min(_902.y, _733))))), 0u).xyz) * ((_917 == 0.0) ? 1.0 : _917);
    float _921 = _920.x;
    float _924 = 0.5 * _920.y;
    float _926 = _920.z;
    float _927 = 0.25 * _926;
    float3 _934 = float3(((0.25 * _921) + _924) + _927, 0.5 * (_921 - _926), (((-0.25) * _921) + _924) - _927);
    int _935 = _716 ? 1 : 2;
    int2 _936 = int2(_721, _935);
    int2 _937 = _724 + _936;
    float4 _951 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _952 = _951.x;
    float3 _955 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_937.x, _728)), max(0, min(_937.y, _733))))), 0u).xyz) * ((_952 == 0.0) ? 1.0 : _952);
    float _956 = _955.x;
    float _959 = 0.5 * _955.y;
    float _961 = _955.z;
    float _962 = 0.25 * _961;
    float3 _969 = float3(((0.25 * _956) + _959) + _962, 0.5 * (_956 - _961), (((-0.25) * _956) + _959) - _962);
    int2 _970 = int2(_762, _935);
    int2 _971 = _724 + _970;
    float4 _985 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _986 = _985.x;
    float3 _989 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_971.x, _728)), max(0, min(_971.y, _733))))), 0u).xyz) * ((_986 == 0.0) ? 1.0 : _986);
    float _990 = _989.x;
    float _993 = 0.5 * _989.y;
    float _995 = _989.z;
    float _996 = 0.25 * _995;
    float3 _1003 = float3(((0.25 * _990) + _993) + _996, 0.5 * (_990 - _995), (((-0.25) * _990) + _993) - _996);
    int2 _1004 = int2(_797, _935);
    int2 _1005 = _724 + _1004;
    float4 _1019 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1020 = _1019.x;
    float3 _1023 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1005.x, _728)), max(0, min(_1005.y, _733))))), 0u).xyz) * ((_1020 == 0.0) ? 1.0 : _1020);
    float _1024 = _1023.x;
    float _1027 = 0.5 * _1023.y;
    float _1029 = _1023.z;
    float _1030 = 0.25 * _1029;
    float3 _1037 = float3(((0.25 * _1024) + _1027) + _1030, 0.5 * (_1024 - _1029), (((-0.25) * _1024) + _1027) - _1030);
    float _1042 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1053 = mix(precise::max(1.0, (1.0 + _1042) * 0.300000011920928955078125), _1042, precise::min(1.0 - (_203 * 0.5), precise::min(1.0 - _205, fast::clamp(_700 * 5.0, 0.0, 1.0))));
    float2 _1056 = _709 + (_719 + float2(_723));
    uint2 _1058 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1061 = float(all(uint2(_725) < _1058));
    bool _1062 = !_720;
    float _1080;
    float3 _1081;
    if (_1062)
    {
        float2 _1066 = _1056 * float2(_1053);
        float _1068 = precise::min(dot(_1066, _1066), 4.0);
        float _1070 = (0.4000000059604644775390625 * _1068) - 1.0;
        float _1072 = (0.25 * _1068) - 1.0;
        float _1078 = _1061 * ((((1.5625 * _1070) * _1070) - 0.5625) * (_1072 * _1072));
        _1080 = _1078;
        _1081 = _761 * _1078;
    }
    else
    {
        _1080 = 0.0;
        _1081 = float3(0.0);
    }
    float _1085 = exp((-2.2999999523162841796875) * dot(_1056, _1056)) * _1061;
    float3 _1086 = _761 * _1085;
    float2 _1090 = _709 + (_719 + float2(_763));
    float _1094 = float(all(uint2(_764) < _1058));
    float _1114;
    float3 _1115;
    if (_1062)
    {
        float2 _1098 = _1090 * float2(_1053);
        float _1100 = precise::min(dot(_1098, _1098), 4.0);
        float _1102 = (0.4000000059604644775390625 * _1100) - 1.0;
        float _1104 = (0.25 * _1100) - 1.0;
        float _1110 = _1094 * ((((1.5625 * _1102) * _1102) - 0.5625) * (_1104 * _1104));
        _1114 = _1080 + _1110;
        _1115 = _1081 + (_796 * _1110);
    }
    else
    {
        _1114 = _1080;
        _1115 = _1081;
    }
    float _1119 = exp((-2.2999999523162841796875) * dot(_1090, _1090)) * _1094;
    float3 _1122 = _796 * _1119;
    float2 _1129 = _709 + (_719 + float2(_798));
    float _1133 = float(all(uint2(_799) < _1058));
    float _1153;
    float3 _1154;
    if (_1062)
    {
        float2 _1137 = _1129 * float2(_1053);
        float _1139 = precise::min(dot(_1137, _1137), 4.0);
        float _1141 = (0.4000000059604644775390625 * _1139) - 1.0;
        float _1143 = (0.25 * _1139) - 1.0;
        float _1149 = _1133 * ((((1.5625 * _1141) * _1141) - 0.5625) * (_1143 * _1143));
        _1153 = _1114 + _1149;
        _1154 = _1115 + (_831 * _1149);
    }
    else
    {
        _1153 = _1114;
        _1154 = _1115;
    }
    float _1158 = exp((-2.2999999523162841796875) * dot(_1129, _1129)) * _1133;
    float3 _1161 = _831 * _1158;
    float2 _1168 = _709 + (_719 + float2(_833));
    float _1172 = float(all(uint2(_834) < _1058));
    float _1192;
    float3 _1193;
    if (_1062)
    {
        float2 _1176 = _1168 * float2(_1053);
        float _1178 = precise::min(dot(_1176, _1176), 4.0);
        float _1180 = (0.4000000059604644775390625 * _1178) - 1.0;
        float _1182 = (0.25 * _1178) - 1.0;
        float _1188 = _1172 * ((((1.5625 * _1180) * _1180) - 0.5625) * (_1182 * _1182));
        _1192 = _1153 + _1188;
        _1193 = _1154 + (_866 * _1188);
    }
    else
    {
        _1192 = _1153;
        _1193 = _1154;
    }
    float _1197 = exp((-2.2999999523162841796875) * dot(_1168, _1168)) * _1172;
    float3 _1200 = _866 * _1197;
    float2 _1207 = _709 + (_719 + float2(_867));
    float _1211 = float(all(uint2(_868) < _1058));
    float _1231;
    float3 _1232;
    if (_1062)
    {
        float2 _1215 = _1207 * float2(_1053);
        float _1217 = precise::min(dot(_1215, _1215), 4.0);
        float _1219 = (0.4000000059604644775390625 * _1217) - 1.0;
        float _1221 = (0.25 * _1217) - 1.0;
        float _1227 = _1211 * ((((1.5625 * _1219) * _1219) - 0.5625) * (_1221 * _1221));
        _1231 = _1192 + _1227;
        _1232 = _1193 + (_900 * _1227);
    }
    else
    {
        _1231 = _1192;
        _1232 = _1193;
    }
    float _1236 = exp((-2.2999999523162841796875) * dot(_1207, _1207)) * _1211;
    float3 _1239 = _900 * _1236;
    float2 _1246 = _709 + (_719 + float2(_901));
    float _1250 = float(all(uint2(_902) < _1058));
    float _1270;
    float3 _1271;
    if (_1062)
    {
        float2 _1254 = _1246 * float2(_1053);
        float _1256 = precise::min(dot(_1254, _1254), 4.0);
        float _1258 = (0.4000000059604644775390625 * _1256) - 1.0;
        float _1260 = (0.25 * _1256) - 1.0;
        float _1266 = _1250 * ((((1.5625 * _1258) * _1258) - 0.5625) * (_1260 * _1260));
        _1270 = _1231 + _1266;
        _1271 = _1232 + (_934 * _1266);
    }
    else
    {
        _1270 = _1231;
        _1271 = _1232;
    }
    float _1275 = exp((-2.2999999523162841796875) * dot(_1246, _1246)) * _1250;
    float3 _1278 = _934 * _1275;
    float2 _1285 = _709 + (_719 + float2(_936));
    float _1289 = float(all(uint2(_937) < _1058));
    float _1309;
    float3 _1310;
    if (_1062)
    {
        float2 _1293 = _1285 * float2(_1053);
        float _1295 = precise::min(dot(_1293, _1293), 4.0);
        float _1297 = (0.4000000059604644775390625 * _1295) - 1.0;
        float _1299 = (0.25 * _1295) - 1.0;
        float _1305 = _1289 * ((((1.5625 * _1297) * _1297) - 0.5625) * (_1299 * _1299));
        _1309 = _1270 + _1305;
        _1310 = _1271 + (_969 * _1305);
    }
    else
    {
        _1309 = _1270;
        _1310 = _1271;
    }
    float _1314 = exp((-2.2999999523162841796875) * dot(_1285, _1285)) * _1289;
    float3 _1317 = _969 * _1314;
    float2 _1324 = _709 + (_719 + float2(_970));
    float _1328 = float(all(uint2(_971) < _1058));
    float _1348;
    float3 _1349;
    if (_1062)
    {
        float2 _1332 = _1324 * float2(_1053);
        float _1334 = precise::min(dot(_1332, _1332), 4.0);
        float _1336 = (0.4000000059604644775390625 * _1334) - 1.0;
        float _1338 = (0.25 * _1334) - 1.0;
        float _1344 = _1328 * ((((1.5625 * _1336) * _1336) - 0.5625) * (_1338 * _1338));
        _1348 = _1309 + _1344;
        _1349 = _1310 + (_1003 * _1344);
    }
    else
    {
        _1348 = _1309;
        _1349 = _1310;
    }
    float _1353 = exp((-2.2999999523162841796875) * dot(_1324, _1324)) * _1328;
    float3 _1356 = _1003 * _1353;
    float2 _1363 = _709 + (_719 + float2(_1004));
    float _1367 = float(all(uint2(_1005) < _1058));
    float _1387;
    float3 _1388;
    if (_1062)
    {
        float2 _1371 = _1363 * float2(_1053);
        float _1373 = precise::min(dot(_1371, _1371), 4.0);
        float _1375 = (0.4000000059604644775390625 * _1373) - 1.0;
        float _1377 = (0.25 * _1373) - 1.0;
        float _1383 = _1367 * ((((1.5625 * _1375) * _1375) - 0.5625) * (_1377 * _1377));
        _1387 = _1348 + _1383;
        _1388 = _1349 + (_1037 * _1383);
    }
    else
    {
        _1387 = _1348;
        _1388 = _1349;
    }
    float _1392 = exp((-2.2999999523162841796875) * dot(_1363, _1363)) * _1367;
    float3 _1395 = _1037 * _1392;
    float _1399 = (((((((_1085 + _1119) + _1158) + _1197) + _1236) + _1275) + _1314) + _1353) + _1392;
    float3 _1403 = float3((abs(_1399) > 1.1754943508222875079687365372222e-38) ? _1399 : 1.0);
    float3 _1404 = ((((((((_1086 + _1122) + _1161) + _1200) + _1239) + _1278) + _1317) + _1356) + _1395) / _1403;
    float _1412 = _1387 * float(_1387 > 6.099999882280826568603515625e-05);
    float3 _1420;
    float _1421;
    if (_1412 > 6.099999882280826568603515625e-05)
    {
        _1420 = fast::clamp(_1388 / float3(_1412), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_761, _796), _831), _866), _900), _934), _969), _1003), _1037), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_761, _796), _831), _866), _900), _934), _969), _1003), _1037));
        _1421 = _1412 * 0.04625000059604644775390625;
    }
    else
    {
        _1420 = _1388;
        _1421 = _1412;
    }
    float _1424 = _720 ? 1.0 : _1421;
    float _1425 = _720 ? 0.0 : _700;
    float3 _1439 = (sqrt(abs(((((((((((_761 * _1086) + (_796 * _1122)) + (_831 * _1161)) + (_866 * _1200)) + (_900 * _1239)) + (_934 * _1278)) + (_969 * _1317)) + (_1003 * _1356)) + (_1037 * _1395)) / _1403) - (_1404 * _1404))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_145 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_129 * _178, _178 - float2(0.5))) / float2(int2(int(_172.x), int(_172.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _212, precise::max(powr(_201, 0.5), _205)))));
    float3 _1442 = (_644 - _1404) / precise::max(_1439, float3(1.19299997436428384389728307724e-07));
    float3 _1457;
    if (length(_1442) > 1.0)
    {
        _1457 = mix((fast::normalize(_1442) * _1439) + _1404, _644, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138, _133)) / _136), level(0.0)).x, fast::clamp(fast::clamp(_654 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _212) * (1.0 - _203), 0.0, 1.0)));
    }
    else
    {
        _1457 = _644;
    }
    float3 _1466 = mix(_1457, select(_1420, _1404, bool3(_720)), float3(fast::clamp(_1424 / precise::max(6.099999882280826568603515625e-05, (_1425 * float(_1425 > 6.099999882280826568603515625e-05)) + _1424), 0.0, 1.0)));
    float _1467 = _1466.x;
    float _1468 = _1466.y;
    float _1470 = _1466.z;
    float4 _1477 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1478 = _1477.x;
    float3 _1483 = precise::max(float3((_1467 + _1468) - _1470, _1467 + _1470, (_1467 - _1468) - _1470) / float3((_1478 == 0.0) ? 1.0 : _1478), float3(0.0));
    float _1484 = _1483.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1484, _1483.yz, precise::max(0.0, precise::max(0.0, precise::min(_654 + (sdk_hlsl_load(rw_new_locks, uint2(_658)).x * (1.0 - precise::max(0.0, _201))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _651))) * float(_690)), uint2(_658));
    sdk_hlsl_store(rw_upscaled_output, float4(_1484, _1483.yz, 1.0), uint2(_658));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_658));
}

