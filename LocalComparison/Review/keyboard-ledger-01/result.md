# Release84：普通运行状态的键盘入口

**已为统一示例接通F2，直接调用已有Log ledger功能。** 用户可在普通Player里用键盘把当前请求/实际后端、资源就绪情况和已有预算状态写入Player日志。沿用窗口焦点与GPU目标输入框门控，不改变GI、后端默认值、计时、反馈或显存采样开关，不增加自动日志或观察器。

产品来源a3a570e，GI仍为0181ef2。[Release84统一入口](<I:/Unity test/Comparison/Builds/LocalRelease84/Start-LocalRelease.cmd>)复用已保存场景，公开Release/None构建成功，0错误、23条warning。Unity构建PID7844／会话20504正常退出；Quality设置与原初始化脚本恢复。

同一个普通Player PID2892中实际按5请求DXR、按F2导出日志成功。采集前后两次F2都记录了当前后端、相机帧与就绪资源；普通窗口通过Alt+F4正常退出0，没有watchdog终止。既有日志功能的键盘接线已经实际可用；没有为两行交互接线新增单元测试。

该日志仍是最新CPU诊断，不是GPU完成或逐帧光追证明。复用它完成的[应用Present测量](../release84-dxr-present-01/result.md)单独说明性能范围。没有通过截图确认新窗口画面，也不把既有画质对照重标为Release84的新测量。
