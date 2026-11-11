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

kernel void main0(constant type_cbFSR3Upscaler& cbFSR3Upscaler [[buffer(0)]], texture2d<float> r_input_color_jittered [[texture(0)]], texture2d<float> r_input_motion_vectors [[texture(1)]], texture2d<float> r_internal_upscaled_color [[texture(2)]], texture2d<float, access::write> rw_internal_upscaled_color [[texture(3)]], texture2d<float, access::write> rw_upscaled_output [[texture(4)]], texture2d<float> r_farthest_depth_mip1 [[texture(5)]], texture2d<float> r_luma_instability [[texture(6)]], texture2d<float, access::read_write> rw_new_locks [[texture(7)]], texture2d<float> r_input_exposure [[texture(8)]], texture2d<float> r_lanczos_lut [[texture(9)]], texture2d<float> r_dilated_reactive_masks [[texture(10)]], sampler s_LinearClamp [[sampler(0)]], uint3 gl_GlobalInvocationID [[thread_position_in_grid]])
{
    float2 _127 = float2(int3(gl_GlobalInvocationID).xy) + float2(0.5);
    float2 _131 = _127 / float2(cbFSR3Upscaler.iUpscaleSize);
    float2 _136 = float2(cbFSR3Upscaler.iRenderSize);
    float2 _138 = _131 + (cbFSR3Upscaler.fJitter / _136);
    float2 _142 = _136 - float2(0.5);
    float2 _145 = float2(cbFSR3Upscaler.iMaxRenderSize);
    uint2 _147 = uint2(int3(gl_GlobalInvocationID).xy);
    float2 _156 = (sdk_hlsl_load(r_input_motion_vectors, uint2(_147), 0u).xy * cbFSR3Upscaler.fMotionVectorScale) - cbFSR3Upscaler.fMotionVectorJitterCancellation;
    float _158 = length(_156 * float2(3840.0, 2160.0));
    float2 _159 = _131 + _156;
    float _160 = _159.x;
    bool _165;
    if (_160 >= 0.0)
    {
        _165 = _160 <= 1.0;
    }
    else
    {
        _165 = false;
    }
    bool _174;
    if (_165)
    {
        float _168 = _159.y;
        bool _173;
        if (_168 >= 0.0)
        {
            _173 = _168 <= 1.0;
        }
        else
        {
            _173 = false;
        }
        _174 = _173;
    }
    else
    {
        _174 = false;
    }
    uint2 _186 = uint2(r_farthest_depth_mip1.get_width(), r_farthest_depth_mip1.get_height());
    float2 _192 = float2(cbFSR3Upscaler.iRenderSize / int2(2));
    bool _209;
    if (_174)
    {
        _209 = 0.0 == cbFSR3Upscaler.fFrameIndex;
    }
    else
    {
        _209 = true;
    }
    float4 _213 = r_dilated_reactive_masks.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _136, _142)) / _145), level(0.0));
    float _215 = fast::clamp(_213.x, 0.0, 1.0);
    float _217 = fast::clamp(_213.y, 0.0, 1.0);
    float _219 = fast::clamp(_213.z, 0.0, 1.0);
    float _221 = fast::clamp(_213.w, 0.0, 1.0);
    float _226 = _221 * float(rint(_221 * 100.0) > 1.0);
    bool _230;
    if (_174)
    {
        _230 = !_209;
    }
    else
    {
        _230 = false;
    }
    float3 _658;
    float _659;
    if (_230)
    {
        float2 _237 = (_159 * float2(cbFSR3Upscaler.iPreviousFrameUpscaleSize)) - float2(0.5);
        float2 _239 = _237 - floor(_237);
        int2 _254 = int2(floor(float2(precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 1), _237.x)), precise::max(0.0, precise::min(float(cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 1), _237.y)))));
        int2 _255 = _254 + int2(-1);
        int _257 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.x - 2;
        int _261 = cbFSR3Upscaler.iPreviousFrameUpscaleSize.y - 2;
        int2 _268 = _254 + int2(0, -1);
        int2 _279 = _254 + int2(1, -1);
        int2 _290 = _254 + int2(2, -1);
        int2 _301 = _254 + int2(-1, 0);
        float4 _321 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_254.x, _257)), max(1, min(_254.y, _261))))), 0u);
        int2 _322 = _254 + int2(1, 0);
        float4 _332 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_322.x, _257)), max(1, min(_322.y, _261))))), 0u);
        int2 _333 = _254 + int2(2, 0);
        int2 _344 = _254 + int2(-1, 1);
        int2 _355 = _254 + int2(0, 1);
        float4 _365 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_355.x, _257)), max(1, min(_355.y, _261))))), 0u);
        int2 _366 = _254 + int2(1);
        float4 _376 = sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_366.x, _257)), max(1, min(_366.y, _261))))), 0u);
        int2 _377 = _254 + int2(2, 1);
        int2 _388 = _254 + int2(-1, 2);
        int2 _399 = _254 + int2(0, 2);
        int2 _410 = _254 + int2(1, 2);
        int2 _421 = _254 + int2(2);
        float _432 = _239.x;
        float2 _438 = float2(abs((-1.0) - _432) * 0.5, 0.5);
        float4 _440 = r_lanczos_lut.sample(s_LinearClamp, _438, level(0.0));
        float _441 = _440.x;
        float2 _447 = float2(abs(-_432) * 0.5, 0.5);
        float4 _449 = r_lanczos_lut.sample(s_LinearClamp, _447, level(0.0));
        float _450 = _449.x;
        float2 _456 = float2(abs(1.0 - _432) * 0.5, 0.5);
        float4 _458 = r_lanczos_lut.sample(s_LinearClamp, _456, level(0.0));
        float _459 = _458.x;
        float2 _465 = float2(abs(2.0 - _432) * 0.5, 0.5);
        float4 _467 = r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0));
        float _468 = _467.x;
        float4 _484 = r_lanczos_lut.sample(s_LinearClamp, _438, level(0.0));
        float _485 = _484.x;
        float4 _489 = r_lanczos_lut.sample(s_LinearClamp, _447, level(0.0));
        float _490 = _489.x;
        float4 _494 = r_lanczos_lut.sample(s_LinearClamp, _456, level(0.0));
        float _495 = _494.x;
        float4 _499 = r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0));
        float _500 = _499.x;
        float4 _516 = r_lanczos_lut.sample(s_LinearClamp, _438, level(0.0));
        float _517 = _516.x;
        float4 _521 = r_lanczos_lut.sample(s_LinearClamp, _447, level(0.0));
        float _522 = _521.x;
        float4 _526 = r_lanczos_lut.sample(s_LinearClamp, _456, level(0.0));
        float _527 = _526.x;
        float4 _531 = r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0));
        float _532 = _531.x;
        float4 _548 = r_lanczos_lut.sample(s_LinearClamp, _438, level(0.0));
        float _549 = _548.x;
        float4 _553 = r_lanczos_lut.sample(s_LinearClamp, _447, level(0.0));
        float _554 = _553.x;
        float4 _558 = r_lanczos_lut.sample(s_LinearClamp, _456, level(0.0));
        float _559 = _558.x;
        float4 _563 = r_lanczos_lut.sample(s_LinearClamp, _465, level(0.0));
        float _564 = _563.x;
        float _577 = _239.y;
        float4 _585 = r_lanczos_lut.sample(s_LinearClamp, float2(abs((-1.0) - _577) * 0.5, 0.5), level(0.0));
        float _586 = _585.x;
        float4 _594 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(-_577) * 0.5, 0.5), level(0.0));
        float _595 = _594.x;
        float4 _603 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(1.0 - _577) * 0.5, 0.5), level(0.0));
        float _604 = _603.x;
        float4 _612 = r_lanczos_lut.sample(s_LinearClamp, float2(abs(2.0 - _577) * 0.5, 0.5), level(0.0));
        float _613 = _612.x;
        float4 _618 = (((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_255.x, _257)), max(1, min(_255.y, _261))))), 0u) * _441) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_268.x, _257)), max(1, min(_268.y, _261))))), 0u) * _450)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_279.x, _257)), max(1, min(_279.y, _261))))), 0u) * _459)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_290.x, _257)), max(1, min(_290.y, _261))))), 0u) * _468)) / float4(((_441 + _450) + _459) + _468)) * _586) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_301.x, _257)), max(1, min(_301.y, _261))))), 0u) * _485) + (_321 * _490)) + (_332 * _495)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_333.x, _257)), max(1, min(_333.y, _261))))), 0u) * _500)) / float4(((_485 + _490) + _495) + _500)) * _595)) + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_344.x, _257)), max(1, min(_344.y, _261))))), 0u) * _517) + (_365 * _522)) + (_376 * _527)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_377.x, _257)), max(1, min(_377.y, _261))))), 0u) * _532)) / float4(((_517 + _522) + _527) + _532)) * _604);
        float4 _632 = fast::clamp((_618 + ((((((sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_388.x, _257)), max(1, min(_388.y, _261))))), 0u) * _549) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_399.x, _257)), max(1, min(_399.y, _261))))), 0u) * _554)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_410.x, _257)), max(1, min(_410.y, _261))))), 0u) * _559)) + (sdk_hlsl_load(r_internal_upscaled_color, uint2(uint2(int2(max(1, min(_421.x, _257)), max(1, min(_421.y, _261))))), 0u) * _564)) / float4(((_549 + _554) + _559) + _564)) * _613)) / float4(((_586 + _595) + _604) + _613), precise::min(precise::min(precise::min(_321, _332), _365), _376), precise::max(precise::max(precise::max(_321, _332), _365), _376));
        float4 _638 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
        float _639 = _638.x;
        float3 _642 = (_632.xyz * cbFSR3Upscaler.fDeltaPreExposure) * ((_639 == 0.0) ? 1.0 : _639);
        float _643 = _642.x;
        float _646 = 0.5 * _642.y;
        float _648 = _642.z;
        float _649 = 0.25 * _648;
        _658 = float3(((0.25 * _643) + _646) + _649, 0.5 * (_643 - _648), (((-0.25) * _643) + _646) - _649);
        _659 = _632.w;
    }
    else
    {
        _658 = float3(0.0);
        _659 = 0.0;
    }
    float _665 = precise::max(fast::clamp(_219, 0.0, 1.0), precise::max(_215, _217));
    float _668 = precise::max(0.0, (_659 * float(!_209)) - (_665 * 2.0));
    spvImageFence(rw_new_locks);
    float2 _688 = _131 - _156;
    float _689 = _688.x;
    bool _694;
    if (_689 >= 0.0)
    {
        _694 = _689 <= 1.0;
    }
    else
    {
        _694 = false;
    }
    bool _703;
    if (_694)
    {
        float _697 = _688.y;
        bool _702;
        if (_697 >= 0.0)
        {
            _702 = _697 <= 1.0;
        }
        else
        {
            _702 = false;
        }
        _703 = _702;
    }
    else
    {
        _703 = false;
    }
    float _713 = precise::min(_226, mix(_226, 0.1500000059604644775390625, fast::clamp(precise::max(0.0, (_158 * cbFSR3Upscaler.fVelocityFactor) * 2.0), 0.0, 1.0)));
    float2 _716 = _127 * cbFSR3Upscaler.fDownscaleFactor;
    int2 _718 = int2(floor(_716));
    float2 _721 = (float2(_718) + float2(0.5)) - cbFSR3Upscaler.fJitter;
    float2 _722 = _721 - _716;
    bool _725 = _721.x > _716.x;
    bool _729 = _721.y > _716.y;
    int2 _731 = int2(_725 ? (-2) : (-1), _729 ? (-2) : (-1));
    float2 _732 = float2(_731);
    bool _733 = _226 == 0.0;
    int _734 = _725 ? 3 : 0;
    int _735 = _729 ? 3 : 0;
    int2 _736 = int2(_734, _735);
    int2 _737 = _718 + _731;
    int2 _738 = _737 + _736;
    int _741 = cbFSR3Upscaler.iRenderSize.x - 1;
    int _746 = cbFSR3Upscaler.iRenderSize.y - 1;
    float4 _756 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _757 = _756.x;
    float3 _760 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_738.x, _741)), max(0, min(_738.y, _746))))), 0u).xyz) * ((_757 == 0.0) ? 1.0 : _757);
    float _761 = _760.x;
    float _764 = 0.5 * _760.y;
    float _766 = _760.z;
    float _767 = 0.25 * _766;
    spvUnsafeArray<float3, 9> _123;
    _123[0] = float3(((0.25 * _761) + _764) + _767, 0.5 * (_761 - _766), (((-0.25) * _761) + _764) - _767);
    int _776 = _725 ? 2 : 1;
    int2 _777 = int2(_776, _735);
    int2 _778 = _737 + _777;
    float4 _792 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _793 = _792.x;
    float3 _796 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_778.x, _741)), max(0, min(_778.y, _746))))), 0u).xyz) * ((_793 == 0.0) ? 1.0 : _793);
    float _797 = _796.x;
    float _800 = 0.5 * _796.y;
    float _802 = _796.z;
    float _803 = 0.25 * _802;
    _123[1] = float3(((0.25 * _797) + _800) + _803, 0.5 * (_797 - _802), (((-0.25) * _797) + _800) - _803);
    int _812 = _725 ? 1 : 2;
    int2 _813 = int2(_812, _735);
    int2 _814 = _737 + _813;
    float4 _828 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _829 = _828.x;
    float3 _832 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_814.x, _741)), max(0, min(_814.y, _746))))), 0u).xyz) * ((_829 == 0.0) ? 1.0 : _829);
    float _833 = _832.x;
    float _836 = 0.5 * _832.y;
    float _838 = _832.z;
    float _839 = 0.25 * _838;
    _123[2] = float3(((0.25 * _833) + _836) + _839, 0.5 * (_833 - _838), (((-0.25) * _833) + _836) - _839);
    int _848 = _729 ? 2 : 1;
    int2 _849 = int2(_734, _848);
    int2 _850 = _737 + _849;
    float4 _864 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _865 = _864.x;
    float3 _868 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_850.x, _741)), max(0, min(_850.y, _746))))), 0u).xyz) * ((_865 == 0.0) ? 1.0 : _865);
    float _869 = _868.x;
    float _872 = 0.5 * _868.y;
    float _874 = _868.z;
    float _875 = 0.25 * _874;
    _123[3] = float3(((0.25 * _869) + _872) + _875, 0.5 * (_869 - _874), (((-0.25) * _869) + _872) - _875);
    int2 _884 = int2(_776, _848);
    int2 _885 = _737 + _884;
    float4 _899 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _900 = _899.x;
    float3 _903 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_885.x, _741)), max(0, min(_885.y, _746))))), 0u).xyz) * ((_900 == 0.0) ? 1.0 : _900);
    float _904 = _903.x;
    float _907 = 0.5 * _903.y;
    float _909 = _903.z;
    float _910 = 0.25 * _909;
    _123[4] = float3(((0.25 * _904) + _907) + _910, 0.5 * (_904 - _909), (((-0.25) * _904) + _907) - _910);
    int2 _919 = int2(_812, _848);
    int2 _920 = _737 + _919;
    float4 _934 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _935 = _934.x;
    float3 _938 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_920.x, _741)), max(0, min(_920.y, _746))))), 0u).xyz) * ((_935 == 0.0) ? 1.0 : _935);
    float _939 = _938.x;
    float _942 = 0.5 * _938.y;
    float _944 = _938.z;
    float _945 = 0.25 * _944;
    _123[5] = float3(((0.25 * _939) + _942) + _945, 0.5 * (_939 - _944), (((-0.25) * _939) + _942) - _945);
    int _954 = _729 ? 1 : 2;
    int2 _955 = int2(_734, _954);
    int2 _956 = _737 + _955;
    float4 _970 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _971 = _970.x;
    float3 _974 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_956.x, _741)), max(0, min(_956.y, _746))))), 0u).xyz) * ((_971 == 0.0) ? 1.0 : _971);
    float _975 = _974.x;
    float _978 = 0.5 * _974.y;
    float _980 = _974.z;
    float _981 = 0.25 * _980;
    _123[6] = float3(((0.25 * _975) + _978) + _981, 0.5 * (_975 - _980), (((-0.25) * _975) + _978) - _981);
    int2 _990 = int2(_776, _954);
    int2 _991 = _737 + _990;
    float4 _1005 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1006 = _1005.x;
    float3 _1009 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_991.x, _741)), max(0, min(_991.y, _746))))), 0u).xyz) * ((_1006 == 0.0) ? 1.0 : _1006);
    float _1010 = _1009.x;
    float _1013 = 0.5 * _1009.y;
    float _1015 = _1009.z;
    float _1016 = 0.25 * _1015;
    _123[7] = float3(((0.25 * _1010) + _1013) + _1016, 0.5 * (_1010 - _1015), (((-0.25) * _1010) + _1013) - _1016);
    int2 _1025 = int2(_812, _954);
    int2 _1026 = _737 + _1025;
    float4 _1040 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1041 = _1040.x;
    float3 _1044 = precise::max(float3(0.0), sdk_hlsl_load(r_input_color_jittered, uint2(uint2(int2(max(0, min(_1026.x, _741)), max(0, min(_1026.y, _746))))), 0u).xyz) * ((_1041 == 0.0) ? 1.0 : _1041);
    float _1045 = _1044.x;
    float _1048 = 0.5 * _1044.y;
    float _1050 = _1044.z;
    float _1051 = 0.25 * _1050;
    _123[8] = float3(((0.25 * _1045) + _1048) + _1051, 0.5 * (_1045 - _1050), (((-0.25) * _1045) + _1048) - _1051);
    if (_733)
    {
        for (int _1063 = 0; _1063 < 9; )
        {
            float _1074 = (_123[_1063].x + _123[_1063].y) - _123[_1063].z;
            float _1075 = _123[_1063].x + _123[_1063].z;
            float _1077 = (_123[_1063].x - _123[_1063].y) - _123[_1063].z;
            float3 _1084 = float3(_1074, _1075, _1077) / float3(precise::max(precise::max(0.0, _1074), precise::max(_1075, _1077)) + 1.0);
            float _1085 = _1084.x;
            float _1088 = 0.5 * _1084.y;
            float _1090 = _1084.z;
            float _1091 = 0.25 * _1090;
            _123[_1063] = float3(((0.25 * _1085) + _1088) + _1091, 0.5 * (_1085 - _1090), (((-0.25) * _1085) + _1088) - _1091);
            _1063++;
            continue;
        }
    }
    float _1103 = precise::min(1.9900000095367431640625, 1.0 + ((float2(1.0) / cbFSR3Upscaler.fDownscaleFactor) - float2(1.0)).x);
    float _1114 = mix(precise::max(1.0, (1.0 + _1103) * 0.300000011920928955078125), _1103, precise::min(1.0 - (_217 * 0.5), precise::min(1.0 - _219, fast::clamp(_713 * 5.0, 0.0, 1.0))));
    float2 _1117 = _722 + (_732 + float2(_736));
    uint2 _1119 = uint2(cbFSR3Upscaler.iRenderSize);
    float _1122 = float(all(uint2(_738) < _1119));
    bool _1123 = !_733;
    float _1142;
    float3 _1143;
    if (_1123)
    {
        float2 _1127 = _1117 * float2(_1114);
        float _1129 = precise::min(dot(_1127, _1127), 4.0);
        float _1131 = (0.4000000059604644775390625 * _1129) - 1.0;
        float _1133 = (0.25 * _1129) - 1.0;
        float _1139 = _1122 * ((((1.5625 * _1131) * _1131) - 0.5625) * (_1133 * _1133));
        _1142 = _1139;
        _1143 = _123[0] * _1139;
    }
    else
    {
        _1142 = 0.0;
        _1143 = float3(0.0);
    }
    float _1147 = exp((-2.2999999523162841796875) * dot(_1117, _1117)) * _1122;
    float3 _1149 = _123[0] * _1147;
    float2 _1153 = _722 + (_732 + float2(_777));
    float _1157 = float(all(uint2(_778) < _1119));
    float _1178;
    float3 _1179;
    if (_1123)
    {
        float2 _1161 = _1153 * float2(_1114);
        float _1163 = precise::min(dot(_1161, _1161), 4.0);
        float _1165 = (0.4000000059604644775390625 * _1163) - 1.0;
        float _1167 = (0.25 * _1163) - 1.0;
        float _1173 = _1157 * ((((1.5625 * _1165) * _1165) - 0.5625) * (_1167 * _1167));
        _1178 = _1142 + _1173;
        _1179 = _1143 + (_123[1] * _1173);
    }
    else
    {
        _1178 = _1142;
        _1179 = _1143;
    }
    float _1183 = exp((-2.2999999523162841796875) * dot(_1153, _1153)) * _1157;
    float3 _1187 = _123[1] * _1183;
    float2 _1194 = _722 + (_732 + float2(_813));
    float _1198 = float(all(uint2(_814) < _1119));
    float _1219;
    float3 _1220;
    if (_1123)
    {
        float2 _1202 = _1194 * float2(_1114);
        float _1204 = precise::min(dot(_1202, _1202), 4.0);
        float _1206 = (0.4000000059604644775390625 * _1204) - 1.0;
        float _1208 = (0.25 * _1204) - 1.0;
        float _1214 = _1198 * ((((1.5625 * _1206) * _1206) - 0.5625) * (_1208 * _1208));
        _1219 = _1178 + _1214;
        _1220 = _1179 + (_123[2] * _1214);
    }
    else
    {
        _1219 = _1178;
        _1220 = _1179;
    }
    float _1224 = exp((-2.2999999523162841796875) * dot(_1194, _1194)) * _1198;
    float3 _1228 = _123[2] * _1224;
    float2 _1235 = _722 + (_732 + float2(_849));
    float _1239 = float(all(uint2(_850) < _1119));
    float _1260;
    float3 _1261;
    if (_1123)
    {
        float2 _1243 = _1235 * float2(_1114);
        float _1245 = precise::min(dot(_1243, _1243), 4.0);
        float _1247 = (0.4000000059604644775390625 * _1245) - 1.0;
        float _1249 = (0.25 * _1245) - 1.0;
        float _1255 = _1239 * ((((1.5625 * _1247) * _1247) - 0.5625) * (_1249 * _1249));
        _1260 = _1219 + _1255;
        _1261 = _1220 + (_123[3] * _1255);
    }
    else
    {
        _1260 = _1219;
        _1261 = _1220;
    }
    float _1265 = exp((-2.2999999523162841796875) * dot(_1235, _1235)) * _1239;
    float3 _1269 = _123[3] * _1265;
    float2 _1276 = _722 + (_732 + float2(_884));
    float _1280 = float(all(uint2(_885) < _1119));
    float _1301;
    float3 _1302;
    if (_1123)
    {
        float2 _1284 = _1276 * float2(_1114);
        float _1286 = precise::min(dot(_1284, _1284), 4.0);
        float _1288 = (0.4000000059604644775390625 * _1286) - 1.0;
        float _1290 = (0.25 * _1286) - 1.0;
        float _1296 = _1280 * ((((1.5625 * _1288) * _1288) - 0.5625) * (_1290 * _1290));
        _1301 = _1260 + _1296;
        _1302 = _1261 + (_123[4] * _1296);
    }
    else
    {
        _1301 = _1260;
        _1302 = _1261;
    }
    float _1306 = exp((-2.2999999523162841796875) * dot(_1276, _1276)) * _1280;
    float3 _1310 = _123[4] * _1306;
    float2 _1317 = _722 + (_732 + float2(_919));
    float _1321 = float(all(uint2(_920) < _1119));
    float _1342;
    float3 _1343;
    if (_1123)
    {
        float2 _1325 = _1317 * float2(_1114);
        float _1327 = precise::min(dot(_1325, _1325), 4.0);
        float _1329 = (0.4000000059604644775390625 * _1327) - 1.0;
        float _1331 = (0.25 * _1327) - 1.0;
        float _1337 = _1321 * ((((1.5625 * _1329) * _1329) - 0.5625) * (_1331 * _1331));
        _1342 = _1301 + _1337;
        _1343 = _1302 + (_123[5] * _1337);
    }
    else
    {
        _1342 = _1301;
        _1343 = _1302;
    }
    float _1347 = exp((-2.2999999523162841796875) * dot(_1317, _1317)) * _1321;
    float3 _1351 = _123[5] * _1347;
    float2 _1358 = _722 + (_732 + float2(_955));
    float _1362 = float(all(uint2(_956) < _1119));
    float _1383;
    float3 _1384;
    if (_1123)
    {
        float2 _1366 = _1358 * float2(_1114);
        float _1368 = precise::min(dot(_1366, _1366), 4.0);
        float _1370 = (0.4000000059604644775390625 * _1368) - 1.0;
        float _1372 = (0.25 * _1368) - 1.0;
        float _1378 = _1362 * ((((1.5625 * _1370) * _1370) - 0.5625) * (_1372 * _1372));
        _1383 = _1342 + _1378;
        _1384 = _1343 + (_123[6] * _1378);
    }
    else
    {
        _1383 = _1342;
        _1384 = _1343;
    }
    float _1388 = exp((-2.2999999523162841796875) * dot(_1358, _1358)) * _1362;
    float3 _1392 = _123[6] * _1388;
    float2 _1399 = _722 + (_732 + float2(_990));
    float _1403 = float(all(uint2(_991) < _1119));
    float _1424;
    float3 _1425;
    if (_1123)
    {
        float2 _1407 = _1399 * float2(_1114);
        float _1409 = precise::min(dot(_1407, _1407), 4.0);
        float _1411 = (0.4000000059604644775390625 * _1409) - 1.0;
        float _1413 = (0.25 * _1409) - 1.0;
        float _1419 = _1403 * ((((1.5625 * _1411) * _1411) - 0.5625) * (_1413 * _1413));
        _1424 = _1383 + _1419;
        _1425 = _1384 + (_123[7] * _1419);
    }
    else
    {
        _1424 = _1383;
        _1425 = _1384;
    }
    float _1429 = exp((-2.2999999523162841796875) * dot(_1399, _1399)) * _1403;
    float3 _1433 = _123[7] * _1429;
    float2 _1440 = _722 + (_732 + float2(_1025));
    float _1444 = float(all(uint2(_1026) < _1119));
    float _1465;
    float3 _1466;
    if (_1123)
    {
        float2 _1448 = _1440 * float2(_1114);
        float _1450 = precise::min(dot(_1448, _1448), 4.0);
        float _1452 = (0.4000000059604644775390625 * _1450) - 1.0;
        float _1454 = (0.25 * _1450) - 1.0;
        float _1460 = _1444 * ((((1.5625 * _1452) * _1452) - 0.5625) * (_1454 * _1454));
        _1465 = _1424 + _1460;
        _1466 = _1425 + (_123[8] * _1460);
    }
    else
    {
        _1465 = _1424;
        _1466 = _1425;
    }
    float _1470 = exp((-2.2999999523162841796875) * dot(_1440, _1440)) * _1444;
    float3 _1474 = _123[8] * _1470;
    float _1478 = (((((((_1147 + _1183) + _1224) + _1265) + _1306) + _1347) + _1388) + _1429) + _1470;
    float3 _1482 = float3((abs(_1478) > 1.1754943508222875079687365372222e-38) ? _1478 : 1.0);
    float3 _1483 = ((((((((_1149 + _1187) + _1228) + _1269) + _1310) + _1351) + _1392) + _1433) + _1474) / _1482;
    float _1491 = _1465 * float(_1465 > 6.099999882280826568603515625e-05);
    float3 _1499;
    float _1500;
    if (_1491 > 6.099999882280826568603515625e-05)
    {
        _1499 = fast::clamp(_1466 / float3(_1491), precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(precise::min(_123[0], _123[1]), _123[2]), _123[3]), _123[4]), _123[5]), _123[6]), _123[7]), _123[8]), precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(precise::max(_123[0], _123[1]), _123[2]), _123[3]), _123[4]), _123[5]), _123[6]), _123[7]), _123[8]));
        _1500 = _1491 * 0.04625000059604644775390625;
    }
    else
    {
        _1499 = _1466;
        _1500 = _1491;
    }
    float3 _1532;
    if (_733)
    {
        float _1503 = _1483.x;
        float _1504 = _1483.y;
        float _1506 = _1483.z;
        float _1507 = (_1503 + _1504) - _1506;
        float _1508 = _1503 + _1506;
        float _1510 = (_1503 - _1504) - _1506;
        float3 _1517 = float3(_1507, _1508, _1510) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1507, precise::max(_1508, _1510))));
        float _1518 = _1517.x;
        float _1521 = 0.5 * _1517.y;
        float _1523 = _1517.z;
        float _1524 = 0.25 * _1523;
        _1532 = float3(((0.25 * _1518) + _1521) + _1524, 0.5 * (_1518 - _1523), (((-0.25) * _1518) + _1521) - _1524);
    }
    else
    {
        _1532 = _1499;
    }
    float _1533 = _733 ? 1.0 : _1500;
    float _1534 = _733 ? 0.0 : _713;
    float3 _1548 = (sqrt(abs(((((((((((_123[0] * _1149) + (_123[1] * _1187)) + (_123[2] * _1228)) + (_123[3] * _1269)) + (_123[4] * _1310)) + (_123[5] * _1351)) + (_123[6] * _1392)) + (_123[7] * _1433)) + (_123[8] * _1474)) / _1482) - (_1483 * _1483))) * float3(1.7000000476837158203125, 1.0, 1.0)) * mix(3.0, 1.0, precise::max(fast::clamp(_158 * 0.0500000007450580596923828125, 0.0, 1.0), precise::max(fast::clamp(0.75 - (r_farthest_depth_mip1.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_138 * _192, _192 - float2(0.5))) / float2(int2(int(_186.x), int(_186.y)))), level(0.0)).x * 0.0500000007450580596923828125), 0.0, 1.0), precise::max(1.0 - _226, precise::max(powr(_215, 0.5), _219)))));
    float3 _1551 = (_658 - _1483) / precise::max(_1548, float3(1.19299997436428384389728307724e-07));
    float3 _1566;
    if (length(_1551) > 1.0)
    {
        _1566 = mix((fast::normalize(_1551) * _1548) + _1483, _658, float3(fast::clamp((precise::max(r_luma_instability.sample(s_LinearClamp, (precise::max(float2(0.5), precise::min(_131 * _136, _142)) / _145), level(0.0)).x, fast::clamp(fast::clamp(_668 - 1.0, 0.0, 1.0), 0.0, 1.0)) * _226) * (1.0 - _217), 0.0, 1.0)));
    }
    else
    {
        _1566 = _658;
    }
    float _1576 = (_1532.x + _1532.y) - _1532.z;
    float _1577 = _1532.x + _1532.z;
    float _1579 = (_1532.x - _1532.y) - _1532.z;
    float3 _1586 = float3(_1576, _1577, _1579) / float3(precise::max(precise::max(0.0, _1576), precise::max(_1577, _1579)) + 1.0);
    float _1587 = _1586.x;
    float _1590 = 0.5 * _1586.y;
    float _1592 = _1586.z;
    float _1593 = 0.25 * _1592;
    float _1605 = (_1566.x + _1566.y) - _1566.z;
    float _1606 = _1566.x + _1566.z;
    float _1608 = (_1566.x - _1566.y) - _1566.z;
    float3 _1615 = float3(_1605, _1606, _1608) / float3(precise::max(precise::max(0.0, _1605), precise::max(_1606, _1608)) + 1.0);
    float _1616 = _1615.x;
    float _1619 = 0.5 * _1615.y;
    float _1621 = _1615.z;
    float _1622 = 0.25 * _1621;
    float3 _1633 = mix(float3(((0.25 * _1616) + _1619) + _1622, 0.5 * (_1616 - _1621), (((-0.25) * _1616) + _1619) - _1622), float3(((0.25 * _1587) + _1590) + _1593, 0.5 * (_1587 - _1592), (((-0.25) * _1587) + _1590) - _1593), float3(fast::clamp(_1533 / precise::max(6.099999882280826568603515625e-05, (_1534 * float(_1534 > 6.099999882280826568603515625e-05)) + _1533), 0.0, 1.0)));
    float _1638 = (_1633.x + _1633.y) - _1633.z;
    float _1639 = _1633.x + _1633.z;
    float _1641 = (_1633.x - _1633.y) - _1633.z;
    float4 _1650 = sdk_hlsl_load(r_input_exposure, uint2(uint2(0u)), 0u);
    float _1651 = _1650.x;
    float3 _1656 = precise::max((float3(_1638, _1639, _1641) / float3(precise::max(6.099999882280826568603515625e-05, 1.0 - precise::max(_1638, precise::max(_1639, _1641))))) / float3((_1651 == 0.0) ? 1.0 : _1651), float3(0.0));
    float _1657 = _1656.x;
    sdk_hlsl_store(rw_internal_upscaled_color, float4(_1657, _1656.yz, precise::max(0.0, precise::max(0.0, precise::min(_668 + (sdk_hlsl_load(rw_new_locks, uint2(_147)).x * (1.0 - precise::max(0.0, _215))), 2.0)) - ((0.100000001490116119384765625 / cbFSR3Upscaler.fJitterSequenceLength) * (1.0 - _665))) * float(_703)), uint2(_147));
    sdk_hlsl_store(rw_upscaled_output, float4(_1657, _1656.yz, 1.0), uint2(_147));
    sdk_hlsl_store(rw_new_locks, float4(0.0), uint2(_147));
}

