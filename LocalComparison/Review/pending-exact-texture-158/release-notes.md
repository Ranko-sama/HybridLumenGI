# Release141 · 贴图等待期间保留精确追踪

精确材质批次在等待匹配贴图页的元数据回读时继续提交三角形。依赖该页的材质求值暂为未知，未知的裁切覆盖保守遮挡。已确认的其他贴图照常使用，待定页通过既有检查后恢复复用。

实际 Unity DX12 Editor 的有限墙场景中，换蓝后的等待帧保留两份精确网格、DXR、原世界缓存代次及地板的已确认贴图。回读完成后恢复同代次蓝贴图，无重复上传。换色帧仍触发墙体局部更新。软件裁切控制沿用已有的等待阶段观察，画面恢复时间和正式性能另行验收。[实际记录及适用范围](https://github.com/Ranko-sama/HybridLumenGI/blob/e418d47237b96cdd8a0d4b56953f505f5d380fd6/LocalComparison/Review/pending-exact-texture-158/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/e418d47237b96cdd8a0d4b56953f505f5d380fd6)
