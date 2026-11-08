# 分页准入优先级延续到实际启动

沿用现有 CPU 宿主，执行实际 `HybridLumenGIAssetPageStreamer` 和 `HybridLumenGIAssetPageStreaming`。Provider 控制 I/O 完成顺序。两版共用同一输入。

一个页以优先级 0 持续请求。另一个页以优先级 1 反复请求，启动包读取后撤回，释放完成后再请求。每步只允许一次操作启动和一个在飞操作，两个组都能通过总容量准入。Release138 在 65 个调度步内始终没有给持续请求页启动读取。修复后它在第 61 步取得读取名额，随后到达 Ready。各步保持原启动限制和组容量。

另一个输入保留两层推测依赖。中间页已在飞时加入一个普通请求。Release138 把未直接请求的深层依赖抬至零，后者取得下一启动名额。修复后，依赖继承实际推测需求的负优先级，普通请求先启动。仍在飞的中间页沿用原操作所有权。两条对照覆盖准入后的启动排序。实际 AssetBundle I/O、高速首显、持续释放失败及生产性能各自验收。[实际组件回归](../../../Tests/StandaloneStreamedRepresentation/Program.cs.txt)
