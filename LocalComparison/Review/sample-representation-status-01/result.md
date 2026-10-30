# 普通示例的表示需求与可用状态

原G4的使用层存在一个漏接：样例已经请求细节页，但在全部绑定前不启用detail proxies，Scene仍可能报告root→root。此时普通UI／F2只显示aggregate published，无法区分主动只要聚合体与细节尚未可用的降级。

最小修改仅在`HybridLumenGIUnifiedSample`保存实际Update发出的需求及引擎帧，并在现有Ledger／UI关联已绑定、当前可提交的作者root/detail集合。输出`requestedRepresentation`、`availableRepresentation`、`representationStatus`、`requestEngineFrame`和范围说明。区分未评估、主动不请求、无完整可提交组、聚合体可用但请求细节、保留细节等待聚合体、请求表示已可用以及未知状态。重复身份、混组、不完整或无效来源不冒充完整可用组。

请求是最近一次样例Update的结果，可用集合来自原发布后保留的visible集合和读取当时的绑定／Renderer标志；原publication帧字段继续保留。它不是逐像素覆盖、当前GPU完成、灯光收敛或通用覆盖判定器。没有改动页需求算法、调度、HLOD原子发布、渲染或画质参数；界面只显示已知需求，不推断具体延迟原因。

Astra认可这一明确展示漏接及验证边界：独立源码审阅与一次公开Release91构建足够，不新建镜像断言、不启动Player或重跑路线。独立源码审阅无阻断，确认请求时点、停用撤回与unknown处理保持上述范围，未改变调度及可见集合。

源码7b47406已同步本机工程，一次公开`HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build`构建成功：Unity6000.0.85f1、Windows64 Mono、Release／None、0错误／23条warning。Unity PID24268、native exit0，原Renderer、Quality及初始化器已恢复。[构建来源](build-attempt.json)、[退出记录](build-exit.json)与[BuildReport摘要](<I:/Unity test/Comparison/Builds/LocalRelease91/build-result.json>)保留。

[启动Release91](<I:/Unity test/Comparison/Builds/LocalRelease91/Start-LocalRelease.cmd>)沿用原统一场景、2ray/DXR及默认关闭的测量／反馈／捕获时间门。没有新的Player、图像或成本运行；原25ms／1GiB起始目标和Release90静止测量、热态路线保持其原来源，画质依据保持Release88来源，完整G0–G5仍未放行。
