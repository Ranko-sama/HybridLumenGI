# Release93 普通门运动的应用 Present

当前统一版本为 Release93，filter4／2ray／默认 DXR。旧运动 Present 来自 Release88／filter3，当前静止 GI 时间不能替代应用运动帧率。Astra 已审查同意用现有流程补齐这一明确缺口，且限单个窗口。

启动已构建的普通 Release93／Runtime aeb6ba2 一次，以 960×540 参数运行保存统一场景，GPU 计时、反馈及显存观察关闭。M 请求普通门运动，F2 记录前后状态。复用 PresentMon 2.6.0，固定 10 秒延迟＋30 秒应用 Present，关闭 display/input/GPU 跟踪。计时内不操作 UI、不截图、不请求日志。随后正常退出。

端点实际 DXR、就绪状态及 hardwareTransformUpdates 推进连同 M 请求提供有限运动依据。UI 可读时辅助确认场景和门位移；不可读不另造前置条件，无运动依据则注明局限且不补测。普通门循环包含开、保持和返回，不代表每帧最大负载。

原样复用统计，保留尾部和超过 33.333ms 的间隔。应用 Present 不是显示 FPS、整帧 GPU 或 GI 增量时间；一次本机窗口不是完整 G5 验收。没有新构建、探针、哈希、参数或配置矩阵。无论结果如何均结束本线，不连跑取最好值。
