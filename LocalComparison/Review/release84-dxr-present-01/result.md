# 普通Release84的DXR应用Present窗口

**本次普通窗口的应用Present平均79.22Hz，p95／p99间隔14.33／14.81ms，所有观测间隔均小于33.33ms。** 对当前本机960×540／30FPS方向，既有DXR路径提供了有效的有限呈交依据；不等于显示器实际FPS、动态/长时验收或完整G5通过。

| 项目 | 观测 |
| --- | ---: |
| 两端Present时间跨度 | 29.965655秒 |
| 应用Present平均频率 | 79.224032Hz |
| 平均／中位间隔 | 12.622432／12.533900ms |
| p95／p99间隔 | 14.325255／14.808761ms |
| 最大间隔 | 17.171700ms |
| 超过33.333333ms的间隔 | 0／2374 |

唯一CSV有2375行，同一个PID2892／DXGI swapchain。只去掉第一条缺少窗口前锚点的间隔，其余2374条全部保留；间隔和与时间戳跨度相符，百分位为(N−1)×q线性插值。SyncInterval=0、PresentFlags=512。关闭display tracking，因此CSV里的Dropped字段不能解释成零显示掉帧。

## 同一个普通Player的配置依据

普通Release84／a3a570e，只新增F2对既有Log ledger的键盘接线；GI仍为0181ef2。保存的统一示例、Release/None、DX12、启动参数960×540窗口；UI与普通输入均保留。没有临时观察器、GPU计时或预算反馈。本次没有截图或逐帧尺寸记录，分辨率依据启动配置，不把旧Editor图像当作这个Player的画面证明。

在同一个PID2892内用5请求DXR，再以F2分别记录采集前后CPU状态：

- engineFrame4366／12191，publicationEngineFrame各为前一帧，当前诊断随运行推进。
- 两端actualBackend=DXR、hardwareBackend=true、20个硬件网格、0fallback、0未知材质记录。
- 两端均为完整details已发布，3个visible成员、13页ready，loading/failed、实例warming/pending均为0。
- 两端GPU计时、预算反馈及进程显存采样均关闭；采集期间没有输入或日志操作。

这些是采集两侧的最新CPU诊断，**不证明每个中间帧或每条射线的后端**。原始端点见[before-ledger.json](before-ledger.json)、[after-ledger.json](after-ledger.json)。

## 范围与收束

复用既有PresentMon2.6.0：10秒delay、30秒timed、关闭display/input/GPU跟踪。PresentMon PID15500／会话59315正常退出0，watchdog=false；采集时间2026-10-30 03:25:31.052539至03:26:11.433450 UTC。Player于03:23:32.266244启动，03:26:36.670455正常退出0／watchdog=false，原启动会话23317已终止。

此处是应用调用Present的节奏，不是显示器呈现、整帧GPU计时或旧13.28ms GI成本的重测。旧Release83软件29.15Hz保留其原来源，不据两次不同运行给出配对加速倍数；没有重跑软件或画质矩阵。默认后端仍为软件，用户可按5请求DXR、F2记录实际状态。等画质、运动场景尾部、长时稳定及总显存预算仍须分别处理。

本项到此结束：补齐现有DXR普通运行的应用Present依据，不追加窗口。独立复核确认同进程端点与统计口径无阻断问题。完整数值见[result.json](result.json)，原始CSV见[测量目录](<I:/Unity test/Comparison/Release84DxrPresent01>)。
