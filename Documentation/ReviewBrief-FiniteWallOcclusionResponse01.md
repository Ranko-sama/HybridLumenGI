# 普通刚体移动的遮挡与恢复

2026-10-29，产品来源 `269241b38c45a97f29758fb92640cdb36f5092f8`。一次固定 56 帧的真实完整 Feature 采集通过 1,512 个接收器检查；没有新增 Runtime 修改，没有使用 Codex with ChatGPT。

沿用有限色墙和地面，只增加一面普通 URP Lit 黑色薄板，法线 +X，局部 `y∈[-.1,2.1]`、`z∈[-2.1,2.1]`。相机、接收器、色墙、灯光和材质固定；第 32 帧通过普通 Transform 将薄板从 x=20 移到 x=.25，第 44 帧移回 x=20。固定 32 帧预热、12 帧遮挡、12 帧恢复，不强制重置，不延长窗口。

使用 DX12 / RTX2080Ti / Unity6000.0.85f1 / URP17.0.4、Linear、640×360、8 rays/pixel、历史上限32/当前权重.08；世界反馈、环境、引导、屏幕追踪、发光和空间滤波关闭。本项隔离真实世界射线遮挡和屏幕历史响应，不代替更多反弹、相机运动、形变或整景验收。

## 独立依据与实测

每帧保存 27 个接收点及邻域的 raw/history/moments、两代几何与材质、motion、变化域、纯采样方向，以及实际提交的 instance/pose/triangle 数据。独立有限平面求交证明所选接收器通向色墙的路径被黑板截断，其他可达表面与环境的单次贡献为零。邻域也单独闭合，不能仅用中心的遮挡套用历史衰减上界。

当前 authored Transform 是物理响应合同。若实际上传姿态滞后，会另外记录来源滞后；不能用它豁免可信旧颜色。没有导出产品逐射线命中答案，也不将 transform 计数称为逐射线 winning-blocker 证据。

- 全部 1,512 个当前估计可信，unknown 与 uncovered 均为 0；远处薄板和恢复阶段分别有 711/275 个正值颜色样本。
- 第 32 帧实际 GPU pose 与源 Transform 都为 x=.25，geometry version 1→2、transform update 0→1；第 44 帧都回到 x=20，version 2→3、update 1→2。三角内容保持一致，scene rebuild 计数始终为1。
- 遮挡阶段 324 个中心估计全部是可信黑，独立输入中有 612 条原本通向色墙的方向，排除了整个窗口恰好全 miss 的伪通过。
- 遮挡当帧，27 个接收器历史长度从31降到2，最大分量 `0.019989013671875`，不超过预声明上界 `0.0200042724609375`。遮挡末帧长度13、最大分量 `0.0030536651611328125`，低于对应上界 `0.003082275390625`。
- 恢复当帧历史长度再次降到2；全部点当帧有可信当前估计，各点首次正值在0–2帧内出现。实际几何/材质、重投影和历史有效性共通过351项响应资格检查。

## 执行与日志限制

双程序集预检通过。两个观察器入口在三套完整后端 shader 上共6项编译通过，实际每套 UAV 数为4/1。56次请求及四类相机/上下文回调均为56，读回完成、native exit0；112产品源、8临时接线文件、原场景和项目设置均恢复一致。首渲染141.9710秒、采集段142.8661秒，首次等待仍是限制，不作性能验收。

冻结 Host 的 `Ready` 日志函数误用了 `readyCards>=6`，而三面墙各有一张 chart，实际56帧均为3张 ready、0 pending、0 material unknown。于是原日志 `ready=false` 全部保留。只读复核确认该布尔值只写入日志，未控制事件、采集、退出或分析；原合同依赖3个精确 published/charted owner和实际输入。附加审计解释此汇总缺陷，不修改原布尔值、颜色阈值或GPU数据，也不为此重跑。

[首分析](../LocalComparison/Review/finite-wall-occlusion-response-01/analysis-first.json)、[执行与恢复](../LocalComparison/Review/finite-wall-occlusion-response-01/execution-receipt.json)、[卡片就绪日志审计](../LocalComparison/Review/finite-wall-occlusion-response-01/readiness-audit.json)、[固定合同](../LocalComparison/Review/finite-wall-occlusion-response-01/contract.txt)、[原始帧日志](../LocalComparison/Review/finite-wall-occlusion-response-01/native/frames.jsonl)、[遮挡末帧预览](../LocalComparison/Review/finite-wall-occlusion-response-01/native/final-043-preview.png)、[恢复预览](../LocalComparison/Review/finite-wall-occlusion-response-01/native/final-055-preview.png)。画面边缘不在本次27点及邻域的验收范围内。

这项有限刚体遮挡响应可收束。默认引导/MIS、更多轮真实反馈、材质与后端范围、规模和生产预算仍继续按原计划推进，四目标与 G0–G5 不标为完成。
