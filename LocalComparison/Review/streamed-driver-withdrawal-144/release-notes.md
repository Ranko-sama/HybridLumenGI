# Release127 · 流式驱动销毁后的页回收

销毁资源页驱动后，已经绑定的表示仍可更新自己的需求。仍有需求时保留网格、材质和页租约。需求撤回后，表示进入原有安全退休流程，页资源等待读者完成后释放。旧驱动排空后，新驱动可取得全局页预算的所有权。

沿用 `Tests/Validate-ChunkStreaming.ps1 -RepresentationOnly` 运行定向回归。测试编译实际绑定、驱动及页调度源码，使用 Unity 对象、异步 I/O 和最后读者完成的适配器。驱动销毁后，已有需求保持有效。调用 `SetWanted(false)` 后，绑定进入待退休状态，安全确认之前仍保留。确认后立即解绑，完成票据通过前仍持有两份租约。票据通过后旧包和驻留字节归零，新驱动通过正常配置入口取得所有权。

该回归覆盖活动绑定将需求撤回交给原有渲染上下文退休流程的路径。原生 GPU 空闲退休另有 Release126 中显式停用绑定的固定场景观察。Release127 为普通 Windows x64 构建，使用同版 Unity 工程 ZIP 的独立解压目录及 Release126 着色器缓存。项目使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/blob/8dc3c3dc9eb39a7ecc2c90d4c744440232d93a0e/Runtime/HybridLumenGIStreamedRepresentation.cs)
