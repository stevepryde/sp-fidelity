// Drives AMD's unchanged FSR3UPSCALER host (sdk/src/components/fsr3upscaler/ffx_fsr3upscaler.cpp)
// through the recording backend, as an application integrating FSR3UPSCALER does.
// The word stream is documented in tests/fsr3upscaler_host_event_stream.rs, whose
// Rust driver reads it in the same order.
#include "host.h"
#include <FidelityFX/host/ffx_fsr3upscaler.h>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>

static uint32_t bits(float f) { uint32_t u; std::memcpy(&u, &f, 4); return u; }

// ffxFsr3UpscalerGetUpscaleRatioFromQualityMode, ffxFsr3UpscalerGetRenderResolutionFromQualityMode,
// ffxFsr3UpscalerGetJitterPhaseCount, ffxFsr3UpscalerGetJitterOffset, ffxFsr3UpscalerResourceIsNull and
// ffxFsr3UpscalerGetEffectVersion for the listed arguments.
static int helpers() {
    for (uint32_t n = word(); n; n--) {
        const auto mode = FfxFsr3UpscalerQualityMode(word());
        const uint32_t displayWidth = word(), displayHeight = word();
        uint32_t renderWidth = 0, renderHeight = 0;
        const FfxErrorCode status = ffxFsr3UpscalerGetRenderResolutionFromQualityMode(&renderWidth, &renderHeight, displayWidth, displayHeight, mode);
        std::cout << "[\"quality\"," << mode << ',' << displayWidth << ',' << displayHeight << ','
                  << bits(ffxFsr3UpscalerGetUpscaleRatioFromQualityMode(mode)) << ',' << status << ',' << renderWidth << ',' << renderHeight << "]\n";
    }
    for (uint32_t n = word(); n; n--) {
        const auto renderWidth = int32_t(word()), displayWidth = int32_t(word());
        std::cout << "[\"phase-count\"," << renderWidth << ',' << displayWidth << ',' << ffxFsr3UpscalerGetJitterPhaseCount(renderWidth, displayWidth) << "]\n";
    }
    for (uint32_t n = word(); n; n--) {
        const auto index = int32_t(word()), phaseCount = int32_t(word());
        float x = 0, y = 0;
        const FfxErrorCode status = ffxFsr3UpscalerGetJitterOffset(&x, &y, index, phaseCount);
        std::cout << "[\"jitter-offset\"," << index << ',' << phaseCount << ',' << status << ',' << bits(x) << ',' << bits(y) << "]\n";
    }
    std::cout << "[\"resource-is-null\"," << ffxFsr3UpscalerResourceIsNull(FfxResource{}) << ','
              << ffxFsr3UpscalerResourceIsNull(external("color", 1, 1)) << "]\n";
    std::cout << "[\"version\"," << ffxFsr3UpscalerGetEffectVersion() << "]\n";
    return 0;
}

static FfxResource optional(bool present, const FfxResource& resource) { return present ? resource : FfxResource{}; }

// A context over a sequence of dispatches and reactive-mask generations.
static int sequence() {
    FfxFsr3UpscalerContextDescription description{};
    description.flags = word();
    description.maxRenderSize = {word(), word()};
    description.maxUpscaleSize = {word(), word()};
    description.backendInterface = backend();
    const uint32_t colorWidth = word(), colorHeight = word();
    ffxFsr3UpscalerSetGlobalDebugMessage(recordMessage, 0);

    const FfxResource color = external("color", colorWidth, colorHeight);
    const FfxResource depth = external("depth", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource motionVectors = external("motion-vectors", description.maxUpscaleSize.width, description.maxUpscaleSize.height);
    const FfxResource exposure = external("exposure", 1, 1);
    const FfxResource reactive = external("reactive", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource transparencyAndComposition = external("transparency-and-composition", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource output = external("output", description.maxUpscaleSize.width, description.maxUpscaleSize.height);
    const FfxResource opaqueOnly = external("opaque-only", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource outReactive = external("out-reactive", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource dilatedDepth = external("dilated-depth", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource dilatedMotionVectors = external("dilated-motion-vectors", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource reconstructedPrevNearestDepth = external("reconstructed-prev-nearest-depth", description.maxRenderSize.width, description.maxRenderSize.height);

    auto context = std::make_unique<FfxFsr3UpscalerContext>();
    const FfxErrorCode created = ffxFsr3UpscalerContextCreate(context.get(), &description);
    result("create-result", created);
    if (created != FFX_OK) return 0;

    FfxEffectMemoryUsage usage{};
    const FfxErrorCode queried = ffxFsr3UpscalerContextGetGpuMemoryUsage(context.get(), &usage);
    std::cout << "[\"memory-usage-result\"," << queried << ',' << usage.totalUsageInBytes << ',' << usage.aliasableUsageInBytes << "]\n";

    FfxFsr3UpscalerSharedResourceDescriptions shared{};
    result("shared-result", ffxFsr3UpscalerGetSharedResourceDescriptions(context.get(), &shared));
    for (const auto* d : {&shared.reconstructedPrevNearestDepth, &shared.dilatedDepth, &shared.dilatedMotionVectors}) {
        const auto& r = d->resourceDescription;
        std::string name; for (const wchar_t* p = d->name; *p; p++) name += char(*p);
        std::cout << "[\"shared-resource\",\"" << name << "\"," << d->heapType << ',' << r.type << ',' << r.format << ','
                  << r.width << ',' << r.height << ',' << r.depth << ',' << r.mipCount << ',' << r.flags << ',' << r.usage << ','
                  << d->initialState << ',' << d->id << ',' << d->initData.type << ',' << d->initData.size << "]\n";
    }

    for (uint32_t index = 0, frames = word(); index < frames; index++) {
        frame(index);
        const uint32_t op = word();
        if (op == 0) {
            FfxFsr3UpscalerDispatchDescription dispatch{};
            const uint32_t present = word();
            dispatch.commandList = (present & 1) ? reinterpret_cast<FfxCommandList>(1) : nullptr;
            dispatch.color = color;
            dispatch.depth = optional(present & 2, depth);
            dispatch.motionVectors = optional(present & 4, motionVectors);
            dispatch.exposure = optional(present & 8, exposure);
            dispatch.reactive = optional(present & 16, reactive);
            dispatch.transparencyAndComposition = optional(present & 32, transparencyAndComposition);
            dispatch.output = optional(present & 64, output);
            dispatch.dilatedDepth = optional(present & 128, dilatedDepth);
            dispatch.dilatedMotionVectors = optional(present & 256, dilatedMotionVectors);
            dispatch.reconstructedPrevNearestDepth = optional(present & 512, reconstructedPrevNearestDepth);
            // Render size: 5 = the two words given; 0..4 are quality modes (including Native AA).
            const uint32_t renderMode = word();
            if (renderMode == 5) {
                dispatch.renderSize.width = word();
                dispatch.renderSize.height = word();
            } else {
                const FfxErrorCode status = ffxFsr3UpscalerGetRenderResolutionFromQualityMode(&dispatch.renderSize.width, &dispatch.renderSize.height,
                    description.maxUpscaleSize.width, description.maxUpscaleSize.height, FfxFsr3UpscalerQualityMode(renderMode));
                if (status != FFX_OK) throw std::runtime_error("quality mode rejected");
            }
            // Jitter: 0 = the SDK's sequence at the given index, otherwise the two scalars given.
            if (word() == 0) {
                const auto jitterIndex = int32_t(word());
                const int32_t phaseCount = ffxFsr3UpscalerGetJitterPhaseCount(dispatch.renderSize.width, description.maxUpscaleSize.width);
                ffxFsr3UpscalerGetJitterOffset(&dispatch.jitterOffset.x, &dispatch.jitterOffset.y, jitterIndex, phaseCount);
            } else {
                dispatch.jitterOffset.x = scalar();
                dispatch.jitterOffset.y = scalar();
            }
            dispatch.upscaleSize = {word(), word()};
            dispatch.motionVectorScale.x = scalar();
            dispatch.motionVectorScale.y = scalar();
            dispatch.enableSharpening = word() != 0;
            dispatch.sharpness = scalar();
            dispatch.frameTimeDelta = scalar();
            dispatch.preExposure = scalar();
            dispatch.reset = word() != 0;
            dispatch.cameraNear = scalar();
            dispatch.cameraFar = scalar();
            dispatch.cameraFovAngleVertical = scalar();
            dispatch.viewSpaceToMetersFactor = scalar();
            dispatch.flags = word();
            result("dispatch-result", ffxFsr3UpscalerContextDispatch(context.get(), &dispatch));
        } else if (op == 2) {
            const auto key = FfxFsr3UpscalerConfigureKey(word());
            const bool present = word() != 0;
            float value = scalar();
            result("configure-result", ffxFsr3UpscalerSetConstant(context.get(), key, present ? &value : nullptr));
        } else {
            FfxFsr3UpscalerGenerateReactiveDescription generate{};
            generate.commandList = word() ? reinterpret_cast<FfxCommandList>(1) : nullptr;
            generate.colorOpaqueOnly = opaqueOnly;
            generate.colorPreUpscale = color;
            generate.outReactive = outReactive;
            generate.renderSize = {word(), word()};
            generate.scale = scalar();
            generate.cutoffThreshold = scalar();
            generate.binaryValue = scalar();
            generate.flags = word();
            result("generate-reactive-result", ffxFsr3UpscalerContextGenerateReactiveMask(context.get(), &generate));
        }
    }
    result("destroy-result", ffxFsr3UpscalerContextDestroy(context.get()));
    return 0;
}

int runEffect() { return word() == 0 ? helpers() : sequence(); }
