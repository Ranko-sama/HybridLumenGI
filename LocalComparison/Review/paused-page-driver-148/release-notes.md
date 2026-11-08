# Release131 · 暂停后的资源页清理与接管

资源页驱动以零启动额度销毁时，现在仍会轮询已发出的操作，并在读者完成后卸载旧页。清理步只为释放保留额度，加载额度为零。旧页、在途操作及退休租约排空后，新的驱动可以取得全局所有权。仍活动的驱动按原配额工作。

`Validate-ChunkStreaming.ps1 -RepresentationOnly` 使用实际绑定、驱动和页调度代码，I/O 和读者完成由适配器提供。相同输入先以 `startsPerStep=0` 验证活驱动暂停，再留下一个未完成的包请求并恢复零额度后销毁。Release130 源码在安全归还后仍保留旧页。Release131 排空旧包、驻留页、在途 I/O 和退休租约，期间无新增加载，随后通过正常入口配置新驱动成功。

本项覆盖受控的页清理与接管条件，实际 AssetBundle I/O 和 GPU 退休分别验收。普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，沿用 Release130 着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/blob/ac8188c79be73e5f63ebac452083ad2ba0ed118d/Runtime/HybridLumenGIAssetPageStreamer.cs)
