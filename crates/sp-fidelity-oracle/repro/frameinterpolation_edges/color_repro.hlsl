// Analytic sources for AMD's unchanged color-interpolation shader.
// No Rust, game, captured inputs, temporal history, or motion estimation.
// SPDX-License-Identifier: MIT
#define FFX_GPU 1
#define FFX_HLSL 1
#include "ffx_core.h"
struct Config { uint width; uint height; uint scenario; uint unused; };
[[vk::push_constant]] ConstantBuffer<Config> config;
[[vk::binding(0, 0)]] RWStructuredBuffer<uint2> output;
int2 RenderSize() { return int2(config.width,config.height); }
int2 DisplaySize() { return RenderSize(); }
int2 GetMaxRenderSize() { return RenderSize(); }
int2 InterpolationRectBase() { return int2(0,0); }
int2 InterpolationRectSize() { return RenderSize(); }
int2 ColorRectBase() { return int2(0,0); }
int2 ColorRectSize() { return RenderSize(); }
uint BackBufferTransferFunction() { return 2; } // linear/scRGB
float MinLuminance() { return 0; }
float MaxLuminance() { return 80; }
float2 Jitter() { return 0; }
float4 DeviceToViewSpaceTransformFactors() { return float4(0,.3,1,1); }
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#include "frameinterpolation/ffx_frameinterpolation_common.h"

// Full geometric translation is (0,-.25); exact midpoint half motion is
// (0,-.125). Infinite-plane depths can remain constant and positive.
VectorFieldEntry vectorAt(float2 uv, float2 motion) {
    VectorFieldEntry v=NewVectorFieldEntry();
    v.fMotionVector=motion; v.bValid=true;
    v.bPosOutside=!IsUvInside(uv+motion);
    v.bNegOutside=!IsUvInside(uv-motion);
    v.fVelocity=length(motion);
    return v;
}
void LoadInpaintedGameFieldMv(float2 uv,out VectorFieldEntry v) {
    v=vectorAt(uv,float2(0,-.125));
}
void SampleOpticalFlowMotionVectorField(float2 uv,out VectorFieldEntry v) {
    // Exact OF for uniform illumination and both mirror cases; deliberately
    // incorrect stationary OF for the diffuse negative controls.
    v=vectorAt(uv,config.scenario==0 ? float2(0,-.125) : float2(0,0));
}
float4 SampleDisocclusionMask(float2 uv) {return float4(1,1,0,0);}
uint FrameIndexSinceLastReset() {return 12;}
float3 color(int2 p,bool current) {
    float2 uv=(float2(p)+.5)/float2(RenderSize());
    float r;
    if (config.scenario==0) return current ? .75 : .5;
    if (config.scenario==1) return float3(.25+.5*uv.y,.25+.25*uv.x,.5);
    float period=config.scenario==3 ? 16 : 48;
    float shift=(current && config.scenario!=4) ? 16 : 0;
    r=.5+.25*sin((float(p.y)+.5-shift)*6.283185307179586/period);
    if (current && config.scenario==3) r+=1.0/1024.0;
    return float3(r,.5,.5);
}
float3 LoadPreviousBackbuffer(int2 p) {return color(p,false);}
float3 LoadCurrentBackbuffer(int2 p) {return color(p,true);}
void StoreFrameinterpolationOutput(int2 p,float4 value) {
    output[p.y*config.width+p.x]=asuint(value.ra);
}
// All interpolation, source-availability, and hypothesis blending remain AMD's.
#include "frameinterpolation/ffx_frameinterpolation.h"
[numthreads(8,8,1)]
void main(uint3 id:SV_DispatchThreadID) {
    if (all(id.xy<uint2(RenderSize()))) computeFrameinterpolation(int2(id.xy));
}
