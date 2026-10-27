# 任务基线与交付漂移独立审计

审计日期：2026-10-27；取证截止约 06:28 UTC。工作区：`C:/Users/Administrator/Desktop/test/HybridLumenGI`。本报告按用户提供的十项原计划审计，不把新增测试数量作为功能完成度。除本报告及配套 `.meta` 外，审计未修改 Runtime、Tests、现有文档或交付包；未运行整套回归、Unity、真实 DXR 或实体 GPU。文中源码定位均相对此工作区，行号对应本次取证快照。

**结论：已发生明确的交付与优先级漂移，但不是没有真实进展。** 当前已有真实三角 chart、网格 SDF、局部失效、世界缓存、方向混合采样、重投影、HLOD 与异步场景加载等实现，不能退回“只有六个锚点的 SSGI”评价。与此同时，十项原计划并未全部完成；离线验证、验证报告再验证、原生计时和研究扩展占据了越来越多的工作，而第一次朋友工程导入/运行仍无证据。继续增加这些设施不会自动填平缺失的功能，也不会替代朋友端验证。

**交付判断：integration-13 已是可交朋友进行导入与基线测试的源码候选；它不是完成原计划的版本。当前材质工作树尚不能作为“统一回归通过的新候选”交付。** 最合适的选择是保留 13 的不可变测试基线，给当前材质集成设置有限收尾清单，另出新候选；不全量回滚已有进展，不把新代码和旧通过报告混装，也不等生产关卡全部完成才让朋友开始测试。用户本机不安装 Unity 是既定条件，不是阻塞这一交付安排的理由。

**一、必须分开的三个放行点**

| 放行点 | 需要满足什么 | 当前判定 |
| --- | --- | --- |
| 朋友测试候选包 | 一个冻结源码版本、与它匹配的离线证据、明确支持/缺失范围、可操作的导入和回传步骤；没有已知而隐瞒的编译/运行阻断 | 13 已具备这一用途。新工作树尚欠来源一致的整体验证和说明收尾。候选允许有待验证项；不能把它描述成已经运行成功的 Player。 |
| 朋友端验证 | 在朋友现有 Unity 工程进行实际导入、Player 构建、软件/DXR 图像与动态检查，取得日志、图像和设备数据，再修阻断 | 未执行。它必须发生在拿到测试候选之后，不能成为生成第一个测试候选的前置条件。 |
| 最终生产放行 | 原计划明确功能闭环；对承诺范围完成质量、稳定、规模、性能、峰值显存和长测；无阻断缺陷 | 未达到。原计划的 alpha、形变、采样、流式预算等实现缺口不能全部改名成“只等实机验收”。也不能声称 UE5 Lumen 等价。 |

证据：`Documentation/ProductionPlan.md:119–126` 明确列的是 G0–G5 生产关卡；`:128–136` 另有交朋友步骤。`Documentation/FriendHandoff.md:3–15` 把交付称为源码集成候选。`Delivery/HybridLumenGI-2026-10-27-delivery-verification-13.json:80–84` 的 Unity、实体 GPU、生产与等价标志均为 false。这些定义本来允许先交测试包；不应在执行中把三个放行点合并。

**二、证据究竟绑定哪个版本**

| 证据 | 独立核对结果 | 能说明什么、不能说明什么 |
| --- | --- | --- |
| integration-13 源码包 | 本次实际 SHA256 为 `8BAC482CF4121181627BCBB6DEA11D199B3426C6A3142D5D750DC4BA805D9B1B`，与原交付审计相同 | 归档仍可作旧基线；本次没有重跑其全部测试。 |
| friend-handoff-13 外包 | 实际 SHA256 为 `057B5BF9782D41B7878FF69E58763B71777A5D7FA74A006408BC4A6E6C2038B8`，与原 handoff 审计相同 | 已存在可传给朋友的外包和说明。不能据此认定里面的软件已在 Unity 运行。 |
| `Tests/offline-validation-results.json` | 仍是 `54C24D2BAA65BC30D725B226C86EBC460307173FA0674145D67A088A455AF7C7`，56 阶段/194 来源；逐项重算时 **21 份来源与当前文件不同** | 旧 126 selected DXC、41 份 C# 语法证据不能覆盖新工作树。新增文件也不在旧 194 来源中。 |
| 13 与当前选定源码/文档对比 | 对归档内 Runtime/Editor/Tests/Documentation 的 `.cs/.hlsl/.shader/.compute/.ps1/.mjs/.md` 比较，22 个既有条目改变，148 个相同；另有 16 个新 Runtime C#/shader 文件 | 这是部分扩展名清单的精确差异，不是全包总文件差异。新材质集成已是实质性变化，不能作为文档小修发布。 |
| HardwareMaterials WARP | 两个已保留报告分别有 9 入口、1,647 案例/46,116 检查；bridge 为 `B8D132…F75`；其提取来源 HardwareTrace 为 `D423953…7D68` | 实际执行了材质 bridge/helper；未执行 UnityRayQuery。当前 HardwareTrace 已是 `6F0B544F…FCF7B`，旧结果不能证明本轮完整接线。 |
| RayQueryPropagation WARP | 报告 passed，1,676 案例/154,192 检查；本次核对报告的当前来源哈希无差异 | 验证原 `TraceSceneQuery` 的参数、观察源与足迹近远场传播。detail/global-SDF 为明确替身；不是实际 BVH/SDF/DXR 遍历或整帧图像。尚未纳入统一清单。 |
| 本轮 4 入口默认优化 DXC | 独立读取 selected 报告：软件/硬件 cache 与 trace 均 exit0；报告 SHA `5F07E57A210F864749175339152190C18F9258AC34693E8B1D747D7E12B078AF` | 本轮主要计算入口可在该离线环境编译，是有效进展。不能替代 C# Unity API 编译、全变体/全专项回归或硬件执行。 |
| 新 aggregate | `Tests/Validate-Offline.ps1:42–48,93–111` 注册 68 阶段；`Tests/Verify-OfflineReport.ps1:192` 声明预期 146 selected DXC | 这是检查清单与通过条件，不是已有一次 68 阶段通过的事实。 |

HardwareMaterials 报告位于 TEMP 的 `hlgi-hardware-materials-warp-7629d15f2a95493f874201542a354581` 与 `hlgi-hardware-materials-warp-2c99c290448c4505be67e13f9758959b`；RayQueryPropagation 位于 `hlgi-ray-query-propagation-warp-682ece5924c2460fa042306efb456386`；四入口报告位于 `hlgi-footprint-integration-selected-f5974fd4b5e143f4945c090296fedccd`。TEMP 不是持久交付存档，正式候选应保存本次实际需要的最终证据，不必再复制一套无关历史验证设施。

**三、十项原计划逐项判定**

| 原计划项目 | 判定与已交内容 | 未完成内容及放行影响 |
| --- | --- | --- |
| 1. 逐模块审查 LuminaGI、kajiya、UnitySSGIURP、Godot SDFGI，锁 commit/许可证，给设计、问题、差距 | **所列模块的审查交付已存在，证据可定位。** `CommunitySourceAudit.md:11–15` 锁定四项目及 Igloo 依赖；`:36–63` 给实际文件/函数观察；`:103–122` 给本项目 A1–A4 反例与修复合同。LuminaGI/Igloo 无项目级许可证的记录没有被写成可再分发许可。 | 不是对所有仓库文件的穷尽审计；本审计核对了本地阅读记录，未重新联网重读全部外部源码。对测试候选无新增阻断。以后实际移植才需逐项处理归属；无需为此次打包再扩大项目清单。 |
| 2. 重审直接光、发光、反射率、PDF、单位、多反弹、夹取、缓存与 C#/shader 合同 | **主要纠错已实现，当前集成仅部分验证。** `Transport.hlsl:7,17–21,243–282,378–415,430–484` 有 D=E/pi、分离旧/新缓存、身份/法线/可见性门控和单次 Le/rho 求值；`Kernels.hlsl:291–305` 比较最近世界/屏幕命中，先检查未知/非有限值再夹取。Feature `:96` 默认关闭有偏 radiance clamp。 | 灯光单位、CPU/GPU 颜色、原生 GI 合成仍需 Unity 对照。新 footprint/view 签名已使部分旧专项提取/字符串断言失配，见第六部分，阻断“新候选统一通过”的声明。不能因 13 的旧绿灯省略这次受影响回归。 |
| 3. 真正世界空间材质缓存：多 cards/patches、位置/法线/rho/Le/覆盖/版本、submesh/UV、atlas 分配回收和预算 | **核心实现已具备；有限覆盖与实际渲染未验收。** `HybridLumenGISurfaceCharts.cs:14–22,100–156,207–238,311–408` 保存来源三角/submesh 并分组、拒绝重叠、生成专用捕获网格；`SurfaceCache.cs:391–397` 按完整 owner 准入；`Transport.hlsl:434–453` 从真实覆盖 patch 读写世界缓存。模块主体仍与 13 来源相同。 | 未配置 chart 才走六面近似；不是所有对象已自动变成六面之外的完整表示。固定页面与 4×4 patch 不保证细薄/全裁剪/凹面完整覆盖，自适应和形变未完成。朋友需检查 atlas/anchor，不必先研发新的自动覆盖证明系统才能交候选。 |
| 4. 近远场几何：实例加速、global SDF clipmap/dirty bricks/衔接，薄壁/非闭合/形变路径 | **部分实现。** 实例 BVH、真实网格 SDF 烘焙/atlas、signed 与 unsigned shell、分层 torus bricks/代次/unknown 已存在。`GlobalSdf.cs:120–182` 局部失效和预算更新；`GlobalSdf.hlsl:31–57` 缺页未知；`Transport.hlsl:153–185` 近远场重叠、保守空区推进、恢复命中距离。 | Global SDF 只加速已发布几何的空区，最终仍细化；renderer bounds 内下界为零（`GlobalSdf.md:21–25`）。薄壁和非闭合是有限精度近似，形变 SDF 自动更新/Skinned 路径缺失。对静态/刚体测试候选属明确边界；对完整原计划仍是实现和验收缺口。 |
| 5. 局部失效、稳定多反弹、可见性/陈旧度/防饥饿 | **机制已实现，稳定性结论未成立。** Feature `:523–538` 导入局部变化而只在 `RequiresFullInvalidation` 时全重置；`Transport.hlsl:260–276,445–450` 验证缓存与局部 hard/soft 失效；`CacheScheduler.cs:104–105,126–136` 保留服务年龄并给最旧项至少约四分之一配额。 | 仍是有限影响域近似，未实现完整路径依赖图/方向距离统计；长距离多反弹关灯残留、移动门消隐与渐进收敛须测。不能用调度公平性通过代替图像稳定，也不能为“证明全部路径”无限追加离线状态机。 |
| 6. 发光体/辐亮度引导、正确混合 PDF/MIS、运动重投影、显露判断、置信度/方差 | **方向混合和时域重建已实现；面积采样路径仍缺。** `EmissiveSampling.md:21–37` 定义完整三路方向 PDF、零贡献样本与种子分离；真实材质 atlas 发光统计接入。`Kernels.hlsl:321–438` 有历史匹配、矩、夹取与置信度；receiver 对象历史有独立身份流程且默认关闭。 | 当前是有效的方向域单样本 MIS，不能冒称已完成三角面积光 NEE/跨表示发光身份/PDF。后者明确缺失（同文 `:47`）。运动/显露/方差实际收益未验收；任意仿射/形变历史不支持。新 spatial footprint 的零角斜率也不是完整 BRDF 多反弹过滤模型。 |
| 7. URP Lit/DXR 材质一致性：keyword/alpha/normal/multi-material、真 UV/材质/形变、烘焙与其他 GI 合成 | **部分实现，也是当前主要未收尾项。** 精确 MaterialSource、UV/原始三角/法线/240B 材质记录、原纹理复制/采样、TBN/LOD 与图批次已接入；`HardwareTrace.hlsl:65–95,123–159` 分 coverage/full/shadow；`Transport.hlsl:388–415` 用真实命中材质而只借 card 查入射缓存。受限制的 native diffuse replacement 也已存在。 | CPU `HardwareBackend.cs:255–270` 仍拒绝 alpha-test，Skinned/不可读 mesh 不准入；不能把 shader 中有 alpha helper 写成 DXR alpha 已支持。自动形变、真实 Unity keyword/纹理上传/法线编码和 baked/environment/其他 GI 对照均未闭环。新候选须写实际支持范围；原计划这部分仍欠功能，不只是“已经做完等朋友验收”。 |
| 8. 真正流式预算：异步 geometry/SDF/material pages、原子 HLOD、上传/cache/RTAS/显存分预算、GPU 反馈接口 | **部分实现，不能按“已完全流式”放行。** `ChunkStreamer.cs:52,60` 真正调用 SceneManager 异步接口；HLOD published/warming 和 readback 门控已接入（`HlodReadback.cs:45–116`）；已有场景/SDF/卡片/射线/屏幕字节预算和可选 GPU 反馈。 | 异步加载整场景不是独立稀疏 SDF/材质页磁盘 IO；跨场景 HLOD 绑定/多相机卸载仍由应用负责（`HlodStreaming.md:35–43`）。RTAS build/refit、IO/解压/实际资产字节和所有阶段时间没有完整独立硬预算。新纹理每批全复制会进一步放大这一缺口，见下节。测试包可以暴露这些限制，原计划不得删项。 |
| 9. 可重复离线回归、色墙/黑室/薄壁/移动门/关灯/切镜固定场景、对照图脚本/验收表 | **离线设施充分，运行回归资产部分完成。** 有数学/cache/allocator/shader 及实际 WARP helper；`Editor/HybridLumenGIValidationScene.cs:34–64` 生成色墙、黑/金属接收者、发光面、灯与门；`ValidationMotion.cs:15–20` 用 Time.time 驱动门；`Validation.md:32–52` 有验收表。 | 该生成场景不是完整封闭黑室/薄壁/关灯/切镜自动序列；Time.time 运动也不是固定帧重放。搜索 Tests/Editor 未找到自动 HDR 对照图采集与误差比较脚本，`Validation.md:3` 明说没有参考图/Player/GPU 时间。为完成本项，下一笔验证工程应补小型固定序列与回传产物，而非另一套离线报告反例框架。 |
| 10. 朋友工程导入/Player、软件与 DXR 图像、动态稳定、GPU p95/p99/峰值显存/长测，修阻断后定生产范围打包 | **源码测试包已打包；朋友验证与最终放行未开始。** 13 源码/外包/说明/哈希和审计俱在，`FriendHandoff.md:9–15` 可供导入。 | 没有 Unity 导入/Player、实际 DXR、目标实体 GPU 图像/性能证据。当前能交的是“供朋友建立这些证据的候选”，不能交成“已完成第 10 项的生产版”。在朋友结果回来前可以收尾本地可做事项，但不得靠继续加离线设施把这一外部验证永久推后。 |

以上 `Transport.hlsl`、`Kernels.hlsl`、`HardwareTrace.hlsl`、`GlobalSdf.hlsl` 均位于 `Runtime/Resources/HybridLumenGI/`，C# 简称位于 `Runtime/`；文档简称位于 `Documentation/`。

**四、新材质系统的具体容量边界**

这不是猜测 GPU 性能，而是现有分配公式可复现的预算拒绝条件：

1. `HybridLumenGIRayTextureLayout.cs:13,21–38` 每 texel 使用 16 字节。`HybridLumenGIRayTexturePool.cs:99–100` 从 mip 0 分配完整逻辑 mip 链，`:115–117` 计入 metadata 并严格检查全局预算。
2. 一张 2048×2048、12 级完整 mip 纹理有 5,592,405 texels，即 89,478,480 字节。三张不同且实际启用的纹理（例如 base、normal、emission）共 **268,435,440 字节，约 256 MiB**。
3. 再加三份 64B metadata 和一份 240B material + 32B binding，最低为 **268,435,904 字节**；默认 `hardwareMaterialBudgetMiB=256` 即 268,435,456 字节（Feature `:113–114`）。即使没有旧批次、没有其他相机，已超预算 448 字节。因此该正常尺寸组合在默认预算下会整批拒绝；不是“只差测试”。
4. `HitMaterialBatch.cs:139–141` 每批创建新 pool；`:164–165` 分配新记录/绑定；Feature `:817–829` 对图批次准备，失败经 `:831–838` 切回软件并使历史/epoch 失效。不存在跨帧持久纹理复用。若两批仍在途，两张相同 2K 纹理也可能因重复持有达到约 341.3 MiB；这是条件性风险，尚未实测发生频率。

需要立即修正的是承诺与诊断：新候选不能声称默认支持常见多张 2K 贴图的 DXR 路径；应附正向小场景与明确的超预算 fallback 用例，记录 `hardwareMaterialStatus`、每批/全局字节和实际后端。不能靠删除预算或把未知覆盖当透明来“修绿”。跨帧共享驻留、按变化复制/上传、合适的纹理存储与 mip 驻留是原计划第 8 项的真实后续工作；若要承诺这一材质规模，应先完成它们，不能只提高默认预算掩盖重复分配。

另一个已过时的数字：`HardwareBackend.cs:83` 现在每三角包含 80B normals + 96B surface + 16B binding，即 192B；250,000 三角仅这部分约 45.8 MiB，不含 128B/instance、标志、纹理、CPU、RTAS/驱动。`ProductionPlan.md:109` 仍按 80+16B、约 22.9 MiB描述；`Research.md:40–42` 和 `FriendHandoff.md:39` 也保留旧属性/材质路径描述。打包新候选前必须同步。

**五、漂移证据与合理复杂度的界线**

| 现象 | 证据 | 审计判断 |
| --- | --- | --- |
| 验证正在替代交付进展 | 13 已有 56 阶段/126 DXC；交付审计还有 source 9,181、native 4,908、outer handoff 590 项检查；随后新 aggregate 68 阶段/146 DXC，新增报告 verifier 76 反例×两 shell，而仍无一次 Unity 导入结果 | **明确存在工作流漂移。** 源码哈希绑定、首次负例与 WARP 执行有价值；追加测试数不是原计划功能完成，也不能提高“从未实际导入”的可信度。不能只根据计数推断每项验证无用或未经授权。 |
| 新材质集成不断延伸到过滤模型与平台细节 | 16 个新 Runtime 文件，原纹理池、复制、采样、TBN/LOD、detail/parallax、观察源、footprint；`Research.md:48–54` 又进入 shadow ray cones 与未选定 BRDF 模型 | 一部分是第 7 项必要依赖；但在首次朋友测试之前继续追求完整 BRDF 角传播，会延后反馈。当前已实现 spatial radius，应明确冻结该层次，完整模型单列未完成项，不继续研究到无期限。 |
| 原计划只要求预留反馈接口，已扩大为可选原生计时系统 | `ProductionPlan.md:93–95,113` 的 native DX12 128 槽/fence、Recorder 回退；`OfflineValidation.md:36–41` 多层托管/native/WARP验证 | 不是无关功能，最终预算会受益；但默认关闭且没有实体 GPU 数据。继续改进这个可选系统的优先级低于一次真实导入、材质容量边界和回归场景。保留现有成果即可。 |
| 报告与状态叙述失同步 | README `:3`、ProductionPlan `:5,11` 仍写 bridge 超时/传播未接入；实际 9 入口 WARP 已通过且当前 footprint 已接线。ProductionPlan `:168,175` 又称“当前统一回归已通过”；但当前旧报告 21 份来源已变 | **明确的状态漂移。** 不应删除历史失败；应把它们标注成旧版本记录，同时明确新工作树的已通过/未完成。OfflineValidation `:3` 的旧版限定写得正确，但不能修复其他“当前已通过”的歧义。 |
| 研究扩张超出原四项目清单 | CommunitySourceAudit `:16–34,65–97` 增加 SimLumen、RTXGI、NRD、AliasfreeShadowRayCones 和 UE 访问尝试 | 现有阅读可保留，针对具体 bug 的核查合理；现在应停止继续扩张。研究发现要落到一个明确实现/测试决策，否则不能成为打包前置任务。 |
| 把生产要求当首次测试包门槛 | 生产 G0–G5与交朋友步骤本已分开；13 外包明确未运行Unity。工作树又在外部验收前持续扩大本地验证 | 可以确认“外部验收尚未发生、离线工作继续增长”的替代效应；仅凭文件不能归因每次延期的全部动机。正确收敛是先交可测基线，再按证据修阻断，不能把 G5 当生成 G0 测试包的门槛。 |

合理复杂度反例也必须保留：材质/纹理精确版本、整块 MPB 优先级、Ng/Ns 分离、candidate coverage 与 shadow policy 分离、unknown 保留遮挡、跨相机资源寿命、fence 后释放和完整混合 PDF 都直接关系真实错误，不能为缩短报告把它们删成均值材质或“所有东西都 opaque”。实际 HLSL 的 WARP oracle 比纯字符串包含测试更强；源哈希可以防止旧通过报告冒充新代码。问题是缺少收尾上限与交付节奏，不是这些技术工作本身不应存在。

**六、当前新候选的最短收尾路径**

推荐“分开候选并补完当前收尾”，理由是：13 已冻结且哈希可验证；新材质直接补原计划第 7 项，不能随意丢弃；新功能已改到共享 Transport/Kernels/Feature，部分回退不是简单删一个文件。四个核心编译入口通过，也没有证据支持为了缩短清单而全量回滚。若收尾发现无法在本轮修复的 Unity/DXR阻断，可继续用 13 建基线，保留新源码快照作为下一候选；不能把回退后的受限基线宣布为完成原计划。

1. **立即停止增项并冻结来源。** 保持 13 不变，给当前工作树建立独立快照/清单。本文是审计，不是新的必检 framework。原计划剩余项继续保留，不在此时追加 NRD/DDGI、全平台、specular/reflections 或新 native 后端。
2. **只修接线与已有测试失配。** 当前 `Validate-DirectLighting.mjs:74–102` 仍用旧 `TraceShadow`/`DirectIrradiance`/`ProxyRadiance` 的函数体断言；`transport-normal-reference.mjs:274` 仍匹配旧 direct 调用；`Validate-RadianceValidity.ps1:74–76` 旧提取规则和 harness `:36,53,136–138` 旧接口不能覆盖新 overload。应让提取/依赖适配器检查实际带 footprint/float4 的主体，保留语义 oracle，不能只删失败断言或把所有参数 stub 成常量。HardwareNormals/HardwareMaterials 等应重新绑定最终来源。
3. **把已完成的 RayQueryPropagation 纳入一次最终清单。** 可作为正式必检加入，或明确保留专项证据；不要让其“已通过”游离在正式候选之外。若纳入，阶段数随清单变为 69，DXC 数由实际任务求和；改数字本身不是验收。无需为它再建立另一套独立的反例验证框架。
4. **固定新候选的实际范围。** 保持当前 alpha CPU gate 与未知处理，说明“DXR alpha 尚未实现准入”，列作原计划后续实现；不得称完整 alpha 支持。把零角度的 spatial footprint、非完整 BRDF 过滤、材质预算拒绝、每批复制和现有图生产者顺序责任写清。若本次候选必须承诺 alpha 或常见 2K 多贴图 DXR，则相应实现就是额外硬缺口，不能用测试通过代替。
5. **补原计划已有的最小运行回归产物。** 在现有生成场景上给色墙/封闭黑室/薄壁/移动门/关灯/切镜一个有限、固定帧序列和统一输出目录，包含软件/DXR模式、配置、帧号、HDR输出与日志；比较脚本可消费朋友回传图。没有参考图时标“待建立”，不要生成假通过。代码可在此机编写并做语法检查，实际执行放到朋友机；不再搭建通用遥测平台。13 的首次导入可以先开始，这项是新候选可重复回归及原计划第9项的收尾。
6. **在稳定快照上跑一次来源一致的统一回归。** 先完成上述小范围改动，再用一个既定 PowerShell 运行必检并保存真实报告。只对失败或随后改变的依赖重测；另一 shell只测脚本兼容相关差异。既有 76 个负例不必每次再扩大；不能跳过现有必检，也不能拿旧源快照的正例宣布当前通过。
7. **一次同步文档、一次封包、一次完整性核对，然后交付。** README、ProductionPlan、Research、FriendHandoff、OfflineValidation、Tests/README统一候选编号、哈希、默认开关、容量、实际支持和缺失项。保留旧归档并在START-HERE中说明哪个包用于什么测试；校验最终包文件/清单/报告一致后即交付。无需为了这一包再产生多层“审计的审计”。

完整 BRDF 角传播、纹理持久复用、面积光 NEE、形变几何与完善的流式字节/RTAS时间预算仍是原计划工作。它们应按朋友首次结果与依赖顺序进入下一实现阶段；不能在项目台账中改为已完成或永久排除。若用户要求“原计划全部功能都在测试包中”，当前缺口必须先实现；本报告不会把 13 或仅收尾的新材质包伪称满足这一更强条件。

**七、现在应停止的工作**

- 停止新增社区项目/论文/引擎源码搜索，除非用于修一个已定位阻断。
- 停止继续选择/扩张完整漫反射角度过滤模型作为本轮封包条件；保留明确未完成条目。
- 停止新建原生计时提供器、复杂统计或普适报告验证框架；现有默认关闭系统先冻结。
- 停止对未变来源反复做全套数学、双 shell WARP、旧包重封、逐层负例扩容；验证工作必须对应本次改变或具体风险。
- 停止用测试/断言数量、源哈希数量、归档轮数当功能进度；报告功能可用范围与未关闭缺陷。
- 停止一边正式回归一边修改 Runtime，及用旧“当前通过”段落包装新代码。
- 停止把缺少本机 Unity 当作研发替身无期限扩展的理由；也不要建议用户安装 Unity。

**八、朋友端必须完成、离线不能替代的工作**

先进行低成本的导入关卡，发现阻断就回传并修复，不要求朋友一开始执行全部生产压力表：

1. 记录 Unity/URP 精确版本、API、GPU/驱动、Linear/RenderGraph 配置。导入候选，建立验证资产，在 Editor 和 Player 构建中检查 C# API、shader include/变体、资源路径、keyword、UAV/MRT、native可选DLL加载。默认先软件、关闭可选身份历史和GPU反馈，取得首个可见结果。失败日志就是有效结果，不是“朋友测试没有完成所以继续本地堆测试”。
2. 用冻结场景/帧序列先验证软件传输：黑/金属零漫反射、色墙、HDR发光、关灯衰减、薄壁与凹面、移动门与显露、切镜/尺寸/多相机；保存线性HDR、间接-only、最终图和atlas/anchor。再检查 native diffuse replacement 与 baked/ambient/其他GI，避免重复计能。颜色探针核实 CPU/GPU颜色和MPB上传。
3. 在实际支持的 DX12 inline-ray-query设备启用硬件并证明确实走硬件：UV/多材质/normal/几何面向、近远场与足迹、不同shadow policy；同时测小贴图正向和3×2K预算拒绝、未知源/失效页、持续GPU积压的fallback。当前未准入alpha/Skinned应按预期拒绝记录，不能记为这些功能通过。软件/DXR差异要定位到表示/材质/合成，不能只比较平均FPS。
4. 检查图执行与资源寿命：真实producer→copy→consumer依赖、所有消费者后的fence、取消图/多相机/尺寸切换/关闭Feature、HLOD warming→published、加载卸载授权、旧页/旧回读拒绝。替身状态机不能证明这些原生行为。
5. 在功能阻断关闭后固定硬件、场景、分辨率与预算，测冷启动、热缓存、快速移动、灯/几何变动、streaming和至少现有表要求的30分钟长测；记录GI分阶段及应用GPU中位数/p95/p99、CPU准备/上传、峰值显存/RTAS与持续增长。编译秒数、WARP耗时、逻辑字节都不能填这些结果。生产门槛数值由真实目标确定，不虚构预算。

第1–4步使测试候选有运行反馈；第5步与尚缺实现共同决定生产范围。朋友端测试可分批进行，但十项原计划的最终欠项仍须逐项关闭。

**九、置信度与取证限制**

对“有交付漂移”“13与当前证据不同”“当前新候选未统一通过”“alpha准入关闭”“全mip float4预算边界”“朋友/生产放行必须分开”的结论为高置信度：分别有本地源码、实际报告、归档字节和公式支持。对十项模块完成程度为中高置信度：读取了权威计划/研究/交接/验证文档及相应实现路径，但没有逐行复审全包。对实际画质、性能、驱动行为、URP API可用性不给通过判断；本机无Unity/实体GPU验收，这是取证边界，不是功能不存在的证明。

本审计没有重演外部社区仓库审读，也无法仅从文件准确还原每次历史授权与延期动机；因此没有把所有新增研究/测试判为错误。对比所用当前关键哈希：Feature `CDA09765F3D02AF42589805A94A5193F2AA7BFB56890D35268241D6C1C9A2919`；Transport `AE16F46F9A6B00F99CF4E265E936ED7F921E1F219BF7A6C9CB31B0140C061D97`；Kernels `17091D05B7553ED636D5DEFF4CF509C4F030144E45505BC1D0C1322CCA4095D6`；HardwareTrace `6F0B544FC968693C5851137ADC14C6276F7467983D25D8425EBA0D78B28FCF7B`。后续修改应以新证据更新状态，不沿用本报告快照结论作为自动放行。
