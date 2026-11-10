# 域外 HLOD 组计数误触发的近远景接替

原 281 双 Base 场景增加一个处于 25 单位可见界外的 HLOD 组，由一个根和 32 个仅有 Collider 的活动代理构成。实机记录确认整个组都在两台相机的可见域外，场景占槽为零。旧版仍把它的成员计入 HLOD 候选，36 个组候选超过了 32 槽容量，结果漏判实际继续驻留的普通精确物体 D。主组的近景精确细节 A／B、超过精确三角额度的近似粗根、光源、配额和相机路线沿用 281。

| 实际阶段 | Release234 | 修复后 |
| --- | --- | --- |
| 第 12 帧，远景粗根预热完成 | A／B／D 都参与 DXR，粗根实际照明回执通过，epoch 5，年龄 3 | 同条件 |
| 第 13 帧，另一相机耗尽共享构建名额 | 提前发布粗根，D 仍在世界 BVH，主相机回退到软件。epoch 6，粗根年龄 1，当前照明门失效 | 保留 A／B／D 的实际 DXR，粗根继续预热。epoch 5，原图卡年龄 4，等待意图 1 |
| 第 14 帧，下一轮构建 | 恢复 DXR，epoch 7，粗根年龄仍为 1 | 录制一次构建，粗根和 D 成为世界 BVH 的完整集合。D 保持精确，粗根以原图卡和 epoch 5 达到年龄 2 的原就绪门，等待归零 |

Scene 先确定全部在域组的目标，再判断已就绪接替是否需要共享构建机会。普通对象的保证前缀为场景容量扣除各在域组 `published ∪ target` 的保守余量，其中也包含等待接替的组自己的旧表示和预热目标。即使其他组随后完成切换或因容量延期，这个上界也能覆盖本帧的槽位选择。原图卡就绪回执和 RTAS 工作配额仍用于实际提交。[场景选择](../../../Runtime/HybridLumenGIScene.cs) · [旧版逐阶段读回](baseline.json) · [修复版逐阶段读回](candidate.json)

两侧均使用 Release234 同源独立工程 `776906d7a5b3faf547390029ef50cb4cd4bbec85`，候选只覆盖 Scene 文件。Unity 6000.0.85f1／URP 17.0.4／RTX 2080 Ti／DX12 Editor Play，双显式 Base 请求共用每引擎帧一次 RTAS 构建。两侧退出 0。采用范围为固定域外组和实际热态世界接替，普通光栅画面、冷高速首显及完整生产负载分别验收。[复用的 281 对照](../hlod-exact-departure-281/result.md) · [旧版退出](<I:/Unity test/Comparison/HlodOutsideGroup288Baseline/native-exit.json>) · [修复版退出](<I:/Unity test/Comparison/HlodOutsideGroup288Fixed/native-exit.json>)
