# 第23轮复审入口：热点定位完成，复用候选已撤回

TASK_ID c2c_a702，ITERATION 23。完整四项目标和十条工作流继续有效；暗区归因永久取消。实际 GPT 6 Pro23 已批准证据提交和撤回决定，下一包 material-mpb-propagation-01。完整回复已归档。

本包只有两个必要 Unity 构建／可见 DXR 进程，双方均240帧（144预热＋64固定源帧145–208＋32排空），所有正式／诊断token、原始ticks、父子嵌套和退出门槛通过。诊断源接线完全一致，构建输入仅Kernels不同。Gather中位约16.907ms，WorldCache约2.342ms，重建约0.073ms。

唯一候选将接收像素方向无关深度导数移出射线循环；逐方向投影、随机数、查询、PDF和未知值行为保持。有限实际HLSL对照30病例／60方向逐字节一致；三个受影响入口编译通过，优化DXIL确认循环内相关load静态位置16→0。未获得物理寄存器数，也不声明整帧Unity图像等价。

候选Gather中位16.879520ms，仅省0.027856ms，小于两侧块间波动；最后一块17.876176ms原样保留。按运行前冻结规则撤回，不追加样本或第二候选。仓库与部署110产品源码均已恢复定位基线；候选源码、patch、原始证据完整保留。实际独占WindowsImporter已在必要构建验证，未改写22轮历史偏差。

请复核有限结论与撤回决定，然后按原计划选择一个具体材质／形变事件的传播与重投影响应。不要继续无界拆分计时、等价冒烟、暗区或MC。

主要入口：

- `LocalComparison/Review/transport-hotspot-and-reuse-01/result.md`、`contract.md`、`comparison.json`、`rollback.json`。
- `locator/`、`candidate/` 各自的 build-analysis、instrumentation/manifest、native-window/analysis 和原始源帧／完成记录。
- `receiver-contract/results.json`、`compiler/{baseline,candidate}/inspection.json`，大asm/DXIL保留本机并有哈希，不需全量读取。
- `astra-design-review.md`、`astra-prebuild-review.md`、`astra-locator-review.md`、`astra-candidate-gate.md`、`astra-result-review.md`。

原生计时／队列区间与纯kernel耗时、项目owner计账与总VRAM、有限样本与生产验收继续区分。完整生产关卡仍开放。
