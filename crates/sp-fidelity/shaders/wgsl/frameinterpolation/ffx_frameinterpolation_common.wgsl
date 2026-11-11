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

#if !defined(FFX_FRAMEINTERPOLATION_COMMON_H)
#define FFX_FRAMEINTERPOLATION_COMMON_H

#define FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_TEAR_LINES       (1 << 0)
#define FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_RESET_INDICATORS (1 << 1)
#define FFX_FRAMEINTERPOLATION_DISPATCH_DRAW_DEBUG_VIEW             (1 << 2)

const FFX_FRAMEINTERPOLATION_EPSILON: FfxFloat32 = 1e-03f;
const FFX_FRAMEINTERPOLATION_FLT_MAX: FfxFloat32 = 3.402823466e+38f;
const FFX_FRAMEINTERPOLATION_FLT_MIN: FfxFloat32 = 1.175494351e-38f;

const fReconstructedDepthBilinearWeightThreshold: FfxFloat32 = FFX_FRAMEINTERPOLATION_EPSILON;

fn RGBToLuma(fLinearRgb: FfxFloat32x3) -> FfxFloat32
{
    return dot(fLinearRgb, FfxFloat32x3(0.2126f, 0.7152f, 0.0722f));
}

fn LinearRec2020ToLuminance(linearRec2020RGB: FfxFloat32x3) -> FfxFloat32
{
    var fY: FfxFloat32 = 0.2627 * linearRec2020RGB.x + 0.678 * linearRec2020RGB.y + 0.0593 * linearRec2020RGB.z;
    return fY;
}

fn ffxscRGBToLinear(value: FfxFloat32x3, minLuminance: FfxFloat32, maxLuminance: FfxFloat32) -> FfxFloat32x3
{
    var p: FfxFloat32x3 = value - FfxFloat32x3(minLuminance / 80.0f);
    return p / FfxFloat32x3((maxLuminance - minLuminance) / 80.0f);
}

fn RawRGBToLinear(fRawRgb: FfxFloat32x3) -> FfxFloat32x3
{
    var fLinearRgb: FfxFloat32x3;

    switch (BackBufferTransferFunction())
    {
    case 0: {
        fLinearRgb = ffxLinearFromSrgb_f32x3(fRawRgb);
        }
    case 1: {
        fLinearRgb = ffxLinearFromPQ_f32x3(fRawRgb) * (10000.0f / MaxLuminance());
        }
    case 2: {
        fLinearRgb = ffxscRGBToLinear(fRawRgb, MinLuminance(), MaxLuminance());
        }
        default: {}
    }

    return fLinearRgb;
}

fn RawRGBToLuminance(fRawRgb: FfxFloat32x3) -> FfxFloat32
{
    var fLuminance: FfxFloat32 = 0.0f;

    switch (BackBufferTransferFunction())
    {
    case 0: {
        fLuminance = RGBToLuma(RawRGBToLinear(fRawRgb));
        }
    case 1: {
        fLuminance = LinearRec2020ToLuminance(RawRGBToLinear(fRawRgb));
        }
    case 2: {
        fLuminance = RGBToLuma(RawRGBToLinear(fRawRgb));
        }
        default: {}
    }

    return fLuminance;
}

fn RawRGBToPerceivedLuma(fRawRgb: FfxFloat32x3) -> FfxFloat32
{
    var fLuminance: FfxFloat32 = RawRGBToLuminance(fRawRgb);

    var fPercievedLuminance: FfxFloat32 = 0;
    if (fLuminance <= 216.0f / 24389.0f)
    {
        fPercievedLuminance = fLuminance * (24389.0f / 27.0f);
    }
    else
    {
        fPercievedLuminance = pow(fLuminance, 1.0f / 3.0f) * 116.0f - 16.0f;
    }

    return fPercievedLuminance * 0.01f;
}

struct BilinearSamplingData
{
    iOffsets: array<FfxInt32x2, 4>,
    fWeights: array<FfxFloat32, 4>,
    iBasePos: FfxInt32x2,
}

fn GetBilinearSamplingData(fUv: FfxFloat32x2, iSize: FfxInt32x2) -> BilinearSamplingData
{
    var data: BilinearSamplingData;

    var fPxSample: FfxFloat32x2 = (fUv * FfxFloat32x2(iSize)) - FfxFloat32x2(0.5f, 0.5f);
    data.iBasePos          = FfxInt32x2(floor(fPxSample));
    var fPxFrac: FfxFloat32x2   = fract(fPxSample);

    data.iOffsets[0] = FfxInt32x2(0, 0);
    data.iOffsets[1] = FfxInt32x2(1, 0);
    data.iOffsets[2] = FfxInt32x2(0, 1);
    data.iOffsets[3] = FfxInt32x2(1, 1);

    data.fWeights[0] = (1 - fPxFrac.x) * (1 - fPxFrac.y);
    data.fWeights[1] = (fPxFrac.x) * (1 - fPxFrac.y);
    data.fWeights[2] = (1 - fPxFrac.x) * (fPxFrac.y);
    data.fWeights[3] = (fPxFrac.x) * (fPxFrac.y);

    return data;
}

#if defined(FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION)
fn ConvertFromDeviceDepthToViewSpace(fDeviceDepth: FfxFloat32) -> FfxFloat32
{
    let deviceToViewDepth: FfxFloat32x4 = DeviceToViewSpaceTransformFactors();
    return deviceToViewDepth[1] / (fDeviceDepth - deviceToViewDepth[0]);
}

fn ComputeNdc(fPxPos: FfxFloat32x2, iSize: FfxInt32x2) -> FfxFloat32x2
{
    return fPxPos / FfxFloat32x2(iSize) * FfxFloat32x2(2.0f, -2.0f) + FfxFloat32x2(-1.0f, 1.0f);
}

fn GetViewSpacePosition(iViewportPos: FfxInt32x2, iViewportSize: FfxInt32x2, fDeviceDepth: FfxFloat32) -> FfxFloat32x3
{
    let fDeviceToViewDepth: FfxFloat32x4 = DeviceToViewSpaceTransformFactors();

    let Z: FfxFloat32 = ConvertFromDeviceDepthToViewSpace(fDeviceDepth);

    let fNdcPos: FfxFloat32x2 = ComputeNdc(FfxFloat32x2(iViewportPos), iViewportSize);
    let X: FfxFloat32 = fDeviceToViewDepth[2] * fNdcPos.x * Z;
    let Y: FfxFloat32 = fDeviceToViewDepth[3] * fNdcPos.y * Z;

    return FfxFloat32x3(X, Y, Z);
}
#endif

fn IsOnScreen(pos: FfxInt32x2, size: FfxInt32x2) -> FfxBoolean
{
    return all((FfxUInt32x2(pos) <  FfxUInt32x2(size)));
}

fn IsUvInside(fUv: FfxFloat32x2) -> FfxBoolean
{
    return (fUv.x > 0.0f && fUv.x < 1.0f) && (fUv.y > 0.0f && fUv.y < 1.0f);
}

fn IsInRect(pos: FfxInt32x2, iRectCorner: FfxInt32x2, iRectSize: FfxInt32x2) -> FfxBoolean
{
    return (pos.x >= iRectCorner.x && pos.x < (iRectSize.x + iRectCorner.x) && pos.y >= iRectCorner.y && pos.y < (iRectSize.y + iRectCorner.y));
}

fn MinDividedByMax(v0: FfxFloat32, v1: FfxFloat32) -> FfxFloat32
{
    let m: FfxFloat32 = max(v0, v1);
    return select(0.0, min(v0, v1) / m, m != 0.0);
}

fn NormalizedDot3(v0: FfxFloat32x3, v1: FfxFloat32x3) -> FfxFloat32
{
    var fMaxLength: FfxFloat32 = max(length(v0), length(v1));

    return select(1.0, dot(v0 / fMaxLength, v1 / fMaxLength), fMaxLength > 0.0);
}

fn NormalizedDot2(v0: FfxFloat32x2, v1: FfxFloat32x2) -> FfxFloat32
{
    var fMaxLength: FfxFloat32 = max(length(v0), length(v1));

    return select(1.0, dot(v0 / fMaxLength, v1 / fMaxLength), fMaxLength > 0.0);
}

fn CalculateStaticContentFactor(fCurrentInterpolationSource: FfxFloat32x3, fPresentColor: FfxFloat32x3) -> FfxFloat32
{
    let fFactor: FfxFloat32x3 = ffxSaturate_f32x3(FfxFloat32x3(
        ffxSaturate_f32((1.0f - MinDividedByMax(fCurrentInterpolationSource.r, fPresentColor.r)) / 0.1f),
        ffxSaturate_f32((1.0f - MinDividedByMax(fCurrentInterpolationSource.g, fPresentColor.g)) / 0.1f),
        ffxSaturate_f32((1.0f - MinDividedByMax(fCurrentInterpolationSource.b, fPresentColor.b)) / 0.1f)
    ));

    return max(fFactor.x, max(fFactor.y, fFactor.z));
}

//
// MOTION VECTOR FIELD
//

const MOTION_VECTOR_FIELD_ENTRY_BIT_COUNT: FfxUInt32 = 32;

// Make sure all bit counts add up to MOTION_VECTOR_FIELD_ENTRY_BIT_COUNT
const MOTION_VECTOR_FIELD_VECTOR_COEFFICIENT_BIT_COUNT: FfxUInt32 = 16;
const MOTION_VECTOR_FIELD_PRIORITY_LOW_BIT_COUNT: FfxUInt32 = 5;
const MOTION_VECTOR_FIELD_PRIORITY_HIGH_BIT_COUNT: FfxUInt32 = 10;
const MOTION_VECTOR_PRIMARY_VECTOR_INDICATION_BIT_COUNT: FfxUInt32 = 1;

const MOTION_VECTOR_FIELD_PRIMARY_VECTOR_INDICATION_BIT: FfxUInt32 = (1u << (MOTION_VECTOR_FIELD_ENTRY_BIT_COUNT - 1));

const PRIORITY_LOW_MAX: FfxUInt32 = (1u << MOTION_VECTOR_FIELD_PRIORITY_LOW_BIT_COUNT) - 1;
const PRIORITY_HIGH_MAX: FfxUInt32 = (1u << MOTION_VECTOR_FIELD_PRIORITY_HIGH_BIT_COUNT) - 1;

const PRIORITY_LOW_OFFSET: FfxUInt32 = MOTION_VECTOR_FIELD_VECTOR_COEFFICIENT_BIT_COUNT;
const PRIORITY_HIGH_OFFSET: FfxUInt32 = PRIORITY_LOW_OFFSET + MOTION_VECTOR_FIELD_PRIORITY_LOW_BIT_COUNT;
const PRIMARY_VECTOR_INDICATION_OFFSET: FfxUInt32 = PRIORITY_HIGH_OFFSET + MOTION_VECTOR_FIELD_PRIORITY_HIGH_BIT_COUNT;

struct VectorFieldEntry
{
    fMotionVector: FfxFloat32x2,
    uHighPriorityFactor: FfxFloat32,
    uLowPriorityFactor: FfxFloat32,
    bValid: FfxBoolean,
    bPrimary: FfxBoolean,
    bSecondary: FfxBoolean,
    bInPainted: FfxBoolean,
    fVelocity: FfxFloat32,
    bNegOutside: FfxBoolean,
    bPosOutside: FfxBoolean,
}

fn NewVectorFieldEntry() -> VectorFieldEntry
{
    var vfe: VectorFieldEntry;
    vfe.fMotionVector = FfxFloat32x2(0.0, 0.0);
    vfe.uHighPriorityFactor = 0.0;
    vfe.uLowPriorityFactor = 0.0;
    vfe.bValid = false;
    vfe.bPrimary = false;
    vfe.bSecondary = false;
    vfe.bInPainted = false;
    vfe.fVelocity = 0.0;
    vfe.bNegOutside = false;
    vfe.bPosOutside = false;
    return vfe;
}

fn PackedVectorFieldEntryIsPrimary(packedEntry: FfxUInt32) -> FfxBoolean
{
    return ((packedEntry & MOTION_VECTOR_FIELD_PRIMARY_VECTOR_INDICATION_BIT) != 0);
}

fn PackVectorFieldEntries(bIsPrimary: FfxBoolean, uHighPriorityFactor: FfxUInt32, uLowPriorityFactor: FfxUInt32, fMotionVector: FfxFloat32x2) -> FfxUInt32x2
{
    let uPriority: FfxUInt32 =
        (FfxUInt32(bIsPrimary) * MOTION_VECTOR_FIELD_PRIMARY_VECTOR_INDICATION_BIT)
        | ((uHighPriorityFactor & PRIORITY_HIGH_MAX) << PRIORITY_HIGH_OFFSET)
        | ((uLowPriorityFactor & PRIORITY_LOW_MAX) << PRIORITY_LOW_OFFSET);

    var packedX: FfxUInt32 = uPriority | ffxF32ToF16_f32(fMotionVector.x);
    var packedY: FfxUInt32 = uPriority | ffxF32ToF16_f32(fMotionVector.y);

    return FfxUInt32x2(packedX, packedY);
}

fn UnpackVectorFieldEntries(packed: FfxUInt32x2, vfElement: ptr<function, VectorFieldEntry>)
{
    (*vfElement).uHighPriorityFactor = FfxFloat32((packed.x >> PRIORITY_HIGH_OFFSET) & PRIORITY_HIGH_MAX) / FfxFloat32(PRIORITY_HIGH_MAX);
    (*vfElement).uLowPriorityFactor = FfxFloat32((packed.x >> PRIORITY_LOW_OFFSET) & PRIORITY_LOW_MAX) / FfxFloat32(PRIORITY_LOW_MAX);

    (*vfElement).bPrimary = PackedVectorFieldEntryIsPrimary(packed.x);
    (*vfElement).bValid = ((*vfElement).uHighPriorityFactor > 0.0f);
    (*vfElement).bSecondary = (*vfElement).bValid && !(*vfElement).bPrimary;

    // Reverse priority factor for secondary vectors
    if ((*vfElement).bSecondary)
    {
        (*vfElement).uHighPriorityFactor = 1.0f - (*vfElement).uHighPriorityFactor;
    }

    (*vfElement).fMotionVector.x = unpack2x16float(packed.x).x;
    (*vfElement).fMotionVector.y = unpack2x16float(packed.y).x;
    (*vfElement).bInPainted      = false;
}

//
// MOTION VECTOR FIELD
//

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_INPAINTING_PYRAMID)
fn ComputeMvInpaintingLevel(fUv: FfxFloat32x2, iMipLevel: FfxInt32, iTexSize: FfxInt32x2) -> FfxFloat32x4
{
    var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fUv, iTexSize);

    var fSum: FfxFloat32   = 0.0f;
    var fColor: FfxFloat32x4 = FfxFloat32x4(0.0, 0.0, 0.0, 0.0);
    fColor.z            = 0;

    let fMaxPriorityFactor: FfxFloat32 = 1.0f;

    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++)
    {
        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

        if (IsOnScreen(iSamplePos, iTexSize))
        {
            var fSample: FfxFloat32x4 = LoadInpaintingPyramid(iMipLevel, iSamplePos);

            let fPriorityFactor: FfxFloat32 = fSample.z;
            let fValidMvFactor: FfxFloat32 = FfxFloat32(fSample.z > 0);
            let fSampleWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex] * fValidMvFactor * fPriorityFactor;

            fSum += fSampleWeight;
            fColor += fSample * fSampleWeight;
        }
    }

    fColor /= select(1.0, fSum, fSum > 0.0);

    return fColor;
}
#if defined(FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION) &&      defined(FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_X) &&      defined(FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_Y)

fn LoadInpaintedGameFieldMv(fUv_in: FfxFloat32x2, vfElement: ptr<function, VectorFieldEntry>)
{
    var fUv: FfxFloat32x2 = fUv_in;
    var iPxSample: FfxInt32x2 = FfxInt32x2(fUv * FfxFloat32x2(RenderSize()));
    var packedGameFieldMv: FfxUInt32x2 = LoadGameFieldMv(iPxSample);
    UnpackVectorFieldEntries(packedGameFieldMv, vfElement);

    if (!(*vfElement).bValid)
    {
        //var fUv: FfxFloat32x2 = (FfxFloat32x2(iPxSample) + 0.5f) / FfxFloat32x2(RenderSize());
        var iTexSize: FfxInt32x2 = RenderSize();

        var fInPaintedVector: FfxFloat32x4 = FfxFloat32x4(0.0, 0.0, 0.0, 0.0);
        for (var iMipLevel: FfxInt32 = 0; iMipLevel < 11 && (fInPaintedVector.w == 0.0f); iMipLevel++)
        {
            iTexSize /= 2;

            fInPaintedVector = ComputeMvInpaintingLevel(fUv, iMipLevel, iTexSize);
        }

        (*vfElement).fMotionVector         = fInPaintedVector.xy;
        (*vfElement).uHighPriorityFactor   = fInPaintedVector.z;
        (*vfElement).uLowPriorityFactor    = fInPaintedVector.w;
        (*vfElement).bInPainted            = true;
    }

    (*vfElement).bNegOutside = !IsUvInside(fUv - (*vfElement).fMotionVector);
    (*vfElement).bPosOutside = !IsUvInside(fUv + (*vfElement).fMotionVector);
    (*vfElement).fVelocity   = length((*vfElement).fMotionVector);
}
#endif
#endif

#if defined(FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_X) &&      defined(FFX_FRAMEINTERPOLATION_BIND_SRV_OPTICAL_FLOW_MOTION_VECTOR_FIELD_Y) &&      defined(FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION)
fn SampleOpticalFlowMotionVectorField(fUv: FfxFloat32x2, vfElement: ptr<function, VectorFieldEntry>)
{
    let scaleFactor: FfxFloat32 = 1.0f;

    var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fUv, FfxInt32x2(FfxFloat32x2(GetOpticalFlowSize2()) * scaleFactor));

    (*vfElement) = NewVectorFieldEntry();

    var fWeightSum: FfxFloat32 = 0.0f;
    for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++)
    {
        let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
        let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

        if (IsOnScreen(iSamplePos, FfxInt32x2(FfxFloat32x2(GetOpticalFlowSize2()) * scaleFactor)))
        {
            let fWeight: FfxFloat32 = bilinearInfo.fWeights[iSampleIndex];

            var fOfVectorSample: VectorFieldEntry = NewVectorFieldEntry();
            var packedOpticalFlowMv: FfxUInt32x2 = LoadOpticalFlowFieldMv(iSamplePos);
            UnpackVectorFieldEntries(packedOpticalFlowMv, &fOfVectorSample);

            (*vfElement).fMotionVector += fOfVectorSample.fMotionVector * fWeight;
            (*vfElement).uHighPriorityFactor += fOfVectorSample.uHighPriorityFactor * fWeight;
            (*vfElement).uLowPriorityFactor += fOfVectorSample.uLowPriorityFactor * fWeight;

            fWeightSum += fWeight;
        }
    }

    if (fWeightSum > 0.0f)
    {
        (*vfElement).fMotionVector /= fWeightSum;
        (*vfElement).uHighPriorityFactor /= fWeightSum;
        (*vfElement).uLowPriorityFactor /= fWeightSum;
    }

    (*vfElement).bNegOutside = !IsUvInside(fUv - (*vfElement).fMotionVector);
    (*vfElement).bPosOutside = !IsUvInside(fUv + (*vfElement).fMotionVector);
    (*vfElement).fVelocity   = length((*vfElement).fMotionVector);
}
#endif

fn Tonemap(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    return fRgb / FfxFloat32x3(max(max(0.f, fRgb.r), max(fRgb.g, fRgb.b)) + 1.f);
}

fn InverseTonemap(fRgb: FfxFloat32x3) -> FfxFloat32x3
{
    return fRgb / FfxFloat32x3(max(1.0e-4, 1.f - max(fRgb.r, max(fRgb.g, fRgb.b))));
}

fn ComputeHrPosFromLrPos(iPxLrPos: FfxInt32x2) -> FfxInt32x2
{
    var fSrcJitteredPos: FfxFloat32x2 = FfxFloat32x2(iPxLrPos) + 0.5f - Jitter();
    var fLrPosInHr: FfxFloat32x2      = (fSrcJitteredPos / FfxFloat32x2(RenderSize())) * FfxFloat32x2(DisplaySize());
    var iPxHrPos: FfxInt32x2        = FfxInt32x2(floor(fLrPosInHr));
    return iPxHrPos;
}
#if FFX_HALF
fn ComputeHrPosFromLrPos_f16(iPxLrPos: FFX_MIN16_I2) -> FFX_MIN16_I2
{
    var fSrcJitteredPos: FFX_MIN16_F2 = FFX_MIN16_F2(iPxLrPos) + FFX_MIN16_F(0.5f) - FFX_MIN16_F2(Jitter());
    var fLrPosInHr: FFX_MIN16_F2      = (fSrcJitteredPos / FFX_MIN16_F2(RenderSize())) * FFX_MIN16_F2(DisplaySize());
    var iPxHrPos: FFX_MIN16_I2        = FFX_MIN16_I2(floor(fLrPosInHr));
    return iPxHrPos;
}
#endif

#endif //!defined(FFX_FRAMEINTERPOLATION_COMMON_H)
