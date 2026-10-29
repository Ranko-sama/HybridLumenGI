#pragma once
#include <cstddef>
#include <cstdint>

// This is our ABI, not a copy of Unity's interfaces. Win64 only, default packing.
namespace hlgi {
enum class NativeStatus : std::uint32_t {
    Unsupported=0, Ready=1, DeviceLost=2, AllocationFailure=3,
    RetirementCapacity=4, Uninitialized=5
};
struct ApiInfo {
    std::uint32_t abiVersion, structSize, status, capacity;
    std::int32_t eventBase;
    std::uint32_t reserved;
    std::uint64_t deviceEpoch, frequency;
    void* callback;
};
struct TimingResult {
    std::uint64_t token, owner, generation, deviceEpoch;
    std::int64_t engineFrame;
    std::uint64_t frequency;
    std::uint64_t ticks[6];
};
// Independent optional export; the existing timestamp ABI remains unchanged.
// DXGI process usage/budget on Unity's adapter, node zero; not GI-only memory.
struct MemoryInfo {
    std::uint32_t abiVersion, structSize;
    std::uint64_t deviceEpoch, adapterLuid;
    std::uint64_t localUsage, localBudget, nonlocalUsage, nonlocalBudget;
};
static_assert(sizeof(void*)==8, "The native timing ABI requires Windows x64.");
static_assert(sizeof(ApiInfo)==48 && offsetof(ApiInfo,callback)==40, "API layout changed.");
static_assert(sizeof(TimingResult)==96 && offsetof(TimingResult,ticks)==48, "Result layout changed.");
static_assert(sizeof(MemoryInfo)==56 && offsetof(MemoryInfo,localUsage)==24, "Memory layout changed.");
}
