# Release148 · 先加 mip 偏移再夹取足迹 LOD

精确软件与 DXR 共用的材质采样现在保留有限正足迹的原始 LOD。现有采样器先应用贴图偏移，再夹到该页实际驻留的 mip 范围。

D3D12 WARP 的实际材质覆盖入口确认，两端偏移造成的错误裁切均已修复，零足迹控制结果一致。完整材质派发在旧版超时，完整颜色与实体 GPU 画面仍待验收。[输入、读回与范围](https://github.com/Ranko-sama/HybridLumenGI/blob/ed99f25d53ab648755fa380a28bc706529bab45d/LocalComparison/Review/mip-bias-footprint-165/result.md)

普通 Win64 包从同版 Unity 工程 ZIP 的独立解压目录构建，使用 Unity 6000.0.85f1 和 URP 17.0.4。完整解压后运行 `Start-LocalRelease.cmd`。离线画册、Apache-2.0 许可证和第三方通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/tree/ed99f25d53ab648755fa380a28bc706529bab45d)
