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
    float2 _126 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _130 = _126 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _135 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _137 = _130 + (cbFSR3Upscaler.fJitter / _135);
    float2 _141 = _135 - float2(0.5);
    float2 _144 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _146 = _130 * _135;
    float2 _151 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(_146))), 0u).xy;
    float _153 = length(_151 * float2(3840.0, 2160.0));
    float2 _154 = _130 + _151;
    float _155 = _154.x;
    bool _160;
    if (_155 >= 0.0)
    {
        _160 = _155 <= 1.0;
    }
    else
    {
        _160 = false;
    }
    bool _169;
    if (_160)
    {
        float _163 = _154.y;
        bool _168;
        if (_163 >= 0.0)
        {
            _168 = _163 <= 1.0;
        }
        else
        {
            _168 = false;
        }
        _169 = _168;
    }
    else
    {
        _169 = false;
    }
    uint2 _180 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _186 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _203;
    if (_169)
    {
        _203 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _203 = true;
    }
    float4 _207 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_137 * _135, _141)) / _144), level(0.0));
    float _209 = fast::clamp(_207.x, 0.0, 1.0);
    float _211 = fast::clamp(_207.y, 0.0, 1.0);
    float _213 = fast::clamp(_207.z, 0.0, 1.0);
    float _215 = fast::clamp(_207.w, 0.0, 1.0);
    float _220 = _215 * float(rint(_215 * 100.0) > 1.0);
    bool _224;
    if (_169)
    {
        _224 = !_203;
    }
    else
    {
        _224 = false;
    }
    float3 _652;
    float _653;
    if (_224)
    {
        float2 _231 = (_154 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
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
        float2 _432 = float2(abs((-1.0) - _426) * 0.5, 0.5);
        float4 _434 = r_lanczos_lut.sample(s_LinearClamp, _432, level(0.0));
        float _435 = _434.x;
        float2 _441 = float2(abs(-_426) * 0.5, 0.5);
        float4 _443 = r_lanczos_lut.sample(s_LinearClamp, _441, level(0.0));
        float _444 = _443.x;
        float2 _450 = float2(abs(1.0 - _426) * 0.5, 0.5);
        float4 _452 = r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0));
        float _453 = _452.x;
        float2 _459 = float2(abs(2.0 - _426) * 0.5, 0.5);
        float4 _461 = r_lanczos_lut.sample(s_LinearClamp, _459, level(0.0));
        float _462 = _461.x;
        float4 _478 = r_lanczos_lut.sample(s_LinearClamp, _432, level(0.0));
        float _479 = _478.x;
        float4 _483 = r_lanczos_lut.sample(s_LinearClamp, _441, level(0.0));
        float _484 = _483.x;
        float4 _488 = r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0));
        float _489 = _488.x;
        float4 _493 = r_lanczos_lut.sample(s_LinearClamp, _459, level(0.0));
        float _494 = _493.x;
        float4 _510 = r_lanczos_lut.sample(s_LinearClamp, _432, level(0.0));
        float _511 = _510.x;
        float4 _515 = r_lanczos_lut.sample(s_LinearClamp, _441, level(0.0));
        float _516 = _515.x;
        float4 _520 = r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0));
        float _521 = _520.x;
        float4 _525 = r_lanczos_lut.sample(s_LinearClamp, _459, level(0.0));
        float _526 = _525.x;
        float4 _542 = r_lanczos_lut.sample(s_LinearClamp, _432, level(0.0));
        float _543 = _542.x;
        float4 _547 = r_lanczos_lut.sample(s_LinearClamp, _441, level(0.0));
        float _548 = _547.x;
        float4 _552 = r_lanczos_lut.sample(s_LinearClamp, _450, level(0.0));
        float _553 = _552.x;
        float4 _557 = r_lanczos_lut.sample(s_LinearClamp, _459, level(0.0));
        float _558 = _557.x;
        float _571 = _233.y;
        float4 _579 = r_lanczos_lut.sample(s_LinearClamp, float2(abs((-1.0) - _571) * 0.5, 0.5), level(0.0));
        float _580 = _579.x;
        float4 _588 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(-_571) * 0.5, 0.5), level(0.0));
        float _589 = _588.x;
        float4 _597 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(1.0 - _571) * 0.5, 0.5), level(0.0));
        float _598 = _597.x;
        float4 _606 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(2.0 - _571) * 0.5, 0.5), level(0.0));
        float _607 = _606.x;
        float4 _612 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_249.x, _251)), max(1, min(_249.y, _255))))), 0u) * _435) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_262.x, _251)), max(1, min(_262.y, _255))))), 0u) * _444)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_273.x, _251)), max(1, min(_273.y, _255))))), 0u) * _453)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_284.x, _251)), max(1, min(_284.y, _255))))), 0u) * _462)) / float4(((_435 + _444) + _453) + _462)) * _580) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_295.x, _251)), max(1, min(_295.y, _255))))), 0u) * _479) + (_315 * _484)) + (_326 * _489)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_327.x, _251)), max(1, min(_327.y, _255))))), 0u) * _494)) / float4(((_479 + _484) + _489) + _494)) * _589)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_338.x, _251)), max(1, min(_338.y, _255))))), 0u) * _511) + (_359 * _516)) + (_370 * _521)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_371.x, _251)), max(1, min(_371.y, _255))))), 0u) * _526)) / float4(((_511 + _516) + _521) + _526)) * _598);
        float4 _626 = fast::clamp((_612 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_382.x, _251)), max(1, min(_382.y, _255))))), 0u) * _543) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_393.x, _251)), max(1, min(_393.y, _255))))), 0u) * _548)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_404.x, _251)), max(1, min(_404.y, _255))))), 0u) * _553)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_415.x, _251)), max(1, min(_415.y, _255))))), 0u) * _558)) / float4(((_543 + _548) + _553) + _558)) * _607)) / float4(((_580 + _589) + _598) + _607), precise::min(precise::min(precise::min(_315, _326), _359), _370), precise::max(precise::max(precise::max(_315, _326), _359), _370));
        float4 _632 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _633 = _632.x;
        float3 _636 = (_626.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_633 == 0.0) ? 1.0 : _633);
        float _637 = _636.x;
        float _640 = 0.5 * _636.y;
        float _642 = _636.z;
        float _643 = 0.25 * _642;
        _652 = float3(((0.25 * _637) + _640) + _643, 0.5 * (_637 - _642), (((-0.25) * _637) + _640) - _643);
        _653 = _626.w;
    }
    else
    {
        _652 = float3(0.0);
        _653 = 0.0;
    }
    float _659 = precise::max(fast::clamp(_213, 0.0, 1.0), precise::max(_209, _211));
    float _662 = precise::max(0.0, (_653 * float(!_203)) - (_659 * 2.0));
    uint2 _666 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _683 = _130 - _151;
    float _684 = _683.x;
    bool _689;
    if (_684 >= 0.0)
    {
        _689 = _684 <= 1.0;
    }
    else
    {
        _689 = false;
    }
    bool _698;
    if (_689)
    {
        float _692 = _683.y;
        bool _697;
        if (_692 >= 0.0)
        {
            _697 = _692 <= 1.0;
        }
        else
        {
            _697 = false;
        }
        _698 = _697;
    }
    else
    {
        _698 = false;
    }
    float _708 = precise::min(_220, mix(_220, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_153 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _711 = _126 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _713 = int2(floor(_711));
    float2 _716 = (float2(_713) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _717 = _716 - _711;
    bool _720 = _716.x > _711.x;
    bool _724 = _716.y > _711.y;
    int2 _726 = int2(_720 ? (-2) : (-1), _724 ? (-2) : (-1));
    float2 _727 = float2(_726);
    bool _728 = _220 == 0.0;
    int _729 = _720 ? 3 : 0;
    int _730 = _724 ? 3 : 0;
    int2 _731 = int2(_729, _730);
    int2 _732 = _713 + _726;
    int2 _733 = _732 + _731;
    int _736 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _741 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _751 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _752 = _751.x;
    float3 _755 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_733.x, _736)), max(0, min(_733.y, _741))))), 0u).xyz) * ((_752 == 0.0) ? 1.0 : _752);
    float _756 = _755.x;
    float _759 = 0.5 * _755.y;
    float _761 = _755.z;
    float _762 = 0.25 * _761;
    spvUnsafeArray<float3, 9> _122;
    _122[0] = float3(((0.25 * _756) + _759) + _762, 0.5 * (_756 - _761), (((-0.25) * _756) + _759) - _762);
    int _771 = _720 ? 2 : 1;
    int2 _772 = int2(_771, _730);
    int2 _773 = _732 + _772;
    float4 _787 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _788 = _787.x;
    float3 _791 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_773.x, _736)), max(0, min(_773.y, _741))))), 0u).xyz) * ((_788 == 0.0) ? 1.0 : _788);
    float _792 = _791.x;
    float _795 = 0.5 * _791.y;
    float _797 = _791.z;
    float _798 = 0.25 * _797;
    _122[1] = float3(((0.25 * _792) + _795) + _798, 0.5 * (_792 - _797), (((-0.25) * _792) + _795) - _798);
    int _807 = _720 ? 1 : 2;
    int2 _808 = int2(_807, _730);
    int2 _809 = _732 + _808;
    float4 _823 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _824 = _823.x;
    float3 _827 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_809.x, _736)), max(0, min(_809.y, _741))))), 0u).xyz) * ((_824 == 0.0) ? 1.0 : _824);
    float _828 = _827.x;
    float _831 = 0.5 * _827.y;
    float _833 = _827.z;
    float _834 = 0.25 * _833;
    _122[2] = float3(((0.25 * _828) + _831) + _834, 0.5 * (_828 - _833), (((-0.25) * _828) + _831) - _834);
    int _843 = _724 ? 2 : 1;
    int2 _844 = int2(_729, _843);
    int2 _845 = _732 + _844;
    float4 _859 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _860 = _859.x;
    float3 _863 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_845.x, _736)), max(0, min(_845.y, _741))))), 0u).xyz) * ((_860 == 0.0) ? 1.0 : _860);
    float _864 = _863.x;
    float _867 = 0.5 * _863.y;
    float _869 = _863.z;
    float _870 = 0.25 * _869;
    _122[3] = float3(((0.25 * _864) + _867) + _870, 0.5 * (_864 - _869), (((-0.25) * _864) + _867) - _870);
    int2 _879 = int2(_771, _843);
    int2 _880 = _732 + _879;
    float4 _894 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _895 = _894.x;
    float3 _898 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_880.x, _736)), max(0, min(_880.y, _741))))), 0u).xyz) * ((_895 == 0.0) ? 1.0 : _895);
    float _899 = _898.x;
    float _902 = 0.5 * _898.y;
    float _904 = _898.z;
    float _905 = 0.25 * _904;
    _122[4] = float3(((0.25 * _899) + _902) + _905, 0.5 * (_899 - _904), (((-0.25) * _899) + _902) - _905);
    int2 _914 = int2(_807, _843);
    int2 _915 = _732 + _914;
    float4 _929 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _930 = _929.x;
    float3 _933 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_915.x, _736)), max(0, min(_915.y, _741))))), 0u).xyz) * ((_930 == 0.0) ? 1.0 : _930);
    float _934 = _933.x;
    float _937 = 0.5 * _933.y;
    float _939 = _933.z;
    float _940 = 0.25 * _939;
    _122[5] = float3(((0.25 * _934) + _937) + _940, 0.5 * (_934 - _939), (((-0.25) * _934) + _937) - _940);
    int _949 = _724 ? 1 : 2;
    int2 _950 = int2(_729, _949);
    int2 _951 = _732 + _950;
    float4 _965 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _966 = _965.x;
    float3 _969 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_951.x, _736)), max(0, min(_951.y, _741))))), 0u).xyz) * ((_966 == 0.0) ? 1.0 : _966);
    float _970 = _969.x;
    float _973 = 0.5 * _969.y;
    float _975 = _969.z;
    float _976 = 0.25 * _975;
    _122[6] = float3(((0.25 * _970) + _973) + _976, 0.5 * (_970 - _975), (((-0.25) * _970) + _973) - _976);
    int2 _985 = int2(_771, _949);
    int2 _986 = _732 + _985;
    float4 _1000 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1001 = _1000.x;
    float3 _1004 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_986.x, _736)), max(0, min(_986.y, _741))))), 0u).xyz) * ((_1001 == 0.0) ? 1.0 : _1001);
    float _1005 = _1004.x;
    float _1008 = 0.5 * _1004.y;
    float _1010 = _1004.z;
    float _1011 = 0.25 * _1010;
    _122[7] = float3(((0.25 * _1005) + _1008) + _1011, 0.5 * (_1005 - _1010), (((-0.25) * _1005) + _1008) - _1011);
    int2 _1020 = int2(_807, _949);
    int2 _1021 = _732 + _1020;
    float4 _1035 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1036 = _1035.x;
    float3 _1039 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1021.x, _736)), max(0, min(_1021.y, _741))))), 0u).xyz) * ((_1036 == 0.0) ? 1.0 : _1036);
    float _1040 = _1039.x;
    float _1043 = 0.5 * _1039.y;
    float _1045 = _1039.z;
    float _1046 = 0.25 * _1045;
    _122[8] = float3(((0.25 * _1040) + _1043) + _1046, 0.5 * (_1040 - _1045), (((-0.25) * _1040) + _1043) - _1046);
    if (_728)
    {
        for (int _1058 = 0; _1058 < 9; )
        {
            float _1069 = (_122[_1058].x + _122[_1058].y) - _122[_1058].z;
            float _1070 = _122[_1058].x + _122[_1058].z;
            float _1072 = (_122[_1058].x - _122[_1058].y) - _122[_1058].z;
            float3 _1079 = float3(_1069, _1070, _1072) / float3(precise::max(precise::max(0.0, _1069), precise::max(_1070, _1072)) + 1.0);
            float _1080 = _1079.x;
            float _1083 = 0.5 * _1079.y;
            float _1085 = _1079.z;
            float _1086 = 0.25 * _1085;
            _122[_1058] = float3(((0.25 * _1080) + _1083) + _1086, 0.5 * (_1080 - _1085), (((-0.25) * _1080) + _1083) - _1086);
            _1058++;
            continue;
        }
    }
    float _1098 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1109 = mix(precise::max(1.0, (1.0 + _1098) * 0.300000011920928955078125), _1098, precise::min(1.0 - (_211 * 0.5), precise::min(1.0 - _213, fast::clamp(_708 * 5.0, 0.0, 1.0))));
    float2 _1112 = _717 + (_727 + float2(_731));
    uint2 _1114 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1117 = float(all(uint2(_733) < _1114));
    bool _1118 = !_728;
    float _1137;
    float3 _1138;
    if (_1118)
    {
        float2 _1122 = _1112 * float2(_1109);
        float _1124 = precise::min(dot(_1122, _1122), 4.0);
        float _1126 = (0.4000000059604644775390625 * _1124) - 1.0;
        float _1128 = (0.25 * _1124) - 1.0;
        float _1134 = _1117 * ((((1.5625 * _1126) * _1126) - 0.5625) * (_1128 * _1128));
        _1137 = _1134;
        _1138 = _122[0] * _1134;
    }
    else
    {
        _1137 = 0.0;
        _1138 = float3(0.0);
    }
    float _1142 = exp((-2.2999999523162841796875) * dot(_1112, _1112)) * _1117;
    float3 _1144 = _122[0] * _1142;
    float2 _1148 = _717 + (_727 + float2(_772));
    float _1152 = float(all(uint2(_773) < _1114));
    float _1173;
    float3 _1174;
    if (_1118)
    {
        float2 _1156 = _1148 * float2(_1109);
        float _1158 = precise::min(dot(_1156, _1156), 4.0);
        float _1160 = (0.4000000059604644775390625 * _1158) - 1.0;
        float _1162 = (0.25 * _1158) - 1.0;
        float _1168 = _1152 * ((((1.5625 * _1160) * _1160) - 0.5625) * (_1162 * _1162));
        _1173 = _1137 + _1168;
        _1174 = _1138 + (_122[1] * _1168);
    }
    else
    {
        _1173 = _1137;
        _1174 = _1138;
    }
    float _1178 = exp((-2.2999999523162841796875) * dot(_1148, _1148)) * _1152;
    float3 _1182 = _122[1] * _1178;
    float2 _1189 = _717 + (_727 + float2(_808));
    float _1193 = float(all(uint2(_809) < _1114));
    float _1214;
    float3 _1215;
    if (_1118)
    {
        float2 _1197 = _1189 * float2(_1109);
        float _1199 = precise::min(dot(_1197, _1197), 4.0);
        float _1201 = (0.4000000059604644775390625 * _1199) - 1.0;
        float _1203 = (0.25 * _1199) - 1.0;
        float _1209 = _1193 * ((((1.5625 * _1201) * _1201) - 0.5625) * (_1203 * _1203));
        _1214 = _1173 + _1209;
        _1215 = _1174 + (_122[2] * _1209);
    }
    else
    {
        _1214 = _1173;
        _1215 = _1174;
    }
    float _1219 = exp((-2.2999999523162841796875) * dot(_1189, _1189)) * _1193;
    float3 _1223 = _122[2] * _1219;
    float2 _1230 = _717 + (_727 + float2(_844));
    float _1234 = float(all(uint2(_845) < _1114));
    float _1255;
    float3 _1256;
    if (_1118)
    {
        float2 _1238 = _1230 * float2(_1109);
        float _1240 = precise::min(dot(_1238, _1238), 4.0);
        float _1242 = (0.4000000059604644775390625 * _1240) - 1.0;
        float _1244 = (0.25 * _1240) - 1.0;
        float _1250 = _1234 * ((((1.5625 * _1242) * _1242) - 0.5625) * (_1244 * _1244));
        _1255 = _1214 + _1250;
        _1256 = _1215 + (_122[3] * _1250);
    }
    else
    {
        _1255 = _1214;
        _1256 = _1215;
    }
    float _1260 = exp((-2.2999999523162841796875) * dot(_1230, _1230)) * _1234;
    float3 _1264 = _122[3] * _1260;
    float2 _1271 = _717 + (_727 + float2(_879));
    float _1275 = float(all(uint2(_880) < _1114));
    float _1296;
    float3 _1297;
    if (_1118)
    {
        float2 _1279 = _1271 * float2(_1109);
        float _1281 = precise::min(dot(_1279, _1279), 4.0);
        float _1283 = (0.4000000059604644775390625 * _1281) - 1.0;
        float _1285 = (0.25 * _1281) - 1.0;
        float _1291 = _1275 * ((((1.5625 * _1283) * _1283) - 0.5625) * (_1285 * _1285));
        _1296 = _1255 + _1291;
        _1297 = _1256 + (_122[4] * _1291);
    }
    else
    {
        _1296 = _1255;
        _1297 = _1256;
    }
    float _1301 = exp((-2.2999999523162841796875) * dot(_1271, _1271)) * _1275;
    float3 _1305 = _122[4] * _1301;
    float2 _1312 = _717 + (_727 + float2(_914));
    float _1316 = float(all(uint2(_915) < _1114));
    float _1337;
    float3 _1338;
    if (_1118)
    {
        float2 _1320 = _1312 * float2(_1109);
        float _1322 = precise::min(dot(_1320, _1320), 4.0);
        float _1324 = (0.4000000059604644775390625 * _1322) - 1.0;
        float _1326 = (0.25 * _1322) - 1.0;
        float _1332 = _1316 * ((((1.5625 * _1324) * _1324) - 0.5625) * (_1326 * _1326));
        _1337 = _1296 + _1332;
        _1338 = _1297 + (_122[5] * _1332);
    }
    else
    {
        _1337 = _1296;
        _1338 = _1297;
    }
    float _1342 = exp((-2.2999999523162841796875) * dot(_1312, _1312)) * _1316;
    float3 _1346 = _122[5] * _1342;
    float2 _1353 = _717 + (_727 + float2(_950));
    float _1357 = float(all(uint2(_951) < _1114));
    float _1378;
    float3 _1379;
    if (_1118)
    {
        float2 _1361 = _1353 * float2(_1109);
        float _1363 = precise::min(dot(_1361, _1361), 4.0);
        float _1365 = (0.4000000059604644775390625 * _1363) - 1.0;
        float _1367 = (0.25 * _1363) - 1.0;
        float _1373 = _1357 * ((((1.5625 * _1365) * _1365) - 0.5625) * (_1367 * _1367));
        _1378 = _1337 + _1373;
        _1379 = _1338 + (_122[6] * _1373);
    }
    else
    {
        _1378 = _1337;
        _1379 = _1338;
    }
    float _1383 = exp((-2.2999999523162841796875) * dot(_1353, _1353)) * _1357;
    float3 _1387 = _122[6] * _1383;
    float2 _1394 = _717 + (_727 + float2(_985));
    float _1398 = float(all(uint2(_986) < _1114));
    float _1419;
    float3 _1420;
    if (_1118)
    {
        float2 _1402 = _1394 * float2(_1109);
        float _1404 = precise::min(dot(_1402, _1402), 4.0);
        float _1406 = (0.4000000059604644775390625 * _1404) - 1.0;
        float _1408 = (0.25 * _1404) - 1.0;
        float _1414 = _1398 * ((((1.5625 * _1406) * _1406) - 0.5625) * (_1408 * _1408));
        _1419 = _1378 + _1414;
        _1420 = _1379 + (_122[7] * _1414);
    }
    else
    {
        _1419 = _1378;
        _1420 = _1379;
    }
    float _1424 = exp((-2.2999999523162841796875) * dot(_1394, _1394)) * _1398;
    float3 _1428 = _122[7] * _1424;
    float2 _1435 = _717 + (_727 + float2(_1020));
    float _1439 = float(all(uint2(_1021) < _1114));
    float _1460;
    float3 _1461;
    if (_1118)
    {
        float2 _1443 = _1435 * float2(_1109);
        float _1445 = precise::min(dot(_1443, _1443), 4.0);
        float _1447 = (0.4000000059604644775390625 * _1445) - 1.0;
        float _1449 = (0.25 * _1445) - 1.0;
        float _1455 = _1439 * ((((1.5625 * _1447) * _1447) - 0.5625) * (_1449 * _1449));
        _1460 = _1419 + _1455;
        _1461 = _1420 + (_122[8] * _1455);
    }
    else
    {
        _1460 = _1419;
        _1461 = _1420;
    }
    float _1465 = exp((-2.2999999523162841796875) * dot(_1435, _1435)) * _1439;
    float3 _1469 = _122[8] * _1465;
    float _1473 = (((((((_1142 + _1178) + _1219) + _1260) + _1301) + _1342) + _1383) + _1424) + _1465;
    float3 _1477 = float3((abs(_1473) > 1.1754943508222875079687365372222e-38) ? _1473 : 1.0);
    float3 _1478 = ((((((((_1144 + _1182) + _1223) + _1264) + _1305) + _1346) + _1387) + _1428) + _1469) / _1477;
    float _1486 = _1460 * float(_1460 > 6.099999882280826568603515625e-05);
    float3 _1494;
    float _1495;
    if (_1486 > 6.099999882280826568603515625e-05)
    {
        _1494 = fast::clamp(_1461 / float3(_1486), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_122[0], _122[1]), _122[2]), _122[3]), _122[4]), _122[5]), _122[6]), _122[7]), _122[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_122[0], _122[1]), _122[2]), _122[3]), _122[4]), _122[5]), _122[6]), _122[7]), _122[8]));
        _1495 = _1486 * 0.04625000059604644775390625;
    }
    else
    {
        _1494 = _1461;
        _1495 = _1486;
    }
    float3 _1527;
    if (_728)
    {
        float _1498 = _1478.x;
        float _1499 = _1478.y;
        float _1501 = _1478.z;
        float _1502 = (_1498 + _1499) - _1501;
        float _1503 = _1498 + _1501;
        float _1505 = (_1498 - _1499) - _1501;
        float3 _1512 = float3(_1502, _1503, _1505) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1502, precise::max(_1503, _1505))));
        float _1513 = _1512.x;
        float _1516 = 0.5 * _1512.y;
        float _1518 = _1512.z;
        float _1519 = 0.25 * _1518;
        _1527 = float3(((0.25 * _1513) + _1516) + _1519, 0.5 * (_1513 - _1518), (((-0.25) * _1513) + _1516) - _1519);
    }
    else
    {
        _1527 = _1494;
    }
    float _1528 = _728 ? 1.0 : _1495;
    float _1529 = _728 ? 0.0 : _708;
    float3 _1543 = (sqrt(abs(((((((((((_122[0] * _1144) + (_122[1] * _1182)) + (_122[2] * _1223)) + (_122[3] * _1264)) + (_122[4] * _1305)) + (_122[5] * _1346)) + (_122[6] * _1387)) + (_122[7] * _1428)) + (_122[8] * _1469)) / _1477) - (_1478 * _1478))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_153 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_137 * _186, _186 - float2(0.5))) / float2(int2(int(_180.x), int(_180.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _220, precise::max(powr(_209, 0.5), _213)))));
    float3 _1546 = (_652 - _1478) / precise::max(_1543, float3(1.19299997436428384389728307724e-07));
    float3 _1561;
    if (length(_1546) > 1.0)
    {
        _1561 = mix((fast::normalize(_1546) * _1543) + _1478, _652, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_146, _141)) / _144), level(0.0)).x, fast::clamp(fast::clamp(_662 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _220) * (1.0 - _211), 0.0, 1.0)));
    }
    else
    {
        _1561 = _652;
    }
    float _1571 = (_1527.x + _1527.y) - _1527.z;
    float _1572 = _1527.x + _1527.z;
    float _1574 = (_1527.x - _1527.y) - _1527.z;
    float3 _1581 = float3(_1571, _1572, _1574) / float3(precise::max(precise::max(0.0, _1571), precise::max(_1572, _1574)) + 1.0);
    float _1582 = _1581.x;
    float _1585 = 0.5 * _1581.y;
    float _1587 = _1581.z;
    float _1588 = 0.25 * _1587;
    float _1600 = (_1561.x + _1561.y) - _1561.z;
    float _1601 = _1561.x + _1561.z;
    float _1603 = (_1561.x - _1561.y) - _1561.z;
    float3 _1610 = float3(_1600, _1601, _1603) / float3(precise::max(precise::max(0.0, _1600), precise::max(_1601, _1603)) + 1.0);
    float _1611 = _1610.x;
    float _1614 = 0.5 * _1610.y;
    float _1616 = _1610.z;
    float _1617 = 0.25 * _1616;
    float3 _1628 = mix(float3(((0.25 * _1611) + _1614) + _1617, 0.5 * (_1611 - _1616), (((-0.25) * _1611) + _1614) - _1617), float3(((0.25 * _1582) + _1585) + _1588, 0.5 * (_1582 - _1587), (((-0.25) * _1582) + _1585) - _1588), float3(fast::clamp(_1528 / precise::max(6.099999882280826568603515625e-05, (_1529 * float(_1529 > 6.099999882280826568603515625e-05)) + _1528), 0.0, 1.0)));
    float _1633 = (_1628.x + _1628.y) - _1628.z;
    float _1634 = _1628.x + _1628.z;
    float _1636 = (_1628.x - _1628.y) - _1628.z;
    float4 _1645 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1646 = _1645.x;
    float3 _1651 = precise::max((float3(_1633, _1634, _1636) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1633, precise::max(_1634, _1636))))) / float3((_1646 == 0.0) ? 1.0 : _1646), float3(0.0));
    float _1652 = _1651.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1652, _1651.yz, precise::max(0.0, precise::max(0.0, precise::min(_662 + (sdk_hlsl_load(rw_new_locks, uint2(_666)).x * (1.0 - precise::max(0.0, _209))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _659))) * float(_698)), uint2(_666));
    sdk_hlsl_store(rw_upscaled_output, float4(_1652, _1651.yz, 1.0), uint2(_666));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_666));
}

