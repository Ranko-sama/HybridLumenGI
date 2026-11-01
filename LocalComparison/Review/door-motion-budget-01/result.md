# 普通门运动的 GI 时间与进程显存

2026-11-02，统一示例在 RTX 2080 Ti 上运行普通 M 键的门运动周期。960×540、半分辨率 GI、2 条射线、4 级滤波、实际 DXR，关闭自适应反馈。在同一段运动中，**GI 三段合计 p95 为 16.984 ms，进程 local 显存采样峰值为 568.816 MiB**，均满足本机的 25 ms／1 GiB 起始目标。[统计与来源](result.json)

| 指标 | 运动窗口 |
| --- | ---: |
| 逐源帧 GI 合计，中位数 | 15.125 ms |
| 逐源帧 GI 合计，p95 / p99 | 16.984 / 17.502 ms |
| 逐源帧 GI 合计，最大值 | 18.629 ms |
| 进程 local / nonlocal 显存采样峰值 | 568.816 / 289.695 MiB |

连续源帧 159–670 全部启用门运动，门的本地 X 从 −1.1 到 +1.1，帧间位置改变 179 次。普通门周期带有短暂停驻。统计保留停驻帧、重复位姿以及移动引起的缓存更新和上传工作。每个源帧以原生时间戳配对 ReceiverCapture、Transport、Composite，先求和后取分位。显存恰好覆盖相同的 512 个源帧，失败采样为零。[分析入口](analyze.py) · [本机原始时间戳、位置及窗口记录](<I:/Unity test/Comparison/DoorMotionBudget01/run/20261101-190426-786bc0ae4c3d4ac09964785f6e20d7e9/>)

Unity 6000.0.85f1／URP 17.0.4、普通 Win64 Release/None、DX12、源代码 `3b7272e`。测量构建复用已保存场景，通过示例的 `SetDoorMoving(true)` 启动门；相机固定，使用普通后备缓冲。GPU 计时打开，反馈关闭。这个窗口不测 Present、实际显示帧率、整应用 GPU 时间、最坏负载或画质。Release93 先前的静止 GI 和运动 Present 读数各自保留原测量来源。[构建输入](build-attempt.json) · [运行参数](player-attempt.json) · [正常退出](native-exit.json)
