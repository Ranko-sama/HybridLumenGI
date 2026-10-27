# 社区源码对照与光传输审计

核查日期：2026-10-27。本文是新增的源码阅读记录。此前的实现主要依据 Epic 讲座、论文和 Unity API；此前没有逐文件审查或移植下列社区项目，也没有逐文件阅读 UE Lumen 引擎源码。本次阅读下面列出的实际实现文件，不把 README 中的效果图、性能数字或术语视为算法正确性证明。

外部源码只用于阅读，没有复制进本包。尤其是 LuminaGI / IglooEngine，在所列提交的完整 Git tree 中未找到 LICENSE、COPYING 或 NOTICE 文件，不能假定它们采用 MIT 或已经允许再分发。下列许可证判断针对项目声明，资源、第三方代码与依赖仍须分别核对。

## 锁定版本与用途

| 仓库 | 本次锁定提交 | 许可证证据 | 对本项目的用途 |
|---|---|---|---|
| [LuminaGI](https://github.com/CarlottaSeal/LuminaGI/tree/eab6f430a6e69c18332c6aec81d894d4ddec2792) | `eab6f430a6e69c18332c6aec81d894d4ddec2792`，2026-06-11 | 完整 tree 未找到项目级许可证；不复制代码 | 软件 SDF、surface cards、screen probes、radiosity 之间的数据流对照。属于自研 DX12 引擎，不能直接作为 URP 插件导入。 |
| [IglooEngine](https://github.com/CarlottaSeal/IglooEngine/tree/22188b4757569aa53da0f2313ca4b4fc80c5b412) | `22188b4757569aa53da0f2313ca4b4fc80c5b412`，2026-10-02 | 同上；旧 `CarlottaSeal/Igloo` 地址重定向至此 | LuminaGI 依赖的 C++ 场景/卡片管理实现。与 LuminaGI 分别锁定，未声称两提交经过联合构建。 |
| [kajiya](https://github.com/EmbarkStudios/kajiya/tree/9fdec0f074f9f822d395f9cfd041b58749e32303) | `9fdec0f074f9f822d395f9cfd041b58749e32303`，2025-07-07；仓库已归档 | [MIT](https://github.com/EmbarkStudios/kajiya/blob/9fdec0f074f9f822d395f9cfd041b58749e32303/LICENSE-MIT) / [Apache-2.0](https://github.com/EmbarkStudios/kajiya/blob/9fdec0f074f9f822d395f9cfd041b58749e32303/LICENSE-APACHE) 双选声明 | 递归 irradiance cache、真实光线命中、采样权重、曝光与历史滤波对照。Rust/Vulkan 实验渲染器，不是 Unity 包。 |
| [UnitySSGIURP](https://github.com/jiaozi158/UnitySSGIURP/tree/8450297537b658218be1abbc973e9240a2aab71c) | `8450297537b658218be1abbc973e9240a2aab71c`，2025-06-01 | [MIT](https://github.com/jiaozi158/UnitySSGIURP/blob/8450297537b658218be1abbc973e9240a2aab71c/LICENSE.md) | URP 屏幕追踪、运动向量重投影、历史管理和滤波。核心几何信息来自屏幕深度，miss 使用 reflection-probe fallback；不是完整世界空间 GI。 |
| [Godot 4.4.1-stable](https://github.com/godotengine/godot/tree/49a5bc7b616bd04689a2c89e89bda41f50241464) | `49a5bc7b616bd04689a2c89e89bda41f50241464`，2025-03-25 | [MIT](https://github.com/godotengine/godot/blob/49a5bc7b616bd04689a2c89e89bda41f50241464/LICENSE.txt) | 固定稳定版本的 SDFGI：级联追踪、探针 SH、历史滚动、直接光注入。不是对最新 Godot 分支的审计。 |
| [SimLumen](https://github.com/ShawnTSH1229/SimLumen/tree/d079f9627d9f906f6515de7f099278bf47617e19) | `d079f9627d9f906f6515de7f099278bf47617e19`，2024-09-29 | [项目 MIT](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/LICENSE)；[MiniEngine MIT](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/MiniEngine/License.txt) | 有实际 C++/HLSL 的 Lumen 类学习实现，阅读 card capture、SDF 命中、直接/间接合成和结构化采样；不是 Epic 官方代码或 Unity 插件。 |
| [NVIDIA RTXGI-DDGI](https://github.com/NVIDIAGameWorks/RTXGI-DDGI/tree/f33e496ca31b3f0eec1c4e2cbaa8bb620e337fa6) | `f33e496ca31b3f0eec1c4e2cbaa8bb620e337fa6`，2024-02-05 | 实际 [License.txt](https://github.com/NVIDIAGameWorks/RTXGI-DDGI/blob/f33e496ca31b3f0eec1c4e2cbaa8bb620e337fa6/License.txt) 是 **NVIDIA RTX SDKs LICENSE**，不是 MIT | NVIDIA 官方可见源码 SDK；核对 DDGI 的距离矩、探针可见性、历史更新、能量与位置修正。当前包没有引入 SDK。 |
| [NVIDIA NRD](https://github.com/NVIDIA-RTX/NRD/tree/e06852bd545973cb224eb28820b891205cfc1624) | `e06852bd545973cb224eb28820b891205cfc1624`，2026-10-09 | 实际 [LICENSE.txt](https://github.com/NVIDIA-RTX/NRD/blob/e06852bd545973cb224eb28820b891205cfc1624/LICENSE.txt) 同为 **NVIDIA RTX SDKs LICENSE** | NVIDIA 官方可见源码 SDK；核对 REBLUR 的资源寿命、运动约定、disocclusion 和历史稳定。不是几何追踪器；当前包没有集成 NRD。 |

新增三个仓库的 ref、commit metadata、完整 recursive Git tree 和下列源码均通过 GitHub connector 读取，tree 均未截断。上述日期为所锁定提交日期，不是本包完成相关功能的日期。许可证检查读取实际文件正文，没有依据 README 徽章推定：SimLumen 主许可证 blob 为 `fb3d3a403d1f16bf0090f7c02bd1618addf067ea`，MiniEngine 许可证 blob 为 `8b755d1fa13a302c16288de67f28ed7226fe8f92`；RTXGI 与 NRD 的许可证 blob 同为 `94965d731e87f62e85c9e06bab49cb0b22534d41`。后两者应称“可见源码 SDK”，不能因为 GitHub 可访问就把它们归入 MIT/Apache 项目。没有下载/运行其预编译依赖或把外部源码存入交付包。

## 阅读到实际阶段的证据

### AliasfreeShadowRayCones：补充的阴影过滤实现

本次额外核查作者仓库 [TU-Clausthal-Rendering/AliasfreeShadowRayCones](https://github.com/TU-Clausthal-Rendering/AliasfreeShadowRayCones/tree/fcc4e0f358a8f4dea64ebfc1bbc7b9db634b4362)，固定提交`fcc4e0f358a8f4dea64ebfc1bbc7b9db634b4362`（2025-11-06）。通过GitHub connector读取ref、commit、完整未截断tree和相关函数；README中`Rendering/Material/TexLODHelpers.slang`的路径少了复数`s`，实际文件位于`Rendering/Materials/`，以下链接采用真实路径。

| 已读文件/函数 | blob | 观察与用途 |
| --- | --- | --- |
| [RayShadow.slangh](https://github.com/TU-Clausthal-Rendering/AliasfreeShadowRayCones/blob/fcc4e0f358a8f4dea64ebfc1bbc7b9db634b4362/Source/Falcor/Scene/Lighting/RayShadow.slangh)：shadow ray构建、候选opacity与visibility累积 | `6aa0d36c1f919a6eaf8675e3b12fa1e636af91eb` | 点光收缩到灯、方向光清角扩展；候选按足迹选择alpha mip。可选择二值alpha或饱和后连续透射率累积；后者不是本包当前cutoff语义，不能直接替换而不验证能量与外观。 |
| [TexLODHelpers.slang](https://github.com/TU-Clausthal-Rendering/AliasfreeShadowRayCones/blob/fcc4e0f358a8f4dea64ebfc1bbc7b9db634b4362/Source/Falcor/Rendering/Materials/TexLODHelpers.slang)：`propagateDistance`、`hit`、`reflect`、`focus`、`orthogonalize` | `5e54c13322c7f66aa63879f5e5f1544aaae60210` | 传播宽度，按表面投影换向，点光使宽度在焦点归零。其字段命名与本包半径/斜率单位不同，不能直接交换数值。 |
| [TextureSampler.slang](https://github.com/TU-Clausthal-Rendering/AliasfreeShadowRayCones/blob/fcc4e0f358a8f4dea64ebfc1bbc7b9db634b4362/Source/Falcor/Scene/Material/TextureSampler.slang)：`ExplicitRayConesLodTextureSampler` | `8fd65279ea74838c62d6cd3c4acf3ef75d961af5` | 采样前再加入实际贴图尺寸的LOD项；shadow文件另有自己的soft sampler。不是URP Lit材质求值器。 |

实际 [LICENSE.md](https://github.com/TU-Clausthal-Rendering/AliasfreeShadowRayCones/blob/fcc4e0f358a8f4dea64ebfc1bbc7b9db634b4362/LICENSE.md)（blob `af9caafb4d9f96180b15e5d019e77089cfc3af3e`）包含NVIDIA版权下的三条再分发条件，并明确DLSS、RTXGI、RTXDI、NRD采用各自许可证。本次仅阅读相关源码，没有复制实现、安装Falcor依赖或再分发这些SDK。未构建该项目，也未复现论文的性能图；本包的独立足迹测试不能替代作者项目或本包Unity端到端验收。

### LuminaGI / IglooEngine

- [GenerateSampleDirections.hlsl，35–72 行](https://github.com/CarlottaSeal/LuminaGI/blob/eab6f430a6e69c18332c6aec81d894d4ddec2792/Run/Data/Shaders/ScreenProbe/GenerateSampleDirections.hlsl#L35)：先通过固定 octahedral 网格得到方向，再评估 BRDF / lighting SH 并存入一个组合 PDF。方向并没有根据这个 PDF 重新随机抽样。不能把该文件中的 power-heuristic 命名直接当作本项目可用的无偏 MIS 实现。
- [RadianceComposite.hlsl，45–56、127–167 行](https://github.com/CarlottaSeal/LuminaGI/blob/eab6f430a6e69c18332c6aec81d894d4ddec2792/Run/Data/Shaders/ScreenProbe/RadianceComposite.hlsl#L45)：该阶段读取 sample direction，但没有使用 `sampleData.PDF` 进行积分权重补偿；实际 source clamp 的阈值是 5，不是 README 所说的全程 `1/pi`。辐亮度本身也没有 `1/pi` 的普适上限，BRDF 的数值界不能拿来约束 HDR 光照。
- [ConvertToSH.hlsl，65–78、174–206 行](https://github.com/CarlottaSeal/LuminaGI/blob/eab6f430a6e69c18332c6aec81d894d4ddec2792/Run/Data/Shaders/SurfaceRadiosity/ConvertToSH.hlsl#L65)：radiosity 使用余弦半球采样，并以 radiance / PDF 累积 SH，再除样本数。这与直接估计 `E/pi` 的单位样本权重不同：SH 投影的积分目标没有同一个余弦因子，不能照抄某一阶段的权重到另一阶段。
- [GISystem.cpp，63–127 行](https://github.com/CarlottaSeal/IglooEngine/blob/22188b4757569aa53da0f2313ca4b4fc80c5b412/Code/Engine/Renderer/GI/GISystem.cpp#L63)：dirty card 集合与距离优先级更新列表分开，`maxCardsPerFrame` 限制所选数量；133–157 行另外建立卡片 BVH。可以参考这些数据职责，但单纯按距离排序本身没有老化防饥饿保证。
- [SurfaceCache.cpp](https://github.com/CarlottaSeal/IglooEngine/blob/22188b4757569aa53da0f2313ca4b4fc80c5b412/Code/Engine/Renderer/Cache/SurfaceCache.cpp) 与 [SurfaceRadiosityCache.cpp](https://github.com/CarlottaSeal/IglooEngine/blob/22188b4757569aa53da0f2313ca4b4fc80c5b412/Code/Engine/Renderer/Cache/SurfaceRadiosityCache.cpp)：实际存在 atlas 资源、radiosity compute 管线和 tile → card lookup 绑定；六个单值锚点不能称为这些 textured cards 的等价实现。
- [VoxelScene.cpp，274–319 行](https://github.com/CarlottaSeal/IglooEngine/blob/22188b4757569aa53da0f2313ca4b4fc80c5b412/Code/Engine/Scene/SDF/VoxelScene.cpp#L274)：存在 global-SDF dirty gate、资源 barrier 与 dispatch；所读函数仍含需绑定 descriptor table 的注释。这里只确认代码组织，不据此宣称独立拉取后即可运行或已通过验证。

### kajiya

- [ircache_trace_common.inc.hlsl，173–218 行](https://github.com/EmbarkStudios/kajiya/blob/9fdec0f074f9f822d395f9cfd041b58749e32303/assets/shaders/ircache/ircache_trace_common.inc.hlsl#L173)：三角光源采样显式除 light PDF 和 light-selection PMF，路径 throughput 使用 `value_over_pdf`；末端再查询 irradiance cache，miss 走远场或环境。这说明采样策略改变时需要同时改变权重与路径终止契约。
- [trace_irradiance.rgen.hlsl，78–139 行](https://github.com/EmbarkStudios/kajiya/blob/9fdec0f074f9f822d395f9cfd041b58749e32303/assets/shaders/ircache/trace_irradiance.rgen.hlsl#L78)：按 entry / sample / frame 生成射线，把 incident radiance 进入 reservoir，并用 pre-exposure delta 修正旧颜色。该实现还有 self-lighting limiter 等偏差控制，不能不加区分地称为无偏路径追踪。
- [sum_up_irradiance.hlsl，48–87 行](https://github.com/EmbarkStudios/kajiya/blob/9fdec0f074f9f822d395f9cfd041b58749e32303/assets/shaders/ircache/sum_up_irradiance.hlsl#L48)：使用 reservoir 的最终权重投影 SH，然后按固定新样本权重合并；无曝光契约就复制时间累积，会在曝光变化时产生错误。
- [rtdgi/temporal_filter.hlsl，100–207 行](https://github.com/EmbarkStudios/kajiya/blob/9fdec0f074f9f822d395f9cfd041b58749e32303/assets/shaders/rtdgi/temporal_filter.hlsl#L100)：一二阶矩、ray-traced history invalidity、颜色夹取和可变历史长度联合控制；不能仅靠深度/法线阈值宣称完整降噪。

### UnitySSGIURP

- [SSGI.hlsl，125–180 行](https://github.com/jiaozi158/UnitySSGIURP/blob/8450297537b658218be1abbc973e9240a2aab71c/Shaders/SSGI.hlsl#L125)：前后表面深度/厚度测试与二分式步长调整决定屏幕命中；命中辐亮度来自历史 camera color 或 back opaque texture。这是特定 SSGI 近似，不能作为我们分离直接光与多反弹源的证据。
- [ScreenSpaceGlobalIllumination.shader，174–254 行](https://github.com/jiaozi158/UnitySSGIURP/blob/8450297537b658218be1abbc973e9240a2aab71c/Shaders/ScreenSpaceGlobalIllumination.shader#L174)：运动向量回溯、世界空间深度检查、失效时增加射线数、余弦方向的均值以及 reflection-probe miss fallback 都在真实 shader 中；其亮度夹取是有偏的稳定手段。
- [同文件，284–355 行](https://github.com/jiaozi158/UnitySSGIURP/blob/8450297537b658218be1abbc973e9240a2aab71c/Shaders/ScreenSpaceGlobalIllumination.shader#L284) 与 [SSGIDenoise.hlsl，8–50 行](https://github.com/jiaozi158/UnitySSGIURP/blob/8450297537b658218be1abbc973e9240a2aab71c/Shaders/SSGIDenoise.hlsl#L8)：维护累计样本数和颜色包围盒。AggressiveDenoise 分支会继续使用已判无效但夹取后的历史；我们的严格 disocclusion 路径不应照搬此行为。
- [ScreenSpaceGlobalIlluminationURP.cs，793–946 行](https://github.com/jiaozi158/UnitySSGIURP/blob/8450297537b658218be1abbc973e9240a2aab71c/Runtime/ScreenSpaceGlobalIlluminationURP.cs#L793)：相机历史索引、尺寸变化、RTHandle 分配与未初始化历史 gate。源码组织对接入有用，但没有在 Unity 中验证其 URP 17 兼容性。

### Godot SDFGI

- [sdfgi_integrate.glsl，181–335 行](https://github.com/godotengine/godot/blob/49a5bc7b616bd04689a2c89e89bda41f50241464/servers/rendering/renderer_rd/shaders/environment/sdfgi_integrate.glsl#L181)：history index 分摊方向序列；逐级联 sphere tracing 在边界推进；采样方向性体素光，累积 SH，历史 ring 中先减旧值再加新值。这不是每帧全体历史清空。
- [同文件，488–606 行](https://github.com/godotengine/godot/blob/49a5bc7b616bd04689a2c89e89bda41f50241464/servers/rendering/renderer_rd/shaders/environment/sdfgi_integrate.glsl#L488)：滚动探针历史和父级数据填充的独立阶段，说明相机跟随的大世界表示需要处理地址变化与内容寿命。
- [sdfgi_direct_light.glsl，150–240、310–369 行](https://github.com/godotengine/godot/blob/49a5bc7b616bd04689a2c89e89bda41f50241464/servers/rendering/renderer_rd/shaders/environment/sdfgi_direct_light.glsl#L150)：探针反馈、直接光可见性、albedo × light × attenuation 注入。可用于核对直接光与递推反馈边界，不能据此保证本包的几何、透明或动态覆盖等同于 Godot。

### SimLumen：可借鉴阶段划分，不能直接采用其全部数值处理

- [SimLumenCardCapture.cpp，`CSimLuCardCapturer::UpdateSceneCards`，13–164 行](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/MiniEngine/SimLumen/SimLumenRuntime/SimLumenCardCapture.cpp#L13)：实际分配 albedo/normal/depth 目标，逐方向绘制网格，再复制到 atlas 并做资源状态转换。每 mesh 固定六张 128² card，源码明确选择了简化布局。可参考材质捕获与光照更新分离；不能据此证明复杂凹面覆盖、可变 chart、稀疏驻留或预算调度已经解决。本包当前的 triangle-isolated CaptureMesh 与 variable owner ranges 是独立实现，没有复制此六面布局。
- [SimLumenSurfaceCache.cpp，`SurfaceCacheDirectLighting` / `SurfaceCacheCombineLighting` / `SurfaceCacheInjectLighting`](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/MiniEngine/SimLumen/SimLumenRuntime/SimLumenSurfaceCache.cpp#L50) 和 [SimLumenSceneCombineLighting.hlsl，`LumenSceneCombineLightingCS`，15–27 行](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/MiniEngine/SimLumen/Shaders/SimLumenSceneCombineLighting.hlsl#L15)：代码确有 direct、indirect、final、voxel lighting 的独立读写资源；combine 为 direct 加上 indirect 乘 albedo。要复用其公式仍必须先核查上游 direct 已包含哪些材质因子；本包保留自己的 `D = E/pi` 契约，而非按变量名照搬。
- [SimLumenScreenProbeTraceMeshSDF.hlsl，`ScreenProbeTraceMeshSDFsCS`，36–115 行](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/MiniEngine/SimLumen/Shaders/SimLumenScreenProbeTraceMeshSDF.hlsl#L36)：遍历 mesh SDF，命中后通过 mesh 的 card 起点和方向查 surface lighting；说明它含世界表示查询，并非仅屏幕空间 SSGI。但该版本的 `max_ray_dir` 初始化后未在三个轴分支中更新，因此不能把“选择最大方向”的意图当作实现已正确。这是源码阅读发现，未构建或运行项目确认最终画面影响。
- [SimLumenStructuredImportanceSampling.hlsl，`StructuredImportanceSamplingCS`，33–158 行](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/MiniEngine/SimLumen/Shaders/SimLumenStructuredImportanceSampling.hlsl#L33)：使用 BRDF SH 与 lighting PDF 排序，合并低权重方向并细分高权重方向，写出方向/层级间接表。它适合研究预算如何分配到角域；仅阅读本阶段不足以证明完整积分的 PDF/solid-angle 权重正确。本包的旧缓存方向引导与完整 mixture PDF 是另一种估计器，没有移植这套排序/细分代码。
- [SimLumenRadiosityTrace.hlsl，`LumenRadiosityDistanceFieldTracingCS`](https://github.com/ShawnTSH1229/SimLumen/blob/d079f9627d9f906f6515de7f099278bf47617e19/MiniEngine/SimLumen/Shaders/SimLumenRadiosityTrace.hlsl#L30)：读取 card 属性、追踪 global SDF 后读取方向 voxel lighting；实际包含固定天空值及把 radiance 限制到 `1/pi` 的处理。该限制不能当作 HDR 辐亮度的物理上界，不能用来替代能量和 PDF 推导。本包没有采用该常量上限。

采用范围：只研究阶段分工、资源依赖和角域预算思想；不采用其数学近似、固定 card 布局或任何源码。未复现 SimLumen 的构建、图像、性能或设备要求。MIT 的项目声明不代替资源与 Embree 等第三方依赖的独立许可核对；本轮没有引入这些依赖。

### RTXGI-DDGI：有价值的是配套信号约定与可见性状态

- [ProbeBlendingCS.hlsl，`DDGIProbeBlendingCS`，475–578 行](https://github.com/NVIDIAGameWorks/RTXGI-DDGI/blob/f33e496ca31b3f0eec1c4e2cbaa8bb620e337fa6/rtxgi-sdk/shaders/ddgi/ProbeBlendingCS.hlsl#L475)：同一框架分别积累 radiance 与距离的一二阶矩，按总权重归一化；历史权重会受大光照变化影响，暗化还处理低精度量化停滞。辐照度编码、距离缩放与后续解码是配套合同，不是可独立抄走的系数。可据此补充“开灯/关灯/低亮收敛”和量化压力的验收用例；当前没有移植 DDGI probe atlas。
- [Irradiance.hlsl，`DDGIGetVolumeIrradiance`，90–203 行](https://github.com/NVIDIAGameWorks/RTXGI-DDGI/blob/f33e496ca31b3f0eec1c4e2cbaa8bb620e337fa6/rtxgi-sdk/shaders/ddgi/Irradiance.hlsl#L90)：查询八个邻近探针，跳过 inactive 状态，组合 wrap-normal、距离矩的 Chebyshev 可见性和三线性权重，最后解码并恢复积分尺度。可见性权重具有下限和经验压缩，并不是严格无遮挡证明。当前表面 patch 的位置/几何法线一致性检查与该算法不同，不能称作 DDGI 的实现或同等漏光水平。
- [ProbeTraceRGS.hlsl，`RayGen`，150–200 行](https://github.com/NVIDIAGameWorks/RTXGI-DDGI/blob/f33e496ca31b3f0eec1c4e2cbaa8bb620e337fa6/samples/test-harness/shaders/ddgi/ProbeTraceRGS.hlsl#L150)：排除用于 relocation/classification 的固定方向射线参与辐照度估计；命中光由直接项与递归查到的 irradiance 共同构成，反射率限制和 `1/pi` 明确放在间接出射项。本示例末尾还使用 saturate；它不能作为本包 HDR 量程选择的依据。可借鉴的是直接项与递归反馈分离及固定样本偏差的检查。
- [ProbeRelocationCS.hlsl，`DDGIProbeRelocationCS`，137–233 行](https://github.com/NVIDIAGameWorks/RTXGI-DDGI/blob/f33e496ca31b3f0eec1c4e2cbaa8bb620e337fa6/rtxgi-sdk/shaders/ddgi/ProbeRelocationCS.hlsl#L137)：检查固定射线的前/背面距离，为过近或处在几何内部的探针计算受限制的位置修正。只移动探针并不能修复错误几何、未加载页面或任意漏光；本包没有实现此探针 relocation 后端。

采用范围：核对辐照度单位、递归能量、历史响应与可见性测试设计；**没有链接 RTXGI、没有移植以上 shader、没有新增 DDGI 后端**。实际许可证包含专门的使用、分发和补充条款；本记录不把“阅读了 SDK”写成获得 MIT 式再分发权，也不代替未来真正集成时的许可核对。

### NRD：作为重建系统合同参考，当前并未接入

- [NRDSettings.h，`nrd::CommonSettings`，91–126、187–204 行](https://github.com/NVIDIA-RTX/NRD/blob/e06852bd545973cb224eb28820b891205cfc1624/Include/NRDSettings.h#L91)：实际接口规定矩阵布局与非 jittered 投影，单独给出前后 jitter，运动向量需要 scale/bias 和明确的 screen/world-space 语义；还存在 reset、history confidence、disocclusion 输入开关。对本包最直接的参考是写清坐标/速度/历史重置合同并逐项验收，不能照搬向量正负号到 URP。
- [Reblur_Diffuse.hpp，`nrd::InstanceImpl::Add_ReblurDiffuse`，15–49、118–229 行](https://github.com/NVIDIA-RTX/NRD/blob/e06852bd545973cb224eb28820b891205cfc1624/Source/Denoisers/Reblur_Diffuse.hpp#L15)：实际配置 permanent/transient 资源池，前帧深度/法线、主历史、快速历史和 stabilized ping-pong；串联 temporal accumulation、history fix、blur、post-blur、temporal stabilization。说明 NRD 不是单个 bilateral filter，接入必须实现整个资源寿命和信号接口。
- [REBLUR_TemporalAccumulation.cs.hlsl，`NRD_CS_MAIN`，144–163、225–302 行](https://github.com/NVIDIA-RTX/NRD/blob/e06852bd545973cb224eb28820b891205cfc1624/Shaders/REBLUR_TemporalAccumulation.cs.hlsl#L144)：从运动向量构造前帧位置，在采样 footprint 上按前帧深度平面、法线、屏幕范围与可用编码下的 material ID 拒绝历史，再形成可用插值权重。把深度/法线仅在最终混色时检查并不能复现其重投影验证。
- [REBLUR_TemporalStabilization.cs.hlsl，`NRD_CS_MAIN` 的 diffuse 分支，120–174 行](https://github.com/NVIDIA-RTX/NRD/blob/e06852bd545973cb224eb28820b891205cfc1624/Shaders/REBLUR_TemporalStabilization.cs.hlsl#L120)：计算局部亮度矩和 sigma，对重投影历史执行 antilag、历史长度调整与夹取后再稳定亮度。存在经验参数和有偏处理，不能把 NRD 名称理解为无偏重建保证。

采用范围：研究可见性与置信度怎样进入历史采样、资源是否有明确初始化和寿命、亮度突变时怎样降低历史权重。当前包仍运行自己的重投影/矩/过滤路径，**没有 NRD 插件、C++ DLL 或 shader 移植**。本轮未构建 NRD、未执行原生 API 绑定、未进行画质/显存/GPU 时间比较。

### Epic 官方源码访问的边界

2026-10-27 使用当前 GitHub connector 读取 `EpicGames/UnrealEngine` 仓库元数据得到 404。不能据此推断用户在其他身份下没有授权；本次连接没有获得可读源码，所以没有固定 UE 源码 commit 或审查 Lumen 实现文件。遵循 Epic 的[官方 GitHub 访问说明](https://www.unrealengine.com/ue-on-github?lang=en-US)，未绕过账户关联、邀请或登录，也未从不明镜像取源码。

Epic 的 [Lumen Technical Details](https://dev.epicgames.com/documentation/en-us/unreal-engine/lumen-technical-details-in-unreal-engine) 与 SIGGRAPH 2022 讲座仍是官方架构依据；当前网页是随引擎更新的说明，不能和固定 2022 讲座或某个未读取的引擎版本混为一谈。它们说明 cards、几何表示与分帧更新的设计，不是本包源代码等价性或生产性能的证明。此前没有逐文件审查 UE Lumen 源码的声明继续成立。

## 本项目代码的具体发现

以下是本次阅读时的定位，后续修改可能移动行号。修复状态应以当前源码、测试和最终验证报告共同确认；本节没有把数值参考测试当成 shader 执行测试。

| 编号 | 审计发现和可复现条件 | 修复契约 |
|---|---|---|
| A1 | `HybridLumenGIKernels.hlsl` 的 `CSTrace` 把 world hit `t + screenThickness` 作为屏幕上界；任何屏幕命中都获胜且不再比较 `screenT`。当世界遮挡距离 1、后方屏幕表面距离 1.05、厚度 0.1 时，会选择遮挡物后的表面。 | 最近世界遮挡必须参与最终命中裁决。若允许软件表示误差，应明确保守误差界并校验同一表面身份，不能把 thickness 无条件当穿墙许可。 |
| A2 | `HybridLumenGITransport.hlsl` 的 cache update 按 capture axis 写入 `id % 6`，随后把法线改成真实斜面法线；lookup 却只读 `FaceIndex(hitNormal)`。X 方向捕获、法线 `(0.35,0.94,0)` 的表面被写入槽 0，读取槽 2，丢失有效缓存。 | 小型六锚点缓存可先遍历本实例候选，以身份、generation、真实法线、位置和可见性选择；未来 textured card/patch 使用明确的表面映射。不要让不同采样约定共享一个隐含索引。 |
| A3 | `HybridLumenGIRendererFeature.cs` 对任意 scene change 或 light hash change 增全局 epoch；cache lookup 拒绝旧 epoch。持续移动一个无关物体也会让整个静态区域的反馈读取归零，Jacobi 迭代无法继续增长阶次。 | 几何失效局部化；直接光与间接反馈的生命周期分开；保留未受影响内容，并对受影响传播区域按置信度、更新时间和预算更新。关灯仍必须衰减，保留历史不等于永久保留旧光。 |
| A4 | 六锚点只有法线与法线方向平面距离，无法充分区分同一凹网格上相隔较远、互相遮挡的共面片。 | 局部空间支持域/visibility 验证和真正的 card/patch identity；六点方案只作为受限降级，不能声称完整 surface cache。 |

不应误判为错误的部分：

- 当前 cosine sampling 的 PDF 是 `cos(theta)/pi`，缓存量为 `D=E/pi`，所以 D 的样本权重是 1。接收面反射率在最终合成乘一次；这与 SH radiance 投影的权重不同。后续如果加入引导采样，应使用实际混合密度，并保留支持整个半球的分量。
- URP 的相对灯光单位不是直接拿 SI irradiance 数值代入的约定。在固定 Unity Graphics 提交 `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53` 的 [Lighting.hlsl，48–79 行](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl#L48) 与 [BRDF.hlsl，82–96 行](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl#L82)，diffuse 项直接乘 light color × attenuation × NdotL。这里任意再除 pi 会造成不匹配。
- [UniversalRenderPipelineCore.cs，1854 行](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Runtime/UniversalRenderPipelineCore.cs#L1854) 明确 `VisibleLight.finalColor` 已是 active color space。以后如果从手工 light.color 转为该值，不应再 `.linear`。当前 CPU 材质颜色与 HDR inspector 的完整对齐仍需 Unity 对照测试，不能仅靠 CPU sRGB 数学证明。
- [MotionVectorsCommon.hlsl，13–54 行](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/MotionVectorsCommon.hlsl#L13) 使用 current − previous 的 UV 运动方向；`currentUV - motion + previousJitter - currentJitter` 在输入 motion 不含 jitter 的契约下符号正确。实际渲染 target 翻转、相机堆叠、XR 和动态物体前一帧变换仍需运行验证。
- 已有的旧深度按 texel center 重建与无效历史直接赋值能避免两类确定性错误。无效 NaN 不能依赖 `lerp(NaN,current,1)` 消除。

## 新增离线测试与后续验收

执行 `node Tests/transport-audit-reference.mjs`：8 组独立 CPU 参考契约通过，并明确复现 A1、A2、A3 的旧算法反例。覆盖最近遮挡、锚点索引、局部失效下递推、jitter 符号、点采样 depth 重建、NaN 清理、线性 HDR 与反射率仅乘一次，以及偏转/背向引导瓣的混合 PDF。引导测试使用四组各 200,000 条独立采样，验证半球外样本保留零贡献且不能按接受样本数重新归一化。

该脚本不读取或执行当前 HLSL；通过仅说明参考夹具自洽，不证明 Runtime 已修复。它不代替现有 `transport-reference.mjs` 的积分/PDF 测试，也不代替最终 DXC、Unity 导入、GPU readback 或视觉验收。修复对应阶段后，需要把相同夹具转成 Unity GPU 测试或确定性场景：斜面、前后薄壁、静态色墙旁独立移动物体、灯开关、金属/白炉、镜头 jitter 与 disocclusion。

### CPU / GPU 颜色契约的待测项

普通 Color 和 HDR Color 不能仅凭名称假定使用同一种 CPU 存储规则。[URP Lit.shader](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Shaders/Lit.shader#L8) 的 `_BaseColor` / `_SpecColor` 是普通 Color，`_EmissionColor` 带 `[HDR]`。Unity 6 的 [SetColor 文档](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Material.SetColor.html) 对 `[HDR]` / `[Gamma]` 的存储前转换有特别说明；[材质属性手册](https://docs.unity3d.com/6000.0/Documentation/Manual/SL-PropertiesInPrograms.html) 另说明 Color 进入 shader 时的线性化。

公开 UnityCsReference 6000.0 提交 `1c2d7db69c060103b6dc087af725442d1efaef9c` 的 [Material.cs，170–173 行](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/Shaders/Material.cs#L170) 和 [Material.bindings.cs，239–250 行](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/Shaders/Material.bindings.cs#L239) 仅暴露 `GetColorFromScript` / `SetColorFromScript` 原生绑定；没有 getter 的具体颜色变换代码。不能由“setter 转换后存储”推断 getter 一定返回存储值，也不能据此把本包所有 `.linear` 删除。

新增 Editor 菜单 **Tools → Hybrid Lumen GI → Validation → Probe CPU and GPU Color Contract**，由 `Editor/HybridLumenGIColorContractValidation.cs` 执行。探针 shader 使用实际 URP `LitInput.hlsl` 声明，并使用与标准 Lit 一致的属性类型/标记；复制真实 Lit 材质原生属性后，将属性值直接写入线性 RGBAFloat 目标，回读对比 `GetColor` raw 和 `.linear`。

- 内置六次测量覆盖 `_BaseColor`、`_SpecColor`、`_EmissionColor` 的低亮值和大于 1 的 HDR 数值。
- 若运行时选中了一个 URP Lit 材质资产，还会读取该资产的三个属性，覆盖由 Inspector 保存的颜色。原资产不会被修改。
- 结果写入 Unity 工程的 `Logs/HybridLumenGI-color-contract.json`，含 Unity 版本、设备、API、颜色空间、属性 flags、CPU/GPU 值和误差。
- 只要求 readback 有限，不断言尚未确认的 raw / linear 方向。该探针核实原生属性上传，不是完整 Lit 光照、纹理采样、GI 或性能测试。
- **本机没有 Unity，未执行该 Editor 探针，未产生 GPU 颜色结果。** C# 语法解析不能验证 Unity 原生 API 行为；DXC 编译也不能证明颜色一致。

接下来优先采用明确许可证下的工程模式和独立数学实现；任何实际复制、移植或派生代码都应在发生时登记来源与许可证，不能用本文的“阅读参考”记录代替归属声明。
