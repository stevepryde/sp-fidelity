// Drive the unchanged SDK reflections denoiser through the recording backend.
#include "host.h"
#include <FidelityFX/host/ffx_denoiser.h>
#include <iostream>
#include <memory>

int runEffect() {
    FfxDenoiserContextDescription description{};
    description.backendInterface = backend();
    description.flags = word();
    description.windowSize = {word(), word()};
    description.normalsHistoryBufferFormat = static_cast<FfxSurfaceFormat>(word());

    const auto width = description.windowSize.width;
    const auto height = description.windowSize.height;
    auto input = [&](const char* name) { return external(name, width, height); };
    const auto depth = input("depth");
    const auto motion = input("motion");
    const auto normal = input("normal");
    const FfxResource radiance[] = {input("radiance0"), input("radiance1")};
    const FfxResource variance[] = {input("variance0"), input("variance1")};
    const auto roughness = input("roughness");
    const auto tiles = external("tiles", (width + 7) / 8 * ((height + 7) / 8), 1);
    const auto indirect = external("indirect", 6, 1);
    const auto output = input("output");

    auto context = std::make_unique<FfxDenoiserContext>();
    const auto created = ffxDenoiserContextCreate(context.get(), &description);
    result("create-result", created);
    if (created != FFX_OK) return 0;
    std::cout << "[\"version\"," << ffxDenoiserGetEffectVersion() << "]\n";

    for (uint32_t index = 0, count = word(); index < count; ++index) {
        frame(index);
        FfxDenoiserReflectionsDispatchDescription dispatch{};
        dispatch.frameIndex = word();
        dispatch.reset = word() != 0;
        const uint32_t parity = word();
        dispatch.commandList = reinterpret_cast<FfxCommandList>(1);
        dispatch.depthHierarchy = depth;
        dispatch.motionVectors = motion;
        dispatch.normal = normal;
        dispatch.radianceA = radiance[parity];
        dispatch.radianceB = radiance[1 - parity];
        dispatch.varianceA = variance[parity];
        dispatch.varianceB = variance[1 - parity];
        dispatch.extractedRoughness = roughness;
        dispatch.denoiserTileList = tiles;
        dispatch.indirectArgumentsBuffer = indirect;
        dispatch.output = output;
        dispatch.renderSize = {word(), word()};
        dispatch.motionVectorScale = {scalar(), scalar()};
        for (float& v : dispatch.invProjection) v = scalar();
        for (float& v : dispatch.invView) v = scalar();
        for (float& v : dispatch.prevViewProjection) v = scalar();
        dispatch.normalsUnpackMul = scalar();
        dispatch.normalsUnpackAdd = scalar();
        dispatch.isRoughnessPerceptual = word() != 0;
        dispatch.roughnessChannel = word();
        dispatch.temporalStabilityFactor = scalar();
        dispatch.roughnessThreshold = scalar();
        result("dispatch-result", ffxDenoiserContextDispatchReflections(context.get(), &dispatch));
    }
    result("destroy-result", ffxDenoiserContextDestroy(context.get()));
    return 0;
}
