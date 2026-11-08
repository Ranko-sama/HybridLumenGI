# Release151 三室中室预算观察

固定中室的 GI 和进程显存均达到起始预算。对源帧 159–670 的 512 个完整原生计时记录，先按源帧相加 ReceiverCapture、Transport、Composite，再取分位数。同一批源帧有 512 次有效 DXGI 进程显存采样。[分析输出](result.json) · [原始源帧](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/run/20261108-163720-ab373bff092b46e78e6fd29bc402ea53/frames.jsonl>) · [原始计时完成记录](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/run/20261108-163720-ab373bff092b46e78e6fd29bc402ea53/completions.jsonl>)

| 指标 | 固定窗口实测 | 结果 |
| --- | ---: | --- |
| 三段 GI 合计中位数／p95／p99／最大值 | 14.074／15.936／16.169／16.566 ms | p95 达到 ≤25 ms |
| 进程 local 显存采样峰值 | 566.191 MiB | 达到 ≤1 GiB |
| 进程 nonlocal 显存采样峰值 | 286.441 MiB | 单列 |
| 应用 Present | CSV 缺失，日志报告丢失 64,691 个 ETW 事件 | 三项同窗证据不足 |

使用产品源码 `027b84c04b85425822fcebe779fe5645b6790988` 的 Release151 Win64 普通观察构建。Unity 6000.0.85f1、RTX 2080 Ti、DX12、实际 DXR。960×540 背缓冲、480×270 GI、2 条射线、4 级滤波，原生计时和显存观察开启，反馈关闭。沿用原 F4 中室机位 (0.36220, 1.5, −5.98923)，中央门打开，五盏灯开启，三件近景细节保持提交。窗口两端各有 168 张就绪卡。[场景及机位](../three-room-passage-01/views.json) · [构建回执](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/setup/build-exit.json>) · [运行记录](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/run/20261108-163720-ab373bff092b46e78e6fd29bc402ea53/run.json>)

首次启动时，观察器仍按旧集合读取可见组，在生成源窗口前退出。记录器也被脚本的 20 秒收尾等待提前终止。另目录的修正观察按原机位和窗口执行。Player 启动前的整机 GPU 利用率为 0%、1%、0%，退出后为 66%、1%、0%。Player 和 PresentMon 均正常退出。原始 QPC 锚点为 452525823317 至 452601472711，频率 10 MHz。由于对应 PID 的 Present 文件缺失，锚点只描述源窗口。ETW 事件丢失与首个退出后 GPU 读数的原因均未知。[首测日志](<I:/Unity test/Comparison/ThreeRoomJoint170/player.log>) · [首次记录器回执](<I:/Unity test/Comparison/ThreeRoomJoint170/setup/present-attempt.json>) · [本次启动回执](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/setup/player-attempt.json>) · [本次退出回执](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/setup/native-exit.json>) · [本次 PresentMon 回执](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/setup/present-attempt.json>) · [本次 ETW 日志](<I:/Unity test/Comparison/ThreeRoomJoint170Corrected/presentmon.log>)

Astra Max 按固定视点的 GI 和进程显存采用，三项联合观察按预定停止线以证据不足收束。该计时限上述原生区间，显存为目标进程有限采样。整应用 GPU 成本、显示帧率、冷入和更高负载按各自条件验收。Release117 的同机位 GI／显存和 Release119 的邻近机位 Present 保留各自范围。[Release117 窗口](../three-room-middle-budget-117/result.md) · [Release119 应用 Present](../three-room-middle-present-119/result.json)
