// This file is part of the FidelityFX SDK.
//
// Copyright (C) 2024 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// WGSL port of ffx_core.h: ffx_common_types.h, ffx_core_hlsl.h,
// ffx_core_gpu_common.h and ffx_core_gpu_common_half.h, in SDK order. Only the
// declarations the ported code uses are present; each core function the FSR2
// headers and FSR1's RCAS call is present with all its SDK overloads.
//
// WGSL has no overloading: an overloaded SDK function carries a suffix naming
// its parameter types in order (b for FfxBoolean, f32, f32x3, f16x3, i16x2,
// u32x2, ..., or a struct's name), e.g. ffxLerp(FfxFloat32x3, FfxFloat32x3,
// FfxFloat32) is ffxLerp_f32x3_f32x3_f32. The FFX_MIN16_* types name their
// FFX_HALF types (FFX_MIN16_F is f16, FFX_MIN16_I2 is i16x2). Function-like SDK
// macros are WGSL functions of the types the effects use, or are expanded in
// place where noted.

#ifndef FFX_CORE_H
#define FFX_CORE_H

// ---- ffx_common_types.h (FFX_HLSL, FFX_HLSL_SM >= 62) ----------------------

// #define FFX_PARAMETER_IN in / FFX_PARAMETER_OUT out / FFX_PARAMETER_INOUT inout
// WGSL: an in parameter is a value parameter; out and inout parameters are
// ptr<function, T> parameters, whose callers pass the address of a local.

alias FfxBoolean = bool;
alias FfxFloat32 = f32;
alias FfxFloat32x2 = vec2<f32>;
alias FfxFloat32x3 = vec3<f32>;
alias FfxFloat32x4 = vec4<f32>;
alias FfxUInt32 = u32;
alias FfxUInt32x2 = vec2<u32>;
alias FfxUInt32x3 = vec3<u32>;
alias FfxUInt32x4 = vec4<u32>;
alias FfxInt32 = i32;
alias FfxInt32x2 = vec2<i32>;
alias FfxInt32x3 = vec3<i32>;
alias FfxInt32x4 = vec4<i32>;
// HLSL matrix<float, 4, 4>; column-major constant packing as in WGSL.
alias FfxFloat32Mat4 = mat4x4<f32>;
alias FfxFloat32Mat3 = mat3x3<f32>;

#if FFX_HALF
alias FfxFloat16 = f16;
alias FfxFloat16x2 = vec2<f16>;
alias FfxFloat16x3 = vec3<f16>;
alias FfxFloat16x4 = vec4<f16>;
// WGSL: no 16-bit integers. uint16_t and int16_t are 32-bit; SDK values that
// wrap at 16 bits would differ, and none of the ported code relies on it.
alias FfxUInt16 = u32;
alias FfxUInt16x2 = vec2<u32>;
alias FfxUInt16x3 = vec3<u32>;
alias FfxUInt16x4 = vec4<u32>;
alias FfxInt16 = i32;
alias FfxInt16x2 = vec2<i32>;
alias FfxInt16x3 = vec3<i32>;
alias FfxInt16x4 = vec4<i32>;

// FFX_MIN16_SCALAR/FFX_MIN16_VECTOR(FFX_MIN16_*, float/int/uint) with FFX_HALF
// and FFX_HLSL_SM >= 62 (ffx_common_types.h, GPU section): 16-bit types.
alias FFX_MIN16_F = f16;
alias FFX_MIN16_F2 = vec2<f16>;
alias FFX_MIN16_F3 = vec3<f16>;
alias FFX_MIN16_F4 = vec4<f16>;
// WGSL: int16_t and uint16_t are 32-bit, as above.
alias FFX_MIN16_I = i32;
alias FFX_MIN16_I2 = vec2<i32>;
alias FFX_MIN16_I3 = vec3<i32>;
alias FFX_MIN16_I4 = vec4<i32>;
alias FFX_MIN16_U = u32;
alias FFX_MIN16_U2 = vec2<u32>;
alias FFX_MIN16_U3 = vec3<u32>;
alias FFX_MIN16_U4 = vec4<u32>;
#else // #if FFX_HALF
// FFX_MIN16_SCALAR/FFX_MIN16_VECTOR without FFX_HALF: the 32-bit types.
alias FFX_MIN16_F = f32;
alias FFX_MIN16_F2 = vec2<f32>;
alias FFX_MIN16_F3 = vec3<f32>;
alias FFX_MIN16_F4 = vec4<f32>;
alias FFX_MIN16_I = i32;
alias FFX_MIN16_I2 = vec2<i32>;
alias FFX_MIN16_I3 = vec3<i32>;
alias FFX_MIN16_I4 = vec4<i32>;
alias FFX_MIN16_U = u32;
alias FFX_MIN16_U2 = vec2<u32>;
alias FFX_MIN16_U3 = vec3<u32>;
alias FFX_MIN16_U4 = vec4<u32>;
#endif // #if FFX_HALF

// ---- ffx_core_hlsl.h ---------------------------------------------------------

// #define FFX_SELECT(cond, arg1, arg2) select(cond, arg1, arg2) (HLSL 2021).
// WGSL: expanded in place as select(arg2, arg1, cond), as is the SDK's
// cond ? arg1 : arg2.

// #define FFX_GROUPSHARED groupshared
// WGSL: expanded in place as a var<workgroup> declaration.

// #define FFX_GROUP_MEMORY_BARRIER GroupMemoryBarrierWithGroupSync()
fn FFX_GROUP_MEMORY_BARRIER() {
    workgroupBarrier();
}

// #define FFX_ATOMIC_ADD(x, y) InterlockedAdd(x, y)
// WGSL: expanded in place as atomicAdd on an atomic declaration; a workgroup
// pointer cannot be a function argument.

// #define FFX_STATIC static
// WGSL: a static const is a module-scope const; a static function is a function.

// #define FFX_UNROLL [unroll]
// WGSL: no loop attributes; the pass preprocessor (sp-fidelity::shaders)
// unrolls the for statement after an FFX_UNROLL line (SDK-P26).

// #define FFX_GREATER_THAN(x, y) x > y, FFX_GREATER_THAN_EQUAL(x, y) x >= y,
// FFX_LESS_THAN(x, y) x < y, FFX_LESS_THAN_EQUAL(x, y) x <= y,
// FFX_EQUAL(x, y) x == y, FFX_NOT_EQUAL(x, y) x != y
// WGSL: expanded in place.

// #define FFX_MATRIX_MULTIPLY(a, b) mul(a, b)
fn FFX_MATRIX_MULTIPLY(a: FfxFloat32Mat4, b: FfxFloat32x4) -> FfxFloat32x4 {
    return a * b;
}

// #define FFX_MODULO(a, b) (fmod(a, b)); WGSL's floating-point % is fmod.
fn FFX_MODULO(a: FfxFloat32, b: FfxFloat32) -> FfxFloat32 {
    return a % b;
}

// #define FFX_BROADCAST_FLOAT32X2(x) FfxFloat32(x) (and the other
// FFX_BROADCAST_* macros): HLSL splats the scalar where a vector is expected.
// WGSL: expanded in place as the vector constructor, e.g. FfxFloat32x4(x).

// #define ffxF32ToF16 f32tof16
// WGSL: f32tof16 is an HLSL intrinsic; pack2x16float with a zero high half is
// the same conversion (DXC emits PackHalf2x16(v, 0)).
fn ffxF32ToF16_f32(value: FfxFloat32) -> FfxUInt32
{
    return pack2x16float(FfxFloat32x2(value, 0.0f));
}

fn ffxF32ToF16_f32x2(value: FfxFloat32x2) -> FfxUInt32x2
{
    return FfxUInt32x2(pack2x16float(FfxFloat32x2(value.x, 0.0f)), pack2x16float(FfxFloat32x2(value.y, 0.0f)));
}

fn ffxPackHalf2x16(value: FfxFloat32x2) -> FfxUInt32
{
    return ffxF32ToF16_f32(value.x) | (ffxF32ToF16_f32(value.y) << 16u);
}

fn ffxBroadcast2_f32(value: FfxFloat32) -> FfxFloat32x2
{
    return FfxFloat32x2(value, value);
}

fn ffxBroadcast3_f32(value: FfxFloat32) -> FfxFloat32x3
{
    return FfxFloat32x3(value, value, value);
}

fn ffxBroadcast4_f32(value: FfxFloat32) -> FfxFloat32x4
{
    return FfxFloat32x4(value, value, value, value);
}

fn ffxBroadcast2_i32(value: FfxInt32) -> FfxInt32x2
{
    return FfxInt32x2(value, value);
}

fn ffxBroadcast3_i32(value: FfxInt32) -> FfxInt32x3
{
    return FfxInt32x3(value, value, value);
}

fn ffxBroadcast4_i32(value: FfxInt32) -> FfxInt32x4
{
    return FfxInt32x4(value, value, value, value);
}

fn ffxBroadcast2_u32(value: FfxUInt32) -> FfxUInt32x2
{
    return FfxUInt32x2(value, value);
}

fn ffxBroadcast3_u32(value: FfxUInt32) -> FfxUInt32x3
{
    return FfxUInt32x3(value, value, value);
}

fn ffxBroadcast4_u32(value: FfxUInt32) -> FfxUInt32x4
{
    return FfxUInt32x4(value, value, value, value);
}

fn ffxBitfieldExtract(src: FfxUInt32, off: FfxUInt32, bits: FfxUInt32) -> FfxUInt32
{
    let mask: FfxUInt32 = (1u << bits) - 1u;
    return (src >> off) & mask;
}

fn ffxBitfieldInsertMask(src: FfxUInt32, ins: FfxUInt32, bits: FfxUInt32) -> FfxUInt32
{
    let mask: FfxUInt32 = (1u << bits) - 1u;
    return (ins & mask) | (src & (~mask));
}

fn ffxAsUInt32_f32(x: FfxFloat32) -> FfxUInt32
{
    return bitcast<FfxUInt32>(x);
}

fn ffxAsUInt32_f32x2(x: FfxFloat32x2) -> FfxUInt32x2
{
    return bitcast<FfxUInt32x2>(x);
}

fn ffxAsUInt32_f32x3(x: FfxFloat32x3) -> FfxUInt32x3
{
    return bitcast<FfxUInt32x3>(x);
}

fn ffxAsUInt32_f32x4(x: FfxFloat32x4) -> FfxUInt32x4
{
    return bitcast<FfxUInt32x4>(x);
}

fn ffxAsFloat_u32(x: FfxUInt32) -> FfxFloat32
{
    return bitcast<FfxFloat32>(x);
}

fn ffxAsFloat_u32x2(x: FfxUInt32x2) -> FfxFloat32x2
{
    return bitcast<FfxFloat32x2>(x);
}

fn ffxAsFloat_u32x3(x: FfxUInt32x3) -> FfxFloat32x3
{
    return bitcast<FfxFloat32x3>(x);
}

fn ffxAsFloat_u32x4(x: FfxUInt32x4) -> FfxFloat32x4
{
    return bitcast<FfxFloat32x4>(x);
}

// rcp(x). WGSL: 1 / x, as DXC emits it (OpFDiv).
fn ffxReciprocal_f32(x: FfxFloat32) -> FfxFloat32
{
    return 1.0f / x;
}

fn ffxReciprocal_f32x2(x: FfxFloat32x2) -> FfxFloat32x2
{
    return 1.0f / x;
}

fn ffxReciprocal_f32x3(x: FfxFloat32x3) -> FfxFloat32x3
{
    return 1.0f / x;
}

fn ffxReciprocal_f32x4(x: FfxFloat32x4) -> FfxFloat32x4
{
    return 1.0f / x;
}

fn ffxRsqrt_f32(x: FfxFloat32) -> FfxFloat32
{
    return inverseSqrt(x);
}

// lerp(x, y, t). WGSL: mix.
fn ffxLerp_f32_f32_f32(x: FfxFloat32, y: FfxFloat32, t: FfxFloat32) -> FfxFloat32
{
    return mix(x, y, t);
}

fn ffxLerp_f32x2_f32x2_f32(x: FfxFloat32x2, y: FfxFloat32x2, t: FfxFloat32) -> FfxFloat32x2
{
    return mix(x, y, t);
}

fn ffxLerp_f32x2_f32x2_f32x2(x: FfxFloat32x2, y: FfxFloat32x2, t: FfxFloat32x2) -> FfxFloat32x2
{
    return mix(x, y, t);
}

fn ffxLerp_f32x3_f32x3_f32(x: FfxFloat32x3, y: FfxFloat32x3, t: FfxFloat32) -> FfxFloat32x3
{
    return mix(x, y, t);
}

fn ffxLerp_f32x3_f32x3_f32x3(x: FfxFloat32x3, y: FfxFloat32x3, t: FfxFloat32x3) -> FfxFloat32x3
{
    return mix(x, y, t);
}

fn ffxLerp_f32x4_f32x4_f32(x: FfxFloat32x4, y: FfxFloat32x4, t: FfxFloat32) -> FfxFloat32x4
{
    return mix(x, y, t);
}

fn ffxLerp_f32x4_f32x4_f32x4(x: FfxFloat32x4, y: FfxFloat32x4, t: FfxFloat32x4) -> FfxFloat32x4
{
    return mix(x, y, t);
}

fn ffxSaturate_f32(x: FfxFloat32) -> FfxFloat32
{
    return saturate(x);
}

fn ffxSaturate_f32x2(x: FfxFloat32x2) -> FfxFloat32x2
{
    return saturate(x);
}

fn ffxSaturate_f32x3(x: FfxFloat32x3) -> FfxFloat32x3
{
    return saturate(x);
}

fn ffxSaturate_f32x4(x: FfxFloat32x4) -> FfxFloat32x4
{
    return saturate(x);
}

fn ffxFract_f32(x: FfxFloat32) -> FfxFloat32
{
    return x - floor(x);
}

fn ffxFract_f32x2(x: FfxFloat32x2) -> FfxFloat32x2
{
    return x - floor(x);
}

fn ffxFract_f32x3(x: FfxFloat32x3) -> FfxFloat32x3
{
    return x - floor(x);
}

fn ffxFract_f32x4(x: FfxFloat32x4) -> FfxFloat32x4
{
    return x - floor(x);
}

fn ffxMax3_f32_f32_f32(x: FfxFloat32, y: FfxFloat32, z: FfxFloat32) -> FfxFloat32
{
    return max(x, max(y, z));
}

fn ffxMax3_f32x2_f32x2_f32x2(x: FfxFloat32x2, y: FfxFloat32x2, z: FfxFloat32x2) -> FfxFloat32x2
{
    return max(x, max(y, z));
}

fn ffxMax3_f32x3_f32x3_f32x3(x: FfxFloat32x3, y: FfxFloat32x3, z: FfxFloat32x3) -> FfxFloat32x3
{
    return max(x, max(y, z));
}

fn ffxMax3_f32x4_f32x4_f32x4(x: FfxFloat32x4, y: FfxFloat32x4, z: FfxFloat32x4) -> FfxFloat32x4
{
    return max(x, max(y, z));
}

fn ffxMax3_u32_u32_u32(x: FfxUInt32, y: FfxUInt32, z: FfxUInt32) -> FfxUInt32
{
    return max(x, max(y, z));
}

fn ffxMax3_u32x2_u32x2_u32x2(x: FfxUInt32x2, y: FfxUInt32x2, z: FfxUInt32x2) -> FfxUInt32x2
{
    return max(x, max(y, z));
}

fn ffxMax3_u32x3_u32x3_u32x3(x: FfxUInt32x3, y: FfxUInt32x3, z: FfxUInt32x3) -> FfxUInt32x3
{
    return max(x, max(y, z));
}

fn ffxMax3_u32x4_u32x4_u32x4(x: FfxUInt32x4, y: FfxUInt32x4, z: FfxUInt32x4) -> FfxUInt32x4
{
    return max(x, max(y, z));
}

fn ffxMin3_f32_f32_f32(x: FfxFloat32, y: FfxFloat32, z: FfxFloat32) -> FfxFloat32
{
    return min(x, min(y, z));
}

fn ffxMin3_f32x2_f32x2_f32x2(x: FfxFloat32x2, y: FfxFloat32x2, z: FfxFloat32x2) -> FfxFloat32x2
{
    return min(x, min(y, z));
}

fn ffxMin3_f32x3_f32x3_f32x3(x: FfxFloat32x3, y: FfxFloat32x3, z: FfxFloat32x3) -> FfxFloat32x3
{
    return min(x, min(y, z));
}

fn ffxMin3_f32x4_f32x4_f32x4(x: FfxFloat32x4, y: FfxFloat32x4, z: FfxFloat32x4) -> FfxFloat32x4
{
    return min(x, min(y, z));
}

fn ffxMin3_u32_u32_u32(x: FfxUInt32, y: FfxUInt32, z: FfxUInt32) -> FfxUInt32
{
    return min(x, min(y, z));
}

fn ffxMin3_u32x2_u32x2_u32x2(x: FfxUInt32x2, y: FfxUInt32x2, z: FfxUInt32x2) -> FfxUInt32x2
{
    return min(x, min(y, z));
}

fn ffxMin3_u32x3_u32x3_u32x3(x: FfxUInt32x3, y: FfxUInt32x3, z: FfxUInt32x3) -> FfxUInt32x3
{
    return min(x, min(y, z));
}

fn ffxMin3_u32x4_u32x4_u32x4(x: FfxUInt32x4, y: FfxUInt32x4, z: FfxUInt32x4) -> FfxUInt32x4
{
    return min(x, min(y, z));
}

#if FFX_HALF

fn ffxFract_f16(x: FFX_MIN16_F) -> FFX_MIN16_F
{
    return x - floor(x);
}

fn ffxFract_f16x2(x: FFX_MIN16_F2) -> FFX_MIN16_F2
{
    return x - floor(x);
}

fn ffxFract_f16x3(x: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    return x - floor(x);
}

fn ffxFract_f16x4(x: FFX_MIN16_F4) -> FFX_MIN16_F4
{
    return x - floor(x);
}

fn ffxLerp_f16_f16_f16(x: FFX_MIN16_F, y: FFX_MIN16_F, a: FFX_MIN16_F) -> FFX_MIN16_F
{
    return mix(x, y, a);
}

fn ffxLerp_f16x2_f16x2_f16(x: FFX_MIN16_F2, y: FFX_MIN16_F2, a: FFX_MIN16_F) -> FFX_MIN16_F2
{
    return mix(x, y, a);
}

fn ffxLerp_f16x2_f16x2_f16x2(x: FFX_MIN16_F2, y: FFX_MIN16_F2, a: FFX_MIN16_F2) -> FFX_MIN16_F2
{
    return mix(x, y, a);
}

fn ffxLerp_f16x3_f16x3_f16(x: FFX_MIN16_F3, y: FFX_MIN16_F3, a: FFX_MIN16_F) -> FFX_MIN16_F3
{
    return mix(x, y, a);
}

fn ffxLerp_f16x3_f16x3_f16x3(x: FFX_MIN16_F3, y: FFX_MIN16_F3, a: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    return mix(x, y, a);
}

fn ffxLerp_f16x4_f16x4_f16(x: FFX_MIN16_F4, y: FFX_MIN16_F4, a: FFX_MIN16_F) -> FFX_MIN16_F4
{
    return mix(x, y, a);
}

fn ffxLerp_f16x4_f16x4_f16x4(x: FFX_MIN16_F4, y: FFX_MIN16_F4, a: FFX_MIN16_F4) -> FFX_MIN16_F4
{
    return mix(x, y, a);
}

fn ffxSaturate_f16(x: FFX_MIN16_F) -> FFX_MIN16_F
{
    return saturate(x);
}

fn ffxSaturate_f16x2(x: FFX_MIN16_F2) -> FFX_MIN16_F2
{
    return saturate(x);
}

fn ffxSaturate_f16x3(x: FFX_MIN16_F3) -> FFX_MIN16_F3
{
    return saturate(x);
}

fn ffxSaturate_f16x4(x: FFX_MIN16_F4) -> FFX_MIN16_F4
{
    return saturate(x);
}

#endif // #if FFX_HALF

// WGSL: HLSL WaveGetLaneIndex() is an intrinsic; WGSL provides the lane index only
// as an entry-point builtin. Each wave-using entry point stores it here first.
var<private> ffx_wgsl_subgroup_invocation_id: FfxUInt32;

fn ffxWaveIsFirstLane() -> FfxBoolean
{
    // WaveIsFirstLane(). WGSL: naga 29 has no subgroupElect(); the first active
    // lane is the lane whose index the first active lane broadcasts.
    return ffx_wgsl_subgroup_invocation_id == subgroupBroadcastFirst(ffx_wgsl_subgroup_invocation_id);
}

fn ffxWaveLaneIndex() -> FfxUInt32
{
    return ffx_wgsl_subgroup_invocation_id;
}

fn ffxWaveReadAtLaneIndexB1(v: FfxBoolean, x: FfxUInt32) -> FfxBoolean
{
    // WaveReadLaneAt(v, x). WGSL: subgroupShuffle has no bool overload.
    return subgroupShuffle(FfxUInt32(v), x) != 0u;
}

fn ffxWavePrefixCountBits(v: FfxBoolean) -> FfxUInt32
{
    // WavePrefixCountBits(v): active lower lanes with v set.
    return subgroupExclusiveAdd(FfxUInt32(v));
}

fn ffxWaveActiveCountBits(v: FfxBoolean) -> FfxUInt32
{
    // WaveActiveCountBits(v)
    let counts: FfxUInt32x4 = countOneBits(subgroupBallot(v));
    return counts.x + counts.y + counts.z + counts.w;
}

fn ffxWaveReadLaneFirstU1(v: FfxUInt32) -> FfxUInt32
{
    return subgroupBroadcastFirst(v);
}

// ---- ffx_core_gpu_common.h ---------------------------------------------------

#define FFX_TRUE (true)
#define FFX_FALSE (false)

fn ffxMin_f32_f32(x: FfxFloat32, y: FfxFloat32) -> FfxFloat32
{
    return min(x, y);
}

fn ffxMin_f32x2_f32x2(x: FfxFloat32x2, y: FfxFloat32x2) -> FfxFloat32x2
{
    return min(x, y);
}

fn ffxMin_f32x3_f32x3(x: FfxFloat32x3, y: FfxFloat32x3) -> FfxFloat32x3
{
    return min(x, y);
}

fn ffxMin_f32x4_f32x4(x: FfxFloat32x4, y: FfxFloat32x4) -> FfxFloat32x4
{
    return min(x, y);
}

fn ffxMin_i32_i32(x: FfxInt32, y: FfxInt32) -> FfxInt32
{
    return min(x, y);
}

fn ffxMin_i32x2_i32x2(x: FfxInt32x2, y: FfxInt32x2) -> FfxInt32x2
{
    return min(x, y);
}

fn ffxMin_i32x3_i32x3(x: FfxInt32x3, y: FfxInt32x3) -> FfxInt32x3
{
    return min(x, y);
}

fn ffxMin_i32x4_i32x4(x: FfxInt32x4, y: FfxInt32x4) -> FfxInt32x4
{
    return min(x, y);
}

fn ffxMin_u32_u32(x: FfxUInt32, y: FfxUInt32) -> FfxUInt32
{
    return min(x, y);
}

fn ffxMin_u32x2_u32x2(x: FfxUInt32x2, y: FfxUInt32x2) -> FfxUInt32x2
{
    return min(x, y);
}

fn ffxMin_u32x3_u32x3(x: FfxUInt32x3, y: FfxUInt32x3) -> FfxUInt32x3
{
    return min(x, y);
}

fn ffxMin_u32x4_u32x4(x: FfxUInt32x4, y: FfxUInt32x4) -> FfxUInt32x4
{
    return min(x, y);
}

fn ffxMax_f32_f32(x: FfxFloat32, y: FfxFloat32) -> FfxFloat32
{
    return max(x, y);
}

fn ffxMax_f32x2_f32x2(x: FfxFloat32x2, y: FfxFloat32x2) -> FfxFloat32x2
{
    return max(x, y);
}

fn ffxMax_f32x3_f32x3(x: FfxFloat32x3, y: FfxFloat32x3) -> FfxFloat32x3
{
    return max(x, y);
}

fn ffxMax_f32x4_f32x4(x: FfxFloat32x4, y: FfxFloat32x4) -> FfxFloat32x4
{
    return max(x, y);
}

fn ffxMax_i32_i32(x: FfxInt32, y: FfxInt32) -> FfxInt32
{
    return max(x, y);
}

fn ffxMax_i32x2_i32x2(x: FfxInt32x2, y: FfxInt32x2) -> FfxInt32x2
{
    return max(x, y);
}

fn ffxMax_i32x3_i32x3(x: FfxInt32x3, y: FfxInt32x3) -> FfxInt32x3
{
    return max(x, y);
}

fn ffxMax_i32x4_i32x4(x: FfxInt32x4, y: FfxInt32x4) -> FfxInt32x4
{
    return max(x, y);
}

fn ffxMax_u32_u32(x: FfxUInt32, y: FfxUInt32) -> FfxUInt32
{
    return max(x, y);
}

fn ffxMax_u32x2_u32x2(x: FfxUInt32x2, y: FfxUInt32x2) -> FfxUInt32x2
{
    return max(x, y);
}

fn ffxMax_u32x3_u32x3(x: FfxUInt32x3, y: FfxUInt32x3) -> FfxUInt32x3
{
    return max(x, y);
}

fn ffxMax_u32x4_u32x4(x: FfxUInt32x4, y: FfxUInt32x4) -> FfxUInt32x4
{
    return max(x, y);
}

fn ffxPow_f32_f32(x: FfxFloat32, y: FfxFloat32) -> FfxFloat32
{
    return pow(x, y);
}

fn ffxPow_f32x2_f32x2(x: FfxFloat32x2, y: FfxFloat32x2) -> FfxFloat32x2
{
    return pow(x, y);
}

fn ffxPow_f32x3_f32x3(x: FfxFloat32x3, y: FfxFloat32x3) -> FfxFloat32x3
{
    return pow(x, y);
}

fn ffxPow_f32x4_f32x4(x: FfxFloat32x4, y: FfxFloat32x4) -> FfxFloat32x4
{
    return pow(x, y);
}

fn ffxApproximateReciprocalMedium_f32(value: FfxFloat32) -> FfxFloat32
{
    let b: FfxFloat32 = ffxAsFloat_u32(FfxUInt32(0x7ef19fff) - ffxAsUInt32_f32(value));
    return b * (-b * value + FfxFloat32(2.0));
}

fn ffxApproximateReciprocalMedium_f32x2(value: FfxFloat32x2) -> FfxFloat32x2
{
    let b: FfxFloat32x2 = ffxAsFloat_u32x2(ffxBroadcast2_u32(0x7ef19fffu) - ffxAsUInt32_f32x2(value));
    return b * (-b * value + ffxBroadcast2_f32(2.0f));
}

fn ffxApproximateReciprocalMedium_f32x3(value: FfxFloat32x3) -> FfxFloat32x3
{
    let b: FfxFloat32x3 = ffxAsFloat_u32x3(ffxBroadcast3_u32(0x7ef19fffu) - ffxAsUInt32_f32x3(value));
    return b * (-b * value + ffxBroadcast3_f32(2.0f));
}

fn ffxApproximateReciprocalMedium_f32x4(value: FfxFloat32x4) -> FfxFloat32x4
{
    let b: FfxFloat32x4 = ffxAsFloat_u32x4(ffxBroadcast4_u32(0x7ef19fffu) - ffxAsUInt32_f32x4(value));
    return b * (-b * value + ffxBroadcast4_f32(2.0f));
}

fn ffxRemapForQuad(a: FfxUInt32) -> FfxUInt32x2
{
    return FfxUInt32x2(ffxBitfieldExtract(a, 1u, 3u), ffxBitfieldInsertMask(ffxBitfieldExtract(a, 3u, 3u), a, 1u));
}

fn ffxRemapForWaveReduction(a: FfxUInt32) -> FfxUInt32x2
{
    return FfxUInt32x2(ffxBitfieldInsertMask(ffxBitfieldExtract(a, 2u, 3u), a, 1u), ffxBitfieldInsertMask(ffxBitfieldExtract(a, 3u, 3u), ffxBitfieldExtract(a, 1u, 2u), 2u));
}

// ---- ffx_core_gpu_common_half.h ----------------------------------------------

#if FFX_HALF

fn ffxMin_f16_f16(x: FfxFloat16, y: FfxFloat16) -> FfxFloat16
{
    return min(x, y);
}

fn ffxMin_f16x2_f16x2(x: FfxFloat16x2, y: FfxFloat16x2) -> FfxFloat16x2
{
    return min(x, y);
}

fn ffxMin_f16x3_f16x3(x: FfxFloat16x3, y: FfxFloat16x3) -> FfxFloat16x3
{
    return min(x, y);
}

fn ffxMin_f16x4_f16x4(x: FfxFloat16x4, y: FfxFloat16x4) -> FfxFloat16x4
{
    return min(x, y);
}

fn ffxMin_i16_i16(x: FfxInt16, y: FfxInt16) -> FfxInt16
{
    return min(x, y);
}

fn ffxMin_i16x2_i16x2(x: FfxInt16x2, y: FfxInt16x2) -> FfxInt16x2
{
    return min(x, y);
}

fn ffxMin_i16x3_i16x3(x: FfxInt16x3, y: FfxInt16x3) -> FfxInt16x3
{
    return min(x, y);
}

fn ffxMin_i16x4_i16x4(x: FfxInt16x4, y: FfxInt16x4) -> FfxInt16x4
{
    return min(x, y);
}

fn ffxMin_u16_u16(x: FfxUInt16, y: FfxUInt16) -> FfxUInt16
{
    return min(x, y);
}

fn ffxMin_u16x2_u16x2(x: FfxUInt16x2, y: FfxUInt16x2) -> FfxUInt16x2
{
    return min(x, y);
}

fn ffxMin_u16x3_u16x3(x: FfxUInt16x3, y: FfxUInt16x3) -> FfxUInt16x3
{
    return min(x, y);
}

fn ffxMin_u16x4_u16x4(x: FfxUInt16x4, y: FfxUInt16x4) -> FfxUInt16x4
{
    return min(x, y);
}

fn ffxMax_f16_f16(x: FfxFloat16, y: FfxFloat16) -> FfxFloat16
{
    return max(x, y);
}

fn ffxMax_f16x2_f16x2(x: FfxFloat16x2, y: FfxFloat16x2) -> FfxFloat16x2
{
    return max(x, y);
}

fn ffxMax_f16x3_f16x3(x: FfxFloat16x3, y: FfxFloat16x3) -> FfxFloat16x3
{
    return max(x, y);
}

fn ffxMax_f16x4_f16x4(x: FfxFloat16x4, y: FfxFloat16x4) -> FfxFloat16x4
{
    return max(x, y);
}

fn ffxMax_i16_i16(x: FfxInt16, y: FfxInt16) -> FfxInt16
{
    return max(x, y);
}

fn ffxMax_i16x2_i16x2(x: FfxInt16x2, y: FfxInt16x2) -> FfxInt16x2
{
    return max(x, y);
}

fn ffxMax_i16x3_i16x3(x: FfxInt16x3, y: FfxInt16x3) -> FfxInt16x3
{
    return max(x, y);
}

fn ffxMax_i16x4_i16x4(x: FfxInt16x4, y: FfxInt16x4) -> FfxInt16x4
{
    return max(x, y);
}

fn ffxMax_u16_u16(x: FfxUInt16, y: FfxUInt16) -> FfxUInt16
{
    return max(x, y);
}

fn ffxMax_u16x2_u16x2(x: FfxUInt16x2, y: FfxUInt16x2) -> FfxUInt16x2
{
    return max(x, y);
}

fn ffxMax_u16x3_u16x3(x: FfxUInt16x3, y: FfxUInt16x3) -> FfxUInt16x3
{
    return max(x, y);
}

fn ffxMax_u16x4_u16x4(x: FfxUInt16x4, y: FfxUInt16x4) -> FfxUInt16x4
{
    return max(x, y);
}

fn ffxPow_f16_f16(x: FfxFloat16, y: FfxFloat16) -> FfxFloat16
{
    return pow(x, y);
}

fn ffxPow_f16x2_f16x2(x: FfxFloat16x2, y: FfxFloat16x2) -> FfxFloat16x2
{
    return pow(x, y);
}

fn ffxPow_f16x3_f16x3(x: FfxFloat16x3, y: FfxFloat16x3) -> FfxFloat16x3
{
    return pow(x, y);
}

fn ffxPow_f16x4_f16x4(x: FfxFloat16x4, y: FfxFloat16x4) -> FfxFloat16x4
{
    return pow(x, y);
}

#endif // #if FFX_HALF

// ---- WGSL: HLSL resource access semantics -----------------------------------
// HLSL Load outside a resource (coordinate or mip) returns zero and a store
// outside it is discarded; WGSL leaves both undefined. SDK accessors test first.

fn ffxWgslOutsideMip(mip: FfxInt32, levels: FfxUInt32) -> FfxBoolean
{
    return mip < 0 || FfxUInt32(mip) >= levels;
}

fn ffxWgslOutside(coordinate: FfxInt32x2, size: FfxUInt32x2) -> FfxBoolean
{
    // | evaluates both tests where || could skip the second: naga emits || as a
    // branch, which costs up to 0.04 ms of a pass at 1920x1080 on Apple M5
    // (SDK-P26).
    return any(coordinate < FfxInt32x2(0)) | any(FfxUInt32x2(coordinate) >= size);
}

// ---- WGSL: HLSL intrinsics absent from WGSL -----------------------------------

// f16tof32 (DXC: UnpackHalf2x16(v).x per component).
fn f16tof32_u32x2(value: FfxUInt32x2) -> FfxFloat32x2
{
    return FfxFloat32x2(unpack2x16float(value.x).x, unpack2x16float(value.y).x);
}

// isinf/isnan by IEEE-754 binary32 classification. Half values widen to
// binary32 exactly, infinities and NaNs included.
fn isinf_f32(x: FfxFloat32) -> FfxBoolean
{
    return (bitcast<FfxUInt32>(x) & 0x7fffffffu) == 0x7f800000u;
}

fn isnan_f32(x: FfxFloat32) -> FfxBoolean
{
    return (bitcast<FfxUInt32>(x) & 0x7fffffffu) > 0x7f800000u;
}

fn isinf_f32x3(x: FfxFloat32x3) -> vec3<bool>
{
    return (bitcast<FfxUInt32x3>(x) & FfxUInt32x3(0x7fffffffu)) == FfxUInt32x3(0x7f800000u);
}

fn isnan_f32x3(x: FfxFloat32x3) -> vec3<bool>
{
    return (bitcast<FfxUInt32x3>(x) & FfxUInt32x3(0x7fffffffu)) > FfxUInt32x3(0x7f800000u);
}

#endif // #ifndef FFX_CORE_H
