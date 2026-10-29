# 可选 DX12 原生计时后端

当前同一可选 DLL 另提供独立的 `HLGI_Memory_Query`，供统一示例的进程显存观察使用。它不调用计时池、提交GPU命令或修改显存预留；旧计时ABI保持1，新内存结构有独立的ABI1/56字节布局。旧DLL仍可用于原计时，新显存入口缺失会明确显示Unavailable。用法、字段与实际Release77接通结果见[驱动层进程显存观察](GpuBudget.md#驱动层进程显存观察)。

本后端给 GPU 时间观测提供提交编号、设备代次和 fence 完成条件，供独立测量或更新预算控制器使用。它不替换软件 SDF 或 DXR 追踪实现，也不改变光照方程。已有 MSVC、CPU 状态机和 WARP 来源证据；e1aa6356 新增一次 Unity/RenderGraph、RTX2080Ti Development DX12 Player 的固定512源帧成本测量，全部有效完成且正常退出，见[实际结果](../LocalComparison/Review/gpu-cost-baseline-01/result.md)，Pro22已接受有限证据。该有限证据不覆盖Release、多相机、长时、异常退出或真实设备丢失。

## 安装与选择

源码位于 `Runtime/Native~/GpuTiming`，Unity 忽略带 `~` 的目录。源码集成包本身不自动安装 DLL。提供的可选 Windows x64 原生候选包包含 DLL、原生构建/测试报告和来源清单；这是供朋友集成验证的二进制候选，不是生产签核。

在本机测试工程中将 `HybridLumenGIGpuTiming.dll` 放到 `Assets/Plugins/x86_64`，在 Plugin Inspector 中只启用 Windows Editor/x86_64 和 Windows x86_64 Player，关闭 Any Platform，并明确关闭 Linux64、OSXUniversal 和 Win32；只关闭 Any Platform 不会清除已有平台勾选。不要同时安装多个同名 DLL。Unity 原生插件替换后应按 Editor 提示重启，不使用手动 FreeLibrary 热卸载。

Renderer Feature 的 `adaptiveGpuBudget` 和 `measureGpuCost` 默认关闭，`targetGpuMilliseconds` 默认零。两种用途都关闭时，计时桥不探测或加载 DLL，也不分配完成记录导出缓冲；统一示例的显存观察开关独立，开启时可调用同一DLL的内存入口。反馈启用仍要求 adaptive 开关和有效正数目标；`measureGpuCost=true` 可在目标为零、反馈关闭时单独观测，保持原静态配额。`preferNativeGpuTiming=true` 优先选取安装且就绪的原生后端；DLL 缺失、ABI 不匹配或不支持时回退 Recorder。两者都无有效数据则使用静态预算。原生 ring 暂满仅表示该帧缺测，不触发后端来回切换。

只测量开关同时开启每 owner 最多 32 条只读完成记录。`TryDequeueCompleted` 不增加原生轮询；记录通过既有完整校验后保留原提交身份、源帧、读取帧、频率和六个 ticks。反馈仍只取最新结果，迟到但有效的完成项仍可导出。`CompletedResults = ExportedResults + UnexportedResults + BufferedCompletedRecords`（计数未饱和时）；缓冲满丢弃新导出项，停用/失效/销毁清除未读项，均计入 Unexported。InvalidCompleted 单独记录无效结果，Cancelled/TimedOut 记录取消及超时（超时也是取消）。RejectedResults 包含仅被反馈拒绝的旧结果，不能直接当成坏时间戳数量。导出失败不改变 GI 命令或配额。

诊断中的 `gpuTimingProvider` 为 `NativeDX12` 或 `Recorder`；同时检查 `nativeGpuTimingStatus`、`nativeGpuPendingSubmissions`、`nativeGpuMeasuredSourceFrame` 和有效观测标志。Native 的 source frame 来自完整匹配的提交结果；Recorder 的预期 frame 仍只是延迟启发式。后端或原生设备代次切换会清空控制器历史，旧配额测量不能驱动新配额再次调整。

## 数据与资源寿命

每个相机帧预留一个正数 63 位提交 ID，绑定 owner、配置代次、设备代次和引擎帧。ID 单调递增，取消或重置也不复用；空间耗尽时拒绝新测量。插件 event 的 `IntPtr` 只是这个整数 ID，原生端仅查表，绝不解引用为 payload 指针，因此没有临时托管地址或被复用结构体的悬空引用。

原生固定池有 128 个在途提交，每项六个 timestamp：接收材质捕获、传输/降噪、合成各自的开始与结束。逻辑 readback 大小是 `128 × 6 × 8 = 6,144` 字节，另有 768 项 query heap、分配粒度和驱动开销；这不是实测总显存。每个 managed owner 最多跟踪32个提交，结果超过32个引擎帧会被取消。

integration-13保留ABI1和六个时间戳，将ReceiverCapture的结束事件延迟到可选身份解析之后，覆盖身份清零/上传、未知覆盖遮罩、光栅候选捕获及解析四个pass；身份关闭时在材质捕获末结束。对应的显式资源依赖约束命令顺序，部分构图或未闭合阶段使整帧反馈无效。integration-12归档仍是旧范围；56阶段统一离线通过仅属于历史integration-13的封存源码，不代表当前工作区。实际Unity的依赖执行、原生回调与设备计时仍待验收。此区间可能包含阶段间等待，仍不包含范围外上传或全部GI附加成本。

查询只追加到 Unity 当前 graphics command list，使用该 graphics queue 的 timestamp frequency；不自行 Reset/Close/Execute Unity 列表，不更改渲染绑定。六个时间戳都记录成功后，才在合成之后有显式依赖的独立 Unsafe RenderGraph pass 中 resolve。D3D12 禁止在原生 render pass 内调用 ResolveQueryData，所以它不放在 Raster 回调中。

每次 timestamp 和 resolve 记录前后都取得 Unity frame fence 的值，并验证同一 fence 对象。CPU 取消会拒绝后续旧 ID，但已写入 GPU 命令的 query 槽仍等 fence 完成才回收。解析结果也必须等该 fence 完成，随后验证身份、频率和六个 ticks 的顺序；读取一次即消费，不按“隔了几帧”猜测可复用性。`GetCompletedValue == UINT64_MAX` 作为设备丢失处理，不当成正常完成。

如果追加命令后拿不到合法完成凭据，则隔离整个设备池并停用该计时路径。最多保留四个未证明已退休的设备池，达到上限停止分配；正常已完成的旧池会释放。没有完成证据的关闭路径保留有界资源到进程退出，不在 DLL 静态析构时冒险释放。该异常路径和真实 Unity 关闭/重建顺序仍须实机验证；不支持手动热卸载或多个原生插件副本。

## 构建与复现

需要已有 Windows x64、Visual Studio 2022 C++ Build Tools、Windows SDK 和 CMake。脚本不会安装软件、修改永久 PATH 或把 DLL 自动复制进 Unity 工程。构建默认使用唯一 TEMP 目录。

```powershell
# 首次下载固定官方接口头到 TEMP；无需本机安装 Unity。
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-NativeGpuTiming.ps1 -DownloadUnityHeaders

# 缓存就绪后离线重跑；编译 DLL/测试并运行 CPU 与 WARP 检查。
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Validate-NativeGpuTiming.ps1

# 也可仅构建，并显式提供朋友安装中的 PluginAPI 目录。
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/Build-NativeGpuTiming.ps1 -UnityPluginApiDirectory "Unity Editor 的 PluginAPI 目录"
```

统一候选验收使用固定接口头及哈希；自选本地头会记录实际来源，不能冒充同一固定版本验证。完整 suite 的 `-DownloadIncludes` 同时允许取得 shader includes 和固定 native headers。原生构建报告保存工具版本、头/源码/脚本哈希、二进制哈希、退出码和 WARP 输出。WARP 不可用返回明确失败/不可用状态，不算通过。

接口取自 Unity 官方 NativeRenderingPlugin commit `522254181faf188efa8b50c3e3bf6fce720b26e4`。三个接口头自身标注 **Unity Companion License**；仓库根 MIT 许可不能替代这些文件的许可。头和原始声明仅在外部构建缓存中保存，未重新分发进源码包。此包的状态机和插件实现为本项目代码，没有复制示例的 `completedFence + 3` 释放启发式。

独立 DLL 候选随附[第三方声明](NativeGpuTimingThirdPartyNotices.md)与[完整 Unity Companion License](Licenses/Unity-Companion-License.txt)。打包脚本 `Tests/PackageNativeGpuTiming.ps1` 要求当前通过报告、源码包内实际报告及测试 DLL 的哈希一致；`NATIVE-MANIFEST.json` 记录对应源码归档的名称与哈希，不能把不同候选的 DLL 和源码混用。

## 已有证据与未关闭关卡

- 实际 C++17 QueryPool 在 MSVC `/W4 /WX` 下编译执行，包含百万次槽位复用、取消、乱序、旧 token、设备代次及整数耗尽测试。
- 实际 DLL 在真实 D3D12 WARP 软件适配器上执行，使用模拟的单线程 Unity v7 宿主。测试覆盖提交前拒读、完整回读、取消后 fence 退休、缺失 query、迟到事件和复用；重置测试复用同一真实 device，不能称为实际设备丢失。
- 故障注入让一个 callback 追加查询后的 fence 值返回零，确认立即停用、旧查询引用仍能执行、隔离容量有界。它验证的是模拟宿主违反契约时的行为。
- 本机 D3D12 debug layer 不可用，未安装。新增的单相机 Development Player/实体 GPU 成本基线见上文；没有多配置 native-render-pass 合并、多相机并行、真实 device removal、Release 或长时性能验收。

朋友必须在原生 render pass 开启/关闭、Editor/Development/Release、两个相机、长期创建销毁相机、后端切换、GPU backlog 和设备重建条件下检查结果。对照独立 profiler 测量三个范围及范围外开销，记录 GPU p95/p99、峰值显存、图像收敛。范围内时间戳是队列区间，包含争用或等待，不代表隔离的 shader 纯成本，也不构成硬 GPU 截止时间保证。

主要接口依据：[Unity DX12 Plugin API](https://github.com/Unity-Technologies/NativeRenderingPlugin/blob/522254181faf188efa8b50c3e3bf6fce720b26e4/PluginSource/source/Unity/IUnityGraphicsD3D12.h)、[Unity event ID API](https://github.com/Unity-Technologies/NativeRenderingPlugin/blob/522254181faf188efa8b50c3e3bf6fce720b26e4/PluginSource/source/Unity/IUnityGraphics.h)、[固定 Core 17.0.4 RasterCommandBuffer](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.core/Runtime/CommandBuffers/RasterCommandBuffer.cs)、[D3D12 render pass 限制](https://learn.microsoft.com/en-us/windows/win32/direct3d12/direct3d-12-render-passes)、[ResolveQueryData](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/nf-d3d12-id3d12graphicscommandlist-resolvequerydata)、[fence 设备丢失语义](https://learn.microsoft.com/en-us/windows/win32/api/d3d12/nf-d3d12-id3d12fence-getcompletedvalue)。
