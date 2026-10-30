# Release90当前2射线GI基线

关闭G0的一项具体信息缺口：当前2射线配置此前只有应用Present分布，GI专项成本仍沿用旧1射线数据。现在取得当前产品0667864的预热后静止DXR基线，供正式GI／显存预算选择；普通Release90不变，完整G0–G5没有因此放行。

| 测量 | 中位 | p95 | p99 | 最大 |
| --- | ---: | ---: | ---: | ---: |
| GI三个区间合计 | 21.66736ms | 22.64332ms | 23.93786ms | 24.41347ms |
| Transport | 21.45250ms | 22.42657ms | 23.71511ms | 24.19194ms |
| ReceiverCapture | 0.14939ms | 0.16009ms | 0.16794ms | 0.17408ms |
| Composite | 0.06349ms | 0.06555ms | 0.06665ms | 0.06758ms |

按每源帧先相加三个区间，再计算合计分位数；线性插值位置为(N−1)q，不相加各区间的分位数。512个连续源帧159–670均取得有效完成记录，实际DXR；配置960×540、GI480×270、2ray、cache8、filter3。Unity6000.0.85f1、DX12、RTX2080Ti，VSync0、targetFrameRate−1；只测量、反馈关闭、静态配额保持。完整数值及完成记录解释见[result.json](result.json)。

同源窗口的进程local当前／采样峰值为592,908,288B（565.4414MiB），nonlocal为301,535,232B（287.5664MiB）；512次CPU采样成功、无失败。local/nonlocal分开报告，不相加为峰值，不是GI独占、整机显存或瞬时／生命周期峰值。OS预算不是产品预算。

相机endCameraRendering回调间隔中位22.0436ms、p95 24.38185ms、p99 25.60828ms；平均45.2405次／秒仅说明回调节奏，**不是Present／显示FPS**。GI区间也不包含范围外CPU准备／上传、query resolve或完整应用GPU成本，区间可能含队列等待／屏障。

## 执行与适用范围

原样复用[既有observer](../release83-dxr-cost-01/UnifiedSampleGpuCost.cs)和已有分析，没有新计时系统或探针。唯一测量专用Release/None构建成功（Unity PID22280、0错误／23条warning）；作者Renderer、Quality、初始化入口和临时observer已恢复。唯一Player PID21820正常退出0，未触发watchdog。来源与退出见[构建记录](build-attempt.json)、[构建退出](build-exit.json)、[运行记录](native-exit.json)。原始完成记录、设置与ledger位于[本次运行目录](<I:/Unity test/Comparison/Release90DxrBaseline01/run/20261030-105239-c2c1072e3e694a70a42d44912f87b156>)。

窗口相机静止，UI／输入关闭；不是普通交互、运动最坏情况、冷启动或长时压力验收。与旧Release83的1射线GI值或Release88的普通门运动Present值不构成单变量配对，不能相减归因或推导等画质加速。没有新图像，颜色、换色／关灯残留、运动拖影和精确收敛保持各自原来源。

独立复核无阻断，Astra同意收束。用户随后明确采用“现有GI三区间合计p95≤25ms、本进程local有限采样峰值≤1GiB，nonlocal另列”作为起始目标；本窗口22.6433152ms／565.4414MiB满足这两个门槛，无需重跑或自动启用反馈。原result.json中的目标未定描述保留采集时状态。该决定不将有限静止窗口提升为完整负载、G0/G5或生产放行；测量到此结束。
