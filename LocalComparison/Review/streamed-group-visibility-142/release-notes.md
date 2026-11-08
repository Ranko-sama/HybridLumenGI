# Release126 · 统一示例的整组可见性

统一示例保留上一组 HLOD 时，现在逐成员校验流式绑定和代次。成员撤回、销毁或重绑后，整个旧组会隐藏。收到匹配当前完整绑定的发布回执才恢复显示。仍完整的旧组可继续显示，直到替换组就绪。

在 Unity 6000.0.85f1 无图形 Play 中加载原三室场景的实际 AssetBundle 页。观察以真实完整绑定形成受控照明回执，读取实际 Renderer 的启用和 `forceRenderingOff` 状态。完整粗根在等待中继续可提交。停用一个细节后，整组三个细节同时隐藏，细节 Proxy 退出 GI。一个成员在同一 Proxy 上从代次 1 重新绑定到代次 2，旧可见集合失效，提供新完整回执后恢复显示。普通 `Destroy` 只销毁绑定组件时，清理也隐藏了仍存活的 Renderer。

实际相机的照明回执、像素与高速冷入继续按原 G4 条件验收。普通 Windows x64 运行包从同版可编辑工程 ZIP 的独立解压目录构建，编译复用 Release125 着色器缓存。完整解压 Windows 附件后双击 `Start-LocalRelease.cmd`，离线画册随包提供。工程使用 Unity 6000.0.85f1 和 URP 17.0.4，原创内容采用 Apache-2.0，第三方许可和通知随附。[固定产品源码](https://github.com/Ranko-sama/HybridLumenGI/blob/9900f000eb894ebc141e342017110be0f0eab7fe/Runtime/HybridLumenGIUnifiedSample.cs)
