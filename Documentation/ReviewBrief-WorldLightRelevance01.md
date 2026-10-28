# Review: world-light-relevance-01

Task c2c_a702, iteration30; baseline4370663. The original four goals and ten streams remain active. This package implements the capability selected by actual Pro29. It does not reopen darkness, Monte Carlo, exposure, reference or timing investigations, or stable-topology deformation history.

## Behavior and scope

Default-off `spatialLightSelection` uses conservative exclusion only after valid candidates exceed the existing capacity. It preserves original discovery order, duplicates, packing/intensity, 80-byte ABI and32-light limit. Under-capacity, disabled and unknown-domain cases retain the original prefix. Disabled mode retains the early pack/exit behavior and reports total candidate/omitted counts as-1 (not measured). Relevant overflow remains a known limitation.

Feature constructs a per-camera finite domain using the exact float inverse GPU view-projection later uploaded to transport. A fixed homogeneous interval covers DX12 XY[-1,1]/Z[0,1], including jitter; standard finite centered nonphysical non-XR full-viewport perspective/orthographic gates reject unsupported configurations. The domain unions all prepared published/warming traversal bounds and prepared surface capture bounds. Any required unknown extent falls back to legacy admission. No visibility-only light list, new world scan, geometry fingerprint or GPU depth query is added.

Astra identified that disabled/hidden warming DrawMesh capture bounds may exceed stale Renderer.bounds. The narrow extra SurfaceCache getter reads frozen owner.bounds; it is necessary for domain closure and does not alter capture, residency or scheduling. Scene likewise exposes existing frozen traversal bounds. Actual finite-range attenuation, including the float squared range floor, defines exclusion. Boundary, unknown and overflow arithmetic cases remain candidates. The margin uses binary32 unit roundoff2^-24, not Single.Epsilon.

## Evidence

All artifacts are under `LocalComparison/Review/world-light-relevance-01/`.

- `baseline-command.log`: actual old collector selects the first two remote lights and omits the third with capacity2. This is a declared capability gap, not an established image defect; successful baseline exit is intentional.
- `source-tests-command.log` and `source-test-first/`: retained initial fixture failure. The X[98,102] intended box was incorrectly put at98..102 on Y/Z too. Only fixture bounds were corrected, plus an independent expected-light containment assertion. No product/tolerance adjustment.
- `source-tests-candidate.log`:691 actual collector/helper checks pass, including the existing301 guards. Covers independent double distance, float reconstruction samples, conservative boundaries, full record compatibility, residual overflow, duplicate contributions and interleaved camera changes. Adapter hashes are not native Unity Vector4 hash evidence.
- `capture-bounds-tests.log`: actual SurfaceCache19995 assertions/13 scenarios pass. Added checks establish frozen hidden DrawMesh bounds and unknown slots; these do not prove native warming routing or raster quality.
- `astra-implementation-review.md`: no remaining implementation blocker, explicitly distinguishes source contracts from native Feature integration.

## Finite native gate

One build and one visible DXR64-frame run of existing Functional scene are now complete. Input consists of three ordinary points assigned after actual InstanceID discovery, two far outside and the third covering the existing Green wall local X-minus face. Fixed color camera, maxLights2 and modeon; original mixed events disabled, initial unchanged deformation snapshot retained. No image/timing capture, native old-mode comparison, extra shaders, history or resource-retirement experiment.

Logical63 records the actual `_HLGI_LightCount` C# binding argument and the actual light buffer bound to both transport kernels, then requests its completed GPU bytes. Count evidence is a binding receipt, not GPU constant readback; only the active buffer prefix is valid. The independent analyzer checks range/domain provenance, fixed input, complete packed record identity, exact active GPU prefix and standard exit/source restoration. Source hashes and temporary observer hooks are frozen separately. No second build/run or longer warmup follows an uncovered result.

**The native capability check failed.** Build succeeded with111 source identities/five staged files verified and original candidate restored. The Player completed64 consecutive frames, actual hardware backend, zero capture errors/images, exit0 without watchdog/native resource errors and final accounting zero. But actual domainValid=false and reason `Prepared world traversal bounds are unknown`, count2 and completed GPU prefix equal the two remote lights. `native-window/analysis.json` and `native-analysis-command.log` preserve the original failure. `native-window/fallback-evidence.json` separately identifies the observed fallback; it does not change that failed result.

## Discovered alias defect and source repair

Feature deliberately calls `combined.TryInclude(...,out combined)` for each required extent. The readonly struct method's early `result=default` cleared this aliased receiver before its `IsValid` read, so the first union failed even with valid geometry. All22 native extents are finite and ordered. This is a candidate product bug, not a margin/scene/brightness problem. The source fixture had used distinct output variables, and the earlier independent gates missed this call-shape semantic.

`domain-alias-baseline.log` reproduces the actual helper failure with the Feature call shape. `domain-alias-repro/` freezes its helper and the new Program. The minimum repair moves default assignment into the invalid-input branch; success evaluates the old/new vector bounds before calling static TryCreate with out. The identical Program then passes693 checks (`domain-alias-candidate.log`). Existing numerical margins, geometry, shader, native fixture and its acceptance requirements are unchanged.

Native helper SHA256 was `a632ace4e095faf069a9aa16304cd4b772fa3a78182adc09eb07d820f9a8349e`; corrected helper is `2b91f9485cf6b08006add5471946d6396a8f08e3a4128274164b7c10339a9cbe`. `domain-alias-repro/corrected-deployment.json` records that distinction and the updated local Unity source. Original native build/restoration verification describes the pre-correction candidate at its execution time. It is not current-source native success after this repair. **No second build/run has been attempted; native admission/upload success for corrected source remains unverified.**

## Review boundary

This package cannot establish whole-image energy, material consistency, performance, full importance sampling, Release or long-term production acceptance. All prior unrelated evidence keeps its original source identity. Pro30 should independently assess the correction and choose the bounded next step given the explicitly exhausted native attempt. Do not approve the original capability acceptance or relabel a second attempt as an automatic extension.
