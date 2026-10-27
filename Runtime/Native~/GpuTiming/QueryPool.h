#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace hlgi
{
inline constexpr std::size_t Capacity = 128;
inline constexpr unsigned QueriesPerSample = 6;

enum class Phase : unsigned char { Free, Reserved, Recording, Resolved, Canceled };

struct Slot
{
    std::uint64_t token = 0;
    std::uint64_t owner = 0;
    std::uint64_t generation = 0;
    std::uint64_t deviceEpoch = 0;
    std::uint64_t requiredFence = 0;
    std::int64_t engineFrame = 0;
    unsigned nextEvent = 0;
    bool touched = false;
    Phase phase = Phase::Free;
};

// CPU bookkeeping only. The caller serializes all access, owns the GPU resources,
// and retains those resources until their retirement fence or device removal.
// Events 0..5 write timestamps; event 6 resolves all six timestamps.
class QueryPool
{
public:
    using Slot = hlgi::Slot;
    using Phase = hlgi::Phase;
    static constexpr std::uint64_t MaxToken =
        static_cast<std::uint64_t>((std::numeric_limits<std::int64_t>::max)());
    static constexpr std::uint64_t MaxSerial = MaxToken / Capacity;

    // A nonzero seed exists for deterministic exhaustion tests. It must never be
    // restored to an earlier value while callbacks from this pool can survive.
    explicit QueryPool(std::uint64_t initialSerial = 0) noexcept
        : nextSerial_(initialSerial) {}

    QueryPool(const QueryPool&) = delete;
    QueryPool& operator=(const QueryPool&) = delete;
    QueryPool(QueryPool&&) = delete;
    QueryPool& operator=(QueryPool&&) = delete;

    std::uint64_t Acquire(std::uint64_t owner, std::uint64_t generation,
        std::int64_t frame, std::uint64_t epoch) noexcept
    {
        if (active_ == Capacity || nextSerial_ > MaxSerial)
            return 0;
        for (std::size_t n = 0; n < Capacity; ++n)
        {
            const std::size_t index = (cursor_ + n) % Capacity;
            if (slots_[index].phase != Phase::Free)
                continue;
            const std::uint64_t offset = static_cast<std::uint64_t>(index) + 1;
            if (nextSerial_ > (MaxToken - offset) / Capacity)
                continue;
            const std::uint64_t token = nextSerial_ * Capacity + offset;
            ++nextSerial_;
            Slot& slot = slots_[index];
            slot = Slot{};
            slot.token = token;
            slot.owner = owner;
            slot.generation = generation;
            slot.engineFrame = frame;
            slot.deviceEpoch = epoch;
            slot.phase = Phase::Reserved;
            ++active_;
            cursor_ = (index + 1) % Capacity;
            return token;
        }
        return 0;
    }

    static constexpr std::size_t Index(std::uint64_t token) noexcept
    {
        return token == 0 || token > MaxToken ? Capacity :
            static_cast<std::size_t>((token - 1) % Capacity);
    }

    Slot* Find(std::uint64_t token) noexcept
    {
        const std::size_t index = Index(token);
        if (index == Capacity)
            return nullptr;
        Slot& slot = slots_[index];
        return slot.phase != Phase::Free && slot.token == token ? &slot : nullptr;
    }

    const Slot* Find(std::uint64_t token) const noexcept
    {
        const std::size_t index = Index(token);
        if (index == Capacity)
            return nullptr;
        const Slot& slot = slots_[index];
        return slot.phase != Phase::Free && slot.token == token ? &slot : nullptr;
    }

    // Does not advance the sequence. On failure, only this exact live token is
    // canceled; stale callbacks must not cancel a new occupant of the same slot.
    bool CanRecord(std::uint64_t token, unsigned event) noexcept
    {
        Slot* slot = Find(token);
        if (!slot)
            return false;
        if ((slot->phase == Phase::Reserved || slot->phase == Phase::Recording) &&
            event <= QueriesPerSample && event == slot->nextEvent)
            return true;
        Cancel(token);
        return false;
    }

    static constexpr bool IsUsableFence(std::uint64_t fence) noexcept
    {
        return fence != 0 && fence != (std::numeric_limits<std::uint64_t>::max)();
    }

    // PRECONDITION: the caller checked CanRecord and IsUsableFence BEFORE issuing
    // the GPU command, then calls Recorded in the same serialized operation.
    // This function cannot make an already-issued command with no valid fence safe.
    bool Recorded(std::uint64_t token, unsigned event, std::uint64_t fence) noexcept
    {
        if (!IsUsableFence(fence))
        {
            Cancel(token);
            return false;
        }
        if (!CanRecord(token, event))
            return false;
        Slot& slot = *Find(token);
        if (fence > slot.requiredFence)
            slot.requiredFence = fence;
        slot.touched = true;
        ++slot.nextEvent;
        slot.phase = event == QueriesPerSample ? Phase::Resolved : Phase::Recording;
        return true;
    }

    void Cancel(std::uint64_t token) noexcept
    {
        Slot* slot = Find(token);
        if (!slot)
            return;
        if (!slot->touched)
            Release(*slot);
        else
            slot->phase = Phase::Canceled;
    }

    std::size_t Collect(std::uint64_t completedFence) noexcept
    {
        if (!IsUsableFence(completedFence))
            return 0;
        std::size_t reclaimed = 0;
        for (Slot& slot : slots_)
        {
            if (slot.phase == Phase::Canceled && IsUsableFence(slot.requiredFence) &&
                slot.requiredFence <= completedFence)
            {
                Release(slot);
                ++reclaimed;
            }
        }
        return reclaimed;
    }

    bool CanRead(std::uint64_t token, std::uint64_t completedFence) const noexcept
    {
        const Slot* slot = Find(token);
        return slot && slot->phase == Phase::Resolved && slot->touched &&
            slot->nextEvent == QueriesPerSample + 1 && IsUsableFence(completedFence) &&
            IsUsableFence(slot->requiredFence) && slot->requiredFence <= completedFence;
    }

    bool Consume(std::uint64_t token, std::uint64_t completedFence) noexcept
    {
        if (!CanRead(token, completedFence))
            return false;
        Release(*Find(token));
        return true;
    }

    // Invalidates all CPU receipts. This does NOT release or retire GPU objects.
    // The plugin must preserve the old device's resources independently if needed.
    void ResetDevice() noexcept
    {
        slots_ = {};
        active_ = 0;
        cursor_ = 0;
        // nextSerial_ deliberately survives device resets, preventing token ABA.
    }

    std::size_t ActiveCount() const noexcept { return active_; }

    std::uint64_t HighestFence() const noexcept
    {
        std::uint64_t highest = 0;
        for (const Slot& slot : slots_)
            if (slot.phase != Phase::Free && slot.requiredFence > highest)
                highest = slot.requiredFence;
        return highest;
    }

private:
    void Release(Slot& slot) noexcept
    {
        slot = Slot{};
        --active_;
    }

    std::array<Slot, Capacity> slots_{};
    std::uint64_t nextSerial_ = 0;
    std::size_t cursor_ = 0;
    std::size_t active_ = 0;
};
} // namespace hlgi
