#include <Windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>
#include "IUnityInterface.h"
#include "IUnityGraphics.h"
#include "IUnityGraphicsD3D12.h"
#include "NativeAbi.h"
#include "QueryPool.h"
#include <algorithm>
#include <array>
#include <cstring>
#include <limits>
#include <memory>
#include <mutex>

using Microsoft::WRL::ComPtr;
namespace {
constexpr unsigned EventCount=7;
constexpr unsigned RetiredCapacity=4;
constexpr UINT64 RemovedFence=std::numeric_limits<UINT64>::max();
constexpr UINT QueryCount=static_cast<UINT>(hlgi::Capacity*hlgi::QueriesPerSample);
constexpr UINT64 ReadbackBytes=static_cast<UINT64>(QueryCount)*sizeof(UINT64);

struct DeviceResources {
    ComPtr<ID3D12Device> device;
    ComPtr<IDXGIAdapter3> memoryAdapter;
    ComPtr<ID3D12Fence> fence;
    ComPtr<ID3D12QueryHeap> queries;
    ComPtr<ID3D12Resource> readback;
    std::uint64_t* mapped=nullptr;
    UINT64 frequency=0,highestFence=0,epoch=0;
    bool retirementUnproven=false;
    ~DeviceResources() {
        // Destruction is permitted only after retirement proof, device removal,
        // or a failed initialization before any GPU command references the object.
        if(mapped && readback) { D3D12_RANGE written{0,0};readback->Unmap(0,&written); }
    }
    bool Removed() const {
        return !device || FAILED(device->GetDeviceRemovedReason()) ||
            (fence && fence->GetCompletedValue()==RemovedFence);
    }
    bool Retired() const {
        if(Removed()) return true;
        if(retirementUnproven) return false;
        if(highestFence==0) return true;
        return fence && fence->GetCompletedValue()>=highestFence;
    }
};
struct State {
    std::mutex mutex;
    IUnityInterfaces* interfaces=nullptr;
    IUnityGraphics* graphics=nullptr;
    IUnityGraphicsD3D12v7* v7=nullptr;
    IUnityGraphicsD3D12v6* v6=nullptr;
    std::unique_ptr<DeviceResources> active;
    std::array<std::unique_ptr<DeviceResources>,RetiredCapacity> retired;
    hlgi::QueryPool pool;
    hlgi::NativeStatus status=hlgi::NativeStatus::Uninitialized;
    std::uint64_t epoch=0;
    int eventBase=-1;
};
State& GetState() {
    // Unity keeps native plugins loaded for the session. If shutdown supplies no
    // GPU-completion proof, retain this bounded state rather than releasing GPU
    // objects still referenced by a queued list during DLL static destruction.
    // No FreeLibrary/hot-unload API is provided. The OS reclaims it at process exit.
    static State* state=new State();
    return *state;
}

void CollectRetired(State& s) {
    for(auto& resource:s.retired) if(resource && resource->Retired()) resource.reset();
}
unsigned RetiredCount(const State& s) {
    unsigned count=0;for(const auto& resource:s.retired) if(resource) ++count;return count;
}
void RetireActive(State& s) {
    s.pool.ResetDevice();
    if(!s.active) return;
    if(s.active->Retired()) { s.active.reset();return; }
    for(auto& resource:s.retired) if(!resource) { resource=std::move(s.active);return; }
    // Initialization reserves one retirement slot before accepting any work, so
    // this branch cannot occur without a programming error. Keep the active owner.
    s.status=hlgi::NativeStatus::RetirementCapacity;
}
bool Refresh(State& s) {
    CollectRetired(s);
    if(!s.active || s.status!=hlgi::NativeStatus::Ready) return false;
    if(s.active->Removed()) {
        s.status=hlgi::NativeStatus::DeviceLost;RetireActive(s);return false;
    }
    s.pool.Collect(s.active->fence->GetCompletedValue());
    return true;
}

// Unity interface calls are confined to graphics initialization and render callbacks.
ID3D12Device* Device(State& s) { return s.v7?s.v7->GetDevice():s.v6->GetDevice(); }
ID3D12Fence* Fence(State& s) { return s.v7?s.v7->GetFrameFence():s.v6->GetFrameFence(); }
UINT64 NextFence(State& s) { return s.v7?s.v7->GetNextFrameFenceValue():s.v6->GetNextFrameFenceValue(); }
ID3D12CommandQueue* Queue(State& s) { return s.v7?s.v7->GetCommandQueue():s.v6->GetCommandQueue(); }
bool Recording(State& s,UnityGraphicsD3D12RecordingState& recording) {
    return s.v7?s.v7->CommandRecordingState(&recording):s.v6->CommandRecordingState(&recording);
}

void Initialize(State& s) {
    RetireActive(s);CollectRetired(s);
    s.v7=nullptr;s.v6=nullptr;s.status=hlgi::NativeStatus::Unsupported;
    if(!s.graphics || !s.interfaces || s.graphics->GetRenderer()!=kUnityGfxRendererD3D12 || s.eventBase<0) return;
    s.v7=s.interfaces->Get<IUnityGraphicsD3D12v7>();
    if(!s.v7) s.v6=s.interfaces->Get<IUnityGraphicsD3D12v6>();
    if(!s.v7 && !s.v6) return;
    // Reserve room for this entire device's retirement, not just its active slots.
    if(s.active || RetiredCount(s)>=RetiredCapacity) { s.status=hlgi::NativeStatus::RetirementCapacity;return; }
    if(s.epoch==std::numeric_limits<std::uint64_t>::max()) return;
    ++s.epoch;
    UnityD3D12PluginEventConfig config{};
    config.graphicsQueueAccess=kUnityD3D12GraphicsQueueAccess_DontCare;
    config.flags=kUnityD3D12EventConfigFlag_SyncWorkerThreads;
    config.ensureActiveRenderTextureIsBound=false;
    for(unsigned i=0;i<EventCount;++i) {
        if(s.v7) s.v7->ConfigureEvent(s.eventBase+static_cast<int>(i),&config);
        else s.v6->ConfigureEvent(s.eventBase+static_cast<int>(i),&config);
    }
    auto resource=std::make_unique<DeviceResources>();
    resource->device=Device(s);resource->fence=Fence(s);resource->epoch=s.epoch;
    ID3D12CommandQueue* queue=Queue(s);
    if(!resource->device || !resource->fence || !queue || resource->device->GetNodeCount()!=1 ||
       FAILED(queue->GetTimestampFrequency(&resource->frequency)) || resource->frequency==0) return;
    // Optional CPU observation of the actual Unity adapter. Failure leaves the
    // established timing path available; never choose an arbitrary adapter.
    ComPtr<IDXGIFactory4> factory;
    if(SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&factory))))
        factory->EnumAdapterByLuid(resource->device->GetAdapterLuid(),IID_PPV_ARGS(&resource->memoryAdapter));
    s.status=hlgi::NativeStatus::AllocationFailure;
    D3D12_QUERY_HEAP_DESC queryDesc{};queryDesc.Count=QueryCount;queryDesc.Type=D3D12_QUERY_HEAP_TYPE_TIMESTAMP;
    if(FAILED(resource->device->CreateQueryHeap(&queryDesc,IID_PPV_ARGS(&resource->queries)))) return;
    D3D12_HEAP_PROPERTIES heap{};heap.Type=D3D12_HEAP_TYPE_READBACK;heap.CreationNodeMask=1;heap.VisibleNodeMask=1;
    D3D12_RESOURCE_DESC buffer{};buffer.Dimension=D3D12_RESOURCE_DIMENSION_BUFFER;buffer.Width=ReadbackBytes;
    buffer.Height=1;buffer.DepthOrArraySize=1;buffer.MipLevels=1;buffer.SampleDesc.Count=1;buffer.Layout=D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
    if(FAILED(resource->device->CreateCommittedResource(&heap,D3D12_HEAP_FLAG_NONE,&buffer,
       D3D12_RESOURCE_STATE_COPY_DEST,nullptr,IID_PPV_ARGS(&resource->readback)))) return;
    D3D12_RANGE readRange{0,static_cast<SIZE_T>(ReadbackBytes)};
    if(FAILED(resource->readback->Map(0,&readRange,reinterpret_cast<void**>(&resource->mapped)))) return;
    resource->queries->SetName(L"HLGI timestamp query pool");resource->readback->SetName(L"HLGI timestamp readback");
    s.active=std::move(resource);s.status=hlgi::NativeStatus::Ready;
}

void UNITY_INTERFACE_API OnDeviceEvent(UnityGfxDeviceEventType eventType) {
    auto& s=GetState();std::lock_guard<std::mutex> lock(s.mutex);
    try {
        if(eventType==kUnityGfxDeviceEventInitialize || eventType==kUnityGfxDeviceEventAfterReset) Initialize(s);
        else if(eventType==kUnityGfxDeviceEventShutdown || eventType==kUnityGfxDeviceEventBeforeReset) {
            s.status=hlgi::NativeStatus::Uninitialized;RetireActive(s);CollectRetired(s);s.v7=nullptr;s.v6=nullptr;
        }
    } catch(...) { s.status=hlgi::NativeStatus::AllocationFailure;RetireActive(s); }
}

void UNITY_INTERFACE_API OnRenderEvent(int eventId,void* opaque) {
    auto& s=GetState();std::lock_guard<std::mutex> lock(s.mutex);
    const auto token=static_cast<std::uint64_t>(reinterpret_cast<std::uintptr_t>(opaque));
    // data is an integer key, NEVER a dereferenced managed or recycled payload pointer.
    if(!Refresh(s) || eventId<s.eventBase || eventId>=s.eventBase+static_cast<int>(EventCount)) return;
    const unsigned event=static_cast<unsigned>(eventId-s.eventBase);
    auto* slot=s.pool.Find(token);
    if(!slot || slot->deviceEpoch!=s.active->epoch || !s.pool.CanRecord(token,event)) return;
    UnityGraphicsD3D12RecordingState recording{};
    if(!Recording(s,recording) || !recording.commandList || recording.commandList->GetType()!=D3D12_COMMAND_LIST_TYPE_DIRECT ||
       Fence(s)!=s.active->fence.Get()) { s.pool.Cancel(token);return; }
    const UINT64 retirement=NextFence(s);
    // Validate BEFORE recording GPU work. MAX denotes device removal, not completion.
    if(retirement==0 || retirement==RemovedFence) { s.pool.Cancel(token);return; }
    const UINT first=static_cast<UINT>(hlgi::QueryPool::Index(token)*hlgi::QueriesPerSample);
    if(event<hlgi::QueriesPerSample) {
        recording.commandList->EndQuery(s.active->queries.Get(),D3D12_QUERY_TYPE_TIMESTAMP,first+event);
    } else {
        // Caller records event 6 exclusively in an Unsafe RenderGraph pass AFTER
        // Composite. ResolveQueryData is illegal inside a D3D12 native render pass.
        // CanRecord also proves all six queries have been initialized this lifetime.
        recording.commandList->ResolveQueryData(s.active->queries.Get(),D3D12_QUERY_TYPE_TIMESTAMP,
            first,hlgi::QueriesPerSample,s.active->readback.Get(),static_cast<UINT64>(first)*sizeof(UINT64));
    }
    const UINT64 after=NextFence(s);
    if(after==0 || after==RemovedFence || Fence(s)!=s.active->fence.Get()) {
        // A contract failure after appending work cannot be repaired by guessing
        // a fence. Quarantine the whole device allocation until device removal.
        s.active->retirementUnproven=true;s.status=hlgi::NativeStatus::Uninitialized;
        RetireActive(s);return;
    }
    const UINT64 covered=std::max(retirement,after);
    s.active->highestFence=std::max(s.active->highestFence,covered);
    s.pool.Recorded(token,event,covered);
}
}

extern "C" {
__declspec(dllexport) int __cdecl HLGI_Memory_Query(hlgi::MemoryInfo* output,std::uint32_t size) noexcept {
    if(!output || size!=sizeof(hlgi::MemoryInfo)) return 0;
    *output={};
    try {
        auto& s=GetState();std::lock_guard<std::mutex> lock(s.mutex);
        if(!s.active || s.status!=hlgi::NativeStatus::Ready)
            return s.status==hlgi::NativeStatus::DeviceLost?-2:0;
        if(s.active->Removed()) return -2;
        if(!s.active->memoryAdapter) return 0;
        DXGI_QUERY_VIDEO_MEMORY_INFO local{},nonlocal{};
        if(FAILED(s.active->memoryAdapter->QueryVideoMemoryInfo(0,DXGI_MEMORY_SEGMENT_GROUP_LOCAL,&local)) ||
           FAILED(s.active->memoryAdapter->QueryVideoMemoryInfo(0,DXGI_MEMORY_SEGMENT_GROUP_NON_LOCAL,&nonlocal))) return 0;
        const LUID luid=s.active->device->GetAdapterLuid();
        const auto identity=(static_cast<std::uint64_t>(static_cast<std::uint32_t>(luid.HighPart))<<32)|luid.LowPart;
        *output={1,sizeof(hlgi::MemoryInfo),s.active->epoch,identity,
            local.CurrentUsage,local.Budget,nonlocal.CurrentUsage,nonlocal.Budget};
        // No timestamp polling, GPU commands, residency or reservation changes.
        return 1;
    } catch(...) { return 0; }
}
__declspec(dllexport) int __cdecl HLGI_Timing_GetInfo(hlgi::ApiInfo* output,std::uint32_t size) noexcept {
    if(!output || size!=sizeof(hlgi::ApiInfo)) return 0;
    try {
        auto& s=GetState();std::lock_guard<std::mutex> lock(s.mutex);Refresh(s);
        *output={1,sizeof(hlgi::ApiInfo),static_cast<std::uint32_t>(s.status),static_cast<std::uint32_t>(hlgi::Capacity),
            s.eventBase,0,s.epoch,s.active?s.active->frequency:0,reinterpret_cast<void*>(&OnRenderEvent)};
        return 1;
    } catch(...) { *output={};return 0; }
}
__declspec(dllexport) std::uint64_t __cdecl HLGI_Timing_Acquire(std::uint64_t owner,std::uint64_t generation,std::int64_t frame) noexcept {
    try { auto& s=GetState();std::lock_guard<std::mutex> lock(s.mutex);
        return Refresh(s)?s.pool.Acquire(owner,generation,frame,s.active->epoch):0;
    } catch(...) { return 0; }
}
__declspec(dllexport) void __cdecl HLGI_Timing_Cancel(std::uint64_t token) noexcept {
    try { auto& s=GetState();std::lock_guard<std::mutex> lock(s.mutex);s.pool.Cancel(token);Refresh(s); } catch(...) {}
}
__declspec(dllexport) int __cdecl HLGI_Timing_Poll(std::uint64_t token,hlgi::TimingResult* output,std::uint32_t size) noexcept {
    if(!output || size!=sizeof(hlgi::TimingResult)) return -1;
    *output={};
    try {
        auto& s=GetState();std::lock_guard<std::mutex> lock(s.mutex);
        if(!Refresh(s)) return s.status==hlgi::NativeStatus::DeviceLost?-2:-1;
        auto* slot=s.pool.Find(token);
        if(!slot || slot->deviceEpoch!=s.active->epoch) return -1;
        const auto completed=s.active->fence->GetCompletedValue();
        if(completed==RemovedFence) return -2;
        if(!s.pool.CanRead(token,completed)) return 0;
        *output={slot->token,slot->owner,slot->generation,slot->deviceEpoch,slot->engineFrame,s.active->frequency,{}};
        const auto first=hlgi::QueryPool::Index(token)*hlgi::QueriesPerSample;
        std::memcpy(output->ticks,s.active->mapped+first,sizeof(output->ticks));
        bool ordered=true;
        for(unsigned i=1;i<hlgi::QueriesPerSample;++i) ordered=ordered && output->ticks[i]>=output->ticks[i-1];
        s.pool.Consume(token,completed);
        if(!ordered) { *output={};return -3; }
        return 1;
    } catch(...) { return -1; }
}
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginLoad(IUnityInterfaces* interfaces) {
    auto& s=GetState();
    {
        std::lock_guard<std::mutex> lock(s.mutex);s.interfaces=interfaces;
        s.graphics=interfaces?interfaces->Get<IUnityGraphics>():nullptr;
        if(!s.graphics) return;
        s.eventBase=s.graphics->ReserveEventIDRange(static_cast<int>(EventCount));
        if(s.eventBase<0 || s.eventBase>std::numeric_limits<int>::max()-static_cast<int>(EventCount)) s.eventBase=-1;
    }
    s.graphics->RegisterDeviceEventCallback(OnDeviceEvent);
    OnDeviceEvent(kUnityGfxDeviceEventInitialize);
}
void UNITY_INTERFACE_EXPORT UNITY_INTERFACE_API UnityPluginUnload() {
    auto& s=GetState();
    if(s.graphics) s.graphics->UnregisterDeviceEventCallback(OnDeviceEvent);
    std::lock_guard<std::mutex> lock(s.mutex);
    s.status=hlgi::NativeStatus::Uninitialized;RetireActive(s);CollectRetired(s);
    s.v7=nullptr;s.v6=nullptr;s.graphics=nullptr;s.interfaces=nullptr;
    // Unproven retired resources stay owned by the bounded process-lifetime state.
    // Neither a callback unregister nor a managed Dispose is GPU completion proof.
}
}
