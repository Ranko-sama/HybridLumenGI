# Release144 · 回收故障相机的 DXR 额度

相机在 DXR 几何准备或构建中遇到异常后继续使用软件追踪。旧 RTAS 和几何缓冲现在会自动进入原围栏退休流程。销毁完成后，其他相机可以使用归还的共享额度。

同一相机先录制并绑定正常几何，再模拟下一帧构建异常。实际 C# 对照中，失败相机保持存活，完成回调前资源仍计账，完成后健康相机可准入。回调和 Unity 调用由宿主模拟，原生 GPU 异常与性能仍待实机验收。[对照与边界](https://github.com/Ranko-sama/HybridLumenGI/blob/2f600925c118a2bba484392e662f35e40e717d0d/LocalComparison/Review/rtas-failure-retirement-161/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/2f600925c118a2bba484392e662f35e40e717d0d)
