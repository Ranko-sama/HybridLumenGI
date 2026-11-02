# HybridLumenGI

Unity 6 / URP 17 的实验性漫反射 GI：真实网格 SDF、表面材质与世界光照缓存、渐进多次反弹、时域重建、精确软件三角查询、可选 DXR，以及形变快照和分页/HLOD。当前仍在开发，完整 G0–G5 尚未验收，不宣称 UE5 Lumen 等价。

## 开始使用

**直接运行**　完整解压 Windows x64 实验性演示包，双击 `Start-LocalRelease.cmd`。请把整个包解压到新目录，保留可执行文件旁的所有数据。下载需要私有仓库访问权限。[下载 Release110](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release110-demo)

Release110 会在相机从域外接近时提前请求聚合体的页，进入实际加载范围后才绑定。在一次 20 单位／秒的冷入折返中，首个可提交组由回程 7.39 单位处的远景根，前移到回程 1.78 单位处的三个完整细节。两次在折返点都尚无可提交组。[冷入路线与资源边界](LocalComparison/Review/cold-aggregate-prefetch-01/result.md)

**在中性两室切换远近景**　按 F3 进入两室，按 2 切到远景，按 1 返回近景。Release106 修复了聚合网格沿共边多拆两张表面卡的问题。两室共用连续的地板和顶棚后，远景聚合体可在原 192 张卡预算内完成发布，返回近景可恢复全部三个细节。[实际 Player 的远近切换](LocalComparison/Review/neutral-room-chart-fit-01/result.md)

**步行穿过三室**　按 F3、F4，从右侧开口进入中室，向左对准中央门，再穿入源室。O 开关中央滑门，F4 恢复原两室。三室复用连续地板与红绿侧墙，在 192 张卡预算内完成了远近切换。[实际键盘路线、三室画面与发布状态](LocalComparison/Review/three-room-passage-01/result.md)

**离线看画面对照**　打开运行包内的 `PictureComparison/index.html` 可查看颜色误差、换色与关灯残留、运动拖影和收敛时间。其他章节包含白炉、零漫反射、离屏纹理、两室关门后的暖光衰减，以及静态烘焙贴图替换与独立直射基准。包内附原始线性 EXR。[真实烘焙三方对照](LocalComparison/Review/baked-lightmap-01/result.md)

Release110 已随包收录 Release109 的同版换色对照。红墙改蓝后第 30 帧，地板与白色接收块相对首帧蓝墙分别暗 12.34% 和 11.59%。这组图与数据也可单独下载。[下载换色对照与原始数据](https://github.com/Ranko-sama/HybridLumenGI/releases/download/release109-demo/HybridLumenGI-Release109-RecolorComparison.zip) · [条件与读数](LocalComparison/Review/blue-wall-history-01/result.md)

只需最初四问的画面时，也可单独下载[原版离线附件（1.44 MB）](https://github.com/Ranko-sama/HybridLumenGI/releases/download/release97-demo/HybridLumenGI-Release97-PictureComparison.zip)。

仓库画册另有单盏 Mixed 主灯的 Shadowmask 对照。替换漫反射后，保留烘焙遮罩的区域仍是阴影，只把遮罩换为全白时该区才重新受光。[四张实机画面与原始 EXR](LocalComparison/Review/mixed-shadowmask-01/result.md)

Release107 画册包含方向贴图对照。转动接收面法线能改变暖、冷烘焙光斑。替换后与仅保留实时直射的独立画面相差最多 0.000488 个线性通道单位。[方向贴图四图与原始 EXR](LocalComparison/Review/directional-lightmap-01/result.md)

本开发机的统一示例使用 960×540、半分辨率 GI、每像素 2 条射线和 4 级空间滤波，启动时优先 DXR。Release109 修复了静止斜面的成熟历史被错误压暗的问题，并保留 Release108 的滤波纹理复用。GPU 计时、预算反馈和进程显存观察默认关闭。[启动本机 Release110](<I:/Unity test/Comparison/Builds/LocalRelease110/Start-LocalRelease.cmd>) · [静止斜面对照](LocalComparison/Review/stationary-tilted-normal-01/result.md) · [屏幕纹理账目](LocalComparison/Review/filter-work-texture-01/result.md)

Release104 修复了冷启动只进入远场时，已加载的聚合体无法显示的问题。离线画册新增门框后地板的对照，两块发光面到该地板的直线都被实墙遮住。[远景发布条件与实测](LocalComparison/Review/cold-far-root-01/result.md) · [遮挡后的地板与原始 EXR](LocalComparison/Review/shaded-room-floor-01/result.md)

Release103 修复了颜色全黑的解析灯占据有限灯表名额的问题。最后一盏有效灯改黑时会移除旧表项，微弱非零的灯恢复后仍能入表。[准入、移除与恢复](LocalComparison/Review/black-light-admission-01/result.md)

**进入相邻两室**　启动后按 F3 切换布局，O 全开／全闭共用隔墙上的门，WASD 可穿过门洞，自由探索前室和光源室。离线画册里可查看同机位的开门／关门地板图。[开门与闭门的固定端点](LocalComparison/Review/connected-rooms-01/result.md) · [实际关门后的暖光残留](LocalComparison/Review/portal-close-response-01/result.md)

**视锥外纹理反弹**　相机只能看到白地板。交换画面外墙上的红蓝纹理后，地板左右两处的反弹颜色也会交换。[成对画面、线性读数与适用范围](LocalComparison/Review/offscreen-wall-texture-01/result.md)

### 接入自己的工程

当前源码包含一项 Editor 修复，在正常退出 Play 后释放跨场景的两个资源回收宿主。[实机快照与范围](LocalComparison/Review/streaming-sustained-30m-01/result.md#editor-退出-play-后的原生对象)

已有 Unity 工程升级时，先保存作者资产和原有引用，再按版本差异替换源码。升级与回退步骤包括旧设置、SDF／charts、分页资产及可选插件的处理。[升级已有 Unity 工程与回退](Documentation/Implementation.md#升级已有-unity-工程与回退)

1. 在 Unity 6 URP 工程中创建 `Assets/HybridLumenGI`，将本仓库的 **`Runtime`、`Editor`、`Shaders` 产品目录及随附 `.meta`** 复制到其中，保留目录结构和 `Runtime/Resources`。`LocalComparison`、`Tests`、`Delivery` 是开发资料，留在工程外；不要把整个仓库放进 `Assets`，也不要同时导入两份产品源码。本仓库没有 UPM `package.json`，此处使用源码目录导入。
2. 配置 **DX12、Linear 色彩空间、Render Graph**，在相机实际使用的 Universal Renderer Data 中添加一次 `HybridLumenGIRendererFeature`。Shader资源自动加载；Feature请求深度、法线和运动矢量，不要求Opaque Texture。
3. 使用 **Tools > Hybrid Lumen GI > Setup & Proxies** 注册Renderer。真实网格路径要求源网格保留Read/Write，并烘焙、绑定匹配SDF和surface charts；没有charts时使用六视图近似。编辑几何后可能需要重烘焙。详见[安装与实现](Documentation/Implementation.md)。
4. 保存普通运行场景后，使用[公开批处理构建入口](Documentation/BatchPlayerBuild.md)构建Player。入口使用现有工程配置，要求Windows x64／Mono／显式DX12／Linear及新输出目录，不注入本机观察器。

默认 **Additive** 合成保留原生漫反射GI；受控对照需关闭额外环境光、探针、lightmap或其他GI，避免重复计入照明。可选 **Replace Native Diffuse GI** 要求Forward/Forward+、有符号HDR、关闭MSAA和普通URP Lit；其强度设为零也不等于关闭Feature。详见[原生漫反射合成合同](Documentation/NativeDiffuseComposition.md)。

需要原生GPU计时／进程显存观察时，按[可选原生插件说明](Documentation/NativeGpuTiming.md)部署DLL；源码导入不等于安装该DLL。分发原生插件时保留随包的[第三方通知](Documentation/NativeGpuTimingThirdPartyNotices.md)及其引用许可。

运行时原地修改可读网格后，调用 `MarkDirty()` 或 `HybridLumenGIMeshSource.NotifyGeometryChanged(mesh)`；形变使用匹配网格/SDF/charts的快照流程。外部GPU纹理写入需要明确的更新通知和生产者顺序，不能仅凭对象引用推断内容已更新。

### 生成统一示例

保存作者场景，选择至少两个已绑定SDF和surface charts的静态Proxy，执行 **Tools > Hybrid Lumen GI > Create Unified Sample From Selected Static Proxies**。菜单要求一个启用相机，并从该相机实际选择的Universal Renderer Data中解析唯一启用的GI Feature。生成器保留作者场景，创建独立变体与资源页；显式API为 `HybridLumenGIUnifiedSampleBuilder.CreateVariant`。

在自己的工程中运行示例键盘交互时，打开 **Edit > Project Settings > Player > Other Settings > Configuration > Active Input Handling**。示例通过 `UnityEngine.Input` 读取按键，请选择 **Input Manager (Old)**，若项目也使用新版 Input System 则选择 **Both**，并按 Unity 提示重启编辑器。此设置只涉及示例交互，单独接入 GI Renderer Feature 可沿用工程的输入方案。

生成的资源页位于工程的 `Assets/StreamingAssets`；交付Player时保留这些bundle及对应数据目录。静态网格、材质和HLOD输入限制及生成步骤见[统一示例说明](LocalComparison/Implementation/UnifiedSample/SAMPLE.md#生成及使用)。生成器不会把任意场景自动变成具有换色、灯光或门事件的验证场景；未提供相应输入时只显示可用操作。

如需在自己的 Unity 工程中生成两室版本，打开由标准彩墙场景生成的统一示例，保存后执行 **Tools > Hybrid Lumen GI > Create Connected Rooms Copy of Unified Sample**。生成器会在同目录保存场景副本，复用原有分页组和烘焙资产。

## 普通示例操作

点击Player窗口后操作；以下事件快捷键对应已交付的统一场景。

| 操作 | 按键 |
| --- | --- |
| 平移／升降／转向 | WASD ／ Q、E ／方向键 |
| 近景／远景／离开分页范围 | 1或R ／ 2 ／ 3 |
| 软件／DXR偏好 | 4 ／ 5 |
| 进入两室／返回原布局，开关分隔门 | F3 ／ O |
| 墙面换色／灯光开关／门运动 | C ／ L ／ M |
| 形变启停／切换网格与骨骼来源 | 空格 ／ K |
| 分页组释放与重载 | B |
| 隐藏面板／退出 | F1 ／ Esc |
| 导出当前状态到Player日志 | F2 |

实际后端以面板诊断为准，DXR偏好不保证采用硬件路径。关灯仍保留发光面。停止形变后异步GI快照可能继续追上可见网格；K切换的两种形变模式均不修改物理碰撞体。

Release97修复[Base转Overlay后的旧GI页需求残留](LocalComparison/Review/overlay-camera-page-retention-01/result.md)：卸载判断排除当前非Base相机的旧场景，保留URP Scene View的Base语义。其他相机及原GPU退休条件保持；源码审阅与普通构建通过，不代表该切换完整生命周期的实机验收。

Release95修复[高反射率材质的直接反弹路径差异](LocalComparison/Review/direct-reflectance-consistency-01/result.md)：物理rho保留[0,1]，0.98只限制递归缓存反馈，screen/world直接项一致。反馈仍有偏；本次固定函数检查及普通构建不增加整景颜色、运动或成本验收结论。

保留Release94的[普通骨骼停稳历史累计](LocalComparison/Review/skinned-stopped-history-01/result.md)：满足完整来源和局部骨姿态稳定条件时恢复历史，真正骨变化仍拒绝旧历史。统一场景GPU观察支持该能力；Cloth、blend shapes和自定义GPU变形不在合同内，也不代表任意动画无拖影或固定帧数收敛。原生短序列退出仍有待退休资源，此次不算清理验收；普通交付不含临时观察器。

- **Group request/available**：样例请求与完整Renderer可提交组，`details/aggregate`表示细节已请求、聚合体仍可用；`unknown`表示无法确认完整组，不等于已证实画面缺失。见[表示状态范围](Documentation/HlodStreaming.md)。
- **Memory: off**：开启本进程local/nonlocal显存、OS预算及采样峰值。缺失或旧原生DLL显示不可用，不影响GI；数据不是GI独占、整机用量或绝对瞬时峰值。
- **GPU time / update budget**：先用 **Measure only** 查看GI区间；输入有限正数并点击 **Apply feedback** 才启用反馈，**Off** 关闭。自96起，这些控制只刷新计时／控制器，不再单独撤销已有光照与HLOD就绪。最低配额仍可能超目标，缺测不当作零成本。见[计时与预算用法](Documentation/GpuBudget.md#普通运行入口与公开配置)。
- **Log ledger／F2** 将当前状态写入日志。遇到 HLOD 预热时，可在 `cameraGi.lastHlodCoverageBlock` 查看最近有效回读里的首个覆盖阻断，区分整张必需 chart 无可用覆盖与某个 patch 的样本年龄不足。[字段与适用范围](LocalComparison/Review/hlod-coverage-diagnostic-01/result.md)

## 当前画质与性能

当前取舍是减少运动颗粒，允许局部变柔，同时避免明显加重拖影。Release99 将已发布表面变化的范围传给世界缓存调度器。预算紧张时，换色墙附近的接收面可先于无关远端更新。下表画质与成本仍按实际采集版本注明。[调度顺序与适用范围](LocalComparison/Review/surface-change-cache-order-01/result.md)

| 问题 | 已有结论与局限 |
| --- | --- |
| 颜色误差 | [93／filter4／DXR静止119](LocalComparison/Review/release93-color-frame119-01/result.md)：Floor／White平均D亮度偏差−3.075%／−0.831%，Y-MAE为0.010529／0.018576，均值色向L1为0.007976／0.033415。相较旧软件filter3，两个MAE约增10.1%／6.6%，不能称全面更准或单独归因滤波。限640×360参考网格的两个ROI及近似参考，不是整景或960×540颜色验收。 |
| 换色／关灯残留 | [83局部换色](LocalComparison/Review/local-recolor-response-01/result.md)中，红墙改蓝后接收面在30帧已明显转蓝；没有独立蓝墙参考，不能量化绝对旧色残留。[78来源分离](LocalComparison/Review/cache-source-separation-01/result.md)在上传解析灯表为空时移除其旧缓存贡献，保留自发光／环境；该条件不等于任意局部灯关闭。当前filter4没有新的事件观察，任意多跳残留仍开放。 |
| 运动拖影 | [92／filter4四时点对照](LocalComparison/Review/four-pass-local-quality-01/comparison.png)中门面、地板与绿墙云斑减少，未见新增持续旧门轮廓；局部明暗过渡更柔。不证明全过程或任意运动无拖影。 |
| 收敛时间 | 仍不能给出整景达到正确颜色的统一帧数。[83重新开灯](LocalComparison/Review/light-restore-response-01/result.md)后30帧，Floor／White平均D恢复到开灯前观测的74.65%／65.68%，59帧为98.36%／96.78%；这不是精确收敛时间。无标记变暗的[静止历史有限检查](LocalComparison/Review/stationary-history-01/result.md)在32步后仍留约6.88%，也不是Unity全场景时间。 |

[完整独立画面对照与不确定性](LocalComparison/Review/dynamic-picture-comparison-01/report.md)保留颜色、残留、拖影和收敛的来源及适用范围。晚帧不作为颜色真值，旧版本结果不改标为当前重新通过。

Release99 另有一项可直接与理论值比较的白炉观测。在均匀单位白环境下，无遮挡白色平面中央区域的普通间接出射 RGB 均值为 (0.99902347, 0.99902347, 0.99902347)，各通道较理论值 1 低 0.09765%。该结果限单帧、单接收面。[原始线性 HDR、预览图与比较口径](LocalComparison/Review/white-furnace-ordinary-01/result.md)

黑色和全金属接收面使用历史 V209 的同帧加法合成对照。两个内区的漫反射率为零，合成前已有的非零颜色得到保留，逐像素 RGB 最大变化为零。[实测对照与适用范围](LocalComparison/Review/zero-diffuse-composite-v209/result.md)

起始目标为 **960×540／30FPS、GI三区间合计p95≤25ms、进程local有限采样峰值≤1GiB**，nonlocal另列。环境为Unity6000.0.85f1／URP17.0.4、Windows x64／Mono／DX12／Linear、RTX2080Ti。

| Release93的独立窗口 | 测量结果 | 适用范围 |
| --- | --- | --- |
| [静止GI与显存](LocalComparison/Review/exact-no-fallback-traversal-01/result.md) | GI合计p95为19.298ms；local峰567.254MiB，nonlocal峰289.691MiB | 满足25ms／1GiB起始门槛；有限采样，不是整应用GPU、瞬时显存峰值或运动最坏情况。 |
| [普通M门运动](LocalComparison/Review/release93-motion-present-01/result.md) | 应用Present平均52.69Hz；间隔p95／p99为21.97／23.57ms，最大25.99ms | 一次固定30秒窗口、960×540启动参数，全部观测间隔低于33.33ms；支持30FPS方向，不是实际显示FPS或完整平台验收。 |

## 支持边界与原计划进度

Feature仅进入Base Game相机及显式允许的Scene View；非DX12、非Linear、Overlay、立体/XR和纹理数组目标会被跳过。普通opaque/cutout URP Lit是主要材质路径；Shader Graph、自定义顶点变形、透明、镜面GI和完整软阴影语义不在同一支持承诺内。

精确软件与DXR共用命中材质、alpha/Cull和chart绑定；未知覆盖或材质不能贡献可信辐射。准入失败时保留明确的SDF/解析近似或未知结果。HLOD就绪表示完整组可发布，不表示照明已收敛；资源账目不等于驱动总VRAM。

[原始计划](Documentation/OriginalDevelopmentPlan.md)的四项目标、十条工作流及[生产计划G0–G5](Documentation/ProductionPlan.md)继续约束开发。**[G0本机基线锁定已完成](Documentation/ProductionPlan.md#g0已锁定的本机基线)，G1–G5继续开放。** 主要开放项为整景颜色与多跳残留、完整运动和精确收敛，复杂薄壁／凹腔及近远场支持范围，冷／热／高速流送、目标规模与长时负载，以及承诺平台的完整性能／内存和发布验收。实际CI按用户要求暂缓。有限窗口不替代这些条件。

**已关闭的具体缺口与各阶段历史统一见[完整推进表](Documentation/DevelopmentProgress.md)。** 本页仅维护当前使用入口和结论；历史构建、失败、候选撤回及原始证据保持原来源。

## 开发文档

- [安装与实现](Documentation/Implementation.md)；[批处理构建](Documentation/BatchPlayerBuild.md)。
- [几何来源、法线与历史](Documentation/GeometryHistoryContracts.md)；[形变快照](Documentation/DeformedGeometry.md)。
- [表面缓存](Documentation/SurfaceCache.md)；[SDF驻留](Documentation/SdfAtlasResidency.md)；[全局SDF](Documentation/GlobalSdf.md)。
- [直接光与阴影](Documentation/DirectLighting.md)；[环境辐射输入](Documentation/EnvironmentRadiance.md)；[发光采样与面积NEE](Documentation/EmissiveSampling.md)。
- [原生漫反射合成](Documentation/NativeDiffuseComposition.md)；[BVH与缓存调度](Documentation/SceneBvh.md)。
- [独立资产页](Documentation/IndependentAssetPages.md)；[HLOD与异步场景](Documentation/HlodStreaming.md)。
- [GPU预算及计账边界](Documentation/GpuBudget.md)；[可选原生DX12计时](Documentation/NativeGpuTiming.md)。
- [固定序列与HDR捕获](Documentation/ValidationSequence.md)；[同场景来源包](Documentation/ReviewBrief-ValidationSourcePackageV2.md)；[验收说明](Documentation/Validation.md)。
- [历史离线验证](Documentation/OfflineValidation.md)；[研究来源](Documentation/Research.md)；[社区来源与许可](Documentation/CommunitySourceAudit.md)。
