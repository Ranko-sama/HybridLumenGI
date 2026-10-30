# Release89：可选的形变捕获经过时间准入

已交付[Release89统一入口](<I:/Unity test/Comparison/Builds/LocalRelease89/Start-LocalRelease.cmd>)。本次补齐原目标3／工作流8的一项具体能力：形变快照不再只能按顶点、作业和字节数量限制新捕获，也可在本帧同步捕获经过时间达到额度后延后下一对象。不是实机加速声明，ProductionPlan §5的完整分阶段调度仍开放。

## 行为与使用

新增共享静态设置`HybridLumenGIDeformedMesh.CaptureBudgetMillisecondsPerFrame`，默认0关闭；负数、NaN和Infinity也关闭。调用方可在主线程设置有限正数毫秒；当前统一示例保持默认关闭，原2射线、DXR和形变配置未变。

仅对完整同步捕获尝试累计Stopwatch经过时间，包括BakeMesh或可读流复制、索引整理、已捕获内容检查、任务创建及失败／未变内容的清理。达到额度后，循环在消费下一对象的游标之前停止；下一对象的请求、重试间隔和资源额度不被消耗，下帧仍按轮转顺序准入。至少一个其他条件合格的捕获可以开始，单次不可抢占操作可能越过额度。

来源替换撤回、已完成作业发布／清理、shutdown和退休保持原流程。准入扫描、发布时Texture/mesh构建上传、后台SDF/chart和其他CPU准备不计入此额度。经过时间包含GC／线程抢占等待，不能称CPU核心占用、整帧硬截止或固定形变延迟。详细[用法与边界](../../../Documentation/DeformedGeometry.md)保持这些限制。

## 必要验证与集成

独立源码审阅无阻断。只扩展既有`Tests/StandaloneDeformedMesh/Program.cs.txt`，复用真实组件、原Task屏障及BakeMesh适配器的Captured回调，验证：

- 一个完整尝试越额后，不开始下一个对象，保留其请求／世代／间隔／轮次／预留；同一引擎帧的新相机context不重开额度。
- 下帧先发布已完成作业，再轮到延期对象；发布耗时不被误计为新捕获额度。
- 失败及unchanged早退也消耗捕获经过时间，仍执行原清理或保留已发布快照；后帧延期对象能推进。

一次`Tests/Validate-DeformedMesh.ps1`通过，原默认关闭的取消／发布／额度／退休语义也保留，见[source-check.log](source-check.log)。新增回调只用约1ms短等待确定跨过0.1ms测试额度，不作性能测试或用户预算。宿主没有执行Unity BakeMesh、实际GPU fence或实体显卡。

源码`c125711`已同步本机工程，唯一公开`HybridLumenGI.Editor.HybridLumenGIPlayerBuild.Build`构建成功：Unity6000.0.85f1、Windows64 Mono、Release／None、0错误／23条warning。Unity PID20672，native exit0；原作者Renderer、Quality和初始化器已恢复。来源、保存场景及本机2ray/DXR覆盖见[构建记录](build-attempt.json)，[BuildReport摘要](<I:/Unity test/Comparison/Builds/LocalRelease89/build-result.json>)保存实际输出。构建承担真实Unity编译与集成，没有再执行一份独立编译。

## 保留的画质与性能边界

本次不改变GI着色器、采样或滤波，没有启动Player或新增画质／性能采集。[Release88的运动颗粒取舍](../two-ray-local-quality-01/result.md)、[软件119颜色对照](../release88-color-frame119-01/result.md)和[软件／DXR四时点图](../release88-dxr-motion-01/result.md)继续保持其实际来源。颜色误差、换色／关灯残留、运动拖影和收敛时间没有新的测量结论；旧39.95Hz Present也不重标为89实测。

本线完成产品能力、必要规则验证与可运行整合后结束，不追加Profiler、实机性能窗口、归档校验或新调度框架。默认关闭意味着本次交付没有启用新的性能取舍；正式GI／显存门槛与完整G0–G5仍未关闭。

Astra完成阶段结果审查，同意以这项能力的实现与集成收束；不追加Player、性能或画质运行。
