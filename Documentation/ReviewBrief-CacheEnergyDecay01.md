# Pro iteration 10: cache-energy-decay-reference-01

## Decision requested

Review the one completed ideal two-node energy/decay reference and decide whether to retain/commit this evidence and proceed to the real scene light-off/change/scheduling chain. No Runtime modification is proposed. Baseline is the Pro9-approved commit `1b8e751`; full original scope remains in OriginalDevelopmentPlan.md. Do not infer whole-scene correctness or add more equivalent function fixtures by default.

## Frozen problem and actual execution

Contract: CacheEnergyDecay01-TestContract.md. Evidence root: LocalComparison/Review/cache-energy-decay-reference-01. The independent reference.json was generated before Unity and frozen at SHA256 49365a7fe6f483bcf86dd044bcbec581a3bb6b35d30598230f1c982ffc3855e6; source manifest and pre-execution analyzer/contract snapshots preserve the boundary. No GPU output was used to choose the answer, 512-round limit or gamma32 scale-dependent rounding bound.

C is indirect incident E/pi, L=rho*(d+C), AO=feedback=1, no emission/environment. rho_A=(.5,.25,.5), rho_B=(.25,.5,.5); d_A=(1,.5,.25), d_B=0. Ideal paired operator C_A=L_B, C_B=L_A. Independent on-state closed form: L_A=(4/7,1/7,1/6), L_B=(1/7,1/14,1/12); cache values are the opposite node's L. Off equilibrium is zero. Finite reference includes the actual declared sample-count/alpha history contract.

One Unity Editor compute batch: PID31664, native exit0 / chunk0ad5e0. Exactly 256-on plus 256-off controlled updates, one actual cosine sample per node per round, two distinct 80-byte cache buffers. Each round waits for two readbacks: actual cache-write and a private 416-byte-per-node observation. Two patches always update; only round256 sends a lighting-only change region. RGB/epoch/generation are never manually cleared at source removal. These are not 512 game frames.

Mechanical extraction executes 18 original functions, including actual CSUpdateCache, ProxyRadiance, HLGICachedSurface, DirectIrradiance, direction sampling and footprint handling. Full original validity/commit, change, lighting policy, emissive and area headers are included. One legal directional light, both normals +Z, actual receiver masks make only A lit. The environment adapters only supply two fixed patch materials and a paired hit for each positive cosine direction. They never supply a computed radiance or cache update. Geometry is intentionally idealized; atlas capture/traversal is not covered. Disabled emitter headers have legal dummy records; shadow strength=0 and zero-length anchor visibility are required to remain uncalled.

## Results

Analysis exit0 / chunke66346; 512 rounds, zero failures. See analysis.json and raw run/observations.bin, run/cache.bin, run/collection.json.

- Initial A cache is exactly measured black with samples=1; B=(0.4999999702,0.1249999925,0.1249999925), samples=1, within predeclared float division/multiply bounds around rho_A*d_A. No receiver albedo or pi duplication.
- All actual old entries equal the previous actual write entries; all private new entries equal the separate cache-write readback. Read/write identities, update mask, tags/generations, source states and sample counts match exactly.
- Actual light injection, endpoint lookup/owner, known confidence, paired outgoing radiance, accumulation, change response and footprint checks pass for every round. One sampled cosine weight can differ from 1 by float division roundoff; gamma4 observation gate and weighted-sum gate were declared before execution within the unchanged gamma32 energy bound (preflight-notes.txt).
- Largest finite-round absolute energy error is 2.69995799606626e-7; maximum error/bound is 0.031249940380803365. On-state finite values satisfy both the per-round reference and the independent steady-state plus finite-iteration bound.
- At first source-off round256, change=(0,1), prepared samples=1, committed samples=2; direct is zero and old partner cache still participates. A may rise slightly for one round through old B, as the Jacobi reference predicts. This is not a failure or a claim of monotonic per-node decay.
- After 256 off rounds, A=(4.6441793e-9,2.3220896e-9,1.3856982e-7), B=(6.5678609e-9,1.6419652e-9,1.3856982e-7). Each is within the precomputed finite residual plus roundoff bound, rather than forced to zero.

Source receipt execution.json confirms all 96 Runtime files, installed helpers, generated source and frozen reference match. Native exit log has no scanner failure signatures or fixture errors. Full Unity.log retains licensing and generic aggregate memory statistics; no whole-process leak claim. One generated actual-entry DXC compile passed with no diagnostics before Unity (compile/report.json). No six-entry full backend matrix was repeated because Runtime is unchanged; no physical DXR claim.

## Review and limits

Astra preflight corrected a harness exception path before execution: pending completions are marked before Dispatch/Request so an exception cannot dispose unproven GPU resources. Astra also checked the weight rounding and coupled accumulation assertion before any GPU output existed. The single run used those frozen helpers; see astra-preflight.txt and preflight-notes.txt. Final astra-result-review.txt reports no blocker, independently checked raw buffer correspondence and hashes, and read-only recomputation at 70-digit precision confirmed all 512 numerical results and the stated bound ratio. No additional GPU run was performed.

This validates the ideal operator's actual update/consumption/mixture/lighting-reactive chain. It does not validate C# runtime light-change detection, budget starvation, real atlas coverage or geometry, whole-image energy, dynamic temporal quality, URP/native composition or physical DXR. The next useful step is one fixed real-scene light-off sequence through UpdateLights -> AddLightChange -> changes -> scheduler -> actual cache/gather, with a bounded observation contract. Source inspection shows directional changes use MarkGlobalLightingChange while point/spot use local bounds; both shader change paths share the existing contract. No such new scene run has occurred in this package.

Player/DXR, GPU p95/p99, peak VRAM and long-run acceptance remain open. The original four goals and ten workstreams are not complete.
