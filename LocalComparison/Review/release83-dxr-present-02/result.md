# Release83 DXR Present：截图恢复复查仍失败

用户报告截图工具可能已恢复后，只启动既有普通 Release83 一次；未重新构建或修改产品。

- Player PID 15656，960×540、DX12，2026-10-30 02:46:24.758275 UTC 启动。
- 正确绑定 HLGI-Comparison 窗口后截图返回 `FrameArrived timed out: timed out waiting on channel`。依照工具恢复规则重新查询并绑定同一窗口，唯一一次重试返回相同错误。
- 文本可访问性仍能读取窗口标题和关闭控件；这不能证明实际渲染画面或后端。不能据截图失败判断场景黑屏、桌面锁定或产品渲染故障。
- **未发送快捷键 5，未确认实际 DXR，未启动 PresentMon。** `capture.py`、`analyze.py` 仅准备，均未执行；没有新的帧率数据。
- 通过 Alt+F4 正常关闭，原生进程 02:47:15.380972 UTC 退出，exitCode=0，watchdogTerminated=false；启动工具会话 93547 已终止。

原有软件 application Present 29.15 Hz 与 DXR GI 成本 13.28 ms 结论不变。此次仅确认截图通路仍不可用，没有关闭新的产品验收缺口，不据此改变默认后端或宣称 G5 完成。
