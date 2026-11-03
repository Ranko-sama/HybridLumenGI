# Validation and release evidence

The generated scene and mathematical checks are test inputs, not evidence that every image-quality, hardware or performance requirement has passed. This repository is the source package rather than a standalone Unity project. The development machine has a Unity project at `I:/Unity test/Project`, local Player builds, HDR captures and limited GPU observations. Use the [current runnable entry](../README.md), [progress and evidence](DevelopmentProgress.md) and [production gates](ProductionPlan.md) for their actual versions and scope; local binaries are not embedded in this source package.

The matrix below retains the original acceptance requirements. Scoped results refer to their recorded scenes and versions. The agreed starting target on the development machine is 960×540 at 30 FPS, with p95 of the three GI intervals summed per frame at most 25 ms and a sampled process-local memory peak at most 1 GiB. Nonlocal memory is reported separately. [Budget and workload scope](GpuBudget.md)

## Create the scene

In Unity, run **Tools > Hybrid Lumen GI > Create Validation Scene Assets**. It creates a new `Assets/HybridLumenGIValidation/Run*/Validation.unity` and new materials, saves it, and closes it without replacing your open scene. Open the generated asset explicitly, assign a renderer containing the feature, then enter Play Mode. The moving occluder cycles through a doorway-sized area, including a pause at each endpoint.

The scene uses standard `Universal Render Pipeline/Lit` materials. It includes red and green walls, a white receiver, a black receiver, a metallic receiver, an emissive panel, a directional light, a point light, and a spot light. Disable baked lightmaps, ambient/light-probe contributions, other GI features, color grading, and automatic exposure when measuring the incremental contribution from this feature. Record both the unmodified URP frame and the feature's indirect-only view.

## Material capture contract

The ordinary `Hidden/HybridLumenGI/SurfaceData`, pass 0, writes three single-sampled render targets:

| Target | RGB | Alpha | Clear value |
| --- | --- | --- | --- |
| 0 | Linear diffuse reflectance, including the metallic or specular energy split | Material occlusion | 0 |
| 1 | Linear emission | Signed material-validity marker, ordinary magnitude 1; sign carries receive-shadows policy | 0 |
| 2 (`R32G32_UInt`) | GameObject layer bit and Renderer rendering-layer mask | Not an RGBA target | uint2(0,0) |

Use the existing screen-material helpers to decode validity and receive-shadows policy: `abs(alpha)>0.5` identifies captured material, and a negative marker is not unknown. The separate native-diffuse replacement capture uses magnitude `1 + materialAO`; this is not the world-card alpha layout. See [direct-light policies](DirectLighting.md) and [native diffuse composition](NativeDiffuseComposition.md).

Use `DrawingSettings.overrideShader`, not `overrideMaterial`, so the original material properties are available. Use only opaque `UniversalForward`, `UniversalForwardOnly`, or `UniversalGBuffer` renderers in a dedicated layer mask. A separate single-sampled depth target avoids attachment sample-count mismatches with an MSAA camera.

Coverage follows the compiled `_ALPHATEST_ON` and `_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A` variants, with `_Cutoff`, tint and texture alpha evaluated according to those variants. Numeric `_AlphaClip` or smoothness-channel values, including MPB overrides, do not switch shader variants. `_SPECULAR_SETUP` selects the diffuse energy split; metallic/specular maps, occlusion and emission retain their keyword-dependent paths. See the finite [alpha](ReviewBrief-SurfaceAlphaKeywordParity01.md) and [workflow](ReviewBrief-SurfaceWorkflowKeywordParity01.md) results. Smoothness is not itself stored in this diffuse buffer; the camera normal texture supplies the gather shading normal.

The texture/enable semantics of standard Lit require `_METALLICSPECGLOSSMAP`, `_OCCLUSIONMAP`, and `_EMISSION`. The override shader includes these variants with `multi_compile` so that absent custom material assets do not cause `shader_feature` stripping. Validate original-material keyword propagation in the exact Unity editor **and** player version. If a version does not preserve those keyword states, explicit per-material capture materials are required before enabling textured capture in production. Merely sampling a default white metallic texture cannot reproduce the untextured metallic-slider path.

Ordinary screen capture includes stock Lit detail albedo (`_DETAIL_MULX2` / `_DETAIL_SCALED`) and camera-view tangent-space parallax UV. The [parallax result](ReviewBrief-SurfaceParallaxUv01.md) retains its original failed bitwise control and subsequent finite qualification; it is not a complete native keyword/coverage certification. World-card capture has its own card-view material evaluation. These UV operations do not displace geometry, and the optional receiver identity/history path still rejects parallax coverage. Do not equate screen capture, world-card sampling and identity eligibility; see [surface cache](SurfaceCache.md) and [geometry/history contracts](GeometryHistoryContracts.md).

This capture shader is not a general Shader Graph evaluator. Custom vertex displacement, decals, clear coat, terrain, transparency, custom alpha logic and incompatible property conventions remain outside this ordinary capture contract unless a matching path is provided. A `UniversalForward` tag alone does not establish material compatibility. Validate layer membership as part of scene import. Override-shader rendering also needs CPU draw-cost evidence; material evaluation does not prove equivalent SRP batching or GPU instancing.

## Required matrix

Record the actual result and evidence path for each row; do not mark rows passed from source inspection.

| Test | Expected result | Evidence |
| --- | --- | --- |
| Unity import and standalone build | No C# or shader errors; all used variants survive stripping | Editor log, player log |
| Black receiver | No reflected diffuse GI | Linear HDR pixel dump. [V209 frame 119, black receiver](../LocalComparison/Review/zero-diffuse-composite-v209/result.md). All 473 paired interior samples kept the same linear RGB across additive composition. |
| Open white furnace | Under uniform unit incident radiance, a unit diffuse receiver with unit AO and intensity should have unit indirect outgoing RGB | [Release99 ordinary linear HDR and analytic comparison](../LocalComparison/Review/white-furnace-ordinary-01/result.md). Central 64×64 mean 0.99902347 per channel. Applies to the unobstructed receiver and this configuration. |
| Metallic=1 receiver | No diffuse GI; URP direct/specular remain intact | Indirect-only and final frame. Available [V209 frame 119 composite comparison](../LocalComparison/Review/zero-diffuse-composite-v209/result.md) shows nonzero native color and zero RGB change at all 298 metallic interior samples. Direct and specular terms were observed together. |
| Red/green wall | Corresponding color bounce on adjacent white geometry | Fixed-exposure comparison |
| Untextured vs white metallic texture | Slider/map behavior agrees with URP Lit semantics | [One ordinary Win64 Player grid](../LocalComparison/Review/player-material-workflow-01/result.md): metallic .5, a linear Point/no-mip map with white/128 regions; captured diffuse and actual outgoing contribution match independent URP/unit-environment expectations. Fixed input scope, not world-hit qualification. |
| Metallic/specular workflows | Correct diffuse energy split in each workflow | [The same Player grid](../LocalComparison/Review/player-material-workflow-01/result.md) includes specular shader-space MPB .25 and white/64 map regions. Actual capture/outgoing and the used variants passed this fixed contract; arbitrary author colors, other material combinations and DXR remain outside it. |
| Emission keyword disabled/enabled | Zero/nonzero emitted source contribution | Material-buffer capture |
| Occlusion disabled/enabled | Capture respects keyword and strength | Material-buffer capture |
| Alpha clip + smoothness alpha | Silhouette matches ordinary URP Lit | [One ordinary Additive cutout input](../LocalComparison/Review/ordinary-cutout-coverage-01/result.md): native camera depth and GI capture depth agreed at every pixel in the predefined interior, including internal alpha edges; holes exposed the blue background. Limited to 128×128 and runtime `_AlphaToMask=0`. Smoothness-alpha combinations, author-default flag 1, MSAA, native replacement and Player remain unqualified. |
| Dark sealed scene | No synthetic ambient leak or self-sustaining GI | 300-frame HDR luminance series |
| Light color/intensity/off | Cache invalidates and converges without retaining stale illumination | 300-frame HDR luminance series |
| Dynamic door, move/remove emitter | History rejects newly visible surfaces; obsolete cache contribution disappears | Video and per-frame error plot |
| Camera translation/rotation | Static surfaces reuse reprojected history; disocclusions reject it | Confidence and history-age views |
| Camera cut/resize | History reset; no stale content or uninitialized pixels | Cut/resize script + capture |
| Two cameras and camera stack | No cross-camera history contamination | Frame Debugger capture |
| 1919×1079 and low render scale | No edge pixels omitted; safe dispatch bounds | Player screenshots |
| Scene load/unload and far-field boundary | No stale entries, missing coverage, or simultaneous near/HLOD double lighting | Streaming capture + cache stats |
| Hardware backend enabled/unsupported | Real backend dispatch on supported device; clear fallback on unsupported device | GPU capture and capability log |
| 30-minute runtime/domain reload | Stable memory and proper resource release | [Release100 streaming workload and separate before/after Editor Memory Profiler snapshots](../LocalComparison/Review/streaming-sustained-30m-01/result.md). The Player recovered after every return. Under default Editor reload, both retirement hosts and their components were released after the fix. The snapshots cover named native objects. |

## Triangle surface-chart acceptance

The generated baseline scene does not by itself cover concave chart geometry. Add a U-shaped cavity, nested room walls, parallel stacked layers, disconnected coplanar islands, material/UV seams and thin triangles. Use **Tools > Hybrid Lumen GI > Bake Surface Charts** on readable static MeshRenderer sources and retain the asset, source mesh and bake diagnostics. Reopen the project before testing to exercise asset serialization and capture-mesh subassets. The capture mesh must draw only the triangles assigned to the selected chart, with their original vertex attributes and source-submesh material.

Inspect diffuse/emission/normal/position atlas textures and the anchor/cache buffers in a native GPU capture. Interior and overlapping-depth surfaces must retain their own charts and matching material samples. Each nonempty patch selects a covered texel inside its half-open cell; no reused page may keep an old anchor or owner. A baked chart owner needs covered, initialized lighting in **every required chart** before an HLOD readiness receipt can publish it. An empty required chart, partial capture, insufficient card capacity or obsolete source asset must keep the replacement warming. Diagnose fully alpha-clipped or subpixel charts explicitly; do not remove the coverage gate to make the switch pass. The six-view fallback has a weaker any-covered-page criterion and is not evidence of complete concave coverage.

Exercise source mesh edits and rebakes, content revision changes, nonuniform/negative transforms, material and MPB changes, card-capacity/grid resizing, multiple cameras, and HLOD transitions while GPU readback is pending. In-place source edits with unchanged vertex counts/bounds require `MarkDirty()`, followed by a chart rebake when content differs. Save diagnostic counters plus the actual atlas, anchor and readback evidence; aggregate ready-card counters alone cannot prove per-chart coverage or illumination convergence. Some engine cases now have limited evidence, including [slot material propagation](DevelopmentProgress.md), [ordinary readable-mesh deformation](ReviewBrief-ContinuousDeformationUsage01.md) and [real Skinned use](../LocalComparison/Review/skinned-unified-usage-01/result.md). Their specific inputs do not close this entire geometry/chart matrix; other cases remain open in the progress record.

## Performance and visual gates

Choose target hardware, Unity/URP versions, graphics API, output resolution, internal resolution, target FPS, GI GPU budget, GI memory budget, and reference renderer before assigning thresholds. Measure warm and cold cache, rapid movement, streaming, and the worst-case light/geometry update rate. Report median, p95, and p99 GPU time over a repeatable workload; report persistent buffers, transient render targets, acceleration structures, and peak memory separately. Do not convert a ray-count cap into a claimed millisecond budget.

Compare linear HDR images with a sufficiently converged offline path-traced reference using matched diffuse materials, light units, and environment. Store exposure-independent RMSE and a luminance time series alongside visual crops of thin walls, contact boundaries, emissive sources, and disocclusions. A reference using different material BRDF/light normalization cannot validate energy conservation.

`node Tests/transport-reference.mjs` checks the mathematical normalization and bounded diffuse recursion used as an oracle. It does not execute the Unity shader or replace any row above.

## Baked mesh SDF runtime

The mesh SDF path reads the baker's RFloat voxel-center samples into a per-camera structured-buffer atlas. The default atlas cap is 2,097,152 floats (8 MiB), plus 128 bytes of metadata per scene slot. Readable source `Texture3D` assets retain their own CPU/GPU storage, which must be included separately in total memory accounting. A camera with no usable mesh SDF allocates only a dummy distance buffer. Identical asset references share voxel storage across instances. Transform changes update metadata without uploading the volume again; changes to the source texture's update counter invalidate its resident copy.

The default upload cap is 262,144 voxels (1 MiB) per `Prepare`, with rotating priority. One complete volume must fit the upload cap; this is not incremental slice upload. Free ranges are reused and coalesced without an implicit full-atlas repack. Fragmentation or capacity pressure can retain an analytic fallback even when total free bytes exceed one requested contiguous allocation. Pending, failed, unreadable, oversized or mismatched-mesh assets also retain fallback. A published `DeformedMesh` snapshot can supply its matching mesh/SDF/charts; arbitrary deformation without such a snapshot is not thereby supported. Admission checks the current readable mesh, source fingerprint/version and asset match as well as slot identity/revision. See [SDF residency](SdfAtlasResidency.md) and [deformed geometry](DeformedGeometry.md).

The tracer intersects the transformed local bounds, manually samples trilinear voxel-center distances, subtracts the baked interpolation error during empty-space stepping, and refines near the surface with small voxel steps. Signed crossings receive bisection refinement. Gradients use an inverse-transpose normal transform; the empty-space scale is conservative under nonuniform scale and shear. A signed field uses a 0.025-smallest-voxel convergence threshold; an unsigned open shell uses 0.25 voxel. These remain finite-resolution approximations. Thin features, grazing rays, open meshes and the bounded 8–128 step limit still need scoped scene evidence. Exhaustion before completing the interval returns unresolved/material-unknown, which cannot become a trusted miss, environment contribution or measured black; it can reduce valid measurement coverage. The [finite query-completion result](ReviewBrief-SdfQueryCompletion01.md) is not full native geometry acceptance. Metadata and uploaded buffer bounds prevent an old slot from sampling an unrelated volume. [Global SDF](GlobalSdf.md) is a conservative empty-region accelerator: unknown pages are not empty-space evidence, and final hits still use detail queries.

Validate rigid translation, rotation, nonuniform/negative scale, shear, two instances of the same asset, source-texture replacement, asset unload, budget reduction, allocation fragmentation, and signed/unsigned variants. Compare hit distance and normal with the original triangle mesh, especially at oblique angles and thin openings. The current surface path uses authored triangle charts, or an explicit six-view fallback when charts are absent. Each patch selects an actually covered texel within its cell; empty cells are cleared rather than represented by six AABB centers. This implementation does not establish complete arbitrary concave/thin-surface coverage; retain the chart acceptance requirements above.

## Source basis

- [Unity DrawingSettings.overrideShader](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.DrawingSettings-overrideShader.html)
- [URP 17 LitInput source](https://github.com/Unity-Technologies/Graphics/blob/6000.0/staging/Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl)
- [URP 17 BRDF source](https://github.com/Unity-Technologies/Graphics/blob/6000.0/staging/Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl)
- [Unity shader variant retention](https://unity.com/blog/engine-platform/shader-variants-optimization-troubleshooting-tips)
