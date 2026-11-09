# 自动蒙皮换姿态后的实际 DXR 命中

Release231 在改骨姿后使用了新的自动 `BakeMesh` 快照。固定物体变换与材质，只有上部顶点跟随骨骼移动。沿用 Release154 的单三角和两条射线。前次在改骨后未取得第二端点，本次的 20 秒观察窗从初始读回完成并改骨后起算。[Release154 的原结果](../native-skinned-hit-175/result.md)

| 射线原点，方向均为 +X | 初始姿态 | 更新后 |
| --- | --- | --- |
| `(0, 0, 0)` | 命中，距离 1.25 | 已知未命中 |
| `(0, 0, 0.5)` | 已知未命中 | 命中，距离 1.50 |

初始快照捕获于第 5 帧，实际查询和改骨在第 6 帧。新快照捕获于第 9 帧，第 10 帧在同一 slot 0、stable ID 1 和 primitive 0 完成查询。owner 和 geometry revision 均由 6 更新到 7，三角上传和场景构建各增加一次，变换更新仍为零。观察器从改骨到首次读到新发布经过 0.108 秒，计时终点在第二次 GPU 查询前。[原始读回](result.json)

使用 Release231 同源可编辑工程 `c357485ed56887b667d0c5faa91d44c1aea4f97a`。Unity 6000.0.85f1 Editor Play、RTX 2080 Ti、DX12。观察器用显式相机请求驱动组件，再调用产品 DXR 后端和 `HLGIHardwareTraceQuery` 读取命中。采用范围为 G3／G4 的单三角新姿态消费。普通 Player 的画面、运动拖影及形变消费延迟另行验收。[同源工程](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release231-demo) · [本机退出回执](<I:/Unity test/Comparison/SkinPoseDxr282/native-exit.json>)

Editor 在同步读回后从 `Update` 退出 Play 并关闭。进程返回 0，最终退休日志仍有 8 条待处理项及 38,976 字节形变预留，DX12 报告 6 个未释放缓冲。普通 Player 的退出归属与资源放行继续开放。[本机 Unity 日志](<I:/Unity test/Logs/SkinPoseDxr282.log>)
