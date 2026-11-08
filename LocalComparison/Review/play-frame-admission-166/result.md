# 禁用域重载后的 Play 帧预算

关闭 Editor 域重载时，退出再进入 Play 会保留静态 GI 帧预算。Unity 6000.0.85f1 的实际第二轮 Play 从第 1 帧开始，低于上一轮留下的第 25 帧。旧版纹理上传准入抛出异常，DXR 构建沿用上一轮的配额和等待顺序。两处准入分别位于传输录制与 RTAS 准备入口。 [Unity 帧计数](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Time-frameCount.html) · [域重载](https://docs.unity3d.com/6000.0/Documentation/Manual/domain-reloading.html) · [实际 Feature 调用](../../../Runtime/HybridLumenGIRendererFeature.cs)

现有 Editor 启动钩子在恢复准入前重置两套帧工作额度，并移除旧的构建需求。退休回调继续持有旧纹理租约、代次与 RTAS 预留，直到各自的完成条件成立。帧预算仍在会话内拒绝旧帧，同帧的多相机调用继续共享额度。 [会话启动钩子](../../../Runtime/HybridLumenGIResourceRetirement.cs)

## 定向对照

在同一隔离 Unity 工程中，仅关闭域重载，保留场景重载。使用 `-batchmode -nographics` 和空场景组件，在第一次 Play 的第 25 帧调用产品的预算方法，用完一次 RTAS 构建额度，留下一个等待需求和 1 MiB 受控退休预留。自然退出后再次进入 Play，以实际第 1 帧调用同一方法。

| 观察 | Release148 源码 | 修复后源码 |
| --- | --- | --- |
| 自然退出和再次进入 | 准入先关闭后恢复 | 准入先关闭后恢复 |
| 纹理上传准入 | 旧帧 25，拒绝第 1 帧 | 取得第 1 帧额度 |
| RTAS 构建准入 | 停在 25，旧需求阻挡新请求 | 切到 1，新请求获准，等待归零 |
| 旧 RTAS 退休账 | 1,048,576 B，完成回调后归零 | 1,048,576 B，完成回调后归零 |

Astra Max 同意按 Editor 会话与托管准入范围采用。这里实际走了 Unity 启动和退出钩子，RTAS 完成与内存占用由受控预留模拟。图形设备为 `Null`。原生围栏跨会话、普通相机画面和 GPU 成本仍按各自条件验收。
