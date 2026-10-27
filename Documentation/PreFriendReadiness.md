# 朋友测试前九项实现交接

本表对应用户原计划前九项的实现范围；不能仅凭有代码就判定实际生效。本机现已安装 Unity 6000.0.85f1 / URP 17.0.4，并在 RTX 2080 Ti / DX12 执行有限场景验证。当前增量、实际暴露的失败和修复见 [Unity 功能接线检查](LocalRuntimeFunctionalAudit.md)。最终候选以随包 runtime-validation-results.json 与 manifest 为准；朋友工程适配及生产性能验收仍单独记录。

| 原计划 | 本次实际交接内容 | 证据与边界 |
| --- | --- | --- |
| 1. 逐模块社区源码审查 | LuminaGI/Igloo、kajiya、UnitySSGIURP、Godot SDFGI 的实际文件、固定 commit、许可证和设计差距；另有补充实现对照 | [源码审查](CommunitySourceAudit.md)。只阅读，不将公开可见误作允许复制；没有逐文件审查或移植 Epic 引擎源码。 |
| 2. 光传输链路审计 | `D=E/pi`、Le/rho/直接与缓存项分离；完整方向PDF；面积Le配对MIS；未知值与置信度；Shader/C#绑定和反馈双缓冲 | [方程与失效](ProductionPlan.md)、[直接光](DirectLighting.md)、[采样](EmissiveSampling.md)。CPU数学、实际HLSL helper WARP和编译证据各自限定范围。 |
| 3. 世界空间表面材质缓存 | 真实三角charts、UV/submesh/材质版本、专属capture mesh、位置/双法线/反射率/发光/覆盖；卡池分配与回收、预算捕获；原贴图页跨帧共享与局部替换 | [表面缓存](SurfaceCache.md)。有限tile分辨率不能保证任意微小或全裁剪chart有覆盖；就绪条件会保守阻止发布。 |
| 4. 几何查询与近远场 | 实例BVH、global SDF clipmap和dirty bricks、near/far查询；精确软件三角BVH与可选DXR；闭合SDF、unsigned薄壳；预算化Skinned/可读网格快照 | [实例BVH](SceneBvh.md)、[global SDF](GlobalSdf.md)、[形变](DeformedGeometry.md)。global SDF负责保守空区加速，命中再细化；GPU私有变形需提供可读快照。 |
| 5. 局部失效与渐进多反弹 | 几何/材质/局部灯光影响域、页与owner代次、局部历史拒绝、双缓冲迭代、短可见性查询、年龄与脏项预算 | [架构与调度](ProductionPlan.md)。局部域是有界近似，完整路径依赖图与全方向可见性统计不作承诺；动态收敛需图像验收。 |
| 6. 重要性采样与降噪 | 余弦/缓存/atlas方向混合PDF；真实三角面积样本和仅Le的配对MIS；屏幕/世界最近命中分区；运动重投影、显露拒绝、历史置信度、方差和à-trous | [采样](EmissiveSampling.md)、[历史](GeometryHistoryContracts.md)。离线helper执行不是整帧均值/方差或时间测量。 |
| 7. URP Lit与DXR一致性 | stock Lit资格与keyword/MPB、真实UV/normal/parallax/多材质、Cull/alpha候选；软件和DXR共用精确材质求值；形变快照；Additive与显式原生漫反射GI替换规则 | [合成规则](NativeDiffuseComposition.md)、[朋友流程](FriendHandoff.md)。支持有界stock Lit合同；任意ShaderGraph、透明/镜面GI、XR不属于本候选支持范围。 |
| 8. 真正分页加载与独立预算 | 独立LZ4 AssetBundle页、依赖闭包整组准入、异步IO/加载、完整表示绑定和HLOD ready后原子切换；上传/纹理复制/RTAS工作与内存独立配额；GPU反馈接口；旧资源等待实际fence退休并持续计账 | [资源页](IndependentAssetPages.md)、[GPU预算](GpuBudget.md)。RTAS驱动预留为估算加观测高水位，配额不是硬毫秒或总VRAM上界。 |
| 9. 可重复回归与采集 | 现有离线数学、实际源码状态/分配适配器、选定shader编译与WARP helper；固定色墙/黑室/薄壁/移动门/关灯/镜头切换场景，720逻辑帧采集、线性HDR比较和统一验收项 | [固定序列](ValidationSequence.md)、[运行验收](Validation.md)、[离线证据](OfflineValidation.md)。未执行的Unity场景与可信参考图保持待验，不用离线数量代替。 |

九项实现的交接不等于十项原计划全部生产完成。本候选不声称完整 UE5 Lumen 等价。已通过且未改变的旧版/off、SDF 和离线工件复用；新增功能接线只补必要的 Unity/Player 证据。朋友先导入自己的工程并回传问题，再按目标硬件决定 GPU p95/p99、峰值显存和长时验收，不能用本机有限场景代替。
