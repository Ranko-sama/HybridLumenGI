# gpu-cost-baseline-01 — iteration 22

Accepted GPT 6 Pro plan: `../current-player-dxr-smoke-01/gpt6-pro-review-and-next-plan.txt`.

Default-off measurement must preserve static quotas with adaptive feedback disabled and target zero. Export every validated native completion through bounded managed storage; newest-only feedback semantics stay intact. Native ABI, six timestamps, query pool, transport, quality and resource dimensions stay unchanged.

Reuse the existing source/hash-matched native DLL. Run only affected actual-source NativeTimingBridge, GpuFrameTiming and GpuBudget checks. One new Development/Mono/DX12 build and one visible DXR run; no automatic rerun.

Existing Functional scene, fixed starting camera, frozen camera/door/material events, initial deformation snapshot only. At most 256 target-camera warmup frames, a preselected contiguous set of 512 source frames, and at most 32 drain frames (800 total). Readiness depends on actual backend/material/geometry/identity/static quotas, never observed timings. No images, texture readbacks, per-frame disk output or heavy probes in measurement. Preallocated bounded storage; write after window/drain. Drain keeps normal timing polls enabled.

Require NativeDX12 and all 512 unique valid completions with unchanged identity/configuration/work quotas. Preserve incomplete evidence without replacement frames or survivor-only percentiles. Report median, descriptive p95/p99 and max for each scope and per-source sum; sum before percentile. Exclude CPU preparation, out-of-scope uploads/graph cost and full-app GPU time. No invented target FPS or memory/performance threshold.

Stop on concrete integration failure, preserve first evidence and review. Do not expand into a profiler architecture, a smoke matrix, or canceled dark-region investigation. Choose subsequent optimization only from actual evidence; original dynamic/material/streaming goals remain open.
