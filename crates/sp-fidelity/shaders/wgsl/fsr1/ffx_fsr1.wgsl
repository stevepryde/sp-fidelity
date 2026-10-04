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

// WGSL port of fsr1/ffx_fsr1.h: the [RCAS] section, which FSR2's
// ffx_fsr2_rcas.h uses. EASU, LFGA, SRTM and TEPD are not ported; FSR2 uses
// none of them. Overloads carry parameter-type suffixes (see ffx_core.wgsl).

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//
//                                      FSR - [RCAS] ROBUST CONTRAST ADAPTIVE SHARPENING
//
//------------------------------------------------------------------------------------------------------------------------------
// (See ffx_fsr1.h for the description of RCAS, its callbacks and its defines.)
//==============================================================================================================================
// This is set at the limit of providing unnatural results for sharpening.
#define FSR_RCAS_LIMIT (0.25-(1.0/16.0))
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//                                                      CONSTANT SETUP
//==============================================================================================================================
// Call to setup required constant values (works on CPU or GPU).
// WGSL: the SDK's GPU FsrRcasCon writes its by-value con, which the caller
// never sees; the port keeps that.
fn FsrRcasCon(con_: FfxUInt32x4,
              // The scale is {0.0 := maximum, to N>0, where N is the number of stops (halving) of the reduction of sharpness}.
              sharpness_: FfxFloat32)
{
    var con: FfxUInt32x4 = con_;
    var sharpness: FfxFloat32 = sharpness_;
    // Transform from stops to linear value.
    sharpness = exp2(-sharpness);
    let hSharp: FfxFloat32x2 = FfxFloat32x2(sharpness, sharpness);
    con[0] = ffxAsUInt32_f32(sharpness);
    con[1] = ffxPackHalf2x16(hSharp);
    con[2] = 0u;
    con[3] = 0u;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//_____________________________________________________________/\_______________________________________________________________
//==============================================================================================================================
//                                                   NON-PACKED 32-BIT VERSION
//==============================================================================================================================
#if defined(FFX_GPU)&&defined(FSR_RCAS_F)
// Input callback prototypes that need to be implemented by calling shader
// FfxFloat32x4 FsrRcasLoadF(FfxInt32x2 p);
// void FsrRcasInputF(inout FfxFloat32 r,inout FfxFloat32 g,inout FfxFloat32 b);
// WGSL: declared by the including module before its #include.
//------------------------------------------------------------------------------------------------------------------------------
fn FsrRcasF(pixR: ptr<function, FfxFloat32>,  // Output values, non-vector so port between RcasFilter() and RcasFilterH() is easy.
            pixG: ptr<function, FfxFloat32>,
            pixB: ptr<function, FfxFloat32>,
#ifdef FSR_RCAS_PASSTHROUGH_ALPHA
            pixA: ptr<function, FfxFloat32>,
#endif
            ip: FfxUInt32x2,  // Integer pixel position in output.
            con: FfxUInt32x4)
{   // Constant generated by RcasSetup().
    // Algorithm uses minimal 3x3 pixel neighborhood.
    //    b
    //  d e f
    //    h
    let sp: FfxInt32x2 = FfxInt32x2(ip);
    let b: FfxFloat32x3 = FsrRcasLoadF(sp + FfxInt32x2(0, -1)).rgb;
    let d: FfxFloat32x3 = FsrRcasLoadF(sp + FfxInt32x2(-1, 0)).rgb;
#ifdef FSR_RCAS_PASSTHROUGH_ALPHA
    let ee: FfxFloat32x4 = FsrRcasLoadF(sp);
    let e: FfxFloat32x3 = ee.rgb;
    *pixA = ee.a;
#else
    let e: FfxFloat32x3 = FsrRcasLoadF(sp).rgb;
#endif
    let f: FfxFloat32x3 = FsrRcasLoadF(sp + FfxInt32x2(1, 0)).rgb;
    let h: FfxFloat32x3 = FsrRcasLoadF(sp + FfxInt32x2(0, 1)).rgb;
    // Rename (32-bit) or regroup (16-bit).
    var bR: FfxFloat32 = b.r;
    var bG: FfxFloat32 = b.g;
    var bB: FfxFloat32 = b.b;
    var dR: FfxFloat32 = d.r;
    var dG: FfxFloat32 = d.g;
    var dB: FfxFloat32 = d.b;
    var eR: FfxFloat32 = e.r;
    var eG: FfxFloat32 = e.g;
    var eB: FfxFloat32 = e.b;
    var fR: FfxFloat32 = f.r;
    var fG: FfxFloat32 = f.g;
    var fB: FfxFloat32 = f.b;
    var hR: FfxFloat32 = h.r;
    var hG: FfxFloat32 = h.g;
    var hB: FfxFloat32 = h.b;
    // Run optional input transform.
    FsrRcasInputF(&bR, &bG, &bB);
    FsrRcasInputF(&dR, &dG, &dB);
    FsrRcasInputF(&eR, &eG, &eB);
    FsrRcasInputF(&fR, &fG, &fB);
    FsrRcasInputF(&hR, &hG, &hB);
    // Luma times 2.
    let bL: FfxFloat32 = bB * FfxFloat32(0.5) + (bR * FfxFloat32(0.5) + bG);
    let dL: FfxFloat32 = dB * FfxFloat32(0.5) + (dR * FfxFloat32(0.5) + dG);
    let eL: FfxFloat32 = eB * FfxFloat32(0.5) + (eR * FfxFloat32(0.5) + eG);
    let fL: FfxFloat32 = fB * FfxFloat32(0.5) + (fR * FfxFloat32(0.5) + fG);
    let hL: FfxFloat32 = hB * FfxFloat32(0.5) + (hR * FfxFloat32(0.5) + hG);
    // Noise detection.
    var nz: FfxFloat32 = FfxFloat32(0.25) * bL + FfxFloat32(0.25) * dL + FfxFloat32(0.25) * fL + FfxFloat32(0.25) * hL - eL;
    nz                 = ffxSaturate_f32(abs(nz) * ffxApproximateReciprocalMedium_f32(ffxMax3_f32_f32_f32(ffxMax3_f32_f32_f32(bL, dL, eL), fL, hL) - ffxMin3_f32_f32_f32(ffxMin3_f32_f32_f32(bL, dL, eL), fL, hL)));
    nz                 = FfxFloat32(-0.5) * nz + FfxFloat32(1.0);
    // Min and max of ring.
    let mn4R: FfxFloat32 = ffxMin_f32_f32(ffxMin3_f32_f32_f32(bR, dR, fR), hR);
    let mn4G: FfxFloat32 = ffxMin_f32_f32(ffxMin3_f32_f32_f32(bG, dG, fG), hG);
    let mn4B: FfxFloat32 = ffxMin_f32_f32(ffxMin3_f32_f32_f32(bB, dB, fB), hB);
    let mx4R: FfxFloat32 = max(ffxMax3_f32_f32_f32(bR, dR, fR), hR);
    let mx4G: FfxFloat32 = max(ffxMax3_f32_f32_f32(bG, dG, fG), hG);
    let mx4B: FfxFloat32 = max(ffxMax3_f32_f32_f32(bB, dB, fB), hB);
    // Immediate constants for peak range.
    let peakC: FfxFloat32x2 = FfxFloat32x2(1.0, -1.0 * 4.0);
    // Limiters, these need to be high precision RCPs.
    let hitMinR: FfxFloat32 = mn4R * ffxReciprocal_f32(FfxFloat32(4.0) * mx4R);
    let hitMinG: FfxFloat32 = mn4G * ffxReciprocal_f32(FfxFloat32(4.0) * mx4G);
    let hitMinB: FfxFloat32 = mn4B * ffxReciprocal_f32(FfxFloat32(4.0) * mx4B);
    let hitMaxR: FfxFloat32 = (peakC.x - mx4R) * ffxReciprocal_f32(FfxFloat32(4.0) * mn4R + peakC.y);
    let hitMaxG: FfxFloat32 = (peakC.x - mx4G) * ffxReciprocal_f32(FfxFloat32(4.0) * mn4G + peakC.y);
    let hitMaxB: FfxFloat32 = (peakC.x - mx4B) * ffxReciprocal_f32(FfxFloat32(4.0) * mn4B + peakC.y);
    let lobeR: FfxFloat32   = max(-hitMinR, hitMaxR);
    let lobeG: FfxFloat32   = max(-hitMinG, hitMaxG);
    let lobeB: FfxFloat32   = max(-hitMinB, hitMaxB);
    var lobe: FfxFloat32    = max(FfxFloat32(-FSR_RCAS_LIMIT), ffxMin_f32_f32(ffxMax3_f32_f32_f32(lobeR, lobeG, lobeB), FfxFloat32(0.0))) * ffxAsFloat_u32
    (con.x);
// Apply noise removal.
#ifdef FSR_RCAS_DENOISE
    lobe *= nz;
#endif
    // Resolve, which needs the medium precision rcp approximation to avoid visible tonality changes.
    let rcpL: FfxFloat32 = ffxApproximateReciprocalMedium_f32(FfxFloat32(4.0) * lobe + FfxFloat32(1.0));
    *pixR           = (lobe * bR + lobe * dR + lobe * hR + lobe * fR + eR) * rcpL;
    *pixG           = (lobe * bG + lobe * dG + lobe * hG + lobe * fG + eG) * rcpL;
    *pixB           = (lobe * bB + lobe * dB + lobe * hB + lobe * fB + eB) * rcpL;
    return;
}
#endif
// FsrRcasH (FFX_HALF && FSR_RCAS_H) and FsrRcasHx2 (FFX_HALF && FSR_RCAS_HX2)
// are not ported: FSR2 selects them only on Xbox (ffx_fsr2_rcas.h:28-40).
