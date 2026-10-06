// Independent Metal execution of AMD C++ host JSONL jobs and original HLSL-derived MSL.
// Build: clang++ -std=c++17 -fobjc-arc oracle/metal.mm -framework Foundation -framework Metal -o metal-oracle
// <shader-dir> holds one directory per compiled permutation (tools/compile_dxc_oracle.py);
// each pipeline event selects the variant compiled for its pass and permutation options.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <stdexcept>
#include <string>
#include <tuple>
#include <vector>

namespace fs = std::filesystem;
static NSString* ns(const std::string& s) { return [NSString stringWithUTF8String:s.c_str()]; }
static std::string str(id value) { return [(NSString*)value UTF8String]; }
static size_t num(id value) { return [(NSNumber*)value unsignedLongLongValue]; }
static void fail(const std::string& what, NSError* error = nil) {
    throw std::runtime_error(what + (error ? ": " + str(error.localizedDescription) : ""));
}
static id json(const fs::path& path) {
    NSError* error = nil;
    NSData* data = [NSData dataWithContentsOfFile:ns(path.string()) options:0 error:&error];
    if (!data) fail("read " + path.string(), error);
    id value = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:&error];
    if (!value) fail("JSON " + path.string(), error);
    return value;
}
static std::vector<uint8_t> bytes(const fs::path& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) fail("read " + path.string());
    return {std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
}
static void writeBytes(const fs::path& path, const void* data, size_t size) {
    fs::create_directories(path.parent_path());
    std::ofstream file(path, std::ios::binary);
    file.write(static_cast<const char*>(data), size);
    if (!file) fail("write " + path.string());
}
static void writeJson(const fs::path& path, id object) {
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:object options:NSJSONWritingPrettyPrinted error:&error];
    if (!data) fail("serialize " + path.string(), error);
    writeBytes(path, data.bytes, data.length);
}
struct PixelFormat { MTLPixelFormat metal; size_t bytes; };
static PixelFormat format(size_t value) {
    switch (value) {
        case 3: return {MTLPixelFormatRGBA32Float, 16};
        case 4: return {MTLPixelFormatRGBA16Float, 8};
        case 6: return {MTLPixelFormatRG32Float, 8};
        case 8: return {MTLPixelFormatR32Uint, 4};
        case 10: return {MTLPixelFormatRGBA8Unorm, 4};
        case 16: return {MTLPixelFormatRG11B10Float, 4};
        case 17: return {MTLPixelFormatRGB10A2Unorm, 4};
        case 18: return {MTLPixelFormatRG16Float, 4};
        case 21: return {MTLPixelFormatR16Float, 2};
        case 24: return {MTLPixelFormatR16Snorm, 2};
        case 25: return {MTLPixelFormatR8Unorm, 1};
        case 26: return {MTLPixelFormatRG8Unorm, 2};
        case 28: return {MTLPixelFormatR32Float, 4};
        default: fail("unsupported FfxSurfaceFormat " + std::to_string(value));
    }
    __builtin_unreachable();
}
// One texel of a ClearFloat colour in an SDK format, as the D3D12 backend's
// ClearUnorderedAccessViewFloat stores it. Formats without an exact encoding
// here accept only zero.
static std::vector<uint8_t> clearTexel(size_t fmt, const float color[4]) {
    std::vector<uint8_t> texel(format(fmt).bytes, 0);
    auto put = [&](auto value, size_t channel) { std::memcpy(texel.data() + channel * sizeof value, &value, sizeof value); };
    size_t channels = 0;
    switch (fmt) {
        case 3: channels = 4; break;
        case 6: channels = 2; break;
        case 28: channels = 1; break;
        case 4: for (size_t c = 0; c < 4; ++c) put(_Float16(color[c]), c); return texel;
        case 18: for (size_t c = 0; c < 2; ++c) put(_Float16(color[c]), c); return texel;
        case 21: put(_Float16(color[0]), 0); return texel;
        case 10: case 25: case 26:
            for (size_t c = 0; c < texel.size(); ++c)
                texel[c] = uint8_t(std::lround(std::clamp(color[c], 0.f, 1.f) * 255.f));
            return texel;
        default:
            for (size_t c = 0; c < 4; ++c) if (color[c] != 0.f) fail("nonzero clear of FfxSurfaceFormat " + std::to_string(fmt));
            return texel;
    }
    for (size_t c = 0; c < channels; ++c) put(color[c], c);
    return texel;
}
struct Resource {
    id<MTLBuffer> buffer = nil;
    id<MTLTexture> texture = nil;
    size_t surfaceFormat = 0, width = 0, height = 1, layers = 1, mips = 1;
    size_t logicalBytes = 0;
};
struct Pipeline {
    id<MTLComputePipelineState> state = nil;
    NSDictionary* reflection = nil;
    id<MTLBuffer> diagnosticTrace = nil;
    std::vector<id<MTLSamplerState>> samplers;
    MTLSize workgroup = MTLSizeMake(1, 1, 1);
};
class Oracle {
    id<MTLDevice> device;
    id<MTLCommandQueue> queue;
    fs::path shaderDir, inputDir, outputDir, replayDir;
    std::map<std::string, Resource> resources;
    std::map<size_t, Pipeline> pipelines;
    // Pass names by SDK pass value, and the variant directory of each compiled (pass, options).
    std::vector<std::string> names;
    std::map<std::pair<std::string, size_t>, fs::path> variants;
    size_t forceWave64Flag = 0;
    std::set<std::string> externals;
    size_t frame = 0;
    std::string compilerMode;
    NSDictionary* compilerOptions = nil;
    NSArray* inputFrames = nil;
    bool captureInputs = false;
    bool privateTextures;
    bool privateBuffers;
    size_t timeRepeats;
    NSMutableArray* measurements = [NSMutableArray array];

    Resource& resource(const std::string& name) {
        auto it = resources.find(name);
        if (it == resources.end()) fail("trace references missing resource " + name);
        return it->second;
    }
    void finish(id<MTLCommandBuffer> command, const std::string& label) {
        command.label = ns(label);
        [command commit];
        [command waitUntilCompleted];
        if (command.status != MTLCommandBufferStatusCompleted) fail(label, command.error);
    }
    id<MTLBuffer> readBuffer(Resource& r) {
        if (!privateBuffers) return r.buffer;
        id<MTLBuffer> staging = [device newBufferWithLength:r.buffer.length options:MTLResourceStorageModeShared];
        if (!staging) fail("allocate buffer readback staging");
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLBlitCommandEncoder> encoder = [command blitCommandEncoder];
        [encoder copyFromBuffer:r.buffer sourceOffset:0 toBuffer:staging destinationOffset:0 size:r.buffer.length];
        [encoder endEncoding]; finish(command, "private buffer readback");
        return staging;
    }
    void upload(Resource& r, const std::vector<uint8_t>* contents = nullptr) {
        if (r.buffer) {
            id<MTLBuffer> target = privateBuffers ? [device newBufferWithLength:r.buffer.length options:MTLResourceStorageModeShared] : r.buffer;
            if (!target) fail("allocate buffer upload staging");
            std::memset(target.contents, 0, target.length);
            if (contents) {
                if (contents->size() > r.buffer.length) fail("buffer input exceeds allocation");
                std::memcpy(target.contents, contents->data(), contents->size());
            }
            if (privateBuffers) {
                id<MTLCommandBuffer> command = [queue commandBuffer];
                id<MTLBlitCommandEncoder> encoder = [command blitCommandEncoder];
                [encoder copyFromBuffer:target sourceOffset:0 toBuffer:r.buffer destinationOffset:0 size:r.buffer.length];
                [encoder endEncoding]; finish(command, "private buffer upload");
            }
            return;
        }
        size_t offset = 0;
        const size_t stride = format(r.surfaceFormat).bytes;
        for (size_t mip = 0; mip < r.mips; ++mip) {
            const size_t width = std::max(size_t(1), r.width >> mip);
            const size_t height = std::max(size_t(1), r.height >> mip);
            const size_t row = width * stride, size = row * height;
            std::vector<uint8_t> zero;
            if (!contents) zero.resize(size, 0);
            for (size_t layer = 0; layer < r.layers; ++layer) {
                if (contents && offset + size > contents->size()) fail("truncated texture input");
                const void* data = contents ? contents->data() + offset : zero.data();
                if (privateTextures) {
                    const size_t pitch = (row + 255) & ~size_t(255);
                    id<MTLBuffer> staging = [device newBufferWithLength:pitch * height options:MTLResourceStorageModeShared];
                    if (!staging) fail("allocate texture upload staging");
                    for (size_t y = 0; y < height; ++y)
                        std::memcpy(static_cast<uint8_t*>(staging.contents) + y * pitch,
                                    static_cast<const uint8_t*>(data) + y * row, row);
                    id<MTLCommandBuffer> command = [queue commandBuffer];
                    id<MTLBlitCommandEncoder> encoder = [command blitCommandEncoder];
                    [encoder copyFromBuffer:staging sourceOffset:0 sourceBytesPerRow:pitch sourceBytesPerImage:pitch * height
                                 sourceSize:MTLSizeMake(width, height, 1) toTexture:r.texture destinationSlice:layer
                           destinationLevel:mip destinationOrigin:MTLOriginMake(0, 0, 0)];
                    [encoder endEncoding]; finish(command, "private texture upload");
                } else [r.texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                               mipmapLevel:mip slice:layer withBytes:data
                               bytesPerRow:row bytesPerImage:size];
                offset += size;
            }
        }
        if (contents && offset != contents->size()) fail("texture input contains extra bytes");
    }
    void create(const std::string& name, bool buffer, size_t fmt, size_t width,
                size_t height, size_t mips, size_t layers, size_t usage, bool cube) {
        Resource r;
        // A zero mip count requests the full chain, as the SDK backends allocate it.
        if (!buffer && mips == 0) while ((std::max(width, height) >> mips) > 0) ++mips;
        r.surfaceFormat = fmt; r.width = width; r.height = height;
        r.layers = layers; r.mips = mips;
        if (buffer) {
            r.logicalBytes = width;
            // The original SPD descriptor is one byte, while its shader uses a
            // u32 atomic. Match the wgpu allocation adapter's four-byte minimum.
            r.buffer = [device newBufferWithLength:std::max(size_t(4), (width + 3) & ~size_t(3))
                                          options:privateBuffers ? MTLResourceStorageModePrivate : MTLResourceStorageModeShared];
            if (!r.buffer) fail("allocate buffer " + name);
            r.buffer.label = ns(name);
        } else {
            if (!width || !height || !mips) fail("invalid original texture extent/mips for " + name);
            if ((!cube && layers != 1) || (cube && (layers != 6 || width != height)))
                fail("unsupported external texture shape for " + name);
            MTLTextureDescriptor* desc = [[MTLTextureDescriptor alloc] init];
            desc.textureType = cube ? MTLTextureTypeCube : MTLTextureType2D;
            desc.pixelFormat = format(fmt).metal;
            desc.width = width; desc.height = height;
            desc.mipmapLevelCount = mips;
            desc.storageMode = privateTextures ? MTLStorageModePrivate : MTLStorageModeShared;
            desc.usage = MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView;
            if (usage & 2) desc.usage |= MTLTextureUsageShaderWrite;
            // --time: the usage wgpu-hal 30 gives sp-fidelity-wgpu's
            // allocation (metal/conv.rs map_texture_usage), without which
            // Metal's lossless compression and texture atomics differ.
            if (timeRepeats) {
                desc.usage &= ~MTLTextureUsagePixelFormatView;
                if (usage & (1 | 4)) desc.usage |= MTLTextureUsageRenderTarget;
                if (@available(macOS 14.0, *))
                    if ((usage & 2) && fmt == 8) desc.usage |= MTLTextureUsageShaderAtomic;
            }
            r.texture = [device newTextureWithDescriptor:desc];
            if (!r.texture) fail("allocate texture " + name);
            r.texture.label = ns(name);
        }
        upload(r);
        resources[name] = r;
    }
    static MTLSamplerAddressMode address(size_t value) {
        switch (value) {
            case 0: return MTLSamplerAddressModeRepeat;
            case 1: return MTLSamplerAddressModeMirrorRepeat;
            case 2: return MTLSamplerAddressModeClampToEdge;
            case 3: return MTLSamplerAddressModeClampToBorderColor;
            case 4: return MTLSamplerAddressModeMirrorClampToEdge;
            default: fail("unsupported original sampler address mode");
        }
        __builtin_unreachable();
    }
    void loadVariants() {
        for (const auto& entry : fs::directory_iterator(shaderDir)) {
            if (!fs::exists(entry.path() / "manifest.json")) continue;
            NSDictionary* manifest = json(entry.path() / "manifest.json");
            std::vector<std::string> stages;
            for (NSString* stage in (NSArray*)manifest[@"stages"]) stages.push_back(str(stage));
            if (!names.empty() && names != stages) fail("variants disagree on the effect's passes: " + entry.path().string());
            names = stages;
            forceWave64Flag = num(manifest[@"forceWave64Flag"]);
            NSDictionary* passes = manifest[@"passes"];
            for (NSString* pass in passes) {
                const auto key = std::make_pair(str(pass), num(passes[pass][@"permutationOptions"]));
                if (variants.count(key)) fail("pass " + key.first + " compiled twice for options " + std::to_string(key.second));
                variants[key] = entry.path();
            }
        }
        if (names.empty()) fail("no compiled variants in " + shaderDir.string());
    }
    void pipeline(NSArray* event) {
        const size_t stage = num(event[1]), flags = num(event[2]);
        if (stage >= names.size()) fail("unsupported pass ID");
        if (flags & forceWave64Flag) fail("original trace requires force-wave64; this Metal oracle cannot enforce it");
        // The trace selects the permutation; only the variant compiled for it may run.
        const auto variant = variants.find({names[stage], flags});
        if (variant == variants.end())
            fail("no compiled variant of " + names[stage] + " for permutation options " + std::to_string(flags));
        const fs::path directory = variant->second;
        Pipeline p;
        p.reflection = json(directory / (names[stage] + ".reflection.json"));
        // Only temporary instrumented shaders declare this sidecar. Ordinary
        // generated shaders and original algorithm resources are unchanged.
        NSDictionary* diagnostic = p.reflection[@"diagnosticTrace"];
        if (diagnostic) {
            p.diagnosticTrace = [device newBufferWithLength:num(diagnostic[@"byteSize"])
                                                    options:MTLResourceStorageModeShared];
            if (!p.diagnosticTrace) fail("allocate diagnostic trace sidecar");
        }
        NSArray* group = p.reflection[@"workgroupSize"];
        p.workgroup = MTLSizeMake(num(group[0]), num(group[1]), num(group[2]));
        NSError* error = nil;
        NSString* source = [NSString stringWithContentsOfFile:ns((directory / (names[stage] + ".metal")).string())
                                                   encoding:NSUTF8StringEncoding error:&error];
        if (!source) fail("read native Metal shader", error);
        MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
        if (compilerMode == "strict") {
            options.languageVersion = MTLLanguageVersion2_3;
            options.fastMathEnabled = NO;
        } else if (compilerMode == "wgpu") {
            // Match wgpu-hal 30 metal/adapter.rs and metal/device.rs.
            // Crucially, wgpu leaves fast math at MTLCompileOptions' default.
            if (@available(macOS 26.0, *)) options.languageVersion = MTLLanguageVersion4_0;
            else if (@available(macOS 15.0, *)) options.languageVersion = MTLLanguageVersion3_2;
            else if (@available(macOS 14.0, *)) options.languageVersion = MTLLanguageVersion3_1;
            else if (@available(macOS 13.0, *)) options.languageVersion = MTLLanguageVersion3_0;
            else if (@available(macOS 12.0, *)) options.languageVersion = MTLLanguageVersion2_4;
            else options.languageVersion = MTLLanguageVersion2_3;
            options.preserveInvariance = YES;
        }
        compilerOptions = @{@"mode":ns(compilerMode), @"languageVersion":@(options.languageVersion),
            @"fastMathEnabled":@(options.fastMathEnabled), @"preserveInvariance":@(options.preserveInvariance)};
        id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
        if (!library) fail("Metal library " + names[stage], error);
        NSString* entry = p.reflection[@"metalEntryPoint"] ?: @"main0";
        id<MTLFunction> function = [library newFunctionWithName:entry];
        if (!function) fail("missing native Metal entry point");
        p.state = [device newComputePipelineStateWithFunction:function error:&error];
        if (!p.state) fail("Metal pipeline " + names[stage], error);
        for (NSArray* original in (NSArray*)event[5]) {
            MTLSamplerDescriptor* desc = [[MTLSamplerDescriptor alloc] init];
            const size_t filter = num(original[0]);
            if (filter > 2) fail("unsupported original sampler filter");
            desc.minFilter = desc.magFilter = filter == 0 ? MTLSamplerMinMagFilterNearest : MTLSamplerMinMagFilterLinear;
            desc.mipFilter = filter == 1 ? MTLSamplerMipFilterLinear : MTLSamplerMipFilterNearest;
            desc.sAddressMode = address(num(original[1]));
            desc.tAddressMode = address(num(original[2]));
            desc.rAddressMode = address(num(original[3]));
            desc.normalizedCoordinates = YES;
            id<MTLSamplerState> sampler = [device newSamplerStateWithDescriptor:desc];
            if (!sampler) fail("create original sampler");
            p.samplers.push_back(sampler);
        }
        pipelines[stage] = p;
        std::cout << "pipeline " << names[stage] << " execution_width=" << p.state.threadExecutionWidth << '\n';
    }
    void dump(const std::string& name, const fs::path& directory, bool onlyBase = false) {
        Resource& r = resource(name);
        if (r.buffer) {
            id<MTLBuffer> data = readBuffer(r);
            writeBytes(directory / (name + ".bin"), data.contents, data.length);
            return;
        }
        const size_t stride = format(r.surfaceFormat).bytes;
        for (size_t mip = 0; mip < (onlyBase ? 1 : r.mips); ++mip) {
            const size_t width = std::max(size_t(1), r.width >> mip);
            const size_t height = std::max(size_t(1), r.height >> mip);
            const size_t row = width * stride, size = row * height;
            std::vector<uint8_t> data(size * r.layers);
            for (size_t layer = 0; layer < r.layers; ++layer) {
                if (privateTextures) {
                    const size_t pitch = (row + 255) & ~size_t(255);
                    id<MTLBuffer> staging = [device newBufferWithLength:pitch * height options:MTLResourceStorageModeShared];
                    if (!staging) fail("allocate texture readback staging");
                    id<MTLCommandBuffer> command = [queue commandBuffer];
                    id<MTLBlitCommandEncoder> encoder = [command blitCommandEncoder];
                    [encoder copyFromTexture:r.texture sourceSlice:layer sourceLevel:mip sourceOrigin:MTLOriginMake(0, 0, 0)
                                 sourceSize:MTLSizeMake(width, height, 1) toBuffer:staging destinationOffset:0
                     destinationBytesPerRow:pitch destinationBytesPerImage:pitch * height];
                    [encoder endEncoding]; finish(command, "private texture readback");
                    for (size_t y = 0; y < height; ++y)
                        std::memcpy(data.data() + layer * size + y * row,
                                    static_cast<const uint8_t*>(staging.contents) + y * pitch, row);
                } else [r.texture getBytes:data.data() + layer * size bytesPerRow:row bytesPerImage:size
                          fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:mip slice:layer];
            }
            writeBytes(directory / (name + ".mip-" + std::to_string(mip) + ".bin"), data.data(), data.size());
        }
    }
    void replay(NSArray* event, size_t stage) {
        if (replayDir.empty()) return;
        const fs::path directory = replayDir / ("frame-" + std::to_string(frame)) / names[stage];
        std::set<std::string> namesToLoad;
        for (NSArray* binding in (NSArray*)event[5]) namesToLoad.insert(str(binding[2]));
        const std::string indirect = str(event[3]);
        if (indirect != "NULL") namesToLoad.insert(indirect);
        for (const auto& name : namesToLoad) {
            Resource& r = resource(name);
            std::vector<uint8_t> data;
            if (r.buffer) {
                data = bytes(directory / (name + ".bin"));
                if (data.size() != r.buffer.length) fail("replay buffer size differs for " + name);
            } else {
                const size_t stride = format(r.surfaceFormat).bytes;
                for (size_t mip = 0; mip < r.mips; ++mip) {
                    auto level = bytes(directory / (name + ".mip-" + std::to_string(mip) + ".bin"));
                    const size_t expected = std::max(size_t(1), r.width >> mip)
                        * std::max(size_t(1), r.height >> mip) * r.layers * stride;
                    if (level.size() != expected) fail("replay texture size differs for " + name);
                    data.insert(data.end(), level.begin(), level.end());
                }
            }
            upload(r, &data);
        }
    }
    void compute(NSArray* event) {
        const size_t stage = num(event[1]);
        Pipeline& p = pipelines.at(stage);
        replay(event, stage);
        std::map<std::string, std::vector<NSArray*>> bindings;
        std::map<std::string, NSArray*> constantBuffers;
        for (NSArray* cb in (NSArray*)event[6]) constantBuffers[str(cb[0])] = cb[1];
        std::set<std::string> written;
        for (NSArray* binding in (NSArray*)event[5]) {
            bindings[str(binding[1])].push_back(binding);
            if (str(binding[0]) != "srv") written.insert(str(binding[2]));
        }
        if (captureInputs) {
            std::set<std::string> observed;
            for (NSArray* binding in (NSArray*)event[5]) observed.insert(str(binding[2]));
            if (str(event[3]) != "NULL") observed.insert(str(event[3]));
            for (const auto& name : observed)
                dump(name, outputDir / "inputs" / ("frame-" + std::to_string(frame)) / names[stage]);
        }
        // Unexecuted trace points remain NaN, distinguishable from zero.
        if (p.diagnosticTrace) std::memset(p.diagnosticTrace.contents, 0xff, p.diagnosticTrace.length);
        std::array<uint32_t, 3> dispatched{};
        const auto encode = [&](id<MTLComputeCommandEncoder> encoder) {
            [encoder setComputePipelineState:p.state];
            if (p.diagnosticTrace)
                [encoder setBuffer:p.diagnosticTrace offset:0
                           atIndex:num(p.reflection[@"diagnosticTrace"][@"mslIndex"])];
            for (NSDictionary* reflected in (NSArray*)p.reflection[@"resources"]) {
                const std::string kind = str(reflected[@"kind"]);
                if (kind == "constant_buffer") {
                    const auto cb = constantBuffers.find(str(reflected[@"name"]));
                    if (cb == constantBuffers.end()) fail("job binds no constants for " + str(reflected[@"name"]));
                    const size_t capacity = num(reflected[@"byteSize"]);
                    NSArray* values = cb->second;
                    if (values.count * 4 > capacity) fail("original constants exceed reflected buffer");
                    std::vector<uint8_t> data(capacity, 0);
                    for (NSUInteger i = 0; i < values.count; ++i) {
                        const uint32_t value = uint32_t(num(values[i]));
                        std::memcpy(data.data() + i * 4, &value, 4);
                    }
                    [encoder setBytes:data.data() length:capacity atIndex:num(reflected[@"mslIndex"])];
                } else if (kind == "sampler") {
                    [encoder setSamplerState:p.samplers.at(num(reflected[@"register"])) atIndex:num(reflected[@"mslIndex"])];
                } else {
                    const auto& list = bindings.at(str(reflected[@"name"]));
                    NSArray* bound = list.at(num(reflected[@"arrayIndex"]));
                    Resource& r = resource(str(bound[2]));
                    const size_t index = num(reflected[@"mslIndex"]);
                    if (r.buffer) {
                        [encoder setBuffer:r.buffer offset:0 atIndex:index];
                    } else {
                        id<MTLTexture> texture = r.texture;
                        if (str(bound[0]) == "uav") {
                            const size_t mip = num(bound[3]);
                            if (mip >= r.mips) fail("original UAV mip outside allocation");
                            texture = [r.texture newTextureViewWithPixelFormat:r.texture.pixelFormat
                                                                  textureType:MTLTextureType2D
                                                                       levels:NSMakeRange(mip, 1)
                                                                       slices:NSMakeRange(0, 1)];
                            if (!texture) fail("create original UAV mip view");
                        }
                        [encoder setTexture:texture atIndex:index];
                    }
                }
            }
            const std::string indirect = str(event[3]);
            if (indirect != "NULL") {
                Resource& args = resource(indirect);
                const size_t offset = num(event[4]);
                if (!args.buffer || offset + 12 > args.buffer.length) fail("invalid original indirect dispatch range");
                std::memcpy(dispatched.data(), static_cast<uint8_t*>(readBuffer(args).contents) + offset, 12);
                [encoder dispatchThreadgroupsWithIndirectBuffer:args.buffer indirectBufferOffset:offset threadsPerThreadgroup:p.workgroup];
            } else {
                NSArray* dims = event[2];
                for (size_t i = 0; i < 3; ++i) dispatched[i] = uint32_t(num(dims[i]));
                [encoder dispatchThreadgroups:MTLSizeMake(dispatched[0], dispatched[1], dispatched[2]) threadsPerThreadgroup:p.workgroup];
            }
            [encoder endEncoding];
        };
        id<MTLCommandBuffer> command = [queue commandBuffer];
        encode([command computeCommandEncoder]);
        finish(command, names[stage]);
        const fs::path directory = outputDir / ("frame-" + std::to_string(frame)) / names[stage];
        if (p.diagnosticTrace)
            writeBytes(directory / "diagnostic-trace.bin", p.diagnosticTrace.contents, p.diagnosticTrace.length);
        for (const auto& name : written) dump(name, directory);
        NSMutableDictionary* measurement = [@{@"frame": @(frame), @"stage": ns(names[stage]),
            @"executionWidth": @(p.state.threadExecutionWidth),
            @"dispatch": @[@(dispatched[0]), @(dispatched[1]), @(dispatched[2])],
            @"gpuSeconds": @(command.GPUEndTime - command.GPUStartTime)} mutableCopy];
        // --time N: after the dumps, the job again N times back to back in
        // one command buffer, each in its own encoder between stage-boundary
        // timestamps, as wgpu times a compute pass.
        if (timeRepeats) {
            MTLCounterSampleBufferDescriptor* samples = [[MTLCounterSampleBufferDescriptor alloc] init];
            for (id<MTLCounterSet> set in device.counterSets)
                if ([set.name isEqualToString:MTLCommonCounterSetTimestamp]) samples.counterSet = set;
            if (!samples.counterSet) fail("no timestamp counter set");
            samples.storageMode = MTLStorageModeShared;
            samples.sampleCount = 2 * timeRepeats;
            NSError* error = nil;
            id<MTLCounterSampleBuffer> buffer = [device newCounterSampleBufferWithDescriptor:samples error:&error];
            if (!buffer) fail("timestamp sample buffer", error);
            id<MTLCommandBuffer> timed = [queue commandBuffer];
            for (size_t i = 0; i < timeRepeats; ++i) {
                MTLComputePassDescriptor* pass = [MTLComputePassDescriptor computePassDescriptor];
                pass.sampleBufferAttachments[0].sampleBuffer = buffer;
                pass.sampleBufferAttachments[0].startOfEncoderSampleIndex = 2 * i;
                pass.sampleBufferAttachments[0].endOfEncoderSampleIndex = 2 * i + 1;
                encode([timed computeCommandEncoderWithDescriptor:pass]);
            }
            finish(timed, names[stage] + " timing");
            NSData* resolved = [buffer resolveCounterRange:NSMakeRange(0, 2 * timeRepeats)];
            const auto* stamps = static_cast<const MTLCounterResultTimestamp*>(resolved.bytes);
            NSMutableArray* nanoseconds = [NSMutableArray array];
            for (size_t i = 0; i < timeRepeats; ++i)
                [nanoseconds addObject:@(stamps[2 * i + 1].timestamp - stamps[2 * i].timestamp)];
            measurement[@"timedNanoseconds"] = nanoseconds;
        }
        [measurements addObject:measurement];
        std::cout << "frame " << frame << ' ' << names[stage] << " groups="
                  << dispatched[0] << ',' << dispatched[1] << ',' << dispatched[2] << '\n';
    }
    // ClearUnorderedAccessViewFloat on the target's UAV, which is its mip 0.
    void clear(const std::string& name, NSArray* bits) {
        Resource& r = resource(name);
        if (!r.texture) fail("clear of buffer " + name);
        float color[4];
        for (size_t c = 0; c < 4; ++c) { const uint32_t v = uint32_t(num(bits[c])); std::memcpy(&color[c], &v, 4); }
        const auto texel = clearTexel(r.surfaceFormat, color);
        std::vector<uint8_t> data;
        for (size_t i = 0; i < r.width * r.height; ++i) data.insert(data.end(), texel.begin(), texel.end());
        const size_t row = r.width * texel.size();
        if (privateTextures) fail("clear with private textures is not supported");
        [r.texture replaceRegion:MTLRegionMake2D(0, 0, r.width, r.height) mipmapLevel:0 slice:0
                       withBytes:data.data() bytesPerRow:row bytesPerImage:row * r.height];
    }
    void copy(NSArray* event) {
        const std::string from = str(event[1]), to = str(event[2]);
        Resource& source = resource(from); Resource& dest = resource(to);
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLBlitCommandEncoder> encoder = [command blitCommandEncoder];
        if (source.buffer && dest.buffer) {
            const size_t fromOffset = num(event[3]), toOffset = num(event[4]);
            const size_t length = num(event[5]) ? num(event[5]) : source.logicalBytes;
            [encoder copyFromBuffer:source.buffer sourceOffset:fromOffset toBuffer:dest.buffer destinationOffset:toOffset size:length];
        } else if (source.texture && dest.texture) {
            // Mip zero of the whole source, as the SDK backends copy it.
            [encoder copyFromTexture:source.texture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0, 0, 0)
                         sourceSize:MTLSizeMake(source.width, source.height, 1) toTexture:dest.texture
                   destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0, 0, 0)];
        } else fail("mixed buffer/texture copy is not supported by this oracle");
        [encoder endEncoding]; finish(command, "copy " + from + " -> " + to);
        dump(to, outputDir / ("frame-" + std::to_string(frame)) / "copy", true);
    }
public:
    Oracle(fs::path shaders, fs::path inputs, fs::path outputs, std::string mode = "strict", fs::path replay = {}, bool capture = false, bool privateStorage = false, bool privateBufferStorage = false, size_t repeats = 0)
        : shaderDir(std::move(shaders)), inputDir(std::move(inputs)), outputDir(std::move(outputs)),
          replayDir(std::move(replay)), compilerMode(std::move(mode)), captureInputs(capture), privateTextures(privateStorage), privateBuffers(privateBufferStorage), timeRepeats(repeats) {
        device = MTLCreateSystemDefaultDevice();
        if (!device) fail("Metal device unavailable");
        queue = [device newCommandQueue];
        if (!queue) fail("Metal command queue unavailable");
        std::cout << "device " << str(device.name) << '\n';
        loadVariants();
        id manifest = json(inputDir / "inputs.json");
        NSArray* textures = [manifest isKindOfClass:[NSArray class]] ? manifest : manifest[@"textures"];
        inputFrames = [manifest isKindOfClass:[NSArray class]] ? nil : manifest[@"frames"];
        if (!textures) fail("inputs.json must be an array or contain textures");
        for (NSDictionary* desc in textures) {
            const std::string name = str(desc[@"name"]);
            const bool cube = [desc[@"cube"] boolValue];
            externals.insert(name);
            create(name, false, num(desc[@"format"]), num(desc[@"width"]), num(desc[@"height"]),
                   desc[@"mipCount"] ? num(desc[@"mipCount"]) : 1,
                   desc[@"layers"] ? num(desc[@"layers"]) : (cube ? 6 : 1), 0, cube);
            if (desc[@"file"] && desc[@"file"] != [NSNull null]) {
                auto data = bytes(inputDir / str(desc[@"file"])); upload(resource(name), &data);
            }
        }
    }
    void run(const fs::path& trace) {
        std::ifstream file(trace);
        if (!file) fail("read C++ trace " + trace.string());
        std::string line; size_t lineNumber = 0;
        while (std::getline(file, line)) {
            ++lineNumber;
            @autoreleasepool {
                NSError* error = nil;
                NSData* data = [ns(line) dataUsingEncoding:NSUTF8StringEncoding];
                NSArray* event = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (!event) fail("C++ trace line " + std::to_string(lineNumber), error);
                const std::string kind = str(event[0]);
                try {
                    if (kind == "resource") {
                        const std::string name = str(event[1]);
                        const size_t type = num(event[2]), initType = num(event[8]);
                        if (type != 0 && type != 2) fail("unsupported FfxResourceType " + std::to_string(type) + " for " + name);
                        create(name, type == 0, num(event[3]), num(event[4]), num(event[5]), num(event[6]), 1, num(event[7]), false);
                        // FFX_RESOURCE_INIT_DATA_TYPE_BUFFER: the C++ host exported AMD's data.
                        if (initType == 2) { auto data = bytes(inputDir / (name + ".bin")); upload(resource(name), &data); }
                        if (initType == 3 && num(event[10]) != 0) fail("nonzero value initialization of " + name);
                    } else if (kind == "pipeline") pipeline(event);
                    else if (kind == "frame") {
                        frame = num(event[1]);
                        if (inputFrames) {
                            if (frame >= inputFrames.count) fail("missing external input frame");
                            // Only application inputs may change here. No transient,
                            // history, counter or output may be imported by a sequence.
                            for (NSDictionary* update in inputFrames[frame]) {
                                const std::string name = str(update[@"name"]);
                                if (!externals.count(name))
                                    fail("sequence update is not an external input: " + name);
                                auto data = bytes(inputDir / str(update[@"file"]));
                                upload(resource(name), &data);
                            }
                        }
                    }
                    else if (kind == "clear") clear(str(event[1]), event[2]);
                    else if (kind == "compute") compute(event);
                    else if (kind == "copy") copy(event);
                    else if (kind == "create-result" && num(event[1])) fail("original C++ context creation failed");
                    else if (kind == "dispatch-result" && num(event[1]))
                        fail("original C++ rejected GPU frame " + std::to_string(frame) + " with status " + std::to_string([event[1] longLongValue]));
                    else if (kind != "create-result" && kind != "dispatch-result" && kind != "destroy-result"
                             && kind != "constants" && kind != "execute" && kind != "unregister" && kind != "destroy-context"
                             && kind != "destroy-resource" && kind != "destroy-pipeline" && kind != "register"
                             && kind != "message" && kind != "memory-usage" && kind != "memory-usage-result"
                             && kind != "generate-reactive-result")
                        fail("unsupported original trace event " + kind);
                    // Execute is already ordered by synchronous command completion;
                    // compute jobs carry their constants; registration, messages,
                    // memory queries and unregister/destroy/result records do not
                    // change GPU contents.
                } catch (const std::exception& e) {
                    fail("trace line " + std::to_string(lineNumber) + " (" + kind + "): " + e.what());
                }
            }
        }
        NSMutableArray* descriptions = [NSMutableArray array];
        for (const auto& [name, r] : resources) {
            [descriptions addObject:@{@"name":ns(name), @"format":@(r.surfaceFormat),
                @"width":@(r.width), @"height":@(r.height), @"layers":@(r.layers), @"mipCount":@(r.mips),
                @"buffer":@(r.buffer != nil), @"logicalBytes":@(r.logicalBytes), @"physicalBytes":@(r.buffer ? r.buffer.length : 0)}];
        }
        writeJson(outputDir / "run.json", @{@"adapter":device.name, @"trace":ns(trace.string()),
            @"compilerOptions":compilerOptions ?: @{},
            @"replayDirectory":ns(replayDir.string()),
            @"externalInputFrames":@(inputFrames ? inputFrames.count : 0),
            @"capturedPassInputs":@(captureInputs),
            @"textureStorage":privateTextures ? @"private" : @"shared",
            @"bufferStorage":privateBuffers ? @"private" : @"shared",
            @"shaderDirectory":ns(shaderDir.string()), @"source":@"original AMD C++ host jobs and original HLSL-derived native Metal",
            @"initialization":@"all allocations zeroed before optional original data upload", @"resources":descriptions,
            @"passes":measurements});
    }
};
int main(int argc, char** argv) {
    @autoreleasepool {
        @try {
            try {
                std::string mode = "strict";
                fs::path replay;
                bool capture = false;
                bool privateStorage = false;
                bool privateBufferStorage = false;
                size_t repeats = 0;
                std::vector<std::string> positional;
                for (int i = 1; i < argc; ++i) {
                    std::string argument = argv[i];
                    if (argument == "--compiler-mode" || argument == "--replay" || argument == "--time") {
                        if (++i == argc) fail("missing value for " + argument);
                        if (argument == "--compiler-mode") mode = argv[i];
                        else if (argument == "--time") repeats = std::stoul(argv[i]);
                        else replay = argv[i];
                    } else if (argument == "--capture-inputs") capture = true;
                    else if (argument == "--private-textures") privateStorage = true;
                    else if (argument == "--private-buffers") privateBufferStorage = true;
                    else if (argument.rfind("--", 0) == 0) fail("unknown oracle option " + argument);
                    else positional.push_back(argument);
                }
                if (positional.size() != 4 || (mode != "strict" && mode != "wgpu" && mode != "passthrough"))
                    fail("usage: metal-oracle [--compiler-mode strict|wgpu|passthrough] [--replay input-snapshot-dir] [--capture-inputs] [--private-textures] [--private-buffers] [--time repetitions] <shader-dir> <cpp-trace.jsonl> <input-dir> <output-dir>");
                Oracle oracle(positional[0], positional[2], positional[3], mode, replay, capture, privateStorage, privateBufferStorage, repeats);
                oracle.run(positional[1]); return 0;
            } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
        } @catch (NSException* error) { std::cerr << str(error.reason) << '\n'; return 1; }
    }
}
