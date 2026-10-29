# 首帧 CPU 分段诊断 01

唯一诊断 Player 的 12 次显式请求全部完成，首次相机完成等待 **2.6840022 秒**。之前 Release71 的 99.24 秒及两个观察场景约 141 秒等待没有复现；本次不能归因那些长等待，也不能证明性能改善。

诊断沿用 Release71／`269241b` 的场景、设置及 640×360 HDR 目标。43 个产品 shader 源和 245 个场景／配置／依赖输入保持相同；Renderer 仅有重新创建的 Cube GUID 差异，替换该 GUID 后序列化内容一致。只在临时 C# 副本加入计时，将有限运行改为 12 帧并关闭图像读回。普通 Release71 入口未替换。

两程序集预编译与 Release/None 构建通过；23 条既有构建 warning 保留。112 产品基线、10 个临时文件和 187 个构建产物来源核对通过，部署恢复。随后仓库应用的 guiding 几何修复不属于这次诊断来源。

| 首次请求内的范围 | CPU 墙钟时间 |
| --- | ---: |
| SubmitRenderRequest 整体 | 2429.7058 ms |
| Feature.RecordRenderGraph | 179.7339 ms |
| Transport 命令记录 | 88.0733 ms |
| Composite 命令记录结束至 endCameraRendering 回调入口的空档 | 1985.0733 ms |

最后一个空档约占首次请求的 81.7%，位于所测 GI 命令记录之外；它可能包含后续 URP 工作或底层执行／同步等待。没有独立 GPU 票据，不能把它称作 GI shader 或 GPU 执行时间。本次六个 FindKernel 调用均低于 0.01 ms，也不支持将这次等待归因到该调用。嵌套范围不能相加。

60 个单线程事件、25 个配对范围及首次相机／context 回调均通过原定分析。按事前合同，不因长等待未复现追加运行。探针可用于后续有明确目的的场景；本包不增加 GPU p95/p99、总显存或生产放行结论。

依据：[事前合同](../LocalComparison/Review/startup-stage-profile-01/contract.md)、[构建核对](../LocalComparison/Review/startup-stage-profile-01/build-analysis.json)、[原始 CPU 事件](../LocalComparison/Review/startup-stage-profile-01/native-explicit/run/startup-stage-cpu.json)、[首分析](../LocalComparison/Review/startup-stage-profile-01/native-explicit/analysis-first.json)。
