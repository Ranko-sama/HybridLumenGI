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
| 7 URP Lit / DXR | 源 UV/多材质、alpha/Cull、native diffuse规则 | 历史Editor DXR/有限合成对照；本轮仅Final小读回 | 当前Player DXR、材质/形变支持矩阵和软件差异解释 |
| 8 流式与预算 | 异步AssetBundle、完整组准入、HLOD原子切换、独立额度 | 历史720帧Player流式证据；本轮预算oracle更新 | 已测Editor退休缺陷已修；Player/在途任务退出、取消/冷暖/高速移动/长时与总VRAM |
| 9 可重复回归 | 离线入口、固定场景、HDR和来源清单 | denoise-03有限场景；gather真实消费/偏移可见性观测；失败cache反例/回放；冻结理想能量参考；全部保留来源和失败记录 | 按具体问题增加最小参考与事件窗口，不堆测试数量；当前转真实关灯链，避免重复同类函数夹具 |
| 10 工程验收 | Unity环境与历史Player已建立 | 当前109产品文件部署一致；当前完整Player尚未重建 | G0–G5、当前Player、参考图、GPU p95/p99、峰值VRAM、长时与支持范围 |

实际环境已知：Unity6000.0.85f1 / URP17.0.4 / Windows DX12 / RTX2080Ti。目标FPS、GI GPU预算和总显存验收阈值尚未确定，不伪造。可继续正确性开发和测量，不能据此宣布生产完成。朋友交付不再是依赖或停点。

resource-shutdown-01b已由Pro批准：先关准入/撤销owner，再按真实fence清理；自然Play退出两次、重入一次和直接Editor退出通过，36+21张旧域票据有逐项完成证据。实机后的取消任务异常保留修正另有actual-source回归，未冒充当前全部字节重新原生执行。Player、禁用域重载、在途worker/readback、Recorded/Quarantined和设备故障仍开放。见ReviewBrief-ResourceShutdown01b.md。

下一包thin-wall-transport-01：精确软件路径、静态薄壁probe；最多正常配置/关闭反馈诊断/单灯已知可见性三类，各至多120帧。固定观察点与阶段输入，只在明确反例上局部修复；不压暗、不改sigma、不把开放边界暗侧全零当物理真值。

thin-wall-transport-01 v3更新：A的120帧与135份阶段数据完成，独立接收面/深度/就绪门槛通过；B/C尚未运行。退出仍报告owned1和29条Persistent分配，构成新的资源生命周期问题，当前整体结果失败，不能用exit0或采集成功覆盖它。已恢复源字节与A设置，并将证据返回Pro规划最小修复。前一资源包只保留其短运行有限验收。详见ReviewBrief-ThinWallTransport01-Retry.md。

iteration7后续：resource01c以actual-source确定复现退出进度竞态；最小谓词修复后相同输入与相关回归通过，唯一12帧原生退出的21张票据完整销毁，计账归零。Pro已批准，源码修复本地提交3c12a87。随后B/C各120帧完成，C固定遮挡/无遮挡与双精度参考通过，两侧完整退出日志无同类故障；Pro批准保留有限诊断证据。A复用且退出失败记录保留；此结果不覆盖实际cache tap/anchor连接或整图物理正确性。见ReviewBrief-ResourceShutdown01c.md与ReviewBrief-ThinWallTransport01-Completed.md。

iteration8的gather-cache-visibility-01已获Pro批准并提交507e52d：单一A配置120帧、四像素与九时点；225次真实偏移可见性查询匹配独立三角参考。17项无偏移物理连接差异处于边界歧义区，不宣称漏光改善或整图正确。实际消费与引导访问已区分。

iteration9的cache-failed-result-01已获Pro批准并提交1b8e751：实际tiny-support反例证实false返回残留结构被world消费；仅清零失败输出，五个其他控制字节不变、直接光/发光/confidence保留。六个受影响完整入口通过固定DXC编译，不作实体DXR验收。

iteration10的cache-energy-decay-reference-01已获同一Pro批准本地提交：唯一512轮理想两节点批次通过运行前冻结的双精度有限轮参考及独立稳态界，最大绝对误差约2.70e-7。实际Jacobi读写、反射率位置、照明变更缩短历史和关灯残留均符合合同；Astra独立复核无阻断。无Runtime变更，不能替代真实场景的灯光检测、atlas、预算调度和gather。下一包scene-lightoff-chain-01沿用单点光C场景，仅一次360逻辑帧，120帧关闭真实灯光。完整G0–G5仍开放。
