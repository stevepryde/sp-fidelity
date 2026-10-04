//! Port of the `FFX_CPU` part of `sdk/include/FidelityFX/gpu/spd/ffx_spd.h`
//! (FidelityFX SDK 1.1.4): the SPD constant setup.
use super::core_cpu::{ffx_max_u32, ffx_min_f32};
use crate::types::{FfxFloat32, FfxInt32, FfxUInt32, FfxUInt32x2, FfxUInt32x4};

/// `ffxSpdSetup(dispatchThreadGroupCountXY, workGroupOffset, numWorkGroupsAndMips, rectInfo, mips)`.
pub fn ffx_spd_setup_mips(
    dispatch_thread_group_count_xy: &mut FfxUInt32x2,
    work_group_offset: &mut FfxUInt32x2,
    num_work_groups_and_mips: &mut FfxUInt32x2,
    rect_info: FfxUInt32x4,
    mips: FfxInt32,
) {
    // determines the offset of the first tile to downsample based on
    // left (rectInfo[0]) and top (rectInfo[1]) of the subregion.
    work_group_offset[0] = rect_info[0] / 64;
    work_group_offset[1] = rect_info[1] / 64;

    // C unsigned arithmetic wraps.
    let end_index_x = rect_info[0].wrapping_add(rect_info[2]).wrapping_sub(1) / 64; // rectInfo[0] = left, rectInfo[2] = width
    let end_index_y = rect_info[1].wrapping_add(rect_info[3]).wrapping_sub(1) / 64; // rectInfo[1] = top, rectInfo[3] = height

    // we only need to dispatch as many thread groups as tiles we need to downsample
    // number of tiles per slice depends on the subregion to downsample
    dispatch_thread_group_count_xy[0] = end_index_x
        .wrapping_add(1)
        .wrapping_sub(work_group_offset[0]);
    dispatch_thread_group_count_xy[1] = end_index_y
        .wrapping_add(1)
        .wrapping_sub(work_group_offset[1]);

    // number of thread groups per slice
    num_work_groups_and_mips[0] =
        dispatch_thread_group_count_xy[0].wrapping_mul(dispatch_thread_group_count_xy[1]);

    if mips >= 0 {
        num_work_groups_and_mips[1] = mips as FfxUInt32;
    } else {
        // calculate based on rect width and height
        let resolution: FfxUInt32 = ffx_max_u32(rect_info[2], rect_info[3]);
        num_work_groups_and_mips[1] =
            ffx_min_f32((resolution as FfxFloat32).log2().floor(), 12 as FfxFloat32) as FfxUInt32;
    }
}

/// `ffxSpdSetup(dispatchThreadGroupCountXY, workGroupOffset, numWorkGroupsAndMips, rectInfo)`.
pub fn ffx_spd_setup(
    dispatch_thread_group_count_xy: &mut FfxUInt32x2,
    work_group_offset: &mut FfxUInt32x2,
    num_work_groups_and_mips: &mut FfxUInt32x2,
    rect_info: FfxUInt32x4,
) {
    ffx_spd_setup_mips(
        dispatch_thread_group_count_xy,
        work_group_offset,
        num_work_groups_and_mips,
        rect_info,
        -1,
    );
}
