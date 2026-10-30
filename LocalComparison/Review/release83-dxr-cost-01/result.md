# Release83已有DXR后端的有限成本取舍

**当前本机静止配置中，DXR的GI区间耗时明显低于精确软件基线，为960×540／30FPS目标提供更多时间余量。** 这是已有后端的测量，不是新增算法优化；本轮没有改变普通Release83的默认设置，也不声称等画质加速或实际显示FPS达标。

| 同口径观测 | 精确软件基线 | 本次DXR |
| --- | ---: | ---: |
| GI三区间合计中位 | 28.0172 ms | 13.2765 ms |
| GI三区间合计p95 | 31.1856 ms | 14.3337 ms |
| GI三区间合计p99 | 31.4469 ms | 14.5221 ms |
| Transport中位 | 27.8023 ms | 13.0618 ms |
| 进程local采样峰值 | 577.449 MiB | 560.941 MiB |
| 进程nonlocal采样峰值 | 280.664 MiB | 287.691 MiB |

合计中位观察差−52.61%。不是整应用GPU或帧率增益；没有此次成对图像证据来宣称相同质量。local/nonlocal分别报告，不合并成峰值，也不当作GI独占、瞬时峰值或正式显存预算。对应相机回调平均70.61次／秒，仍不是Present或显示FPS。

两者均为产品0181ef2／Release83、Unity6000.0.85f1／URP17.0.4、DX12／RTX2080Ti、保存UnifiedRelease74场景、960×540 backbuffer／480×270 GI、源窗口159–670。实际记录的测量配置仅preferHardwareTracing从false变true；反馈关闭，配额保持，UI/input关闭。窗口512个完整来源记录全部hardware=true、exactSoftware=false；既有硬件计数稳定为20 meshes／0 fallback，materialUnknown=0。这些是后端选择和计数，不升级为每条射线精确覆盖证明。

现有NativeDX12区间／完成票据与现有DXGI采样均完整。一次Release/None构建成功（0错误、23警告），临时工程配置和观察器已恢复；唯一Player PID27752正常native0退出，watchdog=false。没有新增query、图像、参考积分、产品改动或配置矩阵。普通Release83保持原版本。原生输出：`I:/Unity test/Comparison/Release83DxrCost01/run/20261030-014858-1b24454694c54abb9693b4b44fab07e1`；构建结果：`I:/Unity test/Comparison/Builds/LocalRelease83DxrCost01/build-result.json`。

一次过早分析发生在同一Player仍运行时，尚无run.json，失败记录保留为premature-analysis.json；确认同一进程终止后才完成本报告分析，没有重跑Player或替换原始测量。最终数据见result.json、comparison.json。

原计划目标4／G4补齐当前两种已实现后端的本机成本取舍依据。显示FPS、动态负载、冷启动、软件/DXR画质差异、长时与正式GPU／显存预算仍未因此关闭。既有画面对照及颜色、残留、拖影、收敛结论保持各自来源。
