# 普通DXR模式的应用Present窗口

Astra认可唯一一次必要测量：软件普通Present窗口29.15Hz，而DXR已有GI耗时13.28ms，仍缺普通运行的应用呈交依据。

启动不变的普通Release83，原DX12／960×540参数、初始相机、普通UI；通过现有按键5或Prefer DXR按钮启用已有后端。采集前必须由现有UI／ledger确认actual DXR；无法确认即停止，不新增诊断。之后沿用软件Present工具参数（no_track_display/input/gpu，v1_metrics），10秒等待、30秒唯一PID窗口，无输入、配置或视角变更。报告平均频率和全部间隔分布，首行间隔排除，多个swapchain或无效值不择优。

只回答当前普通DXR模式的应用Present节奏，不称实际显示FPS、等画质、动态稳定30FPS保证或G5通过。不改默认、重建、扩矩阵或自动重试。
