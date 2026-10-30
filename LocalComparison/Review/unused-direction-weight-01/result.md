# 未消费方向权重候选：撤回

**未采用，定位与验证结束。** 此次没有关闭新的性能功能缺口。[普通Release83入口](<I:/Unity test/Comparison/Builds/LocalRelease83/Start-LocalRelease.cmd>)保持原产品；工作区及Unity部署的候选HLSL已恢复。用户新增的960×540／30 FPS目标已独立写入计划，不因候选失败撤销。

候选针对真实重复工作：面积光开启时，方向sampler先计算完整vMF PDF得到weight，两个生产caller随后由Matched再次求PDF并覆盖weight。当前完整精确软件CSTrace的优化DXIL确认重复没有被消除。最小改动只跳过未消费的第一次权重计算，保留方向、RNG与最终Matched算术，见[原范围](scope.md)和[被撤回的产品差异](candidate.patch)。

独立源码复核通过；一次已有WARP宿主的真实HLSL配对，在预先固定输入下保持方向、RNG、有效最终权重和拒绝语义。非法输入、资源适配及未消费值边界见[有限对照](finite/README.md)与[原始结果](finite/output/result.json)。它不是整景图像或性能证明。

唯一候选测量使用原Release83观察器、保存场景、960×540／480×270 GI、RTX2080Ti DX12、精确软件、固定配额及关闭反馈。源帧159–670的原生记录完整，实际更新配额和环境字段符合对照要求；Release／None构建成功，Player正常退出，无watchdog终止。

| 每源帧三个GI区间之和 | Release83基线 ms | 候选 ms |
| --- | ---: | ---: |
| 中位 | 28.017152 | **30.547456** |
| p95 | 31.185560 | 31.253891 |
| p99 | 31.446907 | 31.521176 |
| 64帧分块中位范围 | 27.777504–28.305616 | 30.405552–30.636192 |

候选中位在这次观察中比基线高约9.03%，不是改善。预先固定的至少5%中位收益、分块分离及p95/p99不增条件全部未通过，详见[采用规则](retention-criterion.json)和[成本结果](cost-result.json)。没有用启动等待或进程时长代替GPU数据；也没有据此断言所有设备／运行中的因果退化或推测编译器原因。

据既定规则，立即恢复三个产品HLSL及两处仅为候选同步的测试调用声明；Unity侧从部署前备份恢复，见[恢复记录](deployment.json)。测量构建的临时Quality／初始化器／观察器也已恢复。没有追加窗口、图片、哈希、参数搜索或分pass诊断，不为此构建新的普通发布版本。

颜色、换色／关灯残留、运动拖影和收敛时间没有新增结论；仍以[主画面对照](../dynamic-picture-comparison-01/report.md)各版本的有限结果为准。实际30 FPS与完整G0–G5尚未验收。

原始运行：[Player退出](native-exit.json)、[构建结果](<I:/Unity test/Comparison/Builds/UnusedDirectionWeight01/build-result.json>)。候选目录仅作失败记录，不是当前启动入口。
