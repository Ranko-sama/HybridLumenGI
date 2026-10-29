# 68 HLOD 冷启动回退：执行前冻结合同

依据 67 的正式下一计划，独立于候选 Scene 改动冻结预期。产品 lane 的 diff 未用于制定断言。只复用实际 Scene/Bvh/Readiness，以及原 Unity/ComputeBuffer 适配器；不改变 runner。

## 唯一旧源／候选对照

使用原 `Group(33)`：root ID 1000，33 叶 ID 1–33，原位置与 bounds 不变。每次近场 `Prepare` 固定相机原点、32 槽、near 20、far 1000、chunk 16、上传预算 1。

旧源与候选执行完全相同的十次 Prepare 和七次显式 readiness 报告；仅预先选择不同断言。前六次分别是首次、无收据、错误 revision、缺 lighting、完整当前收据、保持覆盖。六个阶段的 `PendingCapacity` 都必须恰为 1，表示该组细节需求受阻；不存在因 root 正在 warming 就报告 0 的例外，也不允许按组重复计数。

旧源六次都必须无 resident/warming/published、无 root 槽、BVH 空；给 root 的收据均不接纳。候选前四次只能有一个 warming root，不能进入 BVH 或产生世界变化区域；错 revision 拒绝，当前未完整收据可以接纳但不能发布。完整当前收据后，只有 root 发布、BVH 只有对应槽的一叶，33 叶没有部分驻留。

同一 scene 随后仅移除叶 3–33，保留前两叶和所有 Prepare 参数。第一次只上传一叶，并给两叶报告完整当前收据，必须仅接纳已上传的一份；第二次上传另一叶。第三次不添加收据，候选仍保持唯一 root，旧源保持未发布，证明仅部分目标就绪不能切换。随后给两叶完整当前收据，第四次一次发布两叶、BVH 三节点，root 不再驻留；候选还必须记录 root 的 Representation 移除。缩小后的四个阶段 `PendingCapacity=0`，上传等待数依次 1、0、0、0。

## 候选保持控制

新增唯一恰好容纳控制：空 scene 的 32 叶／32 槽，近场、上传预算 32。首次只暖全部 32 叶，root 不驻留、published/BVH 为空、没有容量或上传等待；完整当前收据后一次发布全部 32 叶，BVH 63 节点，无 root。

随后在同一命令继续原 HlodProgram 全套控制，原 helper 前缀与控制尾部保持原字节。它已涵盖完整 readiness／revision、预算、原子切换、取消、已发布 root＋32 叶容量不足保持、材质保留、过期几何撤销、卸载重载及嵌套分组。

## 执行与退出

只允许根执行一次 baseline 和一次 candidate，使用原 `Tests/Validate-HlodTransactions.ps1`。环境变量 `HLGI_HLOD_COLD_START_EXPECTATION=baseline` 选择旧源预期，SourceRoot 为包内 baseline-source；同一序列结束后 return，不执行候选控制。candidate 可设为 `candidate` 或不设置变量，SourceRoot 为仓库。其他非空值拒绝。

runner 继续通过原 net8.0 项目编译三份真实产品源；已读到 dotnet 路径为 `C:/Program Files/dotnet/dotnet.exe`。首个非预期结果立即停止并保留，不追加运行、不修改容差或预期、不扩矩阵。根冻结全部输入后才执行；本合同准备未运行编译或测试。

退出只证明 CPU 选择、上传准备与发布状态机，不能证明 GPU 完成、代理视觉覆盖、照明收敛或原生流式 IO。零 Unity／Player／GPU 运行。逐文件 SHA256 记录于 contract.json。

准备记录：一次合同写入脚本误假设原测试使用 CRLF，在写入前由保护断言停止；该命令未写任何文件，也未编译或执行行为。随后只读确认原件和增量均为 LF，保留原行尾并核对原 helper／控制段字节，无需产品重试。
