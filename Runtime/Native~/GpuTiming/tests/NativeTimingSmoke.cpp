// Real D3D12/WARP execution with a simulated Unity interface registry.
// This is NOT a Unity Player, RenderGraph, physical-GPU, or device-loss test.
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>
#include <d3d12.h>
#include <d3d12sdklayers.h>
#include <dxgi1_4.h>
#include <wrl/client.h>
#include "IUnityInterface.h"
#include "IUnityGraphics.h"
#include "IUnityGraphicsD3D12.h"
#include "../NativeAbi.h"
#include "../QueryPool.h"

#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;
namespace
{
constexpr UINT64 WorkBytes = 64 * 1024;
constexpr unsigned CopiesPerStage = 16;
constexpr DWORD FenceTimeoutMilliseconds = 10000;
constexpr unsigned ReuseSamples = 257;
std::uint64_t checks = 0;
unsigned scenarios = 0;

struct Unavailable : std::runtime_error { using std::runtime_error::runtime_error; };

void Check(bool condition, const char* message)
{
    ++checks;
    if (!condition) throw std::runtime_error(message);
}

void CheckHr(HRESULT result, const char* operation)
{
    ++checks;
    if (FAILED(result))
    {
        std::cerr << operation << " HRESULT=0x" << std::hex
                  << static_cast<unsigned long>(result) << std::dec << '\n';
        throw std::runtime_error(operation);
    }
}

template<class Function>
Function Export(HMODULE module, const char* name)
{
    const FARPROC address = GetProcAddress(module, name);
    Check(address != nullptr, name);
    static_assert(sizeof(Function) == sizeof(address), "Win64 function pointer layout required");
    Function result = nullptr;
    std::memcpy(&result, &address, sizeof(result));
    return result;
}

struct Plugin
{
    using Load = void (UNITY_INTERFACE_API*)(IUnityInterfaces*);
    using Unload = void (UNITY_INTERFACE_API*)();
    using GetInfo = int (__cdecl*)(hlgi::ApiInfo*, std::uint32_t);
    using Acquire = std::uint64_t (__cdecl*)(std::uint64_t, std::uint64_t, std::int64_t);
    using Cancel = void (__cdecl*)(std::uint64_t);
    using Poll = int (__cdecl*)(std::uint64_t, hlgi::TimingResult*, std::uint32_t);
    HMODULE module = nullptr;
    Load load = nullptr;
    Unload unload = nullptr;
    GetInfo info = nullptr;
    Acquire acquire = nullptr;
    Cancel cancel = nullptr;
    Poll poll = nullptr;
    UnityRenderingEventAndData render = nullptr;
    hlgi::ApiInfo current{};
    unsigned validResults = 0;
    double accumulatedMilliseconds = 0;

    explicit Plugin(const std::filesystem::path& path)
    {
        module = LoadLibraryExW(path.c_str(), nullptr,
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
        Check(module != nullptr, "LoadLibraryExW native timing DLL");
        load = Export<Load>(module, "UnityPluginLoad");
        unload = Export<Unload>(module, "UnityPluginUnload");
        info = Export<GetInfo>(module, "HLGI_Timing_GetInfo");
        acquire = Export<Acquire>(module, "HLGI_Timing_Acquire");
        cancel = Export<Cancel>(module, "HLGI_Timing_Cancel");
        poll = Export<Poll>(module, "HLGI_Timing_Poll");
        // Intentionally no FreeLibrary: the plugin does not offer hot unloading.
    }

    void Ready()
    {
        Check(info(&current, sizeof(current)) == 1, "GetInfo accepted exact ABI");
        Check(current.abiVersion == 1 && current.structSize == sizeof(current), "native info ABI version/size");
        Check(current.status == static_cast<std::uint32_t>(hlgi::NativeStatus::Ready), "native timing Ready on WARP");
        Check(current.capacity == hlgi::Capacity && current.frequency > 0, "native capacity/frequency");
        Check(current.eventBase >= 0 && current.callback != nullptr, "native callback/event range");
        static_assert(sizeof(render) == sizeof(current.callback), "Win64 callback layout required");
        std::memcpy(&render, &current.callback, sizeof(render));
    }

    void Event(std::uint64_t token, unsigned event) const
    {
        render(current.eventBase + static_cast<int>(event),
            reinterpret_cast<void*>(static_cast<std::uintptr_t>(token)));
    }

    int PollResult(std::uint64_t token, hlgi::TimingResult& result) const
    {
        return poll(token, &result, sizeof(result));
    }

    void VerifyResult(std::uint64_t token, std::uint64_t owner,
        std::uint64_t generation, std::int64_t frame, std::uint64_t epoch)
    {
        hlgi::TimingResult result{};
        Check(PollResult(token, result) == 1, "completed timestamp readback ready");
        Check(result.token == token && result.owner == owner, "result submission/owner identity");
        Check(result.generation == generation && result.engineFrame == frame &&
            result.deviceEpoch == epoch, "result generation/frame/device identity");
        Check(result.frequency == current.frequency && result.frequency > 0, "result queue frequency");
        for (unsigned i = 1; i < hlgi::QueriesPerSample; ++i)
            Check(result.ticks[i] >= result.ticks[i - 1], "timestamp order across all stages");
        double total = 0;
        for (unsigned stage = 0; stage < 3; ++stage)
        {
            const auto ticks = result.ticks[stage * 2 + 1] - result.ticks[stage * 2];
            const double milliseconds = static_cast<double>(ticks) * 1000.0 /
                static_cast<double>(result.frequency);
            Check(std::isfinite(milliseconds) && milliseconds >= 0, "finite nonnegative stage duration");
            total += milliseconds;
        }
        accumulatedMilliseconds += total;
        ++validResults;
        Check(PollResult(token, result) == -1, "consumed result cannot be consumed twice");
    }
};

struct Host;
Host* host = nullptr;

struct Host
{
    ComPtr<IDXGIFactory4> factory;
    ComPtr<IDXGIAdapter> adapter;
    ComPtr<ID3D12Device> device;
    ComPtr<ID3D12CommandQueue> queue;
    ComPtr<ID3D12CommandAllocator> allocator;
    ComPtr<ID3D12GraphicsCommandList> list;
    ComPtr<ID3D12Fence> fence;
    ComPtr<ID3D12Resource> upload, destination;
    ComPtr<ID3D12InfoQueue> debugMessages;
    IUnityGraphics graphics{};
    IUnityGraphicsD3D12v7 d3d12{};
    IUnityInterfaces interfaces{};
    IUnityGraphicsDeviceEventCallback deviceCallback = nullptr;
    HANDLE fenceEvent = nullptr;
    UINT64 nextFence = 0;
    bool recording = false;
    bool debugEnabled = false;
    bool configValid = true;
    bool callbackRegistrationValid = true;
    unsigned configureCalls = 0;
    unsigned nextFenceCallsUntilInvalid = 0;
    unsigned injectedFenceFailures = 0;
    unsigned submissions = 0;
    std::uint64_t copyCommands = 0;

    Host()
    {
        host = this;
        ComPtr<ID3D12Debug> debug;
        if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&debug))))
        {
            debug->EnableDebugLayer();
            debugEnabled = true;
        }
        HRESULT result = CreateDXGIFactory2(0, IID_PPV_ARGS(&factory));
        if (FAILED(result)) throw Unavailable("DXGI factory unavailable");
        result = factory->EnumWarpAdapter(IID_PPV_ARGS(&adapter));
        if (FAILED(result)) throw Unavailable("DXGI WARP adapter unavailable");
        result = D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&device));
        if (FAILED(result)) throw Unavailable("D3D12 device creation on WARP unavailable");
        DXGI_ADAPTER_DESC description{};
        CheckHr(adapter->GetDesc(&description), "WARP adapter description");
        std::wcout << L"Adapter: " << description.Description << L" (WARP software)\n";
        if (debugEnabled) device.As(&debugMessages);
        D3D12_COMMAND_QUEUE_DESC queueDescription{};
        queueDescription.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
        CheckHr(device->CreateCommandQueue(&queueDescription, IID_PPV_ARGS(&queue)), "create direct queue");
        UINT64 frequency = 0;
        if (FAILED(queue->GetTimestampFrequency(&frequency)) || frequency == 0)
            throw Unavailable("WARP timestamp frequency unavailable");
        CheckHr(device->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,
            IID_PPV_ARGS(&allocator)), "create command allocator");
        CheckHr(device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator.Get(),
            nullptr, IID_PPV_ARGS(&list)), "create command list");
        CheckHr(list->Close(), "close initial command list");
        CheckHr(device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)), "create frame fence");
        fenceEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        Check(fenceEvent != nullptr, "create bounded fence wait event");
        MakeWorkBuffers();
        MakeInterfaces();
    }

    ~Host() { if (fenceEvent) CloseHandle(fenceEvent); }

    void MakeWorkBuffers()
    {
        D3D12_RESOURCE_DESC description{};
        description.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        description.Width = WorkBytes;
        description.Height = 1;
        description.DepthOrArraySize = 1;
        description.MipLevels = 1;
        description.SampleDesc.Count = 1;
        description.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        D3D12_HEAP_PROPERTIES heap{};
        heap.Type = D3D12_HEAP_TYPE_UPLOAD;
        heap.CreationNodeMask = heap.VisibleNodeMask = 1;
        CheckHr(device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE, &description,
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr, IID_PPV_ARGS(&upload)), "create bounded upload buffer");
        heap.Type = D3D12_HEAP_TYPE_DEFAULT;
        CheckHr(device->CreateCommittedResource(&heap, D3D12_HEAP_FLAG_NONE, &description,
            D3D12_RESOURCE_STATE_COPY_DEST, nullptr, IID_PPV_ARGS(&destination)), "create bounded work buffer");
        void* data = nullptr;
        D3D12_RANGE noRead{0, 0};
        CheckHr(upload->Map(0, &noRead, &data), "map work input");
        std::memset(data, 0x5a, static_cast<std::size_t>(WorkBytes));
        D3D12_RANGE written{0, static_cast<SIZE_T>(WorkBytes)};
        upload->Unmap(0, &written);
    }

    static UnityGfxRenderer UNITY_INTERFACE_API Renderer() { return kUnityGfxRendererD3D12; }
    static void UNITY_INTERFACE_API Register(IUnityGraphicsDeviceEventCallback callback)
    {
        if (host->deviceCallback != nullptr) host->callbackRegistrationValid = false;
        host->deviceCallback = callback;
    }
    static void UNITY_INTERFACE_API Unregister(IUnityGraphicsDeviceEventCallback callback)
    {
        if (host->deviceCallback != callback) host->callbackRegistrationValid = false;
        host->deviceCallback = nullptr;
    }
    static int UNITY_INTERFACE_API Reserve(int count)
    {
        if (count != 7) host->configValid = false;
        return 1000;
    }
    static ID3D12Device* UNITY_INTERFACE_API Device() { return host->device.Get(); }
    static ID3D12Fence* UNITY_INTERFACE_API Fence() { return host->fence.Get(); }
    static UINT64 UNITY_INTERFACE_API NextFence()
    {
        if (host->nextFenceCallsUntilInvalid != 0 && --host->nextFenceCallsUntilInvalid == 0)
        {
            ++host->injectedFenceFailures;
            return 0;
        }
        return host->nextFence;
    }
    static ID3D12CommandQueue* UNITY_INTERFACE_API Queue() { return host->queue.Get(); }
    static bool UNITY_INTERFACE_API Recording(UnityGraphicsD3D12RecordingState* state)
    {
        if (!state || !host->recording) return false;
        state->commandList = host->list.Get();
        return true;
    }
    static void UNITY_INTERFACE_API Configure(int event, const UnityD3D12PluginEventConfig* config)
    {
        ++host->configureCalls;
        if (!config || event < 1000 || event > 1006 ||
            config->graphicsQueueAccess != kUnityD3D12GraphicsQueueAccess_DontCare ||
            (config->flags & kUnityD3D12EventConfigFlag_EnsurePreviousFrameSubmission) != 0)
            host->configValid = false;
        // This host is single-threaded; it does not emulate Unity worker scheduling.
    }
    static IUnityInterface* UNITY_INTERFACE_API GetInterface(UnityInterfaceGUID guid)
    {
        if (guid == GetUnityInterfaceGUID<IUnityGraphics>()) return &host->graphics;
        if (guid == GetUnityInterfaceGUID<IUnityGraphicsD3D12v7>()) return &host->d3d12;
        return nullptr;
    }
    static IUnityInterface* UNITY_INTERFACE_API GetSplit(unsigned long long high, unsigned long long low)
    {
        return GetInterface(UnityInterfaceGUID(high, low));
    }
    static void UNITY_INTERFACE_API RegisterInterface(UnityInterfaceGUID, IUnityInterface*)
    {
        host->configValid = false; // the timing plugin need not publish interfaces
    }
    static void UNITY_INTERFACE_API RegisterSplit(unsigned long long, unsigned long long, IUnityInterface*)
    {
        host->configValid = false;
    }

    void MakeInterfaces()
    {
        graphics.GetRenderer = Renderer;
        graphics.RegisterDeviceEventCallback = Register;
        graphics.UnregisterDeviceEventCallback = Unregister;
        graphics.ReserveEventIDRange = Reserve;
        d3d12.GetDevice = Device;
        d3d12.GetFrameFence = Fence;
        d3d12.GetNextFrameFenceValue = NextFence;
        d3d12.GetCommandQueue = Queue;
        d3d12.ConfigureEvent = Configure;
        d3d12.CommandRecordingState = Recording;
        interfaces.GetInterface = GetInterface;
        interfaces.RegisterInterface = RegisterInterface;
        interfaces.GetInterfaceSplit = GetSplit;
        interfaces.RegisterInterfaceSplit = RegisterSplit;
    }

    void Begin()
    {
        Check(!recording, "no nested recording");
        Check(fence->GetCompletedValue() >= nextFence, "allocator not reused before fence completion");
        CheckHr(allocator->Reset(), "reset retired allocator");
        CheckHr(list->Reset(allocator.Get(), nullptr), "reset retired command list");
        ++nextFence;
        recording = true;
    }

    void Work()
    {
        Check(recording, "copy work has an active list");
        for (unsigned i = 0; i < CopiesPerStage; ++i)
            list->CopyBufferRegion(destination.Get(), 0, upload.Get(), 0, WorkBytes);
        copyCommands += CopiesPerStage;
    }

    void SubmitAndWait()
    {
        Check(recording, "submission has an active list");
        CheckHr(list->Close(), "close recorded list");
        recording = false;
        ID3D12CommandList* lists[] = {list.Get()};
        queue->ExecuteCommandLists(1, lists);
        CheckHr(queue->Signal(fence.Get(), nextFence), "signal actual submitted frame fence");
        if (fence->GetCompletedValue() < nextFence)
        {
            CheckHr(fence->SetEventOnCompletion(nextFence, fenceEvent), "register frame completion");
            Check(WaitForSingleObject(fenceEvent, FenceTimeoutMilliseconds) == WAIT_OBJECT_0,
                "D3D12 frame fence completed within 10 seconds");
        }
        Check(fence->GetCompletedValue() != (std::numeric_limits<UINT64>::max)(), "device not removed");
        Check(fence->GetCompletedValue() >= nextFence, "actual submitted fence reached");
        CheckHr(device->GetDeviceRemovedReason(), "device remains usable after timestamp execution");
        ++submissions;
    }

    void CheckDebugMessages()
    {
        if (!debugMessages) return;
        const UINT64 count = debugMessages->GetNumStoredMessagesAllowedByRetrievalFilter();
        unsigned errors = 0, warnings = 0;
        for (UINT64 i = 0; i < count; ++i)
        {
            SIZE_T size = 0;
            CheckHr(debugMessages->GetMessage(i, nullptr, &size), "query debug message size");
            std::vector<unsigned char> bytes(size);
            auto* message = reinterpret_cast<D3D12_MESSAGE*>(bytes.data());
            CheckHr(debugMessages->GetMessage(i, message, &size), "read debug message");
            if (message->Severity == D3D12_MESSAGE_SEVERITY_CORRUPTION ||
                message->Severity == D3D12_MESSAGE_SEVERITY_ERROR)
            {
                ++errors;
                std::cerr << "D3D12 ERROR: " << message->pDescription << '\n';
            }
            else if (message->Severity == D3D12_MESSAGE_SEVERITY_WARNING) ++warnings;
        }
        std::cout << "D3D12 debug layer: " << errors << " errors, " << warnings << " warnings.\n";
        Check(errors == 0, "D3D12 debug layer reported no errors/corruption");
    }
};

void RecordAll(Host& runtime, Plugin& plugin, std::uint64_t token)
{
    for (unsigned stage = 0; stage < 3; ++stage)
    {
        plugin.Event(token, stage * 2);
        runtime.Work();
        plugin.Event(token, stage * 2 + 1);
    }
    // No native render pass exists in this host: resolve is outside one by design.
    plugin.Event(token, 6);
}

void RoundTripAndReuse(Host& runtime, Plugin& plugin)
{
    ++scenarios;
    std::array<unsigned, hlgi::Capacity> uses{};
    std::uint64_t previous = 0;
    for (unsigned i = 0; i < ReuseSamples; ++i)
    {
        runtime.Begin();
        const std::uint64_t owner = 99 + i % 5;
        const std::uint64_t generation = 100 + i / 7;
        const std::int64_t frame = 10000 + i;
        const auto token = plugin.acquire(owner, generation, frame);
        Check(token > previous && token <= hlgi::QueryPool::MaxToken, "unique monotonic native submission ID");
        previous = token;
        const auto slot = hlgi::QueryPool::Index(token);
        Check(slot < hlgi::Capacity, "valid native pool slot");
        ++uses[slot];
        RecordAll(runtime, plugin, token);
        hlgi::TimingResult pending{};
        Check(plugin.PollResult(token, pending) == 0, "recorded but unsubmitted result remains pending");
        runtime.SubmitAndWait();
        plugin.VerifyResult(token, owner, generation, frame, plugin.current.deviceEpoch);
    }
    for (const auto count : uses) Check(count >= 2, "every physical slot reused after an actual fence");
    Check(plugin.accumulatedMilliseconds > 0, "WARP timestamps observed nonzero bounded work");
}

void CancelBeforeAndLateCallbacks(Host& runtime, Plugin& plugin)
{
    ++scenarios;
    runtime.Begin();
    const auto stale = plugin.acquire(1, 1, 1);
    Check(stale != 0, "acquire pre-cancel sample");
    plugin.cancel(stale);
    for (unsigned event = 0; event < 7; ++event) plugin.Event(stale, event);
    hlgi::TimingResult result{};
    Check(plugin.PollResult(stale, result) == -1, "canceled untouched token rejects late callbacks");
    const auto fresh = plugin.acquire(2, 3, 4);
    Check(fresh > stale, "canceled token ID never reused");
    RecordAll(runtime, plugin, fresh);
    runtime.SubmitAndWait();
    plugin.VerifyResult(fresh, 2, 3, 4, plugin.current.deviceEpoch);
}

void CancelAfterBeginRetainsSlot(Host& runtime, Plugin& plugin)
{
    ++scenarios;
    runtime.Begin();
    const auto canceled = plugin.acquire(1, 1, 1);
    Check(canceled != 0, "acquire partial canceled sample");
    plugin.Event(canceled, 0);
    plugin.cancel(canceled);
    std::vector<std::uint64_t> reserved;
    for (std::size_t i = 1; i < hlgi::Capacity; ++i)
    {
        const auto token = plugin.acquire(2, 2, static_cast<std::int64_t>(i));
        Check(token != 0, "remaining pool capacity available");
        Check(hlgi::QueryPool::Index(token) != hlgi::QueryPool::Index(canceled),
            "touched canceled slot not reused before submission fence");
        reserved.push_back(token);
    }
    Check(plugin.acquire(3, 3, 3) == 0, "canceled in-flight GPU work still occupies one of 128 slots");
    for (unsigned event = 1; event < 7; ++event) plugin.Event(canceled, event);
    for (const auto token : reserved) plugin.cancel(token);
    hlgi::TimingResult result{};
    Check(plugin.PollResult(canceled, result) == 0, "partial canceled work waits for actual fence");
    runtime.SubmitAndWait();
    Check(plugin.PollResult(canceled, result) == -1, "canceled work retired after actual fence");
    reserved.clear();
    bool foundRetiredSlot = false;
    for (std::size_t i = 0; i < hlgi::Capacity; ++i)
    {
        const auto token = plugin.acquire(4, 4, static_cast<std::int64_t>(i));
        Check(token != 0, "all slots recovered after canceled fence");
        foundRetiredSlot = foundRetiredSlot ||
            hlgi::QueryPool::Index(token) == hlgi::QueryPool::Index(canceled);
        reserved.push_back(token);
    }
    Check(foundRetiredSlot, "canceled physical slot becomes reusable after fence");
    for (const auto token : reserved) plugin.cancel(token);
}

void IncompleteResolveAndDuplicate(Host& runtime, Plugin& plugin)
{
    ++scenarios;
    runtime.Begin();
    hlgi::TimingResult result{};
    auto token = plugin.acquire(1, 1, 1);
    Check(token != 0, "acquire empty resolve candidate");
    plugin.Event(token, 6);
    Check(plugin.PollResult(token, result) == -1, "resolve without any timestamps rejected");
    token = plugin.acquire(1, 1, 2);
    Check(token != 0, "acquire partial resolve candidate");
    plugin.Event(token, 0);
    plugin.Event(token, 1);
    plugin.Event(token, 6);
    Check(plugin.PollResult(token, result) == 0, "incomplete resolve canceled but GPU stamps retained");
    for (unsigned event = 2; event < 7; ++event) plugin.Event(token, event);
    const auto duplicate = plugin.acquire(2, 2, 2);
    Check(duplicate != 0, "acquire duplicate event candidate");
    plugin.Event(duplicate, 0);
    plugin.Event(duplicate, 0);
    for (unsigned event = 1; event < 7; ++event) plugin.Event(duplicate, event);
    runtime.SubmitAndWait();
    Check(plugin.PollResult(token, result) == -1, "incomplete resolve never publishes a result");
    Check(plugin.PollResult(duplicate, result) == -1, "duplicate begin never publishes a result");
}

void DeviceEventResetWithPendingWork(Host& runtime, Plugin& plugin)
{
    ++scenarios;
    runtime.Begin();
    const auto oldEpoch = plugin.current.deviceEpoch;
    const auto old = plugin.acquire(7, 8, 9);
    Check(old != 0, "acquire old device epoch sample");
    RecordAll(runtime, plugin, old);
    hlgi::TimingResult result{};
    Check(plugin.PollResult(old, result) == 0, "old device work is still unsubmitted");
    Check(runtime.deviceCallback != nullptr, "device callback registered");
    runtime.deviceCallback(kUnityGfxDeviceEventBeforeReset);
    Check(plugin.acquire(9, 9, 9) == 0, "no new work between reset notifications");
    // Retain the real device and list deliberately. This exercises notification /
    // epoch handling and executing references to retired query/readback resources,
    // not an actual DXGI device removal or a recreation by Unity.
    runtime.deviceCallback(kUnityGfxDeviceEventAfterReset);
    plugin.Ready();
    Check(plugin.current.deviceEpoch > oldEpoch, "device notification advances epoch");
    for (unsigned event = 0; event < 7; ++event) plugin.Event(old, event);
    Check(plugin.PollResult(old, result) == -1, "old epoch token rejected after reset");
    const auto fresh = plugin.acquire(10, 11, 12);
    Check(fresh > old, "reset does not reset native submission serial");
    RecordAll(runtime, plugin, fresh);
    Check(plugin.PollResult(fresh, result) == 0, "new epoch also pending before submit");
    // Both old and new pools are referenced by this real command list. Its
    // execution checks that BeforeReset did not immediately discard old objects.
    runtime.SubmitAndWait();
    plugin.VerifyResult(fresh, 10, 11, 12, plugin.current.deviceEpoch);
    Check(plugin.PollResult(old, result) == -1, "old epoch receipt remains invalid after completion");
}

void PostAppendFenceFailureAndRetirementCap(Host& runtime, Plugin& plugin)
{
    ++scenarios;
    // Four is the plugin's explicit maximum number of quarantined device pools.
    // Each iteration corrupts only the SECOND NextFence call in one event: the
    // pre-append fence is valid, then the host violates its post-append contract.
    // This is injected host metadata failure, not actual D3D12 device removal.
    constexpr unsigned RetirementCapacity = 4;
    for (unsigned quarantined = 1; quarantined <= RetirementCapacity; ++quarantined)
    {
        runtime.Begin();
        const auto oldEpoch = plugin.current.deviceEpoch;
        const auto token = plugin.acquire(70, 80, 90 + quarantined);
        Check(token != 0, "acquire post-append failure candidate");
        runtime.nextFenceCallsUntilInvalid = 2;
        plugin.Event(token, 0);
        Check(runtime.nextFenceCallsUntilInvalid == 0 && runtime.injectedFenceFailures == quarantined,
            "one callback received a valid pre-fence and an injected zero post-fence");
        Check(plugin.acquire(1, 1, 1) == 0, "unproven retirement immediately disables acquisition");
        hlgi::TimingResult result{};
        Check(plugin.PollResult(token, result) == -1, "unproven retirement never publishes old receipt");
        hlgi::ApiInfo state{};
        Check(plugin.info(&state, sizeof(state)) == 1 &&
            state.status == static_cast<std::uint32_t>(hlgi::NativeStatus::Uninitialized),
            "post-append failure leaves explicit unavailable status");
        for (unsigned event = 1; event < 7; ++event) plugin.Event(token, event);
        // The timestamp has already been appended. Execute it for real after the
        // plugin has quarantined the query heap, exercising the retained lifetime.
        runtime.SubmitAndWait();
        Check(plugin.PollResult(token, result) == -1, "actual fence completion does not resurrect invalid receipt");
        runtime.deviceCallback(kUnityGfxDeviceEventAfterReset);
        if (quarantined < RetirementCapacity)
        {
            plugin.Ready();
            Check(plugin.current.deviceEpoch > oldEpoch, "reset can initialize a fresh active pool after quarantine");
            runtime.Begin();
            for (unsigned event = 0; event < 7; ++event) plugin.Event(token, event);
            const std::int64_t frame = 20000 + quarantined;
            const auto fresh = plugin.acquire(100, 200, frame);
            Check(fresh > token, "quarantine recovery preserves unique submission identity");
            RecordAll(runtime, plugin, fresh);
            Check(plugin.PollResult(fresh, result) == 0, "recovered pool still requires a real completion fence");
            runtime.SubmitAndWait();
            plugin.VerifyResult(fresh, 100, 200, frame, plugin.current.deviceEpoch);
            Check(plugin.PollResult(token, result) == -1, "quarantined token cannot affect replacement pool");
        }
        else
        {
            Check(plugin.info(&state, sizeof(state)) == 1 &&
                state.status == static_cast<std::uint32_t>(hlgi::NativeStatus::RetirementCapacity),
                "four unproven retired pools trigger the bounded capacity fallback");
            Check(plugin.acquire(1, 1, 1) == 0, "no fifth active allocation past retirement capacity");
            Check(plugin.PollResult(token, result) == -1, "capacity fallback yields no invalid timing result");
        }
    }
}

std::filesystem::path DllPath(int argc, wchar_t** argv)
{
    if (argc > 1) return std::filesystem::absolute(argv[1]);
    std::array<wchar_t, 32768> path{};
    const DWORD length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    Check(length != 0 && length < path.size(), "find smoke executable directory");
    return std::filesystem::path(path.data()).parent_path() / L"HybridLumenGIGpuTiming.dll";
}
} // namespace

int wmain(int argc, wchar_t** argv)
{
    // Keep the host alive until process exit even on a failed GPU wait. A timeout
    // is not evidence that resources referenced by submitted commands can die.
    Host* runtime = nullptr;
    try
    {
        runtime = new Host();
        Plugin plugin(DllPath(argc, argv));
        plugin.load(&runtime->interfaces);
        plugin.Ready();
        Check(runtime->configureCalls == 7 && runtime->configValid, "seven safe native event configurations");
        Check(runtime->callbackRegistrationValid, "valid native device callback registration");
        hlgi::ApiInfo malformed{};
        Check(plugin.info(&malformed, sizeof(malformed) - 1) == 0, "wrong GetInfo ABI size rejected");
        hlgi::TimingResult malformedResult{};
        Check(plugin.poll(0, &malformedResult, sizeof(malformedResult) - 1) == -1,
            "wrong Poll ABI size rejected");
        RoundTripAndReuse(*runtime, plugin);
        CancelBeforeAndLateCallbacks(*runtime, plugin);
        CancelAfterBeginRetainsSlot(*runtime, plugin);
        IncompleteResolveAndDuplicate(*runtime, plugin);
        DeviceEventResetWithPendingWork(*runtime, plugin);
        PostAppendFenceFailureAndRetirementCap(*runtime, plugin);
        ++scenarios;
        runtime->deviceCallback(kUnityGfxDeviceEventShutdown);
        Check(plugin.acquire(1, 1, 1) == 0, "shutdown disables acquisition");
        plugin.unload();
        Check(runtime->deviceCallback == nullptr && runtime->callbackRegistrationValid,
            "UnityPluginUnload unregisters device callback");
        Check(plugin.info(&malformed, sizeof(malformed)) == 1 &&
            malformed.status == static_cast<std::uint32_t>(hlgi::NativeStatus::Uninitialized),
            "unloaded host status is uninitialized");
        runtime->CheckDebugMessages();
        Check(runtime->configValid && runtime->configureCalls == 35,
            "only five successful device initializations configure seven event IDs");
        std::cout << "NativeTimingSmoke PASS: " << scenarios << " scenarios, " << checks
                  << " checks, " << runtime->submissions << " real D3D12 submissions, "
                  << plugin.validResults << " complete timestamp results, "
                  << runtime->copyCommands << " bounded 64 KiB copies.\n";
        std::cout << "Injected host post-append fence failures: " << runtime->injectedFenceFailures
                  << "; four unproven device pools reach the bounded retirement fallback.\n";
        std::cout << "Debug layer: " << (runtime->debugEnabled ? "enabled" : "unavailable (not installed by test)")
                  << "; fence wait limit: 10 seconds per submission.\n";
        std::cout << "Evidence: actual Windows WARP software adapter, native DLL, timestamps, resolve and fence readback; "
                     "simulated single-threaded Unity v7 host. No Unity/RenderGraph, physical GPU, real device-loss, "
                     "or hot-unload validation.\n";
        // All submitted work is complete; normal-path host resource release is safe.
        delete runtime;
        host = nullptr;
        return 0;
    }
    catch (const Unavailable& error)
    {
        std::cout << "NativeTimingSmoke UNAVAILABLE: " << error.what()
                  << ". No component was installed.\n";
        return 2;
    }
    catch (const std::exception& error)
    {
        std::cerr << "NativeTimingSmoke FAIL: " << error.what() << '\n';
        if (runtime)
        {
            try { runtime->CheckDebugMessages(); } catch (...) {}
        }
        // On failure, conservatively retain native resources to process exit.
        return 1;
    }
}
