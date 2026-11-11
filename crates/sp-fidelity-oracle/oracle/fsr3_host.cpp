// Drives AMD's unchanged composite FSR3 host and all three constituent effects.
#include "host.h"
#include <FidelityFX/host/ffx_fsr3.h>
#include <iostream>
#include <memory>

static uint64_t frameID() { const uint64_t low = word(); return low | (uint64_t(word()) << 32); }
static FfxFrameGenerationConfig configured{};
static FfxErrorCode configure(const FfxFrameGenerationConfig* c) {
    configured = *c;
    std::cout << "[\"frame-generation-config\"," << uintptr_t(c->swapChain) << ','
        << bool(c->presentCallback) << ',' << bool(c->frameGenerationCallback) << ','
        << c->frameGenerationEnabled << ',' << c->allowAsyncWorkloads << ',' << c->allowAsyncPresent << ",\""
        << (c->HUDLessColor.resource ? "hudless" : "NULL") << "\"," << c->flags << ','
        << c->onlyPresentInterpolated << ",[" << c->interpolationRect.left << ',' << c->interpolationRect.top << ','
        << c->interpolationRect.width << ',' << c->interpolationRect.height << "]," << c->frameID << ','
        << c->drawDebugPacingLines << "]\n";
    return FFX_OK;
}

static int sequence() {
    configured = {};
    FfxFsr3ContextDescription description{};
    description.flags = word();
    description.maxRenderSize = {word(), word()};
    description.maxUpscaleSize = {word(), word()};
    description.displaySize = {word(), word()};
    description.backBufferFormat = FFX_SURFACE_FORMAT_R16G16B16A16_FLOAT;
    description.backendInterfaceSharedResources = backend();
    description.backendInterfaceUpscaling = backend();
    description.backendInterfaceFrameInterpolation = backend();
    description.backendInterfaceFrameInterpolation.fpSwapChainConfigureFrameGeneration = configure;
    ffxFsr3UpscalerSetGlobalDebugMessage(recordMessage, 0);
    const auto r = description.maxRenderSize, d = description.displaySize;
    const auto color = external("color", r.width, r.height);
    const auto depth = external("depth", r.width, r.height);
    const auto motion = external("motion-vectors", r.width, r.height);
    const auto exposure = external("exposure", 1, 1);
    const auto reactive = external("reactive", r.width, r.height);
    const auto transparency = external("transparency", r.width, r.height);
    const auto upscaled = external("upscaled", d.width, d.height);
    auto present = external("present", d.width, d.height);
    auto hudless = external("hudless", d.width, d.height);
    present.description.format = description.backBufferFormat;
    hudless.description.format = description.backBufferFormat;
    const auto interpolated = external("interpolated", d.width, d.height);
    const auto opaque = external("opaque", r.width, r.height);
    const auto outReactive = external("out-reactive", r.width, r.height);
    auto context = std::make_unique<FfxFsr3Context>();
    const auto created = ffxFsr3ContextCreate(context.get(), &description);
    result("create-result", created);
    if (created != FFX_OK) return 0;

    for (uint32_t index = 0, operations = word(); index < operations; index++) {
        frame(index);
        const uint32_t op = word();
        if (op == 0) {
            FfxFsr3DispatchUpscaleDescription p{};
            p.frameID = frameID();
            p.commandList = reinterpret_cast<FfxCommandList>(1);
            p.color = color; p.depth = depth; p.motionVectors = motion;
            const uint32_t optional = word();
            if (optional & 1) p.exposure = exposure;
            if (optional & 2) p.reactive = reactive;
            if (optional & 4) p.transparencyAndComposition = transparency;
            p.upscaleOutput = upscaled;
            p.renderSize = {word(), word()};
            p.upscaleSize = {word(), word()};
            p.jitterOffset = {scalar(), scalar()};
            p.motionVectorScale = {scalar(), scalar()};
            p.enableSharpening = word() != 0; p.sharpness = scalar();
            p.frameTimeDelta = scalar(); p.preExposure = scalar(); p.reset = word() != 0;
            p.cameraNear = scalar(); p.cameraFar = scalar(); p.cameraFovAngleVertical = scalar();
            p.viewSpaceToMetersFactor = scalar(); p.flags = word();
            result("upscale-result", ffxFsr3ContextDispatchUpscale(context.get(), &p));
        } else if (op == 1) {
            FfxFsr3DispatchFrameGenerationPrepareDescription p{};
            p.frameID = frameID(); p.commandList = reinterpret_cast<FfxCommandList>(1);
            p.depth = depth; p.motionVectors = motion;
            p.renderSize = {word(), word()};
            p.jitterOffset = {scalar(), scalar()}; p.motionVectorScale = {scalar(), scalar()};
            p.frameTimeDelta = scalar(); p.cameraNear = scalar(); p.cameraFar = scalar();
            p.viewSpaceToMetersFactor = scalar(); p.cameraFovAngleVertical = scalar();
            result("prepare-result", ffxFsr3ContextDispatchFrameGenerationPrepare(context.get(), &p));
        } else if (op == 2) {
            FfxFrameGenerationConfig p{};
            p.frameID = frameID(); p.flags = word();
            p.frameGenerationEnabled = word() != 0;
            p.allowAsyncWorkloads = word() != 0; p.allowAsyncPresent = word() != 0;
            if (word()) p.HUDLessColor = hudless;
            p.interpolationRect = {int32_t(word()), int32_t(word()), int32_t(word()), int32_t(word())};
            p.swapChain = reinterpret_cast<FfxSwapchain>(7);
            p.frameGenerationCallback = [](const FfxFrameGenerationDispatchDescription* p, void*) { return ffxFsr3DispatchFrameGeneration(p); };
            p.presentCallback = [](const FfxPresentCallbackDescription*, void*) { return FfxErrorCode(FFX_OK); };
            result("configure-result", ffxFsr3ConfigureFrameGeneration(context.get(), &p));
        } else if (op == 3) {
            FfxFrameGenerationDispatchDescription p{};
            p.frameID = frameID(); p.commandList = reinterpret_cast<FfxCommandList>(1);
            p.presentColor = present; p.outputs[0] = interpolated; p.numInterpolatedFrames = 1;
            p.reset = word() != 0; p.backBufferTransferFunction = FfxBackbufferTransferFunction(word());
            p.minMaxLuminance[0] = scalar(); p.minMaxLuminance[1] = scalar();
            p.interpolationRect = {int32_t(word()), int32_t(word()), int32_t(word()), int32_t(word())};
            result("frame-generation-result", configured.frameGenerationCallback(&p, configured.frameGenerationCallbackContext));
        } else if (op == 4) {
            FfxFsr3GenerateReactiveDescription p{};
            p.commandList = reinterpret_cast<FfxCommandList>(1); p.colorOpaqueOnly = opaque;
            p.colorPreUpscale = color; p.outReactive = outReactive;
            p.renderSize = {word(), word()}; p.scale = scalar(); p.cutoffThreshold = scalar();
            p.binaryValue = scalar(); p.flags = word();
            result("reactive-result", ffxFsr3ContextGenerateReactiveMask(context.get(), &p));
        } else if (op == 5) {
            FfxEffectMemoryUsage up{}, of{}, fi{};
            const auto status = ffxFsr3ContextGetGpuMemoryUsage(context.get(), &up, &of, &fi);
            std::cout << "[\"memory-usage-result\"," << status << ',' << up.totalUsageInBytes << ',' << up.aliasableUsageInBytes
                << ',' << of.totalUsageInBytes << ',' << of.aliasableUsageInBytes << ',' << fi.totalUsageInBytes << ',' << fi.aliasableUsageInBytes << "]\n";
        }
    }
    result("destroy-result", ffxFsr3ContextDestroy(context.get()));
    if (configured.frameGenerationCallback) {
        FfxFrameGenerationDispatchDescription p{};
        result("destroyed-callback-result", configured.frameGenerationCallback(&p, configured.frameGenerationCallbackContext));
    }
    return 0;
}

int runEffect() {
    for (uint32_t n = word(); n; --n) { sequence(); }
    return 0;
}
