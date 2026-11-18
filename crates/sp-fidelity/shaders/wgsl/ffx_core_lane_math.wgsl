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

// Lane remapping from ffx_core_gpu_common.h and IEEE-754 classification for
// HLSL's isinf/isnan. Also used by the reflections denoiser on core WebGPU.
fn ffxBitfieldExtract(src: u32, off: u32, bits: u32) -> u32
{
    let mask: u32 = (1u << bits) - 1u;
    return (src >> off) & mask;
}

fn ffxBitfieldInsertMask(src: u32, ins: u32, bits: u32) -> u32
{
    let mask: u32 = (1u << bits) - 1u;
    return (ins & mask) | (src & (~mask));
}

fn ffxRemapForWaveReduction(a: u32) -> vec2u
{
    return vec2u(ffxBitfieldInsertMask(ffxBitfieldExtract(a, 2u, 3u), a, 1u), ffxBitfieldInsertMask(ffxBitfieldExtract(a, 3u, 3u), ffxBitfieldExtract(a, 1u, 2u), 2u));
}

fn isinf_f32(x: f32) -> bool
{
    return (bitcast<u32>(x) & 0x7fffffffu) == 0x7f800000u;
}

fn isnan_f32(x: f32) -> bool
{
    return (bitcast<u32>(x) & 0x7fffffffu) > 0x7f800000u;
}

fn isinf_f32x3(x: vec3f) -> vec3<bool>
{
    return (bitcast<vec3u>(x) & vec3u(0x7fffffffu)) == vec3u(0x7f800000u);
}

fn isnan_f32x3(x: vec3f) -> vec3<bool>
{
    return (bitcast<vec3u>(x) & vec3u(0x7fffffffu)) > vec3u(0x7f800000u);
}
