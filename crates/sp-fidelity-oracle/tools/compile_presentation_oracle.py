#!/usr/bin/env python3
"""Explicitly export AMD's unchanged UI shaders for the Metal oracle."""
import argparse
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--dxc', type=Path, required=True)
p.add_argument('--spirv-cross', type=Path, required=True)
a = p.parse_args()
crate = Path(__file__).resolve().parent.parent
source = crate.parent / 'sp-fidelity/vendor/sdk-1.1.4/sdk/src/backends/dx12/FrameInterpolationSwapchain/FrameInterpolationSwapchainUiComposition.hlsl'
out = crate / 'shaders/presentation'
work = crate / 'target/presentation-export'
out.mkdir(parents=True, exist_ok=True)
work.mkdir(parents=True, exist_ok=True)
for name, entry, profile, premul in [('vertex', 'mainVS', 'vs_6_2', 0), ('straight', 'mainPS', 'ps_6_2', 0), ('premultiplied', 'mainPS', 'ps_6_2', 1)]:
    spv = work / f'{name}.spv'
    subprocess.run([str(a.dxc), '-spirv', '-fspv-target-env=vulkan1.1', '-T', profile, '-E', entry, '-HV', '2021', '-D', f'FFX_UI_PREMUL={premul}', str(source), '-Fo', str(spv)], check=True)
    subprocess.run([str(a.spirv_cross), str(spv), '--msl', '--msl-version', '30100', '--output', str(out / f'{name}.metal')], check=True)
    path = out / f'{name}.metal'
    path.write_text('// Generated from unchanged AMD SDK 1.1.4 UI composition HLSL.\n// Copyright (C) 2024 Advanced Micro Devices, Inc. MIT; see vendor license.\n' + path.read_text())
