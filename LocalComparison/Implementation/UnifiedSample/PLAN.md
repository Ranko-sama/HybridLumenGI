# 同一样例 streaming / HLOD / 后端切换与资源计账

依据 `Documentation/OriginalDevelopmentPlan.md` 目标3/4、工作流8/10，以及 `DevelopmentProgress.md` 第4交付节点。交付基于现有 Validation 场景的一组 detail/root 普通使用入口，保留灯光、材质和相机来源；不创建规模测试框架。

1. **复用分页，补生成入口。** `Editor/HybridLumenGIAssetPageBuilder.cs` 已实现真实LZ4页、依赖重映射、CRC、预算声明及空绑定rig，但只有私有菜单函数。提取公开Editor API返回manifest/rig，复用当前自动生成的SDF/charts。在新建运行变体中清除原始强绑定；仅停用原对象仍持有mesh/material，不能宣称流出或节省显存。
2. **复用原子HLOD，补普通控制入口。** `Runtime/HybridLumenGIStreamedRepresentation.cs` 已有距离滞回、附加视点和完整组绑定；`HybridLumenGIScene.cs`/`HybridLumenGIHlodReadback.cs` 已有warming→published及超容量root回退。新增按相机/代理查询published/warming的窄只读入口，供样例协调近/远请求及可见表示。旧 `Assets/ComparisonHarness/Editor/StreamingAuditEditor.cs` 复制重合detail/root，绑定后两个Renderer可同时启用，不能直接升级为普通视觉LOD。实现时必须区分GI发布与URP可见性、避免重复几何；页Ready不是HLOD完成。多相机视觉LOD暂不扩展。
3. **公开后端偏好。** `LocalComparison/Harness/LocalReleaseBootstrap.cs` 当前反射写死DXR偏好。Feature新增读取requested偏好与setter，原位改变同一Settings实例；保留现有配置/实际后端切换时的history、readiness和GPU计时失效。样例同时显示requested与`CameraDiagnostics.hardwareBackend/exactSoftwareGeometry`，明确预算/支持导致的回退，不能把请求DXR显示成实际DXR。
4. **汇总既有计账。** 使用AssetPageStreaming的bundle/resident/IO/upload/retiring，Feature的屏幕/cache/SDF/软件几何/RTAS字段，以及ResourceRetirement的pending/owned/failed/unknown。全局RTAS和材质池只记一次；页预留、GPU估算、驱动高水位分别展示，不相加冒称总VRAM。复用Release JSONL和build/run/restore来源清单，不加新的探针框架。

最小有限运行只观察同一组“冷加载→近场detail→远场root→软件/DXR切换→离开释放”。留用要求绑定完整、发布无空组、实际后端可解释、计账与安全退休闭合；未覆盖或超时保留，不用图片近似或期望开关代替状态证据。没有总VRAM或生产性能结论。

复用41/59/60的附加视点能力、旧candidate-16流式/HLOD、27在途撤回、68冷启动回退及既有退出证据，不重跑旧矩阵。`HybridLumenGIChunkStreamer` 保留可选Additive入口，其安全卸载仍由应用`ReportUnloadSafe`授权；本节点不追加Additive IO流程。核心页状态机、HLOD选择和退休算法不预先重写，仅在整合出现可证反例时修正。
