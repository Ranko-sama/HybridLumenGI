# Release215 热态 HLOD 接替的同窗结果

使用 Release215 的同源普通 Win64 观察版，在 RTX 2080 Ti、DX12、960×540 下沿原固定路线以每秒 20 世界单位往返十次。16 帧完整近景就绪后才出发。GI 为 480×270、2 射线和 4 级滤波，实际 DXR。原生 GI 计时与进程显存观察开启，反馈关闭。只加入原路线观察器和 Unity 已启用的帧计时读取。[Release215 同源工程](../inactive-software-geometry-260/delivery.json) · [原路线与窗口定义](../hot-hlod-budget-192/result.md)

两方向各取得十次完整发布和下一次相机开始的完整提交。40 段接替及退休窗口覆盖 480 个相机源帧，完整路线有 1,123 个连续源帧，均取得同一相机、代次和设备的 NativeDX12 三段完成记录。显存用完整路线内的进程采样。Player 正常退出。[预算与窗口原判定](result.json)

| 指标 | 中位 | p95 | p99 | 峰值 |
| --- | ---: | ---: | ---: | ---: |
| 接替及退休窗口，GI 三段逐源合计 | 7.142 ms | 17.365 ms | 19.019 ms | 19.660 ms |
| 完整路线，进程 local 显存 | — | — | — | 570.941 MiB |
| 完整路线，进程 nonlocal 显存 | — | — | — | 288.313 MiB |

GI 与 local 两项均通过原 25 ms／1 GiB 起始门。统计范围是该热态路线和有限显存采样。

## 应用 Present 的可用范围

Unity 的 `FrameTiming.cpuTimePresentCalled` 记录 Player 调用 Present 的 CPU 时间。现行工程已开启 Frame Timing Stats。实际 CPU 时钟和相机 QPC 均为 10 MHz。路线开始前已取得有效时间戳。按 `frameStartTimestamp` 去重后，源帧 45–1166 在各自相邻相机开始区间内均有一条记录。最后取得的 Present 调用晚于末窗口终点 8.983 ms。[Unity Present 时间戳](https://docs.unity3d.com/cn/6000.0/ScriptReference/FrameTiming-cpuTimePresentCalled.html) · [时钟和墙钟区间](observed-present-overlap.json)

按原窗口保留与其重叠的完整相邻调用间隔，共 510 个观测。中位 10.787 ms，p95 19.801 ms，p99 24.643 ms，最大 30.214 ms，按均值换算为 84.36 次调用／秒。全部观测间隔均在 30 FPS 对应的 33.333 ms 内。Astra Max 复核了窗口内的连续记录和越过终点的末次调用。按原墙钟口径关闭这条固定热态路线的应用 Present 节奏子项。屏幕刷新和逐源 Present 归属各有独立口径。

本次观察器在已收到完整 GI 票据、Present 时间戳跨过末窗口时结束。Unity 的延迟返回使最后源帧 1167 的 Present 记录未取回，事前逐帧资格检查保持 `insufficient`。现有连续调用已经覆盖原墙钟窗口。此处保留全部实际观测和逐帧原判定。[原始 Player 记录](<I:/Unity test/Comparison/HotHlodUnityPresent261/run/run.json>) · [退出回执](<I:/Unity test/Comparison/HotHlodUnityPresent261/setup/native-exit.json>)
