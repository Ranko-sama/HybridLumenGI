# Release145 · 对象 SDF 按帧共享上传额度

普通 Renderer Feature 的对象 SDF 图集共享每引擎帧 1 MiB 的体素上传额度。每台相机仍有自己的图集。额度不足时，等待最久的整卷优先取得下一次可用份额，尚未上传的卷使用原解析回退。

两个实际 C# 图集同帧冷准备的受控对照中，体素 `SetData` 请求从 2 MiB 降到 1 MiB，晚准备的图集随后取得额度。该对照覆盖逻辑提交额度和就绪顺序，实体多相机带宽、性能和高速首显仍待验收。[对照与适用范围](https://github.com/Ranko-sama/HybridLumenGI/blob/a62c82711c408a38dcfb3feb986799215828d5fe/LocalComparison/Review/sdf-frame-upload-162/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/a62c82711c408a38dcfb3feb986799215828d5fe)
