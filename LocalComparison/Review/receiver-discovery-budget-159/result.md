# 接收面发现的 CPU 时间准入

原接收面发现会先枚举并检查整批加载的 LODGroup、Renderer 和材质。接收面记录数及网格指纹字节限制在这次扫描之后才生效，因而不能阻止该阶段继续读取来源。

Renderer Feature 的 `receiverDiscoveryCpuBudgetMilliseconds` 默认是 0。启用时，同一次相机图中的初次发现、材质捕获复核及对象身份捕获复核共享 `Stopwatch` 额度。只累计每次发现调用内的经过时间。达到额度后停止后续 LOD、Renderer、材质槽或拓扑检查，返回不完整结果。

## 受控功能对照

复用 `Tests/Validate-LitQualification.ps1`，编译完整运行时的 ReceiverDiscovery 与 LitQualification。两件普通 Lit Renderer 的来源读取和用于精确边界的时钟由既有 C# 宿主提供。

| 调用 | 工作与结果 |
| --- | --- |
| 初次发现 | 100 tick 额度中消耗 60，两个来源完整，原生 Lit 资格通过 |
| 同一额度重验 | 间隔中的 500 tick 不计。第一件来源消耗剩余 40，第二件 Renderer 的材质读取次数未增加 |
| 不完整结果 | `ScanComplete=false`，只保留已完成的一项供诊断，实际 LitQualification 拒绝原生替换资格 |
| 再次重验 | 同一额度耗尽后，未再次枚举已加载对象 |
| 新调用 | 采用真实 `Stopwatch` 的充足新额度恢复完整扫描，默认零值入口也完整 |

现行 Feature 的三处调用共用同一图内实例。初次扫描不完整时，原生替换走既有拒绝入口并保留原生画面。接收面 Registry 拒绝把不完整结果作为身份依据，后续重验失败也不会签发对象历史回执。实际图接线由源码审阅与普通项目构建覆盖。

Astra Max 同意按此范围采用。已经开始的 Unity 对象枚举或一次来源调用会运行到完成。此能力限制后续检查的启动，网格指纹、其他 CPU 准备、GPU 工作和生产毫秒验收仍各自处理。
