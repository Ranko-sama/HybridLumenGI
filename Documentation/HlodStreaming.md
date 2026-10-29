# HLOD publication and additive scene IO

These modules separate scene loading, GPU preparation and publication. A completed `LoadSceneAsync` operation means Unity has activated a scene. It does not mean that its SDF, material cards or lighting cache are ready.

## Atomic HLOD transactions

The scene table uses three states in `ProxyGpuData.identity.w`:

| Value | State | World visibility |
| --- | --- | --- |
| 0 | Absent or waiting for geometry upload | Not traced |
| 1 | Published | Included in the scene BVH and live backends |
| 2 | Warming | Available to SDF/material/cache preparation; excluded from live world tracing |

The topmost authored HLOD parent represents the far state. Descendant leaf proxies form the near state; intermediate aggregates are not simultaneously published. The complete old published set is retained while slots are reserved and the target set uploads under the existing geometry budget. The target's entire staging set must fit alongside the old representation. If it does not, `PendingCapacity` reports blocked groups and the old representation stays active. Increasing the capacity causes resource reallocation and therefore requires normal full initialization.

At near-field cold start, a group with no published representation uses its existing authored root when its complete detail set exceeds the normalized total scene-slot capacity. The root still warms under the original upload budget and requires complete readiness before publication; it is never declared ready merely because it is smaller. `PendingCapacity` continues to count the blocked detail demand once per group during this fallback. If the live detail set later fits alongside the root, the normal transaction stages and publishes it. This fallback does not solve temporary slot competition between groups, material-card capacity, invalid roots or missing readiness. See the [finite CPU evidence](ReviewBrief-HlodColdStartRootFallback01.md); it does not establish native rendered coverage.

The owner calls `ReportReadiness(stableId, revision, geometryReady, materialReady, lightingReady)` for each prepared proxy. Reports are accepted only for a currently resident matching identity/revision. Once every target member has a matching complete report, the next `Prepare` publishes the entire target set and removes the old set in the same update. `InvalidateReadiness()` must be called when cache/backend/atlas generations change; callers must reject stale GPU completion reports before forwarding them. The readiness container itself is a CPU receipt table, not a GPU fence.

The renderer integration uses `HybridLumenGIHlodReadback` after recording irradiance updates. Its snapshot contains the actual variable card index set and generations, owner layout generation, material atlas generation, cache epoch/grid and geometry source. The callback rechecks current source eligibility and identity, and rejects changed SDF assets, textures/content versions, bounds or transforms even if a replacement upload has already become ready. Normal double-buffered cache alternation is allowed; cache reallocation requires epoch advancement or explicit invalidation. Source guards run again before scene publication.

For a baked-chart owner, **every required chart** needs at least one genuinely covered patch, and every covered patch must meet the initialization accumulation threshold, currently two by default. Explicitly empty patch cells are allowed, but an entirely empty required chart blocks publication. Tiny charts and alpha-clipped material with no surviving texels can therefore remain warming. An owner without a chart asset uses the approximate six-view fallback and requires only object-level nonempty coverage. Neither gate measures complete geometric coverage or irradiance convergence, and uniform material fallback never counts as a covered chart.

The material cache admits complete variable chart sets, prioritizing published owners before warming owners. A configured invalid/stale asset, unsupported chart material or a set larger than available capacity is rejected as a whole. It is not silently converted to six views or partially declared ready. Both old and target scene representations and their required material pages need sufficient staging capacity. Changing the patch grid rebuilds material/anchor storage and invalidates pending initialization results. See [SurfaceCache.md](SurfaceCache.md) for card mapping and allocation.

`IsPublished(slot)`, `IsWarming(slot)`, `PublishedCount`, `WarmingCount` and `PendingCapacity` expose the transaction state. The scene BVH accepts only published slots. Hardware and global-distance-field integrations must apply the same visibility rule; simply testing `identity.w > 0.5` is sufficient for preparation, but would expose duplicate geometry in a live ray backend.

Pure commits tag old-removal/new-addition records with `ChangeKind.Representation`. A local-change consumer must preserve the target's prepared lighting while making surrounding transport reactive. Otherwise the removed aggregate bounds could hard-clear all freshly warmed detail patches at the instant of publication.

Material-only revisions keep unchanged geometry visible and invalidate lighting readiness. Transform, topology and unknown/manual edits remove stale geometry immediately, even if that creates a temporary coverage gap while replacement work waits for budget. Atomic publication never makes obsolete geometry correct. New groups have no previous representation to retain and remain unpublished until preparation completes.

Readiness means initialized data for the accepted revision/generation, not irradiance convergence. Targets that change every frame may not present a consistent ready snapshot before the next revision. Baked charts currently require readable, undeformed MeshRenderer sources; deformation requires rebaking and appropriate revision updates. Authored aggregate meshes are not automatically regenerated when individual detail meshes deform. Applications must update the aggregate or exclude such dynamic objects from that HLOD group. Missing async-readback support, persistent failures or insufficient preparation budgets do not trigger an unsafe timeout publication.

## Explicit additive-scene manifests

Create **Assets > Create > Hybrid Lumen GI > Scene Streaming Manifest**. Each entry provides a unique ID, an exact `Assets/.../*.unity` path, world bounds and load priority. Include these scenes in the application's Build Settings. Add `HybridLumenGIChunkStreamer` to a persistent bootstrap object, assign the manifest and observer, and configure load/unload distance, maximum owned resident scenes, concurrent operations and new operation attempts per frame.

Optional `additionalObservers` in the inspector, or `SetAdditionalObservers(params Transform[])`, add explicit viewpoints to the legacy observer/main-camera fallback. The setter copies the array; null/empty removes additions. The nearest viewpoint controls each chunk's distance demand, with one shared operation budget per frame. All viewpoints must leave the unload distance before demand is withdrawn; no live viewpoints leaves the state unadvanced. This does not authorize unloading or register cameras automatically. The separate asset-page representation also has its own explicit viewpoint collection.

The driver uses `SceneManager.LoadSceneAsync(..., LoadSceneMode.Additive)` and `UnloadSceneAsync`. Loads use distance hysteresis and reserve residency/concurrency capacity while in flight. Failed attempts also consume the per-frame start budget and receive a 60-step retry backoff. A load that becomes unwanted cannot be cancelled; it completes and then waits for safe unloading.

Before unloading an owned chunk, application orchestration must call `ReportUnloadSafe(id, generation, true)` after a replacement representation is published and no camera depends on the chunk. This gate defaults to false. The current generation is available in `ChunkStreamer.State.States`; an old generation cannot authorize a later load. A scene already loaded by another system is never adopted for automatic unloading. If an owned scene is externally replaced, its new scene handle is also treated as externally owned.

The IO driver does not silently unload scenes when disabled or destroyed. Native operations cannot be cancelled, so the application retains those scenes and must resume or transfer orchestration explicitly. The resident-scene limit covers scenes owned/loading through this driver, not unrelated application scenes or a measured byte budget.

Cross-scene HLOD membership is an application integration concern. Bind newly loaded detail proxies to a persistent authored aggregate through `SetHLODParent`; Unity cross-scene serialized references must not be assumed to establish those links. This module does not automatically register membership or infer cross-camera unload safety, generate aggregate meshes, load Addressables, or implement disk-level sparse SDF brick streaming.

## Offline verification

`Tests/Validate-HlodTransactions.ps1` compiles the actual scene/BVH/readiness source and checks readiness gates, stale reports, multi-frame warm-up, whole-group commits, cancellation, insufficient staging capacity, material-only retention, immediate stale-geometry removal, nested root/leaf grouping and readiness invalidation.

`Tests/Validate-ChunkStreaming.ps1` compiles the actual IO policy against a fake asynchronous backend and checks operation/residency limits, hysteresis, unload authorization, uncancellable loads, generations, external ownership, scene-handle replacement, failure budgets and retry backoff. These checks do not execute Unity scene IO or GPU work. Engine integration, activation spikes, rendered transitions and cross-camera unloading remain runtime validation requirements.

`Tests/Validate-HlodReadback.ps1` exercises callback coordination with recorded requests, including variable/noncontiguous cards, required-chart coverage, stale layouts/source data, generation reuse and cache ping-pong. Callbacks use supplied CPU arrays; they do not establish native GPU completion. Use the unified `Tests/Validate-Offline.ps1` report and source hashes for the current candidate's individual outcomes. No Unity/GPU production acceptance is claimed.
