// Drives unchanged SDK prepare and interpolation dispatches through the recorder.
#include "host.h"
#include <FidelityFX/host/ffx_frameinterpolation.h>
#include <iostream>
#include <memory>

static void shared(const FfxCreateResourceDescription& r) {
    const auto& d = r.resourceDescription;
    std::cout << "[\"shared-resource\",\"";
    for (const wchar_t* p = r.name; p && *p; ++p) std::cout << char(*p);
    std::cout << "\"," << r.heapType << ',' << d.type << ',' << d.format << ',' << d.width << ',' << d.height
              << ',' << d.depth << ',' << d.mipCount << ',' << d.flags << ',' << d.usage << ',' << r.initialState
              << ',' << r.id << ',' << r.initData.type << ',' << r.initData.size << "]\n";
}

static int sequence() {
    FfxFrameInterpolationContextDescription description{};
    description.flags = word();
    description.maxRenderSize = {word(), word()};
    description.displaySize = {word(), word()};
    description.backBufferFormat = FfxSurfaceFormat(word());
    description.previousInterpolationSourceFormat = FfxSurfaceFormat(word());
    description.backendInterface = backend();
    const auto render = description.maxRenderSize, display = description.displaySize;
    const auto depth = external("depth", render.width, render.height);
    const auto motion = external("motion-vectors", display.width, display.height);
    const auto dilatedDepth = external("dilated-depth", render.width, render.height);
    const auto dilatedMotion = external("dilated-motion-vectors", render.width, render.height);
    const auto reconstructed = external("reconstructed-depth", render.width, render.height);
    auto color = external("color", display.width, display.height);
    auto hudless = external("hudless", display.width, display.height);
    color.description.format = description.backBufferFormat;
    hudless.description.format = description.previousInterpolationSourceFormat;
    const auto output = external("output", display.width, display.height);
    const auto optical = external("optical-flow", (display.width + 7) / 8, (display.height + 7) / 8);
    const auto scd = external("scene-change", 3, 1);
    const auto distortion = external("distortion", display.width, display.height);
    auto context = std::make_unique<FfxFrameInterpolationContext>();
    const auto created = ffxFrameInterpolationContextCreate(context.get(), &description);
    result("create-result", created);
    if (created != FFX_OK) return 0;
    std::cout << "[\"version\"," << ffxFrameInterpolationGetEffectVersion() << "]\n";
    FfxEffectMemoryUsage usage{};
    const auto queried = ffxFrameInterpolationContextGetGpuMemoryUsage(context.get(), &usage);
    std::cout << "[\"memory-usage-result\"," << queried << ',' << usage.totalUsageInBytes << ',' << usage.aliasableUsageInBytes << "]\n";
    FfxFrameInterpolationSharedResourceDescriptions resources{};
    result("shared-result", ffxFrameInterpolationGetSharedResourceDescriptions(context.get(), &resources));
    shared(resources.reconstructedPrevNearestDepth);
    shared(resources.dilatedDepth);
    shared(resources.dilatedMotionVectors);
    for (uint32_t index = 0, count = word(); index < count; ++index) {
        frame(index);
        const uint32_t op = word(), flags = word(), present = word();
        const FfxDimensions2D size = {word(), word()};
        const uint64_t low = word(), high = word(), id = low | high << 32;
        if (op == 0) {
            FfxFrameInterpolationPrepareDescription p{};
            p.flags = flags;
            p.commandList = present & 1 ? reinterpret_cast<FfxCommandList>(1) : nullptr;
            p.renderSize = size;
            p.frameID = id;
            p.jitterOffset = {scalar(), scalar()};
            p.motionVectorScale = {scalar(), scalar()};
            p.frameTimeDelta = scalar();
            p.cameraNear = scalar();
            p.cameraFar = scalar();
            p.viewSpaceToMetersFactor = scalar();
            p.cameraFovAngleVertical = scalar();
            p.depth = depth;
            p.motionVectors = motion;
            p.dilatedDepth = dilatedDepth;
            p.dilatedMotionVectors = dilatedMotion;
            p.reconstructedPrevDepth = reconstructed;
            for (int i = 0; i < 3; ++i) p.cameraPosition[i] = scalar();
            for (int i = 0; i < 3; ++i) p.cameraUp[i] = scalar();
            for (int i = 0; i < 3; ++i) p.cameraRight[i] = scalar();
            for (int i = 0; i < 3; ++i) p.cameraForward[i] = scalar();
            result("prepare-result", ffxFrameInterpolationPrepare(context.get(), &p));
        } else {
            FfxFrameInterpolationDispatchDescription p{};
            p.flags = flags;
            p.commandList = present & 1 ? reinterpret_cast<FfxCommandList>(1) : nullptr;
            p.renderSize = size;
            p.displaySize = {word(), word()};
            p.frameID = id;
            p.currentBackBuffer = color;
            p.currentBackBuffer_HUDLess = present & 2 ? hudless : FfxResource{};
            p.output = output;
            p.interpolationRect = {int(word()), int(word()), int(word()), int(word())};
            p.opticalFlowVector = present & 4 ? optical : FfxResource{};
            p.opticalFlowSceneChangeDetection = present & 4 ? scd : FfxResource{};
            p.opticalFlowBufferSize = {word(), word()};
            p.opticalFlowScale = {scalar(), scalar()};
            p.opticalFlowBlockSize = int(word());
            p.cameraNear = scalar();
            p.cameraFar = scalar();
            p.cameraFovAngleVertical = scalar();
            p.viewSpaceToMetersFactor = scalar();
            p.frameTimeDelta = scalar();
            p.reset = word() != 0;
            p.backBufferTransferFunction = FfxBackbufferTransferFunction(word());
            p.minMaxLuminance[0] = scalar();
            p.minMaxLuminance[1] = scalar();
            p.dilatedDepth = dilatedDepth;
            p.dilatedMotionVectors = dilatedMotion;
            p.reconstructedPrevDepth = reconstructed;
            p.distortionField = present & 8 ? distortion : FfxResource{};
            result("dispatch-result", ffxFrameInterpolationDispatch(context.get(), &p));
        }
    }
    result("destroy-result", ffxFrameInterpolationContextDestroy(context.get()));
    return 0;
}

int runEffect() {
    for (uint32_t count = word(); count; --count) sequence();
    return 0;
}
