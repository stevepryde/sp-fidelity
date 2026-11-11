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

// WGSL port of ffx_frameinterpolation_optical_flow_vector_field.h.

#ifndef FFX_FRAMEINTERPOLATION_OPTICAL_FLOW_VECTOR_FIELD_H
#define FFX_FRAMEINTERPOLATION_OPTICAL_FLOW_VECTOR_FIELD_H

fn computeOpticalFlowFieldMvs(dtID: FfxUInt32x2, fOpticalFlowVector: FfxFloat32x2)
{
    var fUv: FfxFloat32x2 = FfxFloat32x2(FfxFloat32x2(dtID)+0.5f) / FfxFloat32x2(GetOpticalFlowSize2());

    let scaleFactor: FfxFloat32 = 1.0f;
    var fMotionVectorHalf: FfxFloat32x2 = fOpticalFlowVector * 0.5f;

    // pixel position in current frame + fOpticalFlowVector-> pixel position in previous frame
    var prevBackbufferCol: FfxFloat32x3 = SamplePreviousBackbuffer(fUv + fOpticalFlowVector).xyz; // returns previous backbuffer color of current frame pixel position in previous frame
    var curBackbufferCol: FfxFloat32x3  = SampleCurrentBackbuffer(fUv).xyz; // returns current backbuffer color at current frame pixel position

    var prevLuma: FfxFloat32 = 0.001f + RawRGBToLuminance(prevBackbufferCol);
    var currLuma: FfxFloat32 = 0.001f + RawRGBToLuminance(curBackbufferCol);

    var fVelocity: FfxFloat32 = length(fOpticalFlowVector * FfxFloat32x2(InterpolationRectSize()));
    var uHighPriorityFactor: FfxUInt32 = FfxUInt32(fVelocity > 1.0f) * FfxUInt32(ffxSaturate_f32(fVelocity / length(FfxFloat32x2(InterpolationRectSize()) * 0.05f)) * FfxFloat32(PRIORITY_HIGH_MAX));

    if(uHighPriorityFactor > 0) {
        var uLowPriorityFactor: FfxUInt32 = FfxUInt32(round(pow(MinDividedByMax(prevLuma, currLuma), 1.0f / 1.0f) * FfxFloat32(PRIORITY_LOW_MAX)))
            * FfxUInt32(IsUvInside(fUv + fOpticalFlowVector));

        // Project current depth into previous frame locations.
        // Push to all pixels having some contribution if reprojection is using bilinear logic.

        let packedVectorPrimary: FfxUInt32x2 = PackVectorFieldEntries(true, uHighPriorityFactor, uLowPriorityFactor, fMotionVectorHalf);

        var bilinearInfo: BilinearSamplingData = GetBilinearSamplingData(fUv + fMotionVectorHalf, GetOpticalFlowSize2());
        for (var iSampleIndex: FfxInt32 = 0; iSampleIndex < 4; iSampleIndex++)
        {
            let iOffset: FfxInt32x2 = bilinearInfo.iOffsets[iSampleIndex];
            let iSamplePos: FfxInt32x2 = bilinearInfo.iBasePos + iOffset;

            if (IsOnScreen(iSamplePos, GetOpticalFlowSize2()))
            {
                UpdateOpticalflowMotionVectorField(iSamplePos, packedVectorPrimary);
            }
        }
    }
}

fn computeOpticalFlowVectorField(iPxPos: FfxInt32x2)
{
    var fOpticalFlowVector: FfxFloat32x2 = FfxFloat32x2(0.0, 0.0);
    var fOpticalFlowVector3x3Avg: FfxFloat32x2 = FfxFloat32x2(0.0, 0.0);
    var size: FfxInt32 = 1;
    var sw: FfxFloat32 = 0.0f;

    for(var y: FfxInt32 = -size; y <= size; y++) {
        for(var x: FfxInt32 = -size; x <= size; x++) {

            var samplePos: FfxInt32x2 = iPxPos + FfxInt32x2(x, y);

            var vs: FfxFloat32x2 = LoadOpticalFlow(samplePos);
            // WGSL: SDK confidence is assigned but never consumed; DXC removes
            // that load and its binding from the pass reflection.


            var len: FfxFloat32        = length(vs * FfxFloat32x2(InterpolationRectSize()));
            var len_factor: FfxFloat32 = max(0.0f, 512.0f - len) * FfxFloat32(len > 1.0f);
            var w: FfxFloat32 = len_factor;

            fOpticalFlowVector3x3Avg += vs * w;

            sw += w;
        }
    }

    fOpticalFlowVector3x3Avg /= sw;


    sw = 0.0f;
    for(var y: FfxInt32 = -size; y <= size; y++) {
        for(var x: FfxInt32 = -size; x <= size; x++) {

            var samplePos: FfxInt32x2 = iPxPos + FfxInt32x2(x, y);

            var vs: FfxFloat32x2 = LoadOpticalFlow(samplePos);
            // WGSL: SDK confidence is assigned but never consumed; DXC removes
            // that load and its binding from the pass reflection.
            var len: FfxFloat32               = length(vs * FfxFloat32x2(InterpolationRectSize()));
            var len_factor: FfxFloat32        = max(0.0f, 512.0f - len) * FfxFloat32(len > 1.0f);


            var w: FfxFloat32 = max(0.0f, pow(dot(fOpticalFlowVector3x3Avg, vs), 1.25f)) * len_factor;

            fOpticalFlowVector += vs * w;
            sw += w;
        }
    }

    if (sw > FFX_FRAMEINTERPOLATION_EPSILON)
    {
        fOpticalFlowVector /= sw;
    }

    computeOpticalFlowFieldMvs(FfxUInt32x2(iPxPos), fOpticalFlowVector);
}

#endif // FFX_FRAMEINTERPOLATION_OPTICAL_FLOW_VECTOR_FIELD_H
