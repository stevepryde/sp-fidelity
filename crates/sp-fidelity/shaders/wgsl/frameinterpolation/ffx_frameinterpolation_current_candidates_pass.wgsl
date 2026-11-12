// Current-source mesh fills gaps left by AMD's fixed 2x2 point splats. MIT.
// The same bounded rasterizer as the previous-source correction, with measured
// current motion validating the camera projection before accepting vertices.
#define FFX_OUTGOING_SOURCE_CURRENT 1
#define FFX_FRAMEINTERPOLATION_BIND_SRV_DISTORTION_FIELD 2
#include "frameinterpolation/ffx_frameinterpolation_outgoing_candidates_pass.wgsl"
