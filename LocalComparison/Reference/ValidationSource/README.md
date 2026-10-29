# Source-only primary visibility

This is an offline geometry/domain tool, not a radiance renderer, qualified
physical reference, GPU rasterization certificate or product-quality verdict.
It never accepts a candidate manifest, RGB, validity mask, support buffers or
HLGI cache as an oracle. NumPy is the only non-standard dependency.

```powershell
python -B LocalComparison/Reference/ValidationSource/test_primary.py
python -B LocalComparison/Reference/ValidationSource/primary.py --source C:/input/source.json --state C:/input/states/frame-0119.json --output C:/new-output
```

`--input-root` sets the manifest-relative artifact root (default: source parent).
Source and state must be inside it. Every declared physical source/dynamic asset
is read and SHA256/length checked. State binds the exact source hash. Optional
`--source-sha256` and `--state-sha256` pin caller-known identities. Duplicate JSON
keys, NaNs, unsafe paths, escaped symlinks, missing artifacts and malformed
geometry are rejected. `input-accesses.json` records every input read. The output
must be a fresh disjoint directory; originals are never written.

The actual frame state's mesh, submesh indices/baseVertex, material slots,
positive-determinant affine transforms, culling and enabled/layer flags are used.
Triangles are intersected independently. Reusable output includes near-plane ray
origin, unit direction, far-plane limit, closest triangle/owner/material mapping,
barycentrics, position, geometric/shading normal, UV0, BaseMap-ST UV and device
depth. Directions and normals are not inferred from a product buffer. This
version deliberately retains global unsupported state for unknown shaders,
coverage branches, deforming/static-batched renderers, mirrored transforms,
nontriangles or non-one-to-one submesh/material semantics; it never makes such
occluders disappear into a successful sky result.

`primary.npz` holds arrays shaped `[height,width,...]`; `geometry-index.json`
maps triangle IDs to source keys, submesh, primitive and material. `triangle=-1`
is no center-ray hit. Non-hit numeric fields are finite zero placeholders, not
measured black or valid geometry. Always consult `classification`:

| Code | Meaning |
| --- | --- |
| 0 sky | No source opaque center-ray hit inside the camera near/far interval, outside the edge guard |
| 1 receiver | A closest supported source center-ray hit outside the guard |
| 2 boundary | Half-full-pixel Euclidean band around any clipped triangle edge, or numeric closest-hit tie |
| 3 unsupported | Source/geometry semantics incomplete; does not establish sky or a valid receiver |

The edge guard intentionally includes hidden edges and coplanar diagonals. It is
a declared spatial footprint, not a fitted float-error allowance. Its conservative
coverage can be wider than a true silhouette. Intersection arithmetic is float64,
with fixed degeneracy/tie guards and a VP conditioning rejection; it does **not**
prove all legal GPU float32 transforms, subpixel snapping, depth tests or clipping.
The approximate picture solver reports those differences explicitly instead of
claiming a strict certificate. No reference-quality PASS is generated, including
when all sources are understood.

The default grid is the full camera viewport. Optional `--grid-width` and
`--grid-height` select exact representative full pixels:
`floor((2*gridPixel+1)*fullSize/(2*gridSize))`, then their half-integer centers.
This is not image resampling or an area average. Off-origin viewports are rejected
in this version. Both perspective and orthographic finite camera matrices are
supported. Projection already contains actual jitter; it is not added again.

Raw row order and UV origin are independent. A top-left UV maps to clip
`(2u-1,1-2v,deviceDepth,1)` using the actual row-major GPU projection and view.
The projection can already contain Unity's render-texture Y flip. Neither a
negative m11 nor an upside-down-looking preview authorizes flipping the raw rows.
The independent reprojection residual is included for coordinate self-checking;
it is not an observed GPU depth comparison. Output performs no display flip.

The CLI exit 0 means source-domain artifacts were produced, not quality pass.
The report includes all class counts, unsupported reasons, source/state hashes,
implementation hashes, complete input read ledger and output hashes. A failure
is retained in the new directory. Frozen candidate files and existing reports
are never changed. The next radiance solver can consume the qualified subset of
these source inputs, but may not silently omit boundary/unsupported pixels to
claim full-image acceptance.

## Approximate source-only picture reference

`materials.py` and `lighting.py` interpret constant stock-Lit diffuse/emission and
analytic source lights with hard geometry visibility. `audit_lighting.py` audits
these source values. `render_reference.py` then produces independent CPU diffuse
path-traced `filteredD`, sampling standard errors and optional fixed-exposure PNGs.
See [transport-contract.md](transport-contract.md) for scope, commands, preserved
first results and all model differences. The raw rows are never flipped; a
separately named display PNG is available for human viewing.

The first six-test domain implementation and original result metadata remain
reproducible in `source-domain-v1-original/`. Current generic geometry guards also
handle per-vertex normal normalization, ShadowsOnly primary exclusion, stencil
override refusal and nonstandard depth-write refusal.
