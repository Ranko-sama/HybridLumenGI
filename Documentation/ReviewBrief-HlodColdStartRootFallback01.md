# 68：HLOD 近场冷启动容量回退

本轮关闭原目标3、工作流4／8的具体进展缺口：近场从空表示启动，33个细节叶超过32槽总容量时，旧代码既拒绝整组细节，也不准备作者提供的单个root，因此一直没有该组的GI表示。Astra和流式lane分别从实际源码识别；Pro67确认最小方案后，产品实现与独立验证并行准备。

## 最小改动

只改 `Runtime/HybridLumenGIScene.cs` 的目标选择和容量阻塞计数，10行新增／1行替换。原target构造后、ReadyToPublish前，若没有旧published且完整target自身超过规范化总容量，将本次target换成现有root。root仍走原phase2预热、上传预算、revision与geometry/material/lighting完整就绪门控。

`capacityFallback`是每次Prepare重新派生的临时组标志，用于让PendingCapacity在回退预热／发布帧仍按组计一次；root本身暂时放不下也不重复计数。没有新增资源、抢占、slot／GPU格式或永久far状态。旧published保护、排序、原子发布、脏区域和BVH机制保持原实现。

## 决定采用的实际结果

复用 `Tests/Validate-HlodTransactions.ps1` 与三份实际Scene/BVH/Readiness源码；原Unity对象和ComputeBuffer适配边界不变。输入／预期由独立lane在不看候选diff的条件下冻结。

- 唯一旧源命令exit0，固定33叶／32槽／upload1近场的六个阶段持续valid/warming/published/BVH皆0，PendingCapacity恰1；root收据没有可接纳的槽。旧反例成立。
- 唯一候选命令exit0：首次、无收据、错revision、缺lighting时仅root warming1，published/BVH0；完整当前收据后root成为唯一published和BVH叶。六阶段PendingCapacity始终恰1。
- 同一序列移除31叶，仅留2叶。上传预算仍1，旧root在逐叶准备和第二叶无收据时继续保留；全部就绪后一次发布2叶、BVH3节点，root消失并带Representation移除。没有永久降级或双重遮挡。
- 候选同一命令的32叶／32槽空场景直接预热全部细节，没有多占root；随后原HlodProgram的readiness、预算、旧root保持、原子切换、取消、失效和嵌套控制通过。

所有冻结源／夹具／工具哈希前后不变；候选Scene SHA256 `55d412a36bb252957f892a71fd3b0cb6cf349a6ac10b198640bc3e3c93684cdf`。没有行为失败、重跑或事后改预期。准备过程中一次仅文件写入前的LF保护断言停止，零写入／编译／行为执行；说明保留在合同末尾，随后按原LF保存。不能将这一准备异常隐去或混称行为失败。

## 边界与收束

这是实际CPU准入、准备、发布和BVH状态机证据；不证明GPU完成、真实代理视觉覆盖、光照收敛或原生IO。零Unity／Player／GPU运行。没有解决多组暂时争槽、材质页容量、无效／永不ready的root或改变总容量时的既有全量重建。

旧部署及当前本机Release67仍对应产品2fefc09；本修复未部署或重构建。Astra与实际Pro68已接受有限修复并批准本地提交，未发现本范围阻断，结束此功能。Pro读取292／293及实际diff、合同和两侧输出，同意不追加原生矩阵或无缺陷依据的修复包。下一主阶段仍围绕颜色反弹可信和动态稳定，由可定位的场景／动作问题或源码反例决定最小改动及留用／撤回判据。完整原计划及质量、规模、生产关卡继续开放，不能宣布整体效果理想或开发完成。

证据目录：`LocalComparison/Review/hlod-cold-start-root-fallback-01`，独立合同、原源备份、输入哈希及两次原始输出均保存。
