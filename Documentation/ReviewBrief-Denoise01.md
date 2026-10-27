# 独立审查入口：本机开发与后续计划

用户要求由 ChatGPT GPT 6 Pro 审查本次开发，并提出下一步开发与修复计划。本次仅审查与规划，不自动执行新一轮修改或测试。当前方向为本机开发，不制作朋友交付包，不等待朋友反馈。

完整长期目标以 [用户原始四项目标与十项架构清单](OriginalDevelopmentPlan.md) 为对照。当前降噪审查及 `denoise-02-contracts` 仅为局部工作包，不能取代总计划，也不能据此宣称各模块或最终生产验收完成。

## 审查范围

1. 独立审查 `local-development-denoise-01` 的实现、数值/资源合同和实测证据。区分可证实的缺陷、合理风险和证据不足，不把单帧降噪指标当作完整动态验收。
2. 对照原计划，评估下一阶段应先处理哪些已观察到的问题：薄壁光照、时间稳定性、资源退出、冷启动、可信GPU时间与显存、支持组合。
3. 输出有限、有优先级的计划，包含问题触发条件、文件/函数、修改方向、必要验证、完成判据及停止条件。复用已有结果，不扩建测试框架或添加不必要功能。

## 当前源码与历史基线

- denoise-01审查时尚未建立Git仓库，因此该轮差异使用下面保存的原文件和补丁。2026-10-28按用户要求初始化本地Git仓库，当前基线提交之后的开发可使用Git追踪；初始提交本身不重建此前的提交历史。
- 当前实现：`Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl`，重点 `CSTemporal` / `CSTemporalIdentity` / `CSFilter`。
- 基线：`runtime-candidate-16`，只有上述产品文件相对基线有改动。
- 原文件与差异：`LocalComparison/Review/denoise-01/HybridLumenGIKernels.before.hlsl`、`product.patch`。
- 合同相关：`HybridLumenGIRadianceValidity.hlsl`、`HybridLumenGIScreenGeometry.hlsl`、`HybridLumenGIReceiverTemporal.hlsl`、`Runtime/HybridLumenGIRendererFeature.cs`。
- 全局目标：`Documentation/ProductionPlan.md`。历史运行范围：`Documentation/LocalRuntimeFunctionalAudit.md`、`Documentation/LocalRuntimeFix02.md`。当前增量：`Documentation/LocalDevelopment.md`。

## 证据位置

- `Tests/local-development-validation-results.json`：本轮来源哈希、运行范围、GPU回归及图像指标。
- `Tests/runtime-validation-results.json`：冻结16版的历史记录，不属于当前源码的新Player验证。
- `LocalComparison/Review/denoise-01/`：从本机原始证据复制的文件；包括GPU检查、配对统计、最终run.json、实机帧179修复前/后PNG。
- `LocalComparison/Harness/DenoiseRegressionEditor.cs`：真实Unity GPU回归入口。
- `LocalComparison/Harness/analyze-denoise.py`：图像比较及固定ROI定义。
- `LocalComparison/Harness/record-local-denoise.py`：来源与结果记录过程。

完整原始数据位于工作区外的 `I:/Unity test/Comparison`；连接应只读取当前工作区。不要尝试越界访问。审查需要额外证据时，给出精确的文件/数据需求，由Codex把必要材料复制到工作区后再读取。审查过程中不要求粘贴源码、差异或日志。

请用中文返回：总体判断；按严重度排序且带文件/行号的具体发现；验证缺口；下一轮最小工作包及后续优先级。若未发现确定缺陷，明确写出，不要为凑清单把猜测当问题。
