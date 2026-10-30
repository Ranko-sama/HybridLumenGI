# 未满足画面确认条件，未执行采集

普通 Release83 本次正常启动为 PID35532，窗口标题 HLGI-Comparison。一次实际窗口截图再次报告 `FrameArrived timed out: timed out waiting on channel`；文本窗口状态可读，但不能证明三维场景正常显示。

按事先条件停止，**没有启动 PresentMon，没有新的帧率测量**。使用目标窗口 Alt+F4 正常关闭，native exit 0，watchdogTerminated=false，记录见 `native-exit.json`。未改产品、未构建、未追加截图或参数尝试。原有 GI／回调基线不升级为呈交 FPS。

已请求用户确认实际是否看到正常场景；在缺少该事实时，结束此自动采集路径，不把截图工具故障等同产品渲染故障。CI 环境另有独立待确认项，两者均不证明整个原计划全局受阻。
