// FSR2's RCAS constant buffer as AMD's unchanged host computes it: the
// headers in ffx_fsr2.cpp's include order, then ffx_fsr2.cpp:1261-1263 for
// each FfxFsr2DispatchDescription::sharpness given as float bits. Prints the
// four cbRCAS words per line. Used by the pass oracle until the FSR2 host
// oracle records whole frames.
#include <algorithm>
#include <cmath>
#include <string.h>
#include <cfloat>

#include <FidelityFX/host/ffx_fsr2.h>
#define FFX_CPU
#include <FidelityFX/gpu/ffx_core.h>
#include <FidelityFX/gpu/fsr1/ffx_fsr1.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>

// ffx_fsr2.cpp:132-135.
typedef struct Fsr2RcasConstants {

    uint32_t                    rcasConfig[4];
} FfxRcasConstants;

int main(int argc, char** argv)
{
    for (int i = 1; i < argc; ++i) {
        const uint32_t bits = uint32_t(std::strtoul(argv[i], nullptr, 0));
        float sharpness;
        memcpy(&sharpness, &bits, sizeof(sharpness));

        Fsr2RcasConstants rcasConsts = {};
        const float sharpenessRemapped = (-2.0f * sharpness) + 2.0f;
        FsrRcasCon(rcasConsts.rcasConfig, sharpenessRemapped);

        std::printf("%u %u %u %u\n", rcasConsts.rcasConfig[0], rcasConsts.rcasConfig[1],
                    rcasConsts.rcasConfig[2], rcasConsts.rcasConfig[3]);
    }
    return 0;
}
