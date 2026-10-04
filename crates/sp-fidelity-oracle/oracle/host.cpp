// Execute AMD's unchanged host code of an effect through a recording FfxInterface.
// This is a locally supplied backend, not an AMD test or a GPU benchmark.
#include "host.h"
#include <FidelityFX/host/ffx_message.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <stdexcept>

static std::string narrow(const wchar_t* s) { std::string out; while (*s) out += char(*s++); return out; }
static void wide(wchar_t* out, const std::string& s) { for(char c:s) *out++=c; *out=0; }
uint32_t word() { uint32_t v; if(!(std::cin>>v)) throw std::runtime_error("truncated oracle input"); return v; }
float scalar() { uint32_t v=word(); float f; std::memcpy(&f,&v,4); return f; }
// One DXC-reflected resource of a compiled pass variant: pass, permutation options, kind, register, array index, name.
struct Binding { uint32_t stage, options; std::string kind; uint32_t slot, index; std::string name; };
struct Stored { FfxResourceDescription desc; std::string name; };
static std::vector<Binding> bindings;
static std::map<int,Stored> resources;
static std::vector<std::unique_ptr<uint32_t[]>> constants;
static std::string dataDirectory;
static int nextResource=1;
static uint32_t nextContext=0;
static FfxDeviceCapabilities capabilities{};
static std::string name(FfxResourceInternal r) { return r.internalIndex ? resources.at(r.internalIndex).name : "NULL"; }
static void quoted(const std::string& s) { std::cout << '"' << s << '"'; }
static void words(const void* data,size_t count) {
    auto p=static_cast<const uint32_t*>(data);std::cout<<'[';
    for(size_t i=0;i<count;i++) { if(i)std::cout<<',';std::cout<<p[i]; }
    std::cout<<']';
}
static FfxErrorCode createPipeline(FfxInterface*,FfxEffect,FfxPass pass,uint32_t flags,const FfxPipelineDescription* desc,FfxUInt32,FfxPipelineState* out) {
    *out={}; out->passId=pass; out->pipeline=reinterpret_cast<void*>(uintptr_t(pass+1));
    out->cmdSignature=desc->indirectWorkload ? reinterpret_cast<void*>(1) : nullptr;
    wcscpy_s(out->name,desc->name);
    bool compiled=false;
    for(const auto& b:bindings) if(b.stage==pass && b.options==flags) {
        compiled=true;
        FfxResourceBinding* dest=nullptr;
        if(b.kind=="srv")dest=&out->srvTextureBindings[out->srvTextureCount++];
        else if(b.kind=="uav")dest=&out->uavTextureBindings[out->uavTextureCount++];
        else if(b.kind=="buffer")dest=&out->uavBufferBindings[out->uavBufferCount++];
        else if(b.kind=="cb")dest=&out->constantBufferBindings[out->constCount++];
        else throw std::runtime_error("unknown reflection kind");
        dest->slotIndex=b.slot;dest->arrayIndex=b.index;wide(dest->name,b.name);
    }
    if(!compiled)throw std::runtime_error("no compiled shader variant for pass "+std::to_string(pass)+" options "+std::to_string(flags));
    std::cout<<"[\"pipeline\","<<pass<<','<<flags<<','<<desc->indirectWorkload<<",[";
    for(uint32_t i=0;i<desc->rootConstantBufferCount;i++) { if(i)std::cout<<',';std::cout<<desc->rootConstants[i].size; }
    std::cout<<"],[";
    for(uint32_t i=0;i<desc->samplerCount;i++) { if(i)std::cout<<',';auto s=desc->samplers[i];std::cout<<'['<<s.filter<<','<<s.addressModeU<<','<<s.addressModeV<<','<<s.addressModeW<<','<<s.stage<<']'; }
    std::cout<<"],";quoted(narrow(desc->name));std::cout<<','<<desc->contextFlags<<','<<desc->stage<<','<<desc->backbufferFormat<<",[";
    for(uint32_t i=0;i<desc->rootConstantBufferCount;i++) { if(i)std::cout<<',';std::cout<<desc->rootConstants[i].stage; }
    std::cout<<"]]\n";
    return FfxErrorCode(FFX_OK);
}
static FfxErrorCode schedule(FfxInterface*,const FfxGpuJobDescription* job) {
    if(job->jobType==FFX_GPU_JOB_CLEAR_FLOAT) {
        std::cout<<"[\"clear\",";quoted(name(job->clearJobDescriptor.target));std::cout<<',';words(job->clearJobDescriptor.color,4);std::cout<<',';quoted(narrow(job->jobLabel));std::cout<<"]\n";
    } else if(job->jobType==FFX_GPU_JOB_COPY) {
        auto c=job->copyJobDescriptor;std::cout<<"[\"copy\",";quoted(name(c.src));std::cout<<',';quoted(name(c.dst));std::cout<<','<<c.srcOffset<<','<<c.dstOffset<<','<<c.size<<',';quoted(narrow(job->jobLabel));std::cout<<"]\n";
    } else if(job->jobType==FFX_GPU_JOB_COMPUTE) {
        auto& c=job->computeJobDescriptor;auto& p=c.pipeline;
        std::cout<<"[\"compute\","<<p.passId<<',';words(c.dimensions,3);std::cout<<',';quoted(name(c.cmdArgument));std::cout<<','<<c.cmdArgumentOffset<<",[";
        bool first=true;
        auto resource=[&](const char* kind,const FfxResourceBinding& b,FfxResourceInternal r,uint32_t mip) {
            if(!first)std::cout<<',';first=false;std::cout<<'[';quoted(kind);std::cout<<',';quoted(narrow(b.name));std::cout<<',';quoted(name(r));std::cout<<','<<mip<<','<<b.slotIndex<<','<<b.arrayIndex<<']';
        };
        for(uint32_t i=0;i<p.srvTextureCount;i++)resource("srv",p.srvTextureBindings[i],c.srvTextures[i].resource,0);
        for(uint32_t i=0;i<p.uavTextureCount;i++)resource("uav",p.uavTextureBindings[i],c.uavTextures[i].resource,c.uavTextures[i].mip);
        for(uint32_t i=0;i<p.uavBufferCount;i++)resource("buffer",p.uavBufferBindings[i],c.uavBuffers[i].resource,0);
        std::cout<<"],[";
        for(uint32_t i=0;i<p.constCount;i++) {
            if(i)std::cout<<',';std::cout<<'[';quoted(narrow(p.constantBufferBindings[i].name));std::cout<<',';words(c.cbs[i].data,c.cbs[i].num32BitEntries);std::cout<<','<<p.constantBufferBindings[i].slotIndex<<']';
        }
        std::cout<<"],";quoted(narrow(job->jobLabel));std::cout<<"]\n";
    } else throw std::runtime_error("unhandled SDK GPU job");
    return FfxErrorCode(FFX_OK);
}
FfxInterface backend() {
    FfxInterface b{};b.device=reinterpret_cast<void*>(1);
    b.fpGetSDKVersion=[](FfxInterface*){return FfxVersionNumber(FFX_SDK_MAKE_VERSION(1,1,4));};
    b.fpGetEffectGpuMemoryUsage=[](FfxInterface*,FfxUInt32 id,FfxEffectMemoryUsage* out){std::cout<<"[\"memory-usage\","<<id<<"]\n";*out={};return FfxErrorCode(FFX_OK);};
    b.fpCreateBackendContext=[](FfxInterface*,FfxEffect,FfxEffectBindlessConfig*,FfxUInt32* out){*out=nextContext++;return FfxErrorCode(FFX_OK);};
    b.fpDestroyBackendContext=[](FfxInterface*,FfxUInt32 id){std::cout<<"[\"destroy-context\","<<id<<"]\n";return FfxErrorCode(FFX_OK);};
    b.fpGetDeviceCapabilities=[](FfxInterface*,FfxDeviceCapabilities* out){*out=capabilities;return FfxErrorCode(FFX_OK);};
    b.fpCreateResource=[](FfxInterface*,const FfxCreateResourceDescription* d,FfxUInt32,FfxResourceInternal* out) {
        out->internalIndex=nextResource++; resources[out->internalIndex]={d->resourceDescription,narrow(d->name)};
        if(d->initData.type==FFX_RESOURCE_INIT_DATA_TYPE_BUFFER || d->initData.type==FFX_RESOURCE_INIT_DATA_TYPE_VALUE) {
            resources[nextResource++]={d->resourceDescription,narrow(d->name)+" upload"};
        }
        if(d->initData.type==FFX_RESOURCE_INIT_DATA_TYPE_BUFFER && !dataDirectory.empty()) {
            std::ofstream file(dataDirectory+"/"+narrow(d->name)+".bin",std::ios::binary);
            file.write(static_cast<const char*>(d->initData.buffer),d->initData.size);
            if(!file)throw std::runtime_error("cannot export original initialization data");
        }
        auto r=d->resourceDescription;
        std::cout<<"[\"resource\",";quoted(narrow(d->name));std::cout<<','<<r.type<<','<<r.format<<','<<r.width<<','<<r.height<<','<<r.mipCount<<','<<r.usage<<','<<d->initData.type<<','<<d->initData.size;
        std::cout<<','<<(d->initData.type==FFX_RESOURCE_INIT_DATA_TYPE_VALUE ? unsigned(d->initData.value) : 0u);
        std::cout<<','<<d->heapType<<','<<d->initialState<<','<<d->id<<','<<r.depth<<','<<r.flags<<"]\n";
        return FfxErrorCode(FFX_OK);
    };
    b.fpRegisterResource=[](FfxInterface*,const FfxResource* r,FfxUInt32,FfxResourceInternal* out){out->internalIndex=int(reinterpret_cast<uintptr_t>(r->resource));std::cout<<"[\"register\",";quoted(name(*out));std::cout<<"]\n";return FfxErrorCode(FFX_OK);};
    b.fpGetResource=[](FfxInterface*,FfxResourceInternal r){FfxResource out{};out.resource=reinterpret_cast<void*>(uintptr_t(r.internalIndex));out.description=resources.at(r.internalIndex).desc;return out;};
    b.fpGetResourceDescription=[](FfxInterface*,FfxResourceInternal r){return resources.at(r.internalIndex).desc;};
    b.fpUnregisterResources=[](FfxInterface*,FfxCommandList,FfxUInt32 id){std::cout<<"[\"unregister\","<<id<<"]\n";return FfxErrorCode(FFX_OK);};
    b.fpDestroyResource=[](FfxInterface*,FfxResourceInternal r,FfxUInt32){std::cout<<"[\"destroy-resource\",";quoted(name(r));std::cout<<"]\n";return FfxErrorCode(FFX_OK);};
    b.fpStageConstantBufferDataFunc=[](FfxInterface*,void* data,FfxUInt32 bytes,FfxConstantBuffer* cb) {
        constants.push_back(std::make_unique<uint32_t[]>(bytes/4));std::memcpy(constants.back().get(),data,bytes);
        cb->data=constants.back().get();cb->num32BitEntries=bytes/4;
        std::cout<<"[\"constants\",";words(data,bytes/4);std::cout<<"]\n";return FfxErrorCode(FFX_OK);
    };
    b.fpCreatePipeline=createPipeline;
    b.fpDestroyPipeline=[](FfxInterface*,FfxPipelineState* p,FfxUInt32){std::cout<<"[\"destroy-pipeline\","<<p->passId<<"]\n";return FfxErrorCode(FFX_OK);};
    b.fpScheduleGpuJob=schedule;
    b.fpExecuteGpuJobs=[](FfxInterface*,FfxCommandList,FfxUInt32 id){std::cout<<"[\"execute\","<<id<<"]\n";return FfxErrorCode(FFX_OK);};
    return b;
}
FfxResource external(const char* label,uint32_t w,uint32_t h) {
    FfxResource r{};r.resource=reinterpret_cast<void*>(uintptr_t(nextResource++));
    r.description.type=FFX_RESOURCE_TYPE_TEXTURE2D;r.description.width=w;r.description.height=h;r.description.mipCount=1;
    resources[int(reinterpret_cast<uintptr_t>(r.resource))]={r.description,label};return r;
}
// Replaces the SDK's ffx_message.cpp, which passes a message to the registered
// callback on Windows (or to OutputDebugStringW without one) and drops every
// message elsewhere: this keeps the Windows callback path.
static ffxMessageCallback messageCallback;
void ffxSetPrintMessageCallback(ffxMessageCallback callback, uint32_t) { messageCallback=callback; }
void ffxPrintMessage(uint32_t type, const wchar_t* message) { if(messageCallback)messageCallback(type,message); }
void recordMessage(uint32_t type, const wchar_t* message) { std::cout<<"[\"message\","<<type<<',';quoted(narrow(message));std::cout<<"]\n"; }
void result(const char* kind,FfxErrorCode status) { std::cout<<'[';quoted(kind);std::cout<<','<<status<<"]\n"; }
void frame(uint32_t index) { constants.clear(); std::cout<<"[\"frame\","<<index<<"]\n"; }
int main(int argc,char** argv) {
    try {
        if(argc<2 || argc>3)throw std::runtime_error("usage: host-oracle shader-bindings.txt [init-data-directory] < inputs.words");
        if(argc==3)dataDirectory=argv[2];
        std::ifstream reflected(argv[1]);if(!reflected)throw std::runtime_error("cannot open shader reflection");
        Binding binding;while(reflected>>binding.stage>>binding.options>>binding.kind>>binding.slot>>binding.index>>binding.name)bindings.push_back(binding);
        capabilities.fp16Supported=word()!=0;capabilities.waveLaneCountMin=word();capabilities.waveLaneCountMax=word();capabilities.maximumSupportedShaderModel=FfxShaderModel(word());
        return runEffect();
    } catch(const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
