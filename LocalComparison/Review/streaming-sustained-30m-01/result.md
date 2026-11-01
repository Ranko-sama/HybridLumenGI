# G4 · 30 分钟流式释放与恢复

2026-11-02，本机统一示例在 1,800.0003 秒内完成 30 轮离场与返近，Player 自行正常退出。每次离场时，该组的页、引用和 IO 都已排空。每次返近时，相机都收到本轮新发布的完整 DXR 细节组。这个结果关闭了 G4 在这条路线上的长时使用缺口。[逐端点原始账目](windowed-endpoints.jsonl) · [退出记录](windowed-exit.json)

| 稳定端点 | 近场页 / 消费引用 | 包字节 / 驻留估算字节 | 可见 / 绑定 | 进程 local / nonlocal 当前值 |
| --- | --- | --- | --- | --- |
| 初始近场 | 13 / 18 | 139,484 / 567,710 | 3 / 4 | 565.129 / 288.043 MiB |
| 全部 30 次离场 | 0 / 0 | 0 / 0 | 0 / 0 | 554.066 MiB / 首次 288.043 MiB，其余 287.395 MiB |
| 全部 30 次返近 | 13 / 18 | 139,484 / 567,710 | 3 / 4 | 566.004 / 287.395 MiB |

在第 1、15 和 30 分钟及其余返近端点，资源状态相同。各稳定端点的加载、释放、失败、在途 IO、待退休租约及 GPU 资源退休的 pending、owned、failed、unknown 均为零。相机 GI 工作帧从 32 推进至 53,894。离场时对象 SDF 估算由 8,396,800 B 降至 8,196 B，RTAS 计账由 132,096 B 降至 0，返近时均恢复。相机屏幕纹理估算保持 33,177,600 B。这些计数分别描述页、资源容量及进程使用量，不可相加。

进程显存的采样峰值为 **local 574.508 MiB、nonlocal 288.359 MiB**，包含预热，53,895 次有效采样，失败 0 次。local 在此次使用中满足 1 GiB 起始目标。数据覆盖驻留范围切换后的稳定端点，未采集转场每帧画面和 GI GPU 耗时，也不能排除瞬时显存峰值。

使用 Release100 产品源码构建的专用 Player、Unity 6000.0.85f1、RTX 2080 Ti、DX12、960×540、半分辨率 GI、2 条射线、4 级滤波。定时输入调用普通示例的 `Leave()` 和 `GoNear()`，后台目标为 30 FPS。Release101 另含相机 LOD 淡变材质修复。[范围与构建输入](scope.md) · [正式运行入口](run-windowed.py)

首次以隐藏窗口启动时，180 秒内 13 页已就绪，4 个成员已绑定，但没有相机 GI 诊断或场景发布，长时计时未开始。保留失败后，针对窗口状态改用同一 EXE 的可绘制窗口，启动时不请求焦点。两次使用相同预热上限及就绪条件。[首次现场](hidden-warmup.jsonl) · [首次退出](player-exit.json) · [正式启动记录](windowed-attempt.json)

## Editor 退出 Play 后的原生对象

另在本机 Unity 6000.0.85f1 的 DX12 Editor 打开同一保存场景。用 Memory Profiler 的 `NativeObjects` 在进入 Play 前、正常退出 Play 回到同一 Edit 场景后各取一次快照。Play 内使用 960×540 的相机渲染请求，两次均在第 33 帧取得完整 DXR 近场、13 页、18 个引用、3 个可见和 4 个绑定成员。使用默认域和场景重载，未主动清理未使用资源或调用产品 Dispose。两端快照都写完后才读取具名对象及其持久标记。[采集入口](EditorMemoryPair.cs)

| 同一 Edit 场景内的非持久对象 | 原 Release101 源码，进入前 → 退出后 | 修复后，进入前 → 退出后 |
| --- | --- | --- |
| HLGI 具名对象 | 8 → 14 | 8 → 8 |
| 其中两个退休宿主及其 Transform 和 MonoBehaviour | 0 → 6，共 2,688 B | 0 → 0 |

两个宿主为 `HybridLumenGI Resource Retirement` 和 `HybridLumenGI Asset Page Retirement`。它们通过 `DontDestroyOnLoad` 在 Play 中跨场景提供回收服务。修复让 Editor 中的宿主继续隐藏，随 Play 场景生命周期释放。若禁用域重载且有旧分页所有者，下一次进入 Play 会为其恢复轮询；该模式尚未实测。[原始对象表](editor-baseline-objects.json) · [修复后的对象表](editor-fixed-objects.json)

修复后的退出日志最终记录 generic `owned/pending/unknown/failed` 均为 0，材质、纹理池和形变的退休计账也归零。两次快照对均在退出后观察到额外加载的持久 ComputeShader 资产；原有持久 Shader 的记录大小也有变化。此结论限于有名原生对象及本次退出账目，未检查托管引用链、无标签分配或驱动内部对象。普通 Windows 演示继续使用 Release101。[本机修复前快照](<I:/Unity test/Comparison/EditorMemoryPair01/>) · [本机修复后快照与就绪账目](<I:/Unity test/Comparison/EditorMemoryPair02/>) · [修复后的 Editor 日志](<I:/Unity test/Logs/EditorMemoryPair02.log>)
