# 高更新负载的同窗应用呈交

Release248 同源普通 Win64 Player 在默认近景运行原并发负载。门的位置变化 764 次，骨姿变化 2,417 次，实际灯表在 0 和 5 之间逐源交替。35.0206 秒内源帧 191–2608 连续使用 DXR，共 2,418 帧。使用 Unity 6000.0.85f1、URP 17.0.4、RTX 2080 Ti、DX12、960×540／GI 480×270、2 条射线和 4 级滤波，反馈关闭。Player 正常退出。[Release248 来源](../screen-world-layer-308/delivery.json) · [实际记录与退出回执](<I:/Unity test/Comparison/CombinedPresent310>)

| 同窗指标 | 中位 | p95 | p99 | 最大值或采样峰值 |
| --- | ---: | ---: | ---: | ---: |
| GI 三段逐源合计 | 14.376 ms | **17.198 ms** | 18.410 ms | 19.593 ms |
| 应用 Present 间隔 | 14.466 ms | **21.443 ms** | 23.937 ms | **37.428 ms** |
| 进程 local | — | — | — | **573.691 MiB** |
| 进程 nonlocal | — | — | — | 302.914 MiB |

原 Release233 的并发窗口因 ETW 丢失事件而缺少应用呈交数据。这次复用热态 HLOD 已采用的 Unity `FrameTiming.cpuTimePresentCalled`。Present 与相机窗口使用同一 10 MHz CPU 时钟，去重的帧开始戳数与源窗口一致。完整呈交间隔覆盖窗口两端，保留与窗口相交的全部 2,418 个间隔，按均值为 68.99 次调用／秒。统计量描述应用调用 Present 的节奏，实际显示刷新另计。[原 ETW 记录](../combined-update-cost-285/result.md) · [既有 Unity 采集依据](../hot-hlod-unity-present-261/result.md) · [Unity API](https://docs.unity.com/en-us/engine/6000.0/script-reference/unityengine/frametiming/cputimepresentcalled)

GI p95 与进程 local 有限采样分别达到 25 ms 与 1 GiB 起始门槛。唯一超出 33.333 ms 的间隔跨过活动窗口起点，从起点前 25.960 ms 延续到起点后 11.468 ms。完全位于窗口内的 2,416 个间隔最大为 28.825 ms。按事前冻结的重叠范围保留跨界长帧，因此全窗严格 30 FPS 间隔子项保持开放。Astra Max 复核采用范围，单个跨界间隔的成因未定。
