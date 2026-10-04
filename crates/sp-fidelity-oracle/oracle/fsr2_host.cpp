// Drives AMD's unchanged FSR2 host (sdk/src/components/fsr2/ffx_fsr2.cpp)
// through the recording backend, as an application integrating FSR2 does.
// The word stream is documented in tests/fsr2_host_event_stream.rs, whose
// Rust driver reads it in the same order.
#include "host.h"
#include <FidelityFX/host/ffx_fsr2.h>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>

static uint32_t bits(float f) { uint32_t u; std::memcpy(&u, &f, 4); return u; }

// ffxFsr2GetUpscaleRatioFromQualityMode, ffxFsr2GetRenderResolutionFromQualityMode,
// ffxFsr2GetJitterPhaseCount, ffxFsr2GetJitterOffset, ffxFsr2ResourceIsNull and
// ffxFsr2GetEffectVersion for the listed arguments.
static int helpers() {
    for (uint32_t n = word(); n; n--) {
        const auto mode = FfxFsr2QualityMode(word());
        const uint32_t displayWidth = word(), displayHeight = word();
        uint32_t renderWidth = 0, renderHeight = 0;
        const FfxErrorCode status = ffxFsr2GetRenderResolutionFromQualityMode(&renderWidth, &renderHeight, displayWidth, displayHeight, mode);
        std::cout << "[\"quality\"," << mode << ',' << displayWidth << ',' << displayHeight << ','
                  << bits(ffxFsr2GetUpscaleRatioFromQualityMode(mode)) << ',' << status << ',' << renderWidth << ',' << renderHeight << "]\n";
    }
    for (uint32_t n = word(); n; n--) {
        const auto renderWidth = int32_t(word()), displayWidth = int32_t(word());
        std::cout << "[\"phase-count\"," << renderWidth << ',' << displayWidth << ',' << ffxFsr2GetJitterPhaseCount(renderWidth, displayWidth) << "]\n";
    }
    for (uint32_t n = word(); n; n--) {
        const auto index = int32_t(word()), phaseCount = int32_t(word());
        float x = 0, y = 0;
        const FfxErrorCode status = ffxFsr2GetJitterOffset(&x, &y, index, phaseCount);
        std::cout << "[\"jitter-offset\"," << index << ',' << phaseCount << ',' << status << ',' << bits(x) << ',' << bits(y) << "]\n";
    }
    std::cout << "[\"resource-is-null\"," << ffxFsr2ResourceIsNull(FfxResource{}) << ','
              << ffxFsr2ResourceIsNull(external("color", 1, 1)) << "]\n";
    std::cout << "[\"version\"," << ffxFsr2GetEffectVersion() << "]\n";
    return 0;
}

static FfxResource optional(bool present, const FfxResource& resource) { return present ? resource : FfxResource{}; }

// A context over a sequence of dispatches and reactive-mask generations.
static int sequence() {
    FfxFsr2ContextDescription description{};
    description.flags = word();
    description.maxRenderSize = {word(), word()};
    description.displaySize = {word(), word()};
    description.backendInterface = backend();
    const uint32_t colorWidth = word(), colorHeight = word();
    ffxFsr2SetGlobalDebugMessage(recordMessage, 0);

    const FfxResource color = external("color", colorWidth, colorHeight);
    const FfxResource depth = external("depth", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource motionVectors = external("motion-vectors", description.displaySize.width, description.displaySize.height);
    const FfxResource exposure = external("exposure", 1, 1);
    const FfxResource reactive = external("reactive", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource transparencyAndComposition = external("transparency-and-composition", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource output = external("output", description.displaySize.width, description.displaySize.height);
    const FfxResource opaqueOnly = external("opaque-only", description.maxRenderSize.width, description.maxRenderSize.height);
    const FfxResource outReactive = external("out-reactive", description.maxRenderSize.width, description.maxRenderSize.height);

    auto context = std::make_unique<FfxFsr2Context>();
    const FfxErrorCode created = ffxFsr2ContextCreate(context.get(), &description);
    result("create-result", created);
    if (created != FFX_OK) return 0;

    FfxEffectMemoryUsage usage{};
    const FfxErrorCode queried = ffxFsr2ContextGetGpuMemoryUsage(context.get(), &usage);
    std::cout << "[\"memory-usage-result\"," << queried << ',' << usage.totalUsageInBytes << ',' << usage.aliasableUsageInBytes << "]\n";

    for (uint32_t index = 0, frames = word(); index < frames; index++) {
        frame(index);
        if (word() == 0) {
            FfxFsr2DispatchDescription dispatch{};
            const uint32_t present = word();
            dispatch.commandList = (present & 1) ? reinterpret_cast<FfxCommandList>(1) : nullptr;
            dispatch.color = color;
            dispatch.depth = optional(present & 2, depth);
            dispatch.motionVectors = optional(present & 4, motionVectors);
            dispatch.exposure = optional(present & 8, exposure);
            dispatch.reactive = optional(present & 16, reactive);
            dispatch.transparencyAndComposition = optional(present & 32, transparencyAndComposition);
            dispatch.output = optional(present & 64, output);
            dispatch.colorOpaqueOnly = optional(present & 128, opaqueOnly);
            // Render size: 0 = the two words given, otherwise FfxFsr2QualityMode.
            const uint32_t renderMode = word();
            if (renderMode == 0) {
                dispatch.renderSize.width = word();
                dispatch.renderSize.height = word();
            } else {
                const FfxErrorCode status = ffxFsr2GetRenderResolutionFromQualityMode(&dispatch.renderSize.width, &dispatch.renderSize.height,
                    description.displaySize.width, description.displaySize.height, FfxFsr2QualityMode(renderMode));
                if (status != FFX_OK) throw std::runtime_error("quality mode rejected");
            }
            // Jitter: 0 = the SDK's sequence at the given index, otherwise the two scalars given.
            if (word() == 0) {
                const auto jitterIndex = int32_t(word());
                const int32_t phaseCount = ffxFsr2GetJitterPhaseCount(dispatch.renderSize.width, description.displaySize.width);
                ffxFsr2GetJitterOffset(&dispatch.jitterOffset.x, &dispatch.jitterOffset.y, jitterIndex, phaseCount);
            } else {
                dispatch.jitterOffset.x = scalar();
                dispatch.jitterOffset.y = scalar();
            }
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
            dispatch.enableAutoReactive = word() != 0;
            dispatch.autoTcThreshold = scalar();
            dispatch.autoTcScale = scalar();
            dispatch.autoReactiveScale = scalar();
            dispatch.autoReactiveMax = scalar();
            result("dispatch-result", ffxFsr2ContextDispatch(context.get(), &dispatch));
        } else {
            FfxFsr2GenerateReactiveDescription generate{};
            generate.commandList = word() ? reinterpret_cast<FfxCommandList>(1) : nullptr;
            generate.colorOpaqueOnly = opaqueOnly;
            generate.colorPreUpscale = color;
            generate.outReactive = outReactive;
            generate.renderSize = {word(), word()};
            generate.scale = scalar();
            generate.cutoffThreshold = scalar();
            generate.binaryValue = scalar();
            generate.flags = word();
            result("generate-reactive-result", ffxFsr2ContextGenerateReactiveMask(context.get(), &generate));
        }
    }
    result("destroy-result", ffxFsr2ContextDestroy(context.get()));
    return 0;
}

int runEffect() { return word() == 0 ? helpers() : sequence(); }
