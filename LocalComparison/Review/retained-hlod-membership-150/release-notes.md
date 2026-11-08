# Release133 · HLOD 成员重挂与撤回

已发布的 HLOD 细节撤回、重挂或成为中间节点时，Scene 按当前作者组成员重查旧表示。旧集合缺失成员即整组退出追踪。重挂成员可以在目的组预热并取得回执，旧组仍可独立准备粗根。同版本细节从已发布退回预热时，退出世界追踪并撤销旧照明回执。完整旧组继续按原容量和就绪门槛等待切换。

`Validate-HlodTransactions.ps1` 编译实际 Scene、BVH 和 readiness 源码，以适配器提供 Unity 对象与照明回执。同输入下，Release132 保留旧组，并阻止重挂成员在新组预热和发布。Release133 在旧粗根没有回执时仍能完成新组发布。后续撤回一个成员后，剩余成员重新取得回执才进入完整发布。实际 GPU 回执、普通 Renderer 显隐与冷高速入场按原条件分别验收。

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，沿用 Release132 着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/9fdcb4f8e202b617e3591559cf9e39d4ab2ceac7)
