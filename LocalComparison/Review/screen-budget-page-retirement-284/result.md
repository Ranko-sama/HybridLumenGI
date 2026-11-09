# 屏幕预算拒绝后的分页组退休

两台自动渲染的 Game Base 相机使用同一个 URP Renderer。分页粗根发布后，A 改用 1728×864 目标，超过本次配置的 32 MiB 屏幕纹理预算。A 的普通相机输出继续更新，GI 录制停在工作前的第 11 引擎帧。B 保持 128×64，正常提交 GI。撤回粗根需求后，分别让 B 或 A 的普通绘制成为唯一读者，最后让两台相机都离开该组的 150 单位范围。

| 实际阶段 | Release232 | 修复后 |
| --- | --- | --- |
| A 出域，B 仍在域内录制 GI | 保留两份页引用 | 保留两份页引用 |
| B 出域，域内的 A 仅绘制普通画面 | A 中央仍显示粗根，保留两份页引用 | A 中央仍显示粗根，保留两份页引用 |
| 两台均出域 | 16 个渲染上下文后仍绑定，两份引用，包账 36,562 B | 第 14 个上下文解绑，仍保留两份引用，均进入退休 |
| 原栅栏完成 | 未进入退休 | 第 17 个上下文引用、退休、包、驻留和在途账全部归零 |
| A 恢复 128×64 并复入 | 保留旧版离场反例 | 第 29 个上下文重新录制 GI，粗根以绑定代次 2 重新显示 |

两台相机都保持在普通正交投影中能覆盖粗根中心的位置。域内根的中央样点为 RGB `(0, 0, 0)`，出域时与同一目标的背景相同，RGB 约为 `(0.522, 0.522, 0.522)`。两列均取实际相机目标中的固定中央点和背景点。采用范围为固定场景中实际普通绘制的保留和撤回。[旧版读回](baseline.json) · [修复后读回](candidate.json)

修复仅在当前 Base 相机确实因屏幕预算跳过 GI，且取得本次普通预剔除结果时，用实际选中的受管理 HLOD 成员决定该相机的页保留资格。其他相机继续各自判断。解绑后的旧 GPU 读者仍由原上下文尾栅栏保护。恢复 GI 时沿用正常准备、绑定代次和发布门。[预剔除与预算入口](../../../Runtime/HybridLumenGIRendererFeature.cs) · [原退休流程](../../../Runtime/HybridLumenGIResourceRetirement.cs)

使用 Unity 6000.0.85f1、URP 17.0.4、RTX 2080 Ti、DX12 Editor Play。复用 152 的保存场景及原生 AssetBundle，使用该夹具的 1 射线、零滤波和软件偏好。两侧来自 Release232 工程 `502cb7103af35a00c20987bd16fdd7eb17d4f6f7`，候选仅覆盖两个 Runtime 源文件。首个观察器在初始发布前就固定 Renderer 对象并在资格检查处退出；该次未触发预算。更正恢复 152 在两台初始发布后固定 Renderer 的时机。旧版反例与候选分别正常退出。采用范围限该自动 Base 页退休分支，普通 Player、DXR 加速结构占用及更大负载继续验收。[原 152 入口](../renderer-switch-retirement-152/result.md) · [首次观察日志](<I:/Unity test/Logs/ScreenBudgetRetirement284.log>) · [旧版退出](<I:/Unity test/Comparison/ScreenBudgetRetirement284Qualified/native-exit.json>) · [候选退出](<I:/Unity test/Comparison/ScreenBudgetRetirement284Fixed/native-exit.json>)
