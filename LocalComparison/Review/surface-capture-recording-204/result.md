# Release177 图卡录制 CPU 时间准入

三室热态接替记录的初次预热曾连续四帧各完成 24 张图卡。原实现按图卡数和 draw 数准入。Release177 在 Renderer Feature 增加 `surfaceCaptureRecordingCpuBudgetMilliseconds`。正数为每次相机渲染启用经过时间额度，默认 0 沿用原录制路径。[已有实机负载](../hot-hlod-budget-192/result.md) · [图卡录制](../../../Runtime/HybridLumenGISurfaceCache.cs)

时间从第一张有效图卡的录制起计。整卡的清除、绘制、锚点和就绪更新一起完成。达到额度后，余下卡保留原等待年龄。发现变化时的旧来源失效仍在准备阶段发生。恢复域来自实际录制的已发布卡，并在当前命令序列的缓存更新和时域消费前上传。迟发软域与同一姿态范围合并时保留已解析的接收组。[设置和接线](../../../Runtime/HybridLumenGIRendererFeature.cs) · [变化域](../../../Runtime/HybridLumenGIChangeRegions.cs)

实际 SurfaceCache 源码在现有录制宿主中用三张卡观察。第一张完整录制后超过 1 ms 额度，本次实际上传的三张卡就绪位为 1／0／0，延后两张仍不满足就绪检查。下一帧继续录制第二张，设为 0 后完成第三张。再次改变已就绪来源并将捕获数设为 0，两次元数据上传都撤销旧就绪。实际 ChangeRegions 宿主验证晚合并和命令上传保留已解析姿态组。[图卡用例](../../../Tests/StandaloneSurfaceCache/Program.cs.txt) · [变化域用例](../../../Tests/StandaloneChanges/Program.cs.txt)

首次整套图卡夹具执行在既有发光场景的 `EstimateBytes` 静态反射处中止。随后单独调用本次图卡用例。该用例初版误假定撤销帧只有一次元数据上传，按实际两次上传均拒旧修正断言，产品源码未改。定向图卡与变化域宿主通过。Astra Max 按此范围采用。

适用范围是每次相机渲染的整卡 CPU 命令录制准入。单张卡可以超过额度，准备、已开始的 Unity 调用及 GPU 成本各有自己的时间边界。原生画面、实测帧时间、冷启动与全阶段生产预算仍待验收。
