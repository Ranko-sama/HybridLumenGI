# Resident scene acceleration and update contracts

`HybridLumenGIScene` owns a per-camera fixed table of up to 256 resident instances. `HybridLumenGISceneBvh` builds a balanced median-split BVH over published entries. Its leaves retain the table's stable slot indices. Membership changes rebuild the topology; motion refits the existing topology bottom-up. If summed internal-node surface area grows beyond 1.75 times the rebuild baseline, the topology is rebuilt to limit degradation from large motion.

The GPU node layout is 32 bytes: `float3 minimum`, `uint skipIndex`, `float3 maximum`, `int proxySlot`. Nodes are stored in preorder. An internal node has `proxySlot = -1`; its first child follows it, and `skipIndex` points immediately after its entire subtree. `HLGIBvhNextLeaf` traverses this array without a stack and returns candidate slots. The caller must still execute the selected mesh-SDF, analytic-shape or hardware-triangle intersection. BVH bounds are never accepted as geometric surface hits.

Bounds cover the analytic representation and, when present, all transformed corners of the baked SDF volume. A sphere proxy expands each axis to its actual analytic radius. Internal nodes retain explicit minimum/maximum values instead of converting repeatedly through center/extents; the latter caused a boundary-ray rejection during fuzz validation and was corrected.

Call `scene.Bvh.Bind(command, compute, kernel)` for every transport kernel that traverses the scene. `scene.Prepare` updates the BVH automatically. The GPU allocation is at most 511 nodes, approximately 16 KiB per camera at 256 slots. This excludes instance data, mesh volumes and hardware acceleration structures.

## Local change records

`DirtyRegions` describes only the most recent `Prepare` call. Each record provides `PreviousBounds`, `CurrentBounds`, `HasPrevious`, `HasCurrent`, `Slot`, `StableId`, previous/current revision, and a flags enum distinguishing addition, removal, transform, material, topology and explicit/manual invalidation. Slot reuse retains separate records for the old and new identities. Up to approximately twice the slot capacity may therefore be required when uploading the records.

Old geometry is invalidated immediately, even when its replacement must wait for the upload budget. A changed object records both its previous and desired bounds; a later upload records the newly resident region. `RequiresFullInvalidation` is reserved for capacity/resource reallocation. The existing boolean return from `Prepare` still reports any change for backward compatibility; it should not be treated as an unconditional global history reset by an implementation using local invalidation.

These regions are inputs to cache/history invalidation, not a complete dependency graph. The consumer must account for transport and shadow influence distance. Editing vertices in place without changing bounds or vertex count still requires `proxy.MarkDirty()`, and a baked mesh SDF must be rebaked after deformation.

HLOD staging uses `identity.w = 2`; published instances use `1`, absent slots use `0`. Only published entries enter the world BVH. SDF/material/cache preparation may consume both published and warming entries. Pure HLOD publication carries `ChangeKind.Representation`: old/new representation changes should make neighboring transport reactive without hard-clearing the newly prepared lighting cache. Actual transform/topology/manual edits remain hard changes. See [HLOD and scene streaming](HlodStreaming.md) for readiness, atomic publication and the limits of asynchronous scene IO.

## Patch scheduling

`HybridLumenGICacheScheduler` writes a uint update mask for `capacity * 6 * grid * grid` cache patches, with grid clamped to 1–4. `SelectedCount` never exceeds the requested budget; zero budget selects nothing. At least one quarter of the budget, rounded up, goes to valid entries with the oldest service time. Remaining work prioritizes own-instance changes, lighting changes and nearby dirty regions. Dirty priority remains until each affected patch is serviced.

Revision changes reset sample coverage but retain the fairness service clock. This prevents continuously moving objects from starving stable geometry. Identity reuse clears coverage and the previous object's scheduling metadata. Candidate and mask arrays are retained across frames. Two array sorts are performed per update; large grids increase CPU scheduling cost and still require target-device profiling.

`ScheduledCoverage` reports the fraction of valid patches serviced at least once for their current dirty state. It does not measure irradiance convergence or rendered quality.

An optional `readyCards` array gates candidates by `entry / (grid * grid)`. Missing cards preserve their pending priority but consume no update budget and do not contribute to coverage or age statistics. Readiness is supplied by the capture owner; the scheduler has no dependency on the surface-cache implementation. Coverage must therefore be read together with the capture system's page-coverage metric.

## Reproducible offline evidence

Run `Tests/Validate-SceneBvh.ps1`, `Tests/Validate-SceneResidency.ps1` and `Tests/Validate-CacheScheduler.ps1` with .NET SDK 8. These compile the actual runtime source against math, proxy and inert GPU adapters, outside the Unity project.

The deterministic BVH test passes 50,000 ray queries with no missing or duplicate candidates against an independent double-precision brute-force reference. Its sparse synthetic scene averages 14.87 node visits and 0.201 candidate leaves per query, versus 212.6 brute-force instance tests. These counts are an algorithmic workload comparison, not a GPU timing result. Dense overlapping bounds can still approach a full scan.

The residency tests cover bounded uploads, stable slots, local old/new regions, material/topology/manual changes, deletion and reuse, starvation prevention and capacity resets. Scheduler tests cover zero/hard budgets, the oldest-service quota, lighting coverage, a 96-frame continuous-motion fairness case, invalid entries, reuse and grid changes. Unity import, backend compilation and actual GPU execution remain separate validation steps.
