# 面积光屏幕端点冗余计算已移除

采用本次候选并交付[Release76](<I:/Unity test/Comparison/Builds/LocalRelease76/Start-LocalRelease.cmd>)。关闭原计划目标4中的一个具体冗余成本缺口，不关闭总体性能或画质验收。

面积光NEE调用`TraceScreen`只消费hit和距离，原来仍执行world-match、直接光和缓存辐射求值。新增默认开启的`resolveRadiance`参数，仅这个调用传false，在原有深度/材质/朝向资格门控之后返回同一`surfaceT`。方向估计器保持默认完整路径。march/maxT、最近命中比较、采样、随机数和MIS均保持；省略段没有UAV写入或随机数推进。

## 采用依据

同一保存场景、设置、960×540 backbuffer / 480×270 GI、精确软件、RTX2080Ti / DX12 / Unity6000.0.85f1。两侧均为源159–670的512个连续源帧，现有原生完成记录完整，进程正常退出。候选只执行一次成本窗口。

| 三个GI区间按每源帧相加 | 基线 ms | 候选 ms |
| --- | ---: | ---: |
| 中位 | 38.305184 | 30.742288 |
| p95 | 39.450630 | 31.581285 |
| p99 | 39.749279 | 31.818960 |

中位减少7.562896 ms（19.7438%），超过预定5%。两侧各按连续64源帧分为8块：候选最大块中位31.0124 ms低于基线最小33.50224 ms，第二条件也通过。[事前条件](retention-criterion.json)、[同数据计算](comparison.json)保留原值，没有追加窗口、放宽阈值或新增探针。

实际旧/新`TraceScreen`在一个WARP调度内的固定输入中，完整RGB/known保持原字节，端点hit/t符合预期且跳过三项依赖；三个受影响CSTrace入口编译通过。[原始结果](../../../Tests/StandaloneScreenEndpoint/output/result.json)明确屏幕投影、纹理和依赖的适配边界，不将其称作整景图像等价。首次运行的HEAD为d3b8ade；随后仅把脚本基线引用固定为该提交，未重跑。

## 可运行版本与限制

产品来源为d3b8ade之后本次Kernels改动（已提交9657d98）。使用公开构建入口，Release/None，0错误、19条warning；[构建摘要](<I:/Unity test/Comparison/Builds/LocalRelease76/build-result.json>)。保存的Release74统一场景/资源未重生成；构建期间的工程设置和临时观察器已恢复。测量观察器仅在显式传入`-gpuCostOutput`时创建；普通启动器不传入该参数。沿用Release75的操作能力，成本阶段未重复按键测试，也未再构建另一个EXE。

原始[候选分析](<I:/Unity test/Comparison/UnifiedRelease76Cost/result.json>)与[退出记录](<I:/Unity test/Comparison/UnifiedRelease76Cost/exit.json>)保留本机数据路径。比较只涉及ReceiverCapture、Transport、Composite的原生队列区间，可能包含范围内barrier/wait；不含CPU、全部上传/RenderGraph、query resolve或整应用GPU时间，不推导FPS或总VRAM。全机竞争负载未单独量测。这是有限工程采用依据，不是统计显著性或通用19.7%加速保证。

无新图片或独立参考积分；已有颜色误差、换光残留、运动拖影、收敛结论仍保留各自旧来源。全局缓存/屏幕历史响应修复已保留，默认多跳残留和整景颜色准确度仍开放。停止本项成本测量，不追加DXR、动态、压力或细分kernel窗口。

后续单独的普通窗口观察：现有EXE只执行一次L关灯，在工具返回约输入后2.7秒及17.2秒的两张画面间，未见明显持续衰减或旧色拖尾；发光区域仍存在。首次画面已晚于早期响应，工具墙钟也不是渲染帧或曝光时刻，不能据此量化残留、收敛或物理正确性。Esc正常退出，native exit0，日志为`I:/Unity test/Comparison/Release76LightObservation.log`。没有导出新HDR、重跑旧720序列或建立截图体系，该观察线已结束。
