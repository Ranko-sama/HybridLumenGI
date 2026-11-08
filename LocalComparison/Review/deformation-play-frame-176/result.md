# 快速进入 Play 后的形变捕获

Release154 在一次关闭域重载和场景重载的 Unity 6000.0.85f1 Editor 序列中，第二轮 Play 的第 1 帧启动了新捕获。该输入未复现旧帧号延迟下一轮捕获的问题。[原始记录](result.json)

独立解压 `b95c021a` 的可编辑工程，以 Null 图形设备运行两个实际 Play 会话。单个可读三角网格走组件的默认 MeshFilter 捕获。观察器在指定帧直接调用产品的 `BeginContext`，由实际 Unity 提供 Play 状态和帧号。第一次在帧 25 启动捕获并退出。第二次在帧 1 准入开放，组件有效、来源可读且有新请求。全局上次处理帧仍为 25，组件的 `lastCapture` 已恢复为初值 `-1000000`。调用后在途作业从 0 变为 1，`PendingFrame` 为 1。

两轮记录的 Unity 实例 ID 均为 `-26718`，托管引用比较返回 `false`。原观察器要求托管引用相同，因此仍记录 `insufficient`，退出码为 1。Astra Max 审查后按该实际场景收束。该结果限于一次观察及捕获启动，无法判断托管组件确实保留时的行为、骨姿变化后的发布或 GPU 消费。[Unity 日志](<I:/Unity test/Logs/SkinPlayFrame176Baseline.log>)
