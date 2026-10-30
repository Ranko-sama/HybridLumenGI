# 普通Release83的呈交节奏

用户已选择960×540／30 FPS目标。现有GI原生区间与相机回调不能直接代表应用Present或显示更替；Astra认可补这一次必要观察。

只运行现有普通Release83，使用原启动参数、固定初始相机、默认精确软件路径、半分辨率GI、普通UI和默认关闭的GI计时／反馈／显存面板。窗口可访问状态确认目标窗口获得焦点，但截图两次FrameArrived超时，不能声称已视觉核实场景ready／实际后端。此限制在采集前明确保留：本次只报告该已交付Player的呈交与显示事件，不补建图像／就绪观察器。当前日志未报渲染错误；启动已等待超过一分钟后，再以PresentMon延迟10秒固定记录30秒，期间不输入或改变状态。结束通过普通关闭操作退出。无新构建、产品埋点、场景／后端矩阵或补跑。

使用官方便携PresentMon 2.6.0 x64控制台程序，仅按该Player PID采集，独立命名ETW session；不开服务或GUI，不停止别的session。关闭GPU工作量和输入跟踪，保留应用Present／显示记录及丢弃帧，采用v1 CSV字段。数据可能经过DWM；必须分别报告Present间隔与工具记录的显示更替间隔，不声称物理屏幕扫描／光子测量。

分析只针对唯一目标进程和单一swapchain；若出现多个链或必要字段不可用，保留不确定性，不挑最有利子集。首行没有本窗口内前置锚点，其Present间隔不计入窗口统计；后续缺失/非正值明确计数。显示统计仅使用有显示记录的相邻间隔，丢弃帧单列。输出平均频率、间隔中位/p95/p99/max及超过33.33ms的观察比例；不把倒数p99称为平均FPS，也不把一个静态短窗口升级为动态/长时/G5通过。

工具来源：[官方v2.6.0发行](https://github.com/GameTechDev/PresentMon/releases/tag/v2.6.0)、[相同版本控制台说明](https://github.com/GameTechDev/PresentMon/blob/v2.6.0/README-ConsoleApplication.md)。本机便携目录为`I:/Unity test/Tools/PresentMon-2.6.0`，保留原LICENSE；未安装服务，也未进行hash核验。
