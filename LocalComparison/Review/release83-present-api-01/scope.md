# Release83 应用 Present 节奏：一次有条件替代采集

960×540／30 FPS 是当前目标。旧呈交采集没有 CSV，原因仍未知。官方 PresentMon 2.6.0 的 `RuntimePresentStop` 在关闭 display tracking 时直接完成 Present；只证明可移除下游显示事件依赖，不证明旧失败归因。

Astra 已审查：只启动现有普通 Release83，同一 DX12、960×540 参数；首先通过窗口实际画面确认场景正常显示，不能确认即正常关闭并停止，不采集。确认后只添加 `--no_track_display`，保留 `--no_track_gpu --no_track_input --v1_metrics` 与唯一 PID，10秒延迟、30秒窗口，其间不输入。没有新构建、产品埋点、ETL 或配置矩阵。

只报告单一 swapchain 的应用 Present 间隔、平均频率与尾部；不称显示 FPS 或 G5 通过。首行没有本窗口锚点，排除首个间隔；无效/缺失数据明确计数。多个 swapchain 不择优挑选。若仍无 CSV，则结束此采集路径，不再改参数或重试。

依据：[同版实现](https://github.com/GameTechDev/PresentMon/blob/v2.6.0/PresentData/PresentMonTraceConsumer.cpp)、[控制台选项](https://github.com/GameTechDev/PresentMon/blob/v2.6.0/README-ConsoleApplication.md)。
