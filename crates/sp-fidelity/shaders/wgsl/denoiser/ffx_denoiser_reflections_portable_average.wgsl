#include "ffx_core_storage.wgsl"

fn sdk_store_average(pixel: vec2i, value: vec4f) {
    textureStore(rw_average_radiance, pixel, vec4f(ffxWgslR11G11B10Float(value.xyz), 1.0));
}
