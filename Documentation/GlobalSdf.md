# Global SDF clipmap contract

`HybridLumenGIGlobalSdf` is a bounded, camera-relative cache of conservative unsigned surface-distance lower bounds. It is an **empty-space accelerator**. It never reports a ray hit, a material, or proof that an unknown page is empty. Final visibility and hit attributes still come from the existing per-instance BVH, mesh SDF and/or triangle backend.

The implementation is local to `Runtime/HybridLumenGIGlobalSdf.cs`, `HybridLumenGIGlobalSdf.compute` and `HybridLumenGIGlobalSdf.hlsl`. It does not implement scene-file IO, new HLOD asset production, or deformed mesh SDF generation. Only scene instances with `0.5 < identity.w < 1.5` participate. Warming HLOD instances are excluded.

## Addressing and storage

- Two to four levels, with voxel size doubling between levels. Each level tracks the camera's integer brick coordinate.
- Four voxels per brick axis. Configurable 4, 8 or 16 bricks per level axis. The default is three 32³-voxel levels (`8 × 4` per axis), base voxel size 0.5 world units.
- Physical brick coordinates use positive modulo of signed world-brick coordinates. Every page also carries the complete integer world key, level, generation and ready state. A torus slot does not identify a world location by itself.
- One brick stores 64 float lower bounds plus one float-sized raw generation word. The last word is bitcast to/from uint and published by a separate GPU dispatch. Queries compare it with page metadata, so a new metadata generation cannot expose old voxel data even at the same world key.
- No texture interpolation crosses page boundaries. A query selects the cell containing it, subtracts the distance to that cell's sample center, subtracts floating-point margins, then clamps to zero. If the fine page is unknown, a coarser valid page may answer. If all levels are unknown, the function returns false.

Default GPU allocation at 256 scene slots is about 494 KiB. The largest configuration allocates about 5.1 MiB. `AllocatedBytes` includes the active buffers, disabled query bindings and any detached clipmap still waiting for completion. The CPU scheduling arrays and retained source SDF assets are additional memory.

## Safe distance composition

At each voxel center, `CSMergeBricks` takes a capped minimum over every published scene instance. Analytic boxes and spheres provide unsigned surface distance. A resident object SDF provides an error-subtracted sample scaled by the reciprocal Frobenius norm of world-to-local. Outside the SDF volume, distance to its enclosing local box is used instead. The second interpolation-error allowance covers uncertainty around the sampled zero surface used by the final object-SDF refiner.

For every real Renderer, the result is additionally clamped by distance to an expanded union of its renderer bounds, proxy bounds and SDF bounds. This protects actual triangle geometry when the analytic or baked representation is incomplete or stale. The consequence is intentional: **inside those enclosing bounds the lower bound is zero**, so this configuration does not accelerate the renderer's internal empty cavities. This safety choice is shared by software and hardware tracing. Geometry-scale roundoff is subtracted in addition to position-scale roundoff; a large primitive can have a surface near the origin.

The field is capped by `MaxDistanceInBricks × brickWorldSize` (default two bricks). Dirty geometry invalidates bricks intersecting both the old and new object domains expanded by that cap plus one voxel diagonal. Invalidating only the object's occupied bricks would be incorrect: new geometry can reduce previously cached distances in neighboring bricks. Invalidations do not consume the update budget. Metadata bounds changes are also detected independently from scene revision, and SDF upload/representation changes are imported from `RepresentationChangedBounds`.

These bounds apply to the geometry published in the current scene representation. Hidden or nonresident world geometry is outside the contract, and current source SDF correctness remains a prerequisite for rendererless SDF instances. An absent instance is not repaired by the clipmap.

## CPU and GPU lifecycle

Use one instance per camera. The caller owns execution order and resource lifetime:

1. Prepare the scene and object SDF atlas.
2. Call `Prepare(scene, sdf, cameraPosition, configuration)`. This enumerates the clipmap, invalidates changed keys/domains immediately in its next metadata snapshot, and selects up to `UpdateBrickBudget` pending bricks. Age priority prevents starvation; finer levels and camera distance break equal-age ties.
3. On the graphics command stream, call `RecordUpdate(cmd)`. It uploads changed page and level metadata even at zero recomposition budget. With pending jobs it records the current object bounds and jobs, the merge dispatch, then the publish dispatch. The publish dispatch updates the retained GPU page table. An unchanged frame with no jobs records no uploads. [Recording behavior](../LocalComparison/Review/global-sdf-metadata-314/result.md)
4. Call `Bind(cmd, consumingCompute, kernel)` before consumers on the **same graphics queue**. A Bind before RecordUpdate disables queries. Async-compute queues need additional synchronization and are not supported by this contract.
5. In HLSL call `HLGIGlobalSdfEmptyDistance(worldPosition, out lowerBound)`. `false` means unknown. `true` with zero also means no skip is available. Advance by at most a positive lower bound; retain the original ray endpoint and perform exact scene refinement afterward. Never classify a zero coarse distance as a hit or an unknown page as empty.

`RecordUpdate` is idempotent for a prepared frame. `IsReady` and the CPU `TryGetPage` diagnostics mean that pages have been **scheduled** ready on this queue; they are not GPU fences. If a recorded command stream is discarded, call `InvalidateAll()` before preparing its retry. GPU generation tags reject stale payloads, while explicit invalidation makes the CPU scheduler retry them. Do not share a mutable instance across independent cameras or call Prepare again before the previous recorded stream is submitted in order.

When the feature disables Global SDF, the camera binds three one-element query buffers totaling 68 logical bytes and skips object, page and job preparation. An existing clipmap stays charged through the normal resource retirement completion. Turning Global SDF back on starts with unknown pages and the configured update allowance. [Controlled toggle sequence](../LocalComparison/Review/global-sdf-off-195/result.md)

Changing the clipmap layout, distance metrics, or object capacity on the same enabled instance prepares replacement buffers before switching storage. Replaced buffers stay in `AllocatedBytes` until the existing retirement queue releases them. Several replacements can be in retirement together. If buffer allocation fails, the previous storage remains owned and the private replacement is released. [Live reconfiguration comparison](../LocalComparison/Review/global-sdf-live-reconfigure-306/result.md)

Unity 6 exposes the required [CommandBuffer.SetBufferData](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.CommandBuffer.SetBufferData.html) uploads. Unity-side shader import, actual command ordering/resource hazards, and RenderGraph integration still require an Editor/GPU run; offline recording shims cannot establish those native behaviors.

Public resources for render-graph ownership/dependency declarations:

| Property | Element layout | Update access | Query access |
| --- | --- | --- | --- |
| `DistancesBuffer` | 65 float-sized words per brick | merge/publish write | read |
| `PagesBuffer` | 32-byte key/generation/ready/level | upload and publish write | read |
| `LevelsBuffer` | 32-byte integer origin plus float metrics | upload | read |
| `UpdateJobsBuffer` | 32-byte key/page/generation/level | upload, compute read | unused |
| `ObjectBoundsBuffer` | 32-byte min/max with clamp/published flags | upload, compute read | unused |

The object SDF and scene buffers must remain alive while merge work executes. The class calls `sdf.Bind` and binds `scene.Buffer` for the merge kernel. There are no global SDF render textures.

## Verification and limits

- `Tests/Validate-GlobalSdf.ps1 -CpuOnly` compiles the **actual C# scheduler** with recording substitutes for Unity resources. The cases cover layout, initial unknown pages, dispatch ordering, budget progress, partial scroll reuse, positive modulo, returning to rolled-out keys, old/new dirty domains, SDF readiness changes, warming/published states, renderer-bound changes, cancellation retry, configuration changes and disposal. A paired run also checks the affected pages, generations, ages and job order at an exact boundary and its next floating-point value. [Paired scheduler results](../LocalComparison/Review/global-sdf-dirty-rows-199/result.md)
- The same script runs native DXC on the actual merge and publish entry points and a query harness: 3/3 entries pass. It does not replace Unity shader import or execute the kernels.
- `node Tests/Validate-GlobalSdfBounds.mjs` runs an independent CPU numerical reference: 170,002 lower-bound cases, 16,602 affected dirty-domain checks and five key/generation/ready checks. It includes float32 arithmetic stress, large primitives near the origin, transformed sampled SDFs, and renderer AABB bounds against real triangle distance. This checks the mathematical model, not generated GPU machine code.

The compute cost is proportional to updated bricks × 64 samples × published instances, with enclosing-bound and zero-bound early exits. On the CPU, each dirty region is expanded once per level and projected onto its logical brick rows. The page sweep consults those row masks when applying invalidation. The comparison measures work in the CPU scheduler. GPU cost and whole-frame timing require their own measurements. Ray origins close to receiver geometry often have a zero lower bound, so a caller that skips only the initial ray segment may see little benefit.
