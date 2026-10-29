# 形变几何快照

给已有 `HybridLumenGIProxy` 的对象添加 `HybridLumenGIDeformedMesh`。SkinnedMeshRenderer 按间隔捕获；可读 MeshFilter 或自定义顶点生产者在主线程调用 `RequestCapture(readableSnapshot)`。后者必须提供完成写入的可读网格，GPU 私有顶点缓冲不会被自动推断。原可见 Renderer 和材质继续保留。

捕获在主线程执行。Skinned 路径调用 `BakeMesh(mesh, false)`，保留局部坐标，实例变换只应用一次；普通可读网格复制 GI 需要的位置、法线、切线、UV0 和原 submesh 索引。后台任务只接触复制后的数组，使用与 Editor 相同的 SDF 数学核及既有 chart 分组核。开放网格继续采用 unsigned shell；闭合网格使用带符号体素。

Mesh、SDF、捕获网格和 charts 全部生成成功后，以同一不可变快照替换。Proxy、Scene、SdfAtlas、SurfaceCache 与软件/DXR 三角准备共同读取该来源；不把更新后的 Skinned 绘制与旧 charts 混用。发布触发几何版本及局部缓存失效。这里的发布是 CPU 表示切换，GPU atlas 上传、材质捕获和 HLOD 初始化仍经过原就绪流程。形变更新有采样间隔与处理延迟，不承诺逐动画帧即时重建。

组件设置控制分辨率、更新间隔、单对象顶点/三角上限。共享的 `VertexBudgetPerFrame`、`MaximumWorkers`、`MemoryBudgetBytes`、`UploadBudgetBytesPerFrame` 约束捕获、后台任务、逻辑内存预留和发布。失败捕获也消耗本帧顶点额度，并遵守重试间隔；worker 设为零暂停新任务，仍清理已取消任务。队列按实例轮转，不能让列表开头的对象无限占用机会。

自动 Skinned 轮询仍先按上述准入实际执行 BakeMesh；没有显式待处理请求、没有显式可读网格覆盖来源时，使用既有完整内容指纹比较新捕获与当前同 owner 的成功发布快照。只有网格内容/布局、有效 SDF 分辨率及捕获时冻结的 chart 设置都一致，才清理本次私有捕获并复用原快照，省去重复 SDF/charts 重建和发布失效。它不省略必要捕获，也不更新 PublishedFrame 或声称零 CPU 成本。失败或在途候选不作复用依据；显式强替换与合并请求仍正常处理。私有捕获清理失败沿用失败 Job 的所有权/预留保留政策，使用已完成的空结果任务占位，不是活跃 worker；不会自动重试销毁或归还未清理资源的预留。

新请求递增代次并取消旧任务；任务实际完成前保留其预留，完成结果只有代次和来源仍一致才可发布。旧快照先从未来读者移除，再交由 `HybridLumenGIResourceRetirement`，等待所有相机结束后的 GPU fence 完成才销毁及归还预留。没有可靠 fence 时保留资源，不能用经过若干帧代替完成证据。

上述强替换语义属于原 `RequestCapture()`，继续保留。持续显式生产者可选择 `RequestCoalescedCapture(readableSnapshot)`：让已捕获的有效快照继续完成，同时只保留一个最新待捕获来源引用。中间请求可以被合并；当前快照经过原上传与完整发布流程后，再按原间隔、worker、顶点和内存预算捕获最新来源。旧强替换接口、disable、shutdown及Renderer来源替换仍可撤销在途资格。现有调用者不会自动切换到新模式。

两种接口都在实际主线程捕获时复制数据，调用返回不等于复制完成。输入Mesh是借用引用，生产者应保证捕获边界的数据完整；组件不取得该输入的销毁所有权。后续请求不会修改已复制给worker的快照。合并模式允许较早捕获但内部一致的快照发布，不承诺与当前可见动画逐帧同步；`PublishedFrame`仍表示捕获帧。预算不足或失败仍可能阻止推进。iteration43的实际组件/任务屏障检查覆盖持续请求下发布、停止后最终追上及原取消/预算/退休守卫；它没有新增Unity或GPU运行，也不是动画画质或BakeMesh耗时验收。

字节额度包含实际来源 vertex strides、生成网格/体素及估算的 chart/BVH 工作存储；它不是 Unity/驱动分配器峰值上界。大于单帧发布额度的对象会给出明确状态，需要调高配置或拆分资产，不能宣称已更新。CPU BakeMesh 的成本、生成延迟、长时内存和动态画质需在本机 Player 中测量。

69把合并请求接入了[普通可启停示例](ContinuousDeformationExample.md)。一次真实DX12运行完成256帧，运动期间11次内容不同的发布、停稳最终完整来源一致及两张可判读HDR图像；首个构建准备失败和唯一修正均保留，见[结果](ReviewBrief-ContinuousDeformationUsage01.md)。这补上单个可读生产者的原生使用证据，不补齐Skinned、逐射线GPU消费或完整动态画质。

当前统一样例另外接通了真实两骨骼 Skinned 来源，同时保留原可读 Mesh 模式：`K` 切换来源，`Space` 共用启停。切换先撤回旧快照，再清除显式网格覆盖并让既有自动 `BakeMesh` 路径捕获；退出恢复作者 Renderer/mesh，临时资源沿既有退休流程释放。这是使用入口集成，没有重做形变算法。一次有限 Unity 渲染序列完成141次请求、运动中相邻发布网格出现8次顶点变化；停稳姿态为15.161499°，发布网格与真实 BakeMesh 的最大顶点差为0，Skin/Mesh 两种来源都达到 Feature 的 `Published`，旧 Skin 快照撤回与作者 mesh 恢复均成立。首个启动尝试零渲染失败及临时驱动修正保留，详见[统一样例使用结果](../LocalComparison/Review/skinned-unified-usage-01/result.md)。当前仅这一 Unity 使用范围通过，已构建并整合Release79，普通Player未另行启动；它不新增颜色、残留、无拖影或光照收敛结论，也不证明逐射线 GPU 消费或性能。

`Tests/Validate-DeformedMesh.ps1` 执行实际组件与退休协调器源码，使用明确的 Unity/任务结果适配器验证发布、取消、预算、失败及退休状态。SDF/chart 数学各用既有专项验证。它们没有执行 Unity 的 BakeMesh、RenderGraph、真实 GPU fence 或实体显卡。
