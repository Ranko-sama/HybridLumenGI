# Release179 默认底图的 alpha 裁剪

普通 URP Lit 的 BaseMap 未赋值时，默认白色的 alpha 为 1。开启常规 alpha 裁剪且未启用 smoothness 取自 BaseMap alpha 的关键字时，表面覆盖由材质 alpha 和裁剪阈值决定。旧版仍先请求视差高度，待定高度图会让已透明的前面得到未知覆盖。Release179 仅在覆盖真正依赖 BaseMap 时请求纹理和视差坐标。完整材质求值仍按需要采样高度图。[Unity 6 ShaderLab 默认贴图](https://docs.unity3d.com/cn/6000.0/Manual/SL-Properties.html) · [命中覆盖](../../../Runtime/Resources/HybridLumenGI/HybridLumenGIHitMaterials.hlsl) · [纹理准入](../../../Runtime/Resources/HybridLumenGI/HybridLumenGIHardwareMaterials.hlsl)

旧版 Release178 和修复版使用同一输入，由现有 D3D12 WARP 宿主执行实际覆盖函数。主例开启 alpha test 和 parallax，材质 alpha 为 0.25，裁剪阈值为 0.5，BaseMap 未赋值，高度图有赋值记录但采样句柄待定。对照例有有效的 BaseMap 句柄，且该覆盖查询所需的纹理中只缺高度图。

| 输入 | Release178 | Release179 |
| --- | --- | --- |
| 未赋值 BaseMap，高度图待定 | 未知，保守遮挡 | 已知透明，可裁除 |
| 已赋值 BaseMap，高度图待定 | 未知，保守遮挡 | 未知，保守遮挡 |

首次准备在编译前置阶段缺少 URP 配置头，补入当前工程使用的头后完成上述对照。软件 BVH 和 DXR 均调用该覆盖函数；本次执行范围止于覆盖结果，实际候选遍历、可见远面的命中与相机画面各自验收。Astra Max 采用这一有限范围。离线画册保留其原版本和场景。[软件 BVH](../../../Runtime/Resources/HybridLumenGI/HybridLumenGISoftwareTriangleBvh.hlsl) · [DXR](../../../Runtime/Resources/HybridLumenGI/HybridLumenGIHardwareTrace.hlsl) · [输入与独立参考](../../../Tests/StandaloneHardwareMaterials/HardwareMaterialsOracle.mjs)
