# 同场景普通运行样例

当前普通入口、快捷键和画质／性能结论统一见[首页](../../../README.md)。本文保留生成/API约束及早期接线来源；下述Release74／75叙述属于历史阶段，不代表当前版本需要重新整合。

公开生成路径现已接入 `HybridLumenGIUnifiedSampleInteraction`：菜单/API 生成的场景自带导航，标准 Validation 场景复用其门与灯引用，并绑定未流出的 Red wall。一般作者场景没有这些事件输入时只显示可用操作，不阻断导航；若 Red wall 被选为流式源，其清空后的壳对象不会接换色按钮。本机构建入口复用生成组件，不再另挂第二份。此次接线已通过受影响 C# 编译，未重跑 Unity 菜单生成/图像验收；已发布 Release74 保持其原构建来源。

普通操作：WASD/QE 平移、方向键转向、1/R 近景、2 远景、3 离开、4/5 软件/DXR、B 释放/重载、F1 隐藏面板。标准 Validation 输入存在时另有 C 换墙色、L 灯开关、M 门运动和空格形变启停。

2026-10-30 整合状态：三个 API 与两个源已进入产品；unified-sample-02 完成真实冷加载、近远表示、软件/DXR 偏好、停用释放、重启及离开释放，独立核验通过。以下保留初稿设计说明，初稿中“未部署/未运行”的叙述只对应当时的隔离编译阶段；该专项证据见 [结果](../../../Documentation/ReviewBrief-UnifiedSample02.md)。普通可运行版本已整合，单相机/简单静态组等范围不变。

这两个新增源复用现有分页、HLOD 初始化/原子发布、后端选择和 GPU 退休实现：

- `Runtime/HybridLumenGIUnifiedSample.cs`：单相机普通控制、可见表示、资源账目。
- `Editor/HybridLumenGIUnifiedSampleBuilder.cs`：保存独立场景副本，生成 exact aggregate 和真实 AssetBundle 页。

以下为历史开发接线记录，当前产品已整合，使用时无需应用补丁或复制草稿。早期接线曾应用 `backend-preference.patch`、`publication-api.patch`、`asset-page-builder-api.patch`，再放入这两个新源。不要将较早的整个 Feature 草稿覆盖当前产品文件。最终 `sample-compile-02/report.json` 是完整 Runtime/Editor 源加两个新样例文件的隔离分程序集编译收据，三个 API 在主代理当前源中已整合，编译器只检查 reverse applicability 而不重复应用。保留的 `sample-compile-01/report.json` 为生命周期审查修正前的首轮编译。未部署、运行 Unity、构建 bundle 或声明原生验收通过。

## 生成及使用

打开已保存且无未保存修改的原 Validation 场景，保持该场景 active。在同一场景中选择至少两个普通静态代理，例如 White/Metal/Black 三个 receiver，执行 `Tools/Hybrid Lumen GI/Create Unified Sample From Selected Static Proxies`。菜单要求一个 enabled camera，并从该相机实际使用的Universal Renderer Data解析唯一启用的GI Feature；无关已加载资产不参与选择。自动化可显式调用：

```csharp
HybridLumenGIUnifiedSampleBuilder.Result result = HybridLumenGIUnifiedSampleBuilder.CreateVariant(
    authoringScene, camera, feature, selectedDetailProxies,
    "Assets/MyUnifiedSample/NewRun",
    "Assets/StreamingAssets/MyUnifiedSample/NewRun");
// result.ScenePath 和 result.Manifest；作者场景仍保持打开，生成的副本已保存并关闭。
```

两个目录必须全新、不重叠，不接受已存在目录/孤立 meta、路径跳转或 reparse 点。接口先验证输入，保留失败时的新目录供检查，不清理既有资产。源场景必须已保存，生成器只修改 `UnifiedSample.unity` 副本。副本停用原有限验证 Sequence/Motion，保持同场景静止状态，灯光、材质、其它物体和相机配置继续来源于作者场景。

打开生成场景，或让普通 Player 的场景列表指向它。所有流式目的对象起始为零 mesh/material/SDF/chart 绑定。相机处于原作者近景位置，页冷加载后才可发布完整 details。按钮提供 Near、Far、Leave、Software、Prefer DXR 和单次 JSON 账目日志。Near/Far 相机位置以实际源 bounds 和当前 Feature near/far 设置生成；不要在运行期间另外修改这两个距离，修改后应重新生成变体。初始 Near 需要作者相机位于 nearDistance 的 80% 以内。

`Prefer DXR` 只表达偏好；实际后端从该相机当前诊断显示，预算/支持导致的软件回退保留。软件若未使用 exact geometry，会明确显示 SDF/analytic。按钮不关闭 GI，也不调用 Create/Dispose 重建 Feature。

## 表示及资产所有权

aggregate 通过 Unity `Mesh.CombineMeshes` 保留每个原 submesh 的三角形和材质槽，并复用既有 32³ SDF 与 surface chart Bake。它减少 renderer 个数，不减少三角形数；没有新的简化算法或质量结论。细节与 aggregate 有独立几何/SDF/chart 页，公用材质依赖仍共享。

当前有限生成范围是无已有 HLOD 关系、非 prefab、无自定义组件/动画祖先、正行列式可读静态三角 MeshRenderer、URP Lit、无 MPB/烘焙 lightmap 的简单对象。有效 light/reflection probes 和环境 reflection 被拒绝，避免 aggregate 采样位置改变这些输入。源 SDF/chart 必须已绑定，renderer/proxy 光照策略需一致。不满足条件明确拒绝，不修改材质或伪造支持。

运行变体将**所选源对象**和临时 aggregate 源的 mesh、materials、SDF、charts、proxy source references 及 MeshCollider mesh 清空；作者场景和磁盘原资产保留。Export 另行克隆的 bundle 资产可独立释放。场景中未选择的物体继续非流式，可能仍使用作者 mesh/material，不能据此宣称整个场景或全部显存已流出。生成资产原件不是 Resources 资产，manifest 只保存页描述；Player 构建应使用该运行变体而非同时加载作者场景。

绑定与发布分开处理：所有 authored detail 和 root 页绑定齐全之前，控制器在 LateUpdate 保持 detail proxy 不参与 Scene.Prepare，防止单个 detail 提前构成部分组。资产绑定后仍等实际 HLOD 初始化/readback 与 published 集合。只接受完整 root 或完整 authored detail 集合；Unknown/不完整发布保留仍绑定的前一可见组并报告等待。

每次指定相机 endCamera 边界读取真实 preparedEngineFrame 和发布状态，决定下一相机帧的 URP 可见表示。使用 `forceRenderingOff`，保持静态 renderer/proxy 能作为 GI exact geometry / 显式 surface capture 来源；不会用 renderer.enabled 当视觉开关。初次无发布时不可见。此处不是相机 culling 前的当帧发布 hook，不承诺 GI/URP 在同一帧中途无过渡差异。

相机开始渲染时还会按它的实际位置复核组的可见距离。越过 `farDistance` 后，上次发布的完整表示立即退出本帧提交。处于 `farDistance` 到 `farDistance + 5` 的加载带内时，页和成员可以继续绑定，返回域内仍按完整组的发布规则显示。

可见集合额外注册为普通 URP retirement consumer。新 root/detail 发布后才撤销旧视觉引用；最终解绑、全相机依赖判断和 GPU fence 仍由现有 ResourceRetirement 执行。控制器不调用 ReportUnloadSafe，不构造“已完成”票据。Leave 将相机移出 far domain 并撤销页需求，场景已不选择这些代理后才允许现有退休链释放。Unknown 不按超时强制释放。单独停用控制器会隐藏并禁用本样例 proxy，撤销新读者，仍交既有退休链处理；重新启用时恢复已绑定 root，并重新等待完整 detail 集合/发布，不直接恢复旧可见集合。

这是单 enabled Game camera 样例；发现第二个 Game camera 时隐藏组并报告 unsupported。SceneView/反射/用户自定义显式渲染的 renderer-wide 可见性仲裁不属于本样例，Player 使用范围为单相机。重复手工 render 或修改源对象需另行定义渲染边界，不能借本样例作并发证明。

## 计账及后续一次整合观察

`CaptureLedger()` / `LogLedger()` 分列页面 resident/bundle/IO-inflight 估计、最近一次页 Step 的 IO/upload/operation 启动量与预算等待、ready/loading/releasing/failed 页、lease、组预算等待；`cameraGi` 原样保留此相机 GI 资源字段、实际后端及全局 RTAS/材质池字段（只有一份，不对多相机相加）；retirement pending/owned/failed/unknown 独立列出。Step 计数会被下次 Step 清零，不是累计量，也不保证和相机帧一一对应。没有“总 VRAM”相加，驱动高水位也不当作实时已分配值。诊断按现有 camera name 查找，名称重复则明确 unknown。数据为 CPU 账目，不是 GPU 完成票据或性能测量。

根整合后只需同一实例依次观察冷加载→近景完整 details→远景 root→软件/DXR 偏好切换→Leave 后页与退休收尾。必须看到完整绑定、有效 published 集合和实际后端；未知/失败/未完成保持原样，不用图片、开关状态或延时替代。既有 HLOD/附加视点/退出矩阵不重复；本草稿没有新增大规模验证框架。
