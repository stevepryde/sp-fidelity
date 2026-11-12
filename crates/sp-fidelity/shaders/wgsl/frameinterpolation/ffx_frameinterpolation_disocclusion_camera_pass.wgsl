// sp-fidelity camera visibility extension, MIT; SDK-P29.
#define FFX_FRAMEINTERPOLATION_EDGE_VISIBILITY
#define FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_X 0
#define FFX_FRAMEINTERPOLATION_BIND_SRV_GAME_MOTION_VECTOR_FIELD_Y 1
#define FFX_FRAMEINTERPOLATION_BIND_SRV_RECONSTRUCTED_DEPTH_PREVIOUS_FRAME 2
#define FFX_FRAMEINTERPOLATION_BIND_SRV_DILATED_DEPTH 3
#define FFX_FRAMEINTERPOLATION_BIND_SRV_RECONSTRUCTED_DEPTH_INTERPOLATED_FRAME 4
#define FFX_FRAMEINTERPOLATION_BIND_SRV_INPAINTING_PYRAMID 5
#define FFX_FRAMEINTERPOLATION_BIND_SRV_DISTORTION_FIELD 6
#define FFX_FRAMEINTERPOLATION_BIND_UAV_DISOCCLUSION_MASK 0
#define FFX_FRAMEINTERPOLATION_BIND_CB_FRAMEINTERPOLATION 0
#include "frameinterpolation/ffx_frameinterpolation_callbacks.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_common.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_edge_common.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_edge_visibility.wgsl"
#include "frameinterpolation/ffx_frameinterpolation_disocclusion_mask.wgsl"

@compute @workgroup_size(8, 8, 1)
fn CS(@builtin(global_invocation_id) id: vec3<u32>) {
    computeDisocclusionMask(vec2<i32>(id.xy));
}
