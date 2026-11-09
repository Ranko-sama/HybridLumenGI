# 独立分页的必需叶首次绑定前终止失效

独立分页 HLOD 的一个启用叶在首次绑定前遇到终止错误后，会停止申请页，但仍声明作者成员资格。旧 Scene 把它和仍可到达的叶一起计为等待。若同组已有一片健康叶和可用粗根，尚无完整发布，近场目标就持续为空。

现有完整粗根接替条件现在也识别 `BeforeBinding`。失败叶继续声明原作者集合，源准入排除该叶。只要根可用，就按原槽位、图卡、几何、材质和照明就绪条件进行首次发布。页面仍在加载或可重试时，健康未绑定叶继续按原等待规则处理。公开的绑定退休状态按原规则报告，从未绑定的失败叶无租约需要退休。[原绑定退休证据](../failed-streamed-destination-194/result.md) · [已绑定后的失败恢复](../failed-detail-membership-264/result.md)

| 同一独立分页 Scene 准备步骤 | 旧实现 | 修复后 |
| --- | --- | --- |
| 一片已绑定，另一片健康待绑定 | 近景继续等待，未发布 | 同样等待 |
| 待绑定叶进入终止失败，仍启用且声明有效 | GI 与栅格资格均为 0，粗根未预热 | GI 与栅格资格均为 0，仅完整粗根预热 |
| 粗根取得完整就绪回执 | — | GI、BVH 和栅格资格均只提交粗根 |

实际 Scene、BVH 和就绪代码沿用 `Validate-HlodTransactions.ps1`，绑定与回执由现有宿主控制。`Validate-ChunkStreaming.ps1 -RepresentationOnly` 让实际绑定组件的目标 Renderer 在首次绑定前失效，确认 `BeforeBinding` 的来源准入、公开退休状态和健康请求三者的区别。[Scene 对照](../../../Tests/StandaloneBvh/HlodProgram.cs.txt) · [实际绑定回归](../../../Tests/StandaloneStreamedRepresentation/Program.cs.txt)

关闭 G4 中独立分页终止未绑定叶阻止完整粗根首次发布的缺口。证据限于终止状态和实际 Scene 的发布资格。坏页重建、GPU 就绪时间、实际恢复帧的后端与覆盖，以及健康页的冷高速首显继续各自验收。[完整组条件](../../../Documentation/HlodStreaming.md#atomic-hlod-transactions)
