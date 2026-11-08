# Release134 · 独立分页 HLOD 的逐相机显隐

默认独立导出的 HLOD 现在让每台支持的 Base 相机按自己的完整 GI 发布提交普通 Renderer。新目标预热期间保留有效的旧组，换页后重新取得就绪回执。粗根暂不可用时，仍有作者父级的单个细节保持隐藏。

真实 AssetBundle 和 DX12 Editor 的双相机对照中，Release133 的两个画面都画出了粗根和两片细节。Release134 在等待时保留旧根，就绪后近相机只画两片细节，远相机只画粗根。停用一片细节后，近相机撤回旧整组，远相机仍画根。测试使用两个显式 Base 请求。普通 Player 的双相机负载、原生退休、冷高速入场和性能预算分别验收。[原生对照与 CPU 回归范围](https://github.com/Ranko-sama/HybridLumenGI/blob/b9e51d5c329e7eb05cead10dd806eb7d5614ba96/LocalComparison/Review/independent-hlod-raster-151/result.md)

新导出的 HLOD 组会启用该功能。已有 rig 可重新导出，或在启用前为整组配置 `UseHlodPublicationForRendering(true)`。统一示例使用自己的单相机控制器。[配置与迁移](https://github.com/Ranko-sama/HybridLumenGI/blob/b9e51d5c329e7eb05cead10dd806eb7d5614ba96/Documentation/IndependentAssetPages.md#publication-and-lifetime)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，沿用 Release133 着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/b9e51d5c329e7eb05cead10dd806eb7d5614ba96)
