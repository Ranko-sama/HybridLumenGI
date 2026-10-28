# 完整原计划推进表

更新：2026-10-28。本表按 OriginalDevelopmentPlan.md 的十项工作流区分实现、当前来源实测和生产验收。旧版报告保留来源，不重新标为当前版本通过。当前先处理已证实的阻断和可复现缺陷，再补缺失验收；不因新增局部测试而重跑无关矩阵。

| 工作流 | 已有实现/审查依据 | 当前版本新增或复用证据的边界 | 剩余验收与下一问题 |
| --- | --- | --- | --- |
| 1 社区源码审查 | CommunitySourceAudit 的固定 commit、文件和许可证记录 | 本轮未更换外部设计或复制代码，复用历史审查 | 新引入设计时只补相关模块来源；不重复全库阅读 |
| 2 光传输链路 | DirectLighting、EmissiveSampling、ProductionPlan 方程和绑定 | denoise-02 修复 HDR 二阶矩；1b8e751统一失败cache输出；iteration10理想算子逐轮能量参考通过Pro有限复核 | 真实场景光源变更、匹配单位的色墙/黑室/金属参考和整图能量 |
| 3 世界空间表面缓存 | 真实三角 charts、atlas、版本和预算捕获 | candidate-16 有实际 HDR/UV/材质接线证据，属历史来源 | 当前凹面/薄层/接缝覆盖、规模与捕获成本 |
| 4 几何与近远场 | 实例 BVH、global SDF、dirty bricks、形变快照 | 历史精确/SDF运行；未重新验收当前整体 | 薄壁正确性、非闭合与形变边界、近远场连续性 |
| 5 局部失效与多反弹 | 变更域、代次、双缓冲、预算和年龄调度 | iteration10执行实际cache update/lookup/commit/change，两节点256开+256关独立参考通过；不代表真实帧响应 | 真实灯光检测、调度与缓存/画面链；运动/删除后的残留和收敛 |
| 6 采样与降噪 | 混合 PDF/MIS、运动历史与滤波 | denoise-02 F1/F2与denoise-03局部短历史过渡已通过Pro复核；单个真实门事件覆盖1230像素 | 已知第2/3历史噪声代价；持续reactive/历史上限2或3仍待画质验收；R1只有匹配信号敏感性证据；绝对拖影未验收 |
| 7 URP Lit / DXR | 源 UV/多材质、alpha/Cull、native diffuse规则 | 3088d41同构建软件/DXR各120帧证据获Pro20/21有限接受；iteration25单槽MPB自动发现、实际上传、目标历史重建及一条实际正权重消费链已获Pro25有限接受 | 槽1屏幕历史仍未覆盖；形变、全场景材质一致性、软件差异解释与动态质量 |
| 8 流式与预算 | 异步AssetBundle、完整组准入、HLOD原子切换、独立额度；默认关闭的独立计时/完成记录导出 | e1aa6356实体DXR固定512源帧NativeDX12基线完整，目标0/反馈关闭且配额256/24/16不变；Transport中位19.694ms，三范围和19.853ms；Pro22已接受有限证据 | 23轮已确定Gather主导，唯一复用候选收益未超过波动而撤回；转向具体材质/形变事件。在途异常/取消/冷暖/高速移动/长时与总VRAM仍开放 |
| 9 可重复回归 | 离线入口、固定场景、HDR和来源清单 | denoise-03有限场景；gather真实消费/偏移可见性；失败cache反例；理想能量及实际关灯链；新增固定源帧GPU成本基线；均保留来源和失败记录 | 按具体热点或动态/材质反例增加最小验证；不重复已完成关灯链、Player冒烟或同类函数夹具 |
| 10 工程验收 | Unity环境、当前Player构建与来源清单 | e1aa6356新计时构建110源码/284产物，唯一688帧实体DXR运行与正常退出通过；3088d41软件/DXR图像冒烟保留原来源 | 固定窗口GI三范围p95/p99已有有限数据；整应用/动态/Release尾延迟、参考图/动态质量、峰值VRAM、长时和G0–G5支持范围仍开放 |

实际环境已知：Unity6000.0.85f1 / URP17.0.4 / Windows DX12 / RTX2080Ti。目标FPS、GI GPU预算和总显存验收阈值尚未确定，不伪造。可继续正确性开发和测量，不能据此宣布生产完成。朋友交付不再是依赖或停点。

resource-shutdown-01b已由Pro批准：先关准入/撤销owner，再按真实fence清理；自然Play退出两次、重入一次和直接Editor退出通过，36+21张旧域票据有逐项完成证据。实机后的取消任务异常保留修正另有actual-source回归，未冒充当前全部字节重新原生执行。Player、禁用域重载、在途worker/readback、Recorded/Quarantined和设备故障仍开放。见ReviewBrief-ResourceShutdown01b.md。

下一包thin-wall-transport-01：精确软件路径、静态薄壁probe；最多正常配置/关闭反馈诊断/单灯已知可见性三类，各至多120帧。固定观察点与阶段输入，只在明确反例上局部修复；不压暗、不改sigma、不把开放边界暗侧全零当物理真值。

thin-wall-transport-01 v3更新：A的120帧与135份阶段数据完成，独立接收面/深度/就绪门槛通过；B/C尚未运行。退出仍报告owned1和29条Persistent分配，构成新的资源生命周期问题，当前整体结果失败，不能用exit0或采集成功覆盖它。已恢复源字节与A设置，并将证据返回Pro规划最小修复。前一资源包只保留其短运行有限验收。详见ReviewBrief-ThinWallTransport01-Retry.md。

iteration7后续：resource01c以actual-source确定复现退出进度竞态；最小谓词修复后相同输入与相关回归通过，唯一12帧原生退出的21张票据完整销毁，计账归零。Pro已批准，源码修复本地提交3c12a87。随后B/C各120帧完成，C固定遮挡/无遮挡与双精度参考通过，两侧完整退出日志无同类故障；Pro批准保留有限诊断证据。A复用且退出失败记录保留；此结果不覆盖实际cache tap/anchor连接或整图物理正确性。见ReviewBrief-ResourceShutdown01c.md与ReviewBrief-ThinWallTransport01-Completed.md。

iteration8的gather-cache-visibility-01已获Pro批准并提交507e52d：单一A配置120帧、四像素与九时点；225次真实偏移可见性查询匹配独立三角参考。17项无偏移物理连接差异处于边界歧义区，不宣称漏光改善或整图正确。实际消费与引导访问已区分。

iteration9的cache-failed-result-01已获Pro批准并提交1b8e751：实际tiny-support反例证实false返回残留结构被world消费；仅清零失败输出，五个其他控制字节不变、直接光/发光/confidence保留。六个受影响完整入口通过固定DXC编译，不作实体DXR验收。

iteration10的cache-energy-decay-reference-01已获同一Pro批准本地提交：唯一512轮理想两节点批次通过运行前冻结的双精度有限轮参考及独立稳态界，最大绝对误差约2.70e-7。实际Jacobi读写、反射率位置、照明变更缩短历史和关灯残留均符合合同；Astra独立复核无阻断。无Runtime变更，不能替代真实场景的灯光检测、atlas、预算调度和gather。下一包scene-lightoff-chain-01沿用单点光C场景，仅一次360逻辑帧，120帧关闭真实灯光。完整G0–G5仍开放。

iteration11已保存为失败检查点3241b50：真实Unity首帧观察器重复映射错误，未到119/120帧，0截图；另有7张未提交票据和原生资源失败。原合同与数据保留失败状态。iteration12完成离线唯一patch/别名修正，尚未Unity执行；一次基线归因确定正常Feature.Dispose直接拆散pass的所有权缺口。限定修复统一detach+StopAdmission，专用完整pass父项等待真实idle/fence，子项仍各自完成。actual-source测试通过；唯一同触发原生确认的9张票据均完整销毁，64608逻辑子字节回收，原8个GI buffer泄漏不再出现。引擎1MiB scratch告警仍未归因，冻结整体资源验收保持false；关灯链仍未完成、无新截图。Astra已复核有限结论，正在等实际GPT-6 Pro第12轮审查。工作区候选与已恢复的Unity部署暂时不同，不能沿用上表历史“部署一致”描述为当前状态。完整原计划与生产关卡不变。

Pro12正式批准局部修复及别名观察器本地提交，限定关闭上述GI owner缺口；scratch仍开放。所依赖的本地URP/Core17.0.4最小函数片段、版本、哈希与许可证已归档。下一包scene-lightoff-chain-02获准一个原生进程≤360帧，先部署新提交基线，再验证真实关灯事件链；不重跑提前退出矩阵。完整回复见early-exit-retirement-01/gpt6-pro-review-and-next-plan.txt。

iteration12已提交c50ec78。iteration13的scene-lightoff-chain-02实际Unity完成360目标帧、9组HDR/EXR/PNG、0观察器错误、native0；本次完整扫描无资源故障，96源码和8资产恢复到新基线。真实119就绪门槛和120关灯已执行，34次最终cache消费（20次连到选定patch）与预算/写入/屏幕阶段有对应记录。冻结分析仅因logical1的额外首次灯发现而保持失败：0/1均GIframe0、tick1、previousCount0、旧cache零，全部owner revision增加一次，灯本身未变；具体重建caller未观测，不能断言产品bug或无害。保留原FAIL并交Pro13审查生命周期合同。HDR末帧仍有非零残留，PNG接近黑色不是物理收敛证明；历史异常退出scratch本轮未复现但未归因。完整原计划/Player/DXR/画质性能长时关卡仍开放。详见ReviewBrief-SceneLightoffChain02.md。

Pro13已批准按冻结失败状态本地提交完整场景证据。下一包仅离线：基于组合状态证据进行生命周期限定，保留原FAIL；然后利用实际720patch记录拆解服务等待、自身历史与新估计输入，解释真实响应。无需新Unity/GPU。归因后优先独立真实场景HDR参考，不扩大等价夹具或启动测试。

iteration14–17：已保留实际关灯链的有限缓存响应分解；旧场景缺少六份材质的历史来源字节，因此没有追认旧图物理参考。新配对来源的前两次尝试分别在项目清单路径解析、归档长路径处于Play前失败，原始失败均保留；最小工具修复已获Pro批准并本地提交。

iteration18：首次完成新来源配对的真实120帧、2组PNG/HDR、0采集错误、native0，来源冻结与恢复通过；独立六点来源对应及48批共196608路径积分实际完成，随后比较完成。严格统计/尾项界过宽，referenceEstimateQualified与comparisonConclusive保持false，无追加采样。此前一次JSON序列化失败发生在积分前，0条路径；原脚本、日志与开始标记保留，修复仅两处输出标量转换。中央墙/方块的直接光参考为零，间接光与最终滤波结果微弱但非零；不能把近黑截图当成正确亮度或降噪故障的证明。详见scene-radiometry-matched-baseline-03/result.md。Astra无阻断，实际GPT6Pro18已批准有限证据提交；下一包为真实滤波与上采样贡献归因。Runtime未改，整个原计划及Player/DXR/动态质量/性能/显存/长时验收继续开放。

iteration23：两个固定64源帧DXR窗口均完成，Gather占主要成本；有限等价且编译提升成立的唯一接收导数复用候选只省0.027856ms，未超过块间波动，已撤回并验证仓库/部署110源码恢复。保留原始数据、候选patch与有限结论，不追加样本、不继续无界热点拆分。必要构建验证独占Windows导入标志，22轮历史偏差不改写。实际Pro23已批准有限证据提交与撤回；下一包material-mpb-propagation-01检验单一材质槽MPB事件的自动发现、缓存消费和历史响应，完整生产关卡仍开放。

iteration24：唯一Unity构建成功并恢复部署；唯一DXR运行在logical158停止，159帧、12完整GPU数据、0事件、0截图、native1。测试观察器误把identity.z（三角形编号+1）当成对象行号；未执行的CopySamples分支也有对应索引错误。产品现有temporal通过candidate.x正确定位对象，尚无产品反例。离线修正解释后槽0有139身份像素及66内部像素，槽1仍为0，不能只修观察器就沿用原三屏幕控制点合同重跑。原失败、初版错误分析及Astra事前gate均保留；退出资源计账最终归零。交实际Pro决定下一最小工作包，不自行改视角、换目标或追加测试。详见ReviewBrief-MaterialMpbPropagation01.md。

实际Pro24已批准失败检查点提交，并明确另开material-mpb-propagation-02：修正观察器ABI、用已存数据和少量不等行号/primitive值验证语义，再保留槽0与Green wall两个可见GPU点；槽1只做CPU来源/上传/card对照，屏幕历史保持未覆盖。新合同限一次构建、一次256帧运行，不预授权第二次Player或Runtime修改。原01失败不回填，完整原计划继续。

iteration25：02唯一新构建与DXR Player完成256帧，真实159准入、160普通MPB事件、92完整GPU数据、4组HDR/PNG、native0、退出计账归零。映射与三CPU角色来源/上传核对通过；目标key30→39、reusable变0，已知当前测量历史count32→1，随后恢复累积至32。172帧Green-wall选定像素的一条原始winning proxy路径以正权重消费了变更后的目标槽0材质；其余零权重评估不计消费。槽1屏幕历史保持未覆盖，完整生产验收仍false；Runtime未改，旧01失败不回填。泛用mixed-motion probe标签保留原样，不冒充原混合事件序列完成。正在交Astra与实际Pro25复审并选择下一项实质开发。详见ReviewBrief-MaterialMpbPropagation02.md。

实际Pro25已批准该有限证据提交并结束材质包；172帧首个被记录的正贡献不能解释为12帧传播时延。下一包deformation-snapshot-propagation-01验证现有可读网格的一次正常更新，分开记录源编辑、CPU完整快照发布和实际GPU消费者；保留预算、一次构建/一次256帧运行，不自动追加。PublishedFrame为捕获帧，不能当成实际发布时点。完整原计划与未覆盖验收继续。

iteration26：唯一构建和DXR Player完成256帧、70完整数据、4组HDR/PNG、160普通RequestCapture形变、native0及退出归零。可见网格GeometryGeneration7→39，材质代次8不变，160目标历史重建；新mesh/SDF/charts在logical161/engine162完整发布，原PublishedFrame161为捕获引擎帧。实际绑定instance/12个三角形读回匹配新快照，proxy/surface/backend几何revision22→23；历史随后恢复。选定原始射线没有命中目标，实际新RTAS命中及被改变三角命中保持未覆盖，不补射线或重跑。Runtime未改，完整生产验收仍false。详见ReviewBrief-DeformationSnapshotPropagation01.md。

实际Pro26已批准有限证据提交，并独立读取执行输出137–142。下一项asset-page-inflight-withdrawal-01使用既有detail组完整页闭包，验证真实LoadAssetAsync尚未完成时通过公共API撤回需求后的操作保留、迟到完成和依赖释放；不绑定renderer或取得消费lease，不重复历史runtime-candidate-16已经执行的正常流式/HLOD/双相机矩阵。限一次构建/一次可见Player、256个实际pump tick，不足覆盖不自动重跑。原计划其余关卡继续。

iteration27：既有6页/4直接ID冻结后，唯一真实构建通过、7处临时接线恢复、110产品源码一致。唯一可见DX12 Player共12个实际pump tick/188条记录，tick2真实AssetBundleRequest未完成时普通RemoveRequests撤回，tick3原Poll收到迟到asset，tick5原UnloadAsync完成及Resources.UnloadAsset返回后才归还4190/4304字节预留，连续8tick全空、native0。仅首个无依赖geometry页加载，父子依赖释放顺序明确未覆盖，不补运行；没有消费lease、GPU退休/HLOD/画质/性能验收，Runtime未改，完整生产仍false。交Astra与实际Pro27复审并继续原计划。详见ReviewBrief-AssetPageInflightWithdrawal01.md。

实际Pro27已批准本轮有限证据提交。下一包snapshot-publication-cleanup-01转向已定位的条件性产品缺口：当前有效形变任务在发布异常后若Destroy又失败，提前RemoveAt/Dispose使私有快照失去可追踪owner。先在既有实际C#组件适配测试中组合FailSet/FailDestroy复现，再仅修任务终态/取消源/失败保留责任；无新Unity/Player/GPU运行，不扩撤回或形变矩阵。旧原生结果不追认为候选新源码通过。

iteration28：既有实际源码适配测试确定复现双失败，基线清理异常穿透、Job丢失、154368字节预留保留但FailedCleanupCount0，并跳过另一已完成任务。最小候选仅后移成功终态的CTS/Job清理，失败时保留原Job/snapshot/预留、设置cleanupFailed并记录两个异常，继续其他任务；相同输入通过，后续请求/context/idle/关闭/禁用/新会话无重复销毁或已DisposeCTS异常，最终仅38592字节失败预留。既有完整相关守卫通过。0新Unity/Player/GPU运行；仓库候选比上次实际部署多一个Runtime文件改动，旧原生证据不升级。待Astra与实际Pro28复核后提交。详见ReviewBrief-SnapshotPublicationCleanup01.md。

实际Pro28已读取执行输出149–151并批准局部修复提交，Astra无阻断。下一包light-change-compaction-01处理按下标比较灯表导致的局部失效误报：关闭前置点光后，未变方向光被压缩到前一槽而进入changes，触发全局照明reactive。先实际源码反例，再以完整Data精确、保留重数的差分修复；GPU灯表/ABI/准入/hash与相机独立性保持，0新增Unity/Player/GPU。

iteration29：0994d15基线在原灯光入口实际复现[P,D,D]误报。仅Lights.cs改为精确保留重数差分，旧表来自各相机调用者，复用临时数组而不保存跨相机历史。相同测试字节下候选301项通过；反例两帧上传表的字节摘要/count/受控hash均与基线相同，只去掉未变方向光的changes。额外小用例涵盖中间移位、相同灯重数、真实移动、容量进出与交错相机。0新Unity/Player/GPU；不是实测视觉改善或整个缓存清空问题。Astra已认可方向/设计，待最终Astra与实际Pro29复审。详见ReviewBrief-LightChangeCompaction01.md。

实际Pro29已读取执行输出152–153并批准局部修复提交，Astra最终无阻断。下一包world-light-relevance-01新增默认关闭、仅容量溢出时启用的保守空间选灯：完整屏幕有限视体加本次published/warming遍历范围，剔除确定域外的局部灯，保留未知/边界/方向光及原稳定顺序；相关灯仍超限明确报告。先既有源码入口证明能力与兼容，再至多一次构建/一次64帧可见DXR上传检查，不做亮度或计时调查，不进入形变历史重用。

iteration30：实现上述模式及只读冻结遍历／捕获范围；初版691照明合同、19995表面缓存断言通过。唯一构建成功、111产品来源核对恢复通过；唯一可见DXR64帧零错误／零截图、exit0、标准归零。但新功能原生验收失败：原地TryInclude的out参数先清空自身，导致范围unknown，实际GPU表仍是两盏远灯。已保存实际失败及来源；同一新增别名用例在修前失败、最小修复后693通过。修复只延迟out赋值，不改变范围余量或实验输入。修后源码已部署本机，但其原生准入／上传仍未验证，未追加构建或运行。交实际Pro30决定下一有限步骤，不能将旧实机退出成功记作功能通过。详见ReviewBrief-WorldLightRelevance01.md。

实际Pro30读取154–162后批准实验性默认关闭候选本地提交，原01准入FAILED保留。新独立包world-light-relevance-02先在既有入口回放保存的真实矩阵／22范围／3灯，再在输入与断言均不变的条件下限一次新构建／一次64帧DXR检查，补明确产品缺陷修复的接线证据。成功后关闭此有限功能包，不继续扩选灯或矩阵病例。

iteration31：12e5047候选的原生输入回放455项／44次原地合并通过，已有693与19995不重跑。五份临时接线字节不变，111产品来源仅相对失败版本多helper修复，435依赖／场景／设置与旧284构建产物核对。唯一新构建与可见DXR64帧通过原硬断言：范围有效，3/2/1/0，实际count1，完成GPU有效80字节与第三盏灯原生记录精确一致；零截图／错误，exit0、标准归零、源码恢复。原01失败不变，新成功仅对应02源码／构建。待Astra结果与实际Pro31复核后提交并转下一具体产品缺口；其他投影／原生warming／多相机／光能消费／全画质仍未因此验收。

实际Pro31读取163–168后批准有限证据提交并收束选灯功能。用户已将审查改为干净Astra xhigh：知道完整开发计划，以价值→最小方案→正确性判断，按同一功能累计投入，只在关键节点给短裁决。新代理先独立发现屏幕／世界Receive Shadows不一致，再与既有方案和完整进度比较；Pro31独立确认同一条件性P2缺陷。下一步screen-receive-shadows-01仅贯通材质位，首选复用屏幕emission alpha符号、保持其绝对值AO/有效性；不扩材质框架或阴影算法。验证围绕“语义差异、编码兼容、真实keyword捕获／消费”三个开发决策；最多一次新构建／一次64帧进程，成立即结束此项，继续完整原计划。

iteration32：实际HLSL旧源码反例成立，候选以屏幕emission alpha符号贯通Receive Shadows，两capture及全部screen消费者更新，同输入路径与半精度合同通过。唯一Unity构建成功。唯一DXR64帧运行中，普通捕获实际+1/-1与On遮挡／Off保留直接项通过；切原生捕获后，验证遮挡物漏赋Lit而使用Hidden/InternalErrorShader，资格检查正确拒绝，故完整验收FAILED，不能外推普通成功。原始失败、普通两点GPU记录和源码均保留；未追加运行。干净Astra按完整原计划独立建议仅修夹具材质、由Pro32决定一次累计第二次补验，达到原生keyword／符号／实际消费贯通即结束。详见ReviewBrief-ScreenReceiveShadows01.md；不重启暗区、曝光、计时或完整材质矩阵。

实际Pro32读取169–176后允许候选／失败检查点本地提交，完整原生验收仍FAILED。下一包02仅显式赋遮挡物不透明、非裁剪、无发光stock Lit并确认，其余源码／输入／shader插桩／硬断言固定；累计第二次构建／64帧运行。两个入口收据齐全、断言与正常自动退出通过即结束此项；再次缺失、失败或手动关窗则不追加第三次。
