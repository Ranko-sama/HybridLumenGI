# HybridLumenGI

**当前本机可巡视入口：Release58；已构建产品来源为 `7e387a512cbb4355fd5f3d9f3c76282375f9cd3b`。** 后续提交的 HEAD 不自动成为该 EXE 的产品来源。当前继续本机开发，不需要朋友交付；四项目标与十条工作流仍以[完整原计划](Documentation/OriginalDevelopmentPlan.md)为准。

本机入口：[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease58/Start-LocalRelease.cmd>)。点击窗口后，WASD平移、Q/E升降、方向键转向、R复位、Esc退出；窗口默认常驻。一次普通 Release 构建及一次实际键盘巡视正常退出，原23条构建警告保留。移动、转向、松键和复位有执行层与Astra的画面观察；Pro58核对源码和记录，未独立读取图片。00–03启动暗窗口未合格判读，首可辨场景至退出58.307秒、首窗口至退出151.629秒；失焦护栏仅检查实现。见[巡视结果与限制](Documentation/ReviewBrief-LocalReleaseNavigation01.md)。640×360是运行配置，不是生产分辨率目标。

**最后一次HDR图像基线仍为Release54，来源 `a9292cb8c3c1bd86b64fdcb7888565bd7c957ec4`。** 58的窗口截图不替换54的HDR采集，也不补齐55–57各修复的原生触发条件。

Release54 已在 Unity6000.0.85f1 / URP17.0.4 / Windows x64 / Mono / DX12 / Linear / RTX2080Ti 完成普通 Release（BuildOptions.None）构建、静态120个真实相机/GI帧、一次末帧HDR采集及正常退出；112份产品来源与189项产物有清单，23条构建警告保留。见[当前图像结果与边界](Documentation/ReviewBrief-CurrentRepresentativeFinalImage01.md)、[实际预览图](LocalComparison/Review/current-representative-final-image-01/native-window/run/frame-0119.png)和[原始运行收据](LocalComparison/Review/current-representative-final-image-01/native-window/analysis.json)。该图来自首帧固定的HDR相机目标及既有预览映射，不是普通backbuffer像素证明。未采集的嵌套资源/退休字段默认零值不代表资源归零。

**已实现与已验证需要分开。** 当前产品还包括普通Surface的alpha/BRDF keyword一致性修复和稳定CPU发光面积/CDF复用；54的单张静态Additive图不补齐各功能的原生条件，也不认证整体画质、物理光照、性能、总显存或G0–G5。代码明确跳过非DX12/非Linear、非Base及立体相机；原生漫反射替换还有[限定条件](Documentation/NativeDiffuseComposition.md)。明确拒绝的配置与尚未验证的配置见[当前支持范围](Documentation/ProductionPlan.md#当前支持范围与证据层级)。目标分辨率/FPS、GI毫秒与显存预算仍待确定。

**历史证据保留各自来源。** Release44的300秒公开计账窗口对应5120a8c，见[旧版持续使用结果](Documentation/ReviewBrief-LocalReleaseSteadyUse01.md)，不升级为Release54稳态验收。更早的runtime-candidate-16功能/流式Player及后续软件/DXR图像、动态和资源专项仍可追溯，见[历史功能检查](Documentation/LocalRuntimeFunctionalAudit.md)与[完整推进表](Documentation/DevelopmentProgress.md)。旧失败、归档包和报告继续保留；朋友交付资料属于历史流程，不是当前使用前提。有限记录不代表UE5 Lumen等价或生产认证。

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
