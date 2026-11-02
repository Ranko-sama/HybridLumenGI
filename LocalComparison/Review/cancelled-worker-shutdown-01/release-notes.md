Release107 改进了形变烘焙任务在应用退出时的清理。通用 GPU 资源回收队列排空后，尚在响应取消的后台 CPU 任务可以在原有共享期限内结束，随后由主线程清理未发布的私有网格。

Windows 包保留中性两室和三室。完整解压后运行 `Start-LocalRelease.cmd`，按 **F3 → 2 → 1** 可查看中性两室远近切换。离线打开 `PictureComparison/index.html` 可查看颜色、残留、拖影与恢复过程，画册新增方向光照贴图的四张实际相机画面及原始 EXR。

普通 Windows x64／Mono／DX12，960×540、半分辨率 GI、2 条射线、4 级滤波，优先 DXR。形变取消的依据来自受控 CPU 任务。两室远近切换实测来自 Release106，三室步行实测来自 Release105。
