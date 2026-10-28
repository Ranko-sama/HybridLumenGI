# Astra independent locator and candidate-gate review

Reviewed 2026-10-28. This review inspected existing files and raw records only; it did not run Unity, a compiler, WARP, or a test suite. Only this review document was written. The candidate's eventual performance and equivalence results are not approved by this checkpoint.

The locator evidence supports the finite attribution result. The selected 64 source frames are 145–208, within the single 240-frame run (144 warmup, 64 selected, 32 drain). Parent and diagnostic owners are distinct. Raw spot checks at sources 145, 177 and 208 match the recorded parent association, generation and frequency, and place all three child intervals inside formal Transport. The analyzer requires complete unique source sets and uses integer tick differences before conversion. The original 110 product sources were restored after the 111-source instrumented build; the necessary build also verified the corrected Windows-only plugin importer.

Gather is consistently the dominant measured part. Its four consecutive 16-source block medians are 17.104896, 16.994464, 16.835840 and 16.841200 ms, compared with WorldCache block medians around 2.31–2.35 ms. Whole-window Gather is 16.907376 ms and formal Transport is 19.626784 ms. Reconstruction is small; the remainder remains other commands, gaps and instrumentation, not an identified kernel. These measurements do not establish whole-application GPU cost or production tail latency.

The optimized compiler gate is also supported, within its stated scope. `compiler/baseline/compile.json` records successful DXC `cs_6_5 / CSTrace / -O3` compilation using the pinned RayQuery adapter. The assembly SHA256 is `9b4a30ae8d8d97c697dfe9ad8858355d398e836d66631c22afd55cd8fe7f2d6c`; DXIL SHA256 is `6172fe4b206476a66b38fc66f6ec3f6f6a8c2607bba5b26efa7b329e924a365e`.

Independent bounded inspection of that assembly found:

- The ray loop has header `.lr.ph89430` at assembly line 87474 and a backedge to it at line 492550; the loop condition/increment maps to baseline `CSTrace` source line 275.
- Sixteen `_HLGI_Depth_texture_2d` `textureLoad` instruction sites have the debug-location chain `HLGIScreenDepthDelta:73 → HLGITryScreenRayFootprint:104/105 → CSTrace:287/315` and remain inside that loop region. Their assembly lines are 89378, 89382, 89460, 89464, 89743, 89747, 89825, 89829, 326723, 326727, 326805, 326809, 327088, 327092, 327170 and 327174.
- Example metadata chains are `!36157 → !36138 → !36101` and `!123365 → !123342 → !1938`. These identify the original receiver calls rather than the changing TraceScreen endpoint.

This proves retained repetition in the inspected optimized DXC representation. It is not extracted Unity driver machine code, a physical register count, or a count of unconditional runtime memory transactions. Shader branches and sample eligibility still determine which sites execute. It is sufficient to permit the one planned candidate, not to predict its speedup.

The current candidate diff is appropriately restricted: prepare receiver `dx/dy/valid` once before the ray loop, replace only the direction and area receiver-footprint calls, and retain the original direction projection expression `position, position+dx, position+dy`. The original helper, geometric-normal path, receiver world-match call, TraceScreen endpoint computation, RNG calls, queries and accumulation remain unchanged. Invalid preparation still returns a zeroed footprint while the caller continues querying; it must not become an early ray exit or use `hasGeometry` as footprint validity.

Remaining gates for this single candidate:

- Reuse the existing finite actual-HLSL comparison with identical inputs and compiler conditions, including boundary/discontinuous/invalid depth, degenerate direction and recorded receiver inputs. Compare validity and all footprint fields, preserving the addition/subtraction structure. Such a comparison establishes the tested helper contract; it must not be described as whole-scene Unity pixel identity.
- Inspect candidate optimized output for the intended hoist and code/lifetime changes. Holding six floats and a validity flag across a large ray loop may increase live-value pressure; source simplification alone is not a performance result, and DXIL inspection does not supply physical GPU register occupancy.
- Use the same diagnostic wiring and fixed-window rules for the one allowed candidate Player. Compare Gather together with formal Transport and the formal per-source sum. The locator's Gather block-median range is 0.269056 ms; report candidate block variation as well, without treating a small whole-window median reduction as established benefit.
- No clear benefit, a computation-contract regression, or a new runtime failure means restore the candidate product diff and retain this locator evidence. Do not add samples, a second candidate, further timing scopes, or unrelated runtime matrices.

Conclusion: both conditional entry gates are satisfied for the planned receiver-depth reuse candidate. No additional locator run or profiling framework is needed. Candidate retention remains conditional on its bounded equivalence and actual performance results.
