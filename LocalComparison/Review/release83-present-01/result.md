# 普通 Release83 呈交采集未取得有效数据

当前目标为 960×540／30 FPS；本次没有获得可用于判断该目标的数据。

普通 Release83（产品源码 0181ef2）按原 DX12、窗口 960×540 参数启动。PresentMon 2.6.0 对唯一 Player PID 延迟 10 秒、记录 30 秒后正常返回 0，日志只有 `Started recording.` 和 `Stopped recording.`，没有生成 `present.csv`。不能将工具正常退出解释为测量成功，也不能把没有事件解释为零 FPS 或产品渲染故障。

窗口的文本可访问状态可读，但两次截图均 `FrameArrived timed out`，一次关闭按钮输入因 `coordinate input geometry is unavailable` 失败。未视觉确认场景就绪或实际后端。随后使用该目标窗口的 Alt+F4 正常关闭 Player，native exit 0、watchdogTerminated=false；启动与退出记录见本目录 JSON。未重跑、未追加配置、未修改产品或新建观察系统。

原始日志保留在 `I:/Unity test/Comparison/Release83Present01/player.log` 与 `presentmon.log`。现有 GI 区间耗时和相机回调基线仍保留各自口径；实际 Present／显示节奏仍未测得，G5 未因此关闭。

一次只读核对未定位原因：PID 与启动记录一致，参数符合[同版控制台说明](https://github.com/GameTechDev/PresentMon/blob/v2.6.0/README-ConsoleApplication.md)，没有关闭 CSV 或显示跟踪；关闭 GPU 工作时长和输入跟踪不等于关闭 Present 跟踪。[同版输出实现](https://github.com/GameTechDev/PresentMon/blob/v2.6.0/PresentMon/OutputThread.cpp)允许从事件查询已启动进程，因此不能仅凭“工具晚于 Player 启动”归因。日志未提供足够信息区分目标窗口状态、事件采集或其他原因。此核对到此结束。
