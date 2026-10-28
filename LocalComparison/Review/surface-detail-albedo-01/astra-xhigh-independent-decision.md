Independent decision at the actual-result conflict, before a new main/Pro36 plan.

【简化】现有数据足够作有限取舍，无需第二次运行。产品已补上MulX2/Scaled颜色计算，源码反例与detail-off控制成立；本次失败来自oracle漏用了既有Material非HDR颜色转线性合同。两入口相近只能作旁证，不能单独作为正确性证明。

唯一下一步：保留原FAIL，依据运行前已存在的ShaderColor合同，从原始输入独立推导线性期望值，对四份已存payload做补充判读，沿用原容差及其余断言。它区分颜色输入空间误判与detail产品计算错误，直接决定保留或撤回。

最大风险是从结果反推公式、放宽容差，把事后吻合包装为原验收通过。若既有合同下全部成立，有限关闭此修复，随后进入约定的代表场景整体效果／典型动态评估；若仍有分歧，保持未通过并撤回，不新增运行或用例。
