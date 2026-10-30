# Release87 普通门运动的应用 Present 结果

本机当前统一示例以960×540窗口参数启动、默认DXR、M门运动开启；唯一30秒窗口的应用 Present 平均 **70.85Hz**，p95／p99间隔 **16.73／17.80ms**，所有观测间隔小于33.33ms。这为当前交付版本的门运动补齐有限性能依据，支持用户30FPS开发方向；不等于显示器实际FPS或完整G5放行。

| 项目 | 结果 |
| --- | ---: |
| 两端Present时间跨度 | 29.9647291秒 |
| 应用Present平均频率 | 70.849965Hz |
| 平均／中位间隔 | 14.114333／14.087700ms |
| p95／p99间隔 | 16.734180／17.802000ms |
| 最大间隔 | 19.012000ms |
| 超过33.333333ms的间隔 | 0／2123 |

原CSV共2124行，同一Player PID17992、单一DXGI交换链。沿用原统计规则：仅去掉缺少窗口前锚点的首条间隔，其余2123条全部保留；间隔之和与时间戳跨度相符，百分位采用(N−1)×q线性插值。SyncInterval=0、PresentFlags=512。display tracking关闭，不能将Dropped字段解释为显示掉帧统计。

## 使用条件和实际过程

既有Release87／e352921、Release/None、保存统一场景，不改产品、构建或质量参数。M运动是已有普通交互功能，循环包含开门、保持与返回，并非每帧最大负载。静止成熟历史不触发本次滤波新增邻居读取，因此没有运行静止配对。

computer-use的实际窗口观察显示正常三维场景，M输入后门位置已改变；截图用于普通运行和动作确认，没有另建画质对照。采集前后F2分别在engineFrame4147／9376记录最新CPU状态：

- 两端actualBackend=DXR、20个hardware meshes、0fallback；hardwareTransformUpdates由429增至2064，支持该窗口持续请求门运动的有限判断。
- 两端均为complete details published、3个visible成员，页面loading／failed、实例warming／pending capacity为0。
- GPU计时、预算反馈、进程显存采样均保持关闭。计时窗口内没有输入、截图或日志操作。

端点不是每帧或逐射线证据，也没有直接测量每个像素进入短历史分支。960×540依据本次启动参数，未增加逐帧渲染尺寸记录。

PresentMon2.6.0仅运行一次：PID17616，10秒delay＋30秒timed，2026-10-30 08:58:28.883232至08:59:08.936933 UTC，正常exit0。普通Player于08:57:08.237268启动，采集后正常Alt+F4关闭，08:59:33.089439 exit0；两者watchdog均未触发。

首次F2已经写入日志，但后续UI刷新同时关闭text/screenshot被工具拒绝；随后只刷新窗口状态，未重复F2或测量。复用分析脚本的旧截图标志最初硬编码false，已按实际before记录修正，`metadataCorrection`保留说明，所有时序数据和统计未变。

## 结论和边界

主线程、独立结果复核及Astra同意收束。关闭的是“当前交付版本门运动缺少有限性能依据”的子缺口；不据此填写尚未决定的GI／显存预算，不测算GI专项或滤波增量成本，不与Release84静止窗口相减作加速／开销归因。没有新增软件、显存、长时或动态矩阵。

当前颜色误差、换色／关灯残留、运动画质与收敛结论仍见原[独立画面对照](../dynamic-picture-comparison-01/report.md)，本次Present测量不替代它们。产品仍是Release87，不追加构建或窗口，完整G0–G5仍开放。

数据：[完整数值](result.json)、[采集前](before-ledger.json)、[采集后](after-ledger.json)。原CSV与Player日志位于 `I:/Unity test/Comparison/Release87MotionPresent01`。
