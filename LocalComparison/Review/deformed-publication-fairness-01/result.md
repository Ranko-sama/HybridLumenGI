# 形变快照发布顺序修复

关闭原目标3／ProductionPlan §5的一项具体缺口：已完成作业倒序争用上传额度，持续完成的新快照可使旧的合格ready快照一直等待。现在按捕获入队顺序尝试发布，不引入新队列或预算配置。

旧源码d73144f在单份实际uploadBytes额度下复现反例：older=False、later=False、refresh=True，见[旧源输出](old-source.log)。仅改变BeginContext遍历方向和两处删除后索引推进后，[实际组件宿主](source-check.log)确认旧ready先发布、未完成头项不阻塞、撤销完成项清理不耗发布额度、后续任务继续推进。[既有隔离发布／清理失败例](publication-cleanup-check.log)保持失败项先处理：原Job／旧Published／预留不变，失败销毁不重试，后续健康项仍发布。

这些使用实际组件源码、真实Task屏障以及明确的Unity／烘焙结果适配器，不是GPU、BakeMesh数值或实际动画画质验证。未完成和清理失败保留项仍跳过；大于剩余额度项不阻塞后项。若一份快照永久大于整帧上传额度，仍可能一直等待，不承诺所有任务固定延迟。

公开Release90构建待执行；沿用原统一场景、2ray/DXR及默认关闭的捕获时间门。没有新的Player、图像、性能或颜色／残留／收敛数据。
