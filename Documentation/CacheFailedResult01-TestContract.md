# cache-failed-result-01

Frozen baseline: `507e52d`. GPT-6 Pro iteration 8 approved the previous diagnostic commit and authorizes this bounded actual-source reproduction, then a minimal fix only if reproduced. Full original plan remains open.

Use the existing local Unity compute/AsyncGPUReadback execution pattern (no A/B/C scene rerun). A small fixture includes unmodified production helper headers and function bodies extracted mechanically from the frozen source, as the existing actual-source radiance validation does. Actual functions to execute include surface owner/card/UV validity, HLGICachedSurface, HLGICachedSample, CachedIrradiance, HLGIHitOwnerCurrent, ProxyRadiance, and HLGITransportDirectionPdf. Do not write a second implementation of cache selection/normalization or consumer equations.

Explicit dependency adapters supply a fixed valid surface material, a clear visibility segment and known direct irradiance; these do not claim atlas capture, geometry traversal or lighting reference coverage. Record query count, actual accepted tap weight/total and actual returned structures with read-only instrumentation in the extracted cache function. Preserve its original branch and arithmetic order. Archive original extraction, instrumented extraction, source hashes, inputs and bytes for each execution.

One fixed six-case input set, replayed unchanged before/after:

1. One accepted tap with total weight 2^-18, irradiance RGB (1024,512,256), positive confidence; other three reject by tag. Baseline must reach the low-total failure branch with nonzero partial irradiance/guide. Record low-level bool/full cache structure, actual screen wrapper, world endpoint, receiver-cache result and actual guide PDF. Do not infer guide effect from nonzero partial guide alone.
2. Same support at weight 2^-16: true result, correct normalization and unchanged successful behavior.
3. No measured tap (zero confidence): false/zero.
4. Stale entry identity: false/zero.
5. Stale entry generation: false/zero.
6. Sufficient-support measured black: true with positive confidence, RGB zero.

Use binary-exact UVs for grid 2: x=(0.5+weight)/2, y=0.25, with only cell (1,0) accepted. Card transform identity and z=0.5; correctly placed cell anchors, +Z geometric/shading normals and legal current owner/card/epoch/generation. Use actual card/UV validity, ordinary visibility dependency explicitly clear, and unchanged 1e-5 threshold. Keep nonzero known direct and emission values in the endpoint so a missing cache cannot be mistaken for a missing whole radiance measurement.

Fixture parameters are frozen identically across baseline/fix: bias 1/16, feedback 1, guide fraction 1/2; direct (1/4,1/2,3/4), emission (1/8,1/4,1/2), diffuse (1/2,1/4,3/4), AO 1/2. The actual proposal-count function reads a bound legal zero-count header. Unit +X guide with power 2 remains below the original guide-length eligibility threshold in the tiny partial result, so unchanged PDF is expected there. The screen test is the actual cache wrapper, not the full TraceScreen endpoint. Stamp each 224-byte output with case index and fixed write marker. Check all 80 bytes of a failed cache result for zero, not only RGB. Finite arithmetic comparisons use absolute 2e-7 plus relative 1e-6 only for the PDF; binary-exact cache/material/control quantities and unchanged control output bytes are exact.

Only after baseline reproduction: clear the entire result in the totalWeight<=1e-5 false-return branch in HybridLumenGITransport.hlsl. No other transport parameter, query, PDF, confidence or valid-black change. Re-extract from candidate source and replay exactly the same fixture input/helper bytes. Require failed output zero, preserved direct/emission/knownness, true-normalized and valid-black controls unchanged, and affected full shader entries compile. Record baseline assertion failure separately from fixture/compile/readback failure.

Before reusing native log checking, unify historical Persistent/D3D/unresolved-owner/device/shader/readback signatures and verify against saved known success/failure logs offline. No new Unity run for that maintenance task.

Stop and return to Pro on fixture not reaching the target, unproven actual consumer, unknown/nonfinite output, compile/readback/exit failure, or need to alter sampling/visibility/threshold to pass. Preserve all failures; no ad hoc retries or wider matrix. Candidate is not pre-approved for commit.
