# HybridLumenGI

Unity 6 / URP 17 的实验性漫反射 GI。包含真实网格 SDF、表面材质与世界光照缓存、精确软件三角查询、可选 DXR、时域重建、形变快照和分页/HLOD。当前仍在开发，不宣称 UE5 Lumen 等价或生产验收完成。

**当前本机入口：[启动统一交互 Release78](<I:/Unity test/Comparison/Builds/LocalRelease78/Start-LocalRelease.cmd>)。** 同一场景提供导航、分页/HLOD、软件/DXR 偏好、换色、灯光、门和形变操作；新增可手动开启的进程显存观察，默认关闭。该路径属于当前开发机，其他工程请按下文集成或构建。

Release78 新增[按来源分离的缓存关灯响应](LocalComparison/Review/cache-source-separation-01/result.md)：当前上传的解析灯表为空时，移除其旧多跳贡献，保留自发光／环境贡献。沿用统一交互及默认关闭的[驱动进程显存观察](Documentation/GpuBudget.md#驱动层进程显存观察)，保留此前屏幕历史、缓存首次可信更新和面积光冗余计算修复。[有限成本结果](LocalComparison/Review/screen-endpoint-only-01/result.md)来自 Release76 的固定配置，仅覆盖三个 GI 区间，不代表 Release78 全应用帧率或生产放行。后续源码修改不会自动更新 EXE。

## 使用统一示例

点击窗口后操作：

| 操作 | 按键 |
| --- | --- |
| 平移／升降／转向 | WASD ／ Q、E ／ 方向键 |
| 近景／远景／离开分页范围 | 1 或 R ／ 2 ／ 3 |
| 软件／DXR 偏好 | 4 ／ 5 |
| 墙面换色／灯光开关／门运动 | C ／ L ／ M |
| 形变启停／分页组释放与重载 | 空格 ／ B |
| 隐藏面板／退出 | F1 ／ Esc |

实际后端以面板诊断为准，选择 DXR 偏好不保证硬件路径被采用。关灯仍保留发光面；停止形变后，异步 GI 快照可能继续追上可见网格。当前窗口为 960×540，不是生产分辨率目标。

点击面板的 **Memory: off** 开启本进程 local/nonlocal 显存用量、OS预算及采样峰值；**Log ledger** 同时导出到Player日志。缺失或旧原生DLL会显示不可用，不影响GI。数据不是GI独占、整机用量或绝对瞬时峰值，也不改变更新配额。

从自己的场景生成示例：保存场景，选择至少两个已绑定 SDF 和 surface charts 的静态 Proxy，执行 **Tools > Hybrid Lumen GI > Create Unified Sample From Selected Static Proxies**。菜单要求一个启用相机，并从该相机实际选择的 Universal Renderer Data 中解析唯一启用的 GI Feature；无关已加载资产不参与选择。显式 `CreateVariant` 仍可使用。生成器保留作者场景，创建独立变体与资源页；静态网格、材质及 HLOD 限制见[统一示例说明](Documentation/ReviewBrief-UnifiedSample02.md)。菜单修复已有 Editor 编译依据，尚未重新生成场景。

## 当前画质结论

[打开同曝光对照图与曲线](LocalComparison/Review/dynamic-picture-comparison-01/index.html) · [阅读四项结论及适用范围](LocalComparison/Review/dynamic-picture-comparison-01/report.md) · [Release76关灯基线](LocalComparison/Review/current-lightoff-prefix-01/result.md) · [Release78缓存改进对照](LocalComparison/Review/cache-source-separation-01/result.md)

| 问题 | 当前结论 |
| --- | --- |
| 颜色误差 | 旧同源独立参考显示亮灯间接光偏暗、关灯后仍偏亮；参考带有采样噪声及模型近似，偏差不能直接等同精确产品误差或当前版本缺陷。 |
| 换色／关灯残留 | 已修复全局换光后混入旧屏幕历史及缓存首次更新强制混入半份旧值的问题。新增灯表清空时移除旧解析灯缓存贡献；固定场景早期输出变化明显减少，局部换色及任意多跳响应仍未关闭。 |
| 运动拖影 | 限定相机/TAA 场景验证了新显露处的旧历史拒绝；不能据此宣称任意运动、遮挡和空间滤波都无拖影。 |
| 收敛时间 | 现有采样只能回答观测时点及区间，最后一帧不是收敛真值；尚不能给出整景达到正确颜色的统一帧数。 |

首批独立参考与动态曲线保留修复前来源，不能当作 Release76 修后结果。当前关灯观察只运行原序列的 0–299 前缀，保存 239／240／270／299 四帧；其量为乘过反射率、AO 和强度的**间接漫反射出射贡献**，不是参考中的 D=E/π。原序列与 Editor 的 `failed`、native exit 1 因提前结束而保留，不记为 720 帧通过，也不与旧 D 图直接计算物理误差。

随后尝试的 32 次相机准备响应窗口未达到采用条件，已撤回 Runtime 修改，未成为当前功能，见[未采用候选结果](LocalComparison/Review/global-light-response-window-01/result.md)。Release78采用独立的来源分离实现：关灯首帧→第59帧的平均逐像素绝对Y变化降低92.2%，第30→59帧降低80.0%，同曝光接收面反弹保留。它们是快照变化而非物理误差或收敛速度；缓存存储增加20%，实际带宽/时间增量未测。触发条件是上传灯表为空，不等同于Unity场景中所有灯关闭。

## 安装与工程集成

1. 将源码放入 Unity 6 URP 工程的 `Assets/HybridLumenGI`，不要同时导入两份。当前要求 **DX12、Linear 色彩空间、Render Graph**。
2. 在相机实际使用的 Universal Renderer Data 中添加一次 `HybridLumenGIRendererFeature`。Shader 资源自动加载；Feature 请求深度、法线和运动矢量，不要求 Opaque Texture。
3. 使用 **Tools > Hybrid Lumen GI > Setup & Proxies** 注册相关 Renderer。使用真实网格 SDF/chart 路径时，源网格需保留 Read/Write，并烘焙、绑定匹配资产；修改几何后旧资产可能需要重烘焙。没有 charts 的对象保留六视图近似。详细步骤见[安装与实现](Documentation/Implementation.md)。
4. 保存普通运行场景后，可使用[公开批处理构建入口](Documentation/BatchPlayerBuild.md)构建 Player；它使用现有工程配置，不注入本机观察器。

默认 Additive 合成会保留原生漫反射 GI。用于受控对照时，应关闭额外环境光、探针、lightmap 或其他 GI，避免重复计入照明。可选 Replace Native Diffuse GI 有更严格的 Forward/Forward+、有符号 HDR、MSAA 关闭及普通 URP Lit 条件，详见[原生漫反射合成合同](Documentation/NativeDiffuseComposition.md)。

运行时原地修改可读网格后需调用 `MarkDirty()` 或 `HybridLumenGIMeshSource.NotifyGeometryChanged(mesh)`；形变使用匹配网格/SDF/charts 的快照流程。外部 GPU 纹理写入也需要明确的更新通知和生产者顺序，不能仅靠对象引用推断内容已更新。

## 支持边界与未关闭缺口

本机已有依据的环境为 Unity 6000.0.85f1 / URP 17.0.4、Windows x64 / Mono / DX12 / Linear、RTX2080Ti。Feature 仅进入 Base Game 相机及显式允许的 Scene View；非 DX12、非 Linear、Overlay、立体/XR 和纹理数组目标会被跳过。普通 opaque/cutout URP Lit 是主要材质路径；Shader Graph、自定义顶点变形、透明、镜面 GI 和完整软阴影语义不在同一支持承诺内。

精确软件与 DXR 共用命中材质、alpha/Cull 和 chart 绑定；未知覆盖或材质不能贡献可信辐射。容量、来源或后端准入失败会保留明确的 SDF/解析近似或未知结果。HLOD 就绪表示完整组可发布，不表示照明已经收敛；资源账目也不等于驱动总 VRAM。

[原始计划](Documentation/OriginalDevelopmentPlan.md)的四项目标、十条工作流及[生产计划 G0–G5](Documentation/ProductionPlan.md)仍约束后续开发，主要开放项是：

- 整体颜色准确度、局部换色和多跳残留，以及运动后的画质与收敛时间。
- 复杂薄壁／凹腔覆盖、目标规模、流送压力和各后端未覆盖的实际使用条件。
- 生产分辨率、FPS、GI 时间及显存预算；完整平台验收、实际 CI 和发布保障。

有限场景、短窗口和历史专项不替代上述放行条件。旧成果按各自源码与配置保留，详见[完整进度与历史证据](Documentation/DevelopmentProgress.md)。

## 开发文档

- [安装与实现](Documentation/Implementation.md)；[批处理构建](Documentation/BatchPlayerBuild.md)。
- [几何来源、法线与历史](Documentation/GeometryHistoryContracts.md)；[形变快照](Documentation/DeformedGeometry.md)。
- [表面缓存](Documentation/SurfaceCache.md)；[SDF 驻留](Documentation/SdfAtlasResidency.md)；[全局 SDF](Documentation/GlobalSdf.md)。
- [直接光与阴影](Documentation/DirectLighting.md)；[环境辐射输入](Documentation/EnvironmentRadiance.md)；[发光采样与面积 NEE](Documentation/EmissiveSampling.md)。
- [原生漫反射合成](Documentation/NativeDiffuseComposition.md)；[BVH 与缓存调度](Documentation/SceneBvh.md)。
- [独立资产页](Documentation/IndependentAssetPages.md)；[HLOD 与异步场景](Documentation/HlodStreaming.md)。
- [GPU 预算及计账边界](Documentation/GpuBudget.md)；[可选原生 DX12 计时](Documentation/NativeGpuTiming.md)。
- [固定序列与 HDR 捕获](Documentation/ValidationSequence.md)；[同场景来源包](Documentation/ReviewBrief-ValidationSourcePackageV2.md)；[验收说明](Documentation/Validation.md)。
- [历史离线验证](Documentation/OfflineValidation.md)；[研究来源](Documentation/Research.md)；[社区来源与许可](Documentation/CommunitySourceAudit.md)。
