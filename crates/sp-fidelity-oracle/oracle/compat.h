// Platform declarations for compiling the unchanged SDK CPU source on macOS.
// No effect code, resource mapping or numerical calculations belong here.
#pragma once
#include <cstddef>
#include <cwchar>
#include <cstdlib>
#include <cstring>
#ifndef _WIN32
template <class T, size_t N> constexpr size_t _countof(const T (&)[N]) { return N; }
// The SDK's opaque context sizes assume Windows' 16-bit wchar_t. The oracle is
// compiled with -fshort-wchar. Do not pass these strings to the macOS wide CRT,
// whose wchar_t is 32-bit; only SDK debug/resource names use this shim.
inline int sdk_wcscmp(const wchar_t* a, const wchar_t* b) {
    while (*a && *a == *b) { ++a; ++b; }
    return (*a > *b) - (*a < *b);
}
#define wcscmp sdk_wcscmp
template <size_t N> int wcscpy_s(wchar_t (&target)[N], const wchar_t* source) {
    size_t count = 0;
    while (source[count]) ++count;
    if (count >= N) std::abort();
    for (size_t i = 0; i <= count; ++i) target[i] = source[i];
    return 0;
}
#endif
