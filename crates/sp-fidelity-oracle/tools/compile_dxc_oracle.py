#!/usr/bin/env python3
"""Compile unchanged SDK pass HLSL for the Metal oracle: DXC to SPIR-V, then SPIRV-Cross to MSL.

One run compiles passes of one effect for one permutation-options value (the
flags the SDK host passes to fpCreatePipeline) into one variant directory, and
merges them into its manifest.json. SPIRV-Cross and the HLSL texture-bounds
helpers are shared backend constraints; this is not execution on AMD's
supported Windows DX12/Vulkan backend.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

from framegen_effects import EFFECTS as FRAMEGEN_EFFECTS

CRATE = Path(__file__).resolve().parents[1]
SDK = CRATE.parent / 'sp-fidelity/vendor/sdk-1.1.4/sdk'
REVISION = 'c6efa6bf7f2027b3ec94f28578bb5965eabb9e55'
# SPIR-V bindings of the HLSL register classes: the port's WGSL binding
# offsets (sp_fidelity::shaders::FFX_WGSL_BINDING_OFFSET_*), 64 registers each.
SHIFTS = {'t': 0, 'u': 64, 'b': 128, 's': 192}

EFFECTS = {
    'fsr2': dict(
        # FfxFsr2Pass order (ffx_fsr2.h): oracle pass name, pass HLSL stem.
        passes=[('fsr2_depth_clip', 'depth_clip'),
                ('fsr2_reconstruct_previous_depth', 'reconstruct_previous_depth'),
                ('fsr2_lock', 'lock'),
                ('fsr2_accumulate', 'accumulate'),
                ('fsr2_accumulate_sharpen', 'accumulate'),
                ('fsr2_rcas', 'rcas'),
                ('fsr2_compute_luminance_pyramid', 'compute_luminance_pyramid'),
                ('fsr2_generate_reactive', 'autogen_reactive'),
                ('fsr2_tcr_autogenerate', 'tcr_autogen')],
        callbacks='fsr2/ffx_fsr2_callbacks_hlsl.h',
        # MSL 3.1 has the texture atomics of InterlockedMin (reconstruct previous
        # depth) and InterlockedAdd (SPD counter); SPIRV-Cross emulates them
        # below it through a buffer the texture must alias.
        msl='30100',
        # FSR2_INCLUDE_ARGS, FSR2_BASE_ARGS and FSR2_API_BASE_ARGS of
        # gpu/fsr2/CMakeCompileFSR2Shaders.txt and backends/dx12/CMakeShadersFSR2.txt.
        includes=['.', 'fsr2'],
        args=['-Wno-for-redefinition', '-Wno-ambig-lit-shift',
              '-DFFX_FSR2_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF=0',
              '-DFFX_FSR2_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF=0',
              '-DFFX_FSR2_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF=1',
              '-DFFX_FSR2_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF=0',
              '-DFFX_FSR2_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2'],
        # Fs2ShaderPermutationOptions (ffx_fsr2_private.h) to the PermutationKey
        # defines of POPULATE_PERMUTATION_KEY (ffx_fsr2_shaderblobs.cpp).
        options=[(1 << 0, 'FFX_FSR2_OPTION_REPROJECT_USE_LANCZOS_TYPE'),
                 (1 << 1, 'FFX_FSR2_OPTION_HDR_COLOR_INPUT'),
                 (1 << 2, 'FFX_FSR2_OPTION_LOW_RESOLUTION_MOTION_VECTORS'),
                 (1 << 3, 'FFX_FSR2_OPTION_JITTERED_MOTION_VECTORS'),
                 (1 << 4, 'FFX_FSR2_OPTION_INVERTED_DEPTH'),
                 (1 << 5, 'FFX_FSR2_OPTION_APPLY_SHARPENING')],
        force_wave64=1 << 6,
        allow_fp16=1 << 7,
        # Passes whose blob accessor (ffx_fsr2_shaderblobs.cpp) selects the
        # 32-bit table whatever allow_fp16 says (RCAS outside _GAMING_XBOX).
        fp32_only=['fsr2_rcas', 'fsr2_compute_luminance_pyramid'],
        # Typed UAV formats of the internal resources they bind (ffx_fsr2.cpp);
        # application outputs keep DXC's default.
        formats={'rw_reconstructed_previous_nearest_depth': 'r32ui',
                 'rw_dilated_motion_vectors': 'rg16f', 'rw_dilatedDepth': 'r32f',
                 'rw_internal_upscaled_color': 'rgba16f', 'rw_lock_status': 'rg16f',
                 'rw_lock_input_luma': 'r16f', 'rw_new_locks': 'r8',
                 'rw_prepared_input_color': 'rgba16f', 'rw_luma_history': 'rgba8',
                 'rw_img_mip_shading_change': 'r16f', 'rw_img_mip_5': 'r16f',
                 'rw_dilated_reactive_masks': 'rg8', 'rw_auto_exposure': 'rg32f',
                 'rw_spd_global_atomic': 'r32ui', 'rw_output_autoreactive': 'r8',
                 'rw_output_autocomposition': 'r8',
                 'rw_output_prev_color_pre_alpha': 'r11f_g11f_b10f',
                 'rw_output_prev_color_post_alpha': 'r11f_g11f_b10f'}),
    'fsr3upscaler': dict(
        # FfxFsr3UpscalerPass order, including the unsupported deprecated slot.
        passes=[('fsr3upscaler_prepare_inputs', 'prepare_inputs'),
                ('fsr3upscaler_luma_pyramid', 'luma_pyramid'),
                ('fsr3upscaler_shading_change_pyramid', 'shading_change_pyramid'),
                ('fsr3upscaler_shading_change', 'shading_change'),
                ('fsr3upscaler_prepare_reactivity', 'prepare_reactivity'),
                ('fsr3upscaler_luma_instability', 'luma_instability'),
                ('fsr3upscaler_accumulate', 'accumulate'),
                ('fsr3upscaler_accumulate_sharpen', 'accumulate'),
                ('fsr3upscaler_rcas', 'rcas'),
                ('fsr3upscaler_debug_view', 'debug_view'),
                ('fsr3upscaler_generate_reactive', 'autogen_reactive'),
                ('fsr3upscaler_tcr_autogenerate', None)],
        callbacks='fsr3upscaler/ffx_fsr3upscaler_callbacks_hlsl.h',
        msl='30100',
        includes=['.', 'fsr3upscaler'],
        # CMakeCompileFSR3UpscalerShaders.txt / CMakeShadersFSR3Upscaler.txt.
        args=['-Wno-for-redefinition', '-Wno-ambig-lit-shift',
              '-DFFX_FSR3UPSCALER_OPTION_UPSAMPLE_SAMPLERS_USE_DATA_HALF=0',
              '-DFFX_FSR3UPSCALER_OPTION_ACCUMULATE_SAMPLERS_USE_DATA_HALF=0',
              '-DFFX_FSR3UPSCALER_OPTION_REPROJECT_SAMPLERS_USE_DATA_HALF=1',
              '-DFFX_FSR3UPSCALER_OPTION_POSTPROCESSLOCKSTATUS_SAMPLERS_USE_DATA_HALF=0',
              '-DFFX_FSR3UPSCALER_OPTION_UPSAMPLE_USE_LANCZOS_TYPE=2'],
        options=[(1 << 0, 'FFX_FSR3UPSCALER_OPTION_REPROJECT_USE_LANCZOS_TYPE'),
                 (1 << 1, 'FFX_FSR3UPSCALER_OPTION_HDR_COLOR_INPUT'),
                 (1 << 2, 'FFX_FSR3UPSCALER_OPTION_LOW_RESOLUTION_MOTION_VECTORS'),
                 (1 << 3, 'FFX_FSR3UPSCALER_OPTION_JITTERED_MOTION_VECTORS'),
                 (1 << 4, 'FFX_FSR3UPSCALER_OPTION_INVERTED_DEPTH'),
                 (1 << 5, 'FFX_FSR3UPSCALER_OPTION_APPLY_SHARPENING')],
        force_wave64=1 << 6,
        allow_fp16=1 << 7,
        # The SDK accessor never selects these passes' 16-bit tables on desktop.
        fp32_only=['fsr3upscaler_prepare_inputs', 'fsr3upscaler_rcas',
                   'fsr3upscaler_luma_pyramid', 'fsr3upscaler_shading_change_pyramid',
                   'fsr3upscaler_luma_instability', 'fsr3upscaler_debug_view'],
        # ffx_fsr3upscaler.cpp allocations and shared-resource descriptions.
        formats={'rw_reconstructed_previous_nearest_depth': 'r32ui',
                 'rw_dilated_motion_vectors': 'rg16f', 'rw_dilated_depth': 'r32f',
                 'rw_internal_upscaled_color': 'rgba16f', 'rw_accumulation': 'r8',
                 'rw_luma_history': 'rgba16f', 'rw_shading_change': 'r8',
                 'rw_farthest_depth': 'r16f', 'rw_farthest_depth_mip1': 'r16f',
                 'rw_current_luma': 'r16f', 'rw_luma_instability': 'r16f',
                 'rw_new_locks': 'r8', 'rw_dilated_reactive_masks': 'rgba8',
                 'rw_output_autoreactive': 'r8', 'rw_output_autocomposition': 'r8',
                 'rw_output_prev_color_pre_alpha': 'r11f_g11f_b10f',
                 'rw_output_prev_color_post_alpha': 'r11f_g11f_b10f',
                 'rw_frame_info': 'rgba32f', 'rw_spd_global_atomic': 'r32ui',
                 **{f'rw_spd_mip{i}': 'rg16f' for i in range(6)}}),

}

EFFECTS.update(FRAMEGEN_EFFECTS)

# Verified upstream bugs the port fixes (CONFORMANCE.md), by ID: replacements in
# the working copy of the SDK headers, never in vendor/. A corrected variant is
# the reference for the corrected port; the unchanged ones reproduce the bug.
CORRECTIONS = {
    'fsr2': {
        # Off-screen taps carry no rectification-box weight, as in
        # ffx_fsr3upscaler_upsample.h:611.
        'SDK-P35': [('fsr2/ffx_fsr2_upsample.h',
                     'fBoxSampleWeight = exp(fRectificationCurveBias * fSrcSampleOffsetSq);',
                     'fBoxSampleWeight = exp(fRectificationCurveBias * fSrcSampleOffsetSq) * fOnScreenFactor;')],
        # A sample whose on-screen Lanczos weights sum to FSR2_EPSILON or less
        # takes the rectification box's centre, as ffx_fsr3upscaler_upsample.h:635
        # does for a sample without history, not the unnormalised sum.
        'SDK-P36': [('fsr2/ffx_fsr2_upsample.h',
                     '        Deringing(clippingBox, fColorAndWeight.xyz);\n    }\n',
                     '        Deringing(clippingBox, fColorAndWeight.xyz);\n    } else {\n'
                     '        fColorAndWeight.xyz = clippingBox.boxCenter;\n    }\n')],
        # Taps load clamped coordinates, as the Xbox path of the same function
        # does (ffx_fsr2_upsample.h:275-311), so off-screen taps no longer widen
        # the deringing bounds with zeros or stale texels.
        'SDK-P37': [('fsr2/ffx_fsr2_upsample.h',
                     'ClampLoad(iSrcSamplePos, FfxInt32x2(0, 0), FfxInt32x2(RenderSize()));',
                     'clamp(iSrcSamplePos, FfxInt32x2(0, 0), FfxInt32x2(RenderSize()) - FfxInt32x2(1, 1));')],
    },
}


def run(command, log):
    result = subprocess.run(list(map(str, command)), capture_output=True, text=True)
    log.write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'Compiler failed; see {log}')


def adapt_metal(source: str) -> str:
    """Give Metal the HLSL Load/Store contract: zero outside the resource, stores discarded."""
    # The compiler has already selected which texture reads occur; negative
    # coordinates arrive as large uint values.
    for name in re.findall(r'texture2d<[^>]+> (\w+) \[\[texture', source):
        source = source.replace(name + '.read(', 'sdk_hlsl_load(' + name + ', ')
        source = source.replace(name + '.write(', 'sdk_hlsl_store(' + name + ', ')
    helper = """
template<typename T, access A>
void sdk_hlsl_store(texture2d<T, A> tex, vec<T, 4> value, uint2 p) {
    if (p.x >= tex.get_width() || p.y >= tex.get_height()) return;
    tex.write(value, p);
}
template<typename T>
vec<T, 4> sdk_hlsl_load(texture2d<T, access::sample> tex, uint2 p, uint mip = 0u) {
    if (mip >= tex.get_num_mip_levels()) return vec<T, 4>(T(0));
    if (p.x >= tex.get_width(mip) || p.y >= tex.get_height(mip)) return vec<T, 4>(T(0));
    return tex.read(p, mip);
}
template<typename T>
vec<T, 4> sdk_hlsl_load(texture2d<T, access::read_write> tex, uint2 p) {
    if (p.x >= tex.get_width() || p.y >= tex.get_height()) return vec<T, 4>(T(0));
    return tex.read(p);
}
"""
    return source.replace('using namespace metal;', 'using namespace metal;\n' + helper)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--effect', choices=list(EFFECTS), required=True)
    p.add_argument('--options', type=lambda v: int(v, 0), required=True,
                   help='permutation options the SDK host passes to fpCreatePipeline')
    p.add_argument('--pass-name', action='append', help='default: every pass of the effect')
    p.add_argument('--dxc', type=Path, required=True)
    p.add_argument('--spirv-cross', type=Path, required=True)
    p.add_argument('--correction', action='append', default=[],
                   choices=sorted({c for cs in CORRECTIONS.values() for c in cs}),
                   help='apply a verified upstream fix, repeated for several; default output: '
                        'shaders/generated/<effect>-<correction>[-<correction>...]/')
    p.add_argument('--output', type=Path, help='default: shaders/generated/<effect>/options-<options>')
    a = p.parse_args()
    effect = EFFECTS[a.effect]
    for correction in a.correction:
        if correction not in CORRECTIONS.get(a.effect, {}):
            p.error(f'{correction} does not apply to {a.effect}')
    generated = a.effect + ''.join(f'-{c.lower()}' for c in a.correction)
    stages = [name for name, _ in effect['passes']]
    supported_stages = [name for name, stem in effect['passes'] if stem is not None]
    for name in a.pass_name or []:
        if name not in supported_stages:
            p.error(f'{name} is not a supported pass of {a.effect}: {supported_stages}')
    if a.options & effect['force_wave64']:
        p.error('forced wave64 is not supported: the Metal oracle cannot enforce a subgroup size')
    out = (a.output or CRATE / 'shaders/generated' / generated / f'options-{a.options:#04x}').resolve()
    out.mkdir(parents=True, exist_ok=True)
    work = CRATE / 'target/dxc-oracle' / generated / out.name
    shutil.rmtree(work, ignore_errors=True)
    gpu = work / 'gpu'
    shutil.copytree(SDK / 'include/FidelityFX/gpu', gpu)
    # Vulkan/SPIR-V typed image formats come from the original C++ allocations.
    path = gpu / effect['callbacks']
    code = re.sub(r'((?:globallycoherent\s+)?RWTexture2D<[^>]+>\s+)(rw_\w+)',
        lambda m: f'[[vk::image_format("{effect["formats"][m[2]]}")]] {m[0]}' if m[2] in effect['formats'] else m[0],
        path.read_text())
    path.write_text(code)
    for correction in a.correction:
        for header, original, corrected in CORRECTIONS[a.effect][correction]:
            path = gpu / header
            code = path.read_text()
            if code.count(original) != 1:
                raise SystemExit(f'{correction}: {header} no longer has exactly one {original!r}')
            path.write_text(code.replace(original, corrected))
    version = subprocess.run([str(a.dxc.resolve()), '--version'], capture_output=True, text=True, check=True)
    manifest_path = out / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else dict(
        sdkRevision=REVISION, effect=a.effect, stages=stages, forceWave64Flag=effect['force_wave64'],
        compiler=version.stdout.strip(), passes={}, **({'corrections': a.correction} if a.correction else {}))
    if manifest['effect'] != a.effect or manifest['stages'] != stages:
        raise SystemExit(f'{manifest_path} belongs to another effect')
    if manifest.get('corrections', []) != a.correction:
        raise SystemExit(f'{manifest_path} has other corrections')
    defines = [f'-D{define}={int(bool(a.options & bit))}' for bit, define in effect['options']]
    includes = [arg for directory in effect['includes'] for arg in ('-I', gpu / directory)]
    for name in a.pass_name or supported_stages:
        half = bool(a.options & effect['allow_fp16']) and name not in effect.get('fp32_only', [])
        stem = dict(effect['passes'])[name]
        source = SDK / f'src/backends/dx12/shaders/{a.effect}' / effect.get('sources', {}).get(
            name, f'ffx_{a.effect}_{stem}_pass.hlsl')
        # The wave32 arguments of gpu/CMakeCompileShaders.txt; HLSL 2021 is the
        # default of the DXC the SDK bundles (1.8.2403.2).
        command = [a.dxc.resolve(), '-spirv', '-fspv-target-env=vulkan1.1', '-T', 'cs_6_2', '-E', 'CS', '-HV', '2021',
                   '-DFFX_GPU=1', '-DFFX_HLSL=1', '-DFFX_HLSL_SM=62', f'-DFFX_HALF={int(half)}',
                   *effect['args'], *defines, *includes,
                   *[arg for register_class, shift in SHIFTS.items()
                     for arg in (f'-fvk-{register_class}-shift', shift, '0')],
                   '-Fo', work / f'{name}.spv', source]
        if half:
            command.insert(1, '-enable-16bit-types')
        run(command, work / f'{name}.compile.log')
        run([a.spirv_cross.resolve(), work / f'{name}.spv', '--msl', '--msl-version', effect['msl'],
             '--rename-entry-point', 'CS', 'main0', 'comp', '--output', work / f'{name}.metal'], work / f'{name}.msl.log')
        run([a.spirv_cross.resolve(), work / f'{name}.spv', '--reflect', '--output', work / f'{name}.spirv.json'],
            work / f'{name}.reflect.log')
        metal = adapt_metal((work / f'{name}.metal').read_text())
        (out / f'{name}.metal').write_text(metal)
        spv = json.loads((work / f'{name}.spirv.json').read_text())
        msl = {n: (k, int(i)) for n, k, i in re.findall(r'(\w+) \[\[(buffer|texture|sampler)\((\d+)\)\]\]', metal)}
        resources = []
        for category, kind, register_class in [
                ('separate_images', 'texture', 't'), ('separate_samplers', 'sampler', 's'),
                ('images', 'texture', 'u'), ('ssbos', 'buffer', 'u'),
                ('ubos', 'constant_buffer', 'b')]:
            for r in spv.get(category, []):
                # SPIRV-Cross puts both StructuredBuffer and RWStructuredBuffer
                # in ssbos; readonly reflection identifies the HLSL t register.
                resource_class = 't' if category == 'ssbos' and r.get('readonly', False) else register_class
                resource_shift = SHIFTS[resource_class]
                name_in_shader = r['name'].removeprefix('type.')
                for index in range(r.get('array', [1])[0]):
                    metal_kind, metal_index = msl[name_in_shader]
                    resources.append(dict(name=name_in_shader, kind=kind, registerClass=resource_class,
                        register=r['binding'] - resource_shift, arrayIndex=index, mslIndex=metal_index,
                        mslKind=metal_kind, byteSize=r.get('block_size', 0)))
        reflection = dict(metalEntryPoint='main0', workgroupSize=spv['entryPoints'][0]['workgroup_size'], resources=resources)
        (out / f'{name}.reflection.json').write_text(json.dumps(reflection, indent=2) + '\n')
        # The command as run, with this checkout's paths relative to the crate and
        # the compiler by name (its version is the manifest's compiler).
        recorded = [a.dxc.name if c == command[0] else
                    str(c.relative_to(CRATE)) if isinstance(c, Path) and c.is_relative_to(CRATE) else
                    str(c.relative_to(CRATE.parent)) if isinstance(c, Path) and c.is_relative_to(CRATE.parent) else
                    str(c) for c in command]
        manifest['passes'][name] = dict(source=str(source.relative_to(CRATE.parent)), permutationOptions=a.options,
                                        half=half, command=recorded)
        print(name, out / f'{name}.metal', flush=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
