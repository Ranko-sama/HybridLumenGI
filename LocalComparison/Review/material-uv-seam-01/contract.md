# One ordinary material/UV seam observation

Purpose fixed before native execution: decide the limited ProductionPlan section 8
contract that chart raster and patch anchors retain their source submesh material
and UV on both sides of one ordinary static seam. No product change is proposed.
Existing interior-layer, nonuniform-scale and ordinary color evidence is reused.

Input: one identity-transform XY mesh, z=0, normal +Z, two adjacent quads.
Left submesh spans x=[-1,0], right spans x=[0,1], both y=[0,1]. Seam
positions coincide but vertices/UVs are separate. UV left=(x+1,y), right=(y,1-x).
Both ordinary opaque Lit materials are white, metallic 0, Cull Back. Each has
an 8x8 point-filtered, no-mip, linear RGBA32 texture: left U<.5 red, else green;
right U<.5 blue, else yellow. Default chart baking, 64-pixel tiles, patch grid 4.
Save/reload the mesh/charts/capture subasset. One production SurfaceCache capture.

Observation uses complete native diffuse/position/emission-validity atlases and
the actual metadata and int2 anchor buffers. No compute adapter, transport
instrumentation, injected cache illumination, screenshot, hash or extra build.
Output records all input vertices/UVs/indices/texture pixels, chart membership,
four source triangle bindings, metadata identities and the original atlas row order.

Analysis is fixed independently of the candidate output colors/validity:

* Derive each source plane's projected domain from its recorded source geometry
  and the actual recorded projection/atlas rectangle, at atlas pixel centers.
  Evaluate the source plane intersection, source UV and source texture value.
  Keep every interior point, including those nearest the seam. Exclude only
  source outer-edge ties or the point-sampling stripe tie within 1e-5 source UV.
  Count exclusions explicitly. Never use observed validity to choose the domain.
* The two submeshes must retain their own source triangle/chart/card identities.
  In each predetermined domain require covered finite output, position agreement
  within 2e-5 world units and diffuse RGB within 2/255 of source albedo*0.96.
  The tolerance includes half and RGBA8 storage, not a physical GI error threshold.
* Report each side and the nearest two interior atlas columns/rows to x=0
  separately. The near-seam subset is chosen from expected position distance
  before inspecting output. Both sides must sample both texture colors.
* Every actual patch anchor must lie in its own half-open cell. Where the source
  plane covers legal cell pixels, require a finite covered anchor belonging to
  the same source side with the expected UV/material. Empty cells remain explicit;
  a correct anchor cannot compensate for missing pixels elsewhere in the domain.
* Sanity-check the fixture's discrimination: report how many predetermined pixels
  would differ under swapped material slots or ignored right-side UV rotation.
  These are analytic alternatives, not additional native runs.

Collection success, ready counters and absence of engine errors are not a quality
pass. Launch/readback/input insufficiency is retained and does not authorize an
automatic second observation. A mismatch only supports investigation if attributable
to source coverage, UV, material or anchor ownership in this input. Otherwise report
insufficient. Success covers this static unit-transform two-submesh configuration;
it does not close mirror/transform, bilinear/mip seams, MPB changes, pool reuse,
lighting convergence, exact ray materials, whole-image quality, Player or performance.

Astra Max reviewed the necessity and limited scope before execution. It requires
distinguishable source UV/material values and explicit legal boundary ownership.
