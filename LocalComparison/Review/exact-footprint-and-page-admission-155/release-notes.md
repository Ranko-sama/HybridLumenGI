# Release138 · 精确裁剪和分页准入

- 精确软件和 DXR 在足迹缺失时仍能应用确定的标量裁剪。固定实机输入中的透明前板正确露出蓝色后面，实心前板保持遮挡。确需纹理的覆盖继续在足迹未知时保守挡住射线。
- 收紧每步预算后，已驻留共享页可以供新组复用，已读完的文件也可以直接进入资产上传阶段。实际页调度器的 CPU 对照确认新页能够继续加载，并保留总容量与退休门。[两项对照与适用范围](https://github.com/Ranko-sama/HybridLumenGI/blob/2941440ba387683417854030a7d3243c497581c0/LocalComparison/Review/exact-footprint-and-page-admission-155/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/2941440ba387683417854030a7d3243c497581c0)
