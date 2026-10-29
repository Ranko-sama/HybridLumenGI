# 后端偏好 API 草稿

`HybridLumenGIRendererFeature.RequestedPreferHardwareTracing` 读取当前实例的请求值；`SetPreferHardwareTracing(bool value)` 原位写入当前 `Settings.preferHardwareTracing`。在Unity主线程、下一次相机渲染准备之前调用。它不启用Feature、不保证DXR可用、不修改`exactSoftwareTracing`或预算。通过现有`GetDiagnostics()`区分实际hardware/exact-software/SDF回退。

实际调用链保持：

- `Create`把同一个Settings引用传给`TransportPass.s`；setter不替换对象，也不调用Create/Dispose。
- `RecordRenderGraph`序列化该Settings。配置hash变化使屏幕history、receiver history及HLOD readiness失效；`PrepareGpuBudget`按完整配置串重置GPU反馈。重复写同一值不改变配置串。
- 不偏好硬件时，下一实际准备调用`CancelBuildDemand`；硬件偏好仍需实际`hardware.Prepare`成功，否则进入原软件路径。
- 实际hardware状态变化时，既有分支更新epoch、失效history/readiness/GPU反馈；材料准备阶段的`FallBackToSoftware`也保留自己的相同失效保护。

请求变化但实际仍回退时，原有配置变化失效仍会发生；不在此窄API中另改这一语义。关闭硬件偏好不等于立即释放已有RTAS，资源生命周期和计账保持原行为。该API不新增手工清空、立即RTAS重建或特殊执行路径。

`backend-preference.patch`与`Runtime/HybridLumenGIRendererFeature.cs`仅增加此property、setter和接口注释。`backend-preference-source.json`记录基线/候选hash及移除新增块后完整字节一致的核对；未运行Unity、部署、GPU或新测试矩阵，完整编译交根代理整合时执行。不要用候选全文件覆盖后续并行修改；先核基线或仅应用小patch。
