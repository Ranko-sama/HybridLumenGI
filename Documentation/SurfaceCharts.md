# Triangle surface charts

`HybridLumenGISurfaceCharts` stores deterministic charts of a readable, undeformed source mesh. Each capture submesh contains only its chart's original triangles. This permits internal faces and concave geometry to receive material pages without an outer face hiding them during capture. It does not establish GPU coverage or lighting convergence; those remain separate runtime checks.

## Asset and capture contract

- `SourceMesh` is the original mesh. `CaptureMesh` is a distinct clone with unchanged vertex streams, normals, tangents, colors and UVs; only indices/submesh organization change. The source mesh is never edited.
- `Charts[i]` corresponds to capture submesh `i`. Its `sourceSubmesh` selects the original material/MPB. `triangleIndices` contains **triangle ordinals within that source submesh**, not vertex indices. Original indices are read with base-vertex offsets applied, then written into the capture mesh with base vertex zero.
- `stableId` is nonzero and derived from the deterministic seed triangle. It is stable for unchanged source topology/settings, not across arbitrary rebakes. Cache identity must also include asset `ContentVersion` and owner identity.
- `localToCard` maps mesh-local positions into normalized card coordinates: xy inside the tile, z increasing inward along `-direction`. `direction` is the unit outward seed normal. `localBounds` bounds that chart's source triangles.
- `SetBakedData` validates the asset before publication. `IsValid` validates deserialized assets once on the main thread and caches the result. `OnValidate` advances `ContentVersion` and invalidates this cache without accessing Mesh APIs in the callback. `OnEnable` clears the validation cache.
- `Charts` and `CaptureMesh` are exposed for reading by the renderer. Do not mutate their contents at runtime; use a new bake and `SetBakedData`. Source mutation must advance the owning proxy's source revision before `MatchesSource` is checked. A direct mutation without revision notification violates the asset contract.

Validation rejects nonfinite/nonaffine/singular matrices, unrepresentable inverses, invalid directions/bounds, duplicate identities or triangle ordinals, out-of-range ordinals, capture vertex-stream differences, capture indices differing from the declared source triangles, invalid projected coverage/overlap, and missing valid triangles. Inspector edits invalidate already-issued page/readback identities through the version change. This is CPU input validation, not Unity serialization or rendering acceptance.

## Deterministic bake

The baker processes original submeshes/triangles in order. It welds **exactly equal positions for adjacency only**, preserving all original UV seam vertices in capture. Charts never cross source submeshes. Sorted neighbor traversal grows an edge-connected chart within a fixed seed normal cone, with at most the configured triangle count.

The seed's longest edge defines the fixed right axis; its normal defines the remaining basis. All proposed triangles are tested in that same projection. A strict separating-axis test rejects any positive-area projected intersection; shared edges and points are allowed. The final serialized float matrix is checked again. A failing group is split back to its seed and the other triangles are processed later. A single triangle that cannot be represented by a finite float projection causes the whole bake to fail with a rescale/rebase diagnostic.

Only exactly zero geometric area is counted as degenerate. Small but nonzero triangles remain. XY margins scale with each projected extent, avoiding an absolute padding floor that would erase thin triangles. The longest-edge basis and final singleton area check prevent thin diagonal triangles from becoming almost empty tiles in mathematical projection. A CPU 32×32 sample-grid test covers the supplied skinny/tiny fixtures, but does not emulate GPU floating-point math, rasterization or alpha clipping.

`chartBudget` is advisory: all valid triangles are retained even when the result exceeds it, and `BakeReport.capacityExceeded` reports the condition. Runtime residency must expose insufficient capacity and must not publish a partially covered owner as complete. Nontriangle topology is reported separately and is not converted to triangles.

## Fingerprint and cost

`MatchesSource` requires the same readable source Mesh and compares SHA-256 content, including raw vertex layout/streams, raw index buffer and format, all submesh descriptors, mesh bounds, bind poses, all bone counts/weights, and every blend-shape frame's name, weight and position/normal/tangent deltas. Counts or instance identity alone do not validate content. Call it on source-revision changes, not every frame. Raw-byte fingerprinting is deliberately conservative: storage/layout changes can require a rebake even if the visible shape seems unchanged.

Full asset validation performs vertex-stream hashing, index/ownership checks, and pairwise projected overlap tests within each chart. It occurs at `SetBakedData` and the first `IsValid` after load or Inspector validation. Bake growth also performs pairwise overlap work, bounded by `maxTrianglesPerChart`; the default is 256. This is an offline operation, not a per-frame topology algorithm.

## Editor workflow and current limits

Select a Proxy or static `MeshRenderer`, enable Read/Write on its source mesh, then use **Tools → Hybrid Lumen GI → Bake Surface Charts**. The window writes a new asset with the capture mesh as a subasset, assigns it with `proxy.SetSurfaceCharts(asset)`, and refuses to overwrite an existing file. It can add a proxy when needed. Cancelled/failed work does not intentionally retain a partial new asset. Actual Unity persistence/Undo behavior remains to be tested.

Skinned/deformed mesh poses are not supported by this bake/capture contract. Exact-position adjacency does not repair cracks, nonmanifold meshes or nearly coincident seams. Triangle membership covers concave/internal surfaces geometrically, but alpha-clipped empty charts, back-face behavior, material sampling, and tiny/mixed-size triangles within a multi-triangle tile still need GPU coverage testing. A card with no valid material samples can prevent required-page publication. No claim is made that mathematical chart membership alone solves all visible or hidden-surface lighting.

## Verification and official API evidence

Run `Tests/Validate-SurfaceCharts.ps1` with Windows PowerShell 5.1 or PowerShell 7 and the .NET 8 SDK. It compiles the actual runtime source with minimal CPU adapters. The suite currently checks 91 fixtures and 3,854 assertions: U channels, enclosed/internal layers, material boundaries, UV seams, projected overlap, degenerate/slender/tiny/negative-coordinate geometry, deterministic output, full triangle ownership, independent polygon-clipping overlap checks, capture clone indices, source fingerprints, malformed assets and validation-cache invalidation. These adapters do not verify Unity APIs. No Unity installation, Unity asset import, player build or GPU execution was used.

The following API contracts were checked independently against official Unity sources:

- Unity 6 documents [MeshData.GetIndexData](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Mesh.MeshData.GetIndexData.html) as a direct raw index view. The fixed [UnityCsReference MeshData.cs](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/Graphics/MeshData.cs#L375) implementation divides byte length by `sizeof(T)`, checks divisibility, and uses `Allocator.None`; `byte` is valid for hashing the whole buffer.
- [GetVertexData](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Mesh.MeshData.GetVertexData.html) exposes raw vertex data. The code disposes the [AcquireReadOnlyMeshData](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Mesh.AcquireReadOnlyMeshData.html) owner after all views are consumed; it does not separately dispose those views.
- Fixed [Mesh.bindings.cs](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/Graphics/Mesh.bindings.cs#L205) constructs both `GetAllBoneWeights` and `GetBonesPerVertex` views with `Allocator.None` and read-only safety handles. The fingerprint reads them synchronously and does not dispose mesh-owned memory.
- [GetIndices](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Mesh.GetIndices.html) applies the requested base-vertex offset; [SetIndices](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Mesh.SetIndices.html) accepts the explicit submesh and base vertex used by the capture clone.

Remaining acceptance work: unified offline regression after runtime integration; Unity 6000.0 import/compile and bake/save/reload; GPU page coverage and ordinary Lit UV/normal/emission/alpha sampling on concave fixtures; sufficient-capacity versus blocked-publication behavior; and a new source-package manifest only after those independently recorded checks.
