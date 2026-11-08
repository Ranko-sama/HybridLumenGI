# Release132 · 蒙皮源网格原地编辑后的旧快照撤回

自动 `BakeMesh` 在捕获时记住原 `sharedMesh` 的内容版本。主线程原地编辑源网格后，调用 `HybridLumenGIMeshSource.NotifyGeometryChanged(skin.sharedMesh)`。相机准备世界表示时会撤回旧 Mesh、SDF 和图卡，取消旧作业，随后按原配额捕获并发布当前版本。可选 receiver 检查在同一准备阶段发出的版本通知也会生效。显式可读 producer 仍按捕获请求提供快照。

`Validate-DeformedMesh.ps1` 用实际组件和来源版本服务复现了 Release131 在同引用内容变更后保留旧快照的问题。Release132 通过撤回、取消、等待模拟读者完成及当前版本恢复。原生 GPU 退休、实时捕获时长与形变画质分别验收。

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，沿用 Release131 着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/92bcdf226eee99ac7cd8cb6a7b302666e5903115)
