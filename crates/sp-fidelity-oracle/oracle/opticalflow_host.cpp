// Drives the unchanged SDK optical-flow host through the recording backend.
#include "host.h"
#include <FidelityFX/host/ffx_opticalflow.h>
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

int runEffect() {
    FfxOpticalflowContextDescription description{};
    description.backendInterface = backend();
    description.flags = word();
    description.resolution = {word(), word()};
    const auto color = external("color", description.resolution.width, description.resolution.height);
    const auto vector = external("optical-flow", (description.resolution.width + 7) / 8, (description.resolution.height + 7) / 8);
    const auto scd = external("scene-change", 3, 1);
    auto context = std::make_unique<FfxOpticalflowContext>();
    const auto created = ffxOpticalflowContextCreate(context.get(), &description);
    result("create-result", created);
    if (created != FFX_OK) return 0;
    std::cout << "[\"version\"," << ffxOpticalflowGetEffectVersion() << "]\n";
    FfxEffectMemoryUsage usage{};
    const auto queried = ffxOpticalflowContextGetGpuMemoryUsage(context.get(), &usage);
    std::cout << "[\"memory-usage-result\"," << queried << ',' << usage.totalUsageInBytes << ',' << usage.aliasableUsageInBytes << "]\n";
    FfxOpticalflowSharedResourceDescriptions resources{};
    result("shared-result", ffxOpticalflowGetSharedResourceDescriptions(context.get(), &resources));
    shared(resources.opticalFlowVector);
    shared(resources.opticalFlowSCD);
    for (uint32_t index = 0, count = word(); index < count; ++index) {
        frame(index);
        FfxOpticalflowDispatchDescription dispatch{};
        const uint32_t present = word();
        dispatch.commandList = present & 1 ? reinterpret_cast<FfxCommandList>(1) : nullptr;
        dispatch.color = present & 2 ? color : FfxResource{};
        dispatch.color.description.width = word();
        dispatch.color.description.height = word();
        dispatch.opticalFlowVector = present & 4 ? vector : FfxResource{};
        dispatch.opticalFlowSCD = present & 8 ? scd : FfxResource{};
        dispatch.reset = word() != 0;
        dispatch.backbufferTransferFunction = int(word());
        dispatch.minMaxLuminance = {scalar(), scalar()};
        result("dispatch-result", ffxOpticalflowContextDispatch(context.get(), &dispatch));
    }
    result("destroy-result", ffxOpticalflowContextDestroy(context.get()));
    return 0;
}
