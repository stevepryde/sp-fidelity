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

// WGSL port of the corresponding FidelityFX SDK 1.1.4 FSR3 upscaler source.
// Out/inout parameters use function pointers; numeric conversions are explicit.
const s_MipLevelsToUse: FfxInt32 = 3;

struct ShadingChangeLumaInfo
{
    fSamples: array<FfxFloat32, s_MipLevelsToUse>,
}

fn ComputeShadingChangeLuma(iPxPos: FfxInt32x2, fUv: FfxFloat32x2, iCurrentSize: FfxInt32x2) -> ShadingChangeLumaInfo
{
    var info: ShadingChangeLumaInfo ;

    var fMipUv: FfxFloat32x2 = ClampUv(fUv, ShadingChangeRenderSize(), GetSPDMipDimensions(0));

    
    for (var iMipLevel: FfxInt32 = iShadingChangeMipStart; iMipLevel < s_MipLevelsToUse; iMipLevel++) {

        var fSample: FfxFloat32x2 = SampleSPDMipLevel(fMipUv, FfxUInt32(iMipLevel));

        info.fSamples[iMipLevel] = abs(fSample.x * fSample.y);
    }

    return info;
}

fn ShadingChange(iPxPos: FfxInt32x2)
{
    if (IsOnScreen_i32x2_i32x2(FfxInt32x2(iPxPos), ShadingChangeRenderSize())) {

        var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxPos) + 0.5f) / FfxFloat32x2(ShadingChangeRenderSize());
        var fUvJittered: FfxFloat32x2 = fUv + Jitter() / FfxFloat32x2(RenderSize());

        var info: ShadingChangeLumaInfo = ComputeShadingChangeLuma(iPxPos, fUvJittered, ShadingChangeRenderSize());

        var fScale: FfxFloat32 = 1.0f + FfxFloat32(iShadingChangeMipStart / s_MipLevelsToUse);
        var fShadingChange: FfxFloat32 = 0.0f;
        
        for (var iMipLevel: FfxInt32 = iShadingChangeMipStart; iMipLevel < s_MipLevelsToUse; iMipLevel++)
        {
            if (info.fSamples[iMipLevel] > 0) {
                fShadingChange = max(fShadingChange, info.fSamples[iMipLevel]) * fScale;
            }
        }
        
        StoreShadingChange(FfxUInt32x2(iPxPos), ffxSaturate_f32(fShadingChange));
    }
}
