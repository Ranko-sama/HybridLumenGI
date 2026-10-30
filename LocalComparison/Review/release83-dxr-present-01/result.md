# 未开始DXR应用Present采集

本次普通Release83/PID7652启动后，唯一截图再次FrameArrived超时。经新鲜文本窗口状态确认目标后，通过现有快捷键5请求DXR；输入后的可访问文本为空，无法确认actual后端。已请求用户读取现有面板，但本窗口期间未收到确认。

**没有启动PresentMon，没有新增DXR应用Present或显示FPS数据。** 等待约八分钟后，主线程通过目标窗口Alt+F4正常关闭，native exit 0、watchdog=false。未自动重启、补建诊断、改默认或改产品。

现有DXR GI成本13.28ms与普通软件Present29.15Hz保持各自口径；前者不能替代尚缺的DXR应用Present结果。原计划保持开放，CI环境选择另待用户回复。这两项依赖不构成整体已完成的证明。
