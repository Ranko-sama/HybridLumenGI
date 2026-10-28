Independent judgment received before any new parent/Pro33 plan. Pro33 is reviewing in parallel; compare only after its final plan arrives.

【转向】Receive Shadows 修复可以结束：两入口实际捕获、直接项消费及自动退出均通过，累计两次构建／运行，不再追加。

唯一建议下一步：补普通Surface捕获遗漏的 detail albedo，推进目标1/4、工作流2/7的G1。Surface.shader:122只计算基础颜色；HitMaterials.hlsl:189–199以及native/card捕获已处理detail，因此默认Additive的接收颜色和屏幕反弹会与世界命中不同。现有求值可复用，最小范围只补detail颜色，避免全面重写材质捕获。

先用一个固定UV、非中性detail纹素对照实际求值，区分颜色计算缺失与keyword未生效：前者修计算，后者修变体传递；detail开启后反射率一致、关闭时保持原行为即收束。最大漂移风险是借此扩成全材质矩阵；本次两入口成功只关闭阴影位合同，不能替代这一具体反例，也不应触发新观察器工程。
