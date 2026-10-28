# GPT-6 Pro iteration 9 — failed cache result contract

Task `c2c_a702`, frozen baseline `507e52d` (approved actual gather/cache diagnostic package). Request candidate review, local commit decision and next package under the complete original plan. The candidate is not committed.

## Concrete defect and minimal change

With one accepted tap of weight 2^-18 and RGB irradiance (1024,512,256), the actual baseline HLGICachedSurface reaches its totalWeight<=1e-5 branch and returns false while retaining partial RGB (1/256,1/512,1/1024). The actual CachedIrradiance wrapper returns zero, but actual ProxyRadiance consumes the partial cache and adds an extra world radiance term. This is a reproduced function contract inconsistency, not a demonstrated visible light leak.

The sole Runtime change at HybridLumenGITransport.hlsl:295 clears the entire result before that false return. Threshold, visibility, bias, interpolation, successful normalization, confidence, PDF and feedback code are unchanged. The fixed world endpoint retains direct light, emission and confidence 1; only its failed cache increment disappears.

## Actual-source baseline and same-input replay

`LocalComparison/Review/cache-failed-result-01/` contains both runs, complete native logs, source/hash manifests, generated original and observed function bodies, raw 224-byte outputs, input JSON and independent assertions.

- Baseline Unity PID32056, native exit0, exec chunk a0915d. Six outputs collected; assertions exit1 (b3101e) because the intended contract counterexample is present. `baseline-analysis.json`: fixtureValid, controlsPassed, nativeExitPassed and counterexampleConfirmed are true; the only three failed assertions concern tiny-case false-result residue, world cache increment and receiver residue.
- Fixed Unity PID23252, native exit0, exec chunk549736. Same six input records and helper bytes; assertions exit0 (f8753e). All failed lookup bytes are zero. Other five complete output records are byte-identical to baseline.
- Source/provenance checks cover 96 product files plus two helpers and two generated includes for each run. Raw per-case write stamps, finite outputs, branch reason, accepted count, base/fraction, actual weight/total and readback completion are checked. No fixture retry or A/B/C scene rerun occurred.

| Tiny-support observation | Baseline | Fixed |
| --- | --- | --- |
| Actual accepted weight / total | 2^-18 / 2^-18 | Identical |
| Lookup return / branch | false / low-total | Identical |
| Whole 80-byte failed structure | Nonzero partial irradiance and guide | Zero |
| Screen cache wrapper | (0,0,0) | Identical |
| World cache increment | (2^-10,2^-12,3×2^-13) | (0,0,0) |
| World direct+emission, confidence | Preserved, confidence1 | Preserved, confidence1 |
| Receiver guide PDF / zero-guide PDF | Both 0.3183098733 | Identical |

The unit guide's tiny residue does not pass the original length eligibility test. We do not claim that the baseline residue changed sampling. The fixture passes the actual out guide directly to the actual PDF and reads the real bound zero-count emissive proposal header.

Controls are above-threshold support2^-16, no measured tap, stale entry identity, stale entry generation and valid measured-black cache. Above-threshold and black queries stay true with valid confidence; missing/stale queries stay false/zero. The black-cache case is a cache validity test, distinct from the preceding package's black pixel outputs.

## Execution and coverage boundaries

The Unity compute fixture mechanically extracts 11 original function bodies (plus actual production structs/headers), preserving original algorithm statements. Read-only observations in the extracted cache function expose its internal support and return reason. It executes actual card/owner/UV validity, cache lookup, cache wrapper, world endpoint and receiver PDF. Explicit adapters supply known material resolution, clear ordinary visibility and known direct irradiance; an inactive emissive branch spy must not run. Those adapters are not atlas capture, triangle traversal or independent illumination references. “Screen” here means the actual CachedIrradiance wrapper, not execution of full TraceScreen.

Both complete native logs pass the shared product allocation, D3D unreleased-resource, unresolved-owner, shader, reference, readback and device signatures. The general Unity MemoryLeaks aggregate remains preserved and is not attributed to this product. This is the small fixture's readback/disposal/Editor exit evidence, not a new renderer retirement matrix or long-duration acceptance.

The shared scanner restores omitted legacy signatures including Unreleased non-evictable, separate owners remain and DXGI_ERROR_DEVICE_*. Offline checks pass five saved known good/bad logs plus critical spelling guards; no Unity execution was added for scanner maintenance. The prior executed scanner and evidence remain untouched in the previous commit.

All six affected complete shader entries (CSUpdateCache/CSTrace across software, exact software and hardware) compiled successfully, each compiler exit0; completed exec session16456 / final chunk1c954d. `shader-compile/report.json` and `completion-proof.json` retain arguments, diagnostics, source/include hashes and six nonempty DXIL hashes matching current source. These use installed DXC and existing pinned Unity includes/native RayQuery compile adapter, and do not prove physical DXR execution or Unity variant import.

Next full-plan priority remains independent multi-bounce energy and lights-off decay reference after this small contract fix. Actual dynamics, current Player/DXR, GPU p95/p99, peak VRAM and long-duration resource acceptance remain open. No friend delivery or remote push.
