> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Per-frame GPU timing coordination

The 2026-10-27 standalone run passed **7 scenarios / 1,048 assertions** under both Windows PowerShell 5.1 and PowerShell 7. Run `Tests/Validate-GpuFrameTiming.ps1` from the package root.

The harness compiles the actual `HybridLumenGIGpuFrameTiming`, `HybridLumenGIGpuTiming`, and `HybridLumenGINativeGpuTiming` classes together. Unity profiler/command-buffer APIs are explicit recording substitutes; the native bridge uses an injected fake ABI. No Unity, RenderGraph scheduler, profiler, actual DLL, D3D12 query/fence, or GPU is executed by this test.

The coordinator freezes the selected provider's current token. Its optional ordered phase chain is ReceiverCapture, IdentityClear, IdentityMask, IdentityCapture, IdentityResolve, Transport, Composite. Recorder uses one local BeginSample/EndSample pair in each active pass. Native ABI1 retains events 0 through 6: ReceiverCapture begins in the material pass, ends after identity resolution when enabled, followed by Transport, Composite, and a separate Unsafe resolution pass. This leaves the native DLL ABI unchanged. Native timing measures the enclosing capture-chain interval, including any intervening queue work; it does not separately measure identity.

Checks cover both providers with and without identity; default-disabled/no-token calls; every command-emission fault in each chain; duplicate, skipped, truncated, out-of-order and invalid phases; explicit invalidation; cleanup after invalidation/disposal; old callbacks after a new frame; null, throwing and no-op feedback callbacks; callback replacement of the current token; exactly-once cleanup after EndSample failure; and 192 independently mutated legal phase words. Each successful Recorder begin is paired in the same mock command buffer when that End command returns successfully.

A throwing BeginSample or EndSample has an unknown native append outcome. Only those command-emission exceptions call `Recorder.RejectCommandRecording()`, permanently latching that Recorder instance/channel in `CommandRecordingFailure`. The helper first rejects current-frame feedback, then disables the channel. Tests inject failures both before and after the substitute appends Begin/End, and confirm ten subsequent frames neither warm up nor emit/allocate replacement markers. Begin failure closes CPU open-marker bookkeeping without claiming an unmatched native End is safe. End is attempted only once. Logical RecordBegin rejection, ordinary metadata/graph invalidation, and native-plugin command exceptions do not latch the Recorder channel; the native path retains its existing cancellation-based recovery.

The callback is followed by a current-token check. If a no-op callback leaves the original provider token active, the helper invalidates that provider directly. If the callback has already installed a new token, it is not invalidated. Timings can fail without throwing into GI recording.

Ordinary late callbacks do not revoke a newer frame. There is one explicit channel-safety exception: if an old, actually begun marker's late End command throws, that same Recorder channel must be latched even if a newer frame has started using it. This disables that channel's newer timing receipt, while the old frame's controller-invalidation callback is not invoked. The test covers this distinction; it does not claim all old callbacks have no timing side effects. Current GI remains independent of timing availability.

`Profile(CommandBuffer, string)` isolates the existing string diagnostic markers through a mutable value-type `DiagnosticScope`. A normal `using` does not box the scope; a 1,024-iteration check with a no-allocation command substitute observes zero helper allocations. This does not measure Unity's internal profiler allocations. Repeated `Dispose` on the same instance attempts End once; copying and independently disposing the struct is outside its contract. Diagnostics remain active with feedback disabled. Their Begin/End exceptions before or after mock append never skip the using body or replace its real exception. A string marker fault rejects feedback, latches the Recorder channel, and suppresses later diagnostic Begins in that helper; scopes whose Begin already succeeded still attempt their corresponding End. CustomSampler command faults also suppress later diagnostics. Native plugin-event failures use cancellation and leave diagnostics available.

The fixed official Graphics revision is `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53`. Its [CommandBufferHelpers.cs](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.core/Runtime/CommandBuffers/CommandBufferHelpers.cs#L59), blob `3f7ddbc331000d2a8fa0d81d93541e09aa3c2bc3`, provides `GetNativeCommandBuffer(UnsafeCommandBuffer)` only. There is no public Raster overload. The helper therefore accepts raw and Raster command buffers through separate overloads, sharing the same state machine. [RasterCommandBuffer.cs](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.core/Runtime/CommandBuffers/RasterCommandBuffer.cs#L747), blob `bba9327e2a1a1a2c54949647ccac84f4adfba4af`, exposes `IssuePluginEventAndData` directly alongside its BeginSample/EndSample wrappers. No inaccessible wrapped-buffer member is used.

Frozen source identities for this run:

| File | SHA-256 |
| --- | --- |
| Runtime/HybridLumenGIGpuFrameTiming.cs | `6735E30D7A75CE5A9638ED293F52D1274F2B69DD21235C9B0EF72EE23441AAB8` |
| Runtime/HybridLumenGIGpuTiming.cs | `C895D10DAA0995B68672D1989D7FDABEF5C76B6F86ABAD0C4A098214B3C8C7ED` |
| Runtime/HybridLumenGINativeGpuTiming.cs | `0AF2965F5901D8E35F40DE798F17F48E33A51157CE740DDA12183232ED67FB60` |
| Tests/Validate-GpuFrameTiming.ps1 | `BF63BEF8FD74B20368FAF5871738EB9CA9B2872936BECF26C2A27DC86E8A6A43` |
| Tests/StandaloneGpuFrameTiming/Program.cs.txt | `81AB168EAA3E80F89B53C6524B59FABBADA786C595A2A4E66C3A35650DEFD12B` |
| Tests/StandaloneGpuFrameTiming/UnityStubs.cs.txt | `4DAA077709A3A01D9A86327423ED5C298DE20A7CE1D25EDD5F68A2A7EFE64863` |

Real Unity still needs to verify pass ordering, native callbacks, seven local Recorder sample availability, cancellation during engine teardown, and measured device performance. These CPU assertions do not constitute that acceptance.
