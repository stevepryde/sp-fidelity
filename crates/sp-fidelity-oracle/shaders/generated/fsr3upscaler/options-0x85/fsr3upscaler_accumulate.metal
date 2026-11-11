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
    float2 _126 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _129 = float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _130 = _126 / _129;
    float2 _135 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _137 = _130 + (cbFSR3Upscaler.fJitter / _135);
    float2 _141 = _135 - float2(0.5);
    float2 _144 = float2(cbFSR3Upscaler.iMaxRenderSize);
    float2 _146 = _130 * _135;
    float2 _152 = sdk_hlsl_load(r_dilated_motion_vectors, uint2(uint2(int2(short2(_146)))), 0u).xy;
    float _154 = length(_152 * float2(3840.0, 2160.0));
    float2 _155 = _130 + _152;
    float _156 = _155.x;
    bool _161;
    if (_156 >= 0.0)
    {
        _161 = _156 <= 1.0;
    }
    else
    {
        _161 = false;
    }
    bool _170;
    if (_161)
    {
        float _164 = _155.y;
        bool _169;
        if (_164 >= 0.0)
        {
            _169 = _164 <= 1.0;
        }
        else
        {
            _169 = false;
        }
        _170 = _169;
    }
    else
    {
        _170 = false;
    }
    uint2 _181 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _187 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _204;
    if (_170)
    {
        _204 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _204 = true;
    }
    float4 _208 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_137 * _135, _141)) / _144), level(0.0));
    float _210 = fast::clamp(_208.x, 0.0, 1.0);
    float _212 = fast::clamp(_208.y, 0.0, 1.0);
    float _214 = fast::clamp(_208.z, 0.0, 1.0);
    float _216 = fast::clamp(_208.w, 0.0, 1.0);
    float _221 = _216 * float(rint(_216 * 100.0) > 1.0);
    bool _225;
    if (_170)
    {
        _225 = !_204;
    }
    else
    {
        _225 = false;
    }
    float3 _694;
    float _695;
    if (_225)
    {
        float2 _229 = (_155 * _129) - float2(0.5);
        half2 _232 = half2(_229 - floor(_229));
        int2 _245 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.x), _229.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iUpscaleSize.y), _229.y)))));
        int2 _246 = _245 + int2(-1);
        int _248 = cbFSR3Upscaler.iUpscaleSize.x - 2;
        int _252 = cbFSR3Upscaler.iUpscaleSize.y - 2;
        int2 _260 = _245 + int2(0, -1);
        int2 _272 = _245 + int2(1, -1);
        int2 _284 = _245 + int2(2, -1);
        int2 _296 = _245 + int2(-1, 0);
        half4 _318 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_245.x, _248)), max(1, min(_245.y, _252))))), 0u));
        int2 _319 = _245 + int2(1, 0);
        half4 _330 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_319.x, _248)), max(1, min(_319.y, _252))))), 0u));
        int2 _331 = _245 + int2(2, 0);
        int2 _343 = _245 + int2(-1, 1);
        int2 _355 = _245 + int2(0, 1);
        half4 _366 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_355.x, _248)), max(1, min(_355.y, _252))))), 0u));
        int2 _367 = _245 + int2(1);
        half4 _378 = half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_367.x, _248)), max(1, min(_367.y, _252))))), 0u));
        int2 _379 = _245 + int2(2, 1);
        int2 _391 = _245 + int2(-1, 2);
        int2 _403 = _245 + int2(0, 2);
        int2 _415 = _245 + int2(1, 2);
        int2 _427 = _245 + int2(2);
        half _439 = _232.x;
        float2 _446 = float2(float(abs(half(-1.0) - _439)) * 0.5, 0.5);
        half _450 = half(r_lanczos_lut.sample(s_LinearClamp, _446, level(0.0)).x);
        float2 _457 = float2(float(abs(half(-0.0) - _439)) * 0.5, 0.5);
        half _461 = half(r_lanczos_lut.sample(s_LinearClamp, _457, level(0.0)).x);
        float2 _468 = float2(float(abs(half(1.0) - _439)) * 0.5, 0.5);
        half _472 = half(r_lanczos_lut.sample(s_LinearClamp, _468, level(0.0)).x);
        float2 _479 = float2(float(abs(half(2.0) - _439)) * 0.5, 0.5);
        half _483 = half(r_lanczos_lut.sample(s_LinearClamp, _479, level(0.0)).x);
        half _501 = half(r_lanczos_lut.sample(s_LinearClamp, _446, level(0.0)).x);
        half _507 = half(r_lanczos_lut.sample(s_LinearClamp, _457, level(0.0)).x);
        half _513 = half(r_lanczos_lut.sample(s_LinearClamp, _468, level(0.0)).x);
        half _519 = half(r_lanczos_lut.sample(s_LinearClamp, _479, level(0.0)).x);
        half _537 = half(r_lanczos_lut.sample(s_LinearClamp, _446, level(0.0)).x);
        half _543 = half(r_lanczos_lut.sample(s_LinearClamp, _457, level(0.0)).x);
        half _549 = half(r_lanczos_lut.sample(s_LinearClamp, _468, level(0.0)).x);
        half _555 = half(r_lanczos_lut.sample(s_LinearClamp, _479, level(0.0)).x);
        half _573 = half(r_lanczos_lut.sample(s_LinearClamp, _446, level(0.0)).x);
        half _579 = half(r_lanczos_lut.sample(s_LinearClamp, _457, level(0.0)).x);
        half _585 = half(r_lanczos_lut.sample(s_LinearClamp, _468, level(0.0)).x);
        half _591 = half(r_lanczos_lut.sample(s_LinearClamp, _479, level(0.0)).x);
        half _604 = _232.y;
        half _615 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-1.0) - _604)) * 0.5, 0.5), level(0.0)).x);
        half _626 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(-0.0) - _604)) * 0.5, 0.5), level(0.0)).x);
        half _637 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(1.0) - _604)) * 0.5, 0.5), level(0.0)).x);
        half _648 = half(r_lanczos_lut.sample(s_LinearClamp, float2(float(abs(half(2.0) - _604)) * 0.5, 0.5), level(0.0)).x);
        half4 _653 = (((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_246.x, _248)), max(1, min(_246.y, _252))))), 0u)) * _450) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_260.x, _248)), max(1, min(_260.y, _252))))), 0u)) * _461)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_272.x, _248)), max(1, min(_272.y, _252))))), 0u)) * _472)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_284.x, _248)), max(1, min(_284.y, _252))))), 0u)) * _483)) / half4(((_450 + _461) + _472) + _483)) * _615) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_296.x, _248)), max(1, min(_296.y, _252))))), 0u)) * _501) + (_318 * _507)) + (_330 * _513)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_331.x, _248)), max(1, min(_331.y, _252))))), 0u)) * _519)) / half4(((_501 + _507) + _513) + _519)) * _626)) + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_343.x, _248)), max(1, min(_343.y, _252))))), 0u)) * _537) + (_366 * _543)) + (_378 * _549)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_379.x, _248)), max(1, min(_379.y, _252))))), 0u)) * _555)) / half4(((_537 + _543) + _549) + _555)) * _637);
        half4 _660 = (_653 + ((((((half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_391.x, _248)), max(1, min(_391.y, _252))))), 0u)) * _573) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_403.x, _248)), max(1, min(_403.y, _252))))), 0u)) * _579)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_415.x, _248)), max(1, min(_415.y, _252))))), 0u)) * _585)) + (half4(sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_427.x, _248)), max(1, min(_427.y, _252))))), 0u)) * _591)) / half4(((_573 + _579) + _585) + _591)) * _648)) / half4(((_615 + _626) + _637) + _648);
        float4 _668 = float4(clamp(_660, min(min(min(_318, _330), _366), _378), max(max(max(_318, _330), _366), _378)));
        float4 _674 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _675 = _674.x;
        float3 _678 = (_668.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_675 == 0.0) ? 1.0 : _675);
        float _679 = _678.x;
        float _682 = 0.5 * _678.y;
        float _684 = _678.z;
        float _685 = 0.25 * _684;
        _694 = float3(((0.25 * _679) + _682) + _685, 0.5 * (_679 - _684), (((-0.25) * _679) + _682) - _685);
        _695 = _668.w;
    }
    else
    {
        _694 = float3(0.0);
        _695 = 0.0;
    }
    float _701 = precise::max(fast::clamp(_214, 0.0, 1.0), precise::max(_210, _212));
    float _704 = precise::max(0.0, (_695 * float(!_204)) - (_701 * 2.0));
    uint2 _708 = uint2(int3(gl_GlobalInvocationID).xy);
    spvImageFence(rw_new_locks);
    float2 _725 = _130 - _152;
    float _726 = _725.x;
    bool _731;
    if (_726 >= 0.0)
    {
        _731 = _726 <= 1.0;
    }
    else
    {
        _731 = false;
    }
    bool _740;
    if (_731)
    {
        float _734 = _725.y;
        bool _739;
        if (_734 >= 0.0)
        {
            _739 = _734 <= 1.0;
        }
        else
        {
            _739 = false;
        }
        _740 = _739;
    }
    else
    {
        _740 = false;
    }
    float _750 = precise::min(_221, mix(_221, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_154 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _753 = _126 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _755 = int2(floor(_753));
    float2 _758 = (float2(_755) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _759 = _758 - _753;
    bool _762 = _758.x > _753.x;
    bool _766 = _758.y > _753.y;
    int2 _768 = int2(_762 ? (-2) : (-1), _766 ? (-2) : (-1));
    float2 _769 = float2(_768);
    bool _770 = _221 == 0.0;
    int _771 = _762 ? 3 : 0;
    int _772 = _766 ? 3 : 0;
    int2 _773 = int2(_771, _772);
    int2 _774 = _755 + _768;
    int2 _775 = _774 + _773;
    int _778 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _783 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _793 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _794 = _793.x;
    float3 _797 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_775.x, _778)), max(0, min(_775.y, _783))))), 0u).xyz) * ((_794 == 0.0) ? 1.0 : _794);
    float _798 = _797.x;
    float _801 = 0.5 * _797.y;
    float _803 = _797.z;
    float _804 = 0.25 * _803;
    float3 _811 = float3(((0.25 * _798) + _801) + _804, 0.5 * (_798 - _803), (((-0.25) * _798) + _801) - _804);
    int _812 = _762 ? 2 : 1;
    int2 _813 = int2(_812, _772);
    int2 _814 = _774 + _813;
    float4 _828 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _829 = _828.x;
    float3 _832 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_814.x, _778)), max(0, min(_814.y, _783))))), 0u).xyz) * ((_829 == 0.0) ? 1.0 : _829);
    float _833 = _832.x;
    float _836 = 0.5 * _832.y;
    float _838 = _832.z;
    float _839 = 0.25 * _838;
    float3 _846 = float3(((0.25 * _833) + _836) + _839, 0.5 * (_833 - _838), (((-0.25) * _833) + _836) - _839);
    int _847 = _762 ? 1 : 2;
    int2 _848 = int2(_847, _772);
    int2 _849 = _774 + _848;
    float4 _863 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _864 = _863.x;
    float3 _867 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_849.x, _778)), max(0, min(_849.y, _783))))), 0u).xyz) * ((_864 == 0.0) ? 1.0 : _864);
    float _868 = _867.x;
    float _871 = 0.5 * _867.y;
    float _873 = _867.z;
    float _874 = 0.25 * _873;
    float3 _881 = float3(((0.25 * _868) + _871) + _874, 0.5 * (_868 - _873), (((-0.25) * _868) + _871) - _874);
    int _882 = _766 ? 2 : 1;
    int2 _883 = int2(_771, _882);
    int2 _884 = _774 + _883;
    float4 _898 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _899 = _898.x;
    float3 _902 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_884.x, _778)), max(0, min(_884.y, _783))))), 0u).xyz) * ((_899 == 0.0) ? 1.0 : _899);
    float _903 = _902.x;
    float _906 = 0.5 * _902.y;
    float _908 = _902.z;
    float _909 = 0.25 * _908;
    float3 _916 = float3(((0.25 * _903) + _906) + _909, 0.5 * (_903 - _908), (((-0.25) * _903) + _906) - _909);
    int2 _917 = int2(_812, _882);
    int2 _918 = _774 + _917;
    float4 _932 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _933 = _932.x;
    float3 _936 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_918.x, _778)), max(0, min(_918.y, _783))))), 0u).xyz) * ((_933 == 0.0) ? 1.0 : _933);
    float _937 = _936.x;
    float _940 = 0.5 * _936.y;
    float _942 = _936.z;
    float _943 = 0.25 * _942;
    float3 _950 = float3(((0.25 * _937) + _940) + _943, 0.5 * (_937 - _942), (((-0.25) * _937) + _940) - _943);
    int2 _951 = int2(_847, _882);
    int2 _952 = _774 + _951;
    float4 _966 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _967 = _966.x;
    float3 _970 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_952.x, _778)), max(0, min(_952.y, _783))))), 0u).xyz) * ((_967 == 0.0) ? 1.0 : _967);
    float _971 = _970.x;
    float _974 = 0.5 * _970.y;
    float _976 = _970.z;
    float _977 = 0.25 * _976;
    float3 _984 = float3(((0.25 * _971) + _974) + _977, 0.5 * (_971 - _976), (((-0.25) * _971) + _974) - _977);
    int _985 = _766 ? 1 : 2;
    int2 _986 = int2(_771, _985);
    int2 _987 = _774 + _986;
    float4 _1001 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1002 = _1001.x;
    float3 _1005 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_987.x, _778)), max(0, min(_987.y, _783))))), 0u).xyz) * ((_1002 == 0.0) ? 1.0 : _1002);
    float _1006 = _1005.x;
    float _1009 = 0.5 * _1005.y;
    float _1011 = _1005.z;
    float _1012 = 0.25 * _1011;
    float3 _1019 = float3(((0.25 * _1006) + _1009) + _1012, 0.5 * (_1006 - _1011), (((-0.25) * _1006) + _1009) - _1012);
    int2 _1020 = int2(_812, _985);
    int2 _1021 = _774 + _1020;
    float4 _1035 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1036 = _1035.x;
    float3 _1039 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1021.x, _778)), max(0, min(_1021.y, _783))))), 0u).xyz) * ((_1036 == 0.0) ? 1.0 : _1036);
    float _1040 = _1039.x;
    float _1043 = 0.5 * _1039.y;
    float _1045 = _1039.z;
    float _1046 = 0.25 * _1045;
    float3 _1053 = float3(((0.25 * _1040) + _1043) + _1046, 0.5 * (_1040 - _1045), (((-0.25) * _1040) + _1043) - _1046);
    int2 _1054 = int2(_847, _985);
    int2 _1055 = _774 + _1054;
    float4 _1069 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1070 = _1069.x;
    float3 _1073 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1055.x, _778)), max(0, min(_1055.y, _783))))), 0u).xyz) * ((_1070 == 0.0) ? 1.0 : _1070);
    float _1074 = _1073.x;
    float _1077 = 0.5 * _1073.y;
    float _1079 = _1073.z;
    float _1080 = 0.25 * _1079;
    float3 _1087 = float3(((0.25 * _1074) + _1077) + _1080, 0.5 * (_1074 - _1079), (((-0.25) * _1074) + _1077) - _1080);
    float _1092 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1103 = mix(precise::max(1.0, (1.0 + _1092) * 0.300000011920928955078125), _1092, precise::min(1.0 - (_212 * 0.5), precise::min(1.0 - _214, fast::clamp(_750 * 5.0, 0.0, 1.0))));
    float2 _1106 = _759 + (_769 + float2(_773));
    uint2 _1108 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1111 = float(all(uint2(_775) < _1108));
    bool _1112 = !_770;
    float _1130;
    float3 _1131;
    if (_1112)
    {
        float2 _1116 = _1106 * float2(_1103);
        float _1118 = precise::min(dot(_1116, _1116), 4.0);
        float _1120 = (0.4000000059604644775390625 * _1118) - 1.0;
        float _1122 = (0.25 * _1118) - 1.0;
        float _1128 = _1111 * ((((1.5625 * _1120) * _1120) - 0.5625) * (_1122 * _1122));
        _1130 = _1128;
        _1131 = _811 * _1128;
    }
    else
    {
        _1130 = 0.0;
        _1131 = float3(0.0);
    }
    float _1135 = exp((-2.2999999523162841796875) * dot(_1106, _1106)) * _1111;
    float3 _1136 = _811 * _1135;
    float2 _1140 = _759 + (_769 + float2(_813));
    float _1144 = float(all(uint2(_814) < _1108));
    float _1164;
    float3 _1165;
    if (_1112)
    {
        float2 _1148 = _1140 * float2(_1103);
        float _1150 = precise::min(dot(_1148, _1148), 4.0);
        float _1152 = (0.4000000059604644775390625 * _1150) - 1.0;
        float _1154 = (0.25 * _1150) - 1.0;
        float _1160 = _1144 * ((((1.5625 * _1152) * _1152) - 0.5625) * (_1154 * _1154));
        _1164 = _1130 + _1160;
        _1165 = _1131 + (_846 * _1160);
    }
    else
    {
        _1164 = _1130;
        _1165 = _1131;
    }
    float _1169 = exp((-2.2999999523162841796875) * dot(_1140, _1140)) * _1144;
    float3 _1172 = _846 * _1169;
    float2 _1179 = _759 + (_769 + float2(_848));
    float _1183 = float(all(uint2(_849) < _1108));
    float _1203;
    float3 _1204;
    if (_1112)
    {
        float2 _1187 = _1179 * float2(_1103);
        float _1189 = precise::min(dot(_1187, _1187), 4.0);
        float _1191 = (0.4000000059604644775390625 * _1189) - 1.0;
        float _1193 = (0.25 * _1189) - 1.0;
        float _1199 = _1183 * ((((1.5625 * _1191) * _1191) - 0.5625) * (_1193 * _1193));
        _1203 = _1164 + _1199;
        _1204 = _1165 + (_881 * _1199);
    }
    else
    {
        _1203 = _1164;
        _1204 = _1165;
    }
    float _1208 = exp((-2.2999999523162841796875) * dot(_1179, _1179)) * _1183;
    float3 _1211 = _881 * _1208;
    float2 _1218 = _759 + (_769 + float2(_883));
    float _1222 = float(all(uint2(_884) < _1108));
    float _1242;
    float3 _1243;
    if (_1112)
    {
        float2 _1226 = _1218 * float2(_1103);
        float _1228 = precise::min(dot(_1226, _1226), 4.0);
        float _1230 = (0.4000000059604644775390625 * _1228) - 1.0;
        float _1232 = (0.25 * _1228) - 1.0;
        float _1238 = _1222 * ((((1.5625 * _1230) * _1230) - 0.5625) * (_1232 * _1232));
        _1242 = _1203 + _1238;
        _1243 = _1204 + (_916 * _1238);
    }
    else
    {
        _1242 = _1203;
        _1243 = _1204;
    }
    float _1247 = exp((-2.2999999523162841796875) * dot(_1218, _1218)) * _1222;
    float3 _1250 = _916 * _1247;
    float2 _1257 = _759 + (_769 + float2(_917));
    float _1261 = float(all(uint2(_918) < _1108));
    float _1281;
    float3 _1282;
    if (_1112)
    {
        float2 _1265 = _1257 * float2(_1103);
        float _1267 = precise::min(dot(_1265, _1265), 4.0);
        float _1269 = (0.4000000059604644775390625 * _1267) - 1.0;
        float _1271 = (0.25 * _1267) - 1.0;
        float _1277 = _1261 * ((((1.5625 * _1269) * _1269) - 0.5625) * (_1271 * _1271));
        _1281 = _1242 + _1277;
        _1282 = _1243 + (_950 * _1277);
    }
    else
    {
        _1281 = _1242;
        _1282 = _1243;
    }
    float _1286 = exp((-2.2999999523162841796875) * dot(_1257, _1257)) * _1261;
    float3 _1289 = _950 * _1286;
    float2 _1296 = _759 + (_769 + float2(_951));
    float _1300 = float(all(uint2(_952) < _1108));
    float _1320;
    float3 _1321;
    if (_1112)
    {
        float2 _1304 = _1296 * float2(_1103);
        float _1306 = precise::min(dot(_1304, _1304), 4.0);
        float _1308 = (0.4000000059604644775390625 * _1306) - 1.0;
        float _1310 = (0.25 * _1306) - 1.0;
        float _1316 = _1300 * ((((1.5625 * _1308) * _1308) - 0.5625) * (_1310 * _1310));
        _1320 = _1281 + _1316;
        _1321 = _1282 + (_984 * _1316);
    }
    else
    {
        _1320 = _1281;
        _1321 = _1282;
    }
    float _1325 = exp((-2.2999999523162841796875) * dot(_1296, _1296)) * _1300;
    float3 _1328 = _984 * _1325;
    float2 _1335 = _759 + (_769 + float2(_986));
    float _1339 = float(all(uint2(_987) < _1108));
    float _1359;
    float3 _1360;
    if (_1112)
    {
        float2 _1343 = _1335 * float2(_1103);
        float _1345 = precise::min(dot(_1343, _1343), 4.0);
        float _1347 = (0.4000000059604644775390625 * _1345) - 1.0;
        float _1349 = (0.25 * _1345) - 1.0;
        float _1355 = _1339 * ((((1.5625 * _1347) * _1347) - 0.5625) * (_1349 * _1349));
        _1359 = _1320 + _1355;
        _1360 = _1321 + (_1019 * _1355);
    }
    else
    {
        _1359 = _1320;
        _1360 = _1321;
    }
    float _1364 = exp((-2.2999999523162841796875) * dot(_1335, _1335)) * _1339;
    float3 _1367 = _1019 * _1364;
    float2 _1374 = _759 + (_769 + float2(_1020));
    float _1378 = float(all(uint2(_1021) < _1108));
    float _1398;
    float3 _1399;
    if (_1112)
    {
        float2 _1382 = _1374 * float2(_1103);
        float _1384 = precise::min(dot(_1382, _1382), 4.0);
        float _1386 = (0.4000000059604644775390625 * _1384) - 1.0;
        float _1388 = (0.25 * _1384) - 1.0;
        float _1394 = _1378 * ((((1.5625 * _1386) * _1386) - 0.5625) * (_1388 * _1388));
        _1398 = _1359 + _1394;
        _1399 = _1360 + (_1053 * _1394);
    }
    else
    {
        _1398 = _1359;
        _1399 = _1360;
    }
    float _1403 = exp((-2.2999999523162841796875) * dot(_1374, _1374)) * _1378;
    float3 _1406 = _1053 * _1403;
    float2 _1413 = _759 + (_769 + float2(_1054));
    float _1417 = float(all(uint2(_1055) < _1108));
    float _1437;
    float3 _1438;
    if (_1112)
    {
        float2 _1421 = _1413 * float2(_1103);
        float _1423 = precise::min(dot(_1421, _1421), 4.0);
        float _1425 = (0.4000000059604644775390625 * _1423) - 1.0;
        float _1427 = (0.25 * _1423) - 1.0;
        float _1433 = _1417 * ((((1.5625 * _1425) * _1425) - 0.5625) * (_1427 * _1427));
        _1437 = _1398 + _1433;
        _1438 = _1399 + (_1087 * _1433);
    }
    else
    {
        _1437 = _1398;
        _1438 = _1399;
    }
    float _1442 = exp((-2.2999999523162841796875) * dot(_1413, _1413)) * _1417;
    float3 _1445 = _1087 * _1442;
    float _1449 = (((((((_1135 + _1169) + _1208) + _1247) + _1286) + _1325) + _1364) + _1403) + _1442;
    float3 _1453 = float3((abs(_1449) > 1.1754943508222875079687365372222e-38) ? _1449 : 1.0);
    float3 _1454 = ((((((((_1136 + _1172) + _1211) + _1250) + _1289) + _1328) + _1367) + _1406) + _1445) / _1453;
    float _1462 = _1437 * float(_1437 > 6.099999882280826568603515625e-05);
    float3 _1470;
    float _1471;
    if (_1462 > 6.099999882280826568603515625e-05)
    {
        _1470 = fast::clamp(_1438 / float3(_1462), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_811, _846), _881), _916), _950), _984), _1019), _1053), _1087), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_811, _846), _881), _916), _950), _984), _1019), _1053), _1087));
        _1471 = _1462 * 0.04625000059604644775390625;
    }
    else
    {
        _1470 = _1438;
        _1471 = _1462;
    }
    float _1474 = _770 ? 1.0 : _1471;
    float _1475 = _770 ? 0.0 : _750;
    float3 _1489 = (sqrt(abs(((((((((((_811 * _1136) + (_846 * _1172)) + (_881 * _1211)) + (_916 * _1250)) + (_950 * _1289)) + (_984 * _1328)) + (_1019 * _1367)) + (_1053 * _1406)) + (_1087 * _1445)) / _1453) - (_1454 * _1454))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_154 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_137 * _187, _187 - float2(0.5))) / float2(int2(int(_181.x), int(_181.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _221, precise::max(powr(_210, 0.5), _214)))));
    float3 _1492 = (_694 - _1454) / precise::max(_1489, float3(1.19299997436428384389728307724e-07));
    float3 _1507;
    if (length(_1492) > 1.0)
    {
        _1507 = mix((fast::normalize(_1492) * _1489) + _1454, _694, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_146, _141)) / _144), level(0.0)).x, fast::clamp(fast::clamp(_704 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _221) * (1.0 - _212), 0.0, 1.0)));
    }
    else
    {
        _1507 = _694;
    }
    float3 _1516 = mix(_1507, select(_1470, _1454, bool3(_770)), float3(fast::clamp(_1474 / precise::max(6.099999882280826568603515625e-05, (_1475 * float(_1475 > 6.099999882280826568603515625e-05)) + _1474), 0.0, 1.0)));
    float _1517 = _1516.x;
    float _1518 = _1516.y;
    float _1520 = _1516.z;
    float4 _1527 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1528 = _1527.x;
    float3 _1533 = precise::max(float3((_1517 + _1518) - _1520, _1517 + _1520, (_1517 - _1518) - _1520) / float3((_1528 == 0.0) ? 1.0 : _1528), float3(0.0));
    float _1534 = _1533.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1534, _1533.yz, precise::max(0.0, precise::max(0.0, precise::min(_704 + (sdk_hlsl_load(rw_new_locks, uint2(_708)).x * (1.0 - precise::max(0.0, _210))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _701))) * float(_740)), uint2(_708));
    sdk_hlsl_store(rw_upscaled_output, float4(_1534, _1533.yz, 1.0), uint2(_708));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_708));
}

