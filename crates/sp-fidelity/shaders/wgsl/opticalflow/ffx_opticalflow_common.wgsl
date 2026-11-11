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

// WGSL port of ffx_opticalflow_common.h. WGSL has no msad4 instruction;
// use the SDK's byte-exact scalar fallback (FFX_OPTICALFLOW_USE_MSAD4_INSTRUCTION=0).
#ifndef FFX_OPTICALFLOW_COMMON_H
#define FFX_OPTICALFLOW_COMMON_H
fn GetPackedLuma(width: i32, x: i32, luma0: u32, luma1: u32, luma2: u32, luma3: u32) -> u32 {
    var packedLuma = luma0 | (luma1 << 8u) | (luma2 << 16u) | (luma3 << 24u);
    if (x < 0) {
        let outOfScreenFiller = packedLuma & 0xffu;
        if (x <= -1) { packedLuma = (packedLuma << 8u) | outOfScreenFiller; }
        if (x <= -2) { packedLuma = (packedLuma << 8u) | outOfScreenFiller; }
        if (x <= -3) { packedLuma = (packedLuma << 8u) | outOfScreenFiller; }
    } else if (x > width - 4) {
        let outOfScreenFiller = packedLuma & 0xff000000u;
        if (x >= width - 3) { packedLuma = (packedLuma >> 8u) | outOfScreenFiller; }
        if (x >= width - 2) { packedLuma = (packedLuma >> 8u) | outOfScreenFiller; }
        if (x >= width - 1) { packedLuma = (packedLuma >> 8u) | outOfScreenFiller; }
    }
    return packedLuma;
}
fn Sad(a: u32, b: u32) -> u32 {
    return u32(abs(i32(a & 0xffu) - i32(b & 0xffu)) +
        abs(i32((a >> 8u) & 0xffu) - i32((b >> 8u) & 0xffu)) +
        abs(i32((a >> 16u) & 0xffu) - i32((b >> 16u) & 0xffu)) +
        abs(i32((a >> 24u) & 0xffu) - i32((b >> 24u) & 0xffu)));
}
fn QSad(a0_: u32, a1_: u32, b: u32) -> vec4<u32> {
    var a0 = a0_;
    var a1 = a1_;
    var sad: vec4<u32>;
    sad.x = Sad(a0, b);
    a0 = (a0 >> 8u) | ((a1 & 0xffu) << 24u); a1 >>= 8u;
    sad.y = Sad(a0, b);
    a0 = (a0 >> 8u) | ((a1 & 0xffu) << 24u); a1 >>= 8u;
    sad.z = Sad(a0, b);
    a0 = (a0 >> 8u) | ((a1 & 0xffu) << 24u);
    sad.w = Sad(a0, b);
    return sad;
}
#endif
