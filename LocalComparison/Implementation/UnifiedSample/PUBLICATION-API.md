# 按相机查询 GI 发布状态

`publication-api.patch` 是隔离草稿，仅增加两个查询和实际 `Scene.Prepare` 的时间戳。未修改 Runtime、部署或运行 Unity；不覆盖同目录的后端偏好草稿。整合时应用 patch，不复制其他代理的 Feature 整文件。

## 实际来源链

- `HybridLumenGIRendererFeature.TransportPass.cameras` 按 Camera instance ID 保存 `CameraState`，并再次比较 Camera 对象身份。每个 state 独占 `scene`、`surfaceCache`、`sdf`、`readiness`。
- `HybridLumenGIScene.Prepare` 更新 `Data[slot].identity`：x 为 stable ID，y 为 revision，w=1 为 published，w=2 为 warming。`SelectAtomicGroups` 保留完整旧 published 集合，再预留整个目标集合；`ReadyToPublish` 要求目标全员的现有 slot/revision 和 geometry/material/lighting receipt 合格，才原子替换集合。
- 实际 Feature 的正向 readiness 生产者是 `HybridLumenGIHlodReadback.Record`：在 `CSUpdateCache` 之后安排 `CommandBuffer.RequestAsyncReadback`，回调检查 epoch、invalidation serial、atlas/card/layout generation、当前源及有效覆盖。合格 receipt 在随后一次 `Scene.Prepare` 被消费。Scene 的公共 `ReportReadiness` 本身不会建立 fence，不能单独据方法名声称 GPU 完成。
- 普通未分组 proxy 的 phase1 可以直接来自有预算的场景上传，**不是 HLOD 初始化证明**。`HlodReadiness.IsReady` 是历史初始化收据，不是持续光照收敛或最新所有纹理完成证书。
- 页 `Phase.Ready` 仅允许 `StreamedRepresentation` 获取完整 mesh/material/SDF/chart 资产并绑定；它的类注释明确表示绑定只是开始 GI warmup。页 Ready、资产绑定、组 published、最后使用者 GPU 完成是四个不同状态。

## API 与范围

```csharp
feature.TryGetPublication(camera, proxy, out HybridLumenGIScene.PublicationSnapshot proxyState);
feature.TryGetHlodPublication(camera, root, publishedList, targetList,
    out HybridLumenGIScene.HlodPublicationSnapshot groupState);
```

两接口只读既有相机状态；不调用 `GetCameraState`、Prepare、RefreshSignature、资源加载或 readback。主线程使用，组列表由调用方复用并每次清空，禁止传同一列表。列表无顺序保证。首次相机准备前、Feature 关闭、状态已驱逐、代理/组不存在或成员失效返回 false/Unknown。组返回 true 也可能 Unknown，表示已识别目标组但还没有任何可报告的已发布或 warming slot。

组查询先核对**全部**旧 published 成员的 proxy 对象、stable ID、revision、active 与 phase1，随后才暴露集合。不会将部分有效成员作为可见 LOD。`phase=Published` 可同时 `transitioning=true`：旧表示仍有效，新 target 正在准备。`targetWarmingCount`、`targetUnknownCount` 和 `capacityFallback` 保留预算等待/容量回退信息，不把未知目标宣布 ready。`target` 是此相机上次 Prepare 的实际目标集合，不是尚未加载的所有 authored detail 清单；样例仍必须独立保证其声明的完整 detail 集合已绑定，不能用目标个数反向证明资产组完整。

每个 snapshot 携带 `preparedEngineFrame`、`preparedWorkFrame`、`sceneRevision`。时间戳只在真实 Prepare 成功返回后写入，进入 Prepare 前清为 -1，避免异常沿用旧标签。workFrame 是准备当时的计数，可受既有重置影响；它不是完成帧。调用方应在指定相机本次渲染后读取，并检查期待的 engineFrame，不把旧相机快照当当前帧。查询不刷新后续源修改；对象/相机在准备后变更需要下一次真实准备。重复显式同 engine frame 渲染时，还应按调用方的实际渲染边界消费快照。

## 同一样例的可见 LOD 接线

样例只使用完整 `publishedList` 选择可见组；遇到 Unknown 保留原可见表示并记录等待。保持 proxy 与静态 MeshRenderer 启用：`HardwareBackend.Eligible`/`TryGetHitMaterialSource` 会拒绝 `renderer.enabled=false`，会使本应继续提供 GI 的表示失去 exact 几何资格。此样例可用 `MeshRenderer.forceRenderingOff` 隐藏普通 URP 可见性；当前 exact 后端和 SurfaceCache 的显式 DrawMesh 对静态 MeshRenderer 不据该标志拒绝来源。这是代码接线依据，尚不是原生可见 LOD 验收。

现有 streamed binding 会自动将 renderer.enabled 设 true，因此可见性控制必须覆盖绑定后的渲染边界，不能假设加载完成仍保持隐藏。不要禁用 proxy 作为视觉开关；这会把它移出 ActiveProxies。多相机的可见 LOD 仲裁不在此单样例 API 草稿范围内。

查询值不是卸载许可或 `ICompletion`。实际解绑仍由 `ResourceRetirement` 的所有相机 consumer 查询、末上下文提交和对应 GPU fence 控制；published/warming 表示仍被引用时继续保留。不能用 EndCamera、dispatch 已记录、页面 Ready 或此 API 的 true 代替 GPU 完成。

## 验证边界

`git apply --check --whitespace=error-all` 对真实产品基线通过。`publication-api-source.json` 固定相关来源与候选/patch 哈希。未运行新测试矩阵、编译、Unity、GPU 或改写任何冻结证据；完整 C# 编译和同一样例的有限运行由整合阶段统一执行。
