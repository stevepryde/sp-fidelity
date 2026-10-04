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

// WGSL port of ffx_fsr2_rcas.h.

#define GROUP_SIZE  8
#define FSR_RCAS_DENOISE 1

#include "ffx_core.wgsl"

#if FFX_HALF && defined(__XBOX_SCARLETT) && defined(__XBATG_EXTRA_16_BIT_OPTIMISATION) && (__XBATG_EXTRA_16_BIT_OPTIMISATION == 1)
    #define FSR_RCAS_PREFER_PAIRED_VERSION 1
#else
    #define FSR_RCAS_PREFER_PAIRED_VERSION 0
#endif

fn WriteUpscaledOutput(iPxHrPos: FFX_MIN16_U2, fUpscaledColor: FfxFloat32x3)
{
    StoreUpscaledOutput(FfxUInt32x2(FFX_MIN16_I2(iPxHrPos)), fUpscaledColor);
}

#if FSR_RCAS_PREFER_PAIRED_VERSION
    // FSR_RCAS_HX2 (FsrRcasLoadHx2, FsrRcasInputHx2, CurrFilterPaired): Xbox
    // only (__XBOX_SCARLETT), never compiled here.
#else
    #define FSR_RCAS_F 1
    fn FsrRcasLoadF(p: FfxInt32x2) -> FfxFloat32x4
    {
        var fColor: FfxFloat32x4 = LoadRCAS_Input(p);

        // WGSL: no assignment to a multi-component swizzle (fColor.rgb = ...).
        fColor = FfxFloat32x4(PrepareRgb(fColor.rgb, Exposure(), PreExposure()), fColor.a);

        return fColor;
    }
    fn FsrRcasInputF(r: ptr<function, FfxFloat32>, g: ptr<function, FfxFloat32>, b: ptr<function, FfxFloat32>) {}

    #include "fsr1/ffx_fsr1.wgsl"

    fn CurrFilter(pos: FFX_MIN16_U2)
    {
        var c: FfxFloat32x3;
        // WGSL: a vector component has no address; FsrRcasF writes c.r, c.g
        // and c.b through locals.
        var cR: FfxFloat32;
        var cG: FfxFloat32;
        var cB: FfxFloat32;
        FsrRcasF(&cR, &cG, &cB, pos, RCASConfig());
        c = FfxFloat32x3(cR, cG, cB);

        c = UnprepareRgb(c, Exposure());

        WriteUpscaledOutput(pos, c);
    }

#endif // #if FSR_RCAS_PREFER_PAIRED_VERSION

fn RCAS(LocalThreadId: FfxUInt32x3, WorkGroupId: FfxUInt32x3, Dtid: FfxUInt32x3)
{
    // Do remapping of local xy in workgroup for a more PS-like swizzle pattern.
    var gxy: FfxUInt32x2 = ffxRemapForQuad(LocalThreadId.x) + FfxUInt32x2(WorkGroupId.x << 4u, WorkGroupId.y << 4u);
#if FSR_RCAS_PREFER_PAIRED_VERSION
    // CurrFilterPaired: Xbox only, as above.
#else
    CurrFilter(FFX_MIN16_U2(gxy));
    gxy.x += 8u;
    CurrFilter(FFX_MIN16_U2(gxy));
    gxy.y += 8u;
    CurrFilter(FFX_MIN16_U2(gxy));
    gxy.x -= 8u;
    CurrFilter(FFX_MIN16_U2(gxy));
#endif
}
