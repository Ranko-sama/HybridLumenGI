# 已发布表面变化后的接收面更新顺序

原目标 2／3、工作流 5 的一处接线已补齐。墙面材质或属性块变化时，Surface Cache 已给出了已发布表面的变化边界，GPU 也使用该边界和追踪半径处理局部变化。CPU 分配缓存更新名额时却只知道有照明变化。相同服务年龄下，远处无关表面可能先于换色墙旁的接收面获得更新。

普通 Feature 现在将同一份边界列表和表面影响半径交给实际调度器。变化源和已有局部灯优先级为 1000，附近接收面为 751，其余受全局脏标记影响的积压项为 750。最久未服务的固定份额先分配，剩余名额按优先级竞争。距离按 owner 边界间的最短距离判断。变化列表还可含重新捕获或退休的已发布表面，适合作为保守的更新排序依据。现有公开调用签名继续可用。[调度器](../../../Runtime/HybridLumenGICacheScheduler.cs) · [Feature 接线](../../../Runtime/HybridLumenGIRendererFeature.cs)

既有 CPU 检查运行了真实 Scene 与调度器源码，表面映射和 Unity 类型由原适配器提供。四个单 patch 已就绪且同龄，三个名额中有一个最老服务名额。墙卡片改变，近端与墙的边界间距为 19，远端为 39，表面影响半径为 20，单独的场景几何影响半径为 70。实际选择如下。[固定反例](../../../Tests/StandaloneBvh/SchedulerProgram.cs.txt)

| 更新项 | 只给全局变化 | 同时给表面范围 |
| --- | --- | --- |
| 最老服务名额 | 选中 | 选中 |
| 远端接收面 | 选中 | 等待 |
| 换色墙 | 选中 | 选中 |
| 近端接收面 | 等待 | 选中 |

本项关闭预算竞争时丢失表面变化空间信息的问题。只有一个更新名额时，该名额仍用于最老服务。若所有接收面都在同一影响域内，近远排序无法产生上述取舍。此次结果限定于调度次序，实际画面残留、运动拖影和收敛速度沿用已有测量。[独立画面对照](../dynamic-picture-comparison-01/report.md)

产品源码 `e207593` 已整合到 Release99。Unity 6000.0.85f1 在无图形编辑器中完成普通 Windows x64／Mono／Release 构建，0 个错误、23 个警告，正常退出。运行包同时包含已修正的 GPU 控制说明和离线画面对照。完整解压后运行 `Start-LocalRelease.cmd`，打开 `PictureComparison/index.html` 看图。[下载 Release99](https://github.com/Ranko-sama/HybridLumenGI/releases/download/release99-demo/HybridLumenGI-Release99-Windows-x64.zip) · [构建输入](release-build-attempt.json) · [发布记录](published-release.json)
