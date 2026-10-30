# 形变快照发布顺序修复

关闭原目标3／ProductionPlan §5的一项具体缺口：已完成作业倒序争用上传额度，持续完成的新快照可使旧的合格ready快照一直等待。现在按捕获入队顺序尝试发布，不引入新队列或预算配置。

旧源码d73144f在单份实际uploadBytes额度下复现反例：older=False、later=False、refresh=True，见[旧源输出](old-source.log)。仅改变BeginContext遍历方向和两处删除后索引推进后，[实际组件宿主](source-check.log)确认旧ready先发布、未完成头项不阻塞、撤销完成项清理不耗发布额度、后续任务继续推进。[既有隔离发布／清理失败例](publication-cleanup-check.log)保持失败项先处理：原Job／旧Published／预留不变，失败销毁不重试，后续健康项仍发布。

这些使用实际组件源码、真实Task屏障以及明确的Unity／烘焙结果适配器，不是GPU、BakeMesh数值或实际动画画质验证。未完成和清理失败保留项仍跳过；大于剩余额度项不阻塞后项。若一份快照永久大于整帧上传额度，仍可能一直等待，不承诺所有任务固定延迟。

源码8f0cdc8已同步本机工程，唯一公开`HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build`构建成功：Unity6000.0.85f1、Windows64 Mono、Release／None、0错误／23条warning。Unity PID22432、native exit0；原作者Renderer、Quality及初始化器已恢复。[构建来源](build-attempt.json)、[退出记录](build-exit.json)与[BuildReport摘要](<I:/Unity test/Comparison/Builds/LocalRelease90/build-result.json>)保留。

[启动Release90](<I:/Unity test/Comparison/Builds/LocalRelease90/Start-LocalRelease.cmd>)沿用原统一场景、2ray/DXR及默认关闭的捕获时间门。没有新的Player、图像、性能或颜色／残留／收敛数据；Release88的画质／Present依据继续保持其实际来源，完整G0–G5仍未放行。

独立源码审阅无阻断，Astra同意以必要组件规则验证与一次公开构建收束本线，不追加采集或调度框架。
