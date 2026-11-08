# 相机状态重建时的软件精确几何额度

精确软件追踪的每相机预算同时覆盖三角属性和 BVH。一个 Feature 在 `maxCameras=1` 时从 A 切到 B 会逐出 A 的状态。A 再进入时，旧版的软件属性与 BVH 各自从新状态计费，漏掉仍等待安全释放的旧分配。 [软件准入和状态切换](../../../Runtime/HybridLumenGIRendererFeature.cs) · [BVH 布局](../../../Runtime/HybridLumenGISoftwareTriangleBvh.cs)

修复沿用 DXR 的相机归属，给精确软件维护独立的属性和 BVH 合计。旧分配跨状态重建计账，释放成功后归还。只够分配属性时，BVH 在原准入门等待。现有回退清空工作项的 `geometry` 和 `softwareLayout`，该次渲染使用 SDF／解析追踪。 [回退入口](../../../Runtime/HybridLumenGIRendererFeature.cs#L1316)

## 同输入对照

现有 C# 宿主使用 Feature 的实际三角上限、准备和退休方法，并编译实际精确属性与 BVH 实现。以 1 MiB、64 槽、单 submesh 为配置，普通入口允许 2,040 个三角。输入 2,000 个三角，实际属性为 384,448 B，实际 BVH 节点和叶为 255,968 B。按 A、B、A 顺序模拟状态逐出，完成时机由宿主控制。

| 观察 | Release150 源码 | 修复后源码 |
| --- | --- | --- |
| 旧 A 尚在退休 | 属性与 BVH 共 640,416 B | 属性与 BVH 共 640,416 B |
| B 在 A 未完成时申请 | 独立准入 | 独立准入 |
| 返回 A，旧票据尚未完成 | 新属性和 BVH 均准入，两代共 1,280,832 B | 新属性准入，合计 1,024,864 B。新 BVH 延后，零 BVH 分配 |
| 旧属性和 BVH 释放后 | A 单代 640,416 B | A 恢复完整准入，单代 640,416 B |

Astra Max 按逻辑准入范围采用。Feature 的相机归属和软硬件预算分离经源码核对，分配与完成使用受控适配器。普通 Player 的双相机 GPU 成本、进程总显存和高速冷入继续分别验收。
