# 完整原计划推进表

更新：2026-10-28。本表按 OriginalDevelopmentPlan.md 的十项工作流区分实现、当前来源实测和生产验收。旧版报告保留来源，不重新标为当前版本通过。当前先处理已证实的阻断和可复现缺陷，再补缺失验收；不因新增局部测试而重跑无关矩阵。

| 工作流 | 已有实现/审查依据 | 当前版本新增或复用证据的边界 | 剩余验收与下一问题 |
| --- | --- | --- | --- |
| 1 社区源码审查 | CommunitySourceAudit 的固定 commit、文件和许可证记录 | 本轮未更换外部设计或复制代码，复用历史审查 | 新引入设计时只补相关模块来源；不重复全库阅读 |
| 2 光传输链路 | DirectLighting、EmissiveSampling、ProductionPlan 方程和绑定 | denoise-02 修复 HDR 二阶矩存储；未重验整帧传输 | 匹配单位的色墙/黑室/金属参考、薄壁分层归因、反馈收敛 |
| 3 世界空间表面缓存 | 真实三角 charts、atlas、版本和预算捕获 | candidate-16 有实际 HDR/UV/材质接线证据，属历史来源 | 当前凹面/薄层/接缝覆盖、规模与捕获成本 |
| 4 几何与近远场 | 实例 BVH、global SDF、dirty bricks、形变快照 | 历史精确/SDF运行；未重新验收当前整体 | 薄壁正确性、非闭合与形变边界、近远场连续性 |
| 5 局部失效与多反弹 | 变更域、代次、双缓冲、预算和年龄调度 | 本轮覆盖 temporal reset/reactive/unknown 局部合同 | 关灯/运动/删除后的世界缓存残留和收敛 |
| 6 采样与降噪 | 混合 PDF/MIS、运动历史与滤波 | denoise-02 F1/F2与denoise-03局部短历史过渡已通过Pro复核；单个真实门事件覆盖1230像素 | 已知第2/3历史噪声代价；持续reactive/历史上限2或3仍待画质验收；R1只有匹配信号敏感性证据；绝对拖影未验收 |
| 7 URP Lit / DXR | 源 UV/多材质、alpha/Cull、native diffuse规则 | 历史Editor DXR/有限合成对照；本轮仅Final小读回 | 当前Player DXR、材质/形变支持矩阵和软件差异解释 |
| 8 流式与预算 | 异步AssetBundle、完整组准入、HLOD原子切换、独立额度 | 历史720帧Player流式证据；本轮预算oracle更新 | 已测Editor退休缺陷已修；Player/在途任务退出、取消/冷暖/高速移动/长时与总VRAM |
| 9 可重复回归 | 离线入口、固定场景、HDR和来源清单 | denoise-03两侧各468阶段合同和198帧有限场景；原始采集及失败分析保留；PNG方向勘误已记录 | 按具体问题增加最小参考与事件窗口，不堆测试数量；已完成有限Editor生命周期归因/修复，当前转薄壁传输归因 |
| 10 工程验收 | Unity环境与历史Player已建立 | 当前109产品文件部署一致；当前完整Player尚未重建 | G0–G5、当前Player、参考图、GPU p95/p99、峰值VRAM、长时与支持范围 |

实际环境已知：Unity6000.0.85f1 / URP17.0.4 / Windows DX12 / RTX2080Ti。目标FPS、GI GPU预算和总显存验收阈值尚未确定，不伪造。可继续正确性开发和测量，不能据此宣布生产完成。朋友交付不再是依赖或停点。

resource-shutdown-01b已由Pro批准：先关准入/撤销owner，再按真实fence清理；自然Play退出两次、重入一次和直接Editor退出通过，36+21张旧域票据有逐项完成证据。实机后的取消任务异常保留修正另有actual-source回归，未冒充当前全部字节重新原生执行。Player、禁用域重载、在途worker/readback、Recorded/Quarantined和设备故障仍开放。见ReviewBrief-ResourceShutdown01b.md。

下一包thin-wall-transport-01：精确软件路径、静态薄壁probe；最多正常配置/关闭反馈诊断/单灯已知可见性三类，各至多120帧。固定观察点与阶段输入，只在明确反例上局部修复；不压暗、不改sigma、不把开放边界暗侧全零当物理真值。
