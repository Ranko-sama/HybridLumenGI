# 光传输算法依据与实现边界

核查日期：2026-10-27。以下以作者、会议、期刊、Epic、Unity 和 Microsoft 的一手资料为依据，并按当前源码更新实现边界。设计结论是本项目的工程判断，不能把引用论文理解为本项目已达到论文或 UE5 的质量与性能。

论文、官方技术说明与实际源码阅读是三种不同证据。已读社区实现的固定提交/文件，以及本轮新增 SimLumen、RTXGI-DDGI、NRD 的代码与实际许可证记录，统一见 [CommunitySourceAudit.md](CommunitySourceAudit.md)。这些社区/SDK 源码仅用于研究，没有移植或打包。当前 GitHub 连接访问 `EpicGames/UnrealEngine` 返回 404；这仅说明当前连接无法读取，不说明仓库不存在。没有通过非官方镜像或绕过登录获取引擎源码，也没有逐文件审查 UE Lumen。Epic 的[合法源码访问流程](https://www.unrealengine.com/ue-on-github?lang=en-US)与公开架构资料不能代替实际源码审计。

## 主要资料

| 资料 | 用途 | 对本项目的含义 |
| --- | --- | --- |
| Daniel Wright、Krzysztof Narkowicz、Patrick Kelly，**Lumen: Real-time Global Illumination in Unreal Engine 5**，SIGGRAPH 2022 Advances in Real-Time Rendering [会议主页](https://advances.realtimerendering.com/s2022/)、[讲座 PDF](https://advances.realtimerendering.com/s2022/SIGGRAPH2022-Advances-Lumen-Wright%20et%20al.pdf) | Epic 作者的工程讲座，覆盖 SDF、虚拟化表面缓存、硬件追踪和最终聚集 | 应拆分几何查询、表面表示、光照缓存和屏幕重建；讲座不是本包的实现认证，也不是一篇独立的同行评审论文。 |
| Epic，[Lumen Technical Details](https://dev.epicgames.com/documentation/en-us/unreal-engine/lumen-technical-details-in-unreal-engine) | 官方架构与限制 | 材质 surface cache 和直接/间接光更新分离，跨帧摊销；mesh SDF 与 global distance field 分层；远场依赖 HLOD 与连续覆盖。用 bounds 代替 mesh distance field、用六个值代替 surface cards，都只能是降级表示。 |
| John C. Hart，**Sphere tracing: A geometric method for the antialiased ray tracing of implicit surfaces**，The Visual Computer，1996，[作者机构记录](https://experts.illinois.edu/en/publications/sphere-tracing-a-geometric-method-for-the-antialiased-ray-tracing/) | SDF 追踪基础 | 步长必须来自保守的距离下界；离散采样、非均匀缩放与有限精度必须纳入误差界，否则会穿过薄壁。 |
| Zander Majercik 等，**Dynamic Diffuse Global Illumination with Ray-Traced Irradiance Fields**，JCGT 8(2)，2019，[论文页面](https://jcgt.org/published/0008/02/01/)、[低分辨率 PDF](https://jcgt.org/published/0008/02/01/paper-lowres.pdf) | 世界空间动态辐照度与多次反弹 | 论文使用方向性辐照度、距离矩和可见性插值来减少漏光。只储存 RGB 并做空间插值不足以复现 DDGI；本包的表面 chart/patch 缓存也不是 DDGI 的距离矩探针实现。 |
| Zander Majercik 等，**Scaling Probe-Based Real-Time Dynamic Global Illumination for Production**，JCGT 10(2)，2021，[论文页面](https://jcgt.org/published/0010/02/01/) | 从算法走向生产的依据 | 生产版本还需要场景规模、更新开销、表示密度和各种退化情形的系统性处理；不能仅凭一张静态图片或代码导入成功验收。 |
| Christoph Schied 等，**Spatiotemporal Variance-Guided Filtering**，HPG 2017，[作者研究页](https://research.nvidia.com/labs/rtr/publication/schied2017spatiotemporal/) | 低采样 GI 的时空重建 | 将接收端反照率从信号中分离，累计历史与亮度矩，以方差驱动保边空间过滤，再乘回材质。本包采用相关思路，未声称完整复现论文所有细节。 |

## 光照量的约定

本包缓存的是线性空间的 `D = E / pi`，即辐照度除以 pi。余弦半球采样的 PDF 为 `cos(theta) / pi`，所以 Monte Carlo 估计的 D 是入射辐亮度样本的均值。命中表面的出射漫反射为 `Lo = Le + rho * (Ddirect + Dindirect)`；最终接收面也只乘一次 diffuse reflectance。Unity 灯光采用 URP 的相对强度约定，直接照明 helper 的结果与 URP Lambert 漫反射乘数一致，不应在该 helper 外再随意乘或除 pi。

直接照明、发光材质和间接反馈需要独立变量。相机颜色已经包含材质、镜面和可能存在的环境/烘焙 GI，不能当作无条件有效的二次表面辐亮度。世界缓存读取旧缓冲、写入新缓冲，构成 Jacobi 迭代；必须通过场景版本、材质版本和光照 epoch 拒绝失效值。历史滤波缓冲只供重建使用，不能直接当世界空间多次反弹缓存。

`rho < 1`、明确反馈上限和正值信号使封闭漫反射系统更易稳定；人为 radiance clamp 会引入偏差，不能替代正确 PDF 和吞吐量。当前 `HLGISampleTransportDirection` 混合表面法线余弦分布、旧缓存入射方向引导和 GPU 发光方向提议，使用完整三路混合 PDF 计算权重；落在接收面下半球的样本贡献为零，不重采样。历史引导不能读取正在写入的样本。新增发光分布来自实际 emission atlas 的有效像素统计，使用平滑球面分布，只改变方向概率；原命中求值中的 Le 不再额外叠加。数学定义、数值稳定性和依据见 [EmissiveSampling.md](EmissiveSampling.md)。

提议构建排在同一 graphics queue 的捕获/统计之后、传输之前，仅接受 ready 且 published 的 owner；warming 不作为当前发光源。默认权重 0.5、top 16、上限 32，增加每卡 32 字节描述符与每相机 1,056 字节表。分布变化不等于照明变化，不额外重置缓存。该方向域混合不是面积光 next-event estimation，也没有完成统一屏幕/SDF/DXR 发光命中身份、面积 PDF 与完整路径 MIS。CPU 分布积分、float32 数值参考和命令录制都不能证明实际 GPU 图像无偏、方差改善或时间收益。

本包的 `D = E/pi` 不能直接与 RTXGI 纹理中的编码值互换。已读 RTXGI `ProbeBlendingCS.hlsl` 与 `Irradiance.hlsl` 配套使用其权重归一化、编码和最终 `2pi` 恢复；只摘取一个系数会改变单位。NRD 则要求确定的信号、命中距离、运动向量与矩阵约定；不能把一个 temporal shader 接到本包就称为完整 NRD 集成。具体证据见新增源码记录。

## Unity 6 硬件后端依据

- [SystemInfo.supportsInlineRayTracing](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/SystemInfo-supportsInlineRayTracing.html) 是运行时 ray query 能力检查。在 DX12 下对应 DXR 1.1；Unity 建议使用 `UnityRayQuery.cginc` 包装。
- [ComputeShader.SetRayTracingAccelerationStructure](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/ComputeShader.SetRayTracingAccelerationStructure.html) 和 `#pragma require inlineraytracing` 支持 compute 查询。
- [RTAS.AddInstance](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.RayTracingAccelerationStructure.AddInstance.html) 支持 renderer、mesh 和 procedural AABB。当前后端使用真正的 `RayTracingMeshInstanceConfig` 三角形实例，不把 AABB 相交称作三角形追踪。
- [CommandBuffer.SetGlobalRayTracingAccelerationStructure](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.CommandBuffer.SetGlobalRayTracingAccelerationStructure.html) 必须在 build 后绑定；原生 command buffer 中先 build，再 bind 和 dispatch，保证顺序。
- [Unity 6000.0 C# reference](https://raw.githubusercontent.com/Unity-Technologies/UnityCsReference/6000.0/Runtime/Export/Graphics/RayTracingAccelerationStructure.bindings.cs) 用于交叉核实实例配置、结构签名和构建方法。该源码仅用于 API 核查，没有复制实现。
- [Microsoft DXR Functional Specification](https://microsoft.github.io/DirectX-Specs/d3d/Raytracing.html) 用于核查候选/提交命中、primitive/instance 索引和最近命中的语义。
- [Unity shader API 编译参数](https://docs.unity3d.com/6000.0/Documentation/Manual/SL-ShaderCompilationAPIs.html) 中 `d3d11` 同时覆盖 DirectX 11/12；shader 中没有使用不存在的 `only_renderers d3d12` 令牌。

当前 DXR 的适用范围：注册且已发布的、可读取顶点数据的、不透明且未形变的 MeshRenderer；非空 submesh 分别建立真实三角形实例。每三角形包含80B法线/UV、96B原始位置/切线和16B chart绑定，共 **192 字节**；每实例另有128B记录，scene slot标志另占4B。250,000三角仅这些三角属性约 **45.8 MiB**。命中材质批次另外分配240B材质+32B绑定/实例、纹理metadata与纹素池；还需加CPU数据和驱动BLAS/TLAS，不能将属性估算当峰值显存。

刚体运动保留native instance handles，通过 `UpdateInstanceTransform` 更新变换并记录后续build；未改变的object-space三角属性不重传。材质变更逐帧复查硬件资格，manual/topology变化触发重建。真实驱动refit、耗时及原生资源hazard尚未验证。形变、alpha clipping、透明、不可读mesh或超预算实例仍不准入硬件；软件fallback也不保证这些对象的覆盖/形变准确。新硬件查询使用primitive、重心、UV和冻结材质/纹理表求值，surface card只提供世界缓存入射光；未知命中材质保留遮挡并拒绝该辐射度估计，不用代理常量制造已知结果。任意Shader Graph、真实DXR alpha遍历与完整URP parity仍未完成。后端以DX12 inline-ray-query能力gate启用，软件路径也受当前DX12/Linear目标限制。

## 命中材质、阴影覆盖与射线足迹的新核查

最新工作区正在接入原始UV材质求值与不可变批次；旧版通过surface card/常量近似获得DXR材质的描述仅适用于旧归档。新代码尚未通过Unity整体验收，CPU alpha实例准入仍关闭。需要完整材质的bounce查询与仅需几何/覆盖率的visibility查询已分开，普通visibility仍遵循表面Cull与alpha，不能套用shadow caster的排除规则。

固定URP源码的 [ShadowCasterPass.hlsl](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl) 直接用变换后的base UV做alpha test，不执行ForwardLit的parallax。因而新桥接的shadow coverage局部禁用parallax，不读取height map，也不依赖其切线或观察点；普通表面覆盖保留视差。这只核对了该覆盖规则，未复现LOD crossfade、软阴影或shadowmap过滤的全部行为。

[ShaderVariablesFunctions.hlsl](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl) 区分透视的逐顶点观察向量与正交的恒定方向。新材质接口用`float4`表达观察源：`w=1`为点，`w=0`为朝观察者的方向。Feature现冻结每相机观察源并传入屏幕world-match；近远场推进保留该观察源，普通反弹使用其未加bias的表面点。正交方向不再用虚构的远处相机点替代。接口与接线已有专项/选定编译证据，实际Unity相机和材质一致性仍待验证。

Brüll、Kern、Grosch 的 [Alias-Free Shadows with Ray Cones for Alpha Tested Geometry，VMV 2025](https://diglib.eg.org/bitstream/handle/10.2312/vmv20251226/vmv20251226.pdf) 与[作者源码](https://github.com/TU-Clausthal-Rendering/AliasfreeShadowRayCones/tree/fcc4e0f358a8f4dea64ebfc1bbc7b9db634b4362) 区分方向光的平行传播和点光的焦点收缩。本包独立helper同样保留表面足迹再投影到阴影方向，点光半径随距离收缩至灯位置；不会因一次far-field原点跳跃重置半径。该论文还研究连续透射率的饱和累积，本包当前仍为材质cutoff的二值覆盖，没有把二者混称相同算法。源码核查见社区记录。

漫反射的角度扩展仍未选定完整模型。[2021 Ray Cones论文§4](https://www.jcgt.org/published/0010/01/01/paper-lowres.pdf) 使用BRDF近似并指出需控制Monte Carlo过度模糊；其中粗糙度端点的方差公式不能直接当成有限传播斜率。[PBRT 4的纹理过滤章节](https://www.pbr-book.org/4ed/Textures_and_Materials/Texture_Sampling_and_Antialiasing) 也明确区分镜面微分传播与漫反射的近似处理。进一步可依据[Suykens与Willems，Path Differentials and Applications，2001，§2.3–2.5](https://graphics.cs.kuleuven.be/publications/PATHDIFF/PATHDIFF_paper.pdf)，为实际重要性采样引入方向微分和采样间距，再构建足迹；其间距选择仍是估计，且可见性边界另需处理。本包目前的空间半径helper不等于已经完成这套多次反弹过滤。

## 当前表示与实现阶段

- **表面材质**：已有可变三角 chart baker、独立 CaptureMesh、每 chart 的源 submesh 材质映射、稳定 chart ID、128 字节 card metadata、owner ranges 与物理页间接表。按完整 owner chart 集合准入；容量不足不会静默截断。每张卡捕获后扫描各 patch cell 的实际有效 texel，再发布锚点和 readiness。只有未配置 chart 资产的对象使用六方向首层捕获，属于明确的近似路径。详见 [SurfaceCache.md](SurfaceCache.md)、[SurfaceCharts.md](SurfaceCharts.md)。
- **几何查询**：已有对象 mesh SDF atlas、实例 BVH 与可选硬件三角查询；global SDF 是带 world key/generation/ready 的分层 torus brick 缓存，仅输出保守空域步长，最终命中仍由实例后端求解。缺页是 unknown，不能作空空间。Renderer bounds 下界保护会使包围盒内部无法获得加速；这与 UE 的完整 Global Distance Field tracing 不同。详见 [GlobalSdf.md](GlobalSdf.md)。
- **光照缓存与 HLOD**：材质页、patch irradiance、屏幕历史是独立寿命。HLOD 保留旧 published 集合，目标集合以 warming 状态准备，GPU 回读与源版本/布局/atlas/cache epoch 验证通过后才能整组发布。每个真实 required chart 必须有非空有效 patch；初始化样本阈值不是收敛或完整可见性证明。纯表示切换与真实几何失效分开处理。详见 [HlodStreaming.md](HlodStreaming.md)、[SdfAtlasResidency.md](SdfAtlasResidency.md)。
- **加载**：已有显式 additive-scene manifest 与 `LoadSceneAsync`/`UnloadSceneAsync` 驱动，限制并发和每帧启动次数，使用 generation/ownership/unload-safe 授权。已经超出“仅对已加载对象做 GPU residency”的旧阶段，但没有自动世界分区、自动跨场景 HLOD 绑定、Addressables 或磁盘级稀疏 SDF brick IO。
- **普通 URP Lit 合成**：已有受资格 gate 约束的实验性 native diffuse replacement 路径，复用所锁定 URP 的材质/GI 辅助函数；必须验证 RendererList 属性、local keywords、lightmap/probe、SSAO、decal 与 fog 的实际一致性。部分 baked direct 不能与 native bakedGI 物理分离。它不是任意 URP Shader/渲染路径的通用支持声明。详见 [NativeDiffuseComposition.md](NativeDiffuseComposition.md)。

## 尚不能作为 UE5 等价生产方案的部分

1. 可变三角 chart 解决了旧六方向首层捕获无法分开凹形内外表面的重要限制，但当前固定分辨率页面、有限 patch 网格、细长/亚像素图元和 alpha cutout 仍可能缺覆盖。完整性需要实测覆盖与材质误差；不能将离线 chart 分配、一个非空 patch 或记录到命令流的 ready 当成渲染验收。多分辨率自适应页面与更复杂的动态曲面表示仍需研发。
2. 离屏材质已有受支持的stock Lit card capture和新命中UV材质求值；后者仍需整体验证，不能视为完整原生URP hit shader。CPU alpha准入关闭，任意Shader Graph、透明或形变未支持。原纹理每批完整复制且没有跨帧复用：三张不同的2048²完整mip纹理加必要表已超过默认256MiB材质预算。发生回退必须记录实际后端；不能用代理均值或请求了hardware开关声称材质已经正确。
3. Additive scene IO、SDF 驻留和 HLOD 发布协议已存在，但自动内容制作、跨场景与多相机卸载协调、实际资产字节预算、磁盘/解压峰值和无缝过渡还需要应用集成与实机测量。场景数量预算不是总显存/内存/IO 字节预算。
4. 完整动态几何支持还需要变形 BLAS refit/rebuild、GPU 顶点属性一致性、对象 motion vector，以及 SDF 动态重建或显式退化策略。预算必须同时覆盖 CPU、GPU、显存、IO 与更新延迟。
5. 应用路径追踪或烘焙参考图、相机运动序列、灯光切换、几何删除、材质变化、镜头切换、分辨率变化和设备矩阵验收。每个性能数字都必须附平台、版本、分辨率、场景与 p95/p99；未实测数据只能作为目标。
