# GPU 时间反馈与更新预算

当前实现是有静态上限的实验反馈控制器，不是 GPU 硬截止时间保证。没有在 Unity、实体显卡或 Release Player 上运行。离线控制器/托管桥测试验证各自来源快照的状态机；原生 DLL 另有模拟 Unity 宿主下的 D3D12 WARP 软件适配器测试。这些证据不产生本项目在 Unity 中的 GI 性能数据。当前候选的统一验证状态与报告以 [OfflineValidation.md](OfflineValidation.md) 为入口，不由下述历史结果推定。

## 启用与测量范围

`measureGpuCost` 是默认关闭的独立观测开关。计时可在 `targetGpuMilliseconds=0` 时运行；只有原 `adaptiveGpuBudget` 加有效正数目标才启用反馈。只观测时 Scale 为 1，三项更新配额保持配置上限。关闭反馈的控制器仍沿用既有拒绝观测计数，该计数不表示原生样本无效。严格源帧统计使用原生桥的完整验证记录及独立失败计数，不能重复采集 `LastMilliseconds` 或用 Recorder 猜测源帧。参见 [原生完成记录契约](NativeGpuTiming.md)。

独立静态准入已接入当前渲染路径：

| 设置 | 默认值与行为 |
| --- | --- |
| `materialTextureUploadMiBPerFrame` | 16 MiB，全相机共享实际复制字节；稳定大页跨帧续传，完整复制/回读后ready；不能拼接不同帧的动态RT。 |
| `hardwareMaterialBudgetMiB` | 256 MiB，材质arena包含当前、待上传、读者持有及退休/隔离分配；复用稳定页，局部替换变化页。 |
| `softwareGeometryBudgetMiB` | 128 MiB，每相机精确软件属性、BVH与等待fence的旧缓冲共同计账；新分配前准入，不足则回退/等待退休。 |
| `hardwareGeometryBudgetMiB` | 128 MiB，每相机硬件精确属性，包含当前与退休分配及替换峰值；不与RTAS预留混为一项。 |
| `rtasMemoryBudgetMiB` | 256 MiB，跨相机RTAS预留；按64 KiB + 192 B/triangle + 1024 B/instance估算，后续 `GetSize` 观测只提高高水位；退休仍计账。估算不是驱动上界。 |
| `rtasBuildsPerFrame` | 每引擎帧最多4次实际构建；仅准备不扣构建额度，未变场景不重复扣费。 |
| `rtasTriangleWorkPerFrame` / `rtasInstanceWorkPerFrame` | 250,000三角 / 4,096实例；包含完整dirty构建/refit工作。等待任务积累tokens，最老活跃任务优先。 |
| `rtasTriangleBurstCapacity` / `rtasInstanceBurstCapacity` | 1,000,000三角 / 16,384实例；过大任务明确回退；暂不被相机使用的任务只退出优先队列，不据年龄销毁GPU资源。 |

资源页组件另设IO/并发/上传准入/驻留额度，形变组件另设CPU捕获/后台作业/快照上传额度，见对应说明。诊断中的全局纹理/RTAS计数可能在多个相机记录中重复出现，不应相加。实际分配粒度、驱动scratch与系统峰值必须在朋友设备测量；静态数量配额与下方滞后时间反馈相互补充。

启用反馈且 `preferNativeGpuTiming=true` 时，优先使用可选的 [原生 DX12 时间戳后端](NativeGpuTiming.md)：它返回提交身份并按实际 fence 完成读取和回收。源码包不自动安装 DLL；未安装/不支持/不可用时回退下面描述的 Recorder 路径。原生固定池有 128 个跨相机共享的可循环提交槽，不受 Recorder 的 32 个生命周期通道限制；原生插件仍未经过 Unity/实体 GPU 验收。

`adaptiveGpuBudget` 默认关闭，`targetGpuMilliseconds` 默认零；关闭时不探测或加载原生计时 DLL。朋友应先在目标设备记录基线，再设置正数目标并启用，各相机维护独立反馈状态。零目标、尚无有效样本或两个提供器均不可用时保留静态更新上限；已进入反馈后的短暂缺测保留最后配额，距最后有效观测达到 16 个引擎帧后恢复静态上限。原生 ring 暂满不改变其可用状态，也不为该帧切换到 Recorder。

两个提供器都覆盖接收材质捕获、可选身份四个pass、世界更新/追踪/降噪及最终合成。原生ABI1仍使用三个区间：第一个从材质捕获开始，到身份解析结束；关闭身份时仍在材质捕获末尾结束。其余两个区间为transport和composite，硬件`RecordBuild`在transport内。Recorder采用每pass局部配对的`CustomSampler`：身份关闭时三个，开启时七个，不让Begin/End跨越RenderGraph pass。替换原生漫反射的额外目标仍在材质捕获pass中。

激活范围的GPU时间之和是反馈信号。它不包含CPU准备、范围外立即上传、范围外目标设置/清除、末尾原生resolve pass和整个RenderGraph的附加开销，也不是应用总GPU帧时间。原生第一段是完整捕获链的队列区间，可能包含阶段间屏障、等待或穿插工作；Recorder则累加各pass局部区间，两者不能当作完全相同的隔离shader成本。提供器切换会重置反馈。驱动分配、跨队列重叠及BLAS/TLAS峰值内存仍需外部profiler，不使用CPU录制耗时或整帧FrameTimingManager值替代这些观测。

integration-12归档没有测量身份四个pass；历史integration-13补接了这部分命令范围，当时封存源码通过56阶段统一离线回归，不能作为当前工作区的通过结论，实际Unity计时仍待验收。Clear显式读取captureDepth建立材质捕获→身份清零依赖；Candidates与identity输出建立后续顺序。完整建图后才启用身份计时，部分建图、晚回调、乱序或缺阶段会撤销反馈。实际身份功能因预算或能力变化而开关时，即使Settings和尺寸相同，也会重置计时代次及控制器。计时API异常只撤销反馈，不中断GI命令；真实GI命令异常仍按渲染失败处理。

## 原生提交归属与回收

每次预留返回不复用的正数 63 位 ID，绑定 owner、配置代次、设备代次和源帧；plugin event 的 `IntPtr` 只编码该 ID，不指向托管或临时 payload。完整六个 timestamp 之后，合成的依赖链末尾追加独立 Unsafe resolve pass，避免在 D3D12 native render pass 内调用 `ResolveQueryData`。原生端等实际 fence 完成才发布结果或回收已使用的 query 槽；取消不会提前释放 GPU 仍引用的槽。

托管端每相机最多保留 32 个 ticket，只接纳身份、频率、时间戳顺序与年龄均有效的最新结果；超过 32 个引擎帧的结果会被取消，已消费结果不能再参与反馈。提供器或原生设备代次变化会重置控制器，ring 暂满则只是缺测。原生池逻辑 readback 为 6,144 字节，另有 768 项 query heap、驱动开销与有界的异常退休资源；具体 ABI、构建、安装和失败路径见 [NativeGpuTiming.md](NativeGpuTiming.md)。

## Recorder 回退的可用性与证据边界

Unity 的 [Recorder 文档](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Profiling.Recorder.html)说明 GPU 数据存在三帧延迟。实现先检查 [supportsGpuRecorder](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/SystemInfo-supportsGpuRecorder.html)，再要求有效 sampler/recorder、每个范围恰好一个正时长 GPU block；GPU count 为零、负时长或重复 block 都不作为零成本。

不同相机使用独立标记。只有同代次连续八个已完整录制的帧之后才读取延迟观测；每引擎帧最多读取一次。跳帧、重复渲染、未闭合范围、配置/尺寸/实际后端变化和生命周期失效会清空关联历史。每个 pass 持有相同的帧 token，旧 token 不能发布新历史；失效后仍会关闭已经打开的 marker。这里的“完整”是 CPU 录制完整，不是 GPU 完成证明。

公开 Recorder 接口没有 query ID，也不提供多个范围的原子快照。`frame - 3` 只是按文档建立的预期关联，不能证明这些值来自同一次硬件提交；重复出现的相同时长也不能据此判为新样本或旧样本。因此该路径仅用于受硬上限约束的滞后调节，不能据它声称严格时间归属、满足预算或 GPU fence 已完成。

Unity 文档中的 Player 限制与当前托管源码的 availability 标志不完全一致。固定版本源码 `1c2d7db69c060103b6dc087af725442d1efaef9c` 中的 CustomSampler/Recorder 和固定 URP Graphics `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53` 已作为接口研究依据；实际 native 行为仍须实机核验。本实现直接调用 CommandBuffer/RasterCommandBuffer 的 CustomSampler 重载，避免依赖在非 Development Player 中被剔除的 ProfilingScope。不能据托管源码承诺所有 Release Player 都能取得数据。

Sampler没有公开销毁接口。Recorder最多使用32个生命周期通道，每通道最多七个固定名称，共224个；只创建和启用当前必需的范围，可选marker创建失败不阻断随后关闭身份的基础模式。通道不在无完成凭据时复用；耗尽报告`ChannelLimitReached`并回到静态预算，不停止GI。原生timestamp后端提供独立可回收query池，未改变Recorder的限制，也未完成Unity长期运行验收。

`BeginSample`或`EndSample`命令抛出异常时，无法证明native marker是否已录制或闭合。`RejectCommandRecording()`会锁存`CommandRecordingFailure`，永久停用该实例通道的反馈；普通Invalidate、切换范围或关闭重开均不恢复它，也不回收该通道。已开始marker的同pass finally仍清理CPU配对。普通旧回调不影响新帧；若旧marker的实际结束命令失败，则同一通道仍须停用，但不借旧帧回调重置新帧控制器。GI继续使用静态工作上限。

## 控制规则

控制器只改变以下每帧工作量，并保留用户配置的绝对上限：

| 配额 | 最低更新量 | 保持不变的相关资源 |
| --- | --- | --- |
| cache patches | `max(1, ceil(configured × minimumGpuWorkFraction))` | patch 网格、缓存容量、每 patch 射线数 |
| surface captures | 同上 | 卡池、tile 分辨率和原子绘制上限 |
| global SDF bricks | 启用时同上；关闭时零 | clipmap 层数、尺寸和体素精度 |

最低比例默认 0.125，允许范围 0.01–1。控制使用权重 0.2 的指数平滑与 ±10% 死区，至少八个有效观测后开始调整，每次调整至少间隔 16 帧。连续比例每次最多下降 25% 或上升 10%；整数配额向上取整，因此小配额可能一次改变一个工作项。配置变化或显式 reset 会清空平滑值并恢复静态配额。

原生结果额外携带真实预留提交的 source frame：控制器拒绝重复、倒退、未来、配置代次之前和最后一次配额调整之前的测量，避免旧工作量的迟到结果驱动新工作量继续降额。Recorder 没有这种来源证明，传入未知标志而不是伪造 `frame - 3` 为真实身份；仍依靠保守冷却和硬配额上限。

表面 draw 上限不随比例下降：真实 chart 通常需要两次 draw，六面 fallback 的单卡需要子网格数加一，随意缩减该上限会让整个复杂对象永久无法捕获。最低正数更新配额保留已有最旧项调度的机会，但不保证所有对象都能装进既有静态容量或绘制上限。

不改 `Settings`，不随反馈推进 lighting epoch，也不降低 cache/gather rays 或 filter iterations。即使工作量下降，全池缓存复制/失效、Global SDF 无效页上传及发光提议清表仍执行。配置、真实后端切换等失效若发生于 CPU 准备之后，不重跑准备：保留本帧已排的有界工作，撤销其计时并在下一帧恢复静态配额。

## 诊断与验收

`Log Runtime Diagnostics` 额外输出状态、最新观测是否有效、历史毫秒值及其消费帧、平滑值、工作比例、三个有效配额和计数。`gpuTimingProvider` 区分 `NativeDX12` 与 `Recorder`；原生路径还提供 `nativeGpuTimingStatus`、`nativeGpuPendingSubmissions` 和 `nativeGpuMeasuredSourceFrame`。`gpuLastObservationConsumedFrame` 是 CPU 读取该观测的引擎帧，不是硬件 query 的来源帧；`gpuLastObservedMilliseconds` 可能保留失效之前的历史值，应同时查看有效标志和状态。原生 source frame 来自身份校验后的结果，Recorder 没有同等来源证明。

达到最低工作量并经过最后调整后的十一帧等待窗口，仍连续三个有效观测的平滑值高于死区时，`gpuMinimumWorkOverBudget` 标记持续压力。若初始整数配额已经等于最低值，则无需等待一次不存在的调整。该标志不要求三个原始时长都超标，不证明预算永远不可达，也不承诺已经控制住固定成本。不得通过跳过失效维护或伪报时长来消除该标记。

朋友端需要分别在 Editor、Development Player、Release Player 对照独立 GPU profiler，验证原生提交/fence 生命周期，以及回退 Recorder 的 capability 和 marker block 数。测试 native render pass 开/关、静态/动态负载、极小目标、两个相机、长期相机创建销毁、停用恢复、同帧重复相机、配置/后端切换、原生设备重建、ring 饱和、缺测和 Recorder 生命周期通道耗尽。记录配额变化、实际 GPU p95/p99、画面收敛和捕获积压。源码/录制测试和 WARP 软件适配器检查不能替代这些验收，也尚未关闭 ProductionPlan 的 GPU 预算关卡。
