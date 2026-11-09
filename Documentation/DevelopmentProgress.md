# 完整原计划推进表

## 当前总进度　Release218，G0 已锁定，G1／G2 本机代表性验收通过

T3／G3 已关闭普通 Player 固定两室开门后的新照明恢复子项。首个开门源帧地板为同源控制的 46.85%，约 0.634 秒进入容差并保持到 +2.800 秒。2 秒前最后一帧亮度低 3.82%，色向 L1 为 0.00160。门轮廓拖影与其他动态光路继续验收。[同曝光对照与范围](../LocalComparison/Review/ordinary-portal-open-266/result.md)

T6／G4 已补上形变快照的独立主线程发布时间准入。实际组件对照确认超过额度时首份完整发布，下一份保留原捕获与内存预留，同帧不补额度，下帧继续。默认关闭，单次发布可能超额。实际高更新负载及全阶段预算继续验收。[组件对照与范围](../LocalComparison/Review/deformed-publication-budget-265/result.md) · [Release218 同源交付](../LocalComparison/Review/deformed-publication-budget-265/delivery.json)

T5／G4 已关闭独立分页细节终止失效后，把幸存叶重新发布为完整近景组的路径。实际 Scene 的同输入对照确认 GI、BVH 与栅格资格整组撤回，可用粗根取得回执后接替。首个恢复帧的实际 DXR 与冷高速首显继续验收。[对照与适用范围](../LocalComparison/Review/failed-detail-membership-264/result.md) · [Release217 同源交付](../LocalComparison/Review/failed-detail-membership-264/delivery.json)

T2／G3 已关闭作者默认裁剪材质在单采样下无法积累可选身份历史的缺口。实机同输入的两个实心点由无身份、年龄 1 恢复到前板身份、年龄 16。两个裁剪孔洞取得后板身份，实际 A2C 的拒绝门继续生效。[实机配对与范围](../LocalComparison/Review/author-cutout-history-263/result.md) · [Release216 同源交付](../LocalComparison/Review/author-cutout-history-263/delivery.json)

T6／G4–G5 已关闭原固定热态近远接替的应用 Present 墙钟节奏子项。Release215 两方向各十次完整接替，应用 Present 间隔 p95／p99 为 19.801／24.643 ms，最大 30.214 ms。同次 GI 合计 p95 为 17.365 ms，进程 local 采样峰值 570.941 MiB，两项达到起始预算。末源帧的延迟返回仍缺，事前逐帧资格判定保留。[实机结果及采用范围](../LocalComparison/Review/hot-hlod-unity-present-261/result.md)

T6／G4 已关闭精确软件切回 DXR 后闲置属性和 BVH 持续占额的缺口。普通 Win64 同一机位确认逻辑计账从 80,864 B 归零，再次进入精确软件时恢复。采用范围为实际切换及退休端点。[实机对照](../LocalComparison/Review/inactive-software-geometry-260/result.md) · [Release215 同源交付](../LocalComparison/Review/inactive-software-geometry-260/delivery.json)

T6／G4–G5 已定位固定精确软件近景的主要成本。Gather 单段最低观测为 38.096 ms，单靠削减世界缓存或重建无法达到 25 ms。原软件预算门保持开放，后续集中在 Gather，具体内部热点仍待明确。[实机分项与边界](../LocalComparison/Review/software-transport-cost-259/result.md)

T6／G4 已关闭精确软件 BVH 额度已拒绝时仍完整构建 CPU 树的路径。原 A → B → A 对照中，返回相机在等待帧省去 2,000 叶的构建，旧票据完成后正常构建并恢复计账。采用限软件几何 CPU 准入，软件 GPU 时间继续验收。[同输入对照与范围](../LocalComparison/Review/software-bvh-preflight-258/result.md) · [Release214 同源交付](../LocalComparison/Review/software-bvh-preflight-258/delivery.json)

T3／G3 补齐普通 Player 的 L 键实际灯表和固定地板同曝光对照。切换后首个源帧的解析灯由 5 降至 0，发光面继续供光。1／2 秒附近的区域平均间接光略低于匹配关灯对照，但对照色向漂移 0.03155 超过原 0.025 稳定门槛。期限与保持验收继续开放。[实机对照与适用范围](../LocalComparison/Review/ordinary-player-lightoff-257/result.md)

T6／G4 已关闭分页撤回后仅由在途父包保留的依赖继续启动新加载的缺口。单步唯一启动名额交给仍有需求的页面，原材质包正常完成并安全释放，重入后重新加载。对照使用实际 C# 调度与受控 I/O。[同输入对照](../LocalComparison/Review/withdrawn-dependency-io-256/result.md) · [同源交付](../LocalComparison/Review/withdrawn-dependency-io-256/delivery.json)

T6／G4 已关闭后置相机降低当帧额度时丢失贴图上传轮次的缺口。实际 Batch／Pool 受控对照中，次帧额度恢复后等待相机录制完整的 2 MiB。低额度帧装不下的大页让出额度，1 MiB 小页正常录制。[受控对照与边界](../LocalComparison/Review/texture-quota-tightening-254/result.md) · [两项修复的同源交付](../LocalComparison/Review/texture-quota-tightening-254/delivery.json)

T5／G4 已关闭宽场景的 Far 书签误跳离场问题。长条场景原书签距组约 47 单位，修复后为 18，进入 40 单位可见界内并跨过细节请求退出阈值。新生成和旧保存场景共用修正，原三室书签仍有效。高速冷入继续验收。[书签对照与范围](../LocalComparison/Review/far-bookmark-255/result.md)

T2／T4 已关闭直接 MeshRenderer 的 UV0 覆盖使精确追踪错误穿过实心近板的问题。旧版原生中心为绿，精确软件与 DXR 却仍到达两单位外的蓝板。修复撤销旧图卡与批次，两条后端保留近板解析遮挡，移除覆盖后恢复原精确路径。采用限来源资格与后备遮挡。[实机对照与范围](../LocalComparison/Review/direct-uv0-source-253/result.md) · [同源交付](../LocalComparison/Review/direct-uv0-source-253/delivery.json)

T3／G3 已关闭两盏固定点灯均开启时，一盏青灯换蓝后旧绿继续反弹的缺口。实际 DXR 同曝光对照中，约 1／2 秒的旧绿增量从 12.72%／6.33% 降至 −0.29%／−0.19%，约 0.26 秒进入合格保持区间。恢复中绿色最低比终态低 2.49%，未变蓝通道的最大偏差为 1.17%。[同输入对照与范围](../LocalComparison/Review/point-light-shared-recolor-252/result.md) · [同源交付](../LocalComparison/Review/point-light-shared-recolor-252/delivery.json)

T5／G4 复现独立分页首发缺口。粗根已就绪时首片细节绑定，组发布和预热均归零。先发布粗根的候选在两片叶、32 槽对照中工作，但细节恰好占满槽限时会挡住整组接替。候选已撤回，冷入首显仍待解决。[对照和撤回依据](../LocalComparison/Review/hlod-cold-partial-251/result.md)

T6／G4 的当前固定软件近景实测 GI p95 为 46.868 ms，local 采样峰值为 551.699 MiB。延后世界材质求值的候选 p95 为 47.804 ms，已按冻结条件撤回。软件 25 ms 时间缺口继续开放。[同源成本对照与范围](../LocalComparison/Review/software-deferred-material-250/result.md)

T3／G3 已关闭固定双点灯共用通道时单独关灯的残亮。实际灯表从两条变为一条，青灯全程保持。约 2 秒时旧绿增量从 6.37% 降至 −0.21%，约 0.26 秒进入合格保持区间。整段绿均值最低比青灯终态低 2.45%，蓝通道最大偏差 2.19%。[同曝光实测与范围](../LocalComparison/Review/point-light-shared-off-249/result.md) · [同源交付](../LocalComparison/Review/point-light-shared-off-249/delivery.json)

T3／G3 已关闭固定双点光共用绿色通道时的调暗残亮。约 2 秒时旧绿增量从 6.64% 降至 −0.52%，修复版约 0.19 秒进入合格保持区间。整段绿均值最低比低亮终态低 3.30%，固定蓝通道最大偏差 2.17%。[同曝光实测和范围](../LocalComparison/Review/point-light-shared-channel-248/result.md) · [同源交付](../LocalComparison/Review/point-light-shared-channel-248/delivery.json)

T3／G3 已关闭裁剪 BaseMap 分段上传时漏掉远接收面刷新的缺口。实机 DXR 的最后写入帧与经验证重新绑定帧均恢复地板软反应，调度优先级从 0 升至 1000。稳定可用后无重复通知。像素残留、拖影及收敛时间继续验收。[实机对照与范围](../LocalComparison/Review/cutout-upload-reach-247/result.md) · [同源交付](../LocalComparison/Review/cutout-upload-reach-247/delivery.json)

T6／G4 已关闭两个共享容量阻断。分页的资产加载失败后，失败包可在加载退避期间退休，健康组取得额度，原请求仍按原时点重试。新 RTAS 计划自身超限且旧结构无法复用时，旧预约经安全退休归还，另一相机恢复录制准入。证据范围为实际 C# 调度与受控完成，冷入首显和生产负载预算继续验收。[两个对照](../LocalComparison/Review/shared-budget-retirement-244-245/result.md) · [同源交付](../LocalComparison/Review/shared-budget-retirement-244-245/delivery.json)

T3／G3 已关闭固定双点光中一盏调暗而另一盏保持时的颜色恢复缺口。约 2 秒时，绿通道相对低亮基准的偏差从 +55.48% 降至 +1.06%，约 0.25 秒进入合格保持区间。蓝通道全窗口最大偏差为 2.28%。采用范围为两盏点光的独立颜色通道。[同曝光实测](../LocalComparison/Review/point-light-channels-243/result.md) · [同源交付](../LocalComparison/Review/point-light-channels-243/delivery.json)

T3／G3 已关闭固定单点光调暗后的旧亮残留与低亮恢复缺口。九点线性间接光在约 2 秒时的低亮偏差从 +55.45% 降至 +1.06%，首个合格保持窗口始于 0.260 秒。多灯、升亮与普通 Player 动态质量继续验收。[实机同曝光对照](../LocalComparison/Review/point-light-intensity-241/result.md) · [同源交付](../LocalComparison/Review/point-light-intensity-241/delivery.json)

T6／G4 已关闭同一 URP Asset 内改选 Renderer 后旧相机状态阻塞共享 RTAS 额度的缺口。旧版新 Renderer 连续 12 次录制精确软件，修复版在旧预约释放后恢复 DXR，切回重新创建状态。禁用后手动渲染与无关相机保持原状态。[实机预算回收](../LocalComparison/Review/renderer-budget-242/result.md)

T5／G4 已关闭超槽 HLOD 组部分绑定时漏掉粗根回退的问题。实际 Scene 对照中，33 片声明叶面对 32 槽，首叶绑定后根继续预热，完整回执到达后发布。声明缩小后，两片细节按原就绪门原子接替。宽组页需求和高速冷入继续验收。[容量回退对照](../LocalComparison/Review/hlod-incomplete-capacity-240/result.md) · [同源交付](../LocalComparison/Review/hlod-incomplete-capacity-240/delivery.json)

T3／G3 已关闭固定点光仍开启时，旧色通道从灯表消失却继续在缓存中反弹的残留缺口。同曝光实机对照中，约 1／2 秒旧绿从 11.84%／6.02% 降至 0.046%／0.0041%，新蓝持续供光。整项 G3 与新颜色绝对收敛继续验收。[实机对照](../LocalComparison/Review/point-light-recolor-237/result.md) · [同源交付](../LocalComparison/Review/point-light-recolor-237/delivery.json)

T3／G3 已关闭后备投影物切换解析盒与对象 SDF 时漏掉远接收面的问题。固定点光的实机 GPU 查询确认上传后光路穿过门洞，修复版远地板取得局部照明反应和调度优先级。保持帧无重复事件。画面残留、收敛及高速 HLOD 首显继续验收。[实机对照](../LocalComparison/Review/sdf-shadow-reach-236/result.md) · [同源交付](../LocalComparison/Review/sdf-shadow-reach-236/delivery.json)

T2／G4 已关闭额外材质槽叠绘末子网格时，软件和 DXR 误信首槽透明覆盖的缺口。实机添加不透明槽后，两个后端都拒绝旧精确批次并命中近板解析代理。撤槽恢复普通精确查询。完整叠绘颜色、纹理和生产规模继续验收。[原生覆盖与混合查询](../LocalComparison/Review/extra-material-slots-235/result.md) · [同源交付](../LocalComparison/Review/extra-material-slots-235/delivery.json)

T3／G3 已关闭单个投影物在精确与后备表示之间切换时漏掉远接收面通知的问题。相机保持 DXR，实机关闭和恢复精确裁剪板时，远地板的局部缓存调度优先级均从 0 升至 1000。保持帧无重复通知。像素残留和收敛时间继续验收。[实机对照](../LocalComparison/Review/exact-shadow-reach-234/result.md) · [同源交付](../LocalComparison/Review/exact-shadow-reach-234/delivery.json)

T3／T6 已关闭形变捕获在顶点额度不足时持续跳过合格对象的缺口。实际组件对照中，较小后续对象继续使用当帧余量，延期的蒙皮在下一可用帧捕获并完整发布新姿态。原生 GPU 对新快照的消费、拖影及画面收敛继续按 G3 验收。[捕获合同](DeformedGeometry.md) · [同源交付](../LocalComparison/Review/capture-vertex-turn-233/delivery.json)

T6／G4 已消除精确软件最近命中的重复材质覆盖求值。固定近景同输入中，GI 合计中位降低 7.27%，p95／p99 降至 45.887／46.349 ms。原质量和最近命中语义适用，软件 25 ms 时间缺口仍开放。[实测与范围](../LocalComparison/Review/software-coverage-231/result.md) · [同源交付](../LocalComparison/Review/software-coverage-231/delivery.json)

T6／G4–G5 已明确当前精确软件静止近景的预算缺口。Release195 同窗实测 GI p95 为 50.005 ms，Transport p95 为 49.804 ms，进程 local 采样峰值 576.637 MiB。时间超过起始预算，local 达标，G0 的 DXR 裁决独立保留。[实测、同源配置与适用范围](../LocalComparison/Review/software-budget-230/result.md)

G3 取得一条连续发光体移动的新位置恢复依据。Release195 停稳后约 1.49 秒进入新区原亮度与色向容差，保持超过 0.5 秒。旧区静止控制波动超限，固定点的实际深度位置与预定网格描述有偏差。完整移动子项保持证据不足。[同曝光动画、曲线和实际适用范围](../LocalComparison/Review/emitter-motion-229/result.md)

G3 已关闭固定机位的单一发光体撤出子项。Release195 实机在首个响应源帧退出解析发光板，地板的旧绿均值在 1 秒前剩 2.1094%、2 秒前剩 0.24697%，保持和末帧有效性均通过。发光体移动及其他动态输入仍按原条件验收。[同曝光画面、逐帧曲线与适用范围](../LocalComparison/Review/emitter-removal-228/result.md)

T2／原第 9 节已关闭普通 URP Lit 逐材质 `ShadowCaster` 被精确阴影查询忽略的问题。近板通道开、关、恢复时，实际软件 BVH 和 DXR 的阴影命中均为近、远、近，普通表面始终命中同一近板。两次切换均进入阴影覆盖变化判断。远处接收面的画面恢复和收敛仍归 G3。[实测与适用范围](../LocalComparison/Review/shadow-pass-227/result.md) · [同源交付](../LocalComparison/Review/shadow-pass-227/delivery.json)

T2／原第 9 节已关闭面积光对已确认近遮挡因无关着色贴图待定而丢弃估计的路径。共用 committed resolver 和面积贡献函数的 WARP 对照中，旧版为未知，修复版为已知零。未知覆盖、同层、目标材质以及未完成查询继续按各自资格处理。真实遍历和相机画面继续验收。[对照与范围](../LocalComparison/Review/area-covered-blocker-226/result.md) · [同源交付](../LocalComparison/Review/area-covered-blocker-226/delivery.json)

T6／G4 已关闭失败对象 SDF 卷长期占用可服务区间的问题。实际图集受控对照中，旧元数据撤销写入失败后会重传，成功后归还区间，健康卷在下一帧按原额度上传。失败版本保持回退，换版可重新准入。采用范围为逻辑区间和提交状态。[对照与范围](../LocalComparison/Review/sdf-failed-range-225/result.md) · [同源交付](../LocalComparison/Review/sdf-failed-range-225/delivery.json)

补齐 G3 原验收表的普通 Base 固定中心转向子项。Release192 同源实际 DXR 中，三次转向的共同可见地板历史从 13 增到 16，原视口外新入画的地板均从 1 开始。遮挡物后的新显露使用既有 Release73 TAA 横移证据。Final 画面和完整 G3 继续验收。[转向记录](../LocalComparison/Review/base-camera-turn-224/result.md) · [横移记录](ReviewBrief-CameraMotionTaaResponse03.md)

T6／G4 已关闭默认 AssetBundle 驱动中后续小页反复填满在途额度、使合格大页无法启动的问题。实际驱动受控对照中，旧版第 8 步仍未启动，修复版第 3 步启动、第 6 步就绪，后续小页继续推进。原生 I/O 等待、吞吐和完整生产预算继续验收。[对照与范围](../LocalComparison/Review/asset-bundle-headroom-223/result.md) · [同源交付](../LocalComparison/Review/asset-bundle-headroom-223/delivery.json)

T6／G4 已关闭可选 Additive 场景驱动中持续合格请求拿不到加载名额的问题。实际 C# 调度器同输入对照中，旧版 64 步未服务该请求，修复版第 60 步启动并完成。采用范围为等优先级场景的受控 I/O 和原共享额度，Unity 原生场景 I/O、实际等待和生产预算分别验收。[对照和范围](../LocalComparison/Review/additive-load-fairness-222/result.md) · [同源交付](../LocalComparison/Review/additive-load-fairness-222/delivery.json)

补齐原 Validation 的实际相机栈历史隔离子项。Release190 同源 DXR Editor 实测中，原生 Overlay 的标记进入输出，GI 仍只维护 Base 状态，固定地板的 GPU 历史连续保留。原双独立 Base 切镜结论各自采用。[同栈原图与读数](../LocalComparison/Review/stack-history-221/result.md)

补齐原 Validation 的奇数尺寸和低渲染比例边缘子项。Release190 同源普通 DXR Player 在 URP 1.0 和 0.5 下均输出完整的 1919×1079 相机画面，四条最外边都有 GI 置信度信号。采用范围为固定机位的稳定相机输出。[两张原图及实际尺寸](../LocalComparison/Review/odd-player-edges-220/result.md)

T3／G3 已关闭网格原地编辑后，旧投影者撤出而新上传延期时的远接收面漏报。实际 DXR 在撤出当帧通知旧端并提高远地板调度优先级，随后新网格在可用名额内发布。采用范围为通知、调度和恢复发布，画面残留与收敛分别验收。[延期与恢复实测](../LocalComparison/Review/deferred-caster-reach-219/result.md) · [同源交付](../LocalComparison/Review/deferred-caster-reach-219/delivery.json)

T3／G3 已关闭投影者移动或撤除漏报长范围点光远接收面的问题。双网格 DXR 观察中，照明通知半径为 34，移动时刚体旧缓存拒绝半径为 9，远地板两次均取得调度优先级。采用范围为通知和调度，画面恢复仍待验收。[实测](../LocalComparison/Review/shadow-caster-reach-218/result.md) · [同源交付](../LocalComparison/Review/shadow-caster-reach-218/delivery.json)

T3／G3 已关闭长范围点光投影资格变化漏报远接收面的问题。实际 DXR 关闭投影时，上传软域半径为 34，远地板优先级为 1000。保持关闭并修改渲染层时沿用半径 9。采用范围为通知和调度。[实际点光对照](../LocalComparison/Review/shadow-policy-reach-217/result.md) · [同源交付](../LocalComparison/Review/shadow-policy-reach-217/delivery.json)

T6／G4 已关闭失败重试等待中的页组继续占用计划容量的问题。受控 I/O 对照中，健康组在原容量内就绪，失败组按原时点与顺序恢复。采用范围为 Driver 与页调度器的准入，原生 I/O 和完整压力继续验收。[分页准入](IndependentAssetPages.md) · [同源交付](../LocalComparison/Review/asset-retry-admission-216/delivery.json)

T2／G4 已关闭无关贴图延期造成整条裁切材质记录失效的问题。实际批次保留已就绪 BaseMap 的槽位、代次和冻结来源，延期法线仍按指定但未知处理。原生候选命中和相机画面继续验收。[材质表合同](Implementation.md) · [同源交付](../LocalComparison/Review/deferred-hit-material-215/delivery.json)

T5／G4 已关闭默认独立导出嵌套树的中间聚合自动占页。受控 I/O 对照覆盖冷态自动需求、原安全退休、粗根与叶组共驻和重挂后需求恢复。统一示例高速冷入首显与原生像素、照明分别验收。[分页需求范围](IndependentAssetPages.md) · [同源交付](../LocalComparison/Review/nested-hlod-demand-214/delivery.json)

T3／T6 已关闭降低形变发布额度后，已完成且超额的快照占住工作槽的问题。实际组件在一个工作槽下保留原大快照，小快照在新额度内发布，恢复额度后大快照继续发布。采用范围为 CPU 捕获、发布与受控退休。[形变准入](DeformedGeometry.md) · [同源交付](../LocalComparison/Review/deformation-worker-admission-213/delivery.json)

T6／G4 已补命中材质贴图复制录制的 CPU 时间准入。定向对照确认整页延期、延期材质保持未知、原轮次继续推进及关闭时沿用字节路径。构建后的普通 Player 与可编辑工程已公开交付。[配置与范围](GpuBudget.md#命中材质贴图录制的-cpu-准入) · [同源交付](../LocalComparison/Review/material-texture-recording-212/delivery.json)

T6／G4 已关闭停止补充 RTAS 积分时，余额不足的大请求阻挡余额足够的小请求的缺口。实际 Backend 对照验证了扣费、无效准备拒绝、匹配复用与安全退休。帧末临时收紧的 HLOD 排队控制通过。[对照与范围](../LocalComparison/Review/rtas-nonreplenishing-210/result.md) · [同源交付](../LocalComparison/Review/rtas-nonreplenishing-210/delivery.json)

T3／G3 已关闭精确投影覆盖改变后漏报远处接收面的更新缺口。实际 Unity 对照中，软域覆盖约 12 单位外的地板，地板获得缓存更新优先级。纯 RGB 控制仍只影响近域。[对照与范围](../LocalComparison/Review/cutout-shadow-change-209/result.md) · [同源交付](../LocalComparison/Review/cutout-shadow-change-209/delivery.json)

T6／G4 已关闭后序相机的同源动态贴图上传保留被前序相机消费的问题。实际 C# 旧新对照中，固定三相机按原帧额度轮流录制各自的动态复制，静态页通过原完成门共享。[对照与范围](../LocalComparison/Review/shared-dynamic-upload-208/result.md) · [同源交付](../LocalComparison/Review/shared-dynamic-upload-208/delivery.json)

T2／G4 已关闭普通 Lit 未赋值 BaseMap 时，高度图待定阻塞精确表面裁剪的缺口。默认白底图由材质 alpha 确定覆盖，确需视差采样的已赋值底图仍按原依赖判定。采用范围为软件精确追踪与 DXR 共用的覆盖函数。[对照与范围](../LocalComparison/Review/default-base-alpha-207/result.md) · [同源交付](../LocalComparison/Review/default-base-alpha-207/delivery.json)

T6／G4 关闭共享 RTAS 构建额度为零时仍准备无效计划并占用预留的缺口。冷请求提前回退，已建且仍匹配的 RTAS 可复用，位姿变化与同帧收紧沿原安全退休。适用范围为实际 C# 准入与命令录制。[对照与范围](../LocalComparison/Review/rtas-zero-build-quota-206/result.md) · [同源交付](../LocalComparison/Review/rtas-zero-build-quota-206/delivery.json)

T6／G4 补上相机图卡录制的 CPU 时间准入。启用后在完整卡之间延期，延后卡保持待捕获，旧来源仍立即失效。功能证据覆盖实际 C# 命令和就绪上传。实际成本、其他阶段及生产预算继续验收。[对照与范围](../LocalComparison/Review/surface-capture-recording-204/result.md) · [同源交付](../LocalComparison/Review/surface-capture-recording-204/delivery.json)

T5／G4 已关闭独立分页组在相机首次出域时仍提交旧组的路径。实际 Scene 对照中，跨界相机的旧粗根失去提交资格，域内相机的细节和共享绑定保持。采用范围为 CPU 栅格收集。高速冷入首显仍按原条件验收。[对照与范围](../LocalComparison/Review/streamed-hlod-cull-range-202/result.md) · [同源交付](../LocalComparison/Review/streamed-hlod-cull-range-202/delivery.json)

T3／G3 已关闭新 Skin 发布后仍被旧 Renderer 引用挡住的自动接源缺口。真实 Unity 对照覆盖待校验和重新启用，两条入口随后都把新 Renderer 及同一份 Mesh、SDF 和图卡交给 Scene。采用范围为组件生命周期及真实场景准备。[对照与范围](../LocalComparison/Review/replaced-renderer-rebind-201/result.md) · [同源交付](../LocalComparison/Review/replaced-renderer-rebind-201/delivery.json)

T6／G4 已关闭动态图卡在逐槽来源配置相同时仍反复销毁和重建捕获材质的缺口。实际 C# 对照确认动态像素继续触发失效和预算内捕获，配置变化仍更换材质，无效来源仍撤销图卡。采用范围为 CPU 准备及材质对象生命周期。[对照与范围](../LocalComparison/Review/dynamic-card-material-200/result.md) · [同源交付](../LocalComparison/Review/dynamic-card-material-200/delivery.json)

T6／G4 已关闭 Global SDF 对每块保留砖重复展开所有脏区的 CPU 准备缺口。相同输入的旧源码和候选源码失效相同的 55 块砖，页代次、就绪、年龄和重建提交序列一致。受控脏范围读取从 348 次降到 6 次。完整分阶段时间预算和实机耗时继续验收。[对照与范围](../LocalComparison/Review/global-sdf-dirty-rows-199/result.md) · [同源交付](../LocalComparison/Review/global-sdf-dirty-rows-199/delivery.json)

T5／T6／G4 已关闭近似旧组向精确细节接替时绕过 RTAS 等待的问题。实际 C# 回归覆盖有三角余量的等待和计费、就绪撤销、空场首发及余量不足时的发布。原生画面和高速冷入首显继续验收。[对照与范围](../LocalComparison/Review/hlod-mixed-exact-198/result.md) · [同源交付](../LocalComparison/Review/hlod-mixed-exact-198/delivery.json)

T5／T6／G4 已关闭前序 RTAS 请求导致的提前接替。即使本帧构建名额尚空，后排相机也保留完整旧组。实际 C# 对照确认前序相机先构建，当前相机随后整组接替并计费。[对照与范围](../LocalComparison/Review/hlod-rtas-older-197/result.md) · [同源交付](../LocalComparison/Review/hlod-rtas-older-197/delivery.json)

T3／G3 已关闭相机切换可见层时可能继承旧屏幕累计的缺口。定向回归验证同坐标掩码变化拒旧、未录制帧无法推进，以及新掩码成功录制后的恢复。画面残影幅度按原范围验收。[回归](../LocalComparison/Review/camera-culling-history-196/result.md) · [同源交付](../LocalComparison/Review/camera-culling-history-196/delivery.json)

T6 已关闭 Global SDF 禁用后仍准备裁剪图的预算缺口。关闭时只绑定占位缓冲，旧裁剪图在完成前保持计账，重新开启从未知页开始。采用范围为实际 C# 调度器及受控完成信号。[启停回归](../LocalComparison/Review/global-sdf-off-195/result.md) · [同源交付](../LocalComparison/Review/global-sdf-off-195/delivery.json)

T6／G4 已关闭仍有需求的分页绑定在目标失效后无法退休的问题。实际 C# 回归确认旧代理撤出，租约等最后读者完成再排空。从未绑定的成员继续声明原组关系。修复进入 Release168。[回归与范围](../LocalComparison/Review/failed-streamed-destination-194/result.md) · [同源交付](../LocalComparison/Review/failed-streamed-destination-194/delivery.json)

T2／G4 已补齐同一固定几何中精确软件 BVH 与有符号 SDF 的真实最近命中。软件三角在后时选择较近盒面，在前时保留三角及来源身份。与既有 DXR 记录各自采用，普通相机画面及其他混合输入继续验收。[实机读回和范围](../LocalComparison/Review/software-signed-sdf-193/result.md)

T6／G4／G5 已补齐统一三室原热态 HLOD 接替及退休的 GI／显存预算。路线两方向均完成接替，合并窗口达到原定两项门槛。冷入首次完整表示和应用 Present 各自验收。[实机结果和范围](../LocalComparison/Review/hot-hlod-budget-192/result.md)

T3／G3 已关闭代理停用期间替换同对象 Collider，重新启用后漏接的缺口。两次正常启停的 Unity 对照中，旧版退回代理中心 55 且未发布，修复版启用即绑定，首次准备采用中心 6 和 X 半尺寸 1。该序列无需待校验。[对照与范围](../LocalComparison/Review/collider-reenable-191/result.md) · [Release167 同源交付](../LocalComparison/Review/collider-reenable-191/delivery.json)

T3／G3 已关闭已绑定 Renderer 销毁后中断相机准备的缺口。实际 DX12 相机从当前 Collider 边界继续准备，另一精确对象仍参与 DXR，活动 Shadowmask 正常进入当帧路径。[实机对照与范围](../LocalComparison/Review/destroyed-renderer-fallback-190/result.md) · [Release166 同源交付](../LocalComparison/Review/destroyed-renderer-fallback-190/delivery.json)

T3／G3 已关闭活动代理在普通校验后漏接同对象 Collider 的缺口。真实 Unity 对照中，新组件中心为 2。旧版消费待校验后仍保留中心 55 的边界，修复版在当次准备绑定并按实际边界发布。[正常校验对照](../LocalComparison/Review/pending-collider-validation-189/result.md) · [Release165 同源交付](../LocalComparison/Review/pending-collider-validation-189/delivery.json)

T6 已去掉确定在域外的普通代理对本相机的无效实例刷新及候选入队。Unity 实际场景准备中，候选和查找表均从 7 项降到 3 项。共享网格通知、第二视点的当前材质、重新入域及已有 HLOD 根预热继续成立。证据限准备行为，耗时和完整预算仍待验收。[对照与范围](../LocalComparison/Review/far-ordinary-prepare-188/result.md) · [Release164 同源交付](../LocalComparison/Review/far-ordinary-prepare-188/delivery.json)

T5／T6／G4 已关闭共享 RTAS 构建次数耗尽时，有精确目标的 HLOD 提前接替。双 Base 实机中，修复在耗尽帧保留完整旧根及同一照明代次。取消时撤销等待，竞争相机同帧取得构建名额。继续竞争时，等待相机按原队列取得唯一名额，两件细节达到当前照明门后一起接替。[实机对照与范围](../LocalComparison/Review/hlod-rtas-turn-187/result.md) · [Release163 同源交付](../LocalComparison/Review/hlod-rtas-turn-187/delivery.json)

T5／G4 已关闭 HLOD 接替时新增普通对象抢走整组已就绪图卡的问题。实机固定七卡，旧版刚发布的两件细节各从一张有效卡降到零。修复版在接替及下一帧保持两张原卡与原有普通页，退出后新对象正常取得六张。证据限单相机 DX12 Editor 的精确软件追踪。[实机对照与范围](../LocalComparison/Review/published-hlod-card-retention-185/result.md) · [Release162 同源交付](../LocalComparison/Review/published-hlod-card-retention-185/delivery.json)

T5／G4 已关闭统一示例收到当前整组撤回回执后仍持续提交旧细节的问题。同一保存场景把实例容量从 64 改为 63，旧版在 GI 发布为零时下一次相机仍可提交三件，修复版为零。实际完整发布后整组三件一起恢复。证据限单相机 DX12 Editor 的提交资格。[实机结果与范围](../LocalComparison/Review/withdrawn-sample-raster-184/result.md) · [Release161 同源交付](../LocalComparison/Review/withdrawn-sample-raster-184/delivery.json)

T3／G3 已关闭渲染图在传输录制前中止后，世界缓存仍接受旧照明的问题。实际 DXR 复用同一相机和管线，恢复两帧的旧红峰值从 0.030／0.024 降为 0／0，两帧仍有当前代次的有效条目。Astra Max 同意采用拒旧和恢复推进。蓝信号正控制不足，完整新色恢复继续验收。[实机读回](../LocalComparison/Review/aborted-world-preparation-183/result.md) · [Release160 同源交付](../LocalComparison/Review/aborted-world-preparation-183/delivery.json)

T6／G4 已补齐固定双 Base 相机争用贴图额度的原生进展。实际 DXR 下，A 首帧用满 1 MiB，随后让位，B 录制 128 B。原生回读确认后，B 零复制复用同一页和代次，A 恢复满额上传。采用范围为共享额度、公平、实际完成和复用。Release159 保持现有交付。[实机结果与范围](../LocalComparison/Review/native-camera-texture-turn-182/result.md)

T6／G4 已关闭最后一个 GI 相机销毁后状态滞留的问题。实际 DX12 Editor 中，存活的手动相机在空闲时保留状态。销毁后没有新增渲染上下文，管线仍在，相机状态脱离，历史纹理句柄释放，RTAS 与相机属性账目归零。Astra Max 同意按单相机真实空闲回收采用。修复已进入 Release159。[实机结果与范围](../LocalComparison/Review/destroyed-camera-idle-181/result.md) · [同源交付](../LocalComparison/Review/destroyed-camera-idle-181/delivery.json)

T3／G3 已关闭硬失效域旧值在同一世界迭代中写回其他图块的缺口。实际着色器对照中，匹配标签和图卡代次的旧红值仍被旧版读取，修复版只留下域外蓝值。Gather 的本轮重建输入仍可读取，软域与位姿跳变沿用原规则。修复已进入 Release158，采用范围为读取资格和绑定。实机画面、收敛与性能继续验收。[着色器对照](../LocalComparison/Review/hard-cache-input-180/result.md) · [同源交付](../LocalComparison/Review/hard-cache-input-180/delivery.json)

T3／G3 已关闭同一精确后端内单对象切换表示时漏发局部失效的问题。实际 DXR 固定机位的离屏墙退出和恢复精确三角时，旧版都没有局部域。修复版两次各录制一条墙体几何域，地板调度优先级为 751，保持帧回到零，世界 epoch 保持。修复已进入 Release157，采用范围为录制与局部调度，像素残留、收敛和软件精确路径继续验收。[实际对照](../LocalComparison/Review/exact-membership-179/result.md) · [同源交付](../LocalComparison/Review/exact-membership-179/delivery.json)

T6／G4 已关闭超出 RTAS 突发上限的构建在准备阶段占用共享预留的问题。同额度对照中，旧版占用 67,904 B 并挡住后置小相机。修复版在读取顶点和分配属性前回退，小相机完成一次录制。已建未变结构继续使用，位姿变化后按原条件退休，恢复上限后可重新构建。修复已进入 Release156，采用范围为实际 C# 准入与受控录制和退休。[实际对照](../LocalComparison/Review/rtas-burst-preflight-178/result.md) · [同源交付](../LocalComparison/Review/rtas-burst-preflight-178/delivery.json)

T3／G3 已关闭共享源的蒙皮实例误撤回。实际 Unity 对照中，关闭 A 的形变组件时 A 回退并交接旧快照，B 保留其 Mesh、SDF、图卡和修订。随后真正编辑共享网格，两个实例均撤回并发布新几何。修复已进入 Release155。采用范围为捕获、失效、发布与退休入账，实体 GPU 画质和延迟继续验收。[实际对照](../LocalComparison/Review/shared-skin-withdrawal-177/result.md) · [同源交付](../LocalComparison/Review/shared-skin-withdrawal-177/delivery.json)

G3 补上了 Release154 初始自动 `BakeMesh` 快照的实际 DXR 命中证据。两条固定射线分别读回预期命中及已知未命中，命中身份与发布来源一致。骨姿改变后，本次从观察器启动起算的 90 秒窗口内未取得新发布，因此无第二次查询，原因未知。形变后的 GPU 消费和画质仍待验收。[查询结果和适用范围](../LocalComparison/Review/native-skinned-hit-175/result.md)

T3／T6 的快速进入 Play 候选已收束。禁用域与场景重载的单次 Unity 无图形序列中，第二轮帧 1 正常启动形变捕获。上次捕获帧已恢复初值，托管引用相同的观察前提未成立。原记录保留证据不足，本次未复现旧帧号延迟。[原始记录和边界](../LocalComparison/Review/deformation-play-frame-176/result.md)

T3／G3 已修复蒙皮对象在显式可读网格请求消费后仍反复捕获和使几何历史失效的问题。旧版在无新请求的首个合格周期启动额外作业。修复后，实际组件 CPU 对照中强请求与后续合并请求各发布一次，模拟释放已复制的借用输入时沿用原快照，主动清除才恢复自动 BakeMesh。修复已进入 Release154。实体 GPU 画质和时延继续验收。[请求合同](DeformedGeometry.md) · [定向对照](../Tests/StandaloneDeformedMesh/Program.cs.txt) · [同源交付](../LocalComparison/Review/explicit-skinned-demand-174/delivery.json)

G4 已关闭 Release153 单三角在顺序提交中的刚体变换原生命中缺口。实际 DXR 的两条固定射线正确交换命中，距离从 1.25 变为 1.75，命中关联当前 owner revision。变换计数增加一次，三角上传和应用场景重建各保持一次。驱动内部算法、在飞更新和形变继续验收。[原生查询和边界](../LocalComparison/Review/native-dxr-rigid-transform-173/result.md)

T4 的旧单页复用位置超差已有后验解释。1/256 像素投影顶点量化后的插值与原覆盖位置读回高度一致，支持连续参考遗漏光栅量化。原冻结位置 FAIL 和 T4 开放状态保留。[原报告及参考复核](../LocalComparison/Review/card-page-reuse-01/result.md#既有位置读回的参考复核)

T6／G5 已取得 Release151 原 F4 固定中室的本机 GI／显存依据。512 个源帧的三段 GI 合计 p95／p99 为 15.936／16.169 ms，local 有限采样峰值 566.191 MiB，达到两项起始预算。PresentMon 无 CSV 且报告 ETW 事件丢失，三项同窗按原停止线以证据不足收束。应用节奏和完整 G5 继续开放。[实测与边界](../LocalComparison/Review/three-room-middle-joint-170/result.md)

T6／G4 的跨相机子项补上了后置材质批次的上传机会。旧实现中，第一个相机在相同 1 MiB 额度下再次用满额度。修复后，第二个相机在原读者完成后录制 128 B 的稳定贴图上传，回执后复用同一来源句柄，第一个相机恢复完整复制。撤回后续请求时，保留额度经过一个等待帧后释放。修复已进入 Release153，结论限实际 Batch／Pool 源码与受控完成回执。实机多相机画面和成本仍待验收。[预算规则](GpuBudget.md#启用与测量范围) · [定向对照](../Tests/StandaloneHitMaterialBatch/Program.cs.txt) · [同源交付](../LocalComparison/Review/cross-camera-texture-turn-172/delivery.json)

T6／G4 已关闭同一精确材质批次中，持续更新的动态贴图用满逐帧额度、后续稳定贴图始终拿不到上传机会的缺口。相同 1 MiB 额度下，旧实现第二帧仍跳过稳定页。修复后第二帧上传该页，受控完成回执到达后，第三帧复用其原句柄，动态页恢复复制。修复已进入 Release152，采用范围为普通材质批次的托管准入逻辑。实体 GPU 继续验收。[调度与适用范围](GpuBudget.md#启用与测量范围) · [前后对照](../Tests/StandaloneHitMaterialBatch/Program.cs.txt) · [同源交付](../LocalComparison/Review/texture-upload-fairness-171/delivery.json)

T2／G4 已取得真实 DXR 与 signed SDF 同射线竞争的有限实机依据。较近的盒面胜过真实远三角，另一条射线仍选择更近的真实三角，两个结果均有当前来源身份。Astra Max 按该静态查询范围采用。普通相机画面和整体 T2／G4 分别验收。[输入与实际读回](../LocalComparison/Review/native-dxr-signed-sdf-169/result.md)

T5／G4 已完成原 Release143 观察构建的一次实机折返。最近点无完整组，回程 7.752 单位首次提交粗根，全程没有完整细节接替，离场页账排空。78.670 秒回调间隔跳过全部域内去程采样。高速首显保持开放，按一次观察的范围保留结果。[实机与判定边界](../LocalComparison/Review/cold-crossing-143/result.md)

T6／G4 已关闭相机状态重建时漏记旧软件属性与 BVH 的缺口。实际 Feature 准入与 BVH 代码在 1 MiB 下复现两代 1,280,832 B。修复后保留仍适配的属性，BVH 等旧代释放再准入，另一相机仍独立。Astra Max 同意按托管逻辑准入范围采用。真实双相机 GPU 成本与总显存分别验收。[前后对照](../LocalComparison/Review/camera-software-geometry-budget-168/result.md) · [同源交付](../LocalComparison/Review/camera-software-geometry-budget-168/delivery.json)

T6／G4 已关闭相机状态重建时漏记旧 DXR 属性缓冲的缺口。同一实际 Backend 对照在 1 MiB 下由两代 1,152,392 B 改为等待安全释放，另一相机仍可独立准入。Astra Max 同意按逻辑准入范围采用。原生双相机负载和总显存分别验收。[前后对照](../LocalComparison/Review/camera-dxr-attribute-budget-167/result.md) · [同源交付](../LocalComparison/Review/camera-dxr-attribute-budget-167/delivery.json)

T6／G4 已关闭关闭域重载时旧帧预算阻塞再次 Play 的缺口。Unity 无图形对照中，第二轮第 1 帧恢复纹理上传与 RTAS 构建准入，受控退休预留保留到完成回调。Astra Max 同意按 Editor 生命周期与托管准入采用。实际 GPU 围栏跨会话和完整 G4 各自验收。[前后对照](../LocalComparison/Review/play-frame-admission-166/result.md) · [同源交付](../LocalComparison/Review/play-frame-admission-166/delivery.json)

T2 已修复共用精确材质采样在应用 mip 偏移前夹取正足迹 LOD 的问题。实际 WARP 覆盖入口的两端裁切改为符合预期，零足迹对照一致。Astra Max 同意按此范围采用。完整材质派发曾到等待上限，实体 GPU 与画面继续验收。[输入、读回与范围](../LocalComparison/Review/mip-bias-footprint-165/result.md) · [同源交付](../LocalComparison/Review/mip-bias-footprint-165/delivery.json)

T2／T3 已关闭待定副本使同源就绪贴图被误判为未知的问题。实际材质批次复用了原缓冲和原代次，原在途副本继续计账。收紧额度后原待定路径仍成立。Astra Max 同意按资源选择与句柄范围采用。实际颜色及动态收敛继续验收。[前后对照](../LocalComparison/Review/ready-texture-pending-copy-164/result.md) · [同源交付](../LocalComparison/Review/ready-texture-pending-copy-164/delivery.json)

G4 已关闭多件几何同帧变动、上传额度不足时的部分 HLOD 提交。实际 Scene／BVH 对照中，旧版让两件进入追踪，修复后整组先撤回，三个当前回执齐备后一起恢复。额度足够的同帧完整更新继续提交。Astra Max 同意按 CPU 资格采用。原高速首显与普通 Player 画面继续验收。[实际对照](../LocalComparison/Review/partial-hlod-upload-163/result.md) · [同源交付](../LocalComparison/Review/partial-hlod-upload-163/delivery.json)

T6／G4 已补上对象 SDF 图集的跨相机逐帧上传额度。受控 C# 对照中，两份冷图集的同帧体素提交从 2 MiB 降到 1 MiB，晚准备的图集随后取得额度。失败的复制尝试仍占当帧额度。Astra Max 同意按逻辑准入范围采用。真实上传带宽、全阶段预算及高速首显仍待各自验收。[同输入对照](../LocalComparison/Review/sdf-frame-upload-162/result.md) · [同源交付](../LocalComparison/Review/sdf-frame-upload-162/delivery.json)

T6／G4 已关闭活跃相机在 DXR 异常后继续占用共享额度的缺口。实际 C# 对照在已绑定几何的下一帧注入构建异常，失败相机继续回退，完成回调前旧资源仍计账，完成后健康相机可以准入。Astra Max 同意按功能范围采用。Unity 原生异常和真实 GPU 排空仍待各自验收。[异常前后对照](../LocalComparison/Review/rtas-failure-retirement-161/result.md) · [同源交付](../LocalComparison/Review/rtas-failure-retirement-161/delivery.json)

T5／T6 的世界缓存调度已关闭已确认空格占用逻辑照明配额的缺口。现有回读确认空格后，相同两格配额在实际 C# 对照中从一空一实变为两格有覆盖，零样本覆盖格仍可更新。旧代次拒绝、重捕获恢复和原发布年龄门均保持。Astra Max 同意按这一功能范围采用。原高速冷入首显和真实性能仍待验收。[同额度对照](../LocalComparison/Review/empty-cache-patch-budget-160/result.md) · [同源交付](../LocalComparison/Review/empty-cache-patch-budget-160/delivery.json)

T6／G4 补上接收面发现与重验原先缺少的 CPU 时间准入。一个相机图内共享累计额度，默认关闭。实际运行时 C# 对照证明重验能耗尽余量并停止下一件来源检查，原生资格拒绝不完整输入，下一次足额扫描恢复。Astra Max 同意按此范围采用。已开始的 Unity 调用仍会完成，整帧 CPU 时间、其他阶段和完整生产预算分别验收。[实际源码对照](../LocalComparison/Review/receiver-discovery-budget-159/result.md) · [同源交付](../LocalComparison/Review/receiver-discovery-budget-159/delivery.json)

T3／G3 已关闭普通 BaseMap 等待匹配页回读时整次回退的问题。固定离屏墙的实机等待帧仍录制 DXR，世界缓存 epoch、精确网格及独立已确认地板贴图保持一致。蓝贴图在等待时保留指定标记和零句柄，真实回读完成后复用原页。换色仍触发原局部更新。Astra Max 同意按此功能范围采用，并复用旧裁切等待控制。画面残留、收敛及正式性能分别验收。[实际等待与恢复](../LocalComparison/Review/pending-exact-texture-158/result.md) · [同源交付](../LocalComparison/Review/pending-exact-texture-158/delivery.json)

T3／G3 已关闭已发布精确网格因无图卡而漏报 BaseMap 换色的问题。固定离屏墙的实际 DXR 请求中，旧版读到新蓝贴图后仍无局部事件。修复版同帧写入一个墙体局部照明域，把附近地板缓存优先级提高到 751。等现有纹理回读完成后，下一次仍走 DXR 的请求恢复为零。Astra Max 同意按材质通知与调度的范围采用，画面残留、收敛用时及生产预算分别验收。[实际对照](../LocalComparison/Review/cardless-material-157/result.md) · [同源交付](../LocalComparison/Review/cardless-material-157/delivery.json)

T6／G4 已关闭组等待优先级丢在实际页启动之前的问题。实际 CPU 驱动与调度器的受控对照中，持续请求页由 65 步内未启动变为第 61 步启动并达到 Ready。两层纯预取依赖在中间页仍在飞时保持低优先级。Astra Max 同意按此范围采用，修复已进入 Release139。原高速首显和正式预算仍开放。[前后对照](../LocalComparison/Review/streamed-page-priority-156/result.md) · [同源交付](../LocalComparison/Review/streamed-page-priority-156/delivery.json)

Release138 关闭两个独立缺口。T2／G4 中，无足迹的已知透明前板在实际精确软件及 DXR 查询中正确露出蓝后面，依赖纹理的未知覆盖仍保守遮挡。T6／G4 中，收紧每步启动额度后可复用 Ready 共享页，已读完的包可继续上传，实际 CPU 调度验证了总容量与退休门。Astra Max 同意按各自范围采用。高速冷入、普通 Player 画质及正式预算分别验收。[两项对照与范围](../LocalComparison/Review/exact-footprint-and-page-admission-155/result.md) · [同源交付](../LocalComparison/Review/exact-footprint-and-page-admission-155/delivery.json)

T5／G4 已关闭统一示例在粗根未绑定时挡住完整近景细节的准入缺口。真实分页的无图形对照中，粗根声明有效且无资产，三件细节齐备后全组可进入准备，受控完整回执后才整体可提交。Astra Max 同意按该范围采用，修复已进入 Release137。原高速冷入路线的粗根预热中断和首显仍开放。[实际对照与范围](../LocalComparison/Review/cold-detail-admission-154/result.md) · [同源交付](../LocalComparison/Review/cold-detail-admission-154/delivery.json)

T6／G4 已修复最后一次渲染后，启用中的分页绑定撤回需求仍滞留的问题。单个真实页组在 DX12 Editor 的零新上下文内保持有效消费者，再于其退出后通过实际空闲栅栏排空。CPU 回归补齐重新请求的及时保护和停用再启用后的待查。Astra Max 同意按该范围采用，修复已进入 Release136。普通 Player、多组负载和高速冷入分别验收。[原生对照与范围](../LocalComparison/Review/idle-demand-retirement-153/result.md) · [同源交付](../LocalComparison/Review/idle-demand-retirement-153/delivery.json)

T6／G4 已修复活动 Base 相机切换 URP Renderer 后，旧 GI 状态阻止资源页归还的问题。真实 DX12 双 Base 自动渲染中，第二台仍使用旧 Renderer 时租约保留。最后一台切走后，实际页先解绑再经原生栅栏归还。旧版同输入在后续 24 个实际上下文仍锁住页面。Astra Max 同意按单组范围采用，修复已进入 Release135。生产预算及多组负载分别验收。[原生对照与边界](../LocalComparison/Review/renderer-switch-retirement-152/result.md) · [同源交付](../LocalComparison/Review/renderer-switch-retirement-152/delivery.json)

G4 关闭默认独立导出 HLOD 在普通渲染同时画出粗根和细节的缺口。真实 DX12 双 Base 显式请求中，近相机只提交其完整细节，远相机只提交其粗根，旧根等待及停叶整组撤回均符合约定。相机错过解绑时也会拒绝重绑的新代沿用旧发布。Astra Max 同意按此范围采用，修复已进入 Release134。T5 高速首显、普通 Player 和生产预算分别验收。[原生对照与边界](../LocalComparison/Review/independent-hlod-raster-151/result.md) · [同源交付](../LocalComparison/Review/independent-hlod-raster-151/delivery.json)

G4 已修复已发布的细节重挂后仍占用旧组、阻塞新组的缺口。实际 Scene CPU 回归在 Release132 源码复现问题，Release133 整组撤回旧表示，新组在旧粗根未就绪时按原回执发布。成员撤回后退回预热的同版本成员也需要新回执。Astra Max 同意按此范围纳入普通运行包和可编辑工程，实际 GPU 回执、普通 Renderer 显隐和高速冷入分别验收。[事务合同与回归入口](HlodStreaming.md#atomic-hlod-transactions) · [同源交付](../LocalComparison/Review/retained-hlod-membership-150/delivery.json)

T3／G3 已修复同一蒙皮源网格在明确内容通知后仍可使用旧自动快照的问题。实际版本服务与组件的 CPU 回归在 Release131 复现旧版本留存，Release132 撤回旧快照、取消旧作业并按原流程恢复。Astra Max 同意按明确通知的来源资格范围采用。修复已进入普通 Win64 包和同版可编辑工程，原生退休、响应时间和画质分别验收。[形变流程与验证](DeformedGeometry.md) · [同源交付](../LocalComparison/Review/notified-skin-source-149/delivery.json)

T6／G4 已修复零启动配额下销毁资源驱动后无法排空的问题。同输入 CPU 回归在 Release130 复现旧页滞留。Release131 遵守活驱动的暂停配置，在销毁后完成在途逻辑 I/O、等待安全归还、排空并允许新驱动接管。Astra Max 同意按 `startsPerStep=0` 的受控范围采用，修复已进入普通包，原生 I/O 与 GPU 生命周期各自验收。[资源流程与回归](IndependentAssetPages.md#publication-and-lifetime) · [同源交付](../LocalComparison/Review/paused-page-driver-148/delivery.json)

T3／G3 已修复同帧相机回调换源或清空后的旧快照使用。实际组件 CPU 回归用模拟 Context 完成验证撤回、取消和原预算下恢复，旧版在同一替换输入复现旧快照。Astra Max 同意按来源资格范围采用，已进入 Release130 普通包。实体 GPU 退休、实时姿态和形变画质仍分别验收。[形变流程与回归](DeformedGeometry.md) · [同源交付](../LocalComparison/Review/skinned-camera-source-147/delivery.json)

T2／G4 关闭精确命中截断 SDF 搜索时，未检查末段被判为确定空区的功能缺口。实际追踪和混合查询 HLSL 在 WARP 上用同一闭盒输入对照。Release128 选择 0.00968333 处的后方精确三角，Release129 恢复 0.00841055 处的近 SDF 命中。预算真正耗尽时返回未完成。Astra Max 同意按该范围采用，精确后端结果为受控输入，原生 DXR 和最终色墙画面仍分别验收。[同一输入与结果](../LocalComparison/Review/sdf-clipped-interval-146/release-notes.md) · [同源交付](../LocalComparison/Review/sdf-clipped-interval-146/delivery.json)

G4 关闭默认独立分页导出在细节分批到达时的 GI 发布缺口。Release127 的同一实际 Scene 回归复现了单件替掉有效粗根和单件走普通代理提前发布。Release128 依据启用绑定识别作者组，等完整细节收到原回执再接替。粗根未绑定时，完整细节也可按原距离及回执发布。Astra Max 同意按 CPU 准入范围采用。普通 Renderer 显隐、实际异步加载及 110 高速首显继续按原条件验收。[回归范围](../LocalComparison/Review/streamed-hlod-membership-145/release-notes.md) · [同源交付](../LocalComparison/Review/streamed-hlod-membership-145/delivery.json)

T6／G4 关闭驱动销毁后，仍活动的流式绑定无法处理需求撤回、旧页持续占用全局预算的功能缺口。回归覆盖实际绑定、驱动和页调度代码，I/O 与读者完成由适配器提供。原安全完成后页排空，新驱动可以接管。Release127 已将修复纳入普通 Win64 与同版可编辑工程。Astra Max 同意在该范围采用，原生退休及其他负载继续按各自已有证据和原验收条件处理。[修复范围](../LocalComparison/Review/streamed-driver-withdrawal-144/release-notes.md) · [同源交付](../LocalComparison/Review/streamed-driver-withdrawal-144/delivery.json)

G4 关闭统一示例在流式成员撤回后仍可部分提交旧组、重绑后可借用旧可见记录的缺口。无图形 Unity Play 实际完成资产页绑定，覆盖旧完整根等待、任一细节停用整组隐藏、同 Proxy 换代拒旧、新完整输入恢复和销毁组件后仍存活的 Renderer 隐藏。Release126 已交付普通 Win64 和同版工程，照明回执为受控输入，实际相机和冷入首显继续按原条件验收。[原始状态](../LocalComparison/Review/streamed-group-visibility-142/result.json) · [同源交付](../LocalComparison/Review/streamed-group-visibility-142/delivery.json)

T6／G4 补齐固定粗根在最后一次相机提交后原生退休的实机依据。Release125 实现明确停用后的空闲检查，Release126 同源 DX12 Editor 已实测真实空闲栅栏通过和 6 个页引用排空。停用到排空零新渲染上下文。实际范围为单个固定粗根，其他负载和整体 G4 保持开放。[原生票据与账目](../LocalComparison/Review/streamed-idle-native-143/result.md) · [Release125 同源交付](../LocalComparison/Review/streamed-idle-retirement-141/delivery.json)

T3／G3 关闭同一 SkinnedMeshRenderer 更换或清空来源网格后继续使用旧 GI 形变快照的功能缺口。Release124 在帧级渲染准备撤回旧 Mesh／SDF／图卡、取消旧作业，并由原预算接纳替换网格。实际组件 CPU 回归和同源普通 Win64 构建均已通过。已交付运行包与可编辑工程，形变画质、真实 GPU 退休和整体 G3–G5 保持开放。[功能修复](../LocalComparison/Review/skinned-source-replacement-140/release-notes.md) · [同源交付](../LocalComparison/Review/skinned-source-replacement-140/delivery.json)

2026-11-08，Unity Personal 授权恢复，原 G3 固定两室关门恢复子项已关闭。Release122 基线在约 2 秒仍有 10.33% 暖光残留。两个 Gather 点确认大部分余量在时域输入中已存在。采用的修复按同源几何范围识别门的跳变，避免已受影响的旧光继续递归。修复在 1 秒和 2 秒前最后源的残留分别为 2.637% 和 0.214%，首个 1% 保持窗为 1.373–1.894 秒，保持至 2.612 秒末点。首候选误用含 SDF 留边的遍历范围，未触发，其记录保留。Astra 同意整合实测源码。完整 G3–G5 保持开放。[同曝光画面与适用范围](../LocalComparison/Review/portal-recovery-138/result.md)

Release123 将修复纳入统一 Windows 演示和同版可编辑工程，关闭这次修复与成品的交付差。普通构建使用同一工程 ZIP 的干净解压目录，离线画册同时收入关门前后对照及读数。[构建和发布记录](../LocalComparison/Review/portal-recovery-138/delivery.json)

T2／G4 补齐原第 9 节的一个镜像子网格行为。Release123 同源实机的精确软件 BVH 与 DXR 各自按来源 Cull 跳过不合法近层，沿 +Z 命中蓝色正面，沿 −Z 命中红色背面。距离、来源身份和材质均符合预期。镜像光栅、图卡和混合回退保持开放。[固定输入与原始读回](../LocalComparison/Review/mirrored-submesh-cull-139/result.md)

T7关闭统一离线画册入口缺少已有成果的交付缺口：同一静态读图页现已整合133当前同源颜色、126／127／129的秒级残留和126／134恢复，明确D／Final、棕墙描述偏差、White控制不足和门四时点范围，并以2026-11-04补充包附加到Release122。Astra审阅同意收束，未新增图、Runtime或画质验收；浏览器可视检查被本地URL策略阻止，源内容与引用文件准入不能替代可视检查。2026-11-08 的关门恢复结果由本仓库当前画册入口链接，旧补充包记录当时的交付范围。[统一入口](../LocalComparison/Review/picture-comparison.html) · [交付与限制](../LocalComparison/Review/picture-delivery-20261104/result.md)

原G1的代表性传输验收现已关闭。Astra Max与独立进度审阅按原第6节条件复核：133补上当前Runtime的匹配颜色参考，既有材质／hit、合成、白炉、黑／金属、有限反馈链和封闭室关断提供其余代表依据，没有再识别出具体阻断行为。此前“拟声明全域颜色／能量准确性”的泛化表述不再作为无限前置；保留各原版本、ROI、unknown、模型不确定性与未完整协议，不把代表输入通过扩成全部Lit／三室全像素或第8／9节专项通过。本轮关闭的是原关卡决策缺口，没有新增测试、改Runtime或重建122。[逐项裁决](ProductionPlan.md#g1本机代表性传输验收裁决)。下文保留历史阶段当时的判断，当前以本段为准；G3–G5及专项仍开放。

136没有关闭原定“full变、GI不变”的resize缺口。唯一实际观察虽正常退出、105源连续且三票／恢复完成，但原128MiB配置下GI从820×460变为819×460，未保持预估959×539；主线程遗漏预算尺寸约束的准备疏漏保留。95有成熟32帧历史，96／97分别只出现0..1／0..2年龄，可描述本次full与GI共同变化后的重置／新累计，不能归因full上下文或替代原定子项通过。Astra同意保持不足后收束，不改预算、补跑或新增修复；完整G3仍开放。[实际尺寸、年龄及未关闭项](../LocalComparison/Review/resize-history-136/result.md)

T3／T6补上原默认活动Skin的同窗成本及CPU首次观测帧龄依据。当前122同源普通测量Player、24顶点／12三角／2骨的K+Space已预热负载，GI三区间逐源合计p95／p99为17.088／18.115ms，进程local／nonlocal有限采样峰值572.004／303.688MiB，达到25ms／1GiB起始预算；同次30秒应用Present平均63.042Hz、间隔最大27.078ms。205个新CPU快照的捕获到首次观测帧龄p95为11帧、最大12帧，不是全部渲染帧的快照年龄或GPU延迟。Astra同意有限采用并收束；观察开启、约76秒首次camera回调、可选截图未交付及收尾pending2各自保留，不能称画质、冷启动或清理通过。不改Runtime／公开122，不补图或扩大模型；形变质量、BakeMesh耗时、GPU消费延迟及整体G3–G5仍开放。[原始窗口及边界](../LocalComparison/Review/active-skin-cost-01/result.md)

T3补上原红墙反射率换蓝事件的Floor有限恢复依据：当前122同源Runtime、原640×360场景和同工作帧蓝前史控制下，固定地板均值在1.142–1.654秒形成首个合格保持窗口，后续观测至2.612秒未再越线。White控制平均Y波动9.03%超过事前5%，其恢复不采用，整体保留控制不足；没有延长控制、放宽门槛或GPU补采。Astra同意部分采用并结束，未改产品；原G3及普通Player等范围仍开放。[同量D、源帧及控制资格](../LocalComparison/Review/reflected-color-response-01/result.md)

G5／T7关闭当前支持说明过时、边界分散的交付缺口。[支持主表](ProductionPlan.md#当前支持范围与证据层级)现以Release122／7c08327为交付来源，将历史结果、代码拒绝、有限观察和实测未通过分开；README同步已有颜色／残留／拖影／响应范围、119独立中室Present和122启动入口。Astra同意采用，并补明126／127为约29Hz显式请求、非普通Player性能，以及工程收敛判据不要求数学上精确收敛。复用现有报告、包与迁移说明，没有新增Unity、构建、采样或哈希核对；原承诺及整体T7／G5未完成状态保留。

T2／G1补上当前Runtime在原归档119场景、两个固定ROI的有限静态颜色依据。直接复用原物理资产和有限参考，Floor／White均值亮度偏差−3.075%／−.831%，色向L1 .007976／.033415，MAE比14.69%／8.18%，名义满足事前目标；Floor两个unknown和参考不确定性保留。120前缀收据成功不替代原720协议，指标与93相同不等于所有像素／行为相同；不外推当前三室、960×540、普通Player或完整G1。Astra同意采用并结束本线，无Runtime改动或新版本。[同量画面、原输入和范围](../LocalComparison/Review/archived-runtime-color119-01/result.md)

T4补齐同一GPU页A→B换源的有限身份／覆盖／binding与旧锚点清除依据：实际复用card0，来源和两种代次更新，旧mesh查询拒绝，两个原有锚点格在B确定空后写为无效。**完整冻结合同未通过**：位置最大误差A约2.95e−5、B约4.53e−5，超过固定2e−5；不改阈值，也不直接归因产品错误。A请求pending不证明GPU实际重叠或普遍同步安全。Astra同意采用子结果并结束，无Runtime改动／新版本，整体T4仍开放。[图集、实际数值及未通过项](../LocalComparison/Review/card-page-reuse-01/result.md)

G1第6节基础合同现已在已有本机代表输入上取得有限通过依据：131普通Player的原生regular checker／smoothness-alpha全实区别真实生效，GI captureDepth逐像素一致，域内无未知材质，来源颜色正确；130已补非零workflow／map传递。Astra同意整合本轮进展并结束材质观察。完整G1仍受拟声明支持域的静态颜色／能量准确性与未完整原协议限制，不拼不同版本结果称当前全域通过，不因版本或协议字样自动补跑。[关卡裁决与联合轮廓](../LocalComparison/Review/player-alpha-smoothness-01/result.md)

G1 补齐原列 metallic／specular 标量和贴图网格的普通 Win64 Player 捕获／合成依据。独立rho分别为.48／0／.47812／.75／0／.74902，实际出射约.47820／0／.47820／.74866／0／.74866，均满足冻结容差；零域具有覆盖及已知材质，非零域D≈.99951且无unknown。实际为空世界软件、MPB shader-space输入，不推广到世界hit／DXR或全部作者颜色。Astra同意采用收束，无Runtime改动或公开发版；G1增量复核仍未整体放行。[画面、原协议与剩余范围](../LocalComparison/Review/player-material-workflow-01/result.md)

G1／G3 补齐已有封闭反射房间先有间接光、再关闭唯一点光的有限衰减依据。固定九点在1／2秒前旧绿均值剩0.04606%／0.004056%，后续源保持目标，2.618秒末端实际filteredD有效。该事件按局部点光移除验收，未用全局5秒期限；没有直接观察worldcache、fresh raw或所有中间filtered状态，不能外推任意房间／稳态。首次未Play的准备失败与离线字段读取错误保留；Astra同意采用并收束，没有Runtime改动或新版本。[同曝光画面、指标与边界](../LocalComparison/Review/sealed-room-decay-01/result.md)

T2／G4 关闭静态普通 Lit 二值 Point／无 mip alpha 的实际候选遍历子项：精确软件和真实 DXR 都穿透明格命中蓝后板、在实心格命中红前板，返回距离、源 UV、三角／owner 身份和已知材质均符合冻结几何／纹理预期。实际纹理页 Ready，无 unknown／回退。纠正了旧文档“CPU alpha 准入仍关闭”的描述；首个观察入口保留字编译错误及无效零输出保留，仅一次更正运行通过。没有修改 Runtime 或发版，不扩写为 Feature／Player 图像、阴影、MSAA／A2C 或完整材质验收。[实际命中、输入及限制](../LocalComparison/Review/binary-alpha-traversal-01/result.md)

G1／G3 的实际固定棕墙／白地板全源关断子项已有有限依据：发行质量、960×540、实际约 29.13Hz 下，1／2 秒前旧绿均值已降至 0.2774%／0.02529%，后续观察保持对应目标；末帧实际 filteredD 有效，仍有极低绿色，不是逐位零。时域标签不等于 raw 新鲜资格，中间 filteredD 未逐帧直读。本次也纠正 126／127 把固定棕墙误写为白墙的描述，保留原合同及数值；全白墙／高反射率条件仍未验证，不能称完全符合原冻结输入。Astra Max 同意只采用实际配置子结果，不补采、不改产品或发版。[结果、有效性和输入偏差](../LocalComparison/Review/all-source-off-response-01/result.md)

G3 补上一个固定换色光路的最终状态恢复时间依据：960×540、发行质量、实际约 29.4Hz 显式请求下，相对同工作帧的长蓝前史产品控制，白地板固定域首个合格区域均值窗口为 0.193958–0.708270 秒，之后到 2.612935 秒未再次越线。窗口起点最差点亮度差仍为 23%，约 2 秒为 1%，因此不是全像素在 0.194 秒收敛。1／2 秒之前旧绿样点也已低于对应残留目标。本项不替代物理颜色、其他光路、门运动或普通 Player／完整 G3；保留零请求入口失败与一次纠正，Astra Max 已同意收束，无产品修改或新版本。[同帧画面、时序与不确定性](../LocalComparison/Review/final-state-response-01/result.md)

G2／T4 的普通静态两槽 Point／无 mip 接缝补上图集与锚点子证据：保存重开后，两侧预定域共 3,420 个像素的颜色及位置未超出原容差，24 个有覆盖锚点位置归属正确（20 个核对颜色、4 个分色边界不判颜色），8 个空单元保持无效锚点。观察脚本漏写四条三角 binding 返回数值，完整冻结合同维持 `insufficient-binding-values`，没有新增关闭整体接缝或 T4 关卡。Astra Max 同意按子范围交付并结束，不补采、不改产品或发版。[结果、冻结条件与记录疏漏](../LocalComparison/Review/material-uv-seam-01/result.md)

G1／T2 关闭一个普通 cutout 输入的屏幕覆盖合同：在 Additive、单采样、运行时 `_AlphaToMask=0` 的固定正交场景，普通 URP 相机与 GI 重绘深度逐点一致，裁空处读到蓝色背板。该结果来自现有 Capture 的同帧数据，不扩写为作者默认 flag 1、smoothness-alpha、Replace、DXR 或 Player 通过。输入导入重置与一次启动准备失败分别保留；有效运行正常结束并恢复设置，没有产品修改，按 Astra Max 审查收束。[覆盖、材料归属与限制](../LocalComparison/Review/ordinary-cutout-coverage-01/result.md)

G1／G3 等待用户数值的依赖已解除。用户授权主线程参考相关实现自主判断；[画质起始判据](QualityAcceptance.md)已依据一手资料制定并经 Astra Max 审查。93 原两个区域名义满足静态目标，历史动态帧数仍不冒充秒级响应。

G3 补齐旧绿残留的源帧时间锚点：在既有 640×360／2 射线／4 级滤波场景，1.000209 秒旧绿均值为切前的 0.0429214%，2.000477 秒输出 G 全零。样点低于对应残留幅度目标，但显式渲染请求节奏较快、采集相邻有约 0.43 秒间隔，不能外推普通 960×540／30FPS；严格截止时刻、新蓝正确性和连续稳定仍开放。唯一运行已正常结束并恢复工程，无新修复依据，不补跑。[实际点值、时序与限制](../LocalComparison/Review/timed-green-response-01/result.md)

按现有完成项去重的[剩余 TODO](RemainingWork.md)已交 Astra Max 审查并按意见收束为七项。T1 的同源整合已完成：Release122 将 `7c08327` 的稳定回退历史修复同时交付为 Windows 包与可编辑工程，关闭已修源码尚未进入可运行包的缺口。普通 Release／None 构建从同版工程 ZIP 的干净解压目录完成，0 个错误、6 条警告；未追加画面、性能或压力运行。[发布与构建来源](../LocalComparison/Review/stable-fallback-history-01/delivery.json)

其余 TODO 保留动态质量、更新延迟及全阶段独立时间预算尚未完成的限制；不把任意跨骨形变连续复用自动列成欠交功能。原计划要求明确形变处理路径，现有骨变拒旧／停稳恢复与完整异步快照是已实现的支持路径，仍须在该范围内验收。清单不自动启动新测试或恢复暂缓工作；完整 G1–G5 仍未放行。

G5 的迁移说明已同步到 Release122：明确固定产品源码 `7c08327`、121→122 沿用有效烘焙与资源页的条件，以及同版源码、作者资产和分页文件的整体回退步骤。历史 Release121 的固定来源 `e1e00d8` 仍单列。说明依据现有工程包与构建记录，未增加任意旧工程的兼容性验收。[升级与回退](Implementation.md#升级已有-unity-工程与回退) · [工程来源](UnifiedUnityProject.md)

**本节点收束：按已有门运动画面交付。** 回看统一示例同一路线、同曝光的 149／179／189／209 帧，保留已采用的 2 射线／4 级滤波：门面和地板云斑较 3 级明显减弱，所示四帧未见明显加重的旧门轮廓。现有图没有给出值得新增修改的单一运动问题，本节点沿用已发布的 Release121 Windows 包、可编辑工程及离线画册。[原图及范围](../LocalComparison/Review/four-pass-local-quality-01/result.md)

本节点没有新增关闭 G3 的运动验收缺口。未采用的纹理等待候选已从工作树和本机 Unity 工程撤回，观察记录保留；它没有统一示例的门运动画面依据。下段稳定回退修复是独立成果，已随 Release122 整合，不作为门运动改善的证据。完整 G1–G5、精确拖尾时长与正确颜色收敛继续保持各自未完成状态。

Release122 整合了 G3 中静止接收面因同一材质预算反复回退而无法积累历史的修复。同机位连续 12 帧采用同一 SDF／解析路径，旧版地板 16 个有效像素的历史长度始终为 1，修复后均累积到 12。换同色小图恢复精确软件的首帧重新从 1 起算。适用范围为此次材质准入与软件路径；这些数据来自既有实际相机观察，并非新增 122 测量。[GPU 历史读回与适用条件](../LocalComparison/Review/stable-fallback-history-01/result.md)

G4 关闭软件几何降预算后无法恢复精确查询的缺口。静态可读网格从 10,000 三角换为 2 三角、预算从 64 MiB 降到 1 MiB 后，旧版在 48 个渲染回调中一直回退。121 通过现有栅栏释放旧 BVH，第三个低预算回调为新网格录制精确追踪，软件几何占用 1,056 B。F2 与面板现在只将与当前请求相符的近期 CPU 传输记录标为实际后端。[同相机对照](../LocalComparison/Review/software-budget-recovery-121/result.md)

120 之后的主干关闭了 G2 中非均匀缩放会翻反折面法线、使同卡三角取不到自己图卡的缺口。一个 X 轴压缩为 0.1 的两三角折面上，第二片的捕获法线与源几何法线点积从 −0.99923 变为 +0.99732，按三角绑定和按位置查找都恢复。更强缩放的倾斜单平面保持原命中与置信度。修复已同步本地可编辑工程。[现场读数与限制](../LocalComparison/Review/folded-chart-facing-01/result.md)
G2 第 6 节的代表场景补上了凹物体内表面的普通反弹画面。红色前框和蓝色内板属于同一视锥外网格；白地板左区平均 R/B 为 0.11972/0.02984，右区为 0.04056/0.10396。结合三室、薄壁、离屏纹理与覆盖诊断，可以收束这一组场景。第 8、9 节的接缝及变换后采样等专项继续开放，G1–G5 整体生产验收尚未完成。[凹口画面与线性读数](../LocalComparison/Review/recessed-wall-material-120/result.md) · [按原条款列出的各项依据](ProductionPlan.md#6-按依赖交付的关卡)

G2 关闭公开烘焙入口与运行时识别不一致的缺口。没有 Renderer 的可读 MeshFilter 烘焙成单个带门洞的网格后，旧版 GPU 将洞口和门柱都判为 3.5 单位处的包围盒。Release120 的洞口射线到达 8.75 单位外的后墙，另一条通过距离场命中门柱，与独立物理三角查询的距离相差约 0.00034 单位。这一项覆盖显式烘焙体，不外推所有凹网格和薄层。[两条射线的命中与适用范围](../LocalComparison/Review/rendererless-baked-doorway-01/result.md)

G1 的灯表容量修复已随 120 纳入普通示例。即使灯的颜色和强度有效，完全空的物体照明集合以前也会占用一个名额，可能挤掉能产生反弹的灯。单槽收集器现已保留有效灯，在最后一盏有效灯失去接收面时移除旧项，关闭渲染层筛选后可以重新接纳相应灯。此项覆盖 CPU 灯表准入与移除通知。[灯光层与准入规则](DirectLighting.md)

统一示例的门运动沿用 2 条射线、4 级空间滤波。对照相同曝光的第 149、179 帧，门面和门前地板的云状颗粒较 3 级滤波明显减少，门脚附近明暗过渡稍柔。停后第 10、30 帧没有看见明显加重的旧轮廓；另一组普通画面里，第 239 帧门回到起点，右侧黑块重新露出。按此范围交付 Release119。现有图无法判断帧间闪烁与很弱的间接光拖尾时长。[间接光四帧](../LocalComparison/Review/four-pass-local-quality-01/comparison.png) · [普通画面的门往返](../LocalComparison/Review/full-dxr-sequence-112/comparison.png)

G3 关闭两个可复现的无效更新。运行时把合成强度减半、切到间接光、返回最终画面，旧版每步都把地板历史清到 1；119 同一批 64 个点始终保持 32 帧。普通可读网格门在末姿已被捕获后停止，两版都发布了正确终姿，119 省去一次相同顶点的再发布。统一示例提供 F5 和对应按钮，画册同时列出已有颜色、残留、拖影与收敛边界。[本版画面与终姿](../LocalComparison/Review/display-and-door-stability-119/result.md) · [四个画质问题](../LocalComparison/Review/dynamic-picture-comparison-01/report.md)

G1 关闭单一 Mixed 主方向灯照射静态烘焙表面时，世界命中忽略 Shadowmask、向另一张白色接收面提供多余反弹的缺口。原遮区在真实／白遮罩下的平均间接亮度从旧版相同，变为 0.000000／0.478625。受光侧仍亮，两处各有 256 个共同有效点。[普通间接光对照、来源与边界](../LocalComparison/Review/mixed-static-world-bounce-01/result.md)

G5 补齐普通三室中室的应用呈交依据。Release119 在 960×540 固定中室机位的 30 秒窗口内平均 56.44 Hz，Present 间隔 p95／p99 为 20.278／21.652 ms，最长 23.894 ms。随后按 Esc 正常退出，退出码为 0，普通日志没有 HLGI 未释放警告；逐个资源的退出账目只在开发构建或 Editor 中输出。邻近机位的 GI 三段合计 p95／p99（16.170／16.729 ms）和进程 local／nonlocal 峰值（566.191／287.438 MiB）属于 Release117 的独立测量。[119 呈交与退出记录](../LocalComparison/Review/three-room-middle-present-119/result.json) · [117 GI 与显存](../LocalComparison/Review/three-room-middle-budget-117/result.md)

G4 关闭统一示例在首个域外相机帧仍可提交旧组的问题。同一远景根在域内可提交，下一帧跨至 41 单位时已隐藏，加载带内仍绑定。冷入首显仍开放。提高首次照明更新优先级的候选到最近点仍无完整组，本版保留原缓存调度。[相机边界、长回调间隔与未覆盖的入程](../LocalComparison/Review/outside-group-visibility-01/result.md)

G1 关闭了可唯一确定材质的普通单槽 Lit 世界回退忽略接收阴影关键字的缺口。实际 GPU 在同一个受光点先后查询，两次都确认灯路有遮板。开启接收阴影时保持黑色，关闭后返回每通道 0.328887，与未遮挡漫反射计算一致。此项实测覆盖非 DXR 无卡解析回退。[关键字、物理遮挡与实际 RGB](../LocalComparison/Review/fallback-lit-shadow-receiving-01/result.md)

G2 关闭了旋转 BoxCollider 解析代理误挡空角的缺口。对于同一块 45° 薄板，旧版将穿实体和穿空角的光路都判给近板。Release115 在实体处取得正确的倾斜法线，空角路径命中后墙。两个最近命中的对象、距离和法线都与 Unity 碰撞查询相符。此项限无 Renderer 的规则盒形代理，整景凹面和运动拖影仍开放。[两条光路与实际数据](../LocalComparison/Review/oriented-collider-box-01/result.md)

G3 得到了一次可以直接识别旧色分量的动态对照。仅有的纯绿发光板切蓝，保持 2 射线、半分辨率、时间累积、递归反弹和 4 级滤波。27 个共同已知地板点的旧绿在首蓝帧还剩 7.46%，第 +10／+30／+59 帧分别为 1.43%／0.285%／0.0262%。第 +119 帧仍有微量正值。比例针对这次换色的 G 分量，精确首次越线帧与新蓝光的稳态误差仍开放。[同曝光画面、有效域与残留比例](../LocalComparison/Review/green-emission-decay-114/result.md)

G1／G3 关闭了单槽普通 Lit 的均匀材质回退忽略运行时换色的问题。无精确几何也无可用图卡的近板，依次接受 Renderer 绿色发光、槽 0 蓝色发光并清槽。旧版白地板三帧均红；Release114 的实际 GPU 代理和 27 个共同已知地板点均依次为绿、蓝、绿，与每帧应生效的覆盖一致。此项隔离了材质更新，多跳残留另计。[六图对照与线性读数](../LocalComparison/Review/uniform-fallback-mpb-01/result.md)

G4 关闭了相机显式选择软件后仍占用全局 RTAS 额度的问题。普通 Win64 Player 的同一近景从 DXR 切到精确软件后，RTAS 计账从 132,096 B 降至零，硬件属性从 50,176 B 降至零。再次选择 DXR 后恢复 20 个硬件网格。三个端点均有完整的近景细节。[实际切换、旧版留存和计量边界](../LocalComparison/Review/disabled-dxr-retirement-01/result.md)

G2／G4 已观察到一个确实参与光路的混合回退面。地板和暖色墙走 DXR，较近的绿色遮板只用解析 Box。移入遮板后，同一批白地板采样点的间接光从暖色变为纯绿，红蓝通道降至零。此项覆盖轴对齐 Box 与精确三角命中的竞争。[画面与适用范围](../LocalComparison/Review/mixed-fallback-occluder-01/result.md)

G3 补齐当前配置的完整规定路线。Release112 普通渲染源码在固定场景以 2 射线、4 级滤波和 DXR 连续完成门往返、五灯关闭与重开、薄壁及封闭房间切镜，无执行失败与后端不匹配。关灯前、关灯当帧和第 +59 帧的普通相机全图平均亮度分别为 0.199461、0.010839、0.010817，发光面在关灯后保留。这些值含原生直射，动态误差与精确收敛仍单独开放。[连续动作图与适用范围](../LocalComparison/Review/full-dxr-sequence-112/result.md)

G5 已关闭“能运行下载包，但在另一份工程目录里无法打开并重建同一示例”的缺口。Release112 另附原场景、渲染配置、源码、烘焙资产与活动分页。该 ZIP 在本机首次导入到没有 Library 的新目录后，场景无缺失脚本，实际 PC 管线为 2 条射线、4 级滤波、优先 DXR，活动清单的各页和源资产均可解析。公开入口已成功构建同一场景的普通 Win64 Player。本项覆盖干净工程目录，不外推其他设备和平台。[工程与重建步骤](UnifiedUnityProject.md) · [发布与构建记录](../LocalComparison/Review/deferred-global-light-reset-01/delivery.json)

G3 修复了全局灯变化当帧没有可信测量时，屏幕历史忘记替换旧光的问题。在实际时间重建着色器上连续传递输出，两帧未知后首次可信黑值的输出从 0.666667 降到 0，再下一帧正常累计。相邻像素尚未更新的旧白色也不会经子像素重投影重新混入。实际场景中的多跳残留和局部换色收敛继续按原画面对照报告。[连续帧、子像素与适用边界](../LocalComparison/Review/deferred-global-light-reset-01/result.md)

G1 修复了解析灯忽略逐灯间接倍率的问题。同一盏点光的倍率由 1 改为 0，在独立冷启动的单次反弹场景中，离屏色墙照到白地板的间接 RGB 归零，两次原生直射全图一致。G3 修复了无 cookie 点光原地旋转误报局部照明变化的问题，聚光灯转向仍会更新。两项分别由画面和实际灯表观察支持，运动颗粒与收敛时间仍按原采样版本报告。[同曝光画面、灯表与适用范围](../LocalComparison/Review/analytic-light-bounce-01/result.md)

G1 在 Release110 确认单盏 Mixed 主灯的静态 Forward Lit 直射能保留 Shadowmask。Replace 移除烘焙漫反射后，受遮和未遮内部区域的亮度分别为 0 和 0.488486，与独立原生直射一致。Release118 的世界空间反弹实测另列在本页开头。[110 画面、原始 HDR 与范围](../LocalComparison/Review/mixed-shadowmask-01/result.md)

G2／G5 的分页导出和统一变体生成现在可保留静态 Lit 接收面的独立 UV0 覆盖。重新加载实际资源包后，同一白色接收面三角形在独立页、近景和远景聚合网格及其表面卡上都采到覆盖后的红色 (225, 35, 12)。基础 UV 原会采到蓝色 (20, 65, 210)。共享原网格的另一个接收面仍使用原坐标，作者资产完好。此项通过仓库 Editor 源码交付。已静态合批、额外位置或法线等输入继续由导出保护处理。[支持范围](IndependentAssetPages.md#build-and-use) · [实际页和三角形的读数](../LocalComparison/Review/static-uv0-export.json)

G4 改进了从域外高速进入统一示例时的首次显示。Release110 只提前加载接近方向的粗根页。与 Release109 相同的冷入路线相比，首个完整可提交组由回程 7.39 单位处的根，前移到回程 1.78 单位处的三个细节。最近点仍为空，两次在域外终点均排空。[冷入折返、实际提交与未覆盖范围](../LocalComparison/Review/cold-aggregate-prefetch-01/result.md)

G3 的局部换色已有相同最终材质、不同起始墙色的配对。在同版 DXR 的第 +30 帧，红墙改蓝路径的地板与白色接收块分别较首帧蓝墙的平均间接亮度低 12.34% 和 11.59%。两处红色占比一降一升。该时点的亮度差可量化，精确收敛时间仍开放。[同曝光画面、原始线性值与未知点](../LocalComparison/Review/blue-wall-history-01/result.md)

G1／G3 修复了静止斜面因法线被重复归一化而错误裁剪成熟历史的问题。一个通过身份和几何检查的固定像素，在历史为白、当前测量为黑、权重为 0.08 时，修复前每通道输出 0.0368，修复后按原累积规则输出 0.92。这是实际 HLSL 时间重建分支的对照，整景照度与运动拖影仍按原采集版本报告。[静止斜面输入与输出](../LocalComparison/Review/stationary-tilted-normal-01/result.md)

G4 去掉了空间滤波多申请的一张工作纹理，并按实际滤波级数计算屏幕预算。960×540 的中性两室普通 DXR Player 中，四级滤波保持 480×270 的 GI 尺寸，屏幕纹理账目从 33,177,600 降至 32,140,800 字节，画面正常合成。驱动显存峰值与 GPU 时间仍沿用各自已记录的测量。[纹理用途与同机位账目](../LocalComparison/Review/filter-work-texture-01/result.md)

G5 修复了退出回调错过已取消的形变 CPU 任务、遗留未发布网格的时序问题。用相同任务且不再驱动主循环，旧版留存一个作业和 38,592 字节预留，修复后私有网格得到清理，作业和预留均为零。Release107 普通 Windows 包整合了该修复和方向贴图画册。[受控时序及原生验证边界](../LocalComparison/Review/cancelled-worker-shutdown-01/result.md)

G1 补齐普通 Forward Lit 使用真实方向光照贴图时的替换合成对照。两个接收区随法线倾向出现可辨别的烘焙光变化。替换后保留实时直射，与解绑贴图的独立相机画面对比，内部像素的最大绝对通道差为 0.000488。本项在 Release106 源码上观察。[方向贴图四图与适用范围](../LocalComparison/Review/directional-lightmap-01/result.md)

G2 修复了表面卡烘焙时将共边误判为重叠的问题。真实聚合网格的 36 个三角形由 20 张卡降为 18 张，三个材质槽的三角形归属完整。G4 关闭了中性两室沿用 192 张卡预算时无法从近景交接到远景的问题。Release106 普通 Player 从中性近场直接切换，完整发布一个远景聚合体，返回时恢复全部三个细节。[实际烘焙与远近交接](../LocalComparison/Review/neutral-room-chart-fit-01/result.md)

Release105 已交付可步行通过两道错位门洞的三室路线。该版本三室 Near 用 168 张卡，Far 的唯一完整聚合体发布时用 170 张，返回 Near 后三个细节恢复。普通 Player 的实走坐标和相同机位的 Editor Final 已各自标明来源。[三室路线与观察](../LocalComparison/Review/three-room-passage-01/result.md)

G3 已取得统一两骨门真实前帧蒙皮几何的来源依据。前帧几何候选在相同骨姿的运动末帧取得 CPU 资格，但 2722 个可见门像素均未累计上一帧历史，未确认运动画质改善。该候选已经撤回。[来源、配对画面及判据](../LocalComparison/Review/skinned-previous-vertices-01/result.md)

G4 已关闭首次只进入远场时，已绑定聚合体无法作为完整 HLOD 组发布的缺口。Release104 复用已保存的作者关系，在细节页全程未加载的场景中，先进入预热，再发布唯一的远景表示。[冷远场确认](../LocalComparison/Review/cold-far-root-01/result.md) · [运行包](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release104-demo)

G4 的冷区高速穿行已取得一条独立观测。Release103 从零驻留进入近场并立即返回，途中无半组或双组，离场后资源排空；首次可提交的完整表示延迟到回程。104 的定点远场修复并未重测该路线。[位置与首显边界](../LocalComparison/Review/cold-crossing-01/result.md)

G2 已补齐接收面与两块暖色发光面之间的直线均被隔墙阻断时的画面对照。在现有两室中只移动机位，同一受遮地板的间接出射亮度在开门时为 0.01979983，闭门时为 0.00007467。连续穿越多房间的观察仍开放。[左右墙面位置、同曝光图片与原始 EXR](../LocalComparison/Review/shaded-room-floor-01/result.md)

G1／G3 关闭了纯黑解析灯占用名额、阻止灯表变空的缺口。实际 Unity 收集器在容量为 1 时保留了排在黑灯之后的微弱红光，将红光改黑后正确移除旧项，恢复微弱红光后重新入表。普通两室 Release103 已整合该修复。画面残留和收敛时间仍按各次实测版本报告。[功能结果](../LocalComparison/Review/black-light-admission-01/result.md) · [运行包](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release103-demo)

G1 已确认普通 Forward Lit 在一张真实的非方向 lightmap 上可用替换模式移除烘焙漫反射。暖、冷两块地面保留了同一盏实时直射灯，中心区域与单独关闭贴图的基准最大线性通道差为 5.96 × 10⁻⁸。[同机位三图与原始 EXR](../LocalComparison/Review/baked-lightmap-01/result.md)

G3 已量化 Release102 同一运行中关上分隔门后的前室暖光。首个闭门帧还保留开闭亮度差的 47.45%，第 +30／+59／+119 帧分别为 14.33%／9.38%／6.34%。最后一个时点仍有残留。局部缓存替换候选在相同时点没有改善，已撤回。[关门响应与适用范围](../LocalComparison/Review/portal-close-response-01/result.md)

Release102 在统一示例内交付可步行探索的相邻两室，F3 切换布局，O 操作分隔门。固定前室地板的第 119 帧平均线性亮度由开门的 0.11809 降到闭门的 0.00000530。关闭了同一真实门洞两侧的遮挡与间接光响应缺口。[普通版本与实测](../LocalComparison/Review/connected-rooms-01/result.md)

G2 的离屏纹理反弹已有实际画面对照。普通 DXR 相机只看白地板，完全位于视锥外的已驻留 Lit 色墙交换纹理位置后，左地板平均 R−B 由 +0.1041 变为 −0.1041，右地板由 −0.1035 变为 +0.1035。本项限于该静态两色底图与一次反弹。[离屏纹理实机对照与原始 EXR](../LocalComparison/Review/offscreen-wall-texture-01/result.md)

G2 已补齐可读网格在既有 Prefab 实例上烘焙、保存与重开的依据，SDF 和 surface charts 引用均保留在实例上。SDF 烘焙入口另修复了未识别磁盘上已有但尚未导入的目标文件的问题。[作者工具实测](../LocalComparison/Review/baker-path-and-prefab-01/result.md)

G5 已补齐普通门持续运动时的 GI 专项成本与同窗显存。源帧 159–670 的门位移横跨 2.2 个本地单位，逐帧三段合计 p95 为 16.984 ms，同窗 local 峰值为 568.816 MiB，均达到本机起始目标。[逐帧配对、门位移及显存](../LocalComparison/Review/door-motion-budget-01/result.md)

G4 的半小时跨驻留范围使用已在 Release100 专项构建上完成。每次离场，组页、引用和驻留估算字节均归零；每次返近都重新发布完整 DXR 细节组。进程 local / nonlocal 有限采样峰值分别为 574.508 / 288.359 MiB。[30 分钟路线与原始账目](../LocalComparison/Review/streaming-sustained-30m-01/result.md)

G4/G5 的 Editor 退出检查关闭了两个服务宿主残留的缺口。原 Release101 源码退出 Play 后留下 6 个非持久原生对象，修复后同场景快照中这 6 个对象全部释放。默认域重载已实测，禁用域重载的路径仍未实测。[Editor 快照与修复](../LocalComparison/Review/streaming-sustained-30m-01/result.md#editor-退出-play-后的原生对象)

以下按原计划缺口报告，避免用运行或归档数量代替完成度。具体实现与有限证据的版本、输入和边界保持各自来源；后文逐阶段记录不是当前版本全部重新通过的声明。

G1/G3 修复了默认 Additive 相机材质捕获在原生 LOD 交叉淡变时取错颜色的路径。比如共面重叠的红、蓝两级不透明 Lit，URP 会在同一像素裁掉其中一级，而旧 GI 捕获允许两级都写入。现在捕获调用 URP 的 `LODFadeCrossFade`。DXC 编译确认开启时抖动纹理与淡变量参与裁切，关闭时没有这项纹理依赖。产品提交 `ed391bb` 已整合进普通 Win64 Release 构建，Unity 报告 0 错误、23 警告。实际 LOD 过渡画面与拖影量仍待观察。G4 的 30 分钟流式运行继续沿用已准备的 Release100 测量构建。[捕获着色器](../Runtime/Resources/HybridLumenGI/HybridLumenGISurface.shader) · [Release101 下载](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release101-demo)

G5 的源码工程升级与回退说明已交付，覆盖同源 GUID、旧序列化设置、烘焙资产和资源页的重建条件，以及可选原生插件。97 到 98 的产品改动限于示例换色脚本。更早或自定义工程的实际迁移结果仍须按工程确认。[升级已有 Unity 工程与回退](Implementation.md#升级已有-unity-工程与回退)

G1 已补齐普通 Feature 的无遮挡白炉出射能量对照。Release99 的一个白色漫反射接收面受均匀单位环境照射，中央 64×64 区域单帧 RGB 各通道均值 0.99902347，较理论值 1 低 0.09765%。闭合空间的递归反弹、整景能量与动态收敛仍开放。[线性 HDR 与范围](../LocalComparison/Review/white-furnace-ordinary-01/result.md)

G1 的黑色及全金属接收面另有同帧合成依据。历史 V209 第 119 帧，按源几何选出的 473 个黑色样点和 298 个金属样点的加法合成前后 RGB 完全一致，其中 446 个黑色样点和全部金属样点保留了非零原生颜色。[同曝光裁切图与样点](../LocalComparison/Review/zero-diffuse-composite-v209/result.md)

| 原关卡 | 已落实或关闭的具体缺口 | 尚未关闭 |
| --- | --- | --- |
| G0 基线锁定 | **本机基线锁定完成**；[原条件逐项依据](ProductionPlan.md#g0已锁定的本机基线)已核对版本、设备、用户目标／预算、保存场景／参考图、导入构建与同源93基线；GI p95为19.298ms、local峰567.254MiB，普通Present独立窗口平均52.69Hz | 本机G0无剩余；显示FPS、最坏情况及完整负载／平台验收仍由G4/G5保留，93证据不改标97，有限基线不冒充生产放行 |
| G1 传输正确性 | 本机普通 Forward Lit 的 Replace 合成通过了环境 SH、两类静态光照贴图和单一 Mixed 主方向灯遮罩的[去除原生漫反射对照](NativeDiffuseComposition.md#support-matrix-and-rejection-conditions)。已修复反射率、发光、逐灯间接倍率与单槽材质覆盖问题。116 修复 Lit 回退忽略实时阴影关键字，118 修复静态图卡世界命中丢失烘焙遮挡。Release93 固定红墙第 119 帧与参考的地板／白块平均亮度偏差为 −3.075%／−0.831% | 整景物理颜色、默认多跳稳态及更广材质／灯光条件仍开放。固定红墙的定量参考限于 640×360 中的指定区域 |
| G2 世界表面与几何 | 本机代表场景已有三室、薄壁、门洞、离屏纹理、[凹入内板的分色反弹](../LocalComparison/Review/recessed-wall-material-120/result.md)和可定位的覆盖阻断。实现包含可变图卡、实例 BVH、对象／全局 SDF 与形变快照 | 原计划第 8、9 节的接缝图集与锚点、负／非均匀缩放后的采样等仍有未验收范围；近远场交接和成本保留各自条件 |
| G3 动态稳定性 | 2 射线和 4 级滤波减少了既有四时点的运动云斑。112 走通规定 DXR 完整路线并修复全局换灯跨未知采样的历史错误。114 修复无图卡单槽材质换色，并量化唯一发光源改蓝后的旧绿，在第 +30 帧剩 0.285%。普通蒙皮停稳后可恢复历史 | 明暗过渡更柔。通用跨形变历史、可见拖影的纯幅度及持续帧数、其他光路的多跳残留与新颜色的准确稳态仍开放 |
| G4 规模与后端 | 已观察 30 分钟离场排空、三室完整远近交接、切到软件后归还 RTAS 额度及解析 Box 与硬件网格的混合遮挡。117 在首个出域相机帧隐藏旧组。121 修复降预算后小网格的精确软件准入。[相机边界](../LocalComparison/Review/outside-group-visibility-01/result.md) · [预算恢复](../LocalComparison/Review/software-budget-recovery-121/result.md) | 冷入最近点仍有首显空档。更大负载、最坏显存、切换耗时及其他混合回退几何下的后端偏差仍开放。[高速路线](../LocalComparison/Review/cold-aggregate-prefetch-01/result.md) |
| G5 发布 | [Release121 运行包及可编辑工程](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release121-demo)提供统一示例与离线画册。默认静止场景和 F4 中室各有 GI 时间与显存预算结果，普通门运动和 F4 中室分别有应用 Present 记录 | CI 已由用户暂缓。更大负载下的性能与峰值显存、原生退出的完整所有权账目及生产验收仍开放 |

G0／G5有限关闭[当前filter4／2ray交付配置缺少普通运动Present依据](../LocalComparison/Review/release93-motion-present-01/result.md)的缺口：Release93一次固定30秒M门运动窗口，按960×540参数启动、实际DXR，应用Present平均52.688Hz，间隔p95／p99为21.966／23.567ms，最大25.991ms，全部观测间隔低于33.333ms。普通三维场景与门位移已观察，端点完整details且transform更新推进；支持本机30FPS方向，不是显示FPS、运动GI／显存或最坏负载验收。正常退出，普通93不改、不重建，本线结束。

此前复用[既有切镜与封闭房间画面](../LocalComparison/Review/dynamic-picture-comparison-01/report.md#已有切镜薄壁与封闭房间画面)，补清原固定序列已观察输入的边界；该线没有新增运行或产品修改，也不新增G2/G3放行。没有证据支持重开该序列或立即扩建时间调度框架。

## 最近实现与决定

G4／原目标3关闭[Base转Overlay后的旧GI消费者阻止资产页卸载](../LocalComparison/Review/overlay-camera-page-retention-01/result.md)的具体缺口：源码3de97f4在消费者查询中排除当前非Base相机，保留缺附加组件的Base默认和Scene View强制Base语义；其他相机、解除绑定及最终context fence不变。独立复核、Astra审查及一次普通Release97构建完成，演示包已发布。未新建模拟器或新增Player／采集，不外推全部CameraState释放、两组预算或完整生命周期验收。

G3／G4、原目标2／3关闭[GPU监测／反馈控制不必要撤销光照有效性](../LocalComparison/Review/gpu-controls-preserve-history-01/result.md)的行为缺口：源码171e6fc仅将五项控制从传输配置比较中分离，完整配置仍驱动计时／控制器代次；首次及其他设置变化仍撤销原历史/readiness。独立审阅、实际Unity Settings／JsonUtility检查及一次普通Release96构建通过，可下载演示已更新。未新增Player、图像或成本窗口，不声称实机历史连续性、画质／性能新收益或整体G3／G4通过。

G1／原目标1关闭[高反射率直接反弹的screen/world路径差异](../LocalComparison/Review/direct-reflectance-consistency-01/result.md)：合法rho=1的世界命中此前把直接项压到0.98，屏幕命中保留1。源码1503738将物理材质保留[0,1]、直接项按rho、递归cache项单独限制到0.98，两类缓存来源一致。已有WARP宿主的固定真实函数检查及独立复核通过；不承诺一般输入逐位不变，也不把此缺陷归因于既有整景误差。Astra同意有限采用；一次普通Release95构建成功并完成可下载演示整合，未增加Player、画面或成本窗口，整体G1保持开放。

按原始G0条款逐项核对已有来源，关闭[本机基线锁定](ProductionPlan.md#g0已锁定的本机基线)：版本／设备矩阵行、用户目标与预算、保存场景／参考图以及导入／同Runtime测量构建均已具备。此前将最坏情况、显示FPS及完整生产负载列在G0未关闭栏，混入了后续G4/G5条件，现归回原关卡；没有降低这些条件或补测。独立核对同意关闭G0，G1–G5保持开放。

纠正[表面缓存合同](SurfaceCache.md)四段过时能力说明：精确软件／DXR已有独立alpha/Cull候选筛选、真实UV材质与配对面积Le采样；缺失card不等于常量可补成可信精确材质。CPU常量访问器与实际命中链的区别现已明确，不新增功能或原生验收声明。此前凹腔候选经独立去重及Astra审查停止：薄壁与内部两层已有原生依据，未发现独立新机制，仅增加U形的同链验证不足以立项；没有修改fixture、运行或扩建证明系统，G2完整范围仍开放。

G5关闭[统一可运行版本只能通过开发机路径访问](../LocalComparison/Review/release94-download-01/result.md)的交付缺口：现成普通Release94已作为Windows x64实验性演示包发布至授权私有GitHub仓库，首页提供下载、完整解压与升级入口，附运行依赖、操作边界和既有插件许可。没有重建或新增产品／性能验收；发布后API已确认资产与链接。此前拟定的当前Skin持续运行窗口因截图工具错目标未开始，用户截图确认正常普通场景与实际DXR，随后正常退出，不计持续使用通过；该线不追加窗口。

原目标2／G3的[普通骨骼运动短历史候选](../LocalComparison/Review/skinned-motion-history-01/result.md)不采用并收束：现有URP motion加两帧身份使实际运动样点可累计至2，停稳仍恢复正常历史；但两侧真实轨迹不匹配，Final未确认一致颗粒收益，不满足预设画质采用条件。纠正了候选对普通Lit MotionVectors材质开关的误判，候选diff及结果保留，产品与部署恢复Release94；没有新G3画质关闭项，不重建、不追加采集或变体验证。既有94停稳能力和历史质量／预算证据保持。

原目标2／3、G3关闭[普通Skinned在骨骼停稳后仍一律拒绝屏幕历史](../LocalComparison/Review/skinned-stopped-history-01/result.md)的具体缺口：稳定局部骨矩阵、骨引用、完整网格与材质才恢复既有历史，骨变化换几何代次，DrawRenderer捕获实际顶点流。统一场景真实GPU样点119历史为32，运动120／127最大≤1，停止128开始恢复、239最大32；不外推通用动画、噪声改善幅度、颜色或固定收敛时间。首次可选Cloth模块编译失败、第二次整数纹理直接读回失败均保留，修正后复用既有拷贝完成原定序列；未扩验证范围。退出仍有owned/pending各5、deformationBytes286208及临时buffer警告，清理不算通过。独立与Astra有限采用，产品65c36ef已整合普通Release94，无新增Player／性能／颜色采集；本线收束。

G5使用入口关闭[首页多代“当前”记录与源码导入范围不清](../README.md)的交付缺口：当前93启动与GitHub源码接入明确分开，只导入Runtime／Editor／Shaders及meta，避免实验Harness与冻结源码被Unity一起编译。操作、四项质量边界、独立性能窗口和原计划剩余集中呈现；两个旧样例索引改指首页，历史补丁说明明确为已整合记录。独立接入审阅确认必要资源与限制，产品和普通93不变，没有运行／构建／新归档，不增加画质或G5整体通过项。此前缓存调度筛选未发现新实现缺口；没有把单纯可见面积权重当成已有收益，未改算法或扩测。

G1补齐[当前filter4／DXR静止119的同量颜色估计](../LocalComparison/Review/release93-color-frame119-01/result.md)：复用原256spp／8反弹参考与Floor／White ROI，平均D-Y偏差−3.075%／−0.831%，Y-MAE 0.010529／0.018576、均值色向L1 0.007976／0.033415，unknown为2／0。较旧软件filter3，Floor平均偏差更大、White更小，两处MAE约增10.1%／6.6%；不称全面更准或把差异单独归因于滤波。独立复核与Astra同意保留93的运动减云斑取舍并收束；产品不改、不重建、不补采，完整G1与动态收敛仍开放。

原目标4关闭[精确后端已接管全部published owner仍遍历空回退BVH](../LocalComparison/Review/exact-no-fallback-traversal-01/result.md)的冗余工作：复用已有FallbackCount，在两Bind随meshFlags设置私有uniform，exact宏内无回退才提前返回；混合／无exact路径与unknown／miss语义保持。源aeb6ba2经独立等价审阅、唯一既有静止成本窗口及Astra采用审查：GI合计中位23.921→18.393ms，节省5.528ms超过两侧块变化最大1.082ms；p95为19.298ms，local峰567.254MiB。已完成唯一普通Release93构建，没有新图像、运动Present或第二窗口；收益限此无回退DXR场景，质量保持92来源，本线结束。

原目标1／工作流6按用户质量取舍采用[本机第4级空间滤波并交付Release92](../LocalComparison/Review/four-pass-local-quality-01/result.md)：只改保存示例filter3→4，不改Runtime、2ray／DXR或时间累计。默认DXR四时点的门面／地板／绿墙云斑明显减少，局部明暗更柔，未见新增持续旧轮廓；全图平均Y变化在约−0.051%至+0.031%内，不当颜色正确度。既定一次静止成本窗口GI合计p95为24.562ms、local峰565.441MiB，满足25ms／1GiB但GI余量仅0.438ms；不新增运动Present或参考。独立图审、结果复核及Astra同意有限采用，普通构建完成；旧filter3颜色和响应保持原来源，本线结束。

G4使用层关闭[细节已请求但普通面板只显示聚合体发布状态](../LocalComparison/Review/sample-representation-status-01/result.md)的展示缺口：UI／F2现在关联实际样例请求与完整Renderer可提交组，区分降级可用、主动撤回、未评估和未知，不引入核心覆盖判定器或修改调度。源码7b47406经独立审阅并整合至Release91，公开Release／None构建成功；没有Player、路线或画质重测，也不扩写为GPU／逐像素覆盖通过。

用户已确认本机起始目标：960×540／30FPS，现有GI三区间合计p95≤25ms，进程local有限采样峰值≤1GiB，nonlocal另列。[既有90静止窗口](../LocalComparison/Review/release90-dxr-baseline-01/result.md)的22.643ms／565.441MiB满足这两个窗口门槛，不重测、不自动开启反馈；原正式预算待答项已关闭，完整负载／平台验收仍未关闭。

G4补齐[热态连续近远切换](../LocalComparison/Review/continuous-near-far-01/result.md)的有限依据：已就绪近场起步，20单位／秒往返10次，中间不等ready；实际页IO、目标和发布均推进，按身份记录的Renderer可提交组和当前发布组保持完整，回近后恢复details。普通90不变，无图像／性能测量；不扩大到像素无洞、未驻留冷区穿越、生产长时或完整G4。

G0关闭[当前2射线只有Present、缺少对应GI区间成本](../LocalComparison/Review/release90-dxr-baseline-01/result.md)的信息缺口：原样复用既有observer，预热后静止DXR／960×540／半分辨率GI合计中位21.667ms、p95 22.643ms、p99 23.938ms；进程local／nonlocal采样峰值565.441／287.566MiB。采集时正式预算待定，后续用户确认见上；普通90及画质保持，没有新探针或重复窗口。此前有限滤波阅读没有新候选；局部响应和RTAS额度均按已有历史去重停止，不新增参数改动或验证。

原目标3／工作流8关闭[完成形变快照的发布饥饿机制](../LocalComparison/Review/deformed-publication-fairness-01/result.md)：旧源码在单份上传额度下让新请求抢先、旧ready继续等待；最小改为捕获入队顺序后，合格旧ready先发布，未完成头项、撤销清理和失败所有权保留均沿用原语义。实际组件宿主、独立审阅及一次公开Release90构建完成，源码8f0cdc8。不保证永久超过整帧额度的任务有界等待，不新增Player／画质／性能结论，不关闭完整§5。

已将下述捕获时间准入整合至[Release89](../LocalComparison/Review/deformed-capture-time-budget-01/result.md)：源码c125711，一次公开Release/None构建成功，默认关闭、原场景和2ray/DXR保持。没有启动Player或新测画质／性能；本次进度是可配置CPU捕获准入能力及可运行整合，不是新增实机加速或§5整体完成。

原目标3／工作流8补齐形变同步捕获只有数量／字节额度、没有耗时准入的能力缺口：新增默认关闭的`CaptureBudgetMillisecondsPerFrame`，按完整同步尝试的经过时间决定本帧是否继续开始下一份捕获。失败和unchanged早退计时，延期保留下一对象游标及请求，已完成任务的发布／清理不受此门阻挡。独立源码审阅和既有组件宿主的延期／跨帧推进检查通过；单次BakeMesh不可抢占，实机性能和完整§5仍未验收。具体用法与计量边界见[形变快照](DeformedGeometry.md)。

G4有限关闭“默认2射线DXR缺少当前动停画面依据”的缺口：[当前软件／DXR四时点对照](../LocalComparison/Review/release88-dxr-motion-01/result.md)在149／179／189／209未见明显新增缺失、颗粒回退、边缘异常或持续旧轮廓，主线程、独立图审与Astra结论一致；软斑两侧仍在。保留Release88默认DXR，不要求逐像素相同、不新增物理准确度/全过程等价结论。原720未完成记录保持，产品未改、不重建，该线结束。

G1有限关闭“当前2射线配置只有变亮观察、没有同量参考估计”的缺口：[Release88软件119独立对照](../LocalComparison/Review/release88-color-frame119-01/result.md)复用既有参考，Floor／White平均D偏差−2.776%／−0.938%、逐像素Y-MAE 0.009566／0.017423，均小于历史1射线结果；但Floor色向L1从0.004220增加到0.007884，White为0.032816。保留运动颗粒收益和颜色代价，不称全面改善、同点因果A/B或整景通过。唯一静止时点不能解释全部运动亮度或收敛；产品不改、不追加时点/构建，该线结束。

原目标1／工作流6采用[本机2射线质量配置并交付Release88](../LocalComparison/Review/two-ray-local-quality-01/result.md)：Runtime不改，普通示例raysPerPixel由1增至已有的2。四时点软件颗粒和暗斑减少，未见明显新增持续轮廓；出射平均亮度+7.9–23.1%不称颜色更准。普通DXR门运动Present39.95Hz，p95／p99间隔27.81／28.72ms、最大30.72ms，全部观测间隔低于33.33ms；支持30FPS方向，成本明显增加且余量变小。独立图审/结果复核与Astra同意有限采用，统一入口已更新，不补图、不追加窗口/构建或其他射线数。软件画质与DXR成本分别解释，旧误差/残留/收敛保持原来源。

G0/G5有限关闭“当前交付版本门运动缺少性能依据”的子缺口：[Release87普通M运动](../LocalComparison/Review/release87-motion-present-01/result.md)一次30秒窗口的应用Present平均70.85Hz，p95／p99间隔16.73／17.80ms，最大19.012ms，2123个间隔均低于33.33ms。两端DXR/完整details且transform更新推进，普通场景和门移位已目视确认；按960×540参数启动，没有逐帧尺寸/后端证明。支持30FPS方向，不是显示FPS、GI专项成本或整体G5。独立复核及Astra同意收束，不追加静态、软件、显存、长时窗口或构建。

用户已明确暂缓G5的CI接线；原CI验收条款保留未完成，不作为继续本机功能开发的前置条件。

用户已选择下一阶段的画质取舍：**当前统一示例优先减少运动颗粒，可适度变柔，但不能明显加重拖影。** 起始GI／显存目标已确认；这不替代已有画质问题的功能改进，也不将尚未采集的完整运动表现视为通过。

随后[缓存方向批次分层候选](../LocalComparison/Review/cache-direction-stratification-01/result.md)未显示明确新增收益，已撤回：唯一一次与Release87配对的149/179/189/209软件画面中，运动颗粒没有一致减少，主要改变斑驳分布；独立图审结论一致。本轮没有新增关闭G1/G3缺口，当前产品仍为Release87，不追加采集、调参或相同产品重建。完整批次PDF/MIS源码相容性不当成画面收益或物理误差证明。

据此补齐[Release87的有限动停对照](../LocalComparison/Review/release87-motion-response-01/result.md)：同软件、同前史的149／179帧颗粒减少且略柔，189／209接近原基线；主线程、独立图审和Astra均未见明显新增持续轮廓。结论限这四个时点，不是全过程无拖影；云斑、颜色误差及精确收敛仍开放。产品未改、原720未完成保持，没有补帧或重建87，该观察线结束。

当前统一入口已更新为[Release87](<I:/Unity test/Comparison/Builds/LocalRelease87/Start-LocalRelease.cmd>)：源码e352921完成公开Release/None构建（0错误、23条warning），将下述空间滤波改进整合到原场景，并保留空场修复和本机DXR偏好。没有追加Player、DXR动态或成本窗口；四项画质结论及其原来源见[独立画面对照](../LocalComparison/Review/dynamic-picture-comparison-01/report.md)。

原目标1／工作流6采用[短历史空间滤波改进](../LocalComparison/Review/short-history-spatial-filter-01/result.md)：仅对两端有效短历史使用对称的已有噪声尺度，减少单边亮度权重的不对称；时间混合及成熟历史保持。唯一软件239帧同曝光对照中，门及邻近墙地黑颗粒明显减少，未见阻断性边缘劣化，云状软斑仍在；known和门面moments不变，亮度+3.12%不当颜色真值改善。主线程、独立图审和Astra同意有限采用，原720未完成保持，新增读取成本未测；本候选结束，不扩动态/参考/成本验证。

原工作流9关闭[公开验证场景可能自动绑定无关Feature](../LocalComparison/Review/validation-camera-feature-01/result.md)的入口缺口：复用统一示例已有的实际相机Renderer解析，只有唯一启用且持久保存的GI Feature才预填；未配置时保留空绑定并继续生成几何。独立源码审阅及受影响Editor编译通过，两个Editor源已同步本机工程；没有重新生成场景或启动Unity／Player，Release86不变。本次没有新增多房间场景或扩展历史薄壁／内部层验证。

G5接入说明同步消除了两处过时交付信息：[Implementation](Implementation.md)不再把Release76称为当前入口，改由首页维护唯一入口；不再将已有真实shader输入观察的本机描述为source-only。验证场景说明与当前Feature选择一致，保留有限证据边界；没有新增支持承诺或运行检查。

当前入口已整合为[Release86](<I:/Unity test/Comparison/Builds/LocalRelease86/Start-LocalRelease.cmd>)：普通Release/None构建完成（源码00497b2，0错误），将下述空场资源修复交付到原统一场景；本机DXR偏好沿用85。没有追加Player、图像或性能运行，历史画质与成本结果保持原来源。

原目标3／4、工作流8修复[空场反复分配三角后端资源](../LocalComparison/Review/empty-geometry-preparation-01/result.md)：无可接纳三角实例时直接撤销旧几何并按原流程退休，不再每帧创建空RTAS和dummy缓冲；保留退休完成前计账和同revision重新入场恢复。必要实际源码夹具回归通过，独立审阅无阻断；没有新的画质或实测加速声明。[Release85三轮普通使用](../LocalComparison/Review/release85-resource-cycles-01/result.md)补齐重复恢复的有限端点依据，当前页／引用同阶段一致、离场归零，同时揭示上述重复工作。末次记录延迟至271.747秒，不能算三轮均满足原30秒范围或完整G4放行；本条循环观察已结束。

原目标1／3、工作流7／8补齐[普通URP Lit静态MPB覆盖随资产页保存](../LocalComparison/Review/asset-page-mpb-persistence-01/result.md)：有效材质按槽独立保存，保留slot优先级、纹理/ST、颜色空间、关键词和源栅格状态。真实导出／保存／bundle加载与已有shader输入对照已取得相符结果，补充直接源值比较确认导出不改源；原准备失败及过强历史身份检查的FAIL保留。该能力取代先前“一律拒绝MPB”的有限保护，不是通用MPB序列化、动态材质或完整G4/G5验收；本机Editor已更新，Release85运行时不变。

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
