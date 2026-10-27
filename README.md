# HybridLumenGI

**当前源码：local-development-denoise-01，本机开发中。** 用户已取消当前朋友交付任务，继续在本机修复和验证。当前改动为短历史GI的空间方差补偿，见 [本机开发记录](Documentation/LocalDevelopment.md) 与 [本轮定向验证](Tests/local-development-validation-results.json)。不把冻结候选的Player结果当作当前源码重新构建的结果。

**上一冻结基线：runtime-candidate-16。** 该基线已在 Unity 6000.0.85f1 / URP 17.0.4 / Windows DX12 / RTX 2080 Ti 构建并运行，功能与流式 Player 各完成720帧、32张HDR、零采集错误。基于 integration-15，修复了编译展开、黑室缓存漏光、Unity API接线、发光keyword/HDR颜色、RGB24贴图拒绝、Player灯光API、资源页导出引用失效，以及HLOD返回近场的覆盖空洞。见 [基线运行范围](Documentation/LocalRuntimeFunctionalAudit.md) 和 [基线源码对应的运行摘要](Tests/runtime-validation-results.json)。历史交付包和记录保持不变。

The integration-15 offline report remains historical evidence for its source, not a new all-green run of this revision. This repair uses targeted existing regressions and actual Editor/Player captures; unchanged old/off/SDF evidence is reused. DXR ran in the Editor, while the final Player exercised exact software and streamed HLOD. Dynamic noise, thin-wall reference quality, shutdown resource-release warnings, GPU timing/peak VRAM and long-run production acceptance remain open. This is not UE5 Lumen equivalence or production certification.

Experimental Unity 6 / URP 17 diffuse light transport. The source includes baked triangle surface charts with a variable card pool, mesh SDF baking and residency, a stackless instance BVH, a global distance-field empty-space accelerator, patch irradiance caching, guided sampling, temporal reconstruction, and optional triangle DXR queries. Independent of VXGI.

HLOD groups stage geometry, material cards and lighting before atomic publication, with GPU readback checking cache initialization. Independent AssetBundle pages now load mesh, SDF, charts, materials and textures under dependency, IO, upload and residency quotas. Complete groups bind together and retire after all-camera context fences; the earlier additive-scene streamer remains available. Ordinary opaque/cutout URP Lit has default additive composition and an opt-in, restricted native diffuse replacement path.

Surface charts capture assigned source triangles, including internal surfaces. Static readable meshes use authored assets; `HybridLumenGIDeformedMesh` builds immutable skinning/readable-producer snapshots with matching SDF and charts under capture, worker and publication quotas. Old snapshots retire through GPU fences. Objects without charts retain the six-view approximation. Invalid/stale assets or insufficient complete-owner capacity are rejected; finite raster coverage still requires visual acceptance.

DXR and exact software triangles share original submesh/primitive identity, source-UV material evaluation, alpha coverage, Cull, normals and versioned chart bindings. Unknown coverage blocks visibility and cannot contribute trusted radiance. A chart supplies cached incoming irradiance; it does not replace the hit material. Exact software BVH tables and GPU buffers are reused while geometry is unchanged. Capacity/material failures retain the explicit SDF/analytic fallback.

Stable texture pages persist across frames/cameras. A changed source replaces only its page, with independent generations and reader fences. Eligible color data uses paired binary16 texels; alpha-test coverage inputs and unbounded formats retain float32 precision. Shared memory and per-frame copy quotas include pending/retiring resources; stable large pages upload progressively. Dynamic RenderTextures must fit a coherent current-frame capture. Record actual backend, page status and budget diagnostics. Spatial ray footprints do not certify visibility over a whole patch or complete angular filtering.

Direct-light injection respects shadow enable/strength, GameObject culling masks, and separate URP illumination/shadow rendering layers. Shadow queries filter candidates independently of ordinary GI visibility, including non-casters and two-sided hardware casters. Screen receivers carry exact integer layer masks alongside the material capture. These changes add 8 bytes per full-resolution pixel and 16 bytes per resident scene slot; the screen allocation budget includes that cost. Hard-shadow sampling does not reproduce soft shadows, shadowmask, cookies, or the full Lit receive-shadows contract.

Screen-history receipts bind full and GI dimensions, viewport and target identity. Camera matrices are published with successfully recorded history; reused native camera IDs cannot inherit another camera's state. Depth, motion, temporal lookup and upsampling share actual full-resolution sample centers. Optional `receiverObjectHistory` automatically enables CPU source tracking and adds an explicit identity draw, atomic overlap rejection, unknown-source masks and per-submesh generation/primitive matching. Previous-object transforms are accepted only for supported relative positive similarities. Changes belonging to other occluders remain hard rejections; only a proven receiver's own pose can be exempted. Identity failure or an insufficient identity budget retains affordable current-frame GI. This path is off by default and still needs Unity/Player raster, synchronization and device validation.

World material pages now require exact effective-property snapshots even when their compact hash is unchanged. Renderer and per-material MPB precedence, keyword/texture/sampler changes and source raster Cull are checked separately. RenderTexture sources can still be captured, but cannot reuse an unproven source receipt; producers of other GPU-written textures must report updates. These CPU checks do not establish the contents used by a Unity draw or GPU synchronization.

GPU emission statistics guide directions alongside cosine and cache-guide sampling. Exact prepared emitter triangles additionally supply one area sample per direction sample, paired through full-density MIS. Only endpoint Le receives the direction MIS weight; reflected/cache radiance retains its original estimator. The same screen/world nearest-hit partition suppresses duplicate contributions. Unlisted or approximate endpoints retain their original direction estimate.

Optional GPU feedback adjusts patch, capture and brick update quotas within static limits. It is disabled by default (`adaptiveGpuBudget=false`, `targetGpuMilliseconds=0`). An optional Windows x64 DX12 plugin provides submission identities and fence-gated readback through 128 recyclable slots; when unavailable, the feature falls back to Recorder's 32 lifetime channels, then static quotas if feedback is unavailable. Native ABI1 now extends its receiver-capture interval through the optional identity chain. Recorder uses three or seven locally paired scopes to cover the same scheduled work. A failed Recorder marker command disables that channel's feedback; rendering continues. The source package does not automatically install the DLL. See [GPU budgets](Documentation/GpuBudget.md) and [native timing](Documentation/NativeGpuTiming.md).

**Not UE5 Lumen equivalent or production certified.** The current integration targets DX12, Linear color space and Render Graph. The local Editor evidence is limited to the documented scene, settings and device; it does not establish general rendered correctness or target-device timing and memory budgets. Native timing has separate C++ and D3D12 WARP tests with a simulated Unity host; these do not validate its Unity integration or physical GPU measurements. Follow the handoff and validation documents before using this candidate in a project.

- [Architecture and production plan](Documentation/ProductionPlan.md)
- [Historical task-baseline audit](Documentation/TaskBaselineAudit-2026-10-27.md)
- [Import and implementation](Documentation/Implementation.md)
- [Friend handoff and evidence checklist](Documentation/FriendHandoff.md)
- [Geometry provenance, normals and history contracts](Documentation/GeometryHistoryContracts.md)
- [Direct-light, receiver-layer and shadow-query contracts](Documentation/DirectLighting.md)
- [Papers and official sources](Documentation/Research.md)
- [Community source audit and licenses](Documentation/CommunitySourceAudit.md)
- [World surface cache](Documentation/SurfaceCache.md)
- [Emissive directional sampling and paired area NEE](Documentation/EmissiveSampling.md)
- [Budgeted deformation snapshots](Documentation/DeformedGeometry.md)
- [Independent asset pages and retirement](Documentation/IndependentAssetPages.md)
- [Instance BVH and cache scheduling](Documentation/SceneBvh.md)
- [Global SDF lower bounds](Documentation/GlobalSdf.md)
- [Experimental GPU timing feedback and remaining release gates](Documentation/GpuBudget.md)
- [Optional native DX12 timestamp backend, build and validation scope](Documentation/NativeGpuTiming.md)
- [HLOD transactions and asynchronous chunks](Documentation/HlodStreaming.md)
- [Stock Lit native diffuse composition](Documentation/NativeDiffuseComposition.md)
- [Runtime acceptance tests](Documentation/Validation.md)
- [Fixed scene sequence, linear HDR capture and comparison](Documentation/ValidationSequence.md)
- [Offline validation evidence](Documentation/OfflineValidation.md)
