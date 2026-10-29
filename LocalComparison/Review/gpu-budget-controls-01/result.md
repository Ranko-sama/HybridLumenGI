# 普通运行的 GPU 时间与预算入口

关闭原计划目标3／4、工作流8中的使用入口缺口：统一 Player 现在可以直接使用既有计时与反馈控制器，不再需要先修改 Inspector 或临时脚本。没有新增控制算法或自动预算选择。

在原面板展开 **GPU time / update budget**，选择 **Measure only** 查看现有GI区间；输入有限正数并点击 **Apply feedback** 才启用反馈，**Off** 关闭。输入草稿不改变配置，非法目标保持旧设置；输入时数字导航与运动快捷键暂停。面板区分请求配置与实际诊断，缺测不显示为零成本，历史值明确可能来自旧配置。详见[用法与公开API](../../../Documentation/GpuBudget.md#普通运行入口与公开配置)。

## 单次普通使用结果

公开 Release81 构建成功：Release／None、0错误／23条warning，继续使用保存的统一场景。[构建结果](<I:/Unity test/Comparison/Builds/LocalRelease81/build-result.json>)。一次普通 Player 使用完成以下状态，随后Esc退出，原生退出码0。

| 操作与观测 | 实际结果 |
| --- | --- |
| 初始展开 | 请求off、目标0；无有效计时显示为不可用 |
| Measure only | NativeDX12 Ready，有效观测；反馈false，scale=1，patch／capture／brick配额256／24／16 |
| 输入0并Apply | 显示须输入有限正数，仍为measure only、目标0 |
| 真实数字键输入20 | 草稿为20，仍未应用；相机没有触发数字2的远景快捷键 |
| Apply feedback | 请求20ms，实际反馈true、有效观测；scale=0.125，配额32／3／2；明确提示最低工作量仍超目标 |
| Off | 两项请求false，计时Disabled、观测无效、反馈false；scale=1，配额恢复256／24／16 |

20ms仅用于这一次功能操作，**没有要求达到，也不是生产预算**。耗时仅为既有GI区间，不能当作应用帧时间；这些状态快照不是性能分布或反馈算法验收。原有[ledger](ledger.json)保留measure／feedback／off三次状态；没有新增观察器、定长成本窗口、统计、画质采图或哈希。UI操作截图仅用于实际操作和布局判断，没有另做图像质量结论。

## 整合与边界

[Release81启动入口](<I:/Unity test/Comparison/Builds/LocalRelease81/Start-LocalRelease.cmd>)同时纳入此前`f8b24db`的零AO缓存依赖修复。该修复原先只有源码审阅，本轮进入实际Unity构建，但没有新增零AO专项运行；不把普通UI操作当作该条件的图像验证。真实Skinned、来源分离关灯缓存、进程显存观察继续保留。

颜色误差、换色／关灯残留、运动拖影和准确收敛时间沿用[已有画面对照与范围](../dynamic-picture-comparison-01/report.md)及[来源分离结果](../cache-source-separation-01/result.md)，本轮不增加画质通过项。目标分辨率／FPS、GI时间和显存生产预算，以及完整G0–G5仍未关闭。此次使用结束后不追加反馈调参或测量窗口。
