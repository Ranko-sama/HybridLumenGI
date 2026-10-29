# HybridLumenGI

当前源码新增两项[颜色反弹与动态历史修复](Documentation/ReviewBrief-ColorBounceDynamicLimits01.md)：缓存连接的未知alpha覆盖不再被当成确定遮挡后重归一颜色，变化帧也始终遵守 `maxHistory=1`。两条实际HLSL消费路径已有定向WARP对照；本轮没有新Player，以下Release69尚不包含这两项修复，不能沿用其图像为新源码验收。

本机版本已整合两轮修复：[反射率夹取与动态历史](Documentation/ReviewBrief-ParallelColorDynamics01.md)、[普通Surface视差UV](Documentation/ReviewBrief-SurfaceParallaxUv01.md)，并将静态HDR环境Cube接入完整Feature。采用并行实现／参考准备与集中复审；原逐位失败及显式数值资格调整完整保留。

源码另已修复[HLOD近场冷启动的容量回退](Documentation/ReviewBrief-HlodColdStartRootFallback01.md)：细节组自身超容量且没有旧表示时，先按原就绪门控准备已有粗代理；细节恢复可容纳后仍可原子切换。这项通过实际CPU状态机对照，尚未进入下述Release67。

**当前本机入口：Release69；已构建产品来源为 `50b63c33683ba533f01c7119f6320ad80b4f2ec6`，新增示例接线另有冻结清单。** 后续HEAD不自动成为该EXE的产品来源。当前继续本机开发，不需要朋友交付；四项目标与十条工作流仍以[完整原计划](Documentation/OriginalDevelopmentPlan.md)为准。

当前入口：[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease69/Start-LocalRelease.cmd>)。空格启动／停止红绿格纹薄板形变，默认暂停，停下保持形状并让GI快照追上。WASD平移、Q/E升降、方向键转向、R只复位相机、Esc退出；默认常驻。一次真实256帧运行执行同一启停方法，运动中11次不同内容发布、最终完整来源一致、两张HDR及正常退出通过；本轮没有重复OS按键验收。见[用法](Documentation/ContinuousDeformationExample.md)及[结果与边界](Documentation/ReviewBrief-ContinuousDeformationUsage01.md)。

69累计一次双程序集预检、首次Unity构建准备失败、一次获准的资产查询修正构建及首次Player运行；23条构建警告保留。Astra和实际GPT-6 Pro均采用有限结果并查看原图。首相机回调等待2.938秒，不能与67的101.249秒直接比较为提速。当前两图为[运动结束](LocalComparison/Review/continuous-deformation-usage-01/build-correction/native-window/run/frame-0159.png)与[停稳](LocalComparison/Review/continuous-deformation-usage-01/build-correction/native-window/run/frame-0255.png)，保持同一最终可见姿态，不能作为完整动态画质真值。HLOD68源码已包含，不能据本场景推导HLOD原生验收。以下67等记录保留历史来源与回退入口。

历史67入口：[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease67/Start-LocalRelease.cmd>)。点击窗口后，WASD平移、Q/E升降、方向键转向、R复位、Esc退出；默认常驻。导航代码沿用58，本轮实际执行同EXE的有限HDR分支，没有重复键盘验收。一次Release构建及120目标相机帧采集正常退出，23条构建警告保留；**本次首帧等待101.249秒**，仍是实际使用限制。640×360是运行配置，不是生产分辨率目标。见[67结果与边界](Documentation/ReviewBrief-CurrentLocalRelease67.md)；[Release58](<I:/Unity test/Comparison/Builds/LocalRelease58/Start-LocalRelease.cmd>)及其[巡视证据](Documentation/ReviewBrief-LocalReleaseNavigation01.md)保留回退。

**历史静态Final HDR来自Release67／2fefc09。** [实际预览](LocalComparison/Review/current-local-release-67/native-window/run/frame-0119.png)与[原始运行结果](LocalComparison/Review/current-local-release-67/native-window/analysis.json)对应首帧固定HDR相机目标，不是普通backbuffer。新增输入为固定六面RGBAFloat工程环境，不能以它与54的亮度差证明算法改善。另有[62固定移灯观察](Documentation/ReviewBrief-LocalLightMoveResponse01.md)，来源7190c28，五份IndirectOnly HDR及保留原FAIL的binary32资格修正；有限动态证据不重新标为当前版本验收。

Release67在Unity6000.0.85f1／URP17.0.4／Windows x64／Mono／DX12／Linear／RTX2080Ti完成一次构建和一次末帧HDR采集。112产品源、189产物、实际Feature与Cube构建依赖、临时工程恢复均核对通过；Astra及实际Pro67有限采用，Pro也读取了PNG。未采集的资源／退休字段默认零不代表资源归零。旧[Release54图像](Documentation/ReviewBrief-CurrentRepresentativeFinalImage01.md)保留其a9292cb来源。

**已实现与已验证需要分开。** 单张静态Additive图不补齐各功能未触发的原生条件，也不认证整体画质、物理光照、动态质量、性能、总显存或G0–G5。代码明确跳过非DX12/非Linear、非Base及立体相机；原生漫反射替换还有[限定条件](Documentation/NativeDiffuseComposition.md)。明确拒绝的配置与尚未验证的配置见[当前支持范围](Documentation/ProductionPlan.md#当前支持范围与证据层级)。目标分辨率/FPS、GI毫秒与显存预算仍待确定。

**历史证据保留各自来源。** Release44的300秒公开计账窗口对应5120a8c，见[旧版持续使用结果](Documentation/ReviewBrief-LocalReleaseSteadyUse01.md)，不升级为Release54稳态验收。更早的runtime-candidate-16功能/流式Player及后续软件/DXR图像、动态和资源专项仍可追溯，见[历史功能检查](Documentation/LocalRuntimeFunctionalAudit.md)与[完整推进表](Documentation/DevelopmentProgress.md)。旧失败、归档包和报告继续保留；朋友交付资料属于历史流程，不是当前使用前提。有限记录不代表UE5 Lumen等价或生产认证。

Experimental Unity 6 / URP 17 diffuse light transport. The source includes baked triangle surface charts with a variable card pool, mesh SDF baking and residency, a stackless instance BVH, a global distance-field empty-space accelerator, patch irradiance caching, guided sampling, temporal reconstruction, and optional triangle DXR queries. Independent of VXGI.

An optional static linear HDR Cubemap supplies directional environment radiance to both indirect-light miss paths. Null keeps the constant environment; the Cube is borrowed and replaces that constant. See the [input contract](Documentation/EnvironmentRadiance.md), [63 native compute evidence](Documentation/ReviewBrief-StaticHdrEnvironmentCubemap01.md), and [67 full Feature integration](Documentation/ReviewBrief-CurrentLocalRelease67.md). Release67 contains this capability and a fixed six-face demonstration asset; its single static image does not quantify the Cube contribution or certify performance or physical accuracy.

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
