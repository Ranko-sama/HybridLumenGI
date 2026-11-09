# 相机切换 Renderer 后归还旧 RTAS 预算

在同一 URP Asset 内，相机通过 `SetRenderer` 从 A 切到 B 后，Release202 仍把相机的旧状态保存在 A。旧 RTAS 持续占用共享额度，新 Renderer 即使单独能装下场景，也只能录制软件追踪。

修复在确认渲染循环空闲时检查相机归属。当相机改选同一 Asset 内仍存的另一个 Renderer，且目标未安装旧 Feature 时，旧 Pass 摘除该相机状态并交给现有退休流程。旧 RTAS 的账本额度在已有栅栏通过且原生释放成功后归还。[相机归属](../../../Runtime/HybridLumenGIRendererFeature.cs) · [资源退休](../../../Runtime/HybridLumenGIResourceRetirement.cs) · [RTAS 释放](../../../Runtime/HybridLumenGIHardwareBackend.cs)

| 同输入观察 | Release202 | 修复版 |
| --- | --- | --- |
| 禁用相机后手动向 A 提交渲染 | 保留原相机状态并录制 DXR | 保留原相机状态并录制 DXR |
| 切到 B，A 最后录制于引擎帧 5 | B 在帧 5–16 连续 12 次因共享额度录制精确软件，A 的预约仍占 642,560 字节 | B 在帧 5 因同一额度限制录制精确软件。随后采样确认旧预约已释放，账本为 0。B 在帧 6 录制 DXR，账本为 642,560 字节 |
| 切回 A | 本程止于 B 的持续阻塞 | 帧 8 以新状态录制 DXR，B 的预约已释放 |

两程均保留仍由 A 服务的第二台手动相机。切换由同一台 Base 相机发起，两条 Renderer 使用不同的 Feature 实例。共享 RTAS 上限为 1,048,576 字节，使用一份 3,000 三角面的实际场景几何。对照在 Unity 6000.0.85f1、RTX 2080 Ti、D3D12 Editor Play 中运行，记录后端实际录制、预约释放和共享账本。采样间隔内的退休票据寿命未知。生产预算的应用总显存与帧时间继续分别验收。[Release202 记录](baseline.json) · [修复版记录](fixed.json)

本次关闭同一 URP Asset 内 Base 相机改选不同 Feature 的 Renderer 时，旧状态阻塞新 RTAS 准入的缺口。渲染管线 Asset 更换、Renderer 重建与完整 G4 按各自范围验收。
