//! Port of the `FFX_CPU` part of `sdk/include/FidelityFX/gpu/fsr1/ffx_fsr1.h`
//! used by FSR2 (FidelityFX SDK 1.1.4): the RCAS constant setup.
use super::core_cpu::{ffx_as_uint32, ffx_pack_half_2x16};
use crate::types::{FfxFloat32, FfxFloat32x2, FfxUInt32x4};

/// `FsrRcasCon`. The scale is {0.0 := maximum, to N>0, where N is the number
/// of stops (halving) of the reduction of sharpness}.
pub fn fsr_rcas_con(con: &mut FfxUInt32x4, mut sharpness: FfxFloat32) {
    // Transform from stops to linear value.
    sharpness = (-sharpness).exp2();
    let h_sharp: FfxFloat32x2 = [sharpness, sharpness];
    con[0] = ffx_as_uint32(sharpness);
    con[1] = ffx_pack_half_2x16(h_sharp);
    con[2] = 0;
    con[3] = 0;
}
