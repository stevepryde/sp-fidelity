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

// WGSL port of ffx_spd.h (FidelityFX Single Pass Downsampler 2.0), GPU part;
// the FFX_CPU ffxSpdSetup is host code. Overloads carry parameter-type suffixes
// (see ffx_core.wgsl).

//==============================================================================================================================
//                                                     NON-PACKED VERSION
//==============================================================================================================================
#if defined(FFX_GPU)
#if defined(FFX_SPD_PACKED_ONLY)
// Avoid compiler errors by including default implementations of these callbacks.
fn SpdLoadSourceImage(p: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    return FfxFloat32x4(0.0, 0.0, 0.0, 0.0);
}

fn SpdLoad(p: FfxInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    return FfxFloat32x4(0.0, 0.0, 0.0, 0.0);
}
fn SpdStore(p: FfxInt32x2, value: FfxFloat32x4, mip: FfxUInt32, slice: FfxUInt32)
{
}
fn SpdLoadIntermediate(x: FfxUInt32, y: FfxUInt32) -> FfxFloat32x4
{
    return FfxFloat32x4(0.0, 0.0, 0.0, 0.0);
}
fn SpdStoreIntermediate(x: FfxUInt32, y: FfxUInt32, value: FfxFloat32x4)
{
}
fn SpdReduce4(v0: FfxFloat32x4, v1: FfxFloat32x4, v2: FfxFloat32x4, v3: FfxFloat32x4) -> FfxFloat32x4
{
    return FfxFloat32x4(0.0, 0.0, 0.0, 0.0);
}
#endif // #if FFX_SPD_PACKED_ONLY

//_____________________________________________________________/\_______________________________________________________________

fn ffxSpdWorkgroupShuffleBarrier()
{
    FFX_GROUP_MEMORY_BARRIER();
}

// Only last active workgroup should proceed
fn SpdExitWorkgroup(numWorkGroups: FfxUInt32, localInvocationIndex: FfxUInt32, slice: FfxUInt32) -> bool
{
    // global atomic counter
    if (localInvocationIndex == 0u)
    {
        SpdIncreaseAtomicCounter(slice);
    }

    ffxSpdWorkgroupShuffleBarrier();
    return (SpdGetAtomicCounter() != (numWorkGroups - 1u));
}

// User defined: FfxFloat32x4 SpdReduce4(FfxFloat32x4 v0, FfxFloat32x4 v1, FfxFloat32x4 v2, FfxFloat32x4 v3);
fn SpdReduceQuad(v: FfxFloat32x4) -> FfxFloat32x4
{
#if !defined(FFX_SPD_NO_WAVE_OPERATIONS)

    // requires SM6.0: QuadReadAcrossX/Y/Diagonal
    let v0: FfxFloat32x4 = v;
    let v1: FfxFloat32x4 = quadSwapX(v);
    let v2: FfxFloat32x4 = quadSwapY(v);
    let v3: FfxFloat32x4 = quadSwapDiagonal(v);
    return SpdReduce4(v0, v1, v2, v3);

#endif
    return v;
}

fn SpdReduceIntermediate(i0: FfxUInt32x2, i1: FfxUInt32x2, i2: FfxUInt32x2, i3: FfxUInt32x2) -> FfxFloat32x4
{
    let v0: FfxFloat32x4 = SpdLoadIntermediate(i0.x, i0.y);
    let v1: FfxFloat32x4 = SpdLoadIntermediate(i1.x, i1.y);
    let v2: FfxFloat32x4 = SpdLoadIntermediate(i2.x, i2.y);
    let v3: FfxFloat32x4 = SpdLoadIntermediate(i3.x, i3.y);
    return SpdReduce4(v0, v1, v2, v3);
}

fn SpdReduceLoad4_u32x2_u32x2_u32x2_u32x2_u32(i0: FfxUInt32x2, i1: FfxUInt32x2, i2: FfxUInt32x2, i3: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    let v0: FfxFloat32x4 = SpdLoad(FfxInt32x2(i0), slice);
    let v1: FfxFloat32x4 = SpdLoad(FfxInt32x2(i1), slice);
    let v2: FfxFloat32x4 = SpdLoad(FfxInt32x2(i2), slice);
    let v3: FfxFloat32x4 = SpdLoad(FfxInt32x2(i3), slice);
    return SpdReduce4(v0, v1, v2, v3);
}

fn SpdReduceLoad4_u32x2_u32(base: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    return SpdReduceLoad4_u32x2_u32x2_u32x2_u32x2_u32(FfxUInt32x2(base + FfxUInt32x2(0u, 0u)), FfxUInt32x2(base + FfxUInt32x2(0u, 1u)), FfxUInt32x2(base + FfxUInt32x2(1u, 0u)), FfxUInt32x2(base + FfxUInt32x2(1u, 1u)), slice);
}

fn SpdReduceLoadSourceImage4(i0: FfxUInt32x2, i1: FfxUInt32x2, i2: FfxUInt32x2, i3: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
    let v0: FfxFloat32x4 = SpdLoadSourceImage(FfxInt32x2(i0), slice);
    let v1: FfxFloat32x4 = SpdLoadSourceImage(FfxInt32x2(i1), slice);
    let v2: FfxFloat32x4 = SpdLoadSourceImage(FfxInt32x2(i2), slice);
    let v3: FfxFloat32x4 = SpdLoadSourceImage(FfxInt32x2(i3), slice);
    return SpdReduce4(v0, v1, v2, v3);
}

fn SpdReduceLoadSourceImage(base: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat32x4
{
#if defined(SPD_LINEAR_SAMPLER)
    return SpdLoadSourceImage(FfxInt32x2(base), slice);
#else
    return SpdReduceLoadSourceImage4(FfxUInt32x2(base + FfxUInt32x2(0u, 0u)), FfxUInt32x2(base + FfxUInt32x2(0u, 1u)), FfxUInt32x2(base + FfxUInt32x2(1u, 0u)), FfxUInt32x2(base + FfxUInt32x2(1u, 1u)), slice);
#endif
}

fn SpdDownsampleMips_0_1_Intrinsics(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
    var v: array<FfxFloat32x4, 4>;

    var tex: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u));
    var pix: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y));
    v[0]     = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[0], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y));
    v[1] = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[1], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y + 16u));
    v[2] = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[2], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y + 16u));
    v[3] = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[3], 0u, slice);

    if (mip <= 1u) {
        return;
    }

    v[0] = SpdReduceQuad(v[0]);
    v[1] = SpdReduceQuad(v[1]);
    v[2] = SpdReduceQuad(v[2]);
    v[3] = SpdReduceQuad(v[3]);

    if ((localInvocationIndex % 4u) == 0u)
    {
        SpdStore(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v[0], 1u, slice);
        SpdStoreIntermediate(x / 2u, y / 2u, v[0]);

        SpdStore(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u + 8u, y / 2u)), v[1], 1u, slice);
        SpdStoreIntermediate(x / 2u + 8u, y / 2u, v[1]);

        SpdStore(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u + 8u)), v[2], 1u, slice);
        SpdStoreIntermediate(x / 2u, y / 2u + 8u, v[2]);

        SpdStore(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u + 8u, y / 2u + 8u)), v[3], 1u, slice);
        SpdStoreIntermediate(x / 2u + 8u, y / 2u + 8u, v[3]);
    }
}

fn SpdDownsampleMips_0_1_LDS(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
    var v: array<FfxFloat32x4, 4>;

    var tex: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u));
    var pix: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y));
    v[0]     = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[0], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y));
    v[1] = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[1], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y + 16u));
    v[2] = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[2], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y + 16u));
    v[3] = SpdReduceLoadSourceImage(FfxUInt32x2(tex), slice);
    SpdStore(pix, v[3], 0u, slice);

    if (mip <= 1u) {
        return;
    }

    for (var i: FfxUInt32 = 0u; i < 4u; i++)
    {
        SpdStoreIntermediate(x, y, v[i]);
        ffxSpdWorkgroupShuffleBarrier();
        if (localInvocationIndex < 64u)
        {
            v[i] = SpdReduceIntermediate(FfxUInt32x2(x * 2u + 0u, y * 2u + 0u), FfxUInt32x2(x * 2u + 1u, y * 2u + 0u), FfxUInt32x2(x * 2u + 0u, y * 2u + 1u), FfxUInt32x2(x * 2u + 1u, y * 2u + 1u));
            SpdStore(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x + (i % 2u) * 8u, y + (i / 2u) * 8u)), v[i], 1u, slice);
        }
        ffxSpdWorkgroupShuffleBarrier();
    }

    if (localInvocationIndex < 64u)
    {
        SpdStoreIntermediate(x + 0u, y + 0u, v[0]);
        SpdStoreIntermediate(x + 8u, y + 0u, v[1]);
        SpdStoreIntermediate(x + 0u, y + 8u, v[2]);
        SpdStoreIntermediate(x + 8u, y + 8u, v[3]);
    }
}

fn SpdDownsampleMips_0_1(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    SpdDownsampleMips_0_1_LDS(x, y, workGroupID, localInvocationIndex, mip, slice);
#else
    SpdDownsampleMips_0_1_Intrinsics(x, y, workGroupID, localInvocationIndex, mip, slice);
#endif
}


fn SpdDownsampleMip_2(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 64u)
    {
        let v: FfxFloat32x4 = SpdReduceIntermediate(FfxUInt32x2(x * 2u + 0u, y * 2u + 0u), FfxUInt32x2(x * 2u + 1u, y * 2u + 0u), FfxUInt32x2(x * 2u + 0u, y * 2u + 1u), FfxUInt32x2(x * 2u + 1u, y * 2u + 1u));
        SpdStore(FfxInt32x2(workGroupID.xy * 8u) + FfxInt32x2(FfxUInt32x2(x, y)), v, mip, slice);
        // store to LDS, try to reduce bank conflicts
        // x 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0 x
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // x 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0
        // ...
        // x 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0
        SpdStoreIntermediate(x * 2u + y % 2u, y * 2u, v);
    }
#else
    var v: FfxFloat32x4 = SpdLoadIntermediate(x, y);
    v        = SpdReduceQuad(v);
    // quad index 0 stores result
    if (localInvocationIndex % 4u == 0u)
    {
        SpdStore(FfxInt32x2(workGroupID.xy * 8u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v, mip, slice);
        SpdStoreIntermediate(x + (y / 2u) % 2u, y, v);
    }
#endif
}

fn SpdDownsampleMip_3(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 16u)
    {
        // x 0 x 0
        // 0 0 0 0
        // 0 x 0 x
        // 0 0 0 0
        let v: FfxFloat32x4 =
            SpdReduceIntermediate(FfxUInt32x2(x * 4u + 0u + 0u, y * 4u + 0u), FfxUInt32x2(x * 4u + 2u + 0u, y * 4u + 0u), FfxUInt32x2(x * 4u + 0u + 1u, y * 4u + 2u), FfxUInt32x2(x * 4u + 2u + 1u, y * 4u + 2u));
        SpdStore(FfxInt32x2(workGroupID.xy * 4u) + FfxInt32x2(FfxUInt32x2(x, y)), v, mip, slice);
        // store to LDS
        // x 0 0 0 x 0 0 0 x 0 0 0 x 0 0 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 x 0 0 0 x 0 0 0 x 0 0 0 x 0 0
        // ...
        // 0 0 x 0 0 0 x 0 0 0 x 0 0 0 x 0
        // ...
        // 0 0 0 x 0 0 0 x 0 0 0 x 0 0 0 x
        // ...
        SpdStoreIntermediate(x * 4u + y, y * 4u, v);
    }
#else
    if (localInvocationIndex < 64u)
    {
        var v: FfxFloat32x4 = SpdLoadIntermediate(x * 2u + y % 2u, y * 2u);
        v        = SpdReduceQuad(v);
        // quad index 0 stores result
        if (localInvocationIndex % 4u == 0u)
        {
            SpdStore(FfxInt32x2(workGroupID.xy * 4u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v, mip, slice);
            SpdStoreIntermediate(x * 2u + y / 2u, y * 2u, v);
        }
    }
#endif
}

fn SpdDownsampleMip_4(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 4u)
    {
        // x 0 0 0 x 0 0 0
        // ...
        // 0 x 0 0 0 x 0 0
        let v: FfxFloat32x4 = SpdReduceIntermediate(FfxUInt32x2(x * 8u + 0u + 0u + y * 2u, y * 8u + 0u),
                                         FfxUInt32x2(x * 8u + 4u + 0u + y * 2u, y * 8u + 0u),
                                         FfxUInt32x2(x * 8u + 0u + 1u + y * 2u, y * 8u + 4u),
                                         FfxUInt32x2(x * 8u + 4u + 1u + y * 2u, y * 8u + 4u));
        SpdStore(FfxInt32x2(workGroupID.xy * 2u) + FfxInt32x2(FfxUInt32x2(x, y)), v, mip, slice);
        // store to LDS
        // x x x x 0 ...
        // 0 ...
        SpdStoreIntermediate(x + y * 2u, 0u, v);
    }
#else
    if (localInvocationIndex < 16u)
    {
        var v: FfxFloat32x4 = SpdLoadIntermediate(x * 4u + y, y * 4u);
        v        = SpdReduceQuad(v);
        // quad index 0 stores result
        if (localInvocationIndex % 4u == 0u)
        {
            SpdStore(FfxInt32x2(workGroupID.xy * 2u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v, mip, slice);
            SpdStoreIntermediate(x / 2u + y, 0u, v);
        }
    }
#endif
}

fn SpdDownsampleMip_5(workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 1u)
    {
        // x x x x 0 ...
        // 0 ...
        let v: FfxFloat32x4 = SpdReduceIntermediate(FfxUInt32x2(0u, 0u), FfxUInt32x2(1u, 0u), FfxUInt32x2(2u, 0u), FfxUInt32x2(3u, 0u));
        SpdStore(FfxInt32x2(workGroupID.xy), v, mip, slice);
    }
#else
    if (localInvocationIndex < 4u)
    {
        var v: FfxFloat32x4 = SpdLoadIntermediate(localInvocationIndex, 0u);
        v        = SpdReduceQuad(v);
        // quad index 0 stores result
        if (localInvocationIndex % 4u == 0u)
        {
            SpdStore(FfxInt32x2(workGroupID.xy), v, mip, slice);
        }
    }
#endif
}

fn SpdDownsampleMips_6_7(x: FfxUInt32, y: FfxUInt32, mips: FfxUInt32, slice: FfxUInt32)
{
    var tex: FfxInt32x2 = FfxInt32x2(FfxUInt32x2(x * 4u + 0u, y * 4u + 0u));
    var pix: FfxInt32x2 = FfxInt32x2(FfxUInt32x2(x * 2u + 0u, y * 2u + 0u));
    let v0: FfxFloat32x4  = SpdReduceLoad4_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStore(pix, v0, 6u, slice);

    tex       = FfxInt32x2(FfxUInt32x2(x * 4u + 2u, y * 4u + 0u));
    pix       = FfxInt32x2(FfxUInt32x2(x * 2u + 1u, y * 2u + 0u));
    let v1: FfxFloat32x4 = SpdReduceLoad4_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStore(pix, v1, 6u, slice);

    tex       = FfxInt32x2(FfxUInt32x2(x * 4u + 0u, y * 4u + 2u));
    pix       = FfxInt32x2(FfxUInt32x2(x * 2u + 0u, y * 2u + 1u));
    let v2: FfxFloat32x4 = SpdReduceLoad4_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStore(pix, v2, 6u, slice);

    tex       = FfxInt32x2(FfxUInt32x2(x * 4u + 2u, y * 4u + 2u));
    pix       = FfxInt32x2(FfxUInt32x2(x * 2u + 1u, y * 2u + 1u));
    let v3: FfxFloat32x4 = SpdReduceLoad4_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStore(pix, v3, 6u, slice);

    if (mips <= 7u) {
        return;
    }
    // no barrier needed, working on values only from the same thread

    let v: FfxFloat32x4 = SpdReduce4(v0, v1, v2, v3);
    SpdStore(FfxInt32x2(FfxUInt32x2(x, y)), v, 7u, slice);
    SpdStoreIntermediate(x, y, v);
}

fn SpdDownsampleNextFour(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, baseMip: FfxUInt32, mips: FfxUInt32, slice: FfxUInt32)
{
    if (mips <= baseMip) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_2(x, y, workGroupID, localInvocationIndex, baseMip, slice);

    if (mips <= baseMip + 1u) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_3(x, y, workGroupID, localInvocationIndex, baseMip + 1u, slice);

    if (mips <= baseMip + 2u) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_4(x, y, workGroupID, localInvocationIndex, baseMip + 2u, slice);

    if (mips <= baseMip + 3u) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_5(workGroupID, localInvocationIndex, baseMip + 3u, slice);
}

/// Downsamples a 64x64 tile based on the work group id.
/// If after downsampling it's the last active thread group, computes the remaining MIP levels.
///
/// @param [in] workGroupID             index of the work group / thread group
/// @param [in] localInvocationIndex    index of the thread within the thread group in 1D
/// @param [in] mips                    the number of total MIP levels to compute for the input texture
/// @param [in] numWorkGroups           the total number of dispatched work groups / thread groups for this slice
/// @param [in] slice                   the slice of the input texture
fn SpdDownsample_u32x2_u32_u32_u32_u32(workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mips: FfxUInt32, numWorkGroups: FfxUInt32, slice: FfxUInt32)
{
    // compute MIP level 0 and 1
    let sub_xy: FfxUInt32x2 = ffxRemapForWaveReduction(localInvocationIndex % 64u);
    let x: FfxUInt32      = sub_xy.x + 8u * ((localInvocationIndex >> 6u) % 2u);
    let y: FfxUInt32      = sub_xy.y + 8u * ((localInvocationIndex >> 7u));
    SpdDownsampleMips_0_1(x, y, workGroupID, localInvocationIndex, mips, slice);

    // compute MIP level 2, 3, 4, 5
    SpdDownsampleNextFour(x, y, workGroupID, localInvocationIndex, 2u, mips, slice);

    if (mips <= 6u) {
        return;
    }

    // increase the global atomic counter for the given slice and check if it's the last remaining thread group:
    // terminate if not, continue if yes.
    if (SpdExitWorkgroup(numWorkGroups, localInvocationIndex, slice)) {
        return;
    }

    // reset the global atomic counter back to 0 for the next spd dispatch
    SpdResetAtomicCounter(slice);

    // After mip 5 there is only a single workgroup left that downsamples the remaining up to 64x64 texels.
    // compute MIP level 6 and 7
    SpdDownsampleMips_6_7(x, y, mips, slice);

    // compute MIP level 8, 9, 10, 11
    SpdDownsampleNextFour(x, y, FfxUInt32x2(0u, 0u), localInvocationIndex, 8u, mips, slice);
}
/// Downsamples a 64x64 tile based on the work group id and work group offset.
/// If after downsampling it's the last active thread group, computes the remaining MIP levels.
///
/// @param [in] workGroupOffset         the work group offset. it's (0,0) in case the entire input texture is downsampled.
fn SpdDownsample_u32x2_u32_u32_u32_u32_u32x2(workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mips: FfxUInt32, numWorkGroups: FfxUInt32, slice: FfxUInt32, workGroupOffset: FfxUInt32x2)
{
    SpdDownsample_u32x2_u32_u32_u32_u32(workGroupID + workGroupOffset, localInvocationIndex, mips, numWorkGroups, slice);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//==============================================================================================================================
//                                                       PACKED VERSION
//==============================================================================================================================

#if FFX_HALF

fn SpdReduceQuadH(v: FfxFloat16x4) -> FfxFloat16x4
{
#if !defined(FFX_SPD_NO_WAVE_OPERATIONS)
    // requires SM6.0: QuadReadAcrossX/Y/Diagonal
    let v0: FfxFloat16x4 = v;
    let v1: FfxFloat16x4 = quadSwapX(v);
    let v2: FfxFloat16x4 = quadSwapY(v);
    let v3: FfxFloat16x4 = quadSwapDiagonal(v);
    return SpdReduce4H(v0, v1, v2, v3);
#endif
    return FfxFloat16x4(0.0h, 0.0h, 0.0h, 0.0h);
}

fn SpdReduceIntermediateH(i0: FfxUInt32x2, i1: FfxUInt32x2, i2: FfxUInt32x2, i3: FfxUInt32x2) -> FfxFloat16x4
{
    let v0: FfxFloat16x4 = SpdLoadIntermediateH(i0.x, i0.y);
    let v1: FfxFloat16x4 = SpdLoadIntermediateH(i1.x, i1.y);
    let v2: FfxFloat16x4 = SpdLoadIntermediateH(i2.x, i2.y);
    let v3: FfxFloat16x4 = SpdLoadIntermediateH(i3.x, i3.y);
    return SpdReduce4H(v0, v1, v2, v3);
}

fn SpdReduceLoad4H_u32x2_u32x2_u32x2_u32x2_u32(i0: FfxUInt32x2, i1: FfxUInt32x2, i2: FfxUInt32x2, i3: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat16x4
{
    let v0: FfxFloat16x4 = SpdLoadH(FfxInt32x2(i0), slice);
    let v1: FfxFloat16x4 = SpdLoadH(FfxInt32x2(i1), slice);
    let v2: FfxFloat16x4 = SpdLoadH(FfxInt32x2(i2), slice);
    let v3: FfxFloat16x4 = SpdLoadH(FfxInt32x2(i3), slice);
    return SpdReduce4H(v0, v1, v2, v3);
}

fn SpdReduceLoad4H_u32x2_u32(base: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat16x4
{
    return SpdReduceLoad4H_u32x2_u32x2_u32x2_u32x2_u32(FfxUInt32x2(base + FfxUInt32x2(0u, 0u)), FfxUInt32x2(base + FfxUInt32x2(0u, 1u)), FfxUInt32x2(base + FfxUInt32x2(1u, 0u)), FfxUInt32x2(base + FfxUInt32x2(1u, 1u)), slice);
}

fn SpdReduceLoadSourceImage4H(i0: FfxUInt32x2, i1: FfxUInt32x2, i2: FfxUInt32x2, i3: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat16x4
{
    let v0: FfxFloat16x4 = SpdLoadSourceImageH(FfxInt32x2(i0), slice);
    let v1: FfxFloat16x4 = SpdLoadSourceImageH(FfxInt32x2(i1), slice);
    let v2: FfxFloat16x4 = SpdLoadSourceImageH(FfxInt32x2(i2), slice);
    let v3: FfxFloat16x4 = SpdLoadSourceImageH(FfxInt32x2(i3), slice);
    return SpdReduce4H(v0, v1, v2, v3);
}

fn SpdReduceLoadSourceImageH(base: FfxUInt32x2, slice: FfxUInt32) -> FfxFloat16x4
{
#if defined(SPD_LINEAR_SAMPLER)
    return SpdLoadSourceImageH(FfxInt32x2(base), slice);
#else
    return SpdReduceLoadSourceImage4H(FfxUInt32x2(base + FfxUInt32x2(0u, 0u)), FfxUInt32x2(base + FfxUInt32x2(0u, 1u)), FfxUInt32x2(base + FfxUInt32x2(1u, 0u)), FfxUInt32x2(base + FfxUInt32x2(1u, 1u)), slice);
#endif
}

fn SpdDownsampleMips_0_1_IntrinsicsH(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mips: FfxUInt32, slice: FfxUInt32)
{
    var v: array<FfxFloat16x4, 4>;

    var tex: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u));
    var pix: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y));
    v[0]     = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[0], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y));
    v[1] = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[1], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y + 16u));
    v[2] = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[2], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y + 16u));
    v[3] = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[3], 0u, slice);

    if (mips <= 1u) {
        return;
    }

    v[0] = SpdReduceQuadH(v[0]);
    v[1] = SpdReduceQuadH(v[1]);
    v[2] = SpdReduceQuadH(v[2]);
    v[3] = SpdReduceQuadH(v[3]);

    if ((localInvocationIndex % 4u) == 0u)
    {
        SpdStoreH(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v[0], 1u, slice);
        SpdStoreIntermediateH(x / 2u, y / 2u, v[0]);

        SpdStoreH(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u + 8u, y / 2u)), v[1], 1u, slice);
        SpdStoreIntermediateH(x / 2u + 8u, y / 2u, v[1]);

        SpdStoreH(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u + 8u)), v[2], 1u, slice);
        SpdStoreIntermediateH(x / 2u, y / 2u + 8u, v[2]);

        SpdStoreH(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x / 2u + 8u, y / 2u + 8u)), v[3], 1u, slice);
        SpdStoreIntermediateH(x / 2u + 8u, y / 2u + 8u, v[3]);
    }
}

fn SpdDownsampleMips_0_1_LDSH(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mips: FfxUInt32, slice: FfxUInt32)
{
    var v: array<FfxFloat16x4, 4>;

    var tex: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u));
    var pix: FfxInt32x2 = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y));
    v[0]     = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[0], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y));
    v[1] = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[1], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x, y + 16u));
    v[2] = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[2], 0u, slice);

    tex  = FfxInt32x2(workGroupID.xy * 64u) + FfxInt32x2(FfxUInt32x2(x * 2u + 32u, y * 2u + 32u));
    pix  = FfxInt32x2(workGroupID.xy * 32u) + FfxInt32x2(FfxUInt32x2(x + 16u, y + 16u));
    v[3] = SpdReduceLoadSourceImageH(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v[3], 0u, slice);

    if (mips <= 1u) {
        return;
    }

    for (var i: FfxInt32 = 0; i < 4; i++)
    {
        SpdStoreIntermediateH(x, y, v[i]);
        ffxSpdWorkgroupShuffleBarrier();
        if (localInvocationIndex < 64u)
        {
            v[i] = SpdReduceIntermediateH(FfxUInt32x2(x * 2u + 0u, y * 2u + 0u), FfxUInt32x2(x * 2u + 1u, y * 2u + 0u), FfxUInt32x2(x * 2u + 0u, y * 2u + 1u), FfxUInt32x2(x * 2u + 1u, y * 2u + 1u));
            SpdStoreH(FfxInt32x2(workGroupID.xy * 16u) + FfxInt32x2(FfxUInt32x2(x + FfxUInt32((i % 2) * 8), y + FfxUInt32((i / 2) * 8))), v[i], 1u, slice);
        }
        ffxSpdWorkgroupShuffleBarrier();
    }

    if (localInvocationIndex < 64u)
    {
        SpdStoreIntermediateH(x + 0u, y + 0u, v[0]);
        SpdStoreIntermediateH(x + 8u, y + 0u, v[1]);
        SpdStoreIntermediateH(x + 0u, y + 8u, v[2]);
        SpdStoreIntermediateH(x + 8u, y + 8u, v[3]);
    }
}

fn SpdDownsampleMips_0_1H(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mips: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    SpdDownsampleMips_0_1_LDSH(x, y, workGroupID, localInvocationIndex, mips, slice);
#else
    SpdDownsampleMips_0_1_IntrinsicsH(x, y, workGroupID, localInvocationIndex, mips, slice);
#endif
}


fn SpdDownsampleMip_2H(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 64u)
    {
        let v: FfxFloat16x4 = SpdReduceIntermediateH(FfxUInt32x2(x * 2u + 0u, y * 2u + 0u), FfxUInt32x2(x * 2u + 1u, y * 2u + 0u), FfxUInt32x2(x * 2u + 0u, y * 2u + 1u), FfxUInt32x2(x * 2u + 1u, y * 2u + 1u));
        SpdStoreH(FfxInt32x2(workGroupID.xy * 8u) + FfxInt32x2(FfxUInt32x2(x, y)), v, mip, slice);
        // store to LDS, try to reduce bank conflicts
        // x 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0 x
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // x 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0
        // ...
        // x 0 x 0 x 0 x 0 x 0 x 0 x 0 x 0
        SpdStoreIntermediateH(x * 2u + y % 2u, y * 2u, v);
    }
#else
    var v: FfxFloat16x4 = SpdLoadIntermediateH(x, y);
    v     = SpdReduceQuadH(v);
    // quad index 0 stores result
    if (localInvocationIndex % 4u == 0u)
    {
        SpdStoreH(FfxInt32x2(workGroupID.xy * 8u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v, mip, slice);
        SpdStoreIntermediateH(x + (y / 2u) % 2u, y, v);
    }
#endif
}

fn SpdDownsampleMip_3H(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 16u)
    {
        // x 0 x 0
        // 0 0 0 0
        // 0 x 0 x
        // 0 0 0 0
        let v: FfxFloat16x4 =
            SpdReduceIntermediateH(FfxUInt32x2(x * 4u + 0u + 0u, y * 4u + 0u), FfxUInt32x2(x * 4u + 2u + 0u, y * 4u + 0u), FfxUInt32x2(x * 4u + 0u + 1u, y * 4u + 2u), FfxUInt32x2(x * 4u + 2u + 1u, y * 4u + 2u));
        SpdStoreH(FfxInt32x2(workGroupID.xy * 4u) + FfxInt32x2(FfxUInt32x2(x, y)), v, mip, slice);
        // store to LDS
        // x 0 0 0 x 0 0 0 x 0 0 0 x 0 0 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
        // 0 x 0 0 0 x 0 0 0 x 0 0 0 x 0 0
        // ...
        // 0 0 x 0 0 0 x 0 0 0 x 0 0 0 x 0
        // ...
        // 0 0 0 x 0 0 0 x 0 0 0 x 0 0 0 x
        // ...
        SpdStoreIntermediateH(x * 4u + y, y * 4u, v);
    }
#else
    if (localInvocationIndex < 64u)
    {
        var v: FfxFloat16x4 = SpdLoadIntermediateH(x * 2u + y % 2u, y * 2u);
        v     = SpdReduceQuadH(v);
        // quad index 0 stores result
        if (localInvocationIndex % 4u == 0u)
        {
            SpdStoreH(FfxInt32x2(workGroupID.xy * 4u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v, mip, slice);
            SpdStoreIntermediateH(x * 2u + y / 2u, y * 2u, v);
        }
    }
#endif
}

fn SpdDownsampleMip_4H(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 4u)
    {
        // x 0 0 0 x 0 0 0
        // ...
        // 0 x 0 0 0 x 0 0
        let v: FfxFloat16x4 = SpdReduceIntermediateH(FfxUInt32x2(x * 8u + 0u + 0u + y * 2u, y * 8u + 0u),
                                       FfxUInt32x2(x * 8u + 4u + 0u + y * 2u, y * 8u + 0u),
                                       FfxUInt32x2(x * 8u + 0u + 1u + y * 2u, y * 8u + 4u),
                                       FfxUInt32x2(x * 8u + 4u + 1u + y * 2u, y * 8u + 4u));
        SpdStoreH(FfxInt32x2(workGroupID.xy * 2u) + FfxInt32x2(FfxUInt32x2(x, y)), v, mip, slice);
        // store to LDS
        // x x x x 0 ...
        // 0 ...
        SpdStoreIntermediateH(x + y * 2u, 0u, v);
    }
#else
    if (localInvocationIndex < 16u)
    {
        var v: FfxFloat16x4 = SpdLoadIntermediateH(x * 4u + y, y * 4u);
        v     = SpdReduceQuadH(v);
        // quad index 0 stores result
        if (localInvocationIndex % 4u == 0u)
        {
            SpdStoreH(FfxInt32x2(workGroupID.xy * 2u) + FfxInt32x2(FfxUInt32x2(x / 2u, y / 2u)), v, mip, slice);
            SpdStoreIntermediateH(x / 2u + y, 0u, v);
        }
    }
#endif
}

fn SpdDownsampleMip_5H(workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mip: FfxUInt32, slice: FfxUInt32)
{
#if defined(FFX_SPD_NO_WAVE_OPERATIONS)
    if (localInvocationIndex < 1u)
    {
        // x x x x 0 ...
        // 0 ...
        let v: FfxFloat16x4 = SpdReduceIntermediateH(FfxUInt32x2(0u, 0u), FfxUInt32x2(1u, 0u), FfxUInt32x2(2u, 0u), FfxUInt32x2(3u, 0u));
        SpdStoreH(FfxInt32x2(workGroupID.xy), v, mip, slice);
    }
#else
    if (localInvocationIndex < 4u)
    {
        var v: FfxFloat16x4 = SpdLoadIntermediateH(localInvocationIndex, 0u);
        v     = SpdReduceQuadH(v);
        // quad index 0 stores result
        if (localInvocationIndex % 4u == 0u)
        {
            SpdStoreH(FfxInt32x2(workGroupID.xy), v, mip, slice);
        }
    }
#endif
}

fn SpdDownsampleMips_6_7H(x: FfxUInt32, y: FfxUInt32, mips: FfxUInt32, slice: FfxUInt32)
{
    var tex: FfxInt32x2 = FfxInt32x2(FfxUInt32x2(x * 4u + 0u, y * 4u + 0u));
    var pix: FfxInt32x2 = FfxInt32x2(FfxUInt32x2(x * 2u + 0u, y * 2u + 0u));
    let v0: FfxFloat16x4  = SpdReduceLoad4H_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v0, 6u, slice);

    tex    = FfxInt32x2(FfxUInt32x2(x * 4u + 2u, y * 4u + 0u));
    pix    = FfxInt32x2(FfxUInt32x2(x * 2u + 1u, y * 2u + 0u));
    let v1: FfxFloat16x4 = SpdReduceLoad4H_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v1, 6u, slice);

    tex    = FfxInt32x2(FfxUInt32x2(x * 4u + 0u, y * 4u + 2u));
    pix    = FfxInt32x2(FfxUInt32x2(x * 2u + 0u, y * 2u + 1u));
    let v2: FfxFloat16x4 = SpdReduceLoad4H_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v2, 6u, slice);

    tex    = FfxInt32x2(FfxUInt32x2(x * 4u + 2u, y * 4u + 2u));
    pix    = FfxInt32x2(FfxUInt32x2(x * 2u + 1u, y * 2u + 1u));
    let v3: FfxFloat16x4 = SpdReduceLoad4H_u32x2_u32(FfxUInt32x2(tex), slice);
    SpdStoreH(pix, v3, 6u, slice);

    if (mips < 8u) {
        return;
    }
    // no barrier needed, working on values only from the same thread

    let v: FfxFloat16x4 = SpdReduce4H(v0, v1, v2, v3);
    SpdStoreH(FfxInt32x2(FfxUInt32x2(x, y)), v, 7u, slice);
    SpdStoreIntermediateH(x, y, v);
}

fn SpdDownsampleNextFourH(x: FfxUInt32, y: FfxUInt32, workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, baseMip: FfxUInt32, mips: FfxUInt32, slice: FfxUInt32)
{
    if (mips <= baseMip) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_2H(x, y, workGroupID, localInvocationIndex, baseMip, slice);

    if (mips <= baseMip + 1u) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_3H(x, y, workGroupID, localInvocationIndex, baseMip + 1u, slice);

    if (mips <= baseMip + 2u) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_4H(x, y, workGroupID, localInvocationIndex, baseMip + 2u, slice);

    if (mips <= baseMip + 3u) {
        return;
    }
    ffxSpdWorkgroupShuffleBarrier();
    SpdDownsampleMip_5H(workGroupID, localInvocationIndex, baseMip + 3u, slice);
}

/// Downsamples a 64x64 tile based on the work group id and work group offset.
/// If after downsampling it's the last active thread group, computes the remaining MIP levels.
/// Uses half types.
fn SpdDownsampleH_u32x2_u32_u32_u32_u32(workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mips: FfxUInt32, numWorkGroups: FfxUInt32, slice: FfxUInt32)
{
    let sub_xy: FfxUInt32x2 = ffxRemapForWaveReduction(localInvocationIndex % 64u);
    let x: FfxUInt32      = sub_xy.x + 8u * ((localInvocationIndex >> 6u) % 2u);
    let y: FfxUInt32      = sub_xy.y + 8u * ((localInvocationIndex >> 7u));

    // compute MIP level 0 and 1
    SpdDownsampleMips_0_1H(x, y, workGroupID, localInvocationIndex, mips, slice);

    // compute MIP level 2, 3, 4, 5
    SpdDownsampleNextFourH(x, y, workGroupID, localInvocationIndex, 2u, mips, slice);

    if (mips < 7u) {
        return;
    }

    // increase the global atomic counter for the given slice and check if it's the last remaining thread group:
    // terminate if not, continue if yes.
    if (SpdExitWorkgroup(numWorkGroups, localInvocationIndex, slice)) {
        return;
    }

    // reset the global atomic counter back to 0 for the next spd dispatch
    SpdResetAtomicCounter(slice);

    // After mip 5 there is only a single workgroup left that downsamples the remaining up to 64x64 texels.
    // compute MIP level 6 and 7
    SpdDownsampleMips_6_7H(x, y, mips, slice);

    // compute MIP level 8, 9, 10, 11
    SpdDownsampleNextFourH(x, y, FfxUInt32x2(0u, 0u), localInvocationIndex, 8u, mips, slice);
}

/// Uses half types, with a work group offset.
fn SpdDownsampleH_u32x2_u32_u32_u32_u32_u32x2(workGroupID: FfxUInt32x2, localInvocationIndex: FfxUInt32, mips: FfxUInt32, numWorkGroups: FfxUInt32, slice: FfxUInt32, workGroupOffset: FfxUInt32x2)
{
    SpdDownsampleH_u32x2_u32_u32_u32_u32(workGroupID + workGroupOffset, localInvocationIndex, mips, numWorkGroups, slice);
}

#endif // #if FFX_HALF
#endif // #if defined(FFX_GPU)
