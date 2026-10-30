# HybridLumenGI

Unity 6 / URP 17 的实验性漫反射 GI。包含真实网格 SDF、表面材质与世界光照缓存、精确软件三角查询、可选 DXR、时域重建、形变快照和分页/HLOD。当前仍在开发，不宣称 UE5 Lumen 等价或生产验收完成。

**当前本机入口：[启动统一交互 Release90](<I:/Unity test/Comparison/Builds/LocalRelease90/Start-LocalRelease.cmd>)。** 启动时优先DXR，按4可切回软件，保留既有硬件准备失败回退。同一场景提供导航、分页/HLOD、换色、灯光、门和形变操作；GPU计时、更新预算反馈和进程显存观察默认关闭。该路径属于当前开发机，其他工程请按下文集成或构建。

Release90修复[形变快照发布饥饿](LocalComparison/Review/deformed-publication-fairness-01/result.md)：上传额度紧张时，已完成快照按捕获入队顺序争用额度，避免持续完成的新任务反复抢先。未完成头项仍可跳过，失效清理及失败所有权保留。必要组件回归和公开Release构建通过；GI着色器与2射线/DXR配置保持，没有新的Player、画质或性能测量。

Release89新增[可选形变捕获时间准入](LocalComparison/Review/deformed-capture-time-budget-01/result.md)：本帧同步捕获经过时间达到额度后，延后开始下一对象并保留轮次，完成任务的发布／清理照常执行。默认关闭，单次BakeMesh不可抢占。必要组件规则检查与公开Release构建通过；当前2射线/DXR及画质配置保持，没有新增实机性能或画质结论。

Release88采用[本机2射线质量配置](LocalComparison/Review/two-ray-local-quality-01/result.md)：仅将屏幕每像素射线从1增为现成的2，Runtime算法不变。[四时点软件对照](LocalComparison/Review/two-ray-local-quality-01/comparison.png)中颗粒与暗斑减少，未见明显新增持续轮廓，软斑仍在；全图平均出射亮度上升约7.9–23.1%，不能称颜色更准。默认DXR的普通门运动Present约39.95Hz，p95／p99间隔27.81／28.72ms，最大30.72ms，支持本机960×540启动配置下的30FPS方向，性能余量变小。软件画质与DXR成本为独立来源，不是显示FPS或整体G5验收；旧1射线误差和响应数据不得重标为88。

Release87整合[短历史空间滤波改进](LocalComparison/Review/short-history-spatial-filter-01/result.md)：两端短历史采用对称的已有噪声尺度，时间混合不变。[同曝光软件239帧](LocalComparison/Review/short-history-spatial-filter-01/comparison.png)中，门及邻近墙地的黑颗粒明显减少，云状软斑仍在，未见阻断性边缘损坏；已知点和门面时间统计保持。新增读取成本未测，单帧不证明颜色准确度、全过程无拖影或收敛。普通Release/None构建已完成，未追加Player或成本运行。

按用户明确的取舍，随后[四时点动停对照](LocalComparison/Review/release87-motion-response-01/result.md)中，149／179帧颗粒减少、画面略柔；停止后10／30帧接近原基线，未见明显新增持续轮廓。仅限该软件场景四个时点，不宣称全过程无拖影；没有修改或重建87。

此前普通Release87的[门运动Present窗口](LocalComparison/Review/release87-motion-present-01/result.md)以960×540参数启动、默认DXR，平均70.85Hz，间隔p95／p99为16.73／17.80ms，2123个观测间隔均小于33.33ms。正常三维画面与M后门移位已观察，两端CPU状态为DXR且transform更新推进；该有限窗口支持30FPS开发方向，不是显示FPS、GI专项/滤波增量成本或完整G5验收。没有追加窗口或重建。

Release86修复[离场后重复分配空几何资源](LocalComparison/Review/empty-geometry-preparation-01/result.md)：无可接纳三角实例时直接退出准备并退休旧资源，重新入场仍可恢复。已完成必要源码回归和普通Release/None构建；没有新增Player、画面或性能采集，图像与帧率结论保留以下实际版本来源。

Release85仅落实[本机DXR启动偏好](LocalComparison/Review/dxr-local-default-01/result.md)，GI算法不变；普通启动后F2已确认实际DXR。当前静止软件／DXR对照中，Floor已知域的平均绝对D亮度差约0.00000325，White均值RGB和所列误差指标一致，未见明显新增缺损；这不是动态等画质认证。此前Release84的[普通应用Present窗口](LocalComparison/Review/release84-dxr-present-01/result.md)为79.22Hz、间隔p95 14.33ms／p99 14.81ms，作为本机960×540／30FPS方向的依据保留，不冒充Release85新测帧率或完整生产验收。

Release83 整合[刚体同帧更新的历史恢复](LocalComparison/Review/rigid-pose-history-01/result.md)：修复纯平移重传被误加Added、从而错误拒绝可信历史的问题。原场景239帧门面2739个已知点中，2724点恢复短历史复用，门面黑颗粒明显减少，仍有软斑驳；单帧不能证明无拖影或收敛。真正新增、延迟上传、内容变化及不匹配对应仍保守处理。

Release82 整合[严格静止样本的重建修复](LocalComparison/Review/stationary-history-01/result.md)：避免当前稀疏采样把已积累历史压暗。frame119固定Floor/White平均D偏差由−28.9%/−33.4%降至−5.84%/−3.36%，逐像素误差和色向也改善，未知不增。仅适用于成熟、相机/样本/几何/材质完全未变且无motion/jitter/reactive的条件；无标记真变暗32步仍保留约6.88%的残留，不能称动态不变。原D240采集缺口、运动颗粒和整体收敛限制保留。

Release81 接通[普通Player的GPU计时与反馈入口](LocalComparison/Review/gpu-budget-controls-01/result.md)，允许只测量或显式输入目标后启用已有控制器；关闭可恢复静态配额。同步整合零AO下不必要的缓存依赖修复。没有自动选择生产预算，也不保证达到输入目标。Release80 已修复[零漫反射表面的已知辐射丢失](LocalComparison/Review/zero-diffuse-known-radiance-01/result.md)：有效自发光／黑色不再因无关的阴影或缓存查询未知而被丢弃，正漫反射和来源资格保持。它是局部能量资格修复，没有新增整景颜色、动态质量或性能结论。Release79 已为同一门物体增加[真实 Skinned 骨骼形变模式](LocalComparison/Review/skinned-unified-usage-01/result.md)，保留可读网格模式；沿用 Release78 的[按来源分离的缓存关灯响应](LocalComparison/Review/cache-source-separation-01/result.md)：当前上传的解析灯表为空时，移除其旧多跳贡献，保留自发光／环境贡献。沿用统一交互及默认关闭的[驱动进程显存观察](Documentation/GpuBudget.md#驱动层进程显存观察)，保留此前屏幕历史、缓存首次可信更新和面积光冗余计算修复。[有限成本结果](LocalComparison/Review/screen-endpoint-only-01/result.md)来自 Release76 的固定配置，仅覆盖三个 GI 区间，不代表 Release83 全应用帧率或生产放行。后续源码修改不会自动更新 EXE。

## 使用统一示例

已按用户要求完成[Release83本机起始基线](LocalComparison/Review/release83-local-baseline-01/result.md)：当前960×540／半分辨率GI／精确软件下，GI三区间合计中位28.02ms、p95 31.19ms、p99 31.45ms；相机回调平均34.50次／秒，非Present FPS。进程local采样峰值577.45MiB、nonlocal280.66MiB，非GI独占或瞬时峰值。基线之后用户已选定960×540／30 FPS目标；GI专项时间和显存上限尚未单独确定。

用户确认普通场景显示后，[应用Present窗口](LocalComparison/Review/release83-present-api-02/result.md)测得平均29.15次／秒、间隔p95 38.58ms／p99 41.35ms，该有限窗口尚未达到30FPS。此处关闭显示跟踪，不是显示器实际FPS；与上面的相机回调基线口径不同。

已有[DXR模式的同配置GI成本](LocalComparison/Review/release83-dxr-cost-01/result.md)中位13.28ms、p95 14.33ms，较软件基线有更多时间余量；当前普通示例启动时请求DXR，并可查看面板actual后端。该成本结果不证明等画质或普通显示FPS；通用Feature默认仍为软件偏好。

点击窗口后操作：

| 操作 | 按键 |
| --- | --- |
| 平移／升降／转向 | WASD ／ Q、E ／ 方向键 |
| 近景／远景／离开分页范围 | 1 或 R ／ 2 ／ 3 |
| 软件／DXR 偏好 | 4 ／ 5 |
| 墙面换色／灯光开关／门运动 | C ／ L ／ M |
| 形变启停／切换网格与骨骼来源 | 空格 ／ K |
| 分页组释放与重载 | B |
| 隐藏面板／退出 | F1 ／ Esc |
| 导出当前运行状态至Player日志 | F2 |

实际后端以面板诊断为准，选择 DXR 偏好不保证硬件路径被采用。关灯仍保留发光面；停止形变后，异步 GI 快照可能继续追上可见网格。骨骼模式复用现有快照流程，K可切回原网格模式；两种形变均不修改物理碰撞体。用户已根据本机基线选择先以 **960×540／30 FPS** 为开发目标；这是目标，当前尚未完成稳定帧率验收。

点击面板的 **Memory: off** 开启本进程 local/nonlocal 显存用量、OS预算及采样峰值；**Log ledger** 或 **F2** 将已有当前状态导出到Player日志。F2不会自动开启计时或显存采样。缺失或旧原生DLL会显示不可用，不影响GI。数据不是GI独占、整机用量或绝对瞬时峰值，也不改变更新配额。

展开 **GPU time / update budget**，先选 **Measure only** 查看已有GI区间；输入有限正数并点击 **Apply feedback** 才启用反馈，**Off** 关闭。输入框获得焦点时暂停导航快捷键。实际状态和配额显示在同一面板，**Log ledger** 导出请求与结果；缺测不当作零成本，最低配额仍可能超目标。详见[用法与范围](Documentation/GpuBudget.md#普通运行入口与公开配置)。

从自己的场景生成示例：保存场景，选择至少两个已绑定 SDF 和 surface charts 的静态 Proxy，执行 **Tools > Hybrid Lumen GI > Create Unified Sample From Selected Static Proxies**。菜单要求一个启用相机，并从该相机实际选择的 Universal Renderer Data 中解析唯一启用的 GI Feature；无关已加载资产不参与选择。显式 `CreateVariant` 仍可使用。生成器保留作者场景，创建独立变体与资源页；静态网格、材质及 HLOD 限制见[统一示例说明](Documentation/ReviewBrief-UnifiedSample02.md)。菜单修复已有 Editor 编译依据，尚未重新生成场景。

## 当前画质结论

最新[局部换色对照](LocalComparison/Review/local-recolor-response-01/result.md)：红墙改蓝后，材质未变的Floor／White在30帧已明显更新反弹色，59与119帧的平均色向接近，原有已知点未丢失。首帧颗粒及后续亮度变化仍在；没有蓝墙独立参考，不把晚帧当作正确颜色或“旧色完全清除”的依据。

此前[重新开灯对照](LocalComparison/Review/light-restore-response-01/result.md)：Release83在恢复后30帧，Floor／White平均间接入射D达到开灯前观测的74.65%／65.68%；59帧为98.36%／96.78%，未知不增。当前照明能恢复，首帧颗粒与响应延迟仍在；这些有限时点不等于精确收敛时间或整体动态验收。

[Release83刚体历史对照](LocalComparison/Review/rigid-pose-history-01/result.md) · [Release82修复与独立对照](LocalComparison/Review/stationary-history-01/result.md) · [修复前frame119对照](LocalComparison/Review/current-color-frame119-01/result.md) · [既有动态对照图与曲线](LocalComparison/Review/dynamic-picture-comparison-01/index.html) · [阅读四项结论及适用范围](LocalComparison/Review/dynamic-picture-comparison-01/report.md) · [Release76关灯基线](LocalComparison/Review/current-lightoff-prefix-01/result.md) · [Release78缓存改进对照](LocalComparison/Review/cache-source-separation-01/result.md)

| 问题 | 当前结论 |
| --- | --- |
| 颜色误差 | [Release88软件119独立对照](LocalComparison/Review/release88-color-frame119-01/result.md)：Floor／White平均D偏差−2.776%／−0.938%，逐像素Y-MAE 0.009566／0.017423；比旧1射线结果小，但Floor色向L1由0.004220增至0.007884。限两个ROI和既有近似参考，不解释全部运动亮度变化或整景准确度。 |
| 换色／关灯残留 | 已修复全局换光后混入旧屏幕历史及缓存首次更新强制混入半份旧值的问题。新增灯表清空时移除旧解析灯缓存贡献；固定场景早期输出变化明显减少，局部换色及任意多跳响应仍未关闭。新的静止例外对无标记变暗消退更慢，有限32步后仍保留初始约6.88%。 |
| 运动拖影 | Release88／2射线减少软件149／179／189／209的颗粒和暗斑；[当前DXR同场景四图](LocalComparison/Review/release88-dxr-motion-01/result.md)未见相对软件新增明显颗粒回退、边缘缺损或持续旧轮廓。软斑仍在，不是全段无拖影或任意运动等价。 |
| 收敛时间 | 现有采样只能回答观测时点及区间，最后一帧不是收敛真值；尚不能给出整景达到正确颜色的统一帧数。 |

Release83刚体修复的专项只新增正常产品0–239前缀的239帧历史与画面对照，该项验证已结束。后续0–359重新开灯观察见上方链接，复用原独立参考，没有生成新参考或给出精确收敛时刻。首批候选图与动态曲线保持旧来源。Release82修复复用保存场景的一次0–299前缀，D119/239/270/299完整；D240触及已有Capture容量而缺失，原分析失败保留，普通240出射图不能替代D。没有补采，不外推局部换色、任意运动或精确收敛。此前Release76/78的关灯观察运行原序列的 0–299 前缀，保存 239／240／270／299 四帧；其量为乘过反射率、AO 和强度的**间接漫反射出射贡献**，不是参考中的 D=E/π。原序列与 Editor 的 `failed`、native exit 1 因提前结束而保留，不记为 720 帧通过，也不与旧 D 图直接计算物理误差。

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
- 960×540／30FPS目标下的正式GI时间及显存预算、完整平台验收和发布保障；实际CI按用户要求暂缓。

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
