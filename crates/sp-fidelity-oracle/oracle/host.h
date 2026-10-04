// The recording FfxInterface of the C++ host oracle, shared by every effect.
// An effect driver (oracle/<effect>_host.cpp) defines runEffect(): it reads
// the rest of the word stream, drives AMD's unchanged component through
// backend(), and prints the results with result() and frame(). The event
// format is documented in the crate README.
#pragma once
#include <FidelityFX/host/ffx_interface.h>
#include <cstdint>

// The next word of the input stream, as an integer or as float bits.
uint32_t word();
float scalar();
// The recording backend, reporting the capabilities read from the stream.
FfxInterface backend();
// An application resource, registered by its oracle name.
FfxResource external(const char* label, uint32_t width, uint32_t height);
// An ffxMessageCallback that prints ["message",type,"<text>"].
void recordMessage(uint32_t type, const wchar_t* message);
// Prints ["<kind>",status], e.g. "create-result" or "dispatch-result".
void result(const char* kind, FfxErrorCode status);
// Prints ["frame",index] and releases the previous frame's staged constants.
void frame(uint32_t index);
// Defined by the effect driver; returns the process exit status.
int runEffect();
