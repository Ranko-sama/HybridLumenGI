# 原计划剩余任务 TODO

本表基于 [ProductionPlan](ProductionPlan.md)、[运行验收要求](Validation.md)和[当前推进表](DevelopmentProgress.md)，保留原四项目标、十条工作流及 G0–G5 范围。用途是安排剩余工作，不把未验收项判成代码缺陷，也不把有限交付判成总目标完成。

G0 本机基线已锁定。原第 6 节 G1 传输与 G2 几何的本机代表性验收已通过，G3–G5 及第 8／9 节专项保持开放。T1 已完成，T2–T7 的其余条件继续推进。[G1 采用依据](ProductionPlan.md#g1本机代表性传输验收裁决) · [Release143 同源交付](../LocalComparison/Review/empty-cache-patch-budget-160/delivery.json)

T5／T6 已修复已有回读确认的空格占用逻辑照明名额。实际 C# 回读与调度对照保持原公平份额和就绪门，代次变化后重新准入。高速冷入首显及正式预算各自待验收。[功能对照与边界](../LocalComparison/Review/empty-cache-patch-budget-160/result.md)

T6／G4 已补上接收面发现及重验的累计 CPU 时间准入。现有准入保护处理不完整扫描，原生替换与对象历史依据按各自入口拒绝。单次 Unity 调用会完成，其他 CPU 阶段和完整生产预算继续验收。[范围与实际源码对照](../LocalComparison/Review/receiver-discovery-budget-159/result.md)

T6／G4 已关闭重复新请求使久等页拿不到启动机会，以及在飞的纯预取依赖抬高后续依赖优先级的问题。实际 CPU 驱动与受控 I/O 通过各自反例，修复进入 Release139。原生资源竞争和整体预算按原条件验收。[启动顺序对照](../LocalComparison/Review/streamed-page-priority-156/result.md)

Release138 关闭 T2 无足迹时已知标量透明仍形成遮挡，以及 T6 收紧启动预算后历史页成本阻止新组两处缺口。两种精确后端的已知覆盖／未知纹理实机对照与分页 CPU 受控 I/O 各自采用。实际混合后层、高速冷入及生产负载继续按原条件验收。[两项对照与边界](../LocalComparison/Review/exact-footprint-and-page-admission-155/result.md)

T5／G4 已关闭粗根未绑定时完整细节仍被统一示例挡在准备阶段的问题。实际分页与受控回执验证组完整性和提交资格，修复已进入 Release137。Release110 高速路线中粗根已绑定，实际预热中断和首次完整表示空档继续按原条件处理。[近景准入对照](../LocalComparison/Review/cold-detail-admission-154/result.md)

T6／G4 已关闭无后续渲染上下文时启用绑定的普通需求撤回缺口。固定页组在受控消费者放行后无需新需求边沿，经真实空闲栅栏排空。修复已进入 Release136，T5 高速首显及更广负载继续按原条件验收。[空闲退休对照](../LocalComparison/Review/idle-demand-retirement-153/result.md)

T6／G4 已关闭 Base 相机切换 Renderer 后旧消费者滞留的问题。真实 DX12 双 Base 自动渲染中，仍使用旧 Feature 的相机保留页，最后一台切走后经现有栅栏释放，页账目归零。修复已进入 Release135，普通 Player、多组压力和 T5 高速首显仍开放。[退休对照](../LocalComparison/Review/renderer-switch-retirement-152/result.md)

G4 已修复默认独立分页 rig 的普通组显隐。实际 DX12 双 Base 显式请求复现并消除了粗根与细节同画，完整旧根等待、两相机选择分歧及停叶撤回按原门槛成立。CPU 回归覆盖相机错过解绑重绑后的代次拒旧。修复已进入 Release134，冷高速首显与双相机资源退休负载仍开放。[对照及验收边界](../LocalComparison/Review/independent-hlod-raster-151/result.md)

G4 已关闭已发布 HLOD 成员重挂后被旧组扣留的资格缺口。实际 Scene CPU 回归确认无效组整组退出，目的组可在旧粗根等待时按原回执发布。撤回后退回预热的成员需要重新取得照明回执。修复已进入 Release133，T5 高速首显仍开放。[组成员与验证范围](HlodStreaming.md#atomic-hlod-transactions)

T3／G3 已关闭同一 `sharedMesh` 收到明确内容变更通知后仍消费旧自动快照的资格缺口。实际组件 CPU 回归覆盖撤回、旧作业取消、模拟完成和当前版本恢复，修复已进入 Release132。原生 GPU 生命周期及形变画质按原条件验收。[内容版本与回归范围](DeformedGeometry.md)

T6／G4 已修复资源驱动在零启动配额下销毁后阻塞接管的问题。实际组件 CPU 回归覆盖 `startsPerStep=0`、已有逻辑 I/O、旧租约等待安全完成和后继驱动接管。回归使用适配器，修复已进入 Release131，原生条件按原计划验收。[生命周期与回归范围](IndependentAssetPages.md#publication-and-lifetime)

T3／G3 已关闭相机回调中同帧换源或清空后继续消费旧快照的资格缺口。相机准备撤回旧来源，实际组件 CPU 回归覆盖取消、模拟栅栏退休及后续恢复。修复已进入 Release130，原生退休和画质仍各自验收。[源码行为与回归范围](DeformedGeometry.md)

T2／G4 已修复精确命中限制搜索距离时，体素细化可能越过 SDF 末段的错误。Release129 的同输入 WARP 回归恢复近端 signed SDF 命中，保留真正更近的精确命中、完整空区间与预算耗尽的未完成状态。精确三角结果由受控输入提供，整体混合回退、纹理和实体 GPU 条件继续验收。[修复和原始读回](../LocalComparison/Review/sdf-clipped-interval-146/release-notes.md)

G4 已修复独立分页导出中细节分批绑定可提前发布的问题。Release128 在实际 Scene CPU 回归中保持有效粗根，全部细节满足原回执后原子接替。粗根未绑定时，单件等待，完整近景仍可按原距离规则发布。Astra Max 同意按此范围采用。实际异步到达、独立导出 rig 的普通 Renderer 组显隐及统一示例的高速冷入仍分别验收。[修复和证据边界](../LocalComparison/Review/streamed-hlod-membership-145/release-notes.md)

T6／G4 已修复资源页驱动销毁后，活动绑定因需求冻结而无法交回租约的问题。Release127 的实际 C# 回归确认仍有效的绑定保留，需求撤回进入原安全退休门，完成后排空并由新驱动取得所有权。I/O 和读者完成使用适配器，原生空闲退休沿用固定粗根的独立结果。Astra Max 同意在该范围采用。[修复与验证范围](../LocalComparison/Review/streamed-driver-withdrawal-144/release-notes.md)

G4 已修复统一示例旧组在成员撤回、销毁或重绑后仍能部分提交的问题。Unity 无图形观察验证真实绑定下的 Renderer 显隐和代次拒旧。完整旧组在等待新目标时继续可见，匹配新代次的完整回执可以恢复显示。照明完成回执为受控输入，实际相机与高速冷入仍各自验收。Astra Max 同意按此范围采用，修复已进入 Release126。[修复说明](../LocalComparison/Review/streamed-group-visibility-142/release-notes.md) · [原始状态](../LocalComparison/Review/streamed-group-visibility-142/result.json)

T6／G4 已关闭固定粗根在最后一次相机提交后的实际空闲退休子项。Release125 加入明确停用后的空闲路径。Release126 同源 DX12 Editor 实测中，停用后零新渲染上下文，真实空闲栅栏完成后 6 个页引用及包、驻留和在途账目归零。普通 Player、多组和在飞读者的实机范围仍待验收，整体 G4 保持开放。[实机结果](../LocalComparison/Review/streamed-idle-native-143/result.md) · [资源生命周期](IndependentAssetPages.md#publication-and-lifetime)

T3／G3 修复了同一个 SkinnedMeshRenderer 换网格或清空来源后，旧快照仍可留存或由后台作业重新发布的问题。实际组件 CPU 回归覆盖撤回、取消、新来源恢复与完成票据后的退休。Astra Max 同意按该功能范围采用，修复已进入 Release124。原形变画质和真实 GPU 退休仍各自验收。[修复与范围](../LocalComparison/Review/skinned-source-replacement-140/release-notes.md)

2026-11-08 已恢复 Unity Personal 授权并关闭 G3 的固定两室关门恢复子项。修复隔离门跳变后的旧递归照明，两期限前的残留降为 2.637% 和 0.214%，符合原保持要求。Release122 的未通过基线和首个因 SDF 留边未触发的候选一并保留。[两室关门结果](../LocalComparison/Review/portal-recovery-138/result.md)

T2／G4 已关闭第 9 节的静态镜像双子网格精确剔除与远层命中子项。Release123 同源软件 BVH 与 DXR 分别符合预定来源面向、身份、距离和颜色。T2 剩余纹理、混合回退及其他原专项仍开放。[镜像子网格结果](../LocalComparison/Review/mirrored-submesh-cull-139/result.md)

## 当前优先级

| ID / 优先级 | 类别与关卡 | 剩余任务、完成条件与当前边界 |
| --- | --- | --- |
| T1 / 已完成 | 交付整合 · G5 | 已将接受的稳定回退历史修复交给下载用户。普通 Release122 从同源工程 ZIP 的干净解压目录构建，Windows 包、可编辑工程、版本来源和已有测量边界配套交付。未追加画面、计时或压力运行，不新增画质放行结论。[交付记录](../LocalComparison/Review/stable-fallback-history-01/delivery.json) |
| T2 / 高 | 后端材质专项 · G4／原第9节 | 原第6节G1代表性传输验收已完成，不再以未证明任意场景／所有像素准确性阻断该关卡。本项继续处理原约定的软件／DXR差异及尚未覆盖的alpha／Cull、纹理和混合回退专项。直接复用[88同输入2ray／filter3四时点软件／DXR画面](../LocalComparison/Review/release88-dxr-motion-01/result.md)与128实际二值候选遍历，不把88结果升级为122／filter4全域通过，也不将缺少新版本成对记录自动当成新运行理由。保留SDF／解析近似边界。只补会影响放行决定的具体原合同缺项，发现可归因错误才修复，不顺次生成材质排列或重启严格误差证明。[G1采用裁决](ProductionPlan.md#g1本机代表性传输验收裁决) · [原材质边界](ProductionPlan.md#9-命中身份背面策略与面积光-nee-的边界) |
| T3 / 高 | 动态质量与支持边界 · G3 | 112规定门／灯／切镜已有功能记录，126／127／129／134各自合格域的残留／恢复直接复用。固定两室关门的恢复、无图卡 BaseMap 换色通知及匹配贴图回读待定的整体回退已关闭。门颗粒取舍已收束，其他原约定光路、普通 Player、形变质量及延迟范围继续开放。骨变拒旧、停稳恢复和完整异步快照已实现，135补有限成本和 CPU 观测帧龄。126／127按实际棕墙配置使用，全白未验证。当前证据记录存储历史和末端滤波的有效性边界。[四问及原范围](../LocalComparison/Review/dynamic-picture-comparison-01/report.md) · [关门修复](../LocalComparison/Review/portal-recovery-138/result.md) · [无图卡换色](../LocalComparison/Review/cardless-material-157/result.md) · [贴图等待](../LocalComparison/Review/pending-exact-texture-158/result.md) · [形变边界](DeformedGeometry.md) |
| T4 / 中 | 世界表面专项验收 · G2 | 关闭尚未覆盖的材质／UV 接缝、镜像变换、图集／锚点及池复用身份问题。已有三室、薄壁、凹口、离屏纹理、内层和正比例非均匀缩放结果直接复用。一个保存重开后的静态两槽 Point／无 mip 接缝已有图集及锚点子结果，但该次四条 binding 返回数值未写入，完整冻结合同仍证据不足，不自动补采或宣称整体 T4 通过。专项要能判断正确来源与覆盖，不能用总 ready 数代替。出现具体反例时才改实现。[原条款](ProductionPlan.md#8-真实可变表面-charts已接入与剩余验收) · [接缝范围及缺失记录](../LocalComparison/Review/material-uv-seam-01/result.md) |
| T5 / 中 | 已知使用限制，原因未闭合 · G4 | 处理冷高速入场的首次完整表示空档，或据原验收条件明确其仍未通过。实录显示预取已生效，完整绑定及照明发布仍需等待。区分路线中尚未就绪的粗根与下文源码中的已就绪粗根。原完整组门槛和容量约束继续作为采用条件。[已有冷入结果](../LocalComparison/Review/cold-aggregate-prefetch-01/result.md) · [等待与回调间隔](../LocalComparison/Review/outside-group-visibility-01/result.md) |
| T6 / 中 | 资源、规模与预算能力及验收 · G4／G5 | 在已承诺平台与原规定负载内闭合资源生命周期和预算判断，复用已有双 Base 相机隔离、30 分钟流式运行、域重载清理及后端退休结果。默认活动Skin已补原小网格、已预热且观察开启的同窗预算／Present，不再将这一条件列为成本未知；其他负载边界保留。只处理会改变放行决定的冷／热、高速、流式或高更新负载缺口。全阶段时间预算尚未完成：当前反馈只缩放 patch／capture／brick 数量，不能等同于 CPU 准备、上传、RTAS 等所有阶段分别受时间预算控制；缺失能力须对照原目标处理，不新造预算／验证框架。验收仍用 960×540／30FPS、GI 三段逐帧合计 p95≤25ms、进程 local 有限采样峰值≤1GiB，记录 p99、nonlocal 单列；不混淆 Present、GI 时间和显示帧率。[原调度目标](ProductionPlan.md#5-streaming-与预算) · [目标与现有窗口](GpuBudget.md#当前已确认的起始验收目标) |
| T7 / 最后 | 支持范围与最终放行 · G5 | Release143 提供同源运行包和工程包，沿用已交付的离线画册。继续汇总 T2–T6 在承诺平台上的有界结果，完成剩余生产放行。CI 暂缓，整体 G5 保持开放。[支持主表](ProductionPlan.md#当前支持范围与证据层级) · [离线画册](../LocalComparison/Review/picture-comparison.html) |

这些是当前优先级，不是严格串行依赖。T2–T6 也不是一次性展开的测试矩阵。开始任何新观测前，先明确它能改变哪个采用、修复或放行决定；不能改变决定的观测不做。仅在必要时更新对应产品与证据，不新造验证系统。

T5 现有记录确认了统一示例在加载带入口的一帧绑定延后。Release110 第 306 帧写入粗根请求时 8 页已就绪，第 307 帧才绑定。示例的 `Update` 在流式表示消费需求之后执行。粗根仍在可见边界外绑定，首次完整表示空档保持未通过。[冷入折返与实际记录](../LocalComparison/Review/cold-aggregate-prefetch-01/result.md)

同一记录的第 307–309 帧已绑定粗根，40 单位可见门仍挡住预热，第 310 帧才进入 Warming。第 316、320 帧实际回读均因同一覆盖 patch 的可信样本数不足而拒绝。记录无法区分缺少第二次调度与更新返回未知。第 320 帧目标切到细节，已开始的粗根预热随之撤回。第 308／309 帧分别已有 2／8 个其他发布对象和 192／256 个缓存 patch 更新，空域预热候选仅覆盖第 307 帧。Astra Max 保留原发布界、照明就绪和共享预算作为采用条件。[实际路线](../LocalComparison/Review/cold-aggregate-prefetch-01/result.md)

源码还允许另一条时序。粗根的完整就绪票据在相机准备前到达，细节恰好成为新目标且尚未就绪时，发布只检查细节，已就绪的粗根也会撤回。保留粗根会占用一份代理槽及图卡额度，细节恰满时可能无法开始整组准备。此时序在源码中可达，Release110 的第 320 帧仍是粗根票据不足的实录。两种情形分别保留，采用仍以首显与完整切换能同时推进为条件。[目标与容量门](../Runtime/HybridLumenGIScene.cs) · [实际路线](../LocalComparison/Review/cold-aggregate-prefetch-01/result.md)

Release110 预测带的 8 页在第 15 帧、路线约 0.04 秒已 Ready，第 307 帧才完成绑定。第 307→308 帧实际从 SDF／解析切到 DXR，早于这次切换的照明及回执会作废。现有预热排在普通对象槽位之前，直接加入界外粗根也会争用图卡和工作额度。Astra Max 据此收束界外准备候选。恢复时沿用原路线，比较首次完整表示、最终细节接替和预算，保留原可见界及照明门槛。[实际路线](../LocalComparison/Review/cold-aggregate-prefetch-01/result.md) · [实际后端切换逻辑](../Runtime/HybridLumenGIRendererFeature.cs)

## 用户已暂缓或已收束的工作

- **2026-11-04离线画册整合：已完成本项交付。** 在原静态入口复用现有原图与读数，已单独附加日期补充包到Release122，产品版本不变。D／Final、输入描述偏差、控制不足和未观测范围可见；浏览器可视检查因本地URL策略未完成，文件准入不当作显示验证。Astra同意交付后收束，不追加新图／运行／框架或G3整体通过结论。[交付记录](../LocalComparison/Review/picture-delivery-20261104/result.md)
- **原第6节G1代表性传输验收：已完成。** 133关闭当前颜色依据缺口后，既有代表参考、合成及能量／关断结果可按原范围支持采用。Astra与独立审阅未再指出应阻断此关卡的具体行为；撤去泛化“全域准确性”的阻断理由。原版本／域／不确定性、协议状态及第8／9节专项继续保留，不新增G1观察。[逐项依据](ProductionPlan.md#g1本机代表性传输验收裁决)
- **同GI尺寸的full resize观察：本项不足后结束。** 唯一136运行的实际GI由820×460变819×460，冻结959×539不变条件未实现，原定G3子项仍开放。原预算约束的执行前估计疏漏不改写为产品bug；现有年龄只支持这一次full与GI共同变化后的重置／新累计，不能归因full尺寸识别。不调预算、回切或补跑。[实际记录](../LocalComparison/Review/resize-history-136/result.md)
- **默认活动Skin成本：本项结束。** 当前122同源普通测量Player的已预热K+Space／24顶点／2骨窗口，GI合计p95为17.088ms、local有限采样峰572.004MiB，达到起始预算；同次Present支持该负载30FPS方向。新CPU快照捕获到首次观测帧龄p95为11帧，只关闭该条件的成本和CPU观测等待未知，不是BakeMesh耗时、逐渲染帧年龄或GPU延迟。可选截图未交付，形变质量、其他规模与完整T3／T6仍开放；不补图、重跑或扩大压力范围。[结果](../LocalComparison/Review/active-skin-cost-01/result.md)
- **原红墙反射率换蓝恢复：本项结束。** Floor独立控制合格，当前Runtime均值在1.142–1.654秒形成保持窗口，后续至2.612秒未越线；White控制波动9.03%超过冻结5%，其恢复不足，整体合同不能判通过。不延长前史、扩大ROI、改阈值或补采，G3仍开放。[结果](../LocalComparison/Review/reflected-color-response-01/result.md)
- **归档119两ROI颜色观察：本项结束。** 当前122同源Runtime直接复用原归档物理输入及有限参考，名义满足既定亮度／色向／MAE目标，unknown与MC边界保留；仅关闭该当前Runtime样点，不扩大为普通三室、960×540／Player或完整G1，不补时点／后端／参考。[结果](../LocalComparison/Review/archived-runtime-color119-01/result.md)
- **单页两源复用观察：本项结束。** 身份／代次、完整binding、独立覆盖和旧anchor清除子项符合预期；位置误差已测超过冻结2e−5，因此完整合同未通过。不是数据缺失，不自动补采或改阈值，整体T4仍开放。[结果](../LocalComparison/Review/card-page-reuse-01/result.md)
- **CI 接线：暂缓。** 不自动配置远端执行机器、Unity 许可或工作流；条款保留未完成。
- **扩大严格误差证明范围：暂停。** 保留已有参考及不确定性说明，不把更复杂的证明系统作为判断产品的前置依赖。
- **门运动调参：本节点结束。** 保留 2 射线／4 级滤波及同曝光四时点的有限判断。此前候选的门运动取舍记录仍有效。Release141 依据另一次实际换色回退采用纹理等待修复。[采用范围](../LocalComparison/Review/pending-exact-texture-158/result.md)
- **本机基线、G2 代表场景、现有长时运行和已有迁移说明：复用。** 不仅因文档里的历史“待验收”字样而重复执行。

## Astra Max 审查

2026-11-04，Astra Max 建议修订后交付。已按意见将后端材质并入 T2、资源与预算并入 T6，将原九项合并为七项；把放行判断限定于原承诺支持域，补记跨形变历史与全阶段时间预算的能力限制。

审查明确：清单不等于批准自动执行新测试；ProductionPlan 第 9、10 节过时的“原生未执行／朋友验收”不能直接生成待办；门运动、已有长时与后端证据继续复用。CI 与严格证明扩展维持用户已定状态。审查只负责范围和推进判断，没有新增开发方案或验收标准。

T1 整合阶段的补充审查：第 5 节全阶段时间预算的限制不自动成为下一开发项。独立额度、反馈接口、CPU 捕获时间门、上传和 RTAS 准入已有实现；只有出现具体可达的无界工作、饥饿或预算失效依据，才选择其中一项补齐，不再泛查预算旋钮或扩建全局调度框架。

T4 镜像真实图卡的有界核对已结束：当前 `M d` 投影定向和 `M^-T Ng` 源法线关系对可逆的负行列式变换同样一致，未发现新的计算或准入矛盾。Astra Max 建议不把旧折面变号再跑几个点，也不转开六面 VFACE／Cull 测试。本项没有运行或产品改动；负缩放的原生专项仍未独立确认，整体镜像验收继续开放。

2026-11-04，用户授权主线程参考 UE5／相关项目的技术资料，自主决定画质口径，原等待用户误差数字的依赖已解除。[起始工程判据](QualityAcceptance.md)已参考 Epic 官方、生产 DDGI 论文和 NRD 官方资料制定，并经 Astra Max 审查：保留明确的颜色、残留与响应目标及测量范围，不将工程阈值冒充外部标准。后续自主按判据推进；CI 与扩大严格证明继续暂缓。

T3 的既有绿转蓝事件已补源帧时间，Astra Max 允许按实际观察范围交付并收束。1.000209 秒旧绿均值为 0.0429214%，2.000477 秒输出 G 全零；仅关闭该观察缺时间锚点的信息缺口，不外推普通目标帧率、最终新颜色或整体 G3，不自动补跑。[结果](../LocalComparison/Review/timed-green-response-01/result.md)

T2 已关闭一个普通 Additive、运行时 `_AlphaToMask=0` 的二值 cutout 屏幕覆盖合同：同帧原生深度与 GI 捕获深度一致，孔洞正确露出背板。未关闭默认作者 flag 1、smoothness-alpha、Replace、DXR alpha 或 Player；准备失败和有效观察分别保留。Astra Max 同意收束，不新增材质矩阵或构建。[结果与范围](../LocalComparison/Review/ordinary-cutout-coverage-01/result.md)

默认作者 flag 1 的后续源码核对未发现材质准入失败：它只使屏幕身份历史保守拒绝复用，普通材质快照和其他 GI 路径仍可接纳。Astra Max 建议纠正误读后停止，不为尚无可见问题的资格优化增加 API 例外、运行或发版。本核对不新增关闭原计划的验收缺口。

T2／G4 已补齐一次静态普通 Lit 二值 Point／无 mip 的实际软件／DXR 候选遍历：真实就绪材质页下，透明前格正确露出蓝后板，实心前格仍命中红前板，源 UV／三角／身份和材质符合独立预期。首次观察入口保留字编译失败及误置的执行标记不采用，Astra 允许一次同输入更正后实际通过。只关闭该具体缺口，不扩大为完整 alpha／Cull、阴影、Feature／Player 或 T2 整体；不改 Runtime／发版。[原始结果与范围](../LocalComparison/Review/binary-alpha-traversal-01/result.md)

T2／G1 及 T3 补齐已有封闭室“先有可信间接光→唯一点光关闭”的九点衰减子项：1／2秒前旧绿均值0.04606%／0.004056%，后续保持，末端实际filteredD有效。复用已有房间及122质量设置，没有改白重跑127或推广到任意房间；worldcache、fresh raw及中间filtered仍未直接观测。Astra同意按该事件收束，原准备／解析失败保留，不改Runtime／发版。[画面、结果及未证明事项](../LocalComparison/Review/sealed-room-decay-01/result.md)

G1增量复核：继续复用白炉、黑／金属、色墙、合成和衰减成果，不合并为全支持域通过。T2现补齐一次原列metallic／specular标量／map固定网格的实际普通Win64 Player合同，出射与独立单位环境参考符合；不是仅有函数结果，也不是世界hit／DXR全部材质通过。原承诺输入组合仍有范围缺口，例如alpha／smoothness-alpha联合覆盖；协议差异不自动生成下一材质行或补跑任务。Astra同意采用并结束本项，不改Runtime／公开122。[关卡判断、结果及边界](../LocalComparison/Review/player-material-workflow-01/result.md)

后续131已关闭上段当时指出的限定alpha／smoothness-alpha联合Player覆盖：原生checker／全实区别符合独立预期，GI深度同帧逐点一致，runtimeAlphaToMask0／单采样范围保留。Astra将G1推进为“第6节基础合同在已有本机代表输入上具有限通过依据”，本轮材质观察结束。完整G1的实质边界是声明支持域的静态颜色／能量准确性；300帧／双端记录等未完整协议另列，不与产品缺陷或新测试任务画等号。A2C／Replace等未证范围不自动追加为新前置。[131结果与关卡裁决](../LocalComparison/Review/player-alpha-smoothness-01/result.md)

T4的132单页复用经Astra审查按子项收束：实际身份／代次、源覆盖、binding及旧锚点清除可采用；A／B位置误差超过预先2e−5容差，完整冻结合同明确未通过，点仍在形状内不能替代精度达标，也不足以归因产品错误。保留原状态与阈值，不增加运行。A请求pending仅为请求状态，不证明GPU实际读写重叠或任意同步安全；不扩大到HLOD／transport或整个T4。

T7的当前说明整合经Astra复核后收束：原支持主表与README已分清122交付来源、各历史观察和未放行项；133／132及分开的预算窗口没有被升级成整体通过。126／127须按约29Hz连续显式请求而非普通Player性能理解，响应／收敛继续按既定工程判据，不新增数学精确收敛前置。本轮只关闭支持说明过时、边界分散的交付缺口，不新增构建、测试、远端核验或归档体系，T7整体开放。

135默认活动Skin阶段经Astra复核采用并收束：只补T3／T6中已预热默认网格、观察开启时的有限成本及新快照首次CPU观测帧龄，不能外推逐像素有效性或几何实时跟随。约76秒首次camera回调、截图不可用和provider pending2分别保留，不写成启动、画质或退出清理通过。当前没有新事实支持另开功能修复或必要运行；不扩网格、补截图、诊断该启动等待或重建公开122。原T2–T7与G1–G5未完成状态不变。

G1代表性裁决后的T2去重：Astra指出已有88同源、同场景与前史的2ray／filter3软件／DXR149／179／189／209四时点画面，主线程已读原报告和comparison记录确认。两侧执行失败／后端不匹配均0，原720前缀failed状态保留；已有采用结论并非当前所有后端等价。没有新的具体差异或相关变更依据，本轮不补122软件前缀，不以刷新版本为由重开133颜色线。
