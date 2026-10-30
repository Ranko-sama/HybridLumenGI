# Release85三轮分页恢复与空场重复准备问题

**三轮近→远→离场→近均取得恢复端点；同阶段的当前页持有、引用和所列字节一致，三个离场端点归零。但本次发现空场反复准备的异常，且最后返回近场的记录超出原30秒范围，不能报告整项按原scope通过或运行全正常。**

复用已交付Release85／本机DXR启动偏好5e6b836，Runtime a3a570e／GI0181ef2；960×540普通窗口、原场景、预算和UI。唯一Player PID8724从2026-10-30 14:52:36至15:01:45（北京时间）运行，正常退出0，watchdog=false，见[player-exit.json](player-exit.json)。没有新增构建、观察器或测量运行。

## 十个F2端点的当前持有

下列近场值在初始及三轮返回共4个端点一致；远场、离场各3个端点一致。字节是各自公开计账，不相加为总量。

| 阶段 | 可见／绑定成员 | Ready页／消费引用 | Bundle字节 | Resident字节 | GI实例／硬件网格 | 硬件属性字节 | 材质全局当前字节 | RTAS当前计账字节 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 近场 | 3／4 | 13／18 | 139484 | 567710 | 20／20 | 50176 | 5520 | 132096 |
| 远场 | 1／1 | 8／6 | 122593 | 294809 | 18／18 | 50176 | 5520 | 132096 |
| 离场 | 0／0 | 0／0 | 0 | 0 | 0／0 | 0 | 0 | 0 |

近场为`complete details published`，远场为`aggregate published`，均无`replacement warming`且actual为DXR。离场actual为SDF/analytic software、已发布实例为0；其waiting文字与旧publication帧号是控制器保留状态，不代表仍有页或可见组。

十个端点的`pagesLoading/pagesReleasing/pagesFailed`、`pageActiveOperations/pageIoBytesInFlight/pageRetiringLeases`均为0。所记录的`retirementPending/Owned/Failed/UnknownSubmissions`及`rtasGlobalRetiredBytes`均为0，`retirementSubmissionUncertain=false`。这些只说明采样端点的公开状态，不能推断端点之间没有在途退休、所有GPU工作完成或退出后的全部资源归零。屏幕纹理、世界atlas/cache等保留容量无需随离场清零。

原始端点：[初始近场](00-initial-near.json)；[1远](01-far.json)／[1离场](01-outside.json)／[1近](01-near.json)；[2远](02-far.json)／[2离场](02-outside.json)／[2近](02-near.json)；[3远](03-far.json)／[3离场](03-outside.json)／[3近](03-near.json)。

## 时间范围偏离

原[scope](scope.md)限定每阶段最多30秒。下表是主线程保留的输入至F2工具调用墙钟耗时，含操作和调度等待，**不是精确加载／退休延迟**。

| 轮次 | 远场工具elapsed秒 | 离场工具elapsed秒 | 返回近场工具elapsed秒 |
| --- | ---: | ---: | ---: |
| 1 | 8.461 | 17.521 | 8.953 |
| 2 | 5.359 | 7.995 | 6.405 |
| 3 | 5.967 | 6.560 | 271.747 |

最后03-near因上下文恢复延迟才取得记录。它证明最终恢复到同一近场端点，**不能证明30秒内恢复**；不能把三轮全部重标为满足原scope。其余八个移动端点虽在相应工具窗口内记录，也不给出精确就绪时刻。没有为弥补此范围偏离追加轮次或重启。

## 保留的异常及下一步

`hardwareSceneRebuilds`与`hardwareTriangleUploads`累计值始终相等：初始近场为4，三个离场端点依次为4804、12184、18417，最后近场为24313。累计值无需归零，但这种空场数千次重复增长不能用“累计计数正常”掩盖。

主线程随后从当前源码确认：硬件场景为空时，准备路径每帧重新分配dummy缓冲并退休旧缓冲。该重复准备／分配问题**待修**；本次端点当前持有未见积累，不据此命名为资源泄漏，也不因最终页计账归零而忽略它。计数名称不证明对应数量的真实RTAS构建，当前也没有成本测量。

本观察在正常退出后收束，保留时间范围偏离和空场重复准备异常，交后续最小源码修复处理。结论限于三轮端点恢复、页持有归零及上述具体异常，不扩大为完整G4、生产长时或形变资产生命周期通过。
