# 热态连续近远切换的有限结果

原G4补齐此前缺少的实际使用依据：**已就绪近场出发、途中不等待ready的连续快速近远切换中，完整Renderer可提交组和当前HLOD发布组保持；回近后完整细节恢复。** 这是按实际对象身份记录的CPU状态，不是逐像素无洞或完整G4通过。

当前Release90产品55b5908、原统一场景、960×540／半分辨率GI、2ray、默认DXR。作者两端相距11.94405世界单位，以20单位／秒往返10次，预先计算运动时长11.94405秒，路线始终在驻留域内。计时、反馈、显存观察、UI与输入关闭；没有图像或新GPU读回。

运动记录覆盖20个单程。每次beginCamera的可提交集合均为完整root或全部三个details；每次endCamera的当前发布集合也均为这两种完整身份集合之一，没有半组、混组或失效来源。两者分别记录，允许正常交接时本帧begin与end不同；end状态不是本帧像素内容。

运动中目标集合变化20次、发布集合变化19次，294个记录帧处于替换准备状态，30帧有页IO状态活动。每步IO启动计账合计168,910B、并发操作最多2，不是磁盘吞吐。全部1219份运动CPU后端诊断为DXR，不作逐射线硬件执行证明。

回到Near时先保留root，8个恢复阶段记录帧后达到完整details；最终13个Ready页、18个消费引用、3个可见／4个绑定成员，loading／releasing／failed／activeIO／retiring leases皆0。首个恢复begin至最后end的记录跨度0.1623092秒，**不是精确IO或HLOD恢复延迟**。数值见[result.json](result.json)，原始记录见[run.json](<I:/Unity test/Comparison/ContinuousNearFar01/run.json>)。

唯一临时Release/None构建成功（Unity PID22096、0错误／23条warning），作者Renderer、Quality、初始化器及临时驱动已恢复。Player PID22640正常退出0，无watchdog；见[构建来源](build-attempt.json)、[构建退出](build-exit.json)、[运行退出](native-exit.json)。普通Release90未覆盖，产品源码未修改。

独立源码／结果复核与Astra同意收束。既有冷热、在途撤回、三轮停稳循环和静止300秒证据不重复运行。本次不覆盖未驻留冷区穿越、持续负载压力、像素覆盖、颜色／残留／拖影／收敛、性能或显存；原G4完整条件仍开放，不追加路线或延长窗口。
