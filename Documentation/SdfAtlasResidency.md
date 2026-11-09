# Object SDF residency and local invalidation

`HybridLumenGISdfAtlas` owns bounded voxel storage and per-instance metadata for already-loaded baked object SDF assets. Multiple instances of one asset share uploaded voxel storage. Invalid, pending and over-budget assets retain the analytic software representation. Upload completion is tracked independently from a scene revision; a static pending asset can become ready in a later frame's upload budget.

When a published fallback caster changes between its analytic and object SDF representations, the renderer uses the selected lights' shadow reach to update affected receivers. The original geometry bounds still determine hard history rejection. The fixed point-light doorway comparison covers a delayed upload opening the light path and notifying the distant floor. [DXR camera and GPU fallback comparison](../LocalComparison/Review/sdf-shadow-reach-236/result.md)

Renderer Feature cameras share an engine-frame allowance of 262,144 RFloat voxels (1 MiB), enough for the largest supported 64³ volume. Each camera still owns its atlas and obeys its per-prepare limit. A repeat prepare uses the remaining frame allowance. The oldest waiter whose reservation covers the current frame holds room for one complete volume. Other requests can use the remainder. Withdrawal or atlas disposal removes the request. Until an interval longer than two frames is observed, a reservation lasts through two absent frames. For a longer observed interval between prepares, a reservation covers only the next expected prepare frame and expires on the following frame. The actual upload still checks the current source on that camera's prepare. [Fixed periodic camera comparison](../LocalComparison/Review/periodic-sdf-upload-270/result.md)

Ready volumes require no upload. A `SetData` attempt counts against the allowance even if it throws, while readiness still requires a successful return. Standalone calls to `Prepare` use their own per-call allowance. The shared count covers object-volume payloads passed to `SetData`. Metadata, global SDF bricks, GPU time and driver traffic have separate costs.

A failed upload keeps its source-version record and falls back to analytic tracing. After its metadata withdrawal succeeds, the atlas returns the voxel range for later uploads. If a metadata write throws, readiness and binding require a successful full metadata upload on a later prepare. A changed texture version can then request space through normal admission. The atlas still places each volume in a contiguous free range. [Controlled recovery comparison](../LocalComparison/Review/sdf-failed-range-225/result.md)

For a Box proxy with an active BoxCollider and no source Renderer, the analytic hit follows the collider's center, orientation and scaled dimensions. This applies to transforms with orthogonal axes aligned with the collider rotation. The scene BVH encloses the box in world space. The final hit and global distance calculation use its oriented faces. The box frame occupies the existing metadata slot and needs no voxel storage. Sheared or degenerate collider transforms and Renderer-backed Box fallbacks use their world bounds.

## Source validity and asset migration

A baked asset now includes a versioned SHA-256 fingerprint of the source vertex positions and triangle indices. The baker records it before generating voxels and checks it again when assigning the result, rejecting a source that changed during baking. A matching Mesh reference alone is insufficient. Runtime source validation requires a readable source Mesh as well as the readable RFloat distance texture.

**Older SDF assets without the fingerprint must be rebaked.** They are explicitly invalid, as are assets whose geometry fingerprint no longer matches. Use **Tools > Hybrid Lumen GI > Bake Mesh Distance Field**, choose a new asset path and assign the result; the baker preserves existing assets. Rejected sources use analytic tracing fallback, not stale baked voxels. `rejectedSdfSources` in renderer diagnostics reports affected prepared instances; it is distinct from upload-budget backlog and is not a count of all unsupported geometry. An explicitly assigned rejected SDF cannot satisfy the HLOD target's SDF-readiness check.

Validation is cached per asset. A weak-key table associates each source Mesh with a notification token shared by all its SDF assets. Loading, source notification or detectable count/bounds changes force a fresh comparison; ordinary rigid movement does not rehash vertex/index data. The weak-key table does not retain unloaded meshes, and its object tokens do not wrap like integer generations.

After an in-place edit, notify the shared Mesh on the main thread even when its vertex count and bounds are unchanged. The legacy `HybridLumenGIMeshSdf.NotifyGeometryChanged(mesh)` forwards to `HybridLumenGIMeshSource.NotifyGeometryChanged(mesh)`. Consumers see the new version on their next check. SDF source validation runs again, active proxies advance their geometry and transport revisions on refresh, and tracked receivers can detect the edit even without a proxy. Call `proxy.MarkDirty()` when the caller and other active proxies sharing the Mesh need their revisions advanced immediately. This also publishes the shared version. Disabled proxies refresh on re-enable. Rebake and reassign any SDF or charts whose source no longer matches. [Shared version](../Runtime/HybridLumenGIMeshSource.cs) · [Compatibility entry](../Runtime/HybridLumenGIMeshSdf.cs) · [Proxy refresh](../Runtime/HybridLumenGIProxy.cs)

`Scene.Prepare` calls the proxy's idempotent `RefreshSignatureForRender()` before residency and revision checks, catching transforms applied after its `LateUpdate`. Repeated camera preparations without another change do not advance revisions. Pure transform or uniform-material changes affect transport revision, while mesh-content changes also advance geometry-content revision. Scene classification preserves that content flag even when motion or a material edit occurs simultaneously, so hardware geometry can rebuild rather than retain stale triangles. Same-count/bounds in-place edits still require explicit notification; this is not automatic deforming-mesh support or a promise that sources may mutate during command execution.

Proxy `OnValidate` only sets an atomic pending flag. Main-thread preparation, re-enable or an explicit main-thread `MarkDirty()` consumes the flag once; disabled automatic refresh leaves it pending. This avoids inspecting Unity components or broadcasting to the active registry from a callback that can run on the loading thread. See Unity's [OnValidate contract](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/MonoBehaviour.OnValidate.html). This queued Inspector change is conservative geometry invalidation; it is distinct from the transform-only fast path during normal rendering.

## Representation changes

`RepresentationChangedBounds` contains all local representation-change domains from the last `Prepare`; `GeometryChangedBounds` is its hard-invalidation subset. Consume both after that call and before the next `Prepare`, which clears both lists. Old and new domains are retained when published geometry changes. The snapshot compares the asset reference, texture identity/update count, world transform, local field metadata, signed-field mode and stable instance identity. It includes the padded SDF volume's transformed corners as well as fallback bounds. Material-only revisions and allocator address changes do not change geometric representation.

| Transition | All representation domains | Hard geometry subset |
| --- | --- | --- |
| Published analytic fallback → ready SDF | Old fallback and new SDF | Both |
| Published ready SDF → pending/invalid fallback | Old SDF and new fallback | Both |
| Published SDF transform/content change | Old and new published bounds | Both |
| Ready published instance actually deleted | Old bounds | Old bounds |
| Warming upload/content change | None | None |
| Unchanged warming ready representation → published | New published bounds | None |
| Unchanged published representation retired by an exact pure HLOD-removal event | Old published bounds | None |
| Shape/revision, texture, asset or transform edit during retirement; unexplained disappearance; slot reuse | Published old/new endpoints | All emitted endpoints |

The global clipmap must consume **all** representation domains because even a pure visibility swap changes its contributors. For lighting-cache invalidation, add all domains as reactive-only, then add `GeometryChangedBounds` as hard geometry. Treating every domain as hard would erase the new HLOD representation's already validated warm cache on its publication frame.

Reactive-only retirement requires an explicit `Removed | Representation` scene event for the previous slot, stable identity and revision, with an old endpoint and no new endpoint. Additional Transform/Topology/Manual/Material flags, wrong identity/revision, or same-frame source changes prevent that downgrade. The retained old proxy/source snapshot is rechecked even when the slot has been removed; a texture update need not increment the proxy revision. A concurrent content/fallback change during publication is also hard. A pure publication must have identical ready representation snapshots on both sides.

Analytic-only changes with neither endpoint SDF-ready remain the scene's responsibility. This list does not replace the scene's identity/geometry change events. Warming means `identity.w == 2`; published means `identity.w == 1`. Preparing a staging object must not invalidate the old HLOD representation's lighting merely because its SDF upload completed.

`IsReady(slot, stableId, revision)` is a pure CPU query of the last prepared metadata and upload state. It supports warming slots and compares the exact supplied identity/revision. It is **not a GPU fence** and does not establish published visibility or initialized lighting.

`IsSourceCurrent(slot, proxy, stableId, revision)` additionally checks the current source against the uploaded snapshot, including source fingerprint validity. This prevents a publication ticket from outliving a notified geometry edit, texture update, replacement asset, moved transform, local-bounds/signed-field change or source mesh mismatch even if the proxy revision did not change. It does not call Prepare, upload voxels or consume representation-change events; the asset's CPU source-validation cache may be refreshed. The scene's publication gate and GPU readback coordinator own the remaining material/lighting conditions.

Offline checks:

```powershell
./Tests/Validate-SdfAtlasRepresentation.ps1
./Tests/Validate-SdfAtlasAllocator.ps1
./Tests/Validate-ProxyUpdates.ps1
./Tests/Validate-SceneResidency.ps1
```

The representation suite compiles the actual atlas and asset classes against Unity-resource/math substitutes. It checks source provenance, legacy/unreadable/stale rejection, shared-source notification, publication/retirement, concurrent edits, deletions, stale receipts and slot reuse. Separate actual-source proxy and scene tests cover shared-instance revisions, late refresh and combined content/transform/material flags; allocator tests check overlap, capacity and coalescence. Use the candidate's source-matched unified JSON report for exact results. These are CPU/state tests; actual Unity callbacks, uploads, readability behavior, GPU visibility and rendered SDF correctness remain separate validation work.
