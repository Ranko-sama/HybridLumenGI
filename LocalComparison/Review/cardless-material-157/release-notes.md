# Release140 · 无图卡精确材质的换色响应

已发布网格即使因容量没有图卡，也可能用真实材质参与精确追踪。替换这类离屏墙的 BaseMap 后，渲染器现在会通知附近接收面的照明历史与缓存调度。

实际 Unity DX12 Editor 的固定相机对照中，两版均在换色帧录制了新蓝贴图与同一 DXR 几何。Release139 的局部域为零，Release140 录制一个墙体局部域，地板缓存优先级由 0 升至 751。现有纹理回读完成后，下一次未换色的 DXR 请求不再产生该局部标记。证据覆盖普通 Texture2D 引用替换的录制与调度，画面恢复时间和生产预算另行验收。[前后记录](https://github.com/Ranko-sama/HybridLumenGI/blob/cc6634fefe6d01e5b265a24ed4f72d979d16467a/LocalComparison/Review/cardless-material-157/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/cc6634fefe6d01e5b265a24ed4f72d979d16467a)
