> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Native DX12 timing evidence

The authoritative current candidate evidence is `offline-validation-results.json`, stage `NativeGpuTiming`, with its embedded `nativeGpuTimingReport`. The separate `native-gpu-timing-validation-results.json` is a copy from the same suite run. Current source hashes must pass `Verify-OfflineReport.ps1`; an old result is not evidence for changed sources.

The native implementation is built as a Windows x64 Release DLL with MSVC C++17, `/W4 /WX`, static CRT, and pinned official Unity interface headers. These headers are an external build dependency under their own Unity Companion License; see the bundled third-party notices. No Unity installation is used here.

Three distinct tests cover different boundaries:

- The actual C# coordinator runs against an injected fake C ABI: 2,750 assertions cover identity, owner/generation/device epoch, completed-frame selection, disabled behavior, missing DLL/capability fallback, cancellation and bounded pending work. This test does not call the real DLL.
- The actual C++ `QueryPool` runs eight scenarios, including 1,000,000 reuse transactions and 200,000 independent event-log oracle actions. It checks ordered events, cancellation, fence retirement, stale IDs, reset and ID exhaustion. These are CPU state-machine tests.
- The actual DLL runs against a mock single-threaded Unity v7 host backed by a real D3D12 WARP software device. Seven scenarios execute 268 D3D12 submissions and consume 262 complete timestamp results, with 8,806 checks. The workload includes bounded buffer copies; measured WARP times are not physical-GPU performance numbers.

The WARP test verifies pending results before submission, identity/frequency/timestamp order, one-time consumption, cancellation with late events, no early reuse after a timestamp was recorded, missing queries, duplicate events and all 128 slots traversed repeatedly. Reset notifications reuse the same real device and keep old/new resources referenced until execution; they are not real device-removal tests. Four injected post-append invalid fence values verify quarantine, safe execution of already recorded commands and the four-pool retirement limit.

The D3D12 debug layer was unavailable and was not installed. The mock host does not prove real Unity callback threading, frame-fence semantics, native render-pass merging, RenderGraph scheduling, camera lifecycle, plugin unloading, Editor/Player behavior or actual hardware timing. Manual hot-unload is unsupported.

The budget controller separately rejects exact measurements from before the current configuration or latest quota adjustment, and duplicate/backwards/future source frames. Recorder supplies no trustworthy query frame and keeps its explicitly weaker fallback contract. Synthetic controller inputs are never presented as actual GPU measurements.

Friend-side acceptance must cover Editor, Development and Release Player; native render passes on/off; multiple cameras and prolonged camera churn; backlog and cancellation; configuration/backend changes; and comparison with an independent GPU profiler. All Unity and physical-GPU acceptance fields remain false until such evidence exists.
