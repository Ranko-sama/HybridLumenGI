# HybridLumenGI 本机修复后对照

2026-10-27 · local-runtime-fix02 · Unity 6000.0.85f1 / URP 17.0.4 / DX12 / RTX 2080 Ti / Linear HDR 640×360。

**本轮两项阻断已在固定 Editor 场景中修复并实测：默认精确路径不再编译超时；黑室明显漏光已消除，多次反弹保持开启。仍有微小非零残余，不能据此声称所有场景零漏光、Lumen等价或生产放行。**

[打开图像对照](REPORT.html) · [前轮报告](REPORT-first-round.md) · [精确路径分析](Results/old-new-exact-fix02-analysis.json) · [SDF分析](Results/old-new-sdf-fix02-analysis.json) · [源码差异](Evidence/local-runtime-fix02/product.patch) · [来源哈希](Evidence/local-runtime-fix02/source-revisions.json)

## 结果与对照

新版默认精确路径与 SDF 各完成720逻辑帧、32张HDR，零采集错误。720帧相机、门、光源和共同环境与旧版一致。精确路径所有帧均报告 exactSoftwareGeometry=true，hardwareBackend=false，无未知材质记录。色墙仍有非零GI增量，未靠禁用整个GI或多次反弹使黑室变黑。

旧版和GI关闭基线完全复用已有结果；前轮新旧off的32张raw逐字节相同。本轮没有重启旧版、重跑off、堆叠测试进程或重跑整套离线回归。阶段统计来自32个捕获点，不是全部720帧逐像素收敛判定。

| 观测 | 旧版兼容副本 | 新版默认精确路径 | 新版 SDF 回退 |
| --- | ---: | ---: | ---: |
| 色墙阶段平均 GI 增量 Y | 0.037336527 | 0.029789152 | 0.029735536 |
| 移动门阶段平均 GI 增量 Y | 0.037715093 | 0.033822253 | 0.033800185 |
| 薄壁阶段平均 GI 增量 Y | 0.056555997 | 0.25008287 | 0.24860732 |
| 黑室帧719平均 Y | 2.4964658e-06 | 5.1128923e-07 | 5.5989815e-06 |

亮度高低不是质量评分：薄壁仍有明显差异，缺少可信物理参考，本轮不把其更亮或更暗写成改善。

## 修复与证据

1. 合并近远场详细遍历的调用点，并把四个缓存邻域查询从展开改成循环，避免重复内联整个几何/材质链。保留查询语义、原优化级别和默认精确软件设置。CSTrace输出约2.25MB，缓存更新约0.81MB（原约3.92MB）；本轮首目标相机receipt约249秒，随后完成720帧。这个启动成本包含编译/驱动初始化，不是GPU帧时间，也不是零编译开销。
2. 实际GPU缓存读回发现屋顶内面锚点(11.971396,4,-2.0143013)埋在左墙内却有约0.74的缓存亮度。从锚点向外检查遮挡会从被Cull背面逃出。现在从当前查询表面向锚点检查，偏移两端并检查完整线段。保留Cull、alpha和多次反弹；正式结果bounceFeedback=1。
3. 回收先前已验证的Unity API、UInt纹理能力及RenderGraph投影修复到工作源码。根源码与实际Unity工程的四个产品文件SHA256一致。旧ZIP/RAR未修改，本轮没有重新分发归档。

精确路径黑室末帧平均Y：只修编译时0.00876667 → 完整修复0.000000511，最大RGB从0.025674降到0.000243。SDF从0.01279086 → 0.000005599，最大RGB从0.027145降到0.001060。GI off为0。该症状已大幅消除，微小残余明确保留为观察限制。

一次bounceFeedback=0诊断和一次缓存状态读回用于定位，均非正式交付设置。数值回归只扩展已有transport-normal-reference中的埋入点/连接方向/末端薄壁案例；Astra Max进行了只读增量审查。未扩展测试矩阵或功能。

## 运行边界与停点

本轮止于上述两个受影响路径的Editor实测与同场景对照。新版Player未复验，DXR、GPU p95/p99、峰值显存、长时稳定性没有新增证据。既有FrameTiming数据不能作为GI性能结论。历史integration-15离线报告仍只代表其对应来源，没有重标为当前修复版全量通过。

本机工程已恢复exactSoftwareTracing=true、preferHardwareTracing=false、bounceFeedback=1；捕获诊断钩子已从普通采集入口移除。测试进程已退出。再次分发或做Player交付时再处理相应关卡，不把它扩成本轮额外测试。

完整修复说明也在工作区Documentation/LocalRuntimeFix02.md。固定场景原始帧、EXR、RGBA32F、feature.json和日志均保留，详见分析JSON的sources。
