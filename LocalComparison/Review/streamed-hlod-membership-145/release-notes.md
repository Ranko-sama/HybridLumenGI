# Release128 · 分批加载时保持完整 GI 表示

默认独立分页导出的细节可以在不同帧绑定。Scene 现在用启用的分页绑定识别作者组，等全部细节进入准备后才允许整组接替。有效粗根在细节等待期间继续参与 GI。细节先到时也遵循同一个组门槛。完整细节可以在粗根尚未绑定时预热并发布，近远判定使用已保存的根包围盒和原滞回规则。

用现有 `Tests/Validate-HlodTransactions.ps1` 运行同一输入。Release127 源码在两种到达顺序中分别用单件替掉粗根、或先把单件当普通代理发布。候选保住有效粗根，拒绝首件的提前发布，并在完整细节满足原就绪门槛后接替。原容量、静态嵌套和就绪回执用例一并通过。首次编译发现旧宿主缺少当前 Scene 的 Shadowmask 和几何适配，补齐后才比较旧源码与候选。此处使用实际 Scene／BVH 源码，绑定、包围盒和完成回执为受控 CPU 输入。

这项结果覆盖独立导出 rig 的世界 GI 发布逻辑。实际 AssetBundle 到达顺序、普通 Renderer 的组显隐和高速冷入首显分别验收。Release128 的普通 Windows x64 包从同版 Unity 工程 ZIP 的独立解压目录构建，复用 Release127 着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/blob/d7315b2c0866ae99e62edad5f0d33c376ff01d36/Runtime/HybridLumenGIScene.cs)
