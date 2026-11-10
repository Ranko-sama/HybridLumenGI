# Base 转为 Overlay 后归还旧 RTAS 预约

原计划 T6／G4 的共享内存准入缺口。Release259 的闲时相机扫描把 Overlay 返回的空 Renderer 当作保留旧状态。同一 Renderer 上最后一台 Base 转为 Overlay 后，旧 Feature 仍启用，旧相机失去继续准备或触发驱逐的机会。其他 Feature 的合格请求可能持续被旧预约挡在共享额度之外。修复让同一活动 URP Asset 内确认转为 Overlay 的相机走现有闲时退休。[原切换对照](../renderer-budget-242/result.md) · [分页读者的既有范围](../overlay-camera-page-retention-01/result.md)

实机沿用两个 Renderer、不同 Feature、一份 3,000 三角形的普通 Lit 网格及 **1 MiB** 共享 RTAS 额度。Unity 6000.0.85f1、RTX 2080 Ti、DX12 Editor Play。A 禁用时先手动提交一次，复用已有状态。随后 A 保持相同 Renderer，转为 B 的实际 Overlay。B 首次手动提交时两份 RTAS 仍无法同时准入。

| 实际节点 | 观察 |
| --- | --- |
| 帧 5，A 仍为禁用的 Base | 手动提交继续录制 DXR，使用原状态。 |
| 帧 5，A 转 Overlay 后 B 首次提交 | B 因共享内存额度录制精确软件。A 仍有 642,560 B 预约。 |
| 帧 5，闲时摘除之后、栅栏提交之前 | A 已退出相机跟踪。一份待退休所有权和完成票据仍保留 642,560 B 预约。 |
| B 下一次成功录制 | B 在帧 6 录制 DXR。随后读回确认 A 的预约已释放，账本只剩 B 的 642,560 B。 |

A 的最后一次 GI 录制仍为帧 5，原生 Overlay 实际提交 3 次。Unity 正常退出。采用范围为同一 URP Asset 内的 Base 角色切换、实际旧预约退休和另一 Base 的重新准入。原进程显存、整景画面及其他生产负载继续分别验收。[实机记录](result.json)
