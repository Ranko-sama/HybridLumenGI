# Offline checks

Run from the package root with PowerShell and .NET SDK 8 installed:

```powershell
./Tests/Validate-Offline.ps1 -ReportPath Tests/offline-validation-results.json
./Tests/Verify-OfflineReport.ps1
```

The suite also needs Node.js, Windows SDK DXC, Visual Studio 2022 C++ Build Tools with CMake, and the pinned Unity includes. On the first online run, add `-DownloadIncludes`; later runs reuse those cached includes. The working registry now has 73 stages, including deformation snapshots, paired area-emission sampling, software triangle BVH, hit-material, query-propagation and capture-comparator checks; registration is not a passed run. It preserves command output/exit codes, partial progress and reports in one unique run directory. Missing reports or source changes fail verification. `Verify-OfflineReport.ps1` checks source and artifact evidence before `PackageSource.ps1` creates a candidate. D3D12 WARP and explicit dependency adapters do not certify Unity or physical-GPU execution. Importing the candidate in a friend's Unity project does not require installing these offline development tools first.

**integration-15, 2026-10-27:** the consolidated evidence covers 73 stages, 155 selected DXC entries, 310 source/test hashes and 61 Runtime/Editor C# syntax inputs. The [main report](offline-validation-results.json) SHA256 is `79BD33A51C62777250A3CB975E992AF6BE89B565ADE73D82E681A273B3B40A14`.

This is one complete stage traversal followed by targeted repair, with explicitly retained successful same-source compiler executions. The original failed report, changed sources, actual repair invocations and interrupted duplicate compiler are recorded in `consolidation`; it is not claimed to be a single unchanged-source all-green run. The exact software trace ultimately passed default optimization after about one hour. No `-Od` fallback was enabled.

The late HitMaterials failure was diagnosed with the same DXIL and inputs: its standalone host's 30-second wait expired before WARP completion and could unwind resources still in use. The host now has a bounded 180-second wait and safe failure exit; the existing three-variant stage was formally rerun with unchanged runtime HLSL and oracle. The report verifier accounts for RayTextures' variable metadata/arena prefix, and disclosed repaired invocations retain their actual directories, arguments, timestamps and hashes.

All checks retain explicit CPU/Unity-dependency adapter and WARP limitations. They do not establish Unity API compilation, rasterization, RenderGraph execution, true DXR, rendered GI or physical-GPU performance. Historical validation prose/negative JSONs retain only their original snapshot scope. The source ZIP omits build-machine TEMP artifacts; archive integrity can be checked separately with `VerifySourcePackage.ps1`. Importing the package does not require these offline tools.
Individual checks can also be run:

```powershell
./Tests/Validate-OfflineRunner.ps1
./Tests/Validate-CSharpSyntax.ps1
./Tests/Validate-SdfNumerics.ps1
./Tests/Validate-SdfAtlasAllocator.ps1
./Tests/Validate-SdfAtlasRepresentation.ps1
./Tests/Validate-GlobalSdf.ps1
node Tests/Validate-GlobalSdfBounds.mjs
./Tests/Validate-HardwareBackend.ps1
./Tests/Validate-SceneBvh.ps1
./Tests/Validate-SceneResidency.ps1
./Tests/Validate-CacheScheduler.ps1
./Tests/Validate-GpuBudget.ps1
./Tests/Validate-GpuTiming.ps1
./Tests/Validate-GpuFrameTiming.ps1
./Tests/Validate-NativeTimingBridge.ps1
./Tests/Validate-NativeGpuTiming.ps1
./Tests/Validate-HistoryLifecycle.ps1
./Tests/Validate-MeshSource.ps1
./Tests/Validate-MaterialSource.ps1
./Tests/Validate-ReceiverHistory.ps1
./Tests/Validate-ReceiverIdentityFrame.ps1
./Tests/Validate-ReceiverIdentityPass.ps1
./Tests/Validate-ScreenBudget.ps1
node Tests/Validate-ReceiverIdentity.mjs
./Tests/Validate-ReceiverIdentityShaders.ps1 -ReportPath Tests/receiver-identity-shader-validation-results.json
./Tests/Validate-ReceiverTemporal.ps1 -ReportPath Tests/receiver-temporal-validation-results.json
./Tests/Validate-ProxyUpdates.ps1
./Tests/Validate-Lighting.ps1
node Tests/Validate-DirectLighting.mjs
node Tests/Validate-ReceiverPolicyCapture.mjs
./Tests/Validate-ReceiverPolicyShaders.ps1 -ReportPath Tests/receiver-policy-shader-validation-results.json
node Tests/Validate-SurfaceGeometryNormals.mjs
node Tests/transport-normal-reference.mjs
node Tests/Validate-ScreenGeometryPacking.mjs
node Tests/Validate-ScreenSampling.mjs
node Tests/Validate-SurfaceHitIdentity.mjs
./Tests/Validate-ChangeRegions.ps1
./Tests/Validate-HlodTransactions.ps1
./Tests/Validate-HlodReadback.ps1
./Tests/Validate-ChunkStreaming.ps1
./Tests/Validate-SurfaceCards.ps1
./Tests/Validate-SurfaceCharts.ps1
./Tests/Validate-SurfaceCache.ps1
node Tests/Validate-SurfaceAnchors.mjs
./Tests/Validate-EmissiveResources.ps1
node Tests/Validate-EmissiveProposals.mjs
node Tests/Validate-EmissiveSampling.mjs
./Tests/Validate-SurfaceReadiness.ps1
./Tests/Validate-SurfaceSource.ps1
./Tests/Validate-LitQualification.ps1
./Tests/Validate-NativeDiffuseCapture.ps1
node Tests/native-diffuse-reference.mjs
node Tests/near-far-reference.mjs
node Tests/Validate-GuidedSampling.mjs
node Tests/transport-reference.mjs
node Tests/transport-audit-reference.mjs
./Tests/ValidateShaders.ps1 -DownloadIncludes
```

`Validate-CSharpSyntax.ps1` uses the SDK's Roslyn parser against every C# file in `Runtime` and `Editor`. It checks syntax only: it does not resolve Unity or URP types, validate Render Graph APIs, or compile HLSL.

The history lifecycle harness executes the actual history class and Feature helpers against an independent event-log oracle. Its latest individual run has 17 scenarios / 749,219 assertions, including the actual Execute callback's render/fence failure cleanup. Full-resolution changes invalidate history even when GI dimensions are unchanged; viewport/projection conventions and target identity remain separate checks. Completion still means command recording, not a GPU fence. The Proxy harness's recorded 15 scenarios / 168,139 assertions cover shared Mesh versions, late refresh and notification/policy handling. These individual results must be rebound by the new unified run; they do not prove Unity scheduling or GPU completion.

`Validate-MeshSource.ps1` passes 368,014 assertions in six scenarios against the actual shared-version class. `Validate-MaterialSource.ps1` passes 3,413 assertions in six scenarios against the actual immutable source observer: whole-block per-material MPB priority, exact property/reference/keyword/texture/sampler equality, same-value different-property counterexamples, source-only raster Cull, mutable GPU-texture limits, and frozen identity alpha/Cull/texture/keyword coverage. `Validate-ReceiverHistory.ps1` passes 1,813 assertions in eight scenarios using four actual classes (Registry, ReceiverHistory, HistoryLifecycle and MeshSource) with explicit dependencies substituted, including the material/discovery adapters. It checks source generations, same-frame revalidation, bounded fingerprints, capacity, stale/multicamera receipts and successful completion. The individual LitQualification/Discovery path adds 72 assertions. These are CPU decisions; they do not execute the separate identity raster path or complete Unity discovery/rendering.

The Feature has optional CPU receiver-source preparation and capture-boundary revalidation, with `receiverSourceTracking` defaulting to false. First verified Mesh observations also notify the shared version. Fingerprint budgets count logical bytes rather than CPU time or peak memory; unknown/over-budget sources retain current GI. This option alone adds no pixel identity; the separate default-off receiverObjectHistory option automatically enables source tracking and connects the GPU identity/temporal path described below.

`Validate-ScreenSampling.mjs` adds 1,213,438 CPU numerical/source checks. It covers 30 dimension pairs including 24 non-integer ratios, 188,974 nearest-center and interpolation-footprint cases, 864 projection cases, and five Composite wiring contracts. Integer arithmetic defines the full-resolution depth sample owned by each GI texel; motion starts at that same sample center. History lookup and Composite interpolation use the actual stored centers, including odd dimensions and clamped edges. Independent references reproduce 61,836 old nearest-cell mistakes and four reciprocal-rounding boundary mistakes. The sampling helper itself adds no GPU textures or object identity. Optional object history uses the separate identity path; unknown Ng still retains only the current estimate, and general deformation remains unsupported. Float32 interpolation can retain ULP-scale rounding error even at a mathematical sample center.

The new identity-frame harness executes the actual class with frozen source/value adapters (13 scenarios, 339,710 assertions), including the 80-byte row layout, high key bits, retained holes, per-Renderer groups, positive-similarity transforms and conservative unknown rectangles. The identity-pass harness runs the actual recorder against Unity/RenderGraph/fence recording substitutes (17 scenarios, 439 assertions). ScreenBudget executes the actual pure planner against 11,381 independent plans with 95,207 assertions; identity pressure must fall back to baseline current GI before skipping a camera. These are CPU/recording checks, not Unity API or raster execution.

The identity shader has 12 selected DXC entries, including three DEBUG_DISPLAY fragment variants verified to contain no atomic claim. Its separate CPU numerical/source reference passes 31,861 checks for exact depth/alpha admission, same-owner sticky conflicts, unknown masks and integer sample centers. The new temporal harness compiles the actual ReceiverTemporal HLSL helper and dispatches it on D3D12 WARP: 2,179 cases and 46,841 assertions against an independent double-precision source-geometry oracle. It covers matrix layout, high key bits, primitive/conflict/flags and invalid data; it does not execute full CSTemporalIdentity images, Unity raster or actual RenderGraph barriers. See [StandaloneReceiverTemporal/README.md](StandaloneReceiverTemporal/README.md).

Enabled object history adds 16 bytes per full pixel, 32 bytes per GI pixel and 80 bytes per reserved object row (at least one row). The separate world change-region buffer is 1,088 × 48 bytes. Default-off history requires supported DX12 single-sample/non-XR/full-viewport rendering; current GI survives rejected identity or history. See [GeometryHistoryContracts.md](../Documentation/GeometryHistoryContracts.md) for coverage, lifetime and acceptance limits.

The unchanged `Lighting` stage runs the actual world-light collector against Unity API substitutes (279 checks). It covers all 32 GameObject/rendering-layer bits, separate illumination and native shadow masks, the explicit pipeline light-layer gate, shadow strength, bounded light selection, same-frame property changes and next-rendered-frame membership discovery. Both old and new influence records are retained for invalidation. `Validate-DirectLighting.mjs` adds 6,493 independent mask/energy and source-contract checks: an ineligible nearest surface cannot hide a farther valid shadow caster; disabling rendering layers preserves GameObject culling; zero shadow strength issues no shadow query; nonzero strength scales binary visibility once. This is hard-shadow policy, not a soft-shadow, cookie or complete mixed-lighting implementation.

Receiver capture has a separate R32G32_UInt attachment: GameObject single-layer bit plus the renderer's complete rendering-layer mask, costing 8 bytes per full-resolution pixel. `Validate-ReceiverPolicyCapture.mjs` checks 66,815 numerical/source cases, including bit 31, zero masks, 10,000 random mask pairs and the failure of numeric float32 mask storage. `Validate-ReceiverPolicyShaders.ps1` compiles 22 selected actual shader entries and inspects DXC signatures: 4 vertex position signatures, 18 unsigned two-channel fragment outputs and 10 instanced fragment rendering-layer arrays. Its JSON retains exact compiler arguments, logs, source/include hashes and adapter defines. These checks do not establish Unity's per-renderer builtin values, RendererList ordering, instancing/override keyword selection or actual mixed floating-point/integer MRT writes. DOTS/XR variants are not added to the supported matrix by this test.

The new surface/transport normal references reproduce strong-normal-map material rejection and incorrect shading-normal plane tests. Screen geometry packing exhaustively checks all 2^24 positive integer codes in float32 and tests an independent octahedral normal reference. The source keeps the existing RGBA32F allocation; no interpolated or half-precision loads of these packed values are allowed. See [GeometryHistoryContracts.md](../Documentation/GeometryHistoryContracts.md) for the valid/unknown/invalid contract and SDF asset migration.

`Validate-SdfNumerics.ps1` extracts the current `Bake` method and triangle BVH from `Editor/HybridLumenGIMeshSdfBaker.cs`. It compiles those methods against a small `Vector3`/`Bounds` math adapter and checks 4,096 cube samples against the analytic box SDF, vertex seam welding, cancellation, and unsigned open-mesh output. The adapter is not an alternative runtime implementation.

The C# contract scripts write generated C# and build outputs only to a unique directory under the operating system temporary folder. Test templates use `.cs.txt` so Unity cannot compile them as package scripts.

`Validate-GpuBudget.ps1` compiles the unchanged pure C# quota controller: 13 scenarios and 261,019 assertions, including delayed synthetic feedback, bounds, cooldown, missing samples, reset, camera isolation and exact-source-frame rejection. Synthetic milliseconds are inputs, not GPU measurements. `Validate-GpuTiming.ps1` exercises the actual Recorder coordinator: 15 scenarios and 9,583 assertions, including baseline/identity masks, required counts, zero-duration optional scopes, stale samples and permanent channel rejection after unknown marker-command outcomes. `Validate-GpuFrameTiming.ps1` executes the actual frame coordinator with both provider classes and explicit command adapters: 7 scenarios and 1,048 assertions cover native ABI1 capture spanning identity, Recorder 3/7 local pairing, stale callbacks, source/graph rejection, marker failures and seven diagnostic scopes without aborting rendering. Native retains three intervals; Recorder uses three or seven scopes. Both include identity work when enabled, but CPU preparation, uploads outside them and query resolve remain outside the sum. These adapter tests do not measure Unity or real GPU timing; see [GpuTimingValidationReport.md](GpuTimingValidationReport.md) and [GpuBudget.md](../Documentation/GpuBudget.md).

`Validate-NativeTimingBridge.ps1` checks the actual C# native coordinator with an injected fake C ABI (2,750 assertions); it does not load the DLL. `Validate-NativeGpuTiming.ps1` builds the actual C++ DLL and tests with MSVC, runs the platform-independent query-pool state machine, then loads the DLL into a mock Unity host using real D3D12 WARP commands. WARP unavailability fails the candidate gate. See [NativeGpuTimingValidationReport.md](NativeGpuTimingValidationReport.md) for evidence boundaries and [NativeGpuTiming.md](../Documentation/NativeGpuTiming.md) for integration.

`PackageNativeGpuTiming.ps1 -SourceArchive <verified-source.zip> -Destination <new-native.zip>` creates an optional DLL bundle only when current offline evidence, the exact source archive, and tested DLL hashes agree. It includes source identity, native evidence, installation instructions and third-party notices. It never installs the DLL into Unity. The source archive must already include the license documents. Existing destinations are refused; written archive bytes are reopened and checked.

Surface source-current and ordinary Lit qualification checks use `Invoke-CSharpHarness.ps1` with the installed .NET 8 SDK, not Windows PowerShell 5.1's legacy `Add-Type` compiler. They keep the runtime methods/class unchanged and run against dependency adapters. Both Windows PowerShell and PowerShell 7 retain compile/assertion failures as nonzero exits. The native process-runner regression independently checks successful stderr, nonzero exit codes, a missing executable and continuation with preserved logs.

The scene tests compile the actual runtime BVH, scene-residency and scheduler classes against small Unity/proxy API adapters. BVH validation compares 50,000 deterministic rays against an independent double-precision brute-force bounds query, including boundary/parallel rays, refits, membership changes, empty/single scenes and invalid bounds. Residency's 1,687 checks cover old/new dirty regions, material/topology/manual changes, slot reuse, upload fairness and the separate 16-byte owner lighting-policy snapshot. Policy changes invalidate lighting without asserting that the geometry itself changed. Scheduler checks hard budgets, its oldest-service quota, dynamic fairness, coverage and identity reset. These tests validate CPU algorithms; the adapters do not validate Unity lifecycle events or GPU execution.

`Validate-GuidedSampling.mjs` checks the live HLSL sampler's mixture-PDF/no-resampling contract and runs 4.2 million deterministic samples against analytic and independently integrated reference values. It covers constant radiance, a quadratic anisotropic function, a bright narrow lobe, aligned/tilted/opposite guides and a rotated receiver. Samples below the receiver hemisphere retain zero contribution in the original sample count. The test also demonstrates that conditioning on accepted samples gives a biased answer. This is a numerical CPU reference, not an executed shader test.

The allocator check extracts the current Allocate/Free methods and fuzzes 10,000 operations. The JavaScript file is a transport math reference, not the GPU implementation. Shader validation uses Windows SDK DXC and a fixed official Unity Graphics include revision downloaded to TEMP; the native ray-query adapter is validation-only. Read `ShaderValidationReport.md` for the backend/compiler limitations, including the unsuccessful FXC compatibility attempt.

`Validate-SdfAtlasRepresentation.ps1` compiles the actual atlas class and passes 359 individual contracts, including shared Mesh versions: representation changes, upload readiness independent of scene revision, published/warming filtering, exact identity/revision readiness, and source-current checks for texture, asset, transform, bounds and signed-field changes. The current test also checks pure-pose versus strong-change events and frozen Renderer ownership used by receiver change domains. It distinguishes pure HLOD publication/retirement from concurrent edits and stale receipts. Read-only queries must not consume change events or read/upload voxels. `Validate-ChangeRegions.ps1` checks actual uploaded bounds deduplication, hard-change preservation and conservative overflow through recording adapters. Native engine/GPU dependencies remain substitutes; see `Documentation/SdfAtlasResidency.md`.

`Validate-GlobalSdf.ps1` compiles the actual clipmap scheduler against recording adapters (77 assertions) and compiles its merge, publish and query HLSL entries with native DXC (3/3). It needs Windows SDK DXC; pass `-CompilerPath` if it is installed elsewhere. `Validate-GlobalSdfBounds.mjs` runs an independent CPU reference with 170,002 lower-bound cases, 16,602 affected dirty-domain checks and five validity checks. These cover torus/negative addressing, scrolling, generation rejection, budget progress and conservative empty-space distances. They do not prove GPU execution or performance. See `Documentation/GlobalSdf.md`.

`Validate-HardwareBackend.ps1` compiles the actual hardware-backend class with recording RTAS/mesh/buffer APIs. Its 4,418 checks cover 128-byte instances, 80-byte triangle attributes, 16-byte chart bindings, original submesh material, identity/version changes, retained handles, separate transform/material/binding updates, eligibility, budgets and failure fallback. New CPU candidate oracles cover ShadowCastingMode Off/On/TwoSided/ShadowsOnly, all 32 mask bits, explicit layer enablement and all visit orders of a four-candidate shadow fixture. Lighting-only edits must retain mesh handles and avoid triangle/chart-map uploads or RTAS rebuilds. This includes numerical/source contracts, not GPU candidate execution, driver refits, native alpha traversal or native UV material evaluation. See `HardwareBackendValidationReport.md`.

`Validate-HlodTransactions.ps1` checks the actual scene/BVH/readiness implementation for whole-group publication, retained old visibility while warming, cancellation, capacity blocking, revision receipts and immediate invalidation of stale geometry. `Validate-ChunkStreaming.ps1` checks the actual asynchronous IO policy using controllable fake operations, including budgets, generations, guarded unloads, external ownership and retries. The latter does not run Unity `SceneManager` IO.

`Validate-HlodReadback.ps1` compiles the actual GPU-readback coordination class and manually completes recorded callbacks (126 assertions). It checks Pending deduplication, four-frame throttling, scene/epoch/atlas/card/layout generations, noncontiguous variable card sets, every required chart's coverage, every covered patch's two-sample requirement, live SDF source changes, synchronous/asynchronous failure, invalidation and disposal. Six-view fallback retains its explicit weaker any-covered-page rule. The data and completion events are mocks, not GPU evidence. See `HlodReadbackValidationReport.md`.

`Validate-SurfaceCharts.ps1` compiles the actual runtime chart asset and baker algorithm against Unity dependency adapters (91 fixtures, 3,854 assertions). It covers concave/interior geometry, overlap splitting, UV seams, material boundaries, thin triangles, cancellation, deterministic triangle assignment, capture-mesh indices/vertex streams, malformed serialized inputs and source fingerprints. Unity mesh serialization, AssetDatabase operations and raster coverage require separate engine tests; see `Documentation/SurfaceCharts.md`.

`Validate-SurfaceCache.ps1` compiles the complete SurfaceCache and MaterialSource classes with recording dependencies (19,992 individual assertions across 13 scenarios). In addition to mapping, admission, ordering and triangle-binding checks, it forces identical Material CRC values while changing source properties/samplers, verifies exact-source rejection and recapture, distinguishes same-value MPB properties, and ensures MPB `_Cull` cannot override original raster state. RenderTexture materials still capture currently but cannot prove stable old publication contents. `Validate-SurfaceSource.ps1` passes 6,027 actual-method/adapter assertions, including failure of exact validation despite an unchanged compact hash. These records do not prove native command execution, Unity property encoding or shader color upload; detailed source-observation limits are in [StandaloneMaterialSource/README.md](StandaloneMaterialSource/README.md).

`Validate-SurfaceHitIdentity.mjs` checks explicit chart identity against thin-layer counterexamples, stale bindings and unknown SDF identities; its capture math covers reversed vertex Ns, Cull modes, mirrored/UV-flipped projections and scale-independent geometric derivatives. The transport-normal reference also reproduces backside self intersection when a camera-facing history normal chooses the sampling-origin side. These are numerical/source contracts, not executed raster or ray-query tests.

`Validate-SurfaceAnchors.mjs` checks 5,096 partition/nearest-covered-texel cases over 5,437,178 texels, 58 invalid-data cases and 305 emissive-reduction cases. It compares the shader contract with independent CPU references for half-open patch cells, sparse coverage, deterministic ties and owner/layout rejection. Native DXC also compiles the actual anchor kernel as part of the core shader matrix; neither check executes it on a GPU.

`Validate-EmissiveResources.ps1` compiles the actual per-camera proposal coordinator with recording dependencies. It checks allocation, queue-recorded clearing, missing builders and recording failures, budget clamping, shared snapshot bindings, camera isolation and disposal. `Validate-EmissiveProposals.mjs` compares bounded selection against an independent full-sort oracle, exercises float32 HDR CDF normalization/compaction and checks categorical selection frequencies, empty tables and HLOD publication changes. `Validate-EmissiveSampling.mjs` checks the complete three-way PDF against analytic/numerical integrals and compares estimators using fixed synthetic incident-light functions; it also includes float32 precision regressions. None of these scripts measures GPU rendering quality or timing. See `Documentation/EmissiveSampling.md` and the current unified report for the precise scope and results.

`Validate-SurfaceCards.ps1` and `Validate-NativeDiffuseCapture.ps1` provide separate shader/source checks for their modules; their reports must be read with the same native-DXC-versus-Unity distinction. The color-probe shader can be compiled alone with `./Tests/ValidateShaders.ps1 -OnlyColorProbe` after includes are present. Actual CPU-versus-shader color conversion remains a Unity test: select **Tools > Hybrid Lumen GI > Validation > Probe CPU and GPU Color Contract** and retain the generated `Logs/HybridLumenGI-color-contract.json`. The local offline probe compilation does not establish the engine's color-storage convention.

On a machine with Unity, also run **Tools > Hybrid Lumen GI > Validate Mesh SDF Numerics**, or invoke `HybridLumenGIMeshSdfValidation.Run` with Unity's `-executeMethod`. That check uses Unity's own math types and meshes. Import, shader compilation, rendered-image correctness, graphics API compatibility, GPU timing, and memory profiling remain separate required checks.
