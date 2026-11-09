# Release176 独立分页组的首次出域

Release175 的独立导出 rig 在 `OnCameraPreCull` 取该相机最近一次准备的完整 HLOD。页仍绑定且代次有效时，相机移动到组远界外的第一次剔除仍可开启旧 Renderer，后续 `Scene.Prepare` 才撤回发布。Release176 在收集阶段带入当前相机位置和原 far 门。根和当前有效细节仍以最近范围决定整组资格，根未能进入候选时沿用作者范围。共享绑定继续交给原准备和退休流程。[Feature 接线](../../../Runtime/HybridLumenGIRendererFeature.cs) · [Scene 提交逻辑](../../../Runtime/HybridLumenGIScene.cs) · [统一示例的既有出域实机结果](../outside-group-visibility-01/result.md)

沿用 `Tests/Validate-HlodTransactions.ps1`，分别编译 Release175 和候选的实际 C# Scene、BVH、就绪表。两份 Scene 共享绑定，受控回执使 A 的粗根和 B 的两件细节各自完整发布。A 移动后直接调用栅格收集入口，两个 Scene 都还未再次 Prepare。

| 同一输入 | Release175 | Release176 |
| --- | --- | --- |
| A 到最近有效细节刚好 40 单位，根更远 | 收集完整粗根 | 收集完整粗根 |
| A 到最近有效细节 40.125 单位 | 仍收集一件旧粗根 | 收集零件 |
| 同时留在域内的 B | 收集两件细节 | 收集两件细节 |
| 共享绑定和准备状态 | 绑定仍可用，代次均为 1。两份发布保持 | 同左 |

候选同时保留域内等待时的完整旧组、代次拒绝和不可用父级阻止绕过发布。明确取消父级的普通成员也按当前远界收集。旧版在新的首次出域断言处复现，候选通过。此次证据是受控照明回执下的 CPU 栅格提交资格，实际像素和高速冷入首显仍按原条件验收。[原有事务回归](../../../Tests/Validate-HlodTransactions.ps1)
