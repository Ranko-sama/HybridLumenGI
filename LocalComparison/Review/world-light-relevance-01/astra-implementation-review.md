# Astra implementation review — world-light-relevance-01

Reviewed on 2026-10-28, before this package's native build/run. This review read current product changes and saved source-test evidence; it did not execute tests, Unity, a compiler, or an analyzer. Product baseline: `4370663`.

**Decision: no remaining implementation blocker in the reviewed candidate, after the prepared surface-capture bounds addition described below.** This is an implementation review, not the later native harness/build gate or an upload/visual acceptance result. The parent is adding a small assertion set to the existing SurfaceCache fixture for that addition; no result for that assertion set was available at this review point.

The first draft had one concrete coverage gap. `HybridLumenGIProxy.GetWorldBounds()` reads ordinary `MeshRenderer.bounds`, whereas `HybridLumenGISurfaceCache.CanCaptureRegisteredRenderer`/`CaptureBounds` explicitly support disabled or hidden MeshRenderer sources and calculate the explicit DrawMesh extent from mesh bounds and localToWorld; the existing source comment notes that renderer bounds can be stale. Scene traversal bounds alone therefore did not establish the claimed complete cache/warming domain. Relevant source locations are Proxy:267–274 and SurfaceCache's CaptureBounds implementation (formerly 747–760).

The reviewed correction adds only a read-only `SurfaceCache.TryGetPreparedCaptureBounds` accessor for existing `owner.bounds`. After the existing Scene.Prepare and SurfaceCache.Prepare, `RendererFeature.TryLightDomain` includes both each published/warming slot's frozen traversal bounds and its prepared capture bounds when it has resident cards. Missing/invalid required bounds make the entire domain unknown. The correction does not recalculate residency, change the BVH, capture another surface, or discover new objects. Adding `HybridLumenGISurfaceCache.cs` and the directly affected existing fixture is a necessary, narrow addition to the original file list. Do not simplify the domain back to renderer bounds, active traversal slots only, selected patches only, or current screen visibility.

The collector behavior is appropriately bounded:

- The old overload selects disabled mode. The disabled path retains the original TryPack-before-cap-break order and does not enumerate the entire valid table; candidate/omitted counts are explicitly `-1` rather than invented totals.
- Enabled mode counts all valid records, preserves the first original prefix, and keeps at most the current capacity's worth of nonexcluded records in scratch. It replaces the prefix only when a valid domain exists and valid candidates exceed the capacity. Feature continues to clamp capacity to 32.
- Surviving records retain discovery order, full Data values, and duplicate multiplicity. Directional records are not distance rejected. Unknown domains and no-overflow inputs retain original selection. The reset of `outside` to zero in those paths means this diagnostic counts actual spatial exclusions, not every geometrically outside record that could have been excluded.
- Scratch is overwritten per call and is not camera history. The old effective prefix remains supplied by each CameraState; exact multiset changes still report real old/new admission transitions. Removed temporary legacy-prefix entries are cleared before upload/hash use.

The screen-domain implementation uses the same frozen float `invVP` later uploaded to transport. The current support gate is narrower than generic non-XR: Direct3D12, full viewport, finite ordinary nonphysical centered perspective/orthographic configuration and matching ordinary view. Unsupported configurations retain legacy admission. Matrix equivalence is the gate; the code does not claim to detect whether an equivalent matrix was manually assigned.

The fixed four-row homogeneous interval construction is conservative rather than tight. It covers the complete DX12 clip box, expands XY and multiply/add ranges, requires a positive denominator interval, then expands the quotient and float endpoint conversion. Nonfinite or unbounded cases return unknown. Using actual inverse coefficients avoids replacing the shader's float inverse with an analytically different inverse. Very loose bounds or rejection at extreme far/near ratios are acceptable limitations; no tighter frustum scheme is needed for this package.

The sphere exclusion follows the actual local-light attenuation denominator: the squared float range and its `0.0001f` floor. It preserves equality and a coordinate/radius-scaled roundoff band, and retains candidates for range-square or possible offset/dot overflow. UnitRoundoff is explicitly binary32 `2^-24`, not `Single.Epsilon`. The reviewed code does not alter shader attenuation, spotlight cones, light strength, rendering-layer rules or the 80-byte ABI. This is not an importance ranking and does not close residual relevant-light overflow.

Evidence boundaries:

- `baseline-command.log` records the existing capacity-2 behavior for three declared candidates: the two remote records occupy the table and the relevant third record is omitted. It correctly labels this an existing capacity policy/capability gap, not an established image defect.
- `source-tests-command.log` preserves the first fixture failure. The saved first Program used `[98,102]` in all three axes while the intended light was at `(100,0,0)`. The reviewed change uses X `[98,102]`, Y/Z `[-2,2]`, and asserts that the intended light lies inside. The saved first collector/helper bytes equal the passing collector/helper bytes; no product or numerical tolerance was adjusted to fit that failure.
- `source-tests-candidate.log` reports 691 checks, including the existing compaction guards, finite collector contracts and direct float reconstruction samples. `Validate-Lighting.ps1` compiles actual Lights and LightRelevance with adapters. It does not compile or execute actual RendererFeature/Scene/SurfaceCache camera integration. The offscreen/warming collector cases supply explicit union bounds; they do not by themselves prove native warming integration.
- No new Unity discovery, GPU light-buffer upload, whole-image lighting, performance or platform result is established here. The authorized single build / visible DXR run remains the next finite integration gate. No extra matrix is requested.

Read source SHA256 values:

| Source | SHA256 |
|---|---|
| Runtime/HybridLumenGILights.cs | DED208F3D99AFAB990A249CC0A0ABC94AB36952BA022B1FF1FF7017B75971CFF |
| Runtime/HybridLumenGILightRelevance.cs | A632ACE4E095FAF069A9AA16304CD4B772FA3A78182ADC09EB07D820F9A8349E |
| Runtime/HybridLumenGIScene.cs | D770CB41BA1FBC592B6BD50EC1F741AEFBECF4D530F8015066731572CA1A5376 |
| Runtime/HybridLumenGISurfaceCache.cs | 3EBC2B40B59D333516630710D915E804B3DFC4BE09685E9773F016382AC94584 |
| Runtime/HybridLumenGIRendererFeature.cs | 1BF49DCBD55EFF1C1198DE96E7103B9351EDF30174C680FC4A60B059FFF0DD8F |
| Tests/StandaloneLighting/Program.cs.txt | FB129EA426B95CF3EAEACD4F51F6E3E286D529053905531774BA8839B715E0FC |
| source-tests-candidate.log | AC385D437A10D0CE5373E7420E5D11EFB12E8719E3B7E65C95F3FC4F523ABE13 |
| source-tests-command.log | 87A3712DCF925A1C5303179835DBCD2CA11B91639A54C601DA30AA453FFF8618 |

The source hashes identify this read snapshot; later harness wiring or a changed candidate requires its own provenance, not a retroactive claim that these checks covered those bytes.
