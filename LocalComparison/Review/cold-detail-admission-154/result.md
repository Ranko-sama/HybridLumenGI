# 粗根未绑定时，完整近景细节可开始准备

沿用 Release136 的三室统一示例和实际 AssetBundle。在 Unity 6000.0.85f1 无图形 Play 中暂时断开粗根及一件细节的流式驱动引用，保留粗根绑定组件启用和作者组关系。用示例原有的近景入口发出需求。另两件细节绑定后观察一次，再接回第三件细节的原驱动。粗根始终无网格和页绑定。

| 观察 | Release136 | 修复后 |
| --- | --- | --- |
| 2 件细节已绑定 | 0 件具备 GI 准入资格，0 件可提交 | 0 件具备 GI 准入资格，0 件可提交 |
| 3 件细节已绑定，粗根仍在等待 | 0 件具备 GI 准入资格，0 件可提交 | 3 件具备 GI 准入资格，0 件可提交 |
| 提供受控的完整细节发布回执 | 细节仍被准入门挡住 | 3 件整体取得普通 Renderer 提交资格 |

前两行读取实际 `LateUpdate` 后的 Proxy 和 Renderer 状态。第三行由观察器在准入成立后提供受控回执。既有实际 Scene 源码回归已覆盖无粗根资产时完整近组进入预热和按回执发布。修复让统一示例采用相同的准入条件，发布、距离和旧完整表示的原有控制继续适用。[Scene 回归](../../../Tests/StandaloneBvh/HlodProgram.cs.txt) · [旧版记录](<I:/Unity test/Comparison/ColdDetail154/baseline.json>) · [候选记录](<I:/Unity test/Comparison/ColdDetail154/candidate.json>)

结论限于固定统一示例、受控到达顺序和 CPU 侧准入及提交资格。该对照没有渲染像素或计时。Release110 高速冷入在转近前已绑定粗根，粗根预热被近目标取代的路径仍待解决。[原高速路线](../cold-aggregate-prefetch-01/result.md)
