# 形变几何快照

默认活动Skin已有[普通Player有限成本窗口](../LocalComparison/Review/active-skin-cost-01/result.md)：当前Release122同源、原24顶点／12三角／2骨K+Space、SDF32／间隔4，在观察开启的35秒已预热窗口内，GI三区间合计p95为17.088ms、进程local采样峰572.004MiB，满足起始预算；同次应用Present间隔最大27.078ms。205个新快照的实际捕获到首次CPU观测帧龄p95为11帧、最大12帧，不能当作全部渲染帧的快照年龄、BakeMesh耗时或GPU消费延迟。该窗没有截图／动态质量结论，不关闭更大模型、冷启动、形变画质或整体生产验收；下文79等历史使用范围继续保留各自来源。

自 Release107 起，通用退休队列已经排空时，退出流程会在原有共享期限内等待已取消的后台 CPU 烘焙结束，再由主线程销毁未发布的私有网格。超时或销毁失败的对象继续保留所有权。[退出时序与适用范围](../LocalComparison/Review/cancelled-worker-shutdown-01/result.md)

本机 Win64 的统一示例两骨门另有原生上一帧顶点观测。连续渲染的同一三角形上，第 4 帧 previous 与第 3 帧实际 current 的三个顶点逐点相同，独立骨姿态换算的最大差为 1.26 × 10⁻⁷ 米。该观测区分了真实前帧与绑定姿态，颗粒和拖影仍需由实际画面判断。[坐标空间、原始读回和适用范围](../LocalComparison/Review/skinned-previous-vertices-01/result.md)

屏幕历史另有[普通骨骼停稳恢复](GeometryHistoryContracts.md#普通骨骼停稳历史)：满足完整来源与骨姿态稳定条件时，SkinnedMeshRenderer可重新累计历史；真正骨变化继续拒绝旧历史。这与下述异步GI快照各自工作，不承诺跨形变重投影或可见动画与世界GI逐帧同步。有限统一场景使用结果见[Skinned停稳历史](../LocalComparison/Review/skinned-stopped-history-01/result.md)。

给已有 `HybridLumenGIProxy` 的对象添加 `HybridLumenGIDeformedMesh`。SkinnedMeshRenderer 按间隔捕获；可读 MeshFilter 或自定义顶点生产者在主线程调用 `RequestCapture(readableSnapshot)`。后者必须提供完成写入的可读网格，GPU 私有顶点缓冲不会被自动推断。原可见 Renderer 和材质继续保留。

捕获在主线程执行。自动 Skinned 路径调用 `BakeMesh(mesh, useScale: true)` 补偿 Renderer 缩放，后续由完整实例矩阵应用一次。普通可读网格复制 GI 需要的位置、法线、切线、UV0 和原 submesh 索引。后台任务只接触复制后的数组，使用与 Editor 相同的 SDF 数学核及既有 chart 分组核。开放网格继续采用 unsigned shell；闭合网格使用带符号体素。[Unity 6.0 BakeMesh](https://docs.unity.com/en-us/engine/6000.0/script-reference/unityengine/skinnedmeshrenderer/bakemesh)

Mesh、SDF、捕获网格和 charts 全部生成成功后，以同一不可变快照替换。Proxy、Scene、SdfAtlas、SurfaceCache 与软件/DXR 三角准备共同读取该来源；不把更新后的 Skinned 绘制与旧 charts 混用。发布触发几何版本及局部缓存失效。这里的发布是 CPU 表示切换，GPU atlas 上传、材质捕获和 HLOD 初始化仍经过原就绪流程。形变更新有采样间隔与处理延迟，不承诺逐动画帧即时重建。

共用 SDF 烘焙核复用最近距离遍历的子包围盒距离和冻结三角边。闭合网格额外预计算三个原判内方向的交点不变量。默认两骨门固定 15° 的 SDF32 同输入 Unity CPU 对照中，完整烘焙中位由 135.317 ms 降到 99.627 ms，边界一致，全部体素逐位一致。采用范围为 SDF 核成本，完整形变发布和 GPU 消费延迟继续按原条件验收。[固定门姿对照](../LocalComparison/Review/deformed-sdf-bake-289/result.md)

Release231 沿用 Release154 的单三角和两条固定射线，观察到实际 DXR 从初始自动 `BakeMesh` 快照切到改骨后的版本。旧射线变为已知未命中，另一条以当前几何版本命中新姿态。采用限于这个 DX12 Editor 输入。普通 Player 的画质与形变消费延迟继续验收。[新姿态读回](../LocalComparison/Review/skinned-dxr-pose-282/result.md) · [Release154 初始读回](../LocalComparison/Review/native-skinned-hit-175/result.md)

普通 Win64 Player 的固定 15° 两骨门也已观察到新快照进入生产 DXR。捕获处补偿缩放后，24 个已发布顶点与独立骨矩阵参考的最大世界坐标差为 2.98 × 10⁻⁸ m，实际命中的门顶三角由错误的 5.525 m 回到参考的 2.873 m。采用限该门的快照坐标和一次诊断消费，连续运动画质继续验收。[旧版与修正后实机读回](../LocalComparison/Review/ordinary-skin-scale-300/result.md)

`BakeMesh` 快照绑定捕获时的 `SkinnedMeshRenderer.sharedMesh`。帧级渲染准备会撤回已失效的快照并取消旧作业。Release130 也在相机读取世界表示前复核来源，覆盖 `beginContextRendering` 后在 `beginCameraRendering` 替换或清空网格的情况。已提交读者保留旧快照直到退休栅栏完成，取消的后台作业在实际结束后清理。替换网格沿用每帧的捕获和发布预算。显式可读网格继续遵循各自的请求与合并规则。

旧 Renderer 销毁后，Release175 在代理待校验或重新启用时会查找同对象的新 Renderer。两条入口都在 Unity 组件对照中接到新 Skin 已发布的 Mesh、SDF 和图卡，Scene 随后使用新几何的边界。验证直接驱动快照回调和 Scene 准备，实际相机渲染按原条件验收。[自动接源对照](../LocalComparison/Review/replaced-renderer-rebind-201/result.md)

本机 `Validate-DeformedMesh.ps1` 的同输入回归在 Release129 源码复现相机准备时仍读旧 Mesh／SDF／charts，Release130 在同帧替换及清空时均撤回旧来源，既有异步流程可以恢复新来源。测试使用实际组件与模拟 final-context 完成，覆盖旧读者等待及相机检查没有额外捕获或上传。修复已整合普通包，实体 GPU 退休和形变画质仍分别验收。[定向回归](../Tests/StandaloneDeformedMesh/Program.cs.txt) · [同源交付](../LocalComparison/Review/skinned-camera-source-147/delivery.json)

Release132 的自动 `BakeMesh` 还绑定捕获时原 `sharedMesh` 的内容版本。原地编辑后，主线程可调用 `HybridLumenGIMeshSource.NotifyGeometryChanged(skin.sharedMesh)`。相机读取世界表示前会撤回旧版本并取消旧作业，后续捕获和发布继续使用原配额。可选 receiver 来源检查产生的版本通知同样在该相机的世界准备前生效。显式可读 producer 继续以捕获请求为准。`Validate-DeformedMesh.ps1` 同输入 CPU 回归在 Release131 复现旧快照留存，Release132 通过撤回、取消、模拟栅栏等待和新版发布。[实际组件回归](../Tests/StandaloneDeformedMesh/Program.cs.txt) · [同源交付](../LocalComparison/Review/notified-skin-source-149/delivery.json)

形变快照撤回只推进所属 Proxy 的几何和传输修订。两件蒙皮共用作者网格时，停用一件的形变组件会让该件回退并将旧快照交给退休队列，另一件沿用完整快照。真正编辑共享源并发出内容通知后，两个活动实例仍会重新发布。[实际 Unity 对照与范围](../LocalComparison/Review/shared-skin-withdrawal-177/result.md)

组件设置控制分辨率、更新间隔、单对象顶点/三角上限。共享的 `VertexBudgetPerFrame`、`MaximumWorkers`、`MemoryBudgetBytes`、`UploadBudgetBytesPerFrame` 约束捕获、后台任务、逻辑内存预留和发布。失败捕获也消耗本帧顶点额度，并遵守重试间隔；worker 设为零暂停新任务，仍清理已取消任务。捕获按实例轮转，不能让列表开头的对象无限占用机会。

存在单个活动形变来源、两个空闲工作槽且设备有多个逻辑处理器时，可用两个槽计算同一份 SDF 的两段切片。整个后台任务完成前保留两槽和快照预留。两段汇合后才生成图卡并按原规则尝试发布。取消或失败同样等待两段退出。多来源按实例轮转使用单槽，编辑器烘焙按切片顺序报告进度。[实测与槽位对照](../LocalComparison/Review/deformed-bake-slots-298/result.md)

如果首个合格对象能放入完整帧、但因前序捕获用掉顶点额度而延期，下一帧先尝试它。本帧仍可用余量捕获后续小对象。定向组件对照中，三顶点的未变蒙皮计费后，四顶点的变形蒙皮在六顶点额度下延期，后续三顶点对象照常捕获。修复前变形蒙皮下一可用帧仍未捕获，修复后新姿态完整发布。对照使用实际组件和受控 Unity 接口，覆盖调度及 Mesh、SDF 与图卡一起发布。[组件对照](../Tests/StandaloneDeformedMesh/Program.cs.txt)

完成作业按捕获入队顺序尝试发布，避免后来的快照反复抢占上传额度。当前剩余额度不足时继续检查后项，失效完成项仍可清理。运行时降低发布额度后，已完成且超过整帧额度的快照会等待恢复，同时将新捕获工作槽让给其他对象。等待中的快照保留原队列位置、每对象在途约束与内存预留。额度恢复后重新核对来源，再按原顺序发布。内存不足仍会暂停捕获。[定向行为对照](../Tests/StandaloneDeformedMesh/Program.cs.txt)

已经结束但清理失败的作业也释放共享捕获槽。失败快照继续持有其内存预留，所属对象受同一对象的在途约束。其他对象可以在剩余配额内捕获并发布。[单工作槽对照](../LocalComparison/Review/deformed-failed-slot-294/result.md)

可选的共享 `CaptureBudgetMillisecondsPerFrame` 进一步限制同一引擎帧继续开始捕获。默认0；负数或非有限值也关闭。由调用方在主线程按设备需要设置，例如 `HybridLumenGIDeformedMesh.CaptureBudgetMillisecondsPerFrame = 2.0;`，这个示例值不是本项目正式性能预算。关闭时不读取捕获时间戳，原数量／字节准入保持。

开启后，组件累计完整同步捕获尝试经过的时间，包括BakeMesh或可读流复制、索引整理、已捕获内容检查、任务创建，以及失败或未变内容的清理。达到额度后，本帧不再开始下一份捕获；下一对象保留轮次、请求与未消耗额度，下个引擎帧重新按原调度推进。至少一份原本合格的捕获可以开始，因此单次不可抢占的BakeMesh仍可能超额。这里测的是Stopwatch经过时间，包含GC／线程抢占等待，不是CPU核心占用或整帧硬截止。

该门只约束新捕获。来源替换撤回、完成作业的发布／清理及资源退休照常执行；准入扫描、已完成快照的Texture/mesh创建与上传、后台SDF/chart作业和其他渲染准备不计入这项额度。其他顶点、worker、字节和间隔限制仍可能阻止某对象推进，时间门不保证固定延迟或所有任务永不等待。当前统一示例保持默认关闭，没有因此改变形变采样节奏或画质配置。

可选的共享 `PublicationBudgetMillisecondsPerFrame` 独立控制同一引擎帧何时停止启动完整快照发布。默认值为 0。主线程可设置正的有限值，例如 `HybridLumenGIDeformedMesh.PublicationBudgetMillisecondsPerFrame = 2.0;`。原上传字节和来源资格先判定，纹理、捕获网格、SDF 和图卡的一次同步发布完整执行，并累计经过时间。达到额度后，下一份合格快照保留其捕获帧、队列位置和内存预留，下帧重新参与。取消项照常清理。单次发布仍可能用完或超过额度，后台作业和 GPU 完成时间各有自己的边界。[组件对照及适用范围](../LocalComparison/Review/deformed-publication-budget-265/result.md)

自动 Skinned 轮询仍先按上述准入实际执行 BakeMesh；没有显式待处理请求、没有显式可读网格覆盖来源时，使用既有完整内容指纹比较新捕获与当前同 owner 的成功发布快照。只有网格内容/布局、有效 SDF 分辨率及捕获时冻结的 chart 设置都一致，才清理本次私有捕获并复用原快照，省去重复 SDF/charts 重建和发布失效。它不省略必要捕获，也不更新 PublishedFrame 或声称零 CPU 成本。失败或在途候选不作复用依据；显式强替换与合并请求仍正常处理。私有捕获清理失败沿用失败 Job 的所有权/预留保留政策，使用已完成的空结果任务占位，不是活跃 worker；不会自动重试销毁或归还未清理资源的预留。

新请求递增代次并取消旧任务；任务实际完成前保留其预留，完成结果只有代次和来源仍一致才可发布。旧快照先从未来读者移除，再交由 `HybridLumenGIResourceRetirement`，等待所有相机结束后的 GPU fence 完成才销毁及归还预留。没有可靠 fence 时保留资源，不能用经过若干帧代替完成证据。

上述强替换语义属于原 `RequestCapture()`，继续保留。持续显式生产者可选择 `RequestCoalescedCapture(readableSnapshot)`：让已捕获的有效快照继续完成，同时只保留一个最新待捕获来源引用。中间请求可以被合并；当前快照经过原上传与完整发布流程后，再按原间隔、worker、顶点和内存预算捕获最新来源。旧强替换接口、disable、shutdown及Renderer来源替换仍可撤销在途资格。现有调用者不会自动切换到新模式。

两种接口都在实际主线程捕获时复制数据，调用返回不等于复制完成。输入Mesh是借用引用，生产者应保证捕获边界的数据完整；组件不取得该输入的销毁所有权。后续请求不会修改已复制给worker的快照。合并模式允许较早捕获但内部一致的快照发布，不承诺与当前可见动画逐帧同步；`PublishedFrame`仍表示捕获帧。预算不足或失败仍可能阻止推进。iteration43的实际组件/任务屏障检查覆盖持续请求下发布、停止后最终追上及原取消/预算/退休守卫；它没有新增Unity或GPU运行，也不是动画画质或BakeMesh耗时验收。

在 `SkinnedMeshRenderer` 上提交显式可读网格时，组件按请求捕获，完成后沿用已发布的快照等待新请求。主线程复制完成后，生产者可以释放借用输入。Unity 对已释放对象的判空与托管引用判空有区别，显式传入 `null` 才清除该覆盖并恢复自动 `BakeMesh`。实际组件 CPU 回归覆盖显式强请求、合并请求、模拟输入释放和主动清除后的恢复，证据范围为捕获与发布状态。[Unity 对象判空](https://docs.unity.com/en-us/engine/6000.0/script-reference/unityengine/object/op-equality) · [定向回归](../Tests/StandaloneDeformedMesh/Program.cs.txt)

字节额度包含实际来源 vertex strides、生成网格/体素及估算的 chart/BVH 工作存储；它不是 Unity/驱动分配器峰值上界。大于单帧发布额度的对象会给出明确状态，需要调高配置或拆分资产，不能宣称已更新。CPU BakeMesh 的成本、生成延迟、长时内存和动态画质需在本机 Player 中测量。

69把合并请求接入了[普通可启停示例](ContinuousDeformationExample.md)。一次真实DX12运行完成256帧，运动期间11次内容不同的发布、停稳最终完整来源一致及两张可判读HDR图像；首个构建准备失败和唯一修正均保留，见[结果](ReviewBrief-ContinuousDeformationUsage01.md)。这补上单个可读生产者的原生使用证据，不补齐Skinned、逐射线GPU消费或完整动态画质。

当前统一样例另外接通了真实两骨骼 Skinned 来源，同时保留原可读 Mesh 模式：`K` 切换来源，`Space` 共用启停。切换先撤回旧快照，再清除显式网格覆盖并让既有自动 `BakeMesh` 路径捕获；退出恢复作者 Renderer/mesh，临时资源沿既有退休流程释放。这是使用入口集成，没有重做形变算法。一次有限 Unity 渲染序列完成141次请求、运动中相邻发布网格出现8次顶点变化；停稳姿态为15.161499°，发布网格与真实 BakeMesh 的最大顶点差为0，Skin/Mesh 两种来源都达到 Feature 的 `Published`，旧 Skin 快照撤回与作者 mesh 恢复均成立。首个启动尝试零渲染失败及临时驱动修正保留，详见[统一样例使用结果](../LocalComparison/Review/skinned-unified-usage-01/result.md)。当前仅这一 Unity 使用范围通过，已构建并整合Release79，普通Player未另行启动；它不新增颜色、残留、无拖影或光照收敛结论，也不证明逐射线 GPU 消费或性能。

`Tests/Validate-DeformedMesh.ps1` 执行实际组件与退休协调器源码，使用明确的 Unity/任务结果适配器验证发布、取消、预算、失败及退休状态。SDF/chart 数学各用既有专项验证。它们没有执行 Unity 的 BakeMesh、RenderGraph、真实 GPU fence 或实体显卡。
