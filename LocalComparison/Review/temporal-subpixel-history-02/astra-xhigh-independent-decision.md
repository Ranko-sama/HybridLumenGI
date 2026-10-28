Independent closure/next-direction judgment, before seeing any new main/Pro35 proposal.

【转向】亚像素历史重建可以收束：两个真实入口的线性场误差均降至原来的26.1%，不合格邻点保持原最近邻输出，历史长度未膨胀；代码未放宽拒绝条件。累计两批、零Player，结束此项，不外推整场景抗闪烁验收。

唯一下一步建议修复普通Surface遗漏detail albedo，推进目标1/4、工作流2/7的G1。Surface.shader:122只取基础颜色，而现有native/card及HitMaterials已计算detail；这是默认Additive接收颜色和屏幕反弹的具体合同缺口，现成求值可局部复用。

最小验证用固定UV和非中性detail纹素，区分颜色求值缺失与keyword传递错误，决定修计算还是接线；detail开启符合相同材质参考、关闭保持原行为即结束。最大漂移风险是追加时域场景或展开全材质矩阵，已有证据不支持这些扩展。
