# 本机开发记录

2026-10-27，用户明确取消当前朋友交付任务，直接在本机继续开发。冻结的 `runtime-candidate-16` 及其交付 ZIP 保留为历史基线；不再以等待朋友反馈作为开发停点。

## gpu-cost-baseline-01（2026-10-28）

`e1aa6356` 增加默认关闭的独立成本观测和有界完成记录导出。唯一新Development/Mono/DX12构建及实体RTX2080Ti运行完成688帧，其中固定512源帧全部通过实际NativeDX12身份/ticks校验；静态配额不变，反馈关闭。Transport中位19.694ms，三范围和中位19.853ms/p95为21.483ms。Astra接受有限结果，实际GPT6 Pro22已接受有限证据。此数据不覆盖应用总GPU时间、动态/Release尾延迟或峰值显存，下一步聚焦Transport内部归属。

实际构建的插件误保留Linux/macOS导入勾选，原件已归档；本地元数据和未来builder在运行后修正，没有重建或改写原证据。Windows DLL与本次测量不变。详见[结果和范围](../LocalComparison/Review/gpu-cost-baseline-01/result.md)。

## current-player-shutdown-01（2026-10-28）

用户澄清中间暗区只是疑问，尚无具体故障证据；已取消继续暗区归因，不因旧复审计划自动恢复。转向原计划明确缺失的当前源码 Player 验证。

`d8eb7be` 保留当前源码构建通过、可见软件 Player 退出失败，以及独立探针尾帧覆盖问题。`3088d41` 采用较小的保守修复：在当前 PlayerLoop 根尾部补真实渲染外边界，沿用原有 fence／所有权规则，不改 Application.Quit 或退出码；探针在采集结束前关闭，并绑定唯一帧收据和不可覆盖的 payload。

唯一新软件 Player 在 Unity6000.0.85f1／Windows／Development Mono／DX12 完成120帧、5份有效HDR、零采集错误。第119帧原始moments与统计／哈希／帧身份一致，历史上限32；原生日志确认两父票及七子票分别提交并完成，全部项目owner计账归零，没有旧回收／GC buffer／D3D未释放告警。Astra结果审查无阻断，实际GPT6 Pro已接受较小修复及本次有限验收，并给出同构建单次DXR计划。详见[本轮结果](../LocalComparison/Review/current-player-shutdown-01/result.md)与[Pro复审](../LocalComparison/Review/current-player-shutdown-01/gpt6-pro-review-and-next-plan.txt)。

随后current-player-dxr-smoke-01复用同一283份产物，唯一DXR Player同样通过120帧、实际22硬件mesh/零覆盖缺口、GI读回/5份HDR和正常退出。Pro21接受该有限证据，下一包为gpu-cost-baseline-01，分离只测量与预算反馈后取得固定工作量成本。任意外部Quit／关窗、异常scratch、长时增长、总显存、完整画质与性能仍未验收。Unity原生退出汇总保留，不归因GI或冒称总内存零泄漏。

## cache-failed-result-01（2026-10-28）

Pro第9轮批准后提交 `1b8e751`。实际HLSL反例证实：缓存支持权重为2^-18时，lookup返回false却留下部分结果，world端点继续加入该值，screen包装器则返回零。仅在低总权重失败分支清零完整结构；真实Unity回放保留直接光、发光与confidence，其余五个控制输出逐字节相同。六个完整受影响入口通过固定DXC环境编译；这不代表实体DXR或完整Unity变体验收。详见[审查入口](ReviewBrief-CacheFailedResult01.md)。

此前 `507e52d` 保留实际gather消费与225次缓存可见性查询的观测：受测偏移查询与独立三角参考一致。无偏移物理连接的17项差异均处在边界歧义区，不能据此宣称漏光修复。`3c12a87` 修复退出进度检查的fence状态竞争，并通过对应定向证据；旧失败日志仍保留。

独立两节点缓存能量与关灯衰减参考已获Pro第10轮批准。运行前冻结数学输入、有限轮答案与舍入界；唯一512轮Unity批次最大绝对误差约2.70e-7，所有逐轮合同和原生退出检查通过。该结果仅覆盖理想算子每轮更新条件，不证明真实场景收敛或预算公平性。详见[复核简报](ReviewBrief-CacheEnergyDecay01.md)。下一包为真实单点光C场景的360帧关灯链，120帧关闭真实Light，观测事件、变化域、调度、cache及gather。原计划四项目标、十条工作流继续开放。

## local-development-resource-shutdown-01b（2026-10-28）

GPT-6 Pro已批准保留并本地提交（代码提交bd5a7d2）。实际缺陷是Feature和形变快照在最后可用context之后才转交退休。修复提前关闭会话准入并撤销owner，保留旧pass/state直到真实fence完成；材质批次、纹理池与形变任务仍使用各自完成条件。未知提交、清理失败和未完成任务保留所有权与计账。

定向源码测试及有限Unity运行支持：默认域重载下两次自然Play退出、一次重新进入，以及独立直接Editor退出均成功。36+21张旧域票据逐项实际提交、fence passed后恰好一次销毁；纹理arena、形变快照及通用buffer分别归零，无此前归属的泄漏/观察器错误。实机后另修普通取消任务清理异常时丢失Job所有权，仅有定向actual-source回归证据；执行版本与当前版本哈希明确分列。详见[本包审查](ReviewBrief-ResourceShutdown01b.md)和[Pro原文与下一计划](../LocalComparison/Review/resource-shutdown-01b/gpt6-pro-review-and-next-plan.txt)。

Player、禁用域重载、退出时在途worker/readback、Recorded/Quarantined批次、设备故障、长时增长和总显存/性能继续开放。原始失败工件保留。下一包thin-wall-transport-01先做有限阶段归因与独立线段/薄板可见性控制，只有明确反例才改算法。

## local-development-denoise-03（2026-10-28）

已在4610cc2提交短历史滤波连续过渡，Pro批准范围仅为3→4突变改善。固定门事件的3→4 RMS改善约19%，整个恢复窗口最大相邻RMS仅改善约0.31%，不能混称整体闪烁改善19%；合成噪声在历史2/3有代价，持续reactive或maxHistory=2/3时可能持续。详见[审查与量化边界](ReviewBrief-Denoise03.md)。

## local-development-denoise-02-contracts（2026-10-28）

已修复 HDR 时间矩存储与调试语义，GPT-6 Pro 已批准此局部合同修复本地提交。两张 moments 改为 RGBA32F，预算每 GI 像素增加16字节；SpatialVariance 保留枚举值3，以 `v/(1+v)` 显示。滤波公式和空间方差上限不变。

本机旧 half UAV 将 `1000²` 饱和为65504，没有复现先前推测的 Inf／历史拒绝；问题应表述为 HDR 二阶矩失真。修复版两条 temporal 入口实际连续读写通过，5条旧例和277条GPU阶段记录通过相应合同，其中200条只是R1/R2诊断有限性检查，不能称为画质通过。预算测试通过，109个产品文件与Unity工程一致。详见 [本包审查入口](ReviewBrief-Denoise02.md) 与 [证据](../LocalComparison/Review/denoise-02/validation.json)。

固定合成输入已复现历史3→4时滤波输出跳变，下一包需据此决定连续过渡方案；跨平面因果贡献仍需匹配控制。真实动态、薄壁、资源退出与生产验收继续开放。本包未重跑420帧场景或Player。

## local-development-denoise-01（历史记录）

修复对象是移动接收面、切镜和显露后的短历史 GI 降噪。不是增加新的光传输功能，也没有调整间接光强度、每像素射线数或多次反弹。

GPU 诊断：移动门帧179的固定内部选区 `(340,144)-(400,250)`（640×360最终画面坐标）中，77.36%的GI像素历史长度为1，时间方差中位数为0。原滤波器把单样本的零方差解释为低噪声，亮度权重因此拒绝邻居，保留了明显斑点。

`CSTemporal` 复用已有3×3邻域，记录同表面的亮度空间方差。邻居须满足有效测量、双法线、材质和绝对平面距离条件；不按亮度相近程度筛掉噪声。`CSFilter` 在历史不足4帧时，用空间方差补充时间方差。参考 [SVGF 的时空方差思路](https://research.nvidia.com/labs/rtr/publication/schied2017spatiotemporal/)，这是当前滤波器的局部修复，不是完整复现论文。

Moments纹理合同现在为 `xy=时间亮度矩，z=历史长度，w=空间方差`，w不再保存历史接受标记；历史有效性仍由原来的几何、身份、变更域及正样本数检查决定。空间方差最大存为65504以避免RGBA16F溢出；这只限制滤波尺度，不夹取辐射亮度。不新增纹理或渲染pass，不把无效中心像素用邻居填成有效GI。

本机GPU定向回归运行真实 `CSTemporal`，覆盖已测黑色、单帧噪声、高亮邻居的半精度上界、分离平面、未知中心。测试和图像采集的来源、运行范围及最终指标见 `Tests/local-development-validation-results.json`；未完成的项目不由该结果替代。

最终本机结果（Unity 6000.0.85f1 / URP 17.0.4 / DX12 / RTX 2080 Ti）：5项GPU检查全部通过；最终Editor按预定420帧完成，21张HDR、零采集错误。该短序列在run.json中明确标为 `incomplete-probe`，不是完整720帧验收。诊断基线只运行180帧；初次修复及加入半精度保护后的最终修复各运行420帧。旧版、off、SDF、流式和Player未重跑。

第179帧灰板固定内部选区的邻域高频残差RMS从0.033342降为0.010900（降低67.31%）；平均线性亮度从0.348418变为0.344185（-1.21%）。第119、179帧的滤波前GI历史逐值相同，设置、相机、灯光和门位姿一致。该指标说明单帧斑点减少，不能代替时间闪烁/残影或物理真值误差。最终运行首次出帧335.44秒，包含重新编译和驱动初始化；启动问题仍未关闭。

最终运行：`I:/Unity test/Comparison/Results/20261027-153457-43786b6cdf404df0bb43c9a24eafbb03`。前后图与来源记录：`I:/Unity test/Comparison/Evidence/local-denoise-01/comparison.html`。109个产品源码文件与实际Unity工程逐一匹配，相对16版仅 `HybridLumenGIKernels.hlsl` 改动；当前Player未重建，退出仍有原生资源释放警告。

## 保留的后续工作

- 薄壁亮度差需要隔离直接光、单次反弹与缓存反馈后解释；原场景有开放边界和多盏光，不能只按旧版更暗认定新版漏光。
- 短历史空间降噪改善不等于动态时间稳定性已经验收，仍需检查残影及更复杂运动。
- 退出资源释放、首次编译/驱动初始化、可信GI GPU时间和峰值显存、最终Player DXR与更广材质/形变组合仍未完成。

本机环境继续使用 `I:/Unity test/Start-Unity.ps1`，保留现有缓存、源包和原始采集证据。只对具体修改或新发现的问题执行有限验证，不重跑整套旧版/off/SDF/流式测试，不自动清理环境。

## GPT-6 Pro 独立审查（2026-10-28）

已完成只读源码与证据审查，详见 [审查结论与下一步计划](GPT6ProReview-Denoise01.md)。确认一项既有 HDR 时间二阶矩半精度存储缺陷，以及本次 `moments.w` 改义后遗漏 `HistoryAcceptance` 调试消费者的回归；跨薄层滤波及历史长度3→4的画面影响仍待定向验证。

下一工作包建议为 `denoise-02-contracts`：修存储范围与预算、修调试语义、扩展既有端到端GPU回归，再做有限动态配对。本次仅输出审查和计划，未执行这些修复，未运行新测试；运行时代码版本仍是 `local-development-denoise-01`。
