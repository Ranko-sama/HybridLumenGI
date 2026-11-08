# Release130 · 相机准备前撤回已失效的蒙皮快照

相机回调可以在本帧的快照调度之后更换或清空 `SkinnedMeshRenderer.sharedMesh`。现在 GI 在相机准备读取来源之前重新核对网格，撤回旧 Mesh、SDF 和图卡并取消失效作业。已提交的读者继续持有旧资源，直到原退休栅栏完成。新网格沿用异步捕获与每帧发布预算。

同一输入的 `Validate-DeformedMesh.ps1` 在 Release129 复现了相机准备仍读取旧几何。Release130 源码通过同帧更换与清空回归，覆盖旧作业取消、旧资源等待完成和后续恢复。验证使用实际 C# 组件、受控后台作业及模拟的最终渲染上下文和栅栏。相机前检查没有启动额外的捕获或上传。

本项覆盖快照的来源资格。实体 GPU 退休、形变画质及响应时间按各自条件验收。普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，沿用 Release129 的着色器缓存。使用 Unity 6000.0.85f1 和 URP 17.0.4，完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/blob/c07eee97877a107d57bbee3e0537b030591f6fbd/Runtime/HybridLumenGIDeformedMesh.cs)
