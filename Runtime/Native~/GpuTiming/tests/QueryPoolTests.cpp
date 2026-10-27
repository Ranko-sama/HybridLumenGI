#include "../QueryPool.h"

#include <algorithm>
#include <array>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <random>
#include <string>
#include <unordered_map>
#include <vector>

namespace
{
std::uint64_t assertions = 0;
unsigned scenarios = 0;
constexpr std::uint64_t Removed = (std::numeric_limits<std::uint64_t>::max)();

void Check(bool condition, const char* expression, int line)
{
    ++assertions;
    if (!condition)
    {
        std::cerr << "FAIL line " << line << ": " << expression << '\n';
        std::exit(1);
    }
}
#define CHECK(value) Check((value), #value, __LINE__)

void Record(hlgi::QueryPool& pool, std::uint64_t token, unsigned event, std::uint64_t fence)
{
    CHECK(pool.CanRecord(token, event));
    CHECK(pool.Recorded(token, event, fence));
}

void Complete(hlgi::QueryPool& pool, std::uint64_t token, std::uint64_t firstFence)
{
    for (unsigned event = 0; event <= hlgi::QueriesPerSample; ++event)
        Record(pool, token, event, firstFence + event);
}

void CapacityAndIdentity()
{
    ++scenarios;
    hlgi::QueryPool pool;
    CHECK(pool.ActiveCount() == 0);
    CHECK(pool.HighestFence() == 0);
    CHECK(pool.Find(0) == nullptr);
    CHECK(pool.Find(Removed) == nullptr);
    CHECK(hlgi::QueryPool::Index(0) == hlgi::Capacity);
    CHECK(hlgi::QueryPool::Index(Removed) == hlgi::Capacity);
    std::array<std::uint64_t, hlgi::Capacity> tokens{};
    for (std::size_t i = 0; i < tokens.size(); ++i)
    {
        tokens[i] = pool.Acquire(100 + i, 200 + i, -40 + static_cast<std::int64_t>(i), 300 + i);
        CHECK(tokens[i] > 0 && tokens[i] <= hlgi::QueryPool::MaxToken);
        CHECK(hlgi::QueryPool::Index(tokens[i]) == i);
        CHECK(i == 0 || tokens[i] > tokens[i - 1]);
        const hlgi::QueryPool& immutable = pool;
        const hlgi::Slot* slot = immutable.Find(tokens[i]);
        CHECK(slot != nullptr);
        CHECK(slot->owner == 100 + i && slot->generation == 200 + i);
        CHECK(slot->engineFrame == -40 + static_cast<std::int64_t>(i));
        CHECK(slot->deviceEpoch == 300 + i && slot->phase == hlgi::Phase::Reserved);
        CHECK(!slot->touched && slot->requiredFence == 0 && slot->nextEvent == 0);
        CHECK(pool.ActiveCount() == i + 1);
    }
    CHECK(pool.Acquire(1, 1, 1, 1) == 0);
    const auto stale = tokens[43];
    pool.Cancel(stale);
    CHECK(pool.Find(stale) == nullptr && pool.ActiveCount() == hlgi::Capacity - 1);
    const auto replacement = pool.Acquire(8, 9, 10, 11);
    CHECK(replacement > tokens.back());
    CHECK(hlgi::QueryPool::Index(replacement) == hlgi::QueryPool::Index(stale));
    CHECK(!pool.CanRecord(stale, 0));
    pool.Cancel(stale);
    CHECK(pool.Find(replacement) && pool.ActiveCount() == hlgi::Capacity);
}

void CompleteAndFenceDelay()
{
    ++scenarios;
    hlgi::QueryPool pool;
    const auto token = pool.Acquire(1, 2, 3, 4);
    CHECK(pool.CanRecord(token, 0));
    CHECK(pool.CanRecord(token, 0)); // validation is not an event submission
    CHECK(pool.Find(token)->nextEvent == 0);
    for (unsigned event = 0; event < hlgi::QueriesPerSample; ++event)
    {
        Record(pool, token, event, 20 + event);
        CHECK(!pool.CanRead(token, 1000));
        CHECK(!pool.Consume(token, 1000));
        CHECK(pool.Collect(1000) == 0); // live recording must not be stolen
    }
    Record(pool, token, hlgi::QueriesPerSample, 50);
    CHECK(pool.Find(token)->phase == hlgi::Phase::Resolved);
    CHECK(pool.HighestFence() == 50);
    CHECK(!pool.CanRead(token, 0) && !pool.CanRead(token, 49));
    CHECK(!pool.CanRead(token, Removed));
    CHECK(pool.Collect(Removed) == 0);
    CHECK(pool.Collect(1000) == 0); // ready results belong to the consumer
    CHECK(pool.CanRead(token, 50) && pool.CanRead(token, 1000));
    CHECK(!pool.Consume(token, 49));
    CHECK(pool.Consume(token, 50));
    CHECK(!pool.Consume(token, 50));
    CHECK(pool.Find(token) == nullptr && pool.ActiveCount() == 0);
    CHECK(pool.HighestFence() == 0);
}

void CancellationAndPartialWork()
{
    ++scenarios;
    for (unsigned recorded = 0; recorded <= hlgi::QueriesPerSample + 1; ++recorded)
    {
        hlgi::QueryPool pool;
        const auto token = pool.Acquire(1, 1, 1, 1);
        for (unsigned event = 0; event < recorded; ++event)
            Record(pool, token, event, 100 + event);
        pool.Cancel(token);
        pool.Cancel(token);
        if (recorded == 0)
        {
            CHECK(pool.ActiveCount() == 0 && pool.Find(token) == nullptr);
            CHECK(pool.Collect(Removed) == 0);
            continue;
        }
        const std::uint64_t retirement = 100 + recorded - 1;
        CHECK(pool.ActiveCount() == 1);
        CHECK(pool.Find(token)->phase == hlgi::Phase::Canceled);
        CHECK(pool.Find(token)->requiredFence == retirement);
        CHECK(!pool.CanRead(token, retirement));
        CHECK(!pool.CanRecord(token, recorded));
        CHECK(pool.Collect(0) == 0 && pool.Collect(Removed) == 0);
        CHECK(pool.Collect(retirement - 1) == 0);
        CHECK(pool.Collect(retirement) == 1);
        CHECK(pool.Collect(retirement) == 0 && pool.ActiveCount() == 0);
    }
    hlgi::QueryPool pool;
    const auto token = pool.Acquire(2, 2, 2, 2);
    Record(pool, token, 0, 100);
    Record(pool, token, 1, 20); // max fence must survive a lower later observation
    CHECK(pool.HighestFence() == 100);
    pool.Cancel(token);
    CHECK(pool.Collect(99) == 0 && pool.Collect(100) == 1);
}

void InvalidEventsAndFences()
{
    ++scenarios;
    for (unsigned prefix = 0; prefix <= hlgi::QueriesPerSample + 1; ++prefix)
    {
        for (unsigned invalid = 0; invalid <= hlgi::QueriesPerSample + 2; ++invalid)
        {
            if (prefix <= hlgi::QueriesPerSample && invalid == prefix)
                continue;
            hlgi::QueryPool pool;
            const auto token = pool.Acquire(1, 1, 1, 1);
            for (unsigned event = 0; event < prefix; ++event)
                Record(pool, token, event, 100 + event);
            CHECK(!pool.CanRecord(token, invalid));
            if (prefix == 0)
                CHECK(pool.ActiveCount() == 0);
            else
            {
                CHECK(pool.Find(token)->phase == hlgi::Phase::Canceled);
                CHECK(pool.Find(token)->nextEvent == prefix);
                CHECK(pool.Collect(100 + prefix - 2) == 0);
                CHECK(pool.Collect(100 + prefix - 1) == 1);
            }
        }
    }
    for (const auto invalidFence : {std::uint64_t{0}, Removed})
    {
        hlgi::QueryPool pool;
        auto token = pool.Acquire(1, 1, 1, 1);
        CHECK(!hlgi::QueryPool::IsUsableFence(invalidFence));
        CHECK(!pool.Recorded(token, 0, invalidFence));
        CHECK(pool.ActiveCount() == 0);
        token = pool.Acquire(1, 1, 1, 1);
        Record(pool, token, 0, 8);
        CHECK(!pool.Recorded(token, 1, invalidFence));
        CHECK(pool.Find(token)->requiredFence == 8);
        CHECK(pool.Find(token)->nextEvent == 1);
        CHECK(pool.Collect(7) == 0 && pool.Collect(8) == 1);
    }
    CHECK(hlgi::QueryPool::IsUsableFence(1));
    CHECK(hlgi::QueryPool::IsUsableFence(Removed - 1));
    hlgi::QueryPool pool;
    auto token = pool.Acquire(1, 1, 1, 1);
    CHECK(!pool.Recorded(token, 6, 8)); // Recorded also enforces the order
    CHECK(pool.ActiveCount() == 0);
}

void ResetAndExhaustion()
{
    ++scenarios;
    hlgi::QueryPool pool;
    const auto stale = pool.Acquire(1, 1, 100, 1);
    Complete(pool, stale, 1000);
    const auto unrecorded = pool.Acquire(1, 1, 101, 1);
    pool.ResetDevice();
    CHECK(pool.ActiveCount() == 0 && pool.HighestFence() == 0);
    CHECK(pool.Find(stale) == nullptr && pool.Find(unrecorded) == nullptr);
    const auto fresh = pool.Acquire(1, 1, 100, 2);
    CHECK(fresh > unrecorded);
    CHECK(hlgi::QueryPool::Index(fresh) == hlgi::QueryPool::Index(stale));
    CHECK(!pool.CanRecord(stale, 0) && !pool.Recorded(stale, 0, 1));
    CHECK(!pool.Consume(stale, 10000));
    CHECK(pool.Find(fresh)->deviceEpoch == 2 && pool.ActiveCount() == 1);
    CHECK(pool.Find(fresh)->nextEvent == 0);

    hlgi::QueryPool nearEnd(hlgi::QueryPool::MaxSerial);
    const auto last = nearEnd.Acquire(1, 1, 1, 1);
    CHECK(last > 0 && last <= hlgi::QueryPool::MaxToken);
    nearEnd.Cancel(last);
    CHECK(nearEnd.Acquire(1, 1, 1, 1) == 0);
    nearEnd.ResetDevice();
    CHECK(nearEnd.Acquire(1, 1, 1, 2) == 0);
    hlgi::QueryPool exhausted(hlgi::QueryPool::MaxSerial + 1);
    CHECK(exhausted.Acquire(1, 1, 1, 1) == 0);
    hlgi::QueryPool impossible(Removed);
    CHECK(impossible.Acquire(1, 1, 1, 1) == 0);
    CHECK(hlgi::QueryPool::Index(hlgi::QueryPool::MaxToken) == hlgi::Capacity - 2);
}

// This oracle stores a transaction's submitted event log, not the implementation's
// array, index/serial arithmetic, nextEvent counter, or Phase state machine.
struct Receipt
{
    std::uint64_t owner, generation, epoch;
    std::int64_t frame;
    std::vector<std::uint64_t> eventFences;
    bool canceled = false;
};

struct Oracle
{
    std::unordered_map<std::uint64_t, Receipt> receipts;

    void Cancel(std::uint64_t token)
    {
        auto it = receipts.find(token);
        if (it == receipts.end()) return;
        if (it->second.eventFences.empty()) receipts.erase(it);
        else it->second.canceled = true;
    }

    bool Permit(std::uint64_t token, unsigned event)
    {
        auto it = receipts.find(token);
        if (it == receipts.end()) return false;
        if (!it->second.canceled && event < 7 &&
            it->second.eventFences.size() == event) return true;
        Cancel(token);
        return false;
    }

    static std::uint64_t Fence(const Receipt& receipt)
    {
        return receipt.eventFences.empty() ? 0 :
            *std::max_element(receipt.eventFences.begin(), receipt.eventFences.end());
    }

    bool Ready(std::uint64_t token, std::uint64_t completed) const
    {
        auto it = receipts.find(token);
        return it != receipts.end() && !it->second.canceled &&
            it->second.eventFences.size() == 7 && completed != 0 &&
            completed != Removed && completed >= Fence(it->second);
    }

    std::size_t Collect(std::uint64_t completed)
    {
        if (completed == 0 || completed == Removed) return 0;
        std::vector<std::uint64_t> retired;
        for (const auto& pair : receipts)
            if (pair.second.canceled && Fence(pair.second) <= completed)
                retired.push_back(pair.first);
        for (const auto token : retired) receipts.erase(token);
        return retired.size();
    }

    void Compare(const hlgi::QueryPool& pool) const
    {
        CHECK(pool.ActiveCount() == receipts.size());
        std::uint64_t highest = 0;
        std::array<bool, hlgi::Capacity> occupied{};
        for (const auto& pair : receipts)
        {
            const auto* slot = pool.Find(pair.first);
            const auto& receipt = pair.second;
            CHECK(slot != nullptr);
            CHECK(slot->owner == receipt.owner && slot->generation == receipt.generation);
            CHECK(slot->engineFrame == receipt.frame && slot->deviceEpoch == receipt.epoch);
            CHECK(slot->nextEvent == receipt.eventFences.size());
            CHECK(slot->touched == !receipt.eventFences.empty());
            CHECK(slot->requiredFence == Fence(receipt));
            const auto expected = receipt.canceled ? hlgi::Phase::Canceled :
                receipt.eventFences.empty() ? hlgi::Phase::Reserved :
                receipt.eventFences.size() == 7 ? hlgi::Phase::Resolved : hlgi::Phase::Recording;
            CHECK(slot->phase == expected);
            const auto index = hlgi::QueryPool::Index(pair.first);
            CHECK(index < hlgi::Capacity && !occupied[index]);
            occupied[index] = true;
            highest = std::max(highest, Fence(receipt));
        }
        CHECK(pool.HighestFence() == highest);
    }
};

void RandomizedOracle()
{
    ++scenarios;
    hlgi::QueryPool pool;
    Oracle oracle;
    std::mt19937_64 random(0xd312713d427ULL);
    std::vector<std::uint64_t> history{0, Removed};
    std::uint64_t epoch = 1, lastToken = 0;
    for (unsigned step = 0; step < 200000; ++step)
    {
        const unsigned action = static_cast<unsigned>(random() % 12);
        std::uint64_t token = history[static_cast<std::size_t>(random() % history.size())];
        if (!oracle.receipts.empty() && random() % 4 != 0)
        {
            auto it = oracle.receipts.begin();
            std::advance(it, static_cast<std::ptrdiff_t>(random() % oracle.receipts.size()));
            token = it->first;
        }
        std::uint64_t completed = random() % 220;
        if (random() % 13 == 0) completed = Removed;
        if (action <= 3)
        {
            const auto owner = random() % 19;
            const auto generation = random() % 11;
            const auto acquired = pool.Acquire(owner, generation, step, epoch);
            CHECK((acquired != 0) == (oracle.receipts.size() < hlgi::Capacity));
            if (acquired)
            {
                CHECK(acquired > lastToken);
                lastToken = acquired;
                oracle.receipts.emplace(acquired, Receipt{owner, generation, epoch, step, {}, false});
                history.push_back(acquired);
            }
        }
        else if (action <= 6)
        {
            auto it = oracle.receipts.find(token);
            const unsigned event = it != oracle.receipts.end() && random() % 3 != 0 ?
                static_cast<unsigned>(it->second.eventFences.size()) :
                static_cast<unsigned>(random() % 9);
            const bool expected = oracle.Permit(token, event);
            CHECK(pool.CanRecord(token, event) == expected);
            if (expected && random() % 5 != 0)
            {
                const auto fence = 1 + random() % 200;
                oracle.receipts.at(token).eventFences.push_back(fence);
                CHECK(pool.Recorded(token, event, fence));
            }
        }
        else if (action == 7)
        {
            oracle.Cancel(token);
            pool.Cancel(token);
        }
        else if (action == 8)
        {
            CHECK(pool.Collect(completed) == oracle.Collect(completed));
        }
        else if (action == 9)
        {
            const bool ready = oracle.Ready(token, completed);
            CHECK(pool.CanRead(token, completed) == ready);
            CHECK(pool.Consume(token, completed) == ready);
            if (ready) oracle.receipts.erase(token);
        }
        else if (action == 10 && random() % 97 == 0)
        {
            ++epoch;
            oracle.receipts.clear();
            pool.ResetDevice();
        }
        else
        {
            CHECK(pool.CanRead(token, completed) == oracle.Ready(token, completed));
        }
        oracle.Compare(pool);
    }
}

void MillionTransactionChurn()
{
    ++scenarios;
    hlgi::QueryPool pool;
    std::array<std::uint64_t, hlgi::Capacity> stale{};
    std::array<std::uint64_t, hlgi::Capacity> uses{};
    std::uint64_t previous = 0;
    for (std::uint64_t i = 0; i < 1000000; ++i)
    {
        const auto token = pool.Acquire(i % 101, i / 50, static_cast<std::int64_t>(i), 1 + i / 10000);
        CHECK(token > previous && token <= hlgi::QueryPool::MaxToken);
        previous = token;
        const auto index = hlgi::QueryPool::Index(token);
        CHECK(index < hlgi::Capacity);
        ++uses[index];
        CHECK(pool.Find(stale[index]) == nullptr);
        CHECK(!pool.CanRecord(stale[index], 0));
        pool.Cancel(stale[index]);
        CHECK(pool.Find(token) && pool.ActiveCount() == 1);
        if (i % 3 == 0)
            pool.Cancel(token);
        else if (i % 3 == 1)
        {
            Record(pool, token, 0, i + 1);
            pool.Cancel(token);
            CHECK(pool.Collect(i) == 0);
            CHECK(pool.Collect(i + 1) == 1);
        }
        else
        {
            Complete(pool, token, i + 1);
            CHECK(!pool.Consume(token, i + 6));
            CHECK(pool.Consume(token, i + 7));
        }
        CHECK(pool.ActiveCount() == 0 && pool.HighestFence() == 0);
        stale[index] = token;
        if (i % 10000 == 9999) pool.ResetDevice();
    }
    for (const auto count : uses) CHECK(count > 7000);
}

void RecordingAdapterContract()
{
    ++scenarios;
    hlgi::QueryPool pool;
    unsigned emittedQueries = 0, emittedResolves = 0;
    std::array<bool, 6> written{};
    auto emit = [&](std::uint64_t token, unsigned event, std::uint64_t fence)
    {
        // The native adapter must perform both checks before touching D3D12.
        if (!hlgi::QueryPool::IsUsableFence(fence))
        {
            pool.Cancel(token);
            return false;
        }
        if (!pool.CanRecord(token, event)) return false;
        if (event < 6)
        {
            CHECK(!written[event]);
            written[event] = true;
            ++emittedQueries;
        }
        else
        {
            CHECK(std::all_of(written.begin(), written.end(), [](bool value) { return value; }));
            ++emittedResolves;
        }
        CHECK(pool.Recorded(token, event, fence));
        return true;
    };
    auto token = pool.Acquire(1, 1, 1, 1);
    CHECK(!emit(token, 0, 0));
    CHECK(emittedQueries == 0 && emittedResolves == 0);
    token = pool.Acquire(1, 1, 1, 1);
    CHECK(!emit(token, 6, 1));
    CHECK(emittedQueries == 0 && emittedResolves == 0);
    token = pool.Acquire(1, 1, 1, 1);
    CHECK(emit(token, 0, 1));
    CHECK(!emit(token, 0, 2));
    CHECK(!emit(token, 6, 2));
    CHECK(emittedQueries == 1 && emittedResolves == 0);
    CHECK(pool.Collect(1) == 1);
    written.fill(false);
    token = pool.Acquire(1, 1, 1, 1);
    for (unsigned event = 0; event < 7; ++event) CHECK(emit(token, event, 10 + event));
    CHECK(emittedQueries == 7 && emittedResolves == 1);
    CHECK(pool.Consume(token, 16));
}
} // namespace

int main()
{
    CapacityAndIdentity();
    CompleteAndFenceDelay();
    CancellationAndPartialWork();
    InvalidEventsAndFences();
    ResetAndExhaustion();
    RandomizedOracle();
    MillionTransactionChurn();
    RecordingAdapterContract();
    std::cout << "QueryPool PASS: " << scenarios << " scenarios, " << assertions
              << " assertions; 1,000,000 reuse transactions + 200,000 oracle actions.\n";
    std::cout << "Evidence: actual platform-independent C++17 state machine; no GPU/Unity/driver execution.\n";
    return 0;
}
