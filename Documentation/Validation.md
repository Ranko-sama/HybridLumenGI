# Validation and release evidence

The generated scene and the mathematical checks are test inputs, not a claim of a passed Unity import, image-quality test, hardware backend test, or performance certification. This source-only directory does not contain a Unity project, reference screenshots, a player build, or captured GPU timings.

## Create the scene

In Unity, run **Tools > Hybrid Lumen GI > Create Validation Scene Assets**. It creates a new `Assets/HybridLumenGIValidation/Run*/Validation.unity` and new materials, saves it, and closes it without replacing your open scene. Open the generated asset explicitly, assign a renderer containing the feature, then enter Play Mode. The moving occluder cycles through a doorway-sized area, including a pause at each endpoint.

The scene uses standard `Universal Render Pipeline/Lit` materials. It includes red and green walls, a white receiver, a black receiver, a metallic receiver, an emissive panel, a directional light, a point light, and a spot light. Disable baked lightmaps, ambient/light-probe contributions, other GI features, color grading, and automatic exposure when measuring the incremental contribution from this feature. Record both the unmodified URP frame and the feature's indirect-only view.

## Material capture contract

`Hidden/HybridLumenGI/SurfaceData`, pass 0, writes two single-sampled render targets:

| Target | RGB | Alpha | Clear value |
| --- | --- | --- | --- |
| 0 | Linear diffuse reflectance, including the metallic or specular energy split | Material occlusion | 0 |
| 1 | Linear emission | 1 for a captured surface | 0 |

Use `DrawingSettings.overrideShader`, not `overrideMaterial`, so the original material properties are available. Use only opaque `UniversalForward`, `UniversalForwardOnly`, or `UniversalGBuffer` renderers in a dedicated layer mask. A separate single-sampled depth target avoids attachment sample-count mismatches with an MSAA camera.

Coverage is controlled by `_AlphaClip`, `_Cutoff`, `_BaseColor.a`, and the base texture. When base-map alpha supplies smoothness, URP's color-alpha coverage convention is preserved. Basic map/tint, metallic and specular workflows, occlusion, and emission are captured. Smoothness itself is unnecessary for this diffuse-only buffer; the camera normal texture supplies the shading normal used by the gather stage.

The texture/enable semantics of standard Lit require `_METALLICSPECGLOSSMAP`, `_OCCLUSIONMAP`, and `_EMISSION`. The override shader includes these variants with `multi_compile` so that absent custom material assets do not cause `shader_feature` stripping. Validate original-material keyword propagation in the exact Unity editor **and** player version. If a version does not preserve those keyword states, explicit per-material capture materials are required before enabling textured capture in production. Merely sampling a default white metallic texture cannot reproduce the untextured metallic-slider path.

This capture shader is not a general Shader Graph evaluator. Exclude custom vertex displacement, detail layers, parallax, decals, clear coat, terrain, transparent surfaces, custom alpha logic, and materials with incompatible property conventions until a matching capture pass is implemented. A `UniversalForward` tag alone does not establish material compatibility. Validate layer membership as part of scene import. Override-shader rendering also needs a CPU draw-cost measurement; it is not evidence that SRP batching or GPU instancing behaves identically to the original pass.

## Required matrix

Record the actual result and evidence path for each row; do not mark rows passed from source inspection.

| Test | Expected result | Evidence |
| --- | --- | --- |
| Unity import and standalone build | No C# or shader errors; all used variants survive stripping | Editor log, player log |
| Black receiver | No reflected diffuse GI | Linear HDR pixel dump |
| Metallic=1 receiver | No diffuse GI; URP direct/specular remain intact | Indirect-only and final frame |
| Red/green wall | Corresponding color bounce on adjacent white geometry | Fixed-exposure comparison |
| Untextured vs white metallic texture | Slider/map behavior agrees with URP Lit semantics | Material test grid |
| Metallic/specular workflows | Correct diffuse energy split in each workflow | Material-buffer capture |
| Emission keyword disabled/enabled | Zero/nonzero emitted source contribution | Material-buffer capture |
| Occlusion disabled/enabled | Capture respects keyword and strength | Material-buffer capture |
| Alpha clip + smoothness alpha | Silhouette matches ordinary URP Lit | Depth/material overlay |
| Dark sealed scene | No synthetic ambient leak or self-sustaining GI | 300-frame HDR luminance series |
| Light color/intensity/off | Cache invalidates and converges without retaining stale illumination | 300-frame HDR luminance series |
| Dynamic door, move/remove emitter | History rejects newly visible surfaces; obsolete cache contribution disappears | Video and per-frame error plot |
| Camera translation/rotation | Static surfaces reuse reprojected history; disocclusions reject it | Confidence and history-age views |
| Camera cut/resize | History reset; no stale content or uninitialized pixels | Cut/resize script + capture |
| Two cameras and camera stack | No cross-camera history contamination | Frame Debugger capture |
| 1919×1079 and low render scale | No edge pixels omitted; safe dispatch bounds | Player screenshots |
| Scene load/unload and far-field boundary | No stale entries, missing coverage, or simultaneous near/HLOD double lighting | Streaming capture + cache stats |
| Hardware backend enabled/unsupported | Real backend dispatch on supported device; clear fallback on unsupported device | GPU capture and capability log |
| 30-minute runtime/domain reload | Stable memory and proper resource release | Memory Profiler comparison |

## Triangle surface-chart acceptance

The generated baseline scene does not by itself cover concave chart geometry. Add a U-shaped cavity, nested room walls, parallel stacked layers, disconnected coplanar islands, material/UV seams and thin triangles. Use **Tools > Hybrid Lumen GI > Bake Surface Charts** on readable static MeshRenderer sources and retain the asset, source mesh and bake diagnostics. Reopen the project before testing to exercise asset serialization and capture-mesh subassets. The capture mesh must draw only the triangles assigned to the selected chart, with their original vertex attributes and source-submesh material.

Inspect diffuse/emission/normal/position atlas textures and the anchor/cache buffers in a native GPU capture. Interior and overlapping-depth surfaces must retain their own charts and matching material samples. Each nonempty patch selects a covered texel inside its half-open cell; no reused page may keep an old anchor or owner. A baked chart owner needs covered, initialized lighting in **every required chart** before an HLOD readiness receipt can publish it. An empty required chart, partial capture, insufficient card capacity or obsolete source asset must keep the replacement warming. Diagnose fully alpha-clipped or subpixel charts explicitly; do not remove the coverage gate to make the switch pass. The six-view fallback has a weaker any-covered-page criterion and is not evidence of complete concave coverage.

Exercise source mesh edits and rebakes, content revision changes, nonuniform/negative transforms, material and MPB changes, card-capacity/grid resizing, multiple cameras, and HLOD transitions while GPU readback is pending. In-place source edits with unchanged vertex counts/bounds require `MarkDirty()`, followed by a chart rebake when content differs. Save diagnostic counters plus the actual atlas, anchor and readback evidence; aggregate ready-card counters alone cannot prove per-chart coverage or illumination convergence. These engine/GPU cases are currently unexecuted.

## Performance and visual gates

Choose target hardware, Unity/URP versions, graphics API, output resolution, internal resolution, target FPS, GI GPU budget, GI memory budget, and reference renderer before assigning thresholds. Measure warm and cold cache, rapid movement, streaming, and the worst-case light/geometry update rate. Report median, p95, and p99 GPU time over a repeatable workload; report persistent buffers, transient render targets, acceleration structures, and peak memory separately. Do not convert a ray-count cap into a claimed millisecond budget.

Compare linear HDR images with a sufficiently converged offline path-traced reference using matched diffuse materials, light units, and environment. Store exposure-independent RMSE and a luminance time series alongside visual crops of thin walls, contact boundaries, emissive sources, and disocclusions. A reference using different material BRDF/light normalization cannot validate energy conservation.

`node Tests/transport-reference.mjs` checks the mathematical normalization and bounded diffuse recursion used as an oracle. It does not execute the Unity shader or replace any row above.

## Baked mesh SDF runtime

The mesh SDF path reads the baker's RFloat voxel-center samples into a per-camera structured-buffer atlas. The default atlas cap is 2,097,152 floats (8 MiB), plus 128 bytes of metadata per scene slot. Readable source `Texture3D` assets retain their own CPU/GPU storage, which must be included separately in total memory accounting. A camera with no usable mesh SDF allocates only a dummy distance buffer. Identical asset references share voxel storage across instances. Transform changes update metadata without uploading the volume again; changes to the source texture's update counter invalidate its resident copy.

The default upload cap is 262,144 voxels (1 MiB) per `Prepare`, with rotating priority. One complete volume must fit the upload cap. Free ranges are reused and coalesced without an implicit full-atlas repack. Fragmentation or capacity pressure can retain an analytic fallback even when total free bytes exceed one requested contiguous allocation. Pending, failed, unreadable, oversized, mismatched-mesh, or unsupported deformed-mesh assets also retain the fallback. Only an uploaded volume with the exact scene slot's stable ID and revision replaces its analytic geometry.

The tracer intersects the transformed local bounds, manually samples trilinear voxel-center distances, subtracts the baked interpolation error during empty-space stepping, and refines near the surface with small voxel steps. Signed crossings receive bisection refinement. Gradients use an inverse-transpose normal transform; the empty-space scale is conservative under nonuniform scale and shear. A signed field uses a 0.025-smallest-voxel convergence threshold; an unsigned open shell uses 0.25 voxel. These are finite-resolution approximations. Thin features, grazing rays, open meshes and the bounded 8–128 step limit need explicit scene testing; exhausting the trace budget can miss geometry. The metadata validation and uploaded buffer bounds prevent an old slot from sampling an unrelated mesh's volume.

Validate rigid translation, rotation, nonuniform/negative scale, shear, two instances of the same asset, source-texture replacement, asset unload, budget reduction, allocation fragmentation, and signed/unsigned variants. Compare hit distance and normal with the original triangle mesh, especially at oblique angles and thin openings. The transport cache must sample actual represented surfaces when mesh geometry replaces a bounds proxy; six AABB centers alone cannot establish accurate mesh-surface lighting.

## Source basis

- [Unity DrawingSettings.overrideShader](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.DrawingSettings-overrideShader.html)
- [URP 17 LitInput source](https://github.com/Unity-Technologies/Graphics/blob/6000.0/staging/Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl)
- [URP 17 BRDF source](https://github.com/Unity-Technologies/Graphics/blob/6000.0/staging/Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl)
- [Unity shader variant retention](https://unity.com/blog/engine-platform/shader-variants-optimization-troubleshooting-tips)
