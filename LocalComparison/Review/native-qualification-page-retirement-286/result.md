# 原生漫反射替换退回普通绘制后的分页退休

两台自动渲染的 Game Base 相机共用同一 Forward Renderer，先在 128×64、单采样的 RGBA16F 目标上发布同一分页粗根。A 换成同尺寸的 RGBA8 UNorm 目标，实际记录了原生漫反射替换的格式资格拒绝。A 继续普通绘制，GI 录制保持在第 11 引擎帧。B 保持 RGBA16F 并继续录制 GI。撤回分页需求后，依次让 B 和 A 成为唯一读者，最后两台都离开组的 150 单位范围。

| 实际阶段 | Release233 | 修复后 |
| --- | --- | --- |
| A 出域，B 仍录制域内 GI | 保留两份引用，B 绘制粗根 | 保留两份引用，B 绘制粗根 |
| B 出域，域内 A 只录制普通绘制 | 保留两份引用，A 绘制粗根 | 保留两份引用，A 绘制粗根 |
| 两台均出域 | 16 个上下文后仍绑定，两份引用，包账 36,562 B | 第 14 个上下文解绑，两份引用进入退休 |
| 原栅栏完成 | 观察期内未进入退休 | 第 16 个上下文页引用、退休、驻留、包和在途账均归零 |
| A 恢复 HDR 并复入 | 本侧止于保留反例 | 第 28 个上下文实际重新录制并绘制粗根，绑定代次从 1 到 2 |

两台相机的中央采样点都覆盖粗根原位置。域内有粗根时中心 RGB 为零，出域时中心与同目标的背景一致。RGBA16F 和 RGBA8 的实际背景值分别约为 0.52246 和 0.52157。修复前后的域内读者保留和出域画面一致。旧版观察仅覆盖 16 个上下文，另一个相机后续还可能经空闲相机状态淘汰解除阻挡。[旧版读回](baseline.json) · [修复后读回](candidate.json)

修复在已有场景状态的 Base 相机因原生替换的目标或材质资格退出时，使用当次普通预剔除确定受管理页的消费者。屏幕预算拒绝复用同一入口。只有实际选中受管理页的普通读者才在该入口更新相机状态的使用时间。普通读者和其他相机仍分别判定，旧 GPU 读者继续由原上下文尾栅栏保护。[录制与预剔除](../../../Runtime/HybridLumenGIRendererFeature.cs) · [上下文退休](../../../Runtime/HybridLumenGIResourceRetirement.cs)

两侧从 Release233 工程 `9f9b08ef0c18468d7770bb0e27a5ee16d5052e97` 独立解压，候选仅覆盖 Renderer Feature 源文件。Unity 6000.0.85f1、URP 17.0.4、RTX 2080 Ti、DX12 Editor Play，复用屏幕预算对照的自动双 Base 场景及原生 AssetBundle，使用原夹具的一条射线、零滤波和软件偏好。两侧实际退出 0。实机采用限目标格式拒绝，材质资格返回使用同一入口，普通 Player 与其他配置继续按原计划验收。[已复用的双相机入口](../screen-budget-page-retirement-284/result.md) · [旧版退出](<I:/Unity test/Comparison/NativeQualificationRetirement286Qualified/native-exit.json>) · [候选退出](<I:/Unity test/Comparison/NativeQualificationRetirement286Fixed/native-exit.json>)
