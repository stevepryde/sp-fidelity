// Platform declarations for compiling the unchanged SDK CPU source on macOS.
// No effect code, resource mapping or numerical calculations belong here.
#pragma once
#include <cstddef>
#include <cwchar>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <cstdio>
#include <fstream>
#include <filesystem>
#include <sstream>
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

// libc++'s explicit std::wstring instantiation also uses the native 32-bit
// wchar_t ABI. A distinct traits type keeps SDK wide-string operations in
// this translation unit, where sizeof(wchar_t) is two.
struct sdk_wchar_traits : std::char_traits<wchar_t> {
    static size_t length(const wchar_t* p) { size_t n = 0; while (p[n]) ++n; return n; }
    static int compare(const wchar_t* a, const wchar_t* b, size_t n) {
        for (size_t i = 0; i < n; ++i) { if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1; }
        return 0;
    }
    static const wchar_t* find(const wchar_t* p, size_t n, const wchar_t& c) {
        for (size_t i = 0; i < n; ++i) if (p[i] == c) return p + i;
        return nullptr;
    }
    static wchar_t* copy(wchar_t* dst, const wchar_t* src, size_t n) {
        std::memcpy(dst, src, n * sizeof(wchar_t)); return dst;
    }
    static wchar_t* move(wchar_t* dst, const wchar_t* src, size_t n) {
        std::memmove(dst, src, n * sizeof(wchar_t)); return dst;
    }
    static wchar_t* assign(wchar_t* p, size_t n, wchar_t c) {
        for (size_t i = 0; i < n; ++i) p[i] = c; return p;
    }
    static void assign(wchar_t& target, const wchar_t& value) { target = value; }
};
template <class T> std::vector<wchar_t> sdk_to_wchars(T value) {
    const auto decimal = std::to_string(value);
    std::vector<wchar_t> result(decimal.begin(), decimal.end()); result.push_back(0); return result;
}
#define wstring basic_string<wchar_t, ::sdk_wchar_traits>
#define to_wstring(value) basic_string<wchar_t, ::sdk_wchar_traits>(::sdk_to_wchars(value).data())

// Windows wide printf interprets %s as a wide string. This is the sole
// formatting pattern used by the composite SDK host's shared-resource names.
inline int sdk_swprintf(wchar_t* target, size_t capacity, const wchar_t* format,
                        const wchar_t* prefix, int index) {
    if (sdk_wcscmp(format, L"%s%d") != 0) std::abort();
    const auto digits = sdk_to_wchars(index);
    const size_t prefixLength = sdk_wchar_traits::length(prefix);
    const size_t count = prefixLength + digits.size() - 1;
    if (count >= capacity) return -1;
    sdk_wchar_traits::copy(target, prefix, prefixLength);
    sdk_wchar_traits::copy(target + prefixLength, digits.data(), digits.size());
    return int(count);
}
#define swprintf sdk_swprintf

#endif
