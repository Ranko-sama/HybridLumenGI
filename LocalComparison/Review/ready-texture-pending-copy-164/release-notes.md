# Release147 · 保留已确认的精确材质贴图

另一份贴图副本还在等待上传或回读时，只要完整材质请求能在一个已有缓冲区内满足，就继续使用匹配的已就绪页。缺少可用页或额度不足时，沿用原来的待定处理。

实际 C# 材质批次的受控对照中，后续请求从零代次恢复为原页代次，使用原贴图缓冲，无额外上传。模拟围栏与回读覆盖资源选择，GPU 画面和动态收敛继续验收。[前后对照](https://github.com/Ranko-sama/HybridLumenGI/blob/f0f35ae7caabe0070d77fb8bbbbbc31551926160/LocalComparison/Review/ready-texture-pending-copy-164/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/f0f35ae7caabe0070d77fb8bbbbbc31551926160)
