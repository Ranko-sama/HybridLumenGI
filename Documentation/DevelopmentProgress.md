# 完整原计划推进表

更新：2026-10-28。本表按 OriginalDevelopmentPlan.md 的十项工作流区分实现、当前来源实测和生产验收。旧版报告保留来源，不重新标为当前版本通过。当前先处理已证实的阻断和可复现缺陷，再补缺失验收；不因新增局部测试而重跑无关矩阵。

| 工作流 | 已有实现/审查依据 | 当前版本新增或复用证据的边界 | 剩余验收与下一问题 |
| --- | --- | --- | --- |
| 1 社区源码审查 | CommunitySourceAudit 的固定 commit、文件和许可证记录 | 本轮未更换外部设计或复制代码，复用历史审查 | 新引入设计时只补相关模块来源；不重复全库阅读 |
| 2 光传输链路 | DirectLighting、EmissiveSampling、ProductionPlan 方程和绑定 | denoise-02 修复 HDR 二阶矩；1b8e751统一失败cache输出；iteration10理想算子逐轮能量参考通过Pro有限复核 | 真实场景光源变更、匹配单位的色墙/黑室/金属参考和整图能量 |
| 3 世界空间表面缓存 | 真实三角 charts、atlas、版本和预算捕获 | candidate-16 有实际 HDR/UV/材质接线证据，属历史来源 | 当前凹面/薄层/接缝覆盖、规模与捕获成本 |
| 4 几何与近远场 | 实例 BVH、global SDF、dirty bricks、形变快照 | 历史精确/SDF运行；未重新验收当前整体 | 薄壁正确性、非闭合与形变边界、近远场连续性 |
| 5 局部失效与多反弹 | 变更域、代次、双缓冲、预算和年龄调度 | iteration10执行实际cache update/lookup/commit/change，两节点256开+256关独立参考通过；不代表真实帧响应 | 真实灯光检测、调度与缓存/画面链；运动/删除后的残留和收敛 |
| 6 采样与降噪 | 混合 PDF/MIS、运动历史与滤波 | denoise-02 F1/F2与denoise-03局部短历史过渡已通过Pro复核；单个真实门事件覆盖1230像素 | 已知第2/3历史噪声代价；持续reactive/历史上限2或3仍待画质验收；R1只有匹配信号敏感性证据；绝对拖影未验收 |
| 7 URP Lit / DXR | 源 UV/多材质、alpha/Cull、native diffuse规则 | 当前3088d41同构建软件/DXR各120帧Player、真实后端/唯一GI读回/5份HDR及正常退出通过，Pro20/21接受；不代表图像等价 | 材质/形变定量支持与软件差异解释、动态质量 |
| 8 流式与预算 | 异步AssetBundle、完整组准入、HLOD原子切换、独立额度；默认关闭的独立计时/完成记录导出 | e1aa6356实体DXR固定512源帧NativeDX12基线完整，目标0/反馈关闭且配额256/24/16不变；Transport中位19.694ms，三范围和19.853ms；Pro22已接受有限证据 | 23轮已确定Gather主导，唯一复用候选收益未超过波动而撤回；转向具体材质/形变事件。在途异常/取消/冷暖/高速移动/长时与总VRAM仍开放 |
| 9 可重复回归 | 离线入口、固定场景、HDR和来源清单 | denoise-03有限场景；gather真实消费/偏移可见性；失败cache反例；理想能量及实际关灯链；新增固定源帧GPU成本基线；均保留来源和失败记录 | 按具体热点或动态/材质反例增加最小验证；不重复已完成关灯链、Player冒烟或同类函数夹具 |
| 10 工程验收 | Unity环境、当前Player构建与来源清单 | e1aa6356新计时构建110源码/284产物，唯一688帧实体DXR运行与正常退出通过；3088d41软件/DXR图像冒烟保留原来源 | 固定窗口GI三范围p95/p99已有有限数据；整应用/动态/Release尾延迟、参考图/动态质量、峰值VRAM、长时和G0–G5支持范围仍开放 |

实际环境已知：Unity6000.0.85f1 / URP17.0.4 / Windows DX12 / RTX2080Ti。目标FPS、GI GPU预算和总显存验收阈值尚未确定，不伪造。可继续正确性开发和测量，不能据此宣布生产完成。朋友交付不再是依赖或停点。

resource-shutdown-01b已由Pro批准：先关准入/撤销owner，再按真实fence清理；自然Play退出两次、重入一次和直接Editor退出通过，36+21张旧域票据有逐项完成证据。实机后的取消任务异常保留修正另有actual-source回归，未冒充当前全部字节重新原生执行。Player、禁用域重载、在途worker/readback、Recorded/Quarantined和设备故障仍开放。见ReviewBrief-ResourceShutdown01b.md。

下一包thin-wall-transport-01：精确软件路径、静态薄壁probe；最多正常配置/关闭反馈诊断/单灯已知可见性三类，各至多120帧。固定观察点与阶段输入，只在明确反例上局部修复；不压暗、不改sigma、不把开放边界暗侧全零当物理真值。

thin-wall-transport-01 v3更新：A的120帧与135份阶段数据完成，独立接收面/深度/就绪门槛通过；B/C尚未运行。退出仍报告owned1和29条Persistent分配，构成新的资源生命周期问题，当前整体结果失败，不能用exit0或采集成功覆盖它。已恢复源字节与A设置，并将证据返回Pro规划最小修复。前一资源包只保留其短运行有限验收。详见ReviewBrief-ThinWallTransport01-Retry.md。

iteration7后续：resource01c以actual-source确定复现退出进度竞态；最小谓词修复后相同输入与相关回归通过，唯一12帧原生退出的21张票据完整销毁，计账归零。Pro已批准，源码修复本地提交3c12a87。随后B/C各120帧完成，C固定遮挡/无遮挡与双精度参考通过，两侧完整退出日志无同类故障；Pro批准保留有限诊断证据。A复用且退出失败记录保留；此结果不覆盖实际cache tap/anchor连接或整图物理正确性。见ReviewBrief-ResourceShutdown01c.md与ReviewBrief-ThinWallTransport01-Completed.md。

iteration8的gather-cache-visibility-01已获Pro批准并提交507e52d：单一A配置120帧、四像素与九时点；225次真实偏移可见性查询匹配独立三角参考。17项无偏移物理连接差异处于边界歧义区，不宣称漏光改善或整图正确。实际消费与引导访问已区分。

iteration9的cache-failed-result-01已获Pro批准并提交1b8e751：实际tiny-support反例证实false返回残留结构被world消费；仅清零失败输出，五个其他控制字节不变、直接光/发光/confidence保留。六个受影响完整入口通过固定DXC编译，不作实体DXR验收。

iteration10的cache-energy-decay-reference-01已获同一Pro批准本地提交：唯一512轮理想两节点批次通过运行前冻结的双精度有限轮参考及独立稳态界，最大绝对误差约2.70e-7。实际Jacobi读写、反射率位置、照明变更缩短历史和关灯残留均符合合同；Astra独立复核无阻断。无Runtime变更，不能替代真实场景的灯光检测、atlas、预算调度和gather。下一包scene-lightoff-chain-01沿用单点光C场景，仅一次360逻辑帧，120帧关闭真实灯光。完整G0–G5仍开放。

iteration11已保存为失败检查点3241b50：真实Unity首帧观察器重复映射错误，未到119/120帧，0截图；另有7张未提交票据和原生资源失败。原合同与数据保留失败状态。iteration12完成离线唯一patch/别名修正，尚未Unity执行；一次基线归因确定正常Feature.Dispose直接拆散pass的所有权缺口。限定修复统一detach+StopAdmission，专用完整pass父项等待真实idle/fence，子项仍各自完成。actual-source测试通过；唯一同触发原生确认的9张票据均完整销毁，64608逻辑子字节回收，原8个GI buffer泄漏不再出现。引擎1MiB scratch告警仍未归因，冻结整体资源验收保持false；关灯链仍未完成、无新截图。Astra已复核有限结论，正在等实际GPT-6 Pro第12轮审查。工作区候选与已恢复的Unity部署暂时不同，不能沿用上表历史“部署一致”描述为当前状态。完整原计划与生产关卡不变。

Pro12正式批准局部修复及别名观察器本地提交，限定关闭上述GI owner缺口；scratch仍开放。所依赖的本地URP/Core17.0.4最小函数片段、版本、哈希与许可证已归档。下一包scene-lightoff-chain-02获准一个原生进程≤360帧，先部署新提交基线，再验证真实关灯事件链；不重跑提前退出矩阵。完整回复见early-exit-retirement-01/gpt6-pro-review-and-next-plan.txt。

iteration12已提交c50ec78。iteration13的scene-lightoff-chain-02实际Unity完成360目标帧、9组HDR/EXR/PNG、0观察器错误、native0；本次完整扫描无资源故障，96源码和8资产恢复到新基线。真实119就绪门槛和120关灯已执行，34次最终cache消费（20次连到选定patch）与预算/写入/屏幕阶段有对应记录。冻结分析仅因logical1的额外首次灯发现而保持失败：0/1均GIframe0、tick1、previousCount0、旧cache零，全部owner revision增加一次，灯本身未变；具体重建caller未观测，不能断言产品bug或无害。保留原FAIL并交Pro13审查生命周期合同。HDR末帧仍有非零残留，PNG接近黑色不是物理收敛证明；历史异常退出scratch本轮未复现但未归因。完整原计划/Player/DXR/画质性能长时关卡仍开放。详见ReviewBrief-SceneLightoffChain02.md。

Pro13已批准按冻结失败状态本地提交完整场景证据。下一包仅离线：基于组合状态证据进行生命周期限定，保留原FAIL；然后利用实际720patch记录拆解服务等待、自身历史与新估计输入，解释真实响应。无需新Unity/GPU。归因后优先独立真实场景HDR参考，不扩大等价夹具或启动测试。

iteration14–17：已保留实际关灯链的有限缓存响应分解；旧场景缺少六份材质的历史来源字节，因此没有追认旧图物理参考。新配对来源的前两次尝试分别在项目清单路径解析、归档长路径处于Play前失败，原始失败均保留；最小工具修复已获Pro批准并本地提交。

iteration18：首次完成新来源配对的真实120帧、2组PNG/HDR、0采集错误、native0，来源冻结与恢复通过；独立六点来源对应及48批共196608路径积分实际完成，随后比较完成。严格统计/尾项界过宽，referenceEstimateQualified与comparisonConclusive保持false，无追加采样。此前一次JSON序列化失败发生在积分前，0条路径；原脚本、日志与开始标记保留，修复仅两处输出标量转换。中央墙/方块的直接光参考为零，间接光与最终滤波结果微弱但非零；不能把近黑截图当成正确亮度或降噪故障的证明。详见scene-radiometry-matched-baseline-03/result.md。Astra无阻断，实际GPT6Pro18已批准有限证据提交；下一包为真实滤波与上采样贡献归因。Runtime未改，整个原计划及Player/DXR/动态质量/性能/显存/长时验收继续开放。

iteration23：两个固定64源帧DXR窗口均完成，Gather占主要成本；有限等价且编译提升成立的唯一接收导数复用候选只省0.027856ms，未超过块间波动，已撤回并验证仓库/部署110源码恢复。保留原始数据、候选patch与有限结论，不追加样本、不继续无界热点拆分。必要构建验证独占Windows导入标志，22轮历史偏差不改写。实际Pro23已批准有限证据提交与撤回；下一包material-mpb-propagation-01检验单一材质槽MPB事件的自动发现、缓存消费和历史响应，完整生产关卡仍开放。
