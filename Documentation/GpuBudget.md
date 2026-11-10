# GPU 时间反馈与更新预算

Release108 的屏幕预算根据该相机实际执行的空间滤波级数计入工作纹理。0 或 1 级只需一张 RGBA16F，2–4 级共需两张。四级半分辨率 GI 在本机普通示例少计 1,036,800 字节，对应一张已经去掉的 480×270 纹理。此数值是相机的逻辑资源账目。[实机条件与结果](../LocalComparison/Review/filter-work-texture-01/result.md)

## 当前已确认的起始验收目标

Release233 同源普通 Player 在默认近景同时运行门平移、两骨蒙皮和逐源切灯。35 秒实际 DXR 窗的三段 GI 合计 p95／p99 为 16.572／17.564 ms，进程 local／nonlocal 采样峰值为 580.316／304.688 MiB，达到原 25 ms／1 GiB 门槛。PresentMon 丢事件且未生成 CSV，此并发负载的应用呈交继续验收。[同窗预算与范围](../LocalComparison/Review/combined-update-cost-285/result.md)

新的三角 BVH 分组在 Release227 同源固定近景将软件 GI 合计 p95／p99 从 45.465／45.885 ms 降到 37.060／37.574 ms。local 有限采样峰值 552.512 MiB，满足 1 GiB 门槛。软件仍超出 25 ms，动态重建成本和其他负载继续按原条件验收。[分组实测与范围](../LocalComparison/Review/software-bvh-sah-291/result.md)

Release227 的单次全距查询候选 p95 为 43.860 ms，降幅 3.53%，低于事前 15% 采用门槛，已收束。[同源实机对照](../LocalComparison/Review/software-full-range-277/result.md)

Release196 已采用精确软件覆盖去重。在同一固定近景和画质下，合计中位降低 7.27%，p95／p99 为 45.887／46.349 ms，仍高于 25 ms 时间预算。候选同窗 local／nonlocal 有限采样峰值为 549.574／278.789 MiB。显存读数按各窗口采样使用。[同输入对照与采用边界](../LocalComparison/Review/software-coverage-231/result.md)

Release205 的同一近景精确软件窗口实际 p95／p99 为 47.200／47.818 ms，进程 local 采样峰值为 550.699 MiB。确定阴影遮挡时提前结束的候选使 p95 降至 45.658 ms，未达到预定的 15% 采用门槛，已撤回。软件 25 ms 时间缺口继续开放。[同源配对与采用判定](../LocalComparison/Review/software-shadow-246/result.md)

Release208 的同一固定软件近景实测 p95／p99 为 46.868／47.240 ms，进程 local 采样峰值为 551.699 MiB。延后 Gather 世界材质求值候选的 p95 为 47.804 ms，已按冻结条件撤回。该范围内的 25 ms 时间缺口已用当前版本确认。[同源配对与范围](../LocalComparison/Review/software-deferred-material-250/result.md)

Release214 同源固定近景补齐了精确软件的 Transport 成本定位。实际 Gather 中位 39.612 ms，占 Transport 逐源中位比例 89.65%。观测最低 38.096 ms，高于 25 ms 总目标。世界缓存中位 4.274 ms，重建和其余各约 0.15 ms。软件预算优化集中在 Gather，内部各路径的耗时和正式预算继续验收。[父子时间戳与定位范围](../LocalComparison/Review/software-transport-cost-259/result.md)

软件精确三角 BVH 的同轴子树排序复用候选已撤回。受控 4,096 三角的首个位姿生成相同的完整布局，比较调用减少 16.47%，低于事前采用线。该结果属于 CPU 构建，完整位姿更新成本及软件 GPU 时间各自开放。[前后工作量及范围](../LocalComparison/Review/software-bvh-sort-reuse-262/result.md)

后续在同一固定近景试过将缓冲尺寸校验和三角求交准备移到每条射线的叶遍历前。实机 GI 合计中位为 45.212 ms，p95／p99 为 46.439／47.092 ms，三项均高于上述 Release196 窗口，进程 local 有限采样峰值为 549.637 MiB。已撤回候选，沿用 Release196 的实测与适用范围。

在同一 Release196 固定近景中，未赋值贴图绕过采样循环的候选测得 GI 合计中位 45.106 ms、p95／p99 46.046／46.537 ms。原窗口为 45.006／45.887／46.349 ms。未达到预定收益，候选未纳入产品。25 ms 软件时间缺口保持开放。[同输入裁决](../LocalComparison/Review/software-default-maps-238/decision.json)

Release195 固定近景的精确软件窗口已取得同源结果。960×540、半分辨率 GI、2 射线和 4 级滤波下，GI 三段合计 p95／p99 为 50.005／50.545 ms，超过 25 ms 的时间预算。进程 local／nonlocal 有限采样峰值为 576.637／281.664 MiB，local 在 1 GiB 限额内。该窗口说明软件后端的使用边界，锁定的 G0 基线为 DXR。[实测与范围](../LocalComparison/Review/software-budget-230/result.md)

Release167 统一三室在原热态近远路线实测两方向各 10 次完整 HLOD 接替。480 个接替和退休源帧的三段 GI 合计 p95／p99 为 16.522／17.345 ms，完整路线进程 local／nonlocal 有限采样峰值为 568.508／290.320 MiB，两项起始预算通过。冷入、启动和应用 Present 节奏单列。[路线、接替窗口及范围](../LocalComparison/Review/hot-hlod-budget-192/result.md)

Release182 同源观察包在同一设备完整预热后启动应用 Present 采集。PresentMon 报告丢失 2,029 个 ETW 事件，未生成 CSV。没有取得起始时间锚点，观察器在原路线开始前退出，路线上没有新的 GI、显存或帧率数据。沿用 Release167 的两项预算结论，热态接替的应用 Present 仍待验收。[原始采集日志](<I:/Unity test/Comparison/HotHlodPresent211/run/presentmon.log>) · [退出记录](<I:/Unity test/Comparison/HotHlodPresent211/setup/native-exit.json>)

Release215 使用工程已启用的 Unity 帧计时读取应用 Present，并沿用同一热态路线。两方向各十次完整接替，GI 合计 p95／p99 为 17.365／19.019 ms，进程 local／nonlocal 采样峰值为 570.941／288.313 MiB。与接替和退休窗口重叠的 510 个实测 Present 间隔 p95／p99 为 19.801／24.643 ms，最大 30.214 ms，通过该固定热窗的应用节奏条件。时间戳跨过路线终点，末源帧 1167 的逐帧返回仍缺失。逐帧资格和墙钟判定分别保存。[同窗结果与适用范围](../LocalComparison/Review/hot-hlod-unity-present-261/result.md)

已有 Release176 文件模式启动跟踪中，该 Player 的 DXGI 40／41 经本机清单确认是 Profile。PresentMon 2.6 离线读取该文件未产出 Present CSV，热态路线的文件采集源仍待确认。 [PresentMon 的 DXGI 事件定义](https://github.com/GameTechDev/PresentMon/blob/v2.6.0/PresentData/ETW/Microsoft_Windows_DXGI.h#L37-L40)

Release151 在原 F4 中室取得 512 个同源帧的三段 GI 和进程显存。GI 合计 p95／p99 为 15.936／16.169 ms，local／nonlocal 有限采样峰值为 566.191／286.441 MiB，达到 25 ms／1 GiB 两项起始预算。PresentMon 报告事件丢失且无 CSV，三项同窗仍证据不足。[机位、原始记录与范围](../LocalComparison/Review/three-room-middle-joint-170/result.md)

当前122同源的默认活动Skin已补一个同次普通Player窗口：24顶点／12三角／2骨、K+Space、960×540／半GI／2ray／filter4、实际DXR，计时与显存观察开启、反馈关闭。35.011秒内逐源三段合计中位／p95／p99为14.958／17.088／18.115ms；进程local／nonlocal有限采样峰值572.004／303.688MiB，满足25ms／1GiB。嵌套的30秒应用Present平均63.042Hz、间隔p95／p99／最大20.083／21.770／27.078ms，非显示FPS或逐源GI配对。它只补默认已预热Skin负载，不代表观察关闭、大模型、冷启动、画质或完整G5；初始等待和可选截图未交付均保留。[实际输入、源配对及CPU帧龄](../LocalComparison/Review/active-skin-cost-01/result.md)

Release119 的普通 Windows Player 以 960×540 启动，在 RTX 2080 Ti 上由入口步行到 F4 中室，中央门保持打开。相机停在 (0.310, 1.500, −5.975)，距 117 的 GI 预算机位约 0.055 个世界单位。窗口两端均为实际 DXR、完整的三个近景细节、168 张就绪卡，计时、反馈和显存采样均关闭。PresentMon 的 30 秒窗口中，应用呈交平均 **56.44 Hz**，间隔 p95／p99 为 **20.278／21.652 ms**，最长 **23.894 ms**。1,692 个有前序时间锚点的间隔全部在 30 FPS 对应的 33.33 ms 内。该窗口测量应用调用 Present 的节奏，显示器实际出帧、移动或冷入过程另计。[两端机位、采集参数及统计](../LocalComparison/Review/three-room-middle-present-119/result.json) · [原始 Present 间隔](../LocalComparison/Review/three-room-middle-present-119/present.csv)

Release117 普通三室在已有 F4 中室机位取得同窗结果。960×540、半分辨率 GI、2 射线、4 级滤波、实际 DXR，中央门全开，三个近景细节均可提交。逐源帧三段 GI 合计 p95／p99 为 16.170／16.729 ms，进程 local／nonlocal 有限采样峰值为 566.191／287.438 MiB。该机位满足 25 ms／1 GiB 起始预算。三室 Present 与冷入延迟单列。[实际预算窗口及原始计时](../LocalComparison/Review/three-room-middle-budget-117/result.md)

显式切到软件追踪后，摄像机原有的 RTAS 预约与硬件几何属性继续计入退休中的资源，直到最后读者完成并销毁。Release113 普通 Player 已在固定机位观察到这两项归零，再次选择 DXR 时重新取得额度。[三次端点的实际逻辑账目](../LocalComparison/Review/disabled-dxr-retirement-01/result.md)

Release215 补齐精确软件切回 DXR 的反向归还。实际 DXR 录制后，旧软件属性和 BVH 进入原退休流程。普通 Player 固定机位的逻辑计账为 80,864 B → 0 B → 80,864 B，分别对应精确软件、DXR 和精确软件重入。范围限已完成退休的逻辑额度。[实机端点](../LocalComparison/Review/inactive-software-geometry-260/result.md)

Release144 将准备或构建异常接入同一退休流程。故障相机保留软件回退，可能已录制的构建仍计入本帧额度。现有 C# 宿主模拟完成回调后，健康相机能够重新取得共享额度。[对照与范围](../LocalComparison/Review/rtas-failure-retirement-161/result.md)

Release205 在非复用的新 RTAS 计划自身超过共享内存上限时退休旧结构。旧预约随现有释放完成归还。暂时的共享余额竞争可等待并复用原结构。采用依据为实际 C# 后端与受控完成回调。[对照与范围](../LocalComparison/Review/shared-budget-retirement-244-245/result.md)

用户于2026-10-30取得当前基线后明确采用以下口径；后文历史记录中的“预算未定”保留其当时状态，以本节为准。

[G0本机基线锁定](ProductionPlan.md#g0已锁定的本机基线)已按环境、设备范围、目标／预算、场景／图及同源构建逐项关闭。这里的单个性能窗口仅提供其中一项依据，不替代G4／G5的完整负载验收。

普通统一示例的 M 门运动周期现有同窗结果。960×540、实际 DXR、2 条射线和 4 级滤波下，逐帧 GI 合计 p95 / p99 为 16.984 / 17.502 ms，进程 local / nonlocal 采样峰值为 568.816 / 289.695 MiB。本次运动窗口达到两项起始目标。[逐帧配对、门位移及显存](../LocalComparison/Review/door-motion-budget-01/result.md)

| 项目 | 已确认目标 | 当前Release93／filter4静止窗口 |
| --- | --- | --- |
| 分辨率／帧率方向 | 960×540／30FPS | 本窗口不测Present／显示FPS |
| 现有GI三个计时区间之和 | p95≤25ms | 19.298ms，满足门槛，余量约5.702ms |
| 本进程local有限采样峰值 | ≤1GiB（1024MiB） | 567.254MiB，满足此窗口门槛 |
| nonlocal | 单独报告，未设上限 | 289.691MiB |

当前表来自[93空回退遍历优化的唯一静止成本窗口](../LocalComparison/Review/exact-no-fallback-traversal-01/result.md)：GI合计中位18.393ms、p99 19.498ms、最大19.970ms，保留filter4／2ray／DXR。相较既有92配置窗口，中位下降5.528ms，超过两侧块变化最大1.082ms；这是本候选固定规则下的有限收益，不是总体统计或全部场景保证。默认反馈仍关闭；本次未测Present，不代表整应用GPU、瞬时显存峰值、运动／冷启动／长时负载或完整G0/G5放行。

此前[Release92采用filter4时的静止窗口](../LocalComparison/Review/four-pass-local-quality-01/result.md)为GI中位23.921ms、p95 24.562ms、local／nonlocal采样峰值565.441／289.691MiB。本次保持这组质量参数，仅消除全精确覆盖时无候选的回退遍历；不把回调节奏当FPS。

此前[Release90／filter3静止GI基线](../LocalComparison/Review/release90-dxr-baseline-01/result.md)为用户预算决策提供输入：GI三区间合计中位21.667ms、p95 22.643ms、p99 23.938ms，local／nonlocal采样峰值565.441／287.566MiB。它保留原来源；与当前独立filter4窗口之差不能直接当作单级滤波的精确增量成本。

当前入口由[首页](../README.md)维护；以下成本与画质依据来自[Release88](../LocalComparison/Review/two-ray-local-quality-01/result.md)，其有限采用[本机每像素2射线配置](../LocalComparison/Review/two-ray-local-quality-01/result.md)。当时Runtime为e352921，只将本机示例构建配置从1 ray改为2 ray，保留DXR偏好；通用默认值2未改。软件149／179／189／209四图有明确颗粒收益，但平均Y分别增加7.892%／8.244%／23.112%／22.425%（约8–23%），不代表颜色更准确，也不构成全过程无拖影或完整720帧通过。

成本依据来自独立的普通DXR 2 ray门运动窗口：960×540启动配置下，应用Present平均39.954935Hz，间隔p95为27.8123ms、p99为28.72332ms、最大30.7175ms；1197个间隔没有超过33.333ms。该有限窗口支持30FPS方向，采用后的成本余量较小；软件画质与DXR成本不是同一后端的联合质量／性能验收。Present不是显示FPS、GI专项时间或完整G5放行，不能据此填写正式GI／显存预算；CI接线仍按用户决定暂缓。

此前[Release87普通门运动窗口](../LocalComparison/Review/release87-motion-present-01/result.md)补齐已交付降噪使用条件的有限性能依据：以960×540窗口参数启动、默认DXR、计时与反馈关闭，应用Present平均70.85Hz，间隔p95／p99为16.73／17.80ms，全部2123个间隔小于33.33ms。它支持用户30FPS方向，但不是显示FPS、GI GPU时间或滤波增量开销；不据此填写GI／显存预算，也不与旧静止窗口相减归因。普通门循环包含保持阶段，未增加逐帧渲染尺寸或后端跟踪。该次窗口已收束，无追加矩阵。

## 普通运行入口与公开配置

Release98 下载包的 GPU 面板仍显示调整设置会刷新光照历史的旧提示。从 Release96 起，单独更改这些控制只重置计时与反馈状态，保留光照历史。Release99 已将修正后的面板提示整合进普通运行包。输入的毫秒数是当次运行的反馈目标，顶部表格的 25 ms 则用于比较固定观测窗口内的 GI p95。[设置隔离记录](../LocalComparison/Review/gpu-controls-preserve-history-01/result.md)

[Release81](<I:/Unity test/Comparison/Builds/LocalRelease81/Start-LocalRelease.cmd>)已接入现有计时／反馈能力，并完成一次普通使用，见[结果与范围](../LocalComparison/Review/gpu-budget-controls-01/result.md)。在原面板展开 **GPU time / update budget**：

- **Off** 关闭计时请求与反馈；**Measure only** 只观察已有GI区间，不改变静态更新配额。
- 在 **Target ms** 输入有限正数，点击 **Apply feedback** 才应用目标并启用反馈。目标默认留空，不提供预选生产预算；编辑文本本身不修改配置，非法输入保留旧设置。Off／Measure保留已有合法目标供以后使用。
- 输入框获得焦点时，数字导航、移动及其他样例快捷键暂停，避免输入目标时误切场景；已启动的门／形变动画继续。F1隐藏面板、Esc退出仍可用。
- 面板区分请求模式、已配置目标和上次相机诊断；显示已有提供器／状态、耗时观测、源帧／消费帧、实际反馈状态、缩放比例和patch／capture／brick有效配额。缺测显示不可用；历史值明确可能来自先前配置，不能当新样本或零成本。Recorder没有精确源帧时显示unknown。
- **Log ledger** 沿用原导出入口，额外记录请求的测量／反馈开关与目标，实际结果仍在`cameraGi`。Release84也可按 **F2** 调用同一功能，不自动开启测量。没有新计时或统计管线。

目标只约束既有控制器所观测的GI区间，不是整应用GPU时间、硬截止或G0／G5生产预算。最低更新量下仍超目标会明确显示，不自动降画质或修改资源尺寸。配置在Feature范围生效，各相机独立控制。监测开关、计时提供器偏好、反馈开关、目标毫秒和最低工作比例只刷新独立计时／控制器状态，不再单独撤销世界缓存、屏幕历史或HLOD就绪；完整计时配置仍区分新旧观测，其他设置继续走原传输失效规则。见[职责分离修复](../LocalComparison/Review/gpu-controls-preserve-history-01/result.md)。

自有运行入口可在Unity主线程、相机准备之前调用`TryConfigureGpuBudget(measureCost, feedback, targetMilliseconds)`；有限非负目标是基础要求，启用反馈另须严格大于零。非法输入返回false且三个字段均不变。`RequestedMeasureGpuCost`、`RequestedAdaptiveGpuBudget`、`RequestedTargetGpuMilliseconds`读取请求配置，`GetDiagnostics()`读取实际状态。默认设置保持关闭，不自动选择预算。

## 接收面发现的 CPU 准入

在 Renderer Data 的 Hybrid Lumen GI Feature 中，`receiverDiscoveryCpuBudgetMilliseconds` 为同一次相机图的接收面发现与重验设置累计经过时间额度。默认 0 沿用完整扫描。开启后，时间到达额度即停止后续来源检查。初次发现不完整时保留原生漫反射，身份重验不完整时保留当前 GI 并拒绝对象历史回执。

只计发现调用内部的 CPU 经过时间。已经开始的 Unity 枚举或来源调用运行到完成。此设置和网格指纹字节额度各自生效。[受控功能对照](../LocalComparison/Review/receiver-discovery-budget-159/result.md)

## 图卡录制的 CPU 准入

在 Renderer Data 的 Hybrid Lumen GI Feature 中，`surfaceCaptureRecordingCpuBudgetMilliseconds` 为一次相机渲染的图卡命令录制设置经过时间额度，默认 0。正数在第一张有效图卡开始录制时计时，额度达到后延后下一张完整图卡。卡数、draw 数和等待顺序继续生效。已发现的旧来源失效立即生效，实际录制完成后才提交恢复域。单卡和准备阶段各有自己的成本，实际 CPU、GPU 与显存窗口继续按原条件验收。[功能对照](../LocalComparison/Review/surface-capture-recording-204/result.md)

## 命中材质贴图录制的 CPU 准入

在 Renderer Data 的 Hybrid Lumen GI Feature 中，`materialTextureRecordingCpuBudgetMilliseconds` 设置单个相机材质批的贴图复制录制额度，默认 0 沿用原字节准入。开启后，从第一个通过共享字节准入的页或续传块开始计时。达到额度后延期后续复制，已开始的复制可以录完。字节不足的请求仍登记原有跨相机等待，时间延期保留原轮次。

稳定页继续按字节分块，动态页须在同一帧完成整页复制。延期的未初始化贴图以零句柄保留指定标志，按需取样时保持未知，其他已就绪贴图仍可参与各自查询。驻留就绪由完整上传、读者围栏和有效元数据回读决定。额度作用于复制命令录制的开始时机。单块录制可能越过额度，来源扫描、材质表录制和 GPU 执行另计。[定向行为对照](../Tests/StandaloneHitMaterialBatch/Program.cs.txt)

## 驱动层进程显存观察

Release77 的统一示例新增默认关闭的 **Memory: off/on** 按钮。开启后，现有面板和 **Log ledger** 的 `processVideoMemory` 字段给出 Unity 渲染适配器上的本进程 local/nonlocal 用量、操作系统预算与启用窗口内采样峰值。它通过可选 DX12 插件的独立 `HLGI_Memory_Query` 导出读取，不开启 GPU 计时或反馈，不改变光传输配置、更新配额、驻留或预留。

适配器由 Unity `ID3D12Device::GetAdapterLuid` 绑定；当前插件只支持单节点，因此读取 node 0。[DXGI QueryVideoMemoryInfo](https://learn.microsoft.com/en-us/windows/win32/api/dxgi1_4/nf-dxgi1_4-idxgiadapter3-queryvideomemoryinfo)返回本进程在该适配器的用量和 OS 预算，**不是 GI 独占、整机显存占用或物理显存容量**。local/nonlocal 分开报告，不相加为峰值。OS 预算会变化，也不代替尚待确定的产品预算。

`HybridLumenGIVideoMemory.Sample` 在统一示例的每次 LateUpdate 采样；同一实例同引擎帧不重复查询。`valid/status` 表示本次是否可用，`sampleFrame` 是最后成功帧，`attemptFrame` 是尝试帧；缺失/旧 DLL、设备丢失或查询失败均明确不可用，不把无效字段的零当作已测量零。`windowFirstFrame`、`samples/failedSamples` 描述采样窗口，两个 `peak*UsageBytes` 仅为窗口内成功 CPU 采样的最大值，可能错过采样之间或启用前的峰值。关闭、帧回退或设备身份变化会重新开始窗口。进程级数值在多个实例中可能重复，不能跨相机相加。此数据不控制任何分配器或预算。

这项能力已进入[普通 Release77](<I:/Unity test/Comparison/Builds/LocalRelease77/Start-LocalRelease.cmd>)：原生生产 DLL 与 Release/None Player 构建完成，普通窗口开启观察并使用既有日志入口后正常退出。该次记录的 local 当前/采样峰值为611,201,024 / 612,249,600 B（约582.9 / 583.9 MiB），nonlocal为303,734,784 B（约289.7 MiB）；对应 OS 预算分别22,504,538,112 / 16,334,618,624 B。设备为日志报告的RTX2080Ti，适配器LUID `0x000000000000F1DC`、deviceEpoch 1。原始字段见[既有ledger导出](<I:/Unity test/Comparison/Builds/LocalRelease77/memory-ledger.json>)，构建见[BuildReport摘要](<I:/Unity test/Comparison/Builds/LocalRelease77/build-result.json>)。只证明该次真实窗口中的功能接通；不代表整段运行峰值、设备恢复、长时压力、显存优化或G5放行。

## 已有 GPU 时间结果

**基线后的目标决定：**用户选择先以960×540／30 FPS为正式开发目标，整帧对应约33.33ms。该数值不是GI三个区间的可用额度；随后用户已确认上述25ms／1GiB起始口径，nonlocal另列。保留当前半分辨率GI作为开发起点，不把回调频率当作实际呈现FPS达标依据。

一次[普通Release83呈交采集](../LocalComparison/Review/release83-present-01/result.md)未生成CSV；没有有效Present／显示节奏数据，不代表零FPS，目标仍未据此验收。采集已收尾，未自动重复运行。

随后用户请求重启并确认场景正常显示，[单次应用Present采集](../LocalComparison/Review/release83-present-api-02/result.md)得到平均29.15Hz、间隔中位34.07ms／p95 38.58ms／p99 41.35ms；该普通窗口未达到30FPS。关闭了display tracking，因此仍无实际显示节奏结论。与UI/input关闭、另行计时的起始基线口径不同，不据此推导性能回退；原采集失败原因仍未知。

[普通Release84的DXR应用Present窗口](../LocalComparison/Review/release84-dxr-present-01/result.md)测得79.22Hz，间隔p95 14.33ms／p99 14.81ms，窗口内全部低于33.33ms。同进程F2日志在采集前后报告就绪DXR、计时和反馈关闭；只支持端点状态，不是逐帧后端证明。该有限结果支持当前30FPS方向，仍非实际显示FPS或G5通过；不据与旧83软件运行的差异宣称等画质加速。

[Release87](../LocalComparison/Review/short-history-spatial-filter-01/result.md)的短历史空间滤波改进继续保留在当前Release88，沿用Release85的DXR偏好，按4仍可回软件。87新增邻居moments读取的增量GPU成本尚未单独测量；上文87的1 ray门运动Present与88的2 ray窗口分别保留来源，不能归算为滤波增量成本。83／84静止结果也不改标为当前配置数据。当前起始预算以本页顶部用户决定为准，完整负载验收仍开放。

[已有DXR后端的单次同配置成本窗口](../LocalComparison/Review/release83-dxr-cost-01/result.md)实际512源帧均为DXR：GI三区间合计中位13.276ms、p95 14.334ms、p99 14.522ms；相对软件基线中位观察差−52.61%。进程local采样峰值560.941MiB、nonlocal287.691MiB。此处只提供现有后端取舍依据，没有普通显示FPS或等画质声明，也不自动改变默认和预算。

用户选择先完成本机基线，再确定正式目标。当前[Release83起始基线](../LocalComparison/Review/release83-local-baseline-01/result.md)已完成：960×540／480×270 GI、精确软件、RTX2080Ti DX12、反馈关闭。连续源窗口159–670的三个GI区间合计中位28.017ms、p95 31.186ms、p99 31.447ms；Transport中位27.802ms。目标相机回调平均28.982ms／34.505次每秒，p99 33.666ms；它不是实际Present FPS、纯CPU执行或整应用GPU时间。相同源窗口已有DXGI采样全部有效，进程local当前／采样峰值577.449MiB、nonlocal280.664MiB；非GI独占或瞬时／生命周期峰值。VSync=0、targetFrameRate=−1。只做了这一次测量配置运行，普通Release83保持不变；不据历史版本数值推导加速，也不自动扩矩阵。正式分辨率、FPS、GI-ms和显存上限留待据此决定，G0／G5尚未放行。

Release76采用面积光NEE屏幕端点早退，保留原命中/距离，跳过未被调用方消费的辐射求值。相同场景、设置和512源帧窗口中，每源帧三个GI范围之和的中位为30.742 ms、p95 31.581 ms、p99 31.819 ms；相对下文Release75基线，中位减少7.563 ms（19.7%），满足运行前固定的5%及64帧分块分离条件。只有这一个候选窗口；[完整对比和边界](../LocalComparison/Review/screen-endpoint-only-01/result.md)不宣称统计显著性、所有场景/DXR性能或生产达标。

2026-10-30已补当前[Release75源码的有限成本结果](../LocalComparison/Review/unified-release75-cost-01/result.json)。使用保存的统一场景、960×540普通backbuffer、480×270 GI与默认精确软件路径，另建Release/None测量配置，只开启既有NativeDX12计时、关闭反馈及输入/UI。普通Release75 EXE未替换。固定相机、灯光和几何，源帧159–670的完成记录完整；进程正常退出。没有采图、哈希或新GPU查询。

| 当前测量范围 | 中位 ms | 观察 p95 ms | 观察 p99 ms |
| --- | ---: | ---: | ---: |
| ReceiverCapture（含身份） | 0.153 | 0.164 | 0.170 |
| Transport | 38.088 | 39.239 | 39.544 |
| Composite | 0.058 | 0.063 | 0.066 |
| 每源帧三范围之和 | 38.305 | 39.451 | 39.749 |

合计先按源帧求和，再按`(N−1)×q`插值计算百分位；只是该静态窗口的描述值。成本集中于Transport，本轮不继续细分或重跑。起末账目原样保留：末端页驻留估算567,710 B、bundle估算139,484 B、精确软件几何80,864 B；它们不是可相加的总VRAM，也不支持长时无增长结论。计时排除CPU、部分范围外上传/RenderGraph工作和query resolve；不能推导应用FPS或生产尾延迟。用户已退出游戏，未另测全机竞争负载。生产目标尚待明确，未据此放行G5。

以下Development基线的源码、场景、后端和分辨率不同，保留其历史范围，不据两组数值比较优化收益。

当前实现是有静态上限的实验反馈控制器，不是 GPU 硬截止时间保证。e1aa6356 已在 Unity 6000.0.85f1 / RTX2080Ti 的 Development DX12 Player 中完成固定512源帧的 NativeDX12 只测量基线：三范围和中位19.853ms、描述性p95为21.483ms，反馈关闭且配额不变。见[原始成本结果](../LocalComparison/Review/gpu-cost-baseline-01/result.md)，Pro22已接受有限证据。它不验证反馈自适应效果、整应用/动态尾延迟或Release性能。历史离线控制器、托管桥和WARP报告保留各自来源，不能扩大为完整生产验收。

## 启用与测量范围

`measureGpuCost` 是默认关闭的独立观测开关。计时可在 `targetGpuMilliseconds=0` 时运行；只有原 `adaptiveGpuBudget` 加有效正数目标才启用反馈。只观测时 Scale 为 1，三项更新配额保持配置上限。关闭反馈的控制器仍沿用既有拒绝观测计数，该计数不表示原生样本无效。严格源帧统计使用原生桥的完整验证记录及独立失败计数，不能重复采集 `LastMilliseconds` 或用 Recorder 猜测源帧。参见 [原生完成记录契约](NativeGpuTiming.md)。

独立静态准入已接入当前渲染路径：

| 设置 | 默认值与行为 |
| --- | --- |
| 对象 SDF 图集的 Feature 入口 | 每引擎帧跨相机共享 262,144 个 RFloat 体素（1 MiB）的 `SetData` 尝试额度。最早等待的整卷优先，独立 `Prepare` 按自身额度计账。[驻留与准入](SdfAtlasResidency.md) |
| `objectSdfUploadCpuBudgetMilliseconds` | 0 ms，默认关闭。启用时跨相机累计整卷读入与上传调用的 CPU 时间。同帧可收紧，已启动的上传可超出额度，下一整卷延期并保留等待顺位。[驻留与准入](SdfAtlasResidency.md) |
| `materialTextureUploadMiBPerFrame` | 16 MiB，全相机共享实际复制字节。稳定大页跨帧续传，完整复制并回读后就绪。动态 RT 要求同帧完整复制。后置相机收紧当帧上限时，已录字节继续计账，当前装不下的等待让出额度，可按原资格参加后续帧。[定向对照](../LocalComparison/Review/texture-quota-tightening-254/result.md) |
| `materialTextureRecordingCpuBudgetMilliseconds` | 0 ms，默认关闭。每相机材质批按已录制复制的经过时间延后下一页或续传块。 |
| `hardwareMaterialBudgetMiB` | 256 MiB，材质arena包含当前、待上传、读者持有及退休/隔离分配；复用稳定页，局部替换变化页。 |
| `softwareGeometryBudgetMiB` | 128 MiB，同一 Feature 内按相机合计精确软件属性和 BVH。状态重建后仍计入待释放的旧分配。按准备好的三角数在 CPU 构建前检查 BVH 额度，等待时使用现有回退，释放后恢复。[跨状态计账](../LocalComparison/Review/camera-software-geometry-budget-168/result.md) · [构建前准入](../LocalComparison/Review/software-bvh-preflight-258/result.md) |
| `hardwareGeometryBudgetMiB` | 128 MiB，同一 Feature 内按相机计入硬件精确属性。相机状态重建后仍计入待释放的旧分配，直到安全释放。RTAS 使用独立的共享预留。[定向对照](../LocalComparison/Review/camera-dxr-attribute-budget-167/result.md) |
| `rtasMemoryBudgetMiB` | 256 MiB，跨相机RTAS预留；按64 KiB + 192 B/triangle + 1024 B/instance估算，后续 `GetSize` 观测只提高高水位；退休仍计账。估算不是驱动上界。 |
| `rtasBuildsPerFrame` | 默认每引擎帧最多 4 次实际构建。共享额度为零时，确需构建或更新位姿的计划在准备前置门拒绝。录制处理准备后的同帧收紧。已建且仍匹配的 RTAS 可复用。[定向对照](../LocalComparison/Review/rtas-zero-build-quota-206/result.md) |
| `rtasTriangleWorkPerFrame` / `rtasInstanceWorkPerFrame` | 250,000三角 / 4,096实例；包含完整 dirty 构建／refit 工作。能够在当前有效配置下取得所需积分的最老活跃任务优先。停止补充某项积分后仍可消费已有余额，超出余额的已知请求本帧让出队首。帧末收紧的其他相机额度可在下一帧恢复，原等待顺序继续有效。[余额及跨帧票龄对照](../LocalComparison/Review/rtas-nonreplenishing-210/result.md) |
| `rtasTriangleBurstCapacity` / `rtasInstanceBurstCapacity` | 1,000,000 三角 / 16,384 实例。需要新构建或更新位姿的 RTAS 在超过突发上限时于几何准备阶段回退，录制仍复核同一上限。当前几何和位姿的已建 RTAS 可继续使用。[定向对照](../LocalComparison/Review/rtas-burst-preflight-178/result.md) |

等待中的 RTAS 需求在实际请求帧和按该后端最近准备间隔预计的返回帧参与队首竞争。首次请求沿用下一帧，缺席请求在预计帧结束后过期。已有 GPU 资源在安全退休并完成销毁后归还预留。[固定周期构建对照](../LocalComparison/Review/periodic-rtas-build-271/result.md)

命中材质批次先从等待最久、能在当前剩余额度内推进的贴图来源开始，再按请求顺序循环。复制尝试计入额度后，该来源排到等待序列末尾。动态 RenderTexture 需在一帧内完整复制当前内容，延期时命中材质保持 unknown。多个相机读取同一动态来源时，不可复用的复制分别排队，录制复制只消费该相机的保留。[同批次定向回归](../Tests/StandaloneHitMaterialBatch/Program.cs.txt) · [同源动态贴图对照](../LocalComparison/Review/shared-dynamic-upload-208/result.md)

后置批次因前面已经计入的复制字节而无法推进时，可以在下一帧为最早的等待来源保留一次推进所需的最小额度。其他批次可以使用余量。旧读者在飞时，后续仍在录制的同源需求可以续等，页面继续走原栅栏与回读。首次和连续调用沿用下一帧。若同一消费者实际调用的最近间隔更长，只在下一预计返回帧参与预留，缺席后到期归还额度。受控双批次对照覆盖固定顺序下的等待、完成和撤回。单次双 Base DX12 Editor 观察已补齐实际复制、回读及同页复用。实际多相机画面和 GPU 成本继续验收。[跨批次定向回归](../Tests/StandaloneHitMaterialBatch/Program.cs.txt) · [原生观察](../LocalComparison/Review/native-camera-texture-turn-182/result.md) · [周期相机对照](../LocalComparison/Review/periodic-material-upload-273/result.md)

资源页组件另设IO/并发/上传准入/驻留额度，形变组件另设捕获顶点/后台作业/快照上传额度，以及默认关闭的[主线程捕获经过时间准入](DeformedGeometry.md)。该时间门只延后下一份捕获，不抢占单份BakeMesh，不是GPU反馈或完整CPU硬预算。诊断中的全局纹理/RTAS计数可能在多个相机记录中重复出现，不应相加。实际分配粒度、驱动scratch与系统峰值必须在目标设备测量；静态数量配额与下方滞后时间反馈相互补充。

启用反馈或只测量且 `preferNativeGpuTiming=true` 时，优先使用可选的 [原生 DX12 时间戳后端](NativeGpuTiming.md)：它返回提交身份并按实际 fence 完成读取和回收。源码包不自动安装 DLL；未安装/不支持/不可用时回退下面描述的 Recorder 路径。原生固定池有 128 个跨相机共享的可循环提交槽，不受 Recorder 的 32 个生命周期通道限制；已有上述单相机实体 GPU 有限基线，其他生产条件仍待验收。

`adaptiveGpuBudget` 和 `measureGpuCost` 默认关闭，`targetGpuMilliseconds` 默认零；两种用途均关闭时不探测或加载原生计时 DLL。先在目标设备记录基线，再设置正数反馈目标，各相机维护独立反馈状态。零目标、尚无有效样本或两个提供器均不可用时保留静态更新上限；已进入反馈后的短暂缺测保留最后配额，距最后有效观测达到 16 个引擎帧后恢复静态上限。原生 ring 暂满不改变其可用状态，也不为该帧切换到 Recorder。

两个提供器都覆盖接收材质捕获、可选身份四个pass、世界更新/追踪/降噪及最终合成。原生ABI1仍使用三个区间：第一个从材质捕获开始，到身份解析结束；关闭身份时仍在材质捕获末尾结束。其余两个区间为transport和composite，硬件`RecordBuild`在transport内。Recorder采用每pass局部配对的`CustomSampler`：身份关闭时三个，开启时七个，不让Begin/End跨越RenderGraph pass。替换原生漫反射的额外目标仍在材质捕获pass中。

激活范围的GPU时间之和是反馈信号。它不包含CPU准备、范围外立即上传、范围外目标设置/清除、末尾原生resolve pass和整个RenderGraph的附加开销，也不是应用总GPU帧时间。原生第一段是完整捕获链的队列区间，可能包含阶段间屏障、等待或穿插工作；Recorder则累加各pass局部区间，两者不能当作完全相同的隔离shader成本。提供器切换会重置反馈。驱动分配、跨队列重叠及BLAS/TLAS峰值内存仍需外部profiler，不使用CPU录制耗时或整帧FrameTimingManager值替代这些观测。

integration-12归档没有测量身份四个pass；历史integration-13补接了这部分命令范围，当时封存源码通过56阶段统一离线回归，不能作为当前工作区的通过结论，实际Unity计时仍待验收。Clear显式读取captureDepth建立材质捕获→身份清零依赖；Candidates与identity输出建立后续顺序。完整建图后才启用身份计时，部分建图、晚回调、乱序或缺阶段会撤销反馈。实际身份功能因预算或能力变化而开关时，即使Settings和尺寸相同，也会重置计时代次及控制器。计时API异常只撤销反馈，不中断GI命令；真实GI命令异常仍按渲染失败处理。

## 原生提交归属与回收

每次预留返回不复用的正数 63 位 ID，绑定 owner、配置代次、设备代次和源帧；plugin event 的 `IntPtr` 只编码该 ID，不指向托管或临时 payload。完整六个 timestamp 之后，合成的依赖链末尾追加独立 Unsafe resolve pass，避免在 D3D12 native render pass 内调用 `ResolveQueryData`。原生端等实际 fence 完成才发布结果或回收已使用的 query 槽；取消不会提前释放 GPU 仍引用的槽。

托管端每相机最多保留 32 个 ticket，只接纳身份、频率、时间戳顺序与年龄均有效的最新结果；超过 32 个引擎帧的结果会被取消，已消费结果不能再参与反馈。提供器或原生设备代次变化会重置控制器，ring 暂满则只是缺测。原生池逻辑 readback 为 6,144 字节，另有 768 项 query heap、驱动开销与有界的异常退休资源；具体 ABI、构建、安装和失败路径见 [NativeGpuTiming.md](NativeGpuTiming.md)。

## Recorder 回退的可用性与证据边界

Unity 的 [Recorder 文档](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Profiling.Recorder.html)说明 GPU 数据存在三帧延迟。实现先检查 [supportsGpuRecorder](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/SystemInfo-supportsGpuRecorder.html)，再要求有效 sampler/recorder、每个范围恰好一个正时长 GPU block；GPU count 为零、负时长或重复 block 都不作为零成本。

不同相机使用独立标记。只有同代次连续八个已完整录制的帧之后才读取延迟观测；每引擎帧最多读取一次。跳帧、重复渲染、未闭合范围、配置/尺寸/实际后端变化和生命周期失效会清空关联历史。每个 pass 持有相同的帧 token，旧 token 不能发布新历史；失效后仍会关闭已经打开的 marker。这里的“完整”是 CPU 录制完整，不是 GPU 完成证明。

公开 Recorder 接口没有 query ID，也不提供多个范围的原子快照。`frame - 3` 只是按文档建立的预期关联，不能证明这些值来自同一次硬件提交；重复出现的相同时长也不能据此判为新样本或旧样本。因此该路径仅用于受硬上限约束的滞后调节，不能据它声称严格时间归属、满足预算或 GPU fence 已完成。

Unity 文档中的 Player 限制与当前托管源码的 availability 标志不完全一致。固定版本源码 `1c2d7db69c060103b6dc087af725442d1efaef9c` 中的 CustomSampler/Recorder 和固定 URP Graphics `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53` 已作为接口研究依据；实际 native 行为仍须实机核验。本实现直接调用 CommandBuffer/RasterCommandBuffer 的 CustomSampler 重载，避免依赖在非 Development Player 中被剔除的 ProfilingScope。不能据托管源码承诺所有 Release Player 都能取得数据。

Sampler没有公开销毁接口。Recorder最多使用32个生命周期通道，每通道最多七个固定名称，共224个；只创建和启用当前必需的范围，可选marker创建失败不阻断随后关闭身份的基础模式。通道不在无完成凭据时复用；耗尽报告`ChannelLimitReached`并回到静态预算，不停止GI。原生timestamp后端提供独立可回收query池，未改变Recorder的限制，也未完成Unity长期运行验收。

`BeginSample`或`EndSample`命令抛出异常时，无法证明native marker是否已录制或闭合。`RejectCommandRecording()`会锁存`CommandRecordingFailure`，永久停用该实例通道的反馈；普通Invalidate、切换范围或关闭重开均不恢复它，也不回收该通道。已开始marker的同pass finally仍清理CPU配对。普通旧回调不影响新帧；若旧marker的实际结束命令失败，则同一通道仍须停用，但不借旧帧回调重置新帧控制器。GI继续使用静态工作上限。

## 控制规则

控制器只改变以下每帧工作量，并保留用户配置的绝对上限：

| 配额 | 最低更新量 | 保持不变的相关资源 |
| --- | --- | --- |
| cache patches | `max(1, ceil(configured × minimumGpuWorkFraction))` | patch 网格、缓存容量、每 patch 射线数 |
| surface captures | 同上 | 卡池、tile 分辨率和原子绘制上限 |
| global SDF bricks | 启用时同上；关闭时零 | clipmap 层数、尺寸和体素精度 |

最低比例默认 0.125，允许范围 0.01–1。控制使用权重 0.2 的指数平滑与 ±10% 死区，至少八个有效观测后开始调整，每次调整至少间隔 16 帧。连续比例每次最多下降 25% 或上升 10%；整数配额向上取整，因此小配额可能一次改变一个工作项。配置变化或显式 reset 会清空平滑值并恢复静态配额。

原生结果额外携带真实预留提交的 source frame：控制器拒绝重复、倒退、未来、配置代次之前和最后一次配额调整之前的测量，避免旧工作量的迟到结果驱动新工作量继续降额。Recorder 没有这种来源证明，传入未知标志而不是伪造 `frame - 3` 为真实身份；仍依靠保守冷却和硬配额上限。

表面 draw 上限不随比例下降：真实 chart 通常需要两次 draw，六面 fallback 的单卡需要子网格数加一，随意缩减该上限会让整个复杂对象永久无法捕获。最低正数更新配额保留已有最旧项调度的机会，但不保证所有对象都能装进既有静态容量或绘制上限。

不改 `Settings`，不随反馈推进 lighting epoch，也不降低 cache/gather rays 或 filter iterations。即使工作量下降，全池缓存复制/失效、Global SDF 无效页上传及发光提议清表仍执行。配置、真实后端切换等失效若发生于 CPU 准备之后，不重跑准备：保留本帧已排的有界工作，撤销其计时并在下一帧恢复静态配额。

## 诊断与验收

`Log Runtime Diagnostics` 额外输出状态、最新观测是否有效、历史毫秒值及其消费帧、平滑值、工作比例、三个有效配额和计数。`gpuTimingProvider` 区分 `NativeDX12` 与 `Recorder`；原生路径还提供 `nativeGpuTimingStatus`、`nativeGpuPendingSubmissions` 和 `nativeGpuMeasuredSourceFrame`。`gpuLastObservationConsumedFrame` 是 CPU 读取该观测的引擎帧，不是硬件 query 的来源帧；`gpuLastObservedMilliseconds` 可能保留失效之前的历史值，应同时查看有效标志和状态。原生 source frame 来自身份校验后的结果，Recorder 没有同等来源证明。

达到最低工作量并经过最后调整后的十一帧等待窗口，仍连续三个有效观测的平滑值高于死区时，`gpuMinimumWorkOverBudget` 标记持续压力。若初始整数配额已经等于最低值，则无需等待一次不存在的调整。该标志不要求三个原始时长都超标，不证明预算永远不可达，也不承诺已经控制住固定成本。不得通过跳过失效维护或伪报时长来消除该标记。

朋友端需要分别在 Editor、Development Player、Release Player 对照独立 GPU profiler，验证原生提交/fence 生命周期，以及回退 Recorder 的 capability 和 marker block 数。测试 native render pass 开/关、静态/动态负载、极小目标、两个相机、长期相机创建销毁、停用恢复、同帧重复相机、配置/后端切换、原生设备重建、ring 饱和、缺测和 Recorder 生命周期通道耗尽。记录配额变化、实际 GPU p95/p99、画面收敛和捕获积压。源码/录制测试和 WARP 软件适配器检查不能替代这些验收，也尚未关闭 ProductionPlan 的 GPU 预算关卡。
