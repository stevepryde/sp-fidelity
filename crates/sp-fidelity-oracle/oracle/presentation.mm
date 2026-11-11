// Executes AMD's unchanged UI HLSL after DXC/SPIRV-Cross translation to MSL.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <fstream>
#include <vector>
#include <string>
#include <stdexcept>
static NSString* ns(const std::string& s){return [NSString stringWithUTF8String:s.c_str()];}
static std::vector<uint8_t> read(const std::string& path){std::ifstream f(path,std::ios::binary);if(!f)throw std::runtime_error("read "+path);return {std::istreambuf_iterator<char>(f),{}};}
static void check(bool ok,NSError* e=nullptr){if(!ok)throw std::runtime_error(e?e.localizedDescription.UTF8String:"Metal operation failed");}
int main(int argc,char** argv){@autoreleasepool {
    if(argc!=3)return 2;
    const std::string shaders=argv[1],directory=argv[2];
    id<MTLDevice> device=MTLCreateSystemDefaultDevice();check(device!=nil);id<MTLCommandQueue> queue=[device newCommandQueue];
    auto make=[&](){auto* d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:64 height:4 mipmapped:NO];d.usage=MTLTextureUsageShaderRead|MTLTextureUsageRenderTarget;d.storageMode=MTLStorageModeShared;return [device newTextureWithDescriptor:d];};
    id<MTLTexture> scene=make(),ui=make();auto sceneBytes=read(directory+"/scene.bin"),uiBytes=read(directory+"/ui.bin");
    check(sceneBytes.size()==64*4*4&&uiBytes.size()==sceneBytes.size());
    [scene replaceRegion:MTLRegionMake2D(0,0,64,4) mipmapLevel:0 withBytes:sceneBytes.data() bytesPerRow:256];
    [ui replaceRegion:MTLRegionMake2D(0,0,64,4) mipmapLevel:0 withBytes:uiBytes.data() bytesPerRow:256];
    auto library=[&](const std::string& name){auto code=read(shaders+"/"+name+".metal");auto* options=[MTLCompileOptions new];options.fastMathEnabled=NO;options.languageVersion=MTLLanguageVersion3_1;NSError* error=nil;id<MTLLibrary> lib=[device newLibraryWithSource:ns(std::string(code.begin(),code.end())) options:options error:&error];check(lib!=nil,error);return lib;};
    id<MTLLibrary> vertex=library("vertex");
    for(const std::string mode:{"straight","premultiplied","copy"}){
        id<MTLTexture> output=make();id<MTLCommandBuffer> command=[queue commandBuffer];
        if(mode=="copy") {id<MTLBlitCommandEncoder> blit=[command blitCommandEncoder];[blit copyFromTexture:scene sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0) sourceSize:MTLSizeMake(64,4,1) toTexture:output destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];[blit endEncoding];}
        else {id<MTLLibrary> fragment=library(mode);auto* d=[MTLRenderPipelineDescriptor new];d.vertexFunction=[vertex newFunctionWithName:@"mainVS"];d.fragmentFunction=[fragment newFunctionWithName:@"mainPS"];d.colorAttachments[0].pixelFormat=MTLPixelFormatRGBA8Unorm;NSError* error=nil;id<MTLRenderPipelineState> pipeline=[device newRenderPipelineStateWithDescriptor:d error:&error];check(pipeline!=nil,error);
            auto* pass=[MTLRenderPassDescriptor renderPassDescriptor];pass.colorAttachments[0].texture=output;pass.colorAttachments[0].loadAction=MTLLoadActionClear;pass.colorAttachments[0].storeAction=MTLStoreActionStore;
            id<MTLRenderCommandEncoder> render=[command renderCommandEncoderWithDescriptor:pass];[render setRenderPipelineState:pipeline];[render setFragmentTexture:scene atIndex:0];[render setFragmentTexture:ui atIndex:1];[render drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];[render endEncoding];}
        [command commit];[command waitUntilCompleted];check(command.status==MTLCommandBufferStatusCompleted,command.error);
        std::vector<uint8_t> bytes(64*4*4);[output getBytes:bytes.data() bytesPerRow:256 fromRegion:MTLRegionMake2D(0,0,64,4) mipmapLevel:0];std::ofstream file(directory+"/"+mode+".bin",std::ios::binary);file.write((char*)bytes.data(),bytes.size());
    }
}}
