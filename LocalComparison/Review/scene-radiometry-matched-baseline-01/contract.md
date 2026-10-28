# C-prospective-01 — predeclared matched baseline contract

This is a NEW source/product pairing. The previous historical material closure
remains false. Runtime is unchanged. Source freeze and baseline export happen in
the same and only Unity process, after import. No scene generator is called.

Use the archived chain02 Static.unity structure and archived executed
Renderer/Pipeline/Graphics/Quality/Player settings, together with the six explicitly
adopted current-only material/meta files from iteration15. Preserve their original
and imported bytes; the latter define this new baseline. Freeze real mesh arrays,
transforms, submeshes, material values/keywords, proxy inputs, light settings,
camera matrices, script and shader dependencies. Recheck at103 and119 without
rebaselining. Restore all changed deployment files and generated metadata.

One native process, maximum120 target-camera logical frames. Source stays ON.
Warmup0–103; gate103 requires submitted readback completion, source identity,
exact-software backend and two unique patch/four receiver coverage. It is not a
brightness gate. Observation104–119; final PNG/HDR only104/119. Gate119 must run
before Finish and before restoration. Stop at the first error; no second launch.
All120 have source/binding/selected-patch/update receipts. Full cache old/new and
gather/stage observations are104–119 only. Frame103 retains receiver positions
and header-completion receipts. Fixed rules and pixels are unchanged; identities
are discovered fresh, not assumed to be historical entries21/26.

Independent targets are the two actual cache anchors and four actual receiver
positions at119, with position/identity only. Source triangle/submesh/material/
facing matching precedes integration. Position tolerance is16 float32 eps times
max(1, absolute target coordinate); shading-normal vector tolerance0.02. Cache Ng
has a documented5+5-bit oct encoding (step2/31, round-to-nearest ties-to-even), so compare it with the independently
quantized SOURCE triangle normal using0.002 tolerance for subsequent float repacking;
GI receiver Ng uses source normal tolerance0.02. Preserve raw/source/encoded normal
distances. This rule was fixed before the new native run: old geometry-only evidence
showed that raw Ng differs from +Y by0.03332, consistent with5-bit quantization.
Do not silently widen a raw-normal threshold. No target snapping. Multiple coplanar triangles on the same
renderer/material are equivalent; other ambiguity stops. Float-input origins use
that position uncertainty as numerical outward offset; subsequent double hits
use64 double eps times scene coordinate scale. No product0.06 bias is used.

The standalone CPU solver only reads reference-scene.json and reference-targets.json.
It performs double triangle intersections, using independently constructed mesh
bounding boxes. Stock opaque flat URP Lit surfaces, no textures, no active emission,
neutral proxy overrides, nonmirrored transforms, winding consistent with flat outward
normals (reject rather than repair inconsistent indices) and one white realtime point light
are the intentionally bounded support. Unsupported source data stops integration.

Raw sRGB base/spec colors are independently converted. Metallic workflow diffuse
rho = linear albedo *0.96*(1-metallic); actual _SPECULAR_SETUP selects the alternate
1-max(linear specular) factor. _EMISSION is disabled, so effective emission is zero.
Direct relative irradiance uses URP's inverse-square range fade and shadow/layer
policy. C=E_indirect/pi is the mean endpoint outgoing diffuse radiance under cosine
sampling; do not multiply target rho and do not fit a pi/gamma/exposure factor.
Explicit direct contribution is reported separately. Reference uses all source
geometry with exact visibility; product finite tracing/cache/screen models differ.

Six targets,8 independent batches of4096 paths each, at most64 diffuse vertices.
Seeds are NumPy PCG64 SeedSequence([0xC0012026,targetIndex,batchIndex]), fixed before
product comparison. No Russian roulette, adaptive sample counts, new seeds or
parameter fitting. Preserve per-bounce means, all batch means, termination depths.
Approximate t7 intervals (2.364624251 standard errors) are descriptive only.

Prove source max rho<1 and positive minimum point-light-to-triangle distance.
Let Dmax=max(lightRGB)/dmin², Lmax=rmax*Dmax/(1-rmax). Nonnegative omitted tail
<=rmax^64*Lmax; every whole-path estimator is bounded by Lmax. Report a simultaneous
95% Hoeffding half-width across18 point/channel comparisons, plus that tail.
Reference-only precision target is1e-4+10% of the finite64 mean; it is NOT a GPU
quality threshold. If strict sampling+tail bounds exceed it, reference qualification
stays false even if approximate intervals or the last bounce are small.

Product comparison runs only after reference output exists. Compare cache C and
raw incoming quantities; retain history/filtered/final HDR as separate stages.
Show actual commits and window variation; correlated16frames are not independent
GPU confidence samples and120frames are not automatically steady state. Different
numbers alone do not prove a Runtime defect. Separate source closure, correspondence,
product observation, reference qualification, conclusive comparison and native exit.
Earlier exceptional-exit1MiB scratch remains unresolved even on a clean normal exit.

Primary normalization sources, read before implementation:
- Unity6 material Color conversion: https://docs.unity3d.com/6000.0/Documentation/Manual/SL-PropertiesInPrograms.html
- Locked URP17.0.4 BRDF.hlsl, Lighting.hlsl, RealtimeLights.hlsl, LitInput.hlsl and SurfaceInput.hlsl (archived by exporter).
- https://pbr-book.org/4ed/Reflection_Models/Diffuse_Reflection
- https://pbr-book.org/4ed/Light_Transport_I_Surface_Reflection/A_Better_Path_Tracer

Bounded verification: compile new C# integration using the existing Unity response
and redirected outputs; check independent geometry/attenuation/occlusion identities
with an analytic offline fixture. Reuse unchanged HLSL compile evidence by hash.
No repeated native attempt or broad DXC matrix. All failed and successful commands
are preserved for GPT6Pro. Full original development plan remains open.
