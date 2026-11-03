# 统一示例活动 Skin：预算与 CPU 快照帧龄

**原 T3／T6 的默认活动 Skin 同窗成本缺口已有有限依据：本次 GI 合计 p95 17.088ms、进程 local 采样峰值 572.004MiB，满足 25ms／1GiB 起始预算。** 新快照从实际捕获帧到首次 CPU 观察的帧龄 p95 为 11 帧、最大 12 帧。这关闭该使用条件的成本与 CPU 观测帧龄未知子项，不能替代形变画质、BakeMesh CPU 耗时、GPU 消费延迟或完整 G3／G4／G5。

## 输入与唯一运行

当前 Release122 同源产品 `7c08327`，从同版可编辑工程构建普通 Win64／Mono、Release／None 私有测量 Player。Unity6000.0.85f1／URP17.0.4，RTX2080Ti、D3D12、Linear；默认色墙场景 `Assets/HLGINeutral106/Variant/NeutralThreeRooms.unity`，原相机／灯光／HUD、960×540／GI480×270、2ray／filter4、偏好 DXR。没有改 Runtime／示例、时间步长、配额或公开122。

仅调用已交付的 `SetSkinnedDeformation(true)` 和 `SetDeformationRunning(true)`，对应 K+Space，M 刚体运动关闭。实际默认网格只有 **24 顶点、12 三角、2 骨**；SDF32、捕获间隔4帧、共享顶点额度65,536／帧、worker2、形变内存128MiB、发布上传8MiB／帧，捕获经过时间门保持默认0。它不是大模型或连续可读网格成本。

初始准备后固定32个活动源帧，再记录35秒；不等待全窗 all-ready，不按成功／稳定筛帧。引擎源191–2400共2210帧，源窗35.011173秒，骨角变化2209次、新快照首次 CPU 观测205次。全部实际 DXR、原生计时可用，无记录到的材质／身份 unknown、fallback mesh 或 mesh／SDF／charts 来源引用不一致。CPU Scene 全窗记录 Published，仍不证明 GPU 已消费当前几何。

使用现有 measure-only 原生计时与进程显存观察，反馈关闭、targetMs0；**这是开启观察的成本，不能当作默认关闭观察时的性能。** 同窗 PresentMon 仅调用一次，Player PID31336 正常退出0，没有超时强杀或重启。

## 成本、Present 与帧龄

每个源的完整 token／owner／generation／deviceEpoch／计时 epoch／provider 身份与六个 timestamp 匹配；无缺票或重复。先求该源三个区间之和，再用 `(N−1)q` 线性插值取分位；没有把三个区间的各自 p95 相加。

| 原生队列区间，ms | 中位 | p95 | p99 | 最大 |
| --- | ---: | ---: | ---: | ---: |
| ReceiverCapture | .154 | .170 | .177 | 2.625 |
| Transport | 14.739 | 16.858 | 17.881 | 19.292 |
| Composite | .069 | .075 | .077 | .334 |
| 同源三段合计 | 14.958 | **17.088** | **18.115** | 19.510 |

区间可能包含屏障／等待，不是隔离 shader 执行时间；范围外 CPU 准备、上传、query resolve、RenderGraph 与应用总 GPU 时间不在此合计中。计时 token epoch 不等于世界照明 epoch，不能据其不变推断世界状态不变。

同一源范围2210次 DXGI 进程采样全部有效，local 峰值 **572.004MiB**，nonlocal 峰值 **303.688MiB**。它们是 Unity 适配器上的本进程有限采样，不是 GI 独占、瞬时上界或整机显存；两类不相加。该窗达到 GI p95≤25ms、local≤1GiB 的已定门槛，不能推广到冷入、长时、更多对象或压力边界。

PresentMon 调用 UTC23:40:34.670006–23:41:04.817460 完整位于活动窗23:40:34.622958–23:41:09.634461内。同一进程／DXGI流，首行没有前序锚点而排除；其余1888个间隔覆盖29.948225秒，应用 Present 平均 **63.042Hz**，间隔 p95／p99／最大 **20.083／21.770／27.078ms**，没有超过30FPS对应33.33ms的观测间隔。这是应用呈交节奏，不是显示器实际帧率，也没有与 GI 源逐票配成联合指标。

205个新快照的“实际捕获引擎帧→首次观察到匹配 CPU mesh／SDF／charts”的帧龄中位／p95／p99／最大为 **11／11／12／12帧**。统计总体是新快照首次观测，**不是2210个渲染帧各自正在使用的快照年龄**。PublishedFrame 仍表示捕获帧；这些数据不是精确发布时间、BakeMesh CPU 毫秒或 GPU 几何消费延迟，也不按目标30FPS换算成实测毫秒。

首次 camera 源回调在 realtime76.1864秒，Skin 在79.0837秒启用，活动准备到成本窗开始约.5988秒；首个 Skin CPU 快照于引擎168观测、捕获159，源切换 marker 到首次观测约.2236秒。这些在暖窗之外的准备钟原样保留，不是隔离成本，不把初始等待归因于 Skin／BakeMesh。固定32帧收尾后 provider 仍记录2个 pending；2210个成本窗票据已完整，但不能声称所有 GPU 工作均排空或清理全部验证。

## 未交付截图与采用边界

首次构建的可选 ScreenCapture 调用因精简工程缺该 API 而 CS0103 编译失败，Player 没有运行。主线程遗漏了该依赖。按 Astra 允许的一次入口更正，只删去可选截图调用并记录 unavailable，没有添加模块／替代采集工具或改变核心判据；更正构建0错误、5警告，之后仅一次实际 Player。原失败源码、合同及日志保留。**原窗后 PNG 输出没有满足，画面可判读及运动质量在此项仍未知**，不把成本合格写成完整冻结合同所有输出通过。

本项只采用原默认活动 Skin 的有限预算、应用 Present 与新快照 CPU 观测帧龄。形变拖影／颗粒、CPU 捕获耗时、GPU 消费时刻、更大模型、可读网格、冷启动及完整生产验收继续开放；不因此补图、重跑、加 profiler 或扩大压力矩阵。公开 Release122 继续复用。

[数值及资格](result.json) · [原合同与更正说明](contract.md) · [离线解释器](analyze.py) · [原始数据、失败记录和观察入口](data-and-source.zip)。原数据：`I:/Unity test/Comparison/SkinCost135Corrected`；初次失败：`I:/Unity test/Comparison/SkinCost135`。
