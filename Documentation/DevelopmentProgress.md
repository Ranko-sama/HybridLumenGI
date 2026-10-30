# 完整原计划推进表

用户已明确暂缓G5的CI接线；原CI验收条款保留未完成，不作为继续本机功能开发的前置条件。

原目标3／工作流8修复[资产页直接导出静默丢失MPB覆盖](../LocalComparison/Review/asset-page-mpb-export-01/result.md)：创建输出前明确拒绝无法序列化的Renderer／材质槽覆盖，实际Editor确认拒绝时无输出且源保持。关闭的是错误处理缺口，不是新增MPB持久化或材质保真验收；运行时MPB、无MPB导出和Release85不变。没有追加Player、图像或性能测试。

当前普通入口为[Release85](<I:/Unity test/Comparison/Builds/LocalRelease85/Start-LocalRelease.cmd>)，关闭原目标4／G4的[本机低成本后端仍需手动选择](../LocalComparison/Review/dxr-local-default-01/result.md)缺口：仅将保存示例启动偏好设为DXR，正常启动且未按5时F2已报告实际DXR、20硬件网格、0fallback／材质unknown。当前静止画面对照保留有效域，Floor后端平均绝对D亮度差约0.00000325，未见明显新增缺损。原自加零容差筛选仍为false；经Astra审查撤销其作为原计划外硬前置，本机采用是独立配置取舍，不冒充数值筛选通过。GI／通用默认不变，无新性能测量或动态等画质承诺，完整G4/G5仍开放。

原目标2／G3补齐[当前门到终点后的画面依据](../LocalComparison/Review/door-stop-response-01/result.md)：179刚到终点、189／209保持同一姿态，旧门屏幕区域未见可辨认的完整门形残影，运动时颗粒／斑驳在停止后减轻。共同已知2737点，未知2／2／1，端点已知未丢失；189→209逐像素平均绝对D亮度变化0.022465，仍不能称精确收敛。关闭的是动停画面依据空白，没有新算法修复或整个G3放行；短前缀观察结束，Release84保持。

此前普通入口升级为[Release84](<I:/Unity test/Comparison/Builds/LocalRelease84/Start-LocalRelease.cmd>)：新增[F2复用既有Log ledger](../LocalComparison/Review/keyboard-ledger-01/result.md)，关闭已有运行状态导出依赖鼠标按钮的使用缺口，没有新观察器或GI修改。同一普通Player内由F2确认DXR端点后，[应用Present窗口](../LocalComparison/Review/release84-dxr-present-01/result.md)得到79.22Hz、间隔p95 14.33ms／p99 14.81ms，窗口内无超过33.33ms间隔。原目标4／G5补齐当前DXR普通运行的呈交依据，支持960×540／30FPS方向，但不是实际显示FPS、逐帧DXR、等画质加速或生产放行。软件默认与旧83结果保持，不追加窗口、成本或软件重测；完整G0–G5继续开放。

原目标1/2／G3补齐[当前局部墙面换色的接收面响应](../LocalComparison/Review/local-recolor-response-01/result.md)：普通Renderer级MPB将红墙改蓝，材质未变的Floor／White在30帧已明显转蓝，59帧与119帧的平均色向L1差为0.005536／0.001583，无基线已知点丢失。首帧颗粒及后续亮度变化保留；晚239帧不是独立蓝色真值，不给出绝对旧色残留或精确收敛时刻。关闭的是局部换色后“接收面是否实际更新”的当前画面依据空白，没有新增功能修复或完整G1/G3放行。一次静止门的局部事件观察已结束，未重开slot1专项或扩大证明，Release83保持。

原目标1/2／G3补齐[当前重新开灯的恢复依据](../LocalComparison/Review/light-restore-response-01/result.md)：Release83同次运行中，恢复后30帧Floor／White平均D为开灯前119观测的74.65%／65.68%，59帧为98.36%／96.78%，未知不增；59帧相对已有独立亮灯参考偏差−7.39%／−6.48%。照明能够恢复，首帧颗粒及恢复速度局限仍保留；稀疏时点不证明精确收敛或全过程稳定。关闭的是来源分离和历史修复后“能否重新建立亮灯间接照明”的证据空白，没有新功能修复或整体G3放行。唯一0–359前缀已结束，原720 failed/native1保留；不补采、不延长、不调参，Release83入口保持。

原目标4／G4补齐[Release83已有DXR后端的成本取舍](../LocalComparison/Review/release83-dxr-cost-01/result.md)：同源窗口与配置仅切换后端偏好，实际DXR的GI合计中位13.28ms、p95 14.33ms／p99 14.52ms；软件基线分别28.02／31.19／31.45ms。进程local采样峰值560.94MiB、nonlocal287.69MiB。现有后端为当前30FPS方向提供更大余量；不是新增算法收益、等画质加速或显示FPS放行，默认与普通版本保持，G4／G5仍开放。

用户重新确认普通场景显示后，原目标4／G5补齐[Release83应用Present节奏](../LocalComparison/Review/release83-present-api-02/result.md)：平均29.15次／秒、间隔p95 38.58ms／p99 41.35ms，该有限普通窗口低于30目标。只记录应用Present，不是实际显示FPS；普通UI及配置收据与测量基线不同，不能据此宣称回退或整机性能。填补的是应用呈交数据缺口，没有性能达标或新功能关闭项。旧无CSV与截图失败保留，未归因；下一项仅比较已有DXR的成本与显存取舍，不改变默认或扩大画质验证。

960×540／30 FPS目标下的[普通Release83呈交采集](../LocalComparison/Review/release83-present-01/result.md)未取得CSV。工具按时正常退出、Player正常关闭，但截图不可用且没有帧记录，实际呈交FPS仍未知；只读核对未定位明确原因，未自动重跑。没有新增功能或验收关闭项，保留当前可运行版本与原GI／回调基线。

针对目标4的[未消费方向权重候选](../LocalComparison/Review/unused-direction-weight-01/result.md)已撤回并结束：优化DXIL确认两次求和仍存在，有限真实HLSL对照保持语义，但唯一同配置成本窗口的GI合计中位28.017→30.547ms，未通过事先固定的收益及尾部条件。源码与Unity部署已恢复，Release83保持。没有新增性能关闭项，不追加探针／测量／调参；960×540／30 FPS目标继续有效。

基线交付后，用户已选择先以 **960×540／30 FPS** 为开发目标，补齐G0的分辨率／帧率决定。整帧对应约33.33ms，不等于GI专项额度；GI时间与显存上限、实际稳定帧率及完整G0／G5仍未验收。此前“目标未定”记录属于这一决定之前，不再作为停止功能推进的理由。

[主画面对照入口](../LocalComparison/Review/dynamic-picture-comparison-01/report.md)已补齐Release82／83的颜色、残留、拖影和收敛四问汇总，并明确旧正文／图片属于修复前或中间版本。关闭的是交付入口仍将旧数值写作“当前”的版本歧义；复用既有结果，没有新测量、图像或画质通过项。正式性能目标未定只约束相应决策，不据此宣称整个项目已完成或全局受阻。

原目标4／工作流10、G0／G5补齐[当前Release83本机起始基线](../LocalComparison/Review/release83-local-baseline-01/result.md)：用户明确选择先测量再定正式目标。960×540／半分辨率GI／精确软件下，三GI区间合计中位28.017ms、p95 31.186ms、p99 31.447ms；回调平均34.505次／秒，非Present FPS。对应CPU采样窗口的进程local峰值577.449MiB、nonlocal280.664MiB，非GI独占或瞬时峰值。单次测量已结束，普通Release83保持；未扩配置矩阵、重新采图或比较版本加速。关闭的是当前起始数据缺口，正式预算与完整G0／G5仍开放。只读功能筛选未发现足以立项的新确定缺陷，不因原计划仍开放而重做已结束的局部诊断。

原目标2／工作流6补上[同Feature双Base相机切镜的原生依据](../LocalComparison/Review/multi-camera-history-01/result.md)：B切镜后重置自己的历史，随后A的46705个预先固定成熟点全部保持，零已知丢失或历史缩短。它与旧双相机detail驻留记录不同；没有产品修改，Release83保持。仅这一有限精确软件情形，完整G3仍开放，确认已结束。用户已回答生产预算问题：**先完成本机基线测量，再确定正式目标**；不代填FPS／GI-ms／总显存阈值。

Release83后的颜色候选筛选已收束：既有299帧White的filteredY为0.0082913、raw亮度时间统计为0.0084646、参考为0.0101188；后处理差距不足以支持再次修改重建，也不能直接归咎追踪或缓存。Astra同意结束此方向，不再读更多纹理、调参或补采。Cookie仍属明确未覆盖的支持扩展，暂不作为约定范围的必做项；旧静态300秒、基础软件/DXR及分页/HLOD/Skinned操作不因版本更新而重跑。本次筛选没有新增功能关闭项。

原目标2／工作流6新增关闭“受保护刚体在同帧更新后仍全部丢失历史”的功能缺口：[刚体历史恢复](../LocalComparison/Review/rigid-pose-history-01/result.md)修正Transform在清除／重传过程中被错误合并Added，保留真正新增、延迟及内容变化的拒绝。一次实际门控定位后停止诊断，主线程实现0181ef2；必要的现有Scene检查和唯一正常产品239帧确认后，2739已知门点中2724点恢复长度2历史，黑颗粒明显减少，软斑驳仍在。单帧不证明无拖影、物理误差或收敛。Astra与独立审查同意有限采用，验证结束；[Release83](<I:/Unity test/Comparison/Builds/LocalRelease83/Start-LocalRelease.cmd>)已由公开Release/None构建整合统一入口，无追加Player／性能运行。G1/G3仍开放，原720前缀failed与已有颜色／残留证据边界保留。

原目标1/2、工作流6有限关闭“成熟且严格静止的历史仍被单帧稀疏邻域裁暗”的功能缺口：[重建修复](../LocalComparison/Review/stationary-history-01/result.md)保留同位置可信历史，其余路径保持。frame119固定Floor/White的平均D偏差从−28.9%/−33.4%降至−5.84%/−3.36%，MAE与色向均改善，未知不增；不是调亮强度。代价明确：无标记真变黑32步仍保留6.88%，运动阶段239仍有颗粒/斑驳，整体G1/G3不关闭。唯一300前缀中D240因已有Capture容量缺失，原分析失败保持，普通240仅用于图审，未补采；299偏差+0.144%/−18.06%，精确收敛仍未知。Astra同意有限采用与收束；[Release82](<I:/Unity test/Comparison/Builds/LocalRelease82/Start-LocalRelease.cmd>)已通过公开Release/None构建，产品来源5e714f6，普通入口延续，无追加Player/性能/画质运行。总进度按这项重建缺口的有限关闭报告，不把采集完整性或构建数量当作生产验收。

原验收说明已在44c5454纠正过期集成合同：区分源码包与本机Unity工程/Player，更新普通材质三目标、keyword覆盖/detail/parallax范围、SDF未完成查询及真实chart采样说明；原矩阵、历史失败与G0–G5保持。这关闭了集成说明与当前实现不符的缺口，没有新增画质通过项，也无需测试或哈希校验。

随后按Astra意见停止再次检查已审过的光变化缓存路径。另定位到既有时域裁剪的取舍：当合格3×3 raw邻域全黑时，历史每通道上限为0.04；这可能消除静止稀疏采样贡献，但不能据此归因frame119的28.9%/33.4%偏差。利用成熟历史的亮度矩扩展RGB sigma的候选在设计审查时被否决：满历史不证明静止，raw亮度矩与已裁剪RGB口径不同，按旧RGB分配方差可能延长旧色残留。该候选没有实现、测试或捕获；不继续调公式，不重开cache、空间滤波或新增追踪框架。现有动态裁剪收益保持，颜色与整体动态缺口仍开放。

原计划目标1／G1关闭“当前颜色结论只有旧源码来源”的交付缺口：[35fddaa的frame119独立对照](../LocalComparison/Review/current-color-frame119-01/result.md)复用保存场景与已有CPU参考，实际读回同量D及有效掩码。Floor13330源点／13328配对／2未知、White86／86／0；平均D亮度偏差仍为−28.9%／−33.4%，与旧记录一致。单帧不是稳态，像素SE不是ROI置信区间，模型局限保持；不据此调亮全局强度。唯一0–119前缀读回完成，原720协议failed/native1保持，未新积分、哈希校验、构建或延长。当前静止偏暗仍是开放问题，本轮没有产品修改或新画质通过项；换色／关灯、拖影及准确收敛沿用各自有限依据。

原计划目标3／4、工作流8关闭“已有GPU计时／反馈无法从普通Player使用”的入口缺口：[Release81](<I:/Unity test/Comparison/Builds/LocalRelease81/Start-LocalRelease.cmd>)在原面板提供默认关闭的只测量、显式目标反馈、实际状态与有效配额，并沿用ledger导出。一次普通使用确认NativeDX12有效观测、非法目标不改变配置、数字输入不触发导航、实际feedback active及Off恢复；20ms只作临时功能操作，最低配额仍超目标的事实保留，不是性能达标。见[结果与范围](../LocalComparison/Review/gpu-budget-controls-01/result.md)。Astra已同意收尾；无追加统计、画质或哈希。该构建也纳入零AO修复，只新增编译整合依据，不新增其专项画质结论。此前局部调度的限定源码筛选确认已有功能接通，无新增缺口，已停止。

原计划目标1／工作流2继续收束同类源码缺口：在正漫反射但AO严格为零时，世界与屏幕消费者仍会因没有贡献的cache unknown丢弃合法直接光／Le。现在只保护这两处缓存查询，保留来源、direct、非零AO及有限性规则；屏幕额外保持非有限反馈的原拒绝路径。独立源码审阅通过，Astra判断不需要单独新增测试或重建；没有编译／运行通过声明。BounceFeedback=0原本已有正确门控，不是新增缺口，逐参数核查在此结束。该阶段仅保留源码，Release80（ca5600f）不包含它；随后已随上文Release81部署和构建，未新增该条件的专项运行。

原计划目标1／工作流2关闭“零漫反射仍因无关入射查询未知而丢弃有效辐射”的具体缺口：[屏幕与世界路径修复](../LocalComparison/Review/zero-diffuse-known-radiance-01/result.md)只在原有效来源的漫反射项严格为零时返回原Le／已知黑，世界保留发光MIS与来源分离；小正值、无效来源和端点规则保持。必要的实际函数固定对照通过，Astra同意采用且结束此条验证；未增加整景颜色、残留、拖影、精确收敛或性能通过项。已通过公开入口构建[Release80](<I:/Unity test/Comparison/Builds/LocalRelease80/Start-LocalRelease.cmd>)，0错误／19条warning，当前启动入口同步；沿用保存统一示例，无重复Player、画面或哈希检查。

原计划目标3/工作流4关闭“真实Skinned尚未进入统一普通使用流程”的缺口：[同一门物体的两种形变来源](../LocalComparison/Review/skinned-unified-usage-01/result.md)现可由K切换，Space共用启停；保留可读Mesh，Skin实际经骨骼和既有BakeMesh快照管线。一次必要使用序列确认运动发布、停稳来源匹配、Feature发布及切回/关闭恢复。首尝试为零渲染的临时驱动启动失败，保留后只修初始化调用完成单次重试；产品与判据未改。Astra已采用并结束此条验证。它是样例集成，不重复计为新Skinned算法；任意Skinned配置、整体运动画质与性能仍开放，已通过公开入口构建[Release79](<I:/Unity test/Comparison/Builds/LocalRelease79/Start-LocalRelease.cmd>)并更新当前启动入口，实际使用依据保留上述Unity序列，未重复启动Player。

非空灯表快速比例换色的有界评估已结束：即使相邻两张灯表呈统一RGB比例，缓存仍可能混有更早非统一灯光变化的反馈，不能据此安全重映射解析份额。没有改产品、没有运行验证，也不增加来源代次体系来挽救该候选。Release78空灯表置零不依赖这项前提，保持有效；非空表的渐进响应仍是开放限制，不改称新合同错误。

原计划目标1、2/工作流2与5新增关闭一个具体动态反馈缺口：[来源分离缓存](../LocalComparison/Review/cache-source-separation-01/result.md)使当前上传解析灯表清空后，其旧多跳贡献不再继续反馈，同时保留自发光／环境来源。一次原场景前缀中，关灯前239均值不变；240→299平均逐像素绝对Y变化降低92.2%，270→299降低80.0%，接收面的反弹保留。仅支持该触发范围和观察窗口，不关闭局部换色、整体颜色准确度、运动拖影或准确收敛帧数。缓存项80→96B，存储增加20%；实际带宽和时间增量未测。Astra已同意有限采用；本条验证结束，不追加运行。已用公开入口和保存统一场景构建[Release78](<I:/Unity test/Comparison/Builds/LocalRelease78/Start-LocalRelease.cmd>)，新缓存能力进入普通可运行交付；0错误/23条warning。按必要性判断未重复启动Player或采集图片，当前运行证据来自上述完整Unity Feature前缀。

原计划目标4/工作流10关闭“只有资源估算、缺少驱动进程内存观察能力”的缺口：[Release77](<I:/Unity test/Comparison/Builds/LocalRelease77/Start-LocalRelease.cmd>)通过现有可选DX12插件，按Unity实际适配器查询本进程local/nonlocal用量和OS预算；统一示例默认关闭，可在原面板开启并由既有ledger导出当前值、采样窗口与峰值。它不改变光传输/更新预算。普通Player已实际开启显示、导出并正常退出，详见[用法和有限结果](GpuBudget.md#驱动层进程显存观察)。采样峰值不等于瞬时峰值，OS预算不是产品目标；设备恢复、长时/压力、峰值验收和G5仍开放。之前只读功能筛选未发现可立项故障，已结束，没有扩查或新增验证体系。

此前Release76阶段已收束统一示例交付入口：[首页](../README.md)突出唯一当前入口、统一操作与安装说明，集中列出颜色/残留/拖影/收敛的来源和边界；过期启动长段改为既有历史文档链接。该阶段关闭的是交付入口混淆，未改Runtime、未重建未变EXE，不增加动态质量通过项；后续当前版本以上方更新为准。

全局照明突变后的暂态加权候选已[结束并撤回](../LocalComparison/Review/global-light-response-window-01/result.md)：32次相机准备内提高可信缓存新估计权重，未满足预声明采用条件。270→299输出变化反增4.3%，晚帧均值下降10.0%且不具真值资格；未据此宣称压黑错误或更快收敛。Runtime和Unity部署已恢复，Release76保持。该候选没有关闭新的G1/G3功能缺口；停止该调参路线，不扩大验证。

已补上修复后当前版本的[有限关灯画面对照](../LocalComparison/Review/current-lightoff-prefix-01/result.md)：普通IndirectOnly出射贡献在239/240/270/299的全图平均Y为0.030014/0.010134/0.004400/0.003761；关灯后30与59帧的平均绝对变化仍为晚帧均值17.3%，不能判定收敛。仅一次保存场景的0–299前缀，四张HDR、连续GI收据和零采集错误；原720协议的failed/native1保持，非完整序列通过。没有新来源核验、参考积分或额外运行。关闭的是“修后早期响应没有当前画面依据”的交付缺口，不是残留/物理误差验收；颜色、换色、运动的旧结论保留各自来源。

统一示例公开菜单关闭一个具体入口缺口：从目标相机实际Renderer Data中选择唯一active GI Feature，遵循URP的默认/缺失索引回退；不再受无关已加载Feature影响，也不再仅凭全局计数为1就误选。显式CreateVariant和Runtime保持，独立源码复核及一次真实引用Editor编译通过，源码已同步当前Unity工程；未重跑场景生成或Player，Release76运行版本不变。

Release76随后一次普通L关灯观察在工具返回约2.7秒与17.2秒时未见明显继续衰减/旧色拖尾，发光材质保留，Esc/native0。工具墙钟不是渲染帧或曝光时刻，早期响应未覆盖；不由此关闭当前整景残留/收敛质量。该观察线结束，没有重开旧720序列、来源体系或参考积分。

原计划目标4新增关闭一个具体成本缺口：面积光NEE只使用屏幕命中/距离，却继续计算并丢弃该端点的直接光、缓存和辐射；现已在原命中资格门控后提前返回。同配置有限窗口的三GI区间合计中位38.305→30.742 ms（约−19.7%），候选全部分块中位数低于基线全部分块，满足预定采用条件；没有追加窗口。[Release76](<I:/Unity test/Comparison/Builds/LocalRelease76/Start-LocalRelease.cmd>)已整合该改动，沿用统一普通交互入口。此项不改变图像算法合同，也不关闭颜色误差、默认多跳残留、总体帧率、显存或G5；详见[结果与适用范围](../LocalComparison/Review/screen-endpoint-only-01/result.md)。

已关闭“当前普通Release源码缺少有限GPU成本依据”的缺口：[Release75测量配置](GpuBudget.md)复用保存统一场景、960×540/半分辨率GI、精确软件路径。三个现有GI区间合计中位38.305 ms、p95 39.451 ms、p99 39.749 ms，成本主要在Transport。固定窗口完整、native exit0，未加新查询/图像/哈希，测量已结束。资源账目不等于总VRAM；静态窗口不替代动态/长时/生产预算验收。普通Release75不因本轮测量改变。

Release75后的一次有界源码判断已结束：SurfaceCache虽识别`materialsChanged`，但其`ChangedBounds`还合并运动、几何与重捕获；Feature/GPU局部域保留影响范围而不保留独立材质原因。因此不能把`change.y`直接当MPB辐射突变。材质变更已触发局部更新，这不是已证实的漏处理缺陷；经Astra审查，停止直接复用或增加专用字段来加速响应的候选，不为证明其必要性追加测试。原局部换色画质边界保留，未采用任何新产品修改。

可运行交付已收束为[Release75](<I:/Unity test/Comparison/Builds/LocalRelease75/Start-LocalRelease.cmd>)，包含下述缓存响应改进和当前产品源码。新公开构建入口首次实际使用，复用保存的统一场景与资源页；普通窗口显示、一次L关灯、Esc退出完成。关闭的是“新缓存规则尚未进入可运行版本”和“公开构建入口只有编译证据”两个缺口。公开场景生成器未重跑，整景动态质量、性能和实际CI仍开放。仅一次普通构建/窗口，无哈希或新增画质采集。

本轮关闭一个具体动态响应缺口：全局灯变化后，世界缓存的首次可信更新不再强制混入半份旧时间平均；待替换状态跨预算等待和unknown保留。维持原 reactive 年龄2及HLOD就绪语义，避免连续换光阻塞warming组。最终实际HLSL短序列通过，见[结果与边界](ReviewBrief-GlobalLightHistoryReset01.md)；该局部实现阶段没有新增Unity、图片或哈希，后续发布整合见上文Release75。多跳反馈本身的残留、整景颜色误差与收敛时间仍开放。

发布能力新增：[公开批处理构建入口](BatchPlayerBuild.md)已实现并完成新增 Editor C# 编译。调用方显式提供场景顺序、新输出目录和当前支持的工程配置，普通 BuildPipeline 路径不依赖本机 Harness；未引入云服务、观察器、hash/归档框架。关闭的是“缺少可供CI调用的产品入口”，实际CI、平台/性能放行仍未关闭。

新增功能收束：公开 `CreateVariant`/菜单现在直接生成普通导航与可用的标准 Validation 交互，消除了仅本机发布脚本接入这些能力的缺口。缺少墙/灯/门不再阻断导航，构建脚本复用生成实例。一次受影响 C# 编译通过；没有追加 Unity、图像或哈希检查，Release74保持原构建来源。

当前可运行入口已更新为[Release74](ReviewBrief-CurrentLocalRelease74.md)。本节点按缺口计进度：**统一普通交互入口已关闭**（导航、页/HLOD、后端、换色、灯、门、形变同场景）；**独立画面对照入口已关闭首批交付缺口**（有明确分量与不确定性）；**全局光变化仍混入旧屏幕历史的具体缺陷已修复**。局部 MPB 换色残留、默认多跳缓存收敛、整体颜色准确度、规模压力与 G5 仍开放。四项画质回答见[对照报告](../LocalComparison/Review/dynamic-picture-comparison-01/report.md)，不把有限结果升级为全部关卡通过。

推进规则：功能实现优先。每次拟做测试/哈希前先判断其是否会改变当前功能交付判断，非必要不做；不确定时咨询独立 Astra Max 子代理 `astra_stage_review`。每个阶段确认下一项工作前主动唤起该代理，只审主线、重复工作和额外验收依赖，不将其变为开发方案或用户审批流程。保持不使用 Codex with ChatGPT。

2026-10-30 当前优先级：按用户要求暂停扩大严格误差证明，保留已有成果，先交付注明适用范围与不确定性的独立画面对照。下一交付必须回答颜色误差、换色／关灯残留、运动拖影和收敛时间，并据证据修复具体问题。进度按原计划缺口关闭情况报告，不按测试或归档数量换算。

新关闭的使用缺口：[同场景分页、完整组 HLOD、软件/DXR 偏好切换及停用/离开释放](ReviewBrief-UnifiedSample02.md)已在真实 Unity 中接通。自动烘焙与同场景来源包也已接通；普通 Release 整合、独立颜色图与默认动态质量结论仍在进行，G1–G5 不因此关闭。

当前增量：`95a3213` 已将接收面身份顶点改为 URP Lit 同源变换，删除自算 VP/M 上传；严格深度、alpha、Cull 和历史门保持。实际 [深度诊断](ReviewBrief-CameraIdentityDepthDiagnostic01.md) 已确认 275 个身份丢失均来自顶点深度不匹配，现有 CPU 合同、12 shader 入口与两程序集预编译通过，112 产品源已部署；[原 48 帧相机/TAA 验收](ReviewBrief-CameraMotionTaaResponse03.md)首次分析通过：57 显露事件、561 持续点，零输出违例和覆盖缺口。该修复已进入[Release73](ReviewBrief-CurrentLocalRelease73.md)，112产品源／189产物与真实120帧／Final HDR通过；旧Release72保持13f31ec来源。

当前执行：[同场景来源包与合成接线](ReviewBrief-ValidationSourcePackageV2.md)已完成118份源码的双程序集预编译、真实720帧和32时点全部采集，20代理自动烘焙绑定，来源unsupported为空；未知间接光掩码与独立参考缺口保持。普通入口仍Release73。正在接续同场景streaming/HLOD/后端切换和动态使用，整体G0–G5未完成。

后续按原计划整体依赖推进五个交付节点，局部检查完成后继续下一项：

1. 收束已观测的相机身份缺陷：最小修复、原序列验收、一次版本整合；不继续扩展探索性探针。
2. 接通现有 ValidationSequence 的同场景 HDR 来源包、独立参考接口和同帧合成分解，供 G1–G3 共用。旧六点积分与有限色墙结果不能替代整图参考。
3. 自动烘焙并绑定现有验证场景的 SDF/charts，完成统一场景的相机、灯、门和形变流程；slot1 单事件补覆盖归入此节点。
4. 接通同一样例的 streaming/HLOD/软件与 DXR 切换及资源计账，基于实际反例完善规模支持，推进 G4。
5. 完成来源一致发布、CI 与迁移/支持矩阵；G5 的生产分辨率、FPS、GI 时间和总显存门槛仍需明确，当前游戏并发数据不作性能放行依据。

历史阶段记录：颜色可信性／历史限龄与引导几何修复已进入[Release72](ReviewBrief-CurrentLocalRelease72.md)，112产品源、189产物、一次真实120帧及HDR通过，产品来源13f31ec。用户同时游戏，本次121.38秒首帧不作性能比较。[相机移动／真实TAA](ReviewBrief-CameraMotionTaaResponse02.md)完成48帧，43显露点／462持续点无合格输出违例，但38/39及41–43覆盖失败，整体FAIL保留；已定位37面板与41地面的身份候选中断及历史重置，后续深度诊断及95a3213修复已在上文03回归收束。四目标、十工作流和G0–G5仍未完成。

[首帧分段诊断](ReviewBrief-StartupStageProfile01.md)完成同Release71场景／shader的唯一12帧诊断Player，60事件／25CPU范围闭合，首次完成2.684秒。旧99–142秒等待未复现，不据此声称改善；最大1.985秒空档在GI合成命令记录后，GPU归因仍未知。普通Release71未替换，诊断源码保持269241b；后续引导修复属于新来源。

[普通移动薄板的真实遮挡／恢复](ReviewBrief-FiniteWallOcclusionResponse01.md)完成固定56帧：1,512当前估计、351历史输入资格通过，unknown/uncovered均0；姿态32/44当帧更新，可信黑遮挡和恢复颜色均成立。保留Host错误的6卡ready汇总日志，以实字段及独立审计解释，不改数据或重跑；首渲染141.97秒仍是限制。当前颜色/动态两项产品修复及本轮新增的三类真实场景有限证据已整合，继续原计划其余有依据的工作，不能将测试数量换算为整体完成百分比。

[真实有限缓存反馈](ReviewBrief-CacheFeedbackFinite02.md)继续通过固定32黑帧+2开灯更新：6缓存/54gather与独立参考一致，双缓冲不变性及相邻更新来源闭合；最大cache2阶、raw3阶。保留首个观察器9UAV失败，02只拆为8+1并保持数学/误差合同字节相同。该结论受预声明几何定位假设和有限数值实现类约束，不升级为默认多bounce或通用DXR精度验收。继续普通移动黑板的真实遮挡与恢复。

2026-10-29：[真实色墙变色／关灯动态响应](ReviewBrief-FiniteWallDynamicResponse01.md)完成一次固定96帧完整Feature验证。27接收点累计2,592项首分析通过；另层891项实际重投影、几何/材质和历史置信输入资格全部通过。换色采用当前可信颜色，reactive历史31→2；关灯残留符合运行前推导的32帧上界。首渲染141.34秒保留为限制；这项隔离屏幕历史、不证明默认多次反弹或运动整景画质。正在接续真实两有限墙、32帧黑预热后两次cache更新的独立反馈验证；四目标／十工作流／G0–G5继续开放。

后续[Release71整合](ReviewBrief-CurrentLocalRelease71.md)已通过112产品源／189产物核对与一次显式后台120帧Player及HDR读回，首次渲染99.24秒；70两次自动隐藏运行失败保留，普通OS按键未重测。当前继续真实色墙变色／关灯动态接收器验证与有限cache反馈参考。

更新：2026-10-29。本表按 OriginalDevelopmentPlan.md 的十项工作流区分实现、当前来源实测和生产验收。旧版报告保留来源，不重新标为当前版本通过。当前先处理已证实的阻断和可复现缺陷，再补缺失验收；不因新增局部测试而重跑无关矩阵。

当前源码在 `78618e1` 后新增[颜色反弹可信性与动态历史上限修复](ReviewBrief-ColorBounceDynamicLimits01.md)：未知alpha/覆盖的缓存连接撤销整个可信估计；reactive历史上限与用户 `maxHistory` 取交集，修复上限1时仍混入旧色的反例。两条子代理并行实现，第三条独立审查；颜色8项WARP对照符合合同，动态两入口的主反例消除、六项保持控制逐位一致，保留首分析FAIL并对原数据作RTZ补判通过。本轮不使用Codex with ChatGPT。后续[真实Unity整合](ReviewBrief-CurrentColorDynamicsIntegration01.md)已完成168次纹理计算、28行合同验证和Release70构建，Unity部署更新到269241b；两个隐藏Player检查无相机帧而失败，保留原记录，Release69仍为已通过运行验证的基线。后续[完整Feature有限色墙参考](ReviewBrief-FiniteWallColorReference02.md)在27个像素／216条输入射线上通过独立单bounce RGB比较；原输入判据失败与另层光栅资格均保留，未改颜色阈值。继续验证真实变色／关灯响应；整体画质、多bounce物理能量和生产验收继续开放。

69新增普通可启停连续形变入口，69阶段采用[Release69](<I:/Unity test/Comparison/Builds/LocalRelease69/Start-LocalRelease.cmd>)，产品及Unity部署来源50b63c3，示例接线另记清单。并行实现／独立参考后一次真实256帧完成运动中11次不同内容发布、停稳最终完整来源一致及两张可判读HDR，native0。首个Unity准备失败、唯一资产查询修正及23条warning保留。Astra与实际Pro已查看原图并有限采用；不追加运行，不把本轮当完整动态画质或整体进度跃升。见[69结果](ReviewBrief-ContinuousDeformationUsage01.md)。以下各轮记录保留当时来源。

65按用户要求改为两线并行：修复普通Surface过早夹取detail反射率，以及未知当前测量丢失单帧照明变化的历史限龄。两条实际着色器消费者的旧反例、候选与保持控制通过，见[合并结果与边界](ReviewBrief-ParallelColorDynamics01.md)；已获一次实际Pro合并复核及Astra有限采用，停止扩测。未新增Unity/Player或整景质量结论，普通入口与部署来源不变。

66继续采用产品实现与独立参考并行，补齐普通Surface的stock Lit视差UV。实际Vert插值/Frag主反例符合独立参考；零偏移四个float的1ULP逐位FAIL保留，获Pro明确数值资格；唯一续行只补未执行off控制和四个完整编译，全部通过，满足Pro条件提交与有限结项。见[视差结果](ReviewBrief-SurfaceParallaxUv01.md)。累计Surface36/51/52/65/66，不将夹具数量算作整体进度；这条材质修复线收束。

历史67本机入口及静态Final HDR：Release67，已构建产品来源2fefc097b36084e05e88653d8dff8466caf9d513；后续HEAD不自动替换EXE来源。[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease67/Start-LocalRelease.cmd>)保留默认常驻和58导航代码，本轮未重复键盘验收。一次Release/None构建及一次真实120帧末帧HDR采集正常exit0，112产品源/189产物、实际Feature静态Cube与恢复均首判通过；23条warning和101.249秒首帧等待保留。Astra及实际Pro67有限采用，Pro实际读取PNG。见[67整合结果](ReviewBrief-CurrentLocalRelease67.md)。固定六面环境输入改变，不能用与54的亮度差证明算法改善；640×360不是生产目标。

各能力保留自己的有限专项证据，67静态整合不补齐未触发原生条件或动态质量。Release58/7e387a5的[键盘巡视](ReviewBrief-LocalReleaseNavigation01.md)和入口保留回退；Release44/5120a8c的300秒公开计账、54/a9292cb的旧HDR、[62/7190c28移灯观察](ReviewBrief-LocalLightMoveResponse01.md)均保持原来源。明确拒绝和待验收配置见[支持范围](ProductionPlan.md#当前支持范围与证据层级)。整体画质、性能、总显存、预算目标与G0–G5继续开放；四项目标和十条工作流不标为完成。

68新增近场冷启动HLOD组自身超容量时的已有root回退。实现和独立预期并行；唯一旧源命令证实33/32时无表示，唯一候选首判通过root完整就绪、按组容量计数、缩至2叶后原子切换、恰满32叶直接准备及原相关控制。仅Scene目标选择／诊断10行新增1行替换，见[有限结果](ReviewBrief-HlodColdStartRootFallback01.md)。Astra及实际Pro68接受并批准本地提交，停止此项与无证据自动扩包；没有新Unity运行，部署／Release67仍2fefc09。下一阶段继续关注颜色反弹和动态稳定，只有可定位实际问题或源码反例且能给出最小改动与留用／撤回标准时才启动；未验收标签本身不等于新产品缺陷。

| 工作流 | 已有实现/审查依据 | 当前版本新增或复用证据的边界 | 剩余验收与下一问题 |
| --- | --- | --- | --- |
| 1 社区源码审查 | CommunitySourceAudit 的固定 commit、文件和许可证记录 | 本轮未更换外部设计或复制代码，复用历史审查 | 新引入设计时只补相关模块来源；不重复全库阅读 |
| 2 光传输链路 | DirectLighting、EmissiveSampling、ProductionPlan 方程和绑定 | 当前269241b新增27接收点有限单次反弹参考、6缓存／54gather有限真实反馈及变色／关灯证据；未知材质连接撤销可信估计已修复。均保持预声明输入与数值合同 | 默认多次反馈、广泛材质／灯光单位、整图能量与稳态仍待验收 |
| 3 世界空间表面缓存 | 真实三角 charts、atlas、版本和预算捕获 | candidate-16 有实际 HDR/UV/材质接线证据，属历史来源 | 当前凹面/薄层/接缝覆盖、规模与捕获成本 |
| 4 几何与近远场 | 实例 BVH、global SDF、dirty bricks、形变快照；SDF未完成查询显式传播，可选连续合并形变请求 | iteration42实际HLSL有限反例及保留原FAIL的同数据资格修正获接受；43真实Task屏障验证连续发布/最终追上。69新增普通启停入口及单个可读网格256帧原生连续请求／最终追上；不外推Skinned或整体动态质量 | 广泛薄壁/非闭合与形变边界、近远场连续性；不得把合法步数耗尽当确定miss，允许合并模式的捕获延迟 |
| 5 局部失效与多反弹 | 变更域、代次、双缓冲、预算和年龄调度 | 新增32黑帧后2次更新的实际双缓冲有限反馈，cache最多2阶／raw3阶，旧buffer不变及下一轮来源闭合；变色关灯96帧与移动遮挡56帧提供局部动态输入证据；历史62移灯保持原来源 | 默认多反弹残留、长距离变化传播、渐进稳态及广泛动态质量 |
| 6 采样与降噪 | 混合 PDF/MIS、运动历史与滤波 | reactive历史上限1反例已修复；13f31ec修复引导开关的射线起点／history Ng耦合，同8输入WARP默认输出逐位保持、三后端完整编译通过；891变色关灯历史输入及351遮挡历史输入通过 | 95a3213的原48帧相机/TAA回归通过，57显露事件／561持续点；默认guided均值／方差、绝对拖影和整体动态质量仍开放 |
| 7 URP Lit / DXR | 源 UV/多材质、alpha/Cull、native diffuse规则 | 3088d41同构建软件/DXR各120帧证据获Pro20/21有限接受；iteration25单槽MPB自动发现、实际上传、目标历史重建及一条实际正权重消费链已获Pro25有限接受 | 槽1屏幕历史仍未覆盖；形变、全场景材质一致性、软件差异解释与动态质量 |
| 8 流式与预算 | 异步AssetBundle、完整组准入、HLOD原子切换、独立额度；资源页与可选Additive场景的显式附加视点冷加载需求；默认关闭的计时/完成记录导出 | 41实际representation/driver/scheduler验证资源页附加视点冷需求；59实际ChunkStreaming有限序列证明Additive需求合并、共享额度与卸载权限，完整driver编译；60仅对固定六页组完成真实辅助Transform→距离需求→异步IO→完整绑定的原生有限采用；不外推Additive IO/多渲染相机。e1aa6356的512源帧NativeDX12有限成本基线保留来源，23轮复用优化收益未超过波动而撤回 | 固定组以外的多视点原生综合使用、冷暖/高速移动/总VRAM与生产预算仍开放；不重跑已完成在途撤回和正常退出矩阵 |
| 9 可重复回归 | 离线入口、固定场景、HDR和来源清单 | 有限色墙、变色关灯、缓存反馈、移动遮挡的合同／输入／输出／失败记录已归档；新增首帧CPU分段探针，未复现旧长等待 | 后续只对具体反例和真实未覆盖输入补最小验证；历史来源不重标为新版本通过 |
| 10 工程验收 | Unity环境、普通Release默认常驻与连续形变启停入口、当前Player与来源清单、历史键盘巡视 | 当前Release72/13f31ec已构建并完成显式后台120帧与HDR，121.38秒首帧；用户同时游戏，不作性能比较；70两次隐藏运行无相机回调的失败保留。69/50b63c3的256帧、11次运动发布与两张Final HDR保持历史来源；不同场景／观察器的首帧时长不构成受控性能比较 | OS按键未重复验收；整体动态画质、Release尾延迟、参考图、总显存与生产长测、G0–G5仍开放 |

实际环境已知：Unity6000.0.85f1 / URP17.0.4 / Windows DX12 / RTX2080Ti。用户已选择960×540／30 FPS；GI GPU预算和总显存验收阈值仍未确定，不伪造。可继续正确性开发和测量，不能据此宣布生产完成。朋友交付不再是依赖或停点。

51的当前增量修复普通Surface按数值属性而非keyword决定alpha覆盖的问题，见[有限结果](ReviewBrief-SurfaceAlphaKeywordParity01.md)：实际Frag旧反例成立，候选覆盖与当前URP合同一致，一致控制保持，完整片元编译通过。尚未在Unity验证keyword传递或原生光栅覆盖，不改变Release49来源或整体材质验收状态。

52继续同一Surface一致性修复：漫反射比例改由_SPECULAR_SETUP选择，避免与数值_WorkflowMode不同步时出现错误金属/镜面反射率。实际Frag的标量/贴图反例与一致控制已通过首轮限定验证，见[有限结果](ReviewBrief-SurfaceWorkflowKeywordParity01.md)。这与51及早期Surface专项累计计入同一功能投入，不重开alpha矩阵，也不升级为Unity原生材质或画质验收。

53增加每相机单条CPU发光三角面积/CDF复用：稳定prepared来源仅换材质batch代次时，实际builder定向序列的第二次三角求值由3降为0，当前代次输出与原构建逐字节一致，旧输出保持不可变。来源变化、容量、空表及失败恢复保留原语义，见[结果与CPU内存边界](ReviewBrief-EmitterAreaCdfReuse01.md)。这不是实测帧率收益，也未执行原生Backend/RenderGraph全链；未修改Release49。

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

iteration33：69ef642产品源码未变，仅修遮挡物Lit准备；112产品源及其他5份临时源完全一致。唯一补验构建与64帧Player通过，自动native0、零错误／截图、无手动关窗／看门狗，源码恢复。31普通alpha±1、63原生±2，两入口On直接项0、Off等于各自无遮挡直接项，AO／有效性／层／发光／实际辐射累加原硬断言全部通过。该有限Receive Shadows修复达到退出条件，同功能累计两次构建／运行，原01失败不改写。正在交计划知情的Astra独立选择下一实质缺口，再由实际Pro33复审；不扩矩阵或把有限材质一致性当整体生产通过。

实际Pro33读取177–180批准证据提交并关闭Receive Shadows。Astra先独立提出普通Surface遗漏detail albedo（G1真实待办），再比较Pro33方案后同意优先temporal-subpixel-history-01：原最近邻有效时，只有全套非零历史tap逐项通过旧门槛才四点重建，否则完整退回NN；历史长度取最小，不增资源或改阈值。推进目标2／工作流6／G3；仅一个Unity计算批次验证实际最终输出与边界回退，零Player；无明确收益或错误混合则撤回，不扩测试。detail albedo留待后续，不遗忘也不同时实施；整体动态画质仍未验收。

iteration34：候选四点历史重建两个实际入口通过DXC，唯一Unity DX12计算批次在第16项退出1。前15项通过；八个非identity线性样本保存值重算RMSE由0.001332降至0.000347。失败因测试把未知Ng编码误设0（实际为无效receiver），旧新正确返回全零，断言却预期保留当前；identity入口未执行。保留首个失败和未完成汇总，Runtime及部署已恢复基线，不算新增产品能力。C#预检中历史rsp引用已恢复删除的测试源导致一次准备失败，排除不存在源后通过，两记录保留。无自动第二批，零Player。关键节点Astra先独立建议仅改编码为-1、保持全部候选／用例／阈值／断言固定，累计最后一批补验；再次失败则不自动第三批。实际Pro34正在审查后续方向。

实际Pro34读取181–186，同意Astra的限定继续裁决；140b7dc保存失败检查点，Runtime保持撤回直到补验。iteration35唯一补验仅修Ng输入0→-1，旧新取冻结源码，其他16份临时来源一致。真实Unity计算批次exit0，两个入口均满足原解析误差及边界合同，各自八样本RMSE0.001332→0.000347；所有要求回退的输出／moments逐位一致，长度取最小，未知Ng保留当前。已恢复同一冻结Runtime候选，临时接线恢复。同功能累计两批、零Player，此项停止扩测试并交独立Astra和实际Pro35完成复核。推进的是可靠表面历史取样连续性，不是全场景动态画质或性能验收。

实际Pro35读取187–190批准有限时域修复并转向普通Surface detail albedo；cc00eca已提交。iteration36仅Surface增加detail纹理/mask/UV/Scale和两变体，保持原限幅、格式、AO/发光/阴影合同。实际旧新Vert/Frag反例及关闭控制通过；一次构建、一次64帧真实Player正常完成两入口读回，自动exit0、零错误，源码恢复。首次分析FAILED：分析器把Material.SetColor的编写颜色当成GPU线性，遗漏现有ShaderColor已明确的Color.linear转换。四组原始普通/native颜色齐全、发光/有效性/AO正常，失败与原分析器保留，不重跑或放宽容差，等待独立Astra/Pro决定是否仅用已有数据按既有颜色合同作有限取舍。阶段约束：时域/detail两个实质节点后回现有代表场景整体评估，性能目标阈值异步询问中，不据未定阈值宣称性能完成。

实际Pro36读取191–197批准候选及原FAIL提交2516da3，允许仅用已有数据修正native编写颜色解释。iteration37补充报告通过全部原断言/原容差，13冻结证据未变，零新增Unity/构建/GPU；detail有限修复结束，不追加材料矩阵。已完成时域/detail后整体阶段复评，独立Astra选择移动遮挡物后的GI恢复。旧176–196数组中三组显露代理初次history等于raw，未发现首次跨表面历史残留；后续无真值且来源旧，不能判为当前输入滞后或绝对残影。停止离线扩拆，下一方向交Pro37选择是否复用原Functional门片段做一次当前整体动态检查；尚未启动新采集。全计划/G0–G5及性能阈值继续开放。见StageReassessment-TemporalAndDetail.md。

实际Pro37读取198–199批准阶段检查点与detail结项。下一步一个当前DXR198帧Functional门段，关闭测试probe的相机摆动/形变/MPB混合动作，复用既有integer copy与阶段读回，检查来源可靠的新显露静态背景是否错误带入旧primitive历史。默认不改产品；一次运行后明确反例、有限覆盖无反例或仍不足即结束，不自动补帧/重跑，不把结果称为整体物理或性能通过。

iteration38：当前8a5f17b一次构建/可见DXR198帧正常自动exit0，29组图像、21raw及189阶段payload、pending0、0采集错误，112产品源/8临时接线恢复。实际motion/jitter/上传刚体映射及采样位置判定192已知raw的新显露静态背景，全部history=current、length1；3未知测量另列，未作为已知黑色验收。119/179/196实图已查看，没有可归因的持续门轮廓反例；无物理真值，整体动态质量未验收。有限当前集成覆盖完成，Runtime零改动，不追加运行/调参。交独立Astra及实际Pro38收束并选下一实质缺口，完整原计划继续。见ReviewBrief-MovingOccluderStageReview01.md。

实际Pro38读取200–204及179/196原图批准提交并关闭门片段；认可独立Astra转G2内部多层世界缓存链。下一包复用CPU封闭房间/内部夹层几何为单owner，源primitive12–15；一次构建/最多120帧可见DXR、一次就绪快照/四条固定实际TraceSceneQuery及原surface/cache读取。验证内部层捕获、anchor和primitive→card消费，不手填命中/伪造辐射，不扩材质矩阵；成功/首个错误/未覆盖均结束，零预授权产品改动或第二次运行。

iteration39：原工作流3/4、G2内部多层缓存链完成一次有限真实验证，Runtime未变。复用同一owner的既有16三角房间+两层平面，一次build/120帧DXR正常退出，零错误/截图、pending0、来源恢复。四条原TraceSceneQuery命中12–15，实际材料捕获和原HLGICachedSample分别使用card6/7及各自层上的实际anchor，返回有效已测量黑色[0,0,0,14]；冻结首分析通过。初次离线DXC引用路径失败保留，只修编译mirror后通过，未追加Unity运行。此项结束，不扩凹面矩阵、不算G2整体完成；等待计划知情Astra独立下一方向及实际Pro39复核。见ReviewBrief-InteriorSurfaceCacheChain01.md。

实际Pro39读取205–210并批准内部层有限链及本地提交，同意Astra独立方向：local-release-baseline-01。下一轮复用Functional和现有配置，显式BuildOptions.None，正常启动停用旧测试自动入口/序列/探针，默认保持可见可关闭，另120实际目标帧验证模式正常Quit。仅公开GetDiagnostics验证实际进度/后端/准备状态；无新GPU查询或图像读回，一次build/一次Player，任一失败保留后停止。Release详细逐owner日志可能按条件不编译，不据日志安静声称清零。Full plan仍开放。

iteration40：工作流10/G5新增普通本机Release可运行基线，Runtime/Editor112源未改。CurrentPlayerBuild显式None分支、薄普通启动绕过旧自动入口并停用测试组件，默认常驻窗口，参数分支才计120目标帧。唯一build和唯一可见进程均通过，实际debugBuildfalse、GI1/60/120、末段22硬件mesh/132readycards/材质双方绑定、native0/零错误、未触发watchdog。4启动/构建覆盖及历史孤立include已恢复；189产物保存在I:/Unity test/Comparison/Builds/LocalRelease40，含启动器说明。公开诊断不升级逐射线或逐owner清零，Release条件详细日志缺失正常，无性能/整体验收声明。39/40两节点后回完整计划复评，见StageReassessment-LocalRelease.md；Astra先独立选择下一实际问题，再比较实际Pro40计划，不以观察器/日志/包数作为总体进展。

实际Pro40读取211–213批准本地Release结项和提交，并认同Astra独立提出的多视点冷加载能力。下一包streamed-representation-multiview-demand-01优先只改StreamedRepresentation：默认空的附加观察点集合，与原observer/Camera.main共同取最小world-bounds距离，复用原load/unload滞回；手动优先，无有效视点时保留原wanted语义，不直接退休/解绑，不扫描全部Camera或扩ChunkStreamer。真实Update生成一个this完整组请求，显式Unity/IO适配器加原预算入口有限验证；0新增Unity/Player/GPU。Release40产物仍对应原112源，不能标为含下一候选。

iteration41：目标3/工作流8新增附加视点的冷加载需求输入，只改StreamedRepresentation产品源。原单视点控制主远辅近0请求，候选实际Update提交一个this完整组；清除附加视点、原滞回、重复重排、legacy/manual、整组预算59阻/60准入和allfar后已绑定资源保留均首轮通过。实际driver/scheduler参与，Unity对象/原生IO为明确适配边界，没有复制需求或预算算法。既有chunk/page源检查同命令通过，7份冻结源哈希未变。0Unity/Player/GPU，无本轮失败，不升级原生多相机/IO/HLOD/退休验收。现有Unity部署及Release40仍旧源。候选待Astra独立审查和实际Pro41复审，再提交并沿完整计划选择下一步；详见ReviewBrief-StreamedRepresentationMultiviewDemand01.md。

实际Pro41读取214/215及完整原始日志，批准本地提交并结束CPU多视点需求功能。派生复审文本误把UTF-8当UTF-16的问题已修正并重新释出；原始字节未改，未重跑。Astra先独立选择SDF有限步数耗尽被当作确定miss的语义缺口，Pro核对源码后同意。下一包sdf-query-completion-01只允许实际HLSL冻结基线反例和同输入候选判定，合法8–128steps且独立几何/区间判断；成立才最小贯通unknown，确定hit/miss及近远/直接消费者不退化，不调整追踪参数/持久GPU ABI，不运行Unity/Player。此前DXR画面漏光未被证明，原计划继续。

iteration41已提交d606f94。iteration42以解析闭盒SDF16³和合法8步实际HLSL/WARP确认耗尽仍在待查区间却被当作known miss/environment的条件性缺陷；独立几何/区间界不是高步数真值。4个HLSL候选贯通显式未完成状态、保守下界、无假交点身份、缓存连接known和屏幕严格更近选择，原步数/容差/偏移/分辨率/持久ABI不变。唯一候选WARP native0，但原冻结判定FAIL：nearer控制的extra.xy属于另一次完整范围SDF查询，本应改变，不是场景近命中回归。原失败未改、未重跑。Astra独立确认无本范围产品阻断，要求一次原数据补充判读：明确检查xy的[0,0]→[1,2561]，zw及其余原断言/容差保留，已qualified_finite_contract。实际命中/miss、最近表面、近远段、screen前后/等距及缓存数值未知链得到有限来源证据，6个直接主入口编译通过。cache.w为缓存项而非ProxyRadiance RGB读回；实际confidence0保留。0Unity/Player/实体GPU，源码/原始二进制均冻结；待实际Pro42复审。41/42后回完整原计划复评，见StageReassessment-MultiviewAndSdf.md，旧Release40/Unity部署未升级。

实际Pro42读取218–221（包括原失败），批准四header和来源证据本地提交并结束SDF包。接受表述为“原冻结候选判定失败，经明确同数据资格修正，有限源码合同获接受”，不改原报告。下一deformation-coalesced-request-01采用Astra独立选择的目标3/工作流4、8连续生产者能力：新可选合并请求复用requested/explicitSource，一个在途任务加一个最新需求引用；旧强取消/硬失效、预算/完整发布/退休均保留。一次有限旧行为控制、一次候选实际源码验证，0Unity/Player/GPU；不自动迁移旧caller、不称逐帧动画同步。完整计划继续，预算问题待答。

iteration42已提交e4414ae。iteration43新增RequestCoalescedCapture，仅赋existing explicitSource/requested，保留旧强取消与所有调度/退休实现。一次冻结旧源控制确认连续强替换的无发布限制；一次候选实际组件/真实Task屏障验证首轮通过：700发布仅捕获702，再发布702且最终704追上，701/703不创建任务；借用输入不销毁、在途内容不被后续请求改写、Mesh/SDF/charts同源。上传0阻发布，原完成前持有预留，合并pending下强取消705→707及Disable阻止708复活。既有原子发布/失败/预算/退休源检查同命令通过，7份源哈希未变。0Unity/Player/GPU、本轮无失败/重跑；仅CPU组件请求/发布/所有权合同，不称动画画质或GPU同步。Astra先独立审结果及下一价值，再实际Pro43复审；旧Release40/Unity部署未升级。

实际Pro43读取222/223，批准合并请求有限能力提交并结束，不扩动画矩阵。Astra独立选择的下一方向与Pro一致：local-release-steady-use-01，一次当前源码普通Release构建及一次300秒固定窗口，首60秒初始化、后240秒观察，每5秒同阶段公开计账；检查持续执行与资源积累的具体不确定性。保持Runtime/场景/预算不变，不加GPU探针，不重复120帧启动，不自动延时/补跑；未稳定或计账不足则明确未解决，不能宣称总VRAM/生产长测通过。与Release40累计评估投入，完整原计划继续。
实际Pro44读取224–226，批准普通Release持续使用有限结项与本地提交；不延长/补跑，不归因99秒启动或宣称总VRAM。下一skinned-unchanged-snapshot-reuse-01采用Astra独立选择：自动Skinned捕获在实际内容/布局及烘焙设置与成功发布快照相同时跳过重复SDF/charts重建和MarkDirty，显式请求不变。先一轮实际组件基线成立再最小修复，一轮候选判定；0Unity/Player/GPU，首个反例/生命周期扩张即保存并返回复审。完整原计划继续。
iteration44已提交2007409。iteration45固定实际组件基线确认相同自动Skinned捕获仍双任务/双发布/dirty；最小DeformedMesh改动复用完整内容SHA256及有效SDF/冻结chart设置，仅信当前同owner成功Published。首次候选通过：相同自动捕获不重建/不抬发布帧；同数量UV变更、失败发布重试、SDF分辨率、捕获参数与后续live修改、两种显式请求仍重建；匹配临时捕获清理失败复用失败Job一次保留，非活跃worker且不重复销毁。实际完整指纹方法/Write源码执行，原组件/退休守卫同命令通过；MeshData/BakeMesh/数值/fence仍明确适配器，7编译源仅产品组件不同。0原生运行、无失败/重跑，不称已测性能收益。候选待Astra独立及实际Pro45复审；已部署和Release44仍5120a8c。
实际Pro45读取227/228，批准相同自动Skinned快照复用源码合同提交。Astra建议收窄后续投入，Pro同意一次skinned-native-capture-boundary-01：0产品改动，1个Editor进程/3次真实BakeMesh(false)，临时双骨骼单位变换；同姿态完整指纹一致、上方顶点骨骼X+.25符合独立解析位置1e-6且指纹变化，索引/UV等未改属性保持。保存原始stream/index/布局/bounds，不规范化或改比较规则；不补跑，不启动Player/GI/新GPU查询。它验证复用的原生捕获依赖，不等于候选组件完整Unity运行；现部署指纹源与候选依赖相同，无需整套升级Runtime。
iteration45已提交65e2a11。iteration46一次真实Unity Editor批次/PID21608、三次独立BakeMesh(false)完成，A1/A2全内容指纹一致，B上方骨骼X+.25产生预期顶点且指纹改变；位置/未变法线/切线/UV误差全0≤预声明1e-6，精确索引/拓扑/计数与有限/可读门槛成立。真实布局2条stream160/32B、stride40/8，原始字节/描述/bounds均未改；源网格指纹前后一致。首managed预检/原生/冻结分析均0，无失败/补跑；临时preview scene与Editor脚本恢复，112部署源/场景/设置不变。仅验证简单骨架原生捕获依赖，未部署候选组件、无Player/GI渲染/新GPU查询/性能声明。结合45可有限支持复用采用，不外推任意动画或全G5。Astra与实际Pro46正在按完整计划做形变累计阶段复评。

实际Pro46读取229/230批准有限原生捕获依据和本地证据提交，形变链停止扩展。Astra先从完整原计划独立选出默认Additive未衰减雾的源码缺口；Pro复核后同意优先目标4/工作流7。下一步additive-fog-composition-01先以实际Frag和当前URP依赖建立反例，成立才单shader最小修复；G*T、无雾、Replace有符号差值、Debug和未知保护为退出条件。一次基线/候选源码判定，零Unity/Player，不把先前截图归因为此缺口。

iteration47：目标4/工作流7修复默认Additive最终雾衰减缺口，产品仅Composite增加8行。实际Frag旧反例在T=.5/0仍加完整G；候选正确为T*G，实际Reconstruct与当前URP雾函数执行，无雾及Replace有符号差值/Debug/unknown等控制逐字节保持。当前URP3依赖与固定cache一致，首轮基线/候选通过、受影响pass编译通过，无失败/重试/Unity/部署；不是此前截图归因或运行时变体选择验收。形变累计检查结束，本项按有限源码结果交独立Astra和实际Pro47，不扩雾类型矩阵。

实际Pro47读取231/232批准Additive雾衰减的有限源码修复和本地提交，不扩雾/材质/原生矩阵。同意Astra独立下一方向：local-light-scheduling-priority-01，只在原全局照明脏标记和全部候选基础上，对局部灯光旧/新范围增加调度优先权，保留公平配额及预算；不把范围用作光传输硬截止，不宣称性能/画质收益。

iteration48：目标2/3、工作流5/8增加局部灯变化的更新优先权，保留原全局750脏标记、全部候选与公平份额。实际Lights生成旧/新/关闭/方向光事件；实际Scene/Scheduler及AddLightChange方法首轮基线/候选通过，同预算2选择[0,1]变[0,3]且fairness1。重复事件不累加，清空事件后缺页/零预算恢复仍保留优先；四帧远近均获服务。产品仅Feature/Scheduler，未执行完整Feature/Unity/GPU或部署，不宣称耗时/画质收益。47/48两个产品节点后按完整计划阶段复评，独立Astra先选下一方向，待实际Pro48复核。

实际Pro48读取233/234批准有限局部灯调度能力及本地提交。Astra先独立阶段判断应回到当前整体使用，Pro同意current-release-integration-01：冻结新HEAD，部署相对Release44的四处产品变化，复用原Release构建/普通启动/120帧判据，一次构建一次可见运行；不扩专项事件或300秒观察，不用静态整合认证三项功能各自原生全链。

iteration49：工作流10当前本机整合成立，恰四处已接受源部署到Unity，112产品与31c9415一致。一managed预检0，一Unity Release None build成功（0errors/23warnings保留），一visible DX12 Player PID13396正常120帧/exit0，无watchdog。1/60/120实际GI同步推进，末段22实例/mesh、132readycards、0未知材料；首原条件分析通过，4覆盖+6历史include恢复，场景设置和189产物hash一致。LocalReleaseBootstrap字节与120判据未变；无新增截图/查询/事件/300秒。新入口LocalRelease49，旧40/44原证据不升级；三功能分别原生全链和生产验收仍开放。独立Astra先从完整计划选择下一步，再比较Pro49方案。

实际Pro49读取235–237批准本地整合记录并采用Release49。120模式嵌套资源/退休字段未采集，默认零值不能当资源归零；当前采用依据只含原顶层运行字段。下一步按Astra独立建议统一README、ProductionPlan与本表摘要的当前入口及支持边界，零新运行/源码测试，不改冻结产物或原计划关卡。

iteration54：当前最终HDR图像链有限成立，产品a9292cb，恰三处已接受修改相对Release49。一Release None构建0errors/23warnings，一DX12进程PID21956完成120真实相机/GI帧、单次末帧RGBA32F/EXR/PNG和exit0。原Capture/Finish保留、720帧事件驱动禁用，5临时接线和6历史include恢复，112来源/189产物及场景设置一致。Codex、Astra和实际Pro54均查看PNG，未建立具体集成故障；不把暗部、未采集零值、单张Additive图转为物理、owner-zero、性能或全面功能验收。更新当前入口与证据说明并随本轮提交，不另开状态包。

iteration55已获Astra和实际Pro有限结项：共用渲染失败出口补现有globalSdf.InvalidateAll，避免已录制但丢弃的页永久保留CPU-ready而不重排。首基线因测试错误请求1级被产品钳为2级而失败，原FAIL保留；经Astra/Pro允许，唯一合法128页更正基线建立反例、唯一候选使128页重排/代次推进并回到稳定0更新，成功控制与原失败动作不变。只执行实际CPU类和逐字提取的失败方法，非原生GPU丢弃验收；Release54仍为a9292cb。见[恢复结果与首失败](ReviewBrief-GlobalSdfFailedRenderRecovery01.md)。

iteration56有限结项：GlobalSdf只排除明确非零且仅Material/Lighting的几何失效输入，共享事件仍保留。首基线/首候选确认三类纯事件从128页失效/更新降到0并保持页代次；混合/零/未知与表示/bounds独立失效的完整记录不变。已有积压在budget7下由7ready推进到14，避免反复撤销进度。生产枚举逐字进入适配器，真实Scene分类/原生GPU仍未执行；55恢复不变，未重跑其双分支。Astra及实际Pro接受产品有限结果；Pro发现专项模式外缺少Kind依赖，将同一类型适配移到公共准备后，唯一默认/恢复入口编译批次通过。两者stub与56执行输入逐字相同，产品字节未变，旧执行脚本/结果保留；未执行Main或追加行为测试，满足Pro有条件提交与结束标准。55/56累计五次行为命令加一次编译批次，本段SDF工作停止扩展。见[结果与边界](ReviewBrief-GlobalSdfNongeometricDirty01.md)。

iteration56已提交862b93c并获实际Pro确认收束。iteration57首轮基线确认屏幕分区已排除的面积项因端点照明未知，错误否决已知方向估计；候选仅将该零贡献标为knowntrue，保留全部胜出/PDF/采样规则。实际TraceScreen未知照明出口、完整估计循环及原有效性谓词在既有WARP宿主执行，独立D参考准确保留，真正方向未知、未解决world等距不胜出的面积未知及非零面积控制逐字节不变。唯一候选两CSTrace入口及旧源码守卫前缀均通过；无行为/编译失败、重跑、新宿主、数值CDF矩阵或Unity，非可见故障/画质收益验收。冻结执行前缀末尾空行的格式诊断保留，不重写原执行字节。见[结果与边界](ReviewBrief-ScreenExcludedAreaKnownZero01.md)。独立Astra及实际Pro均接受有限结项和本地提交，停止本项扩测。下一普通Release导航补齐实际巡视能力：键盘移动/转向/复位/退出，固定采集路径保持原样；一预检/一构建/一真实窗口操作，非动态质量验收。

iteration58已有限采用：普通Release新增WASD/QE移动、方向键转向、R精确初始位姿、Esc退出；只在!verify执行，有限采集与GI配置不变。一次预检0、一Release构建0(23warnings)、一普通可见Player20784经实际OS键盘输入观察到平移/转向/松键停止/复位并exit0；112当前产品源、189产物、五覆盖与六include恢复均核对。00–03暗窗口未合格判读，04才可辨场景；总进程172.586秒、首窗口至exit151.629秒、首可辨场景至exit58.307秒，不能声称无条件120秒通过。失焦护栏仅代码核验。首次postcheck误匹配启动JSON空error键，首诊断保留，同数据结构化解释修正，无原生重跑。见[巡视结果与原始边界](ReviewBrief-LocalReleaseNavigation01.md)。独立Astra与实际Pro58批准有限采用Release58并停止追加导航验证；Pro未独立读取图片，视觉结论属于执行层和Astra。Release54仍为HDR图像来源。

iteration59：两处产品修改补齐可选Additive场景辅助视点冷需求，默认空附加集合/复制setter/每帧合并一次Step，旧单位置API、滞回、预算和卸载收据保持。一次旧源控制0、一次候选实际状态机0；五份旧单视点快照及external结果逐字相同，driver/state/manifest真实Unity引用编译0、两个序列化字段警告保留。0Unity/Player/GPU，setter/Transform枚举仅源码核对，清空对照执行的是仅传主位置的State，不伪称原生输入。Astra和实际Pro59有限结项并批准本地提交；累计41+59，不追加Additive矩阵。下一项仅为资源页主路径真实辅助Transform冷加载到完整绑定的采用判断。Release58产品仍7e387a5，完整计划继续开放。见[59能力与边界](ReviewBrief-AdditiveChunkMultiviewDemand01.md)。

iteration60：Runtime未改，产品a11eb615；一次预检0(5既有warnings)、一次普通Release None构建0(23warnings)、一次visible DX12 PID12456 exit0/无watchdog。两帧正常距离模式六页Unloaded且零需求/预留；仅添加真实辅助Transform后，第11实际目标相机帧整组Ready、四直接lease与mesh/material/SDF/chartsSourceMesh绑定一致，renderer/proxy启用。保留postbuild路径读错的首exit1，只改读取根对同数据核对，不改断言/重建。collected.exactBindings=false为未重测默认值，权威complete-binding=true原记录保留。112产品源/188产物/8原资产及5覆盖+6include恢复核对。Astra及实际Pro60有限采用、批准证据提交，累计41+59+60结束，不追加矩阵；不证明HLOD、多相机渲染、退休清零或性能。Release58仍为用户入口。下一项先建立表面缓存录制丢弃后的假就绪反例，再决定最小恢复修复。见[60原生绑定与边界](ReviewBrief-AssetPageAuxiliaryColdBind01.md)。

iteration61：两处产品修改修复公共渲染失败出口后的表面缓存CPU假就绪／不重试。唯一旧源反例捕获[0,0,0]，唯一候选恢复[1,1,0]，单卡预算下owner仅在全部卡重捕后恢复；所有驻留卡撤销ready、代次推进、重新全清理，资源与owner/chart/tile身份不变，正常分支逐字相同。实际SurfaceCache及逐字提取的失败方法执行，完整Feature/RenderGraph/原生GPU丢弃未执行；无本轮失败或重跑。Astra独立与实际Pro61均批准本地提交和收束，55＋61累计为同一失败恢复投入，不扩矩阵。部署及60 Player仍a11eb615，用户入口仍Release58。下一步沿原目标1/2与工作流2/5/6进行一次固定局部灯迁移的真实间接光响应观察；不是物理真值或性能验收。见[61修复与边界](ReviewBrief-SurfaceCacheFailedRenderRecovery01.md)。

iteration62有限结项：产品7190c28、零Runtime修改，一预检0、一Release None构建0(23warnings)、一visible DX12 Player17268完成180目标相机帧与五次原Capture、exit0/正常退出。固定Point在logical120/engine121从A移至B，CPU选中表及两条旧新变化记录对应；Codex、Astra和实际Pro均看过五张图，右青墙与邻近地面形成有限空间响应，未建立具体产品故障。冻结离线判读首FAIL来自十进制期望与Unity binary32精确判等，原FAIL保留；Pro授权唯一同数据补判只转换预声明A/B期望，完整原断言全部通过、35原文件hash不变。准备阶段虚拟Package路径首诊断同样保留，无重建/原生重跑/补帧。112产品、435场景/包/设置输入、187产物、5覆盖+6include恢复核对。此动态专项收束，不证明物理正确、收敛时间或整体生产验收；Release58仍为用户入口。见[结果与原失败](ReviewBrief-LocalLightMoveResponse01.md)。


iteration63：目标1/4、工作流2/7新增默认空且借用的静态线性HDR Cubemap，替代常量并由同一函数为世界缓存/屏幕追踪提供方向Li，原PDF/反射率/pi/曝光位置不变。三文件32新增2替换；一次托管预检0、一次Unity DX12 Editor PID39020/exit0，12固定输入48dispatches保留原始字节。真实Cube方向匹配、旧常量及命中/未知/零权重控制保持，非有限样本拒绝；实际格式准入及UnityJson原设置失效块通过。源资格/33设置文件/112部署源恢复通过，无失败补跑。显式输入适配器不证明完整几何或Feature/RenderGraph，零Player/场景/性能；普通Release58不变。Astra与实际Pro63均有限采用，环境输入及原生合成合同随同提交；本项不扩测试。见[63结果及边界](ReviewBrief-StaticHdrEnvironmentCubemap01.md)。
