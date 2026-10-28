# GPT-6 Pro iteration 8 — actual gather/cache visibility

Task `c2c_a702`; previous review iteration 7 approved local commits. Resource fix is `3c12a87`; thin-wall evidence is `1647a88`. This package freezes the latter. No workspace Runtime algorithm changes. Request: review bounded evidence, local commit decision and the next concrete package under the complete original plan.

## Result and provenance

One A run only: PID 1356, native DX12 / Unity 6000.0.85f1 / RTX 2080 Ti, 120 logical frames, exit 0, final exec chunk `061f9d`. First frame took 214.9 seconds including compilation/startup; no performance inference. All 36 observer files were collected with zero errors, pending requests, missing records or overflow. Maximum stream occupancy was 111 of 256 records. All 120 frame diagnostics report exact software; the observer's all-frame target guard stops fallback. Actual `CSTrace` stream stamps prove the selected dispatches, independently of diagnostics.

Same A settings, camera, all lights and scene object metadata match the prior A exactly. Frozen actual mesh snapshot contains 240 triangles, all supported opaque URP Lit/Cull configurations; no bounding-box substitution. Sources and four test assets were restored, 106 checks pass. Executed shader/C# bytes and hashes are archived. Original asset bytes and effective runtime settings/geometry are retained; the mutated serialized test assets were restored before separately archiving their post-run bytes, so no post-run serialized-asset hash is claimed.

Evidence root: `LocalComparison/Review/gather-cache-visibility-01/`. Start with `execution-receipt.json`, `source-restored.json`, `analysis.json`, `coverage-details.json`, `astra-preflight.txt`, and `A/20261028-003039-1dfa0103552e4566b52f2c733517f692/gather-summary.json`. `decoded/` contains readable, typed original event payloads for every selected pixel/frame; raw binary streams remain in A. Header and discrete identity fields retain uint types.

The complete `Unity-A.log` has no matched product Persistent allocation leak, unresolved retirement, shader/readback/backend or shutdown-error signature. Generic Unity aggregate MemoryLeaks statistics and licensing/info-queue startup warnings remain preserved. This is one log-level direct Editor exit check, not a new per-ticket proof or whole-process leak claim.

## What was actually checked

| Observation | Result |
| --- | --- |
| Fixed receiver samples | 36: 22 valid nonblack, 14 measured black; zero unknown/no-receiver |
| Direction winners | 27 world, 1 screen, 42 environment, 2 zero-weight |
| Cache calls | 64: 36 receiver guide, 25 world endpoint, 3 screen calculations |
| Final cache consumption | 26: 25 world + 1 screen; valid terminal, positive direction weight and nonzero cache coefficient |
| Four-tap decisions | 194 accepted; 31 tag/measurement rejected; 31 visibility blocked |
| Ordinary visibility queries | 225/225 match independent double triangle reference, including hit owner/distance; no actual-segment boundary ambiguity |
| Independent raw reconstruction | Maximum absolute error 5.068523e-8; texture also within predeclared binary16 quantization bound |
| Cache normalization | Maximum absolute irradiance error 1.907349e-6, within declared arithmetic tolerance |

Two screen/cache evaluations (frame 3/lane 0 and frame 95/lane 2) occurred for zero-weight samples. They are preserved and explicitly excluded from final consumption. The observer adds no Random, trace or cache call sites and retains original product branch expressions and accumulation order; shader optimization/driver cost under instrumentation is not assumed identical to the uninstrumented build.

Reference checks use exact ID/tag/generation/address comparisons, independently recomputed projection, tap cells/weights, orientation and plane decisions, ordinary visibility and normalization, endpoint material/direct/emission/cache equations and both-ray accumulation. The observer preserves partial result structures on false cache returns; no such tiny-weight partial-return branch was observed.

## Physical endpoint comparison and remaining coverage

There are 17 Boolean differences between exact recorded unshifted segments and actual biased/shortened segments. Thirteen unshifted floor segments pass within float error of the thin wall's bottom edge (receiver y approximately -7.26e-8); four unshifted hits lie at other segment/triangle boundaries. **All 17 unshifted cases are numerically ambiguous under the predeclared 2e-5 boundary tolerance.** They are neither a demonstrated light leak nor demonstrated physical improvement. The actual product segments remain unambiguous and match their reference.

Astra caught that analyzer v1 marked ambiguity only on accepted hits. The offline oracle now also marks rejected near-edge/near-end intersections. `analysis-v1.json`, `analysis-v1.log`, and `instrumentation/analyzer-v1.executed.py.txt` preserve the earlier result. Reanalysis of the same saved GPU data passes with unchanged actual-query and arithmetic conclusions; no tolerance increase and no GPU rerun.

Area emitter count was zero at all 36 selected pixels, and all 72 area statuses were NONE. Area NEE/screen suppression was instrumented but is uncovered, not validated. Other missing branches include generation-only rejection, normal/plane rejection, short/no-query connections, unknown estimates, tiny-weight partial return and unsupported/alpha materials. No pixel/ray/configuration changes were made to seek those branches.

This package closes only the observed actual-gather/cache arithmetic, identity and ordinary-visibility gap. It does not establish whole-image physical energy correctness, multi-bounce convergence, dynamic stability, current Player/DXR consistency, GPU p95/p99, peak VRAM or long-duration resource acceptance. Original four goals and ten workstreams remain open where evidence is absent; no friend delivery or remote push.
