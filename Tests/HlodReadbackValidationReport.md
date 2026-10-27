> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# HLOD readback coordination validation

Run `powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-HlodReadback.ps1` from the package root. The script compiles the actual `Runtime/HybridLumenGIHlodReadback.cs` with .NET 8 and recording substitutes for Unity buffers/readback, scene tickets, surface cards and the object SDF atlas. The current suite contains **126 assertions**. Execution results and the exact source SHA256 are recorded in `offline-validation-results.json`; a result applies only while its source hash still matches.

The recording command buffer retains callbacks without completing them automatically. Tests mutate state while a request is pending, then manually supply data or a failure. They check:

- The 80-byte cache entry layout and relevant member offsets.
- No ticket before completion; one request while Pending; a new request only after the four-frame interval.
- Scene stable identity and revision, lighting epoch, material-atlas generation, owner layout generation and each actual card generation, including noncontiguous variable card sets.
- Every covered patch must have at least two samples. The retained six-view fixtures exercise failure at each of 24 patch positions. Real chart assets additionally require at least one covered patch in every required chart; explicit zero cells can be uncovered, but an entirely empty required chart cannot produce readiness. The approximate fallback keeps its weaker any-covered-page rule.
- Changed card membership, ownership, layout, patch grid, source-current status, SDF asset/texture/upload/transform and stale callbacks cannot publish a new representation. Normal double-buffer swapping alone does not invalidate an otherwise current request.
- Nonfinite values, stale tags, truncated readbacks, missing material/SDF readiness and no-longer-warming slots.
- Per-slot acceptance isolation, invalidation, disposal, native error callbacks and synchronous request-recording failure followed by retry.

The review found and corrected two runtime bugs: geometry-unready responses incremented `AcceptedTickets`, and a synchronous request exception left Pending latched without a callback. The corrected counter requires geometry readiness; synchronous failure releases Pending and increments the failure count. An earlier class-name collision with the scene's receipt store was also resolved: `HybridLumenGIHlodReadback` now owns asynchronous coordination, while `HybridLumenGIHlodReadiness` remains the pure receipt store exercised by the scene tests.

The native readback event, GPU data, driver fences, camera scheduling and real RenderGraph command ordering are **not exercised**. Scene and atlas dependencies are fixtures; separate actual-source scene and atlas tests cover those implementations. Passing this suite cannot demonstrate GPU completion or production rendering acceptance.
