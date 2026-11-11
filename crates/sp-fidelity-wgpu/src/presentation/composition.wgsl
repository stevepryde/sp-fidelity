// Port of FrameInterpolationSwapchainUiComposition.hlsl and DebugPacing.hlsl.
// Copyright (C) 2024 Advanced Micro Devices, Inc. MIT; see LICENSE.txt.
@group(0) @binding(0) var scene: texture_2d<f32>;
@group(0) @binding(1) var ui: texture_2d<f32>;
struct Options { mode: u32, frame_index: u32, debug: u32, padding: u32 };
@group(0) @binding(2) var<uniform> options: Options;

@vertex fn vs(@builtin(vertex_index) id: u32) -> @builtin(position) vec4<f32> {
    return vec4<f32>(f32(i32(id & 1u)*4-1), f32(i32(id & 2u)*(-2)+1), 0.5, 1.);
}
@fragment fn fs(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let color = textureLoad(scene, vec2<i32>(pos.xy), 0);
    var result = color;
    if options.mode != 0u {
        let gui = textureLoad(ui, vec2<i32>(pos.xy), 0);
        if options.mode == 2u {
            result = vec4<f32>((1.-gui.a)*color.rgb + gui.rgb, 1.);
        } else {
            result = vec4<f32>(mix(color.rgb, gui.rgb, gui.a), 1.);
        }
    }
    if options.debug != 0u {
        let a = f32(options.frame_index & 1u);
        let b = f32((~options.frame_index) & 1u);
        if pos.x < 16. { return vec4<f32>(b,a,b,1.); }
        if pos.x < 32. { return vec4<f32>(a,a,a,1.); }
    }
    return result;
}
