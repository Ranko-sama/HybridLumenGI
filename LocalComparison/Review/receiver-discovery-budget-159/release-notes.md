# Release142 · 接收面发现的 CPU 时间准入

Renderer Data 中的 Hybrid Lumen GI Feature 增加 `receiverDiscoveryCpuBudgetMilliseconds`。启用后，同一次相机图的初次接收面发现与重验累计各次扫描的经过时间，额度用完即停止后续检查。默认 0 沿用完整扫描。

不完整结果沿用原有保护。初次发现不完整时保留原生漫反射，身份重验不完整时保留当前 GI 并拒绝对象历史回执。受控 C# 对照覆盖额度共享、停止后续来源检查、实际资格拒绝及下一次完整扫描。已经开始的 Unity 枚举或来源调用会完成，生产 CPU 与 GPU 时间仍按原口径验收。[功能对照与范围](https://github.com/Ranko-sama/HybridLumenGI/blob/877d71a2bb737bbfbbbc7287b47c68efb889529f/LocalComparison/Review/receiver-discovery-budget-159/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/877d71a2bb737bbfbbbc7287b47c68efb889529f)
