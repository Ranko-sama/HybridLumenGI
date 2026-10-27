# 朋友集成验收说明

当前交付为 runtime-candidate-16。发给朋友整个 friend-handoff-16.zip，先读其中 START-HERE-16.txt：包含源码包、可直接运行的 Windows Player、独立 Unity 测试工程和证据/图像说明。旧 integration-15 仍保留，但不含后续运行修复。实际检查见 [Unity功能接线记录](LocalRuntimeFunctionalAudit.md) 与 [原计划交接表](PreFriendReadiness.md)。本机 Editor 软件/DXR、默认软件 Player 与资源页/HLOD Player 已运行；朋友自己的工程适配、性能和最终生产放行仍单独验收。**不等价于完整 UE5 Lumen，不提前宣称生产验收**。

[统一离线报告](../Tests/offline-validation-results.json) 是 integration-15 的历史汇总，没有被重标为修复版全量通过。新 [运行摘要](../Tests/runtime-validation-results.json) 绑定当前 Runtime/Editor 来源。只补缓存可见性、纹理池、灯光和HLOD相关现有回归；未变工件与旧/off/SDF运行复用。两组最终 Player 各720帧、32张HDR、零采集错误；默认软件 Player 有3帧启动期回退，稳定阶段使用精确几何且纹理仅首帧上传。首次驱动初始化约168秒，Editor DXR首次约310秒，这些不是GPU帧时间。退出释放警告、动态低采样噪点、部分材质组合及性能/长时验收仍明确保留。

## 导入

第一轮先取得Editor导入和软件路径的首个结果；有编译或运行阻断就先回传日志，不需要一次做完本文全部生产压力项目。固定场景、720逻辑帧和线性HDR采集步骤见 [ValidationSequence.md](ValidationSequence.md)。每种对照从新Player进程或重新进入Play开始，回传完整目录及源码包的SOURCE-MANIFEST.json；没有可信参考图时保持“待建立”。

1. 使用朋友现有 Unity 工程的版本控制或副本进行集成。记录 Unity/URP 精确版本、显卡、驱动、分辨率及目标帧率。
2. 解压得到 `HybridLumenGI` 文件夹，放入工程 `Assets`。如果原来已有同名包，更新这一份，避免重复类和重复 GUID。
3. 当前运行目标为 Unity 6 / URP 17、Windows DX12、Linear、Render Graph；其他 API、XR 和叠加相机尚未支持。
4. 在实际使用的 Universal Renderer Data 中添加一次 `HybridLumenGIRendererFeature`。
5. 用 `Tools > Hybrid Lumen GI > Setup & Proxies` 注册验证对象；对启用 Read/Write 的 MeshFilter 网格运行 `Tools > Hybrid Lumen GI > Bake Mesh Distance Field`。新版 SDF 保存顶点位置/三角索引指纹；旧版无指纹资产必须重烘焙到新路径并重新赋给代理，工具保留旧资产。运行时需保留源网格 Read/Write。缺少、过期或无指纹 SDF 使用解析形状 fallback，不会继续信任旧体素。
6. 对静态、未形变的 MeshRenderer 源网格启用 Read/Write，选中对象，运行 `Tools > Hybrid Lumen GI > Bake Surface Charts`，点击 `Bake selected source and assign proxy`。保存到新的资产路径，确认生成的 `HybridLumenGISurfaceCharts` 已赋给代理；工具不覆盖已有资产。chart 预算为提示值，超出时仍保留有效三角，运行时必须提供足够卡池容量。
7. 静态资产原地编辑后调用代理 `MarkDirty()`，重烘焙 SDF/charts 并重新赋予资产；共享 Mesh 的代理都会消费该变化。持续形变则添加 `HybridLumenGIDeformedMesh`：Skinned 自动按间隔捕获，可读网格生产者调用 `RequestCapture(readableSnapshot)`。观察状态、发布帧和预算；完整 CPU 快照生成后一起切换，GPU 就绪仍另行判断。GPU 私有变形缓冲必须先提供可读快照。见 [形变流程](DeformedGeometry.md)。
8. 独立资源页使用 [分页导出/加载流程](IndependentAssetPages.md)。给完整表示组配置 mesh、SDF、charts、material 和共享 texture 页，设置 IO/上传/驻留额度。加载完成不等于 HLOD 就绪；检查新表示就绪前旧覆盖保持，离场资源只在最终 context fence 和页租约全部释放后退休。

Scene 在每相机准备边界调用幂等的 `RefreshSignatureForRender()`，因此晚于代理 `LateUpdate` 的变换也会刷新；无变化的第二相机不应再次增加版本。Inspector 的 `OnValidate` 只排队，由主线程刷新/启用或显式 `MarkDirty()` 合并消费，禁用对象保留待处理请求。这是变化通知，不是前帧对象矩阵重投影。用两个共享 Mesh 的对象分别分配不同 SDF 或只分配 charts，编辑一次并调用 `MarkDirty()`，检查所有实例都失效，未共享 Mesh 的对象不受影响。诊断 `rejectedSdfSources` 表示准备中的实例因 SDF 来源验证失败被拒绝；它与上传积压不同。配置了被拒绝 SDF 的 HLOD 目标应保持未就绪，重烘焙后再验收发布。详见 [SdfAtlasResidency.md](SdfAtlasResidency.md)。

没有代理的代码可在主线程调用 `HybridLumenGIMeshSource.NotifyGeometryChanged(mesh)`。该服务以实际 Mesh 引用和不可复用的版本对象广播来源变化；SDF 共用此版本，代理在渲染边界只消费一次，不再重复广播。它不是自动内容检测器；下述可选 receiver 核验只对纳入预算的可读网格检测未通知编辑，不能替代所有场景的显式通知与资产重烘焙。

## 表面 chart 与空卡检查

- 真实 chart 捕获只绘制分配给它的三角；用凹房间、被外壳挡住的内壁、薄夹层和多材质网格检查内部纹理。没有 chart 资产的对象仍用六张首层视图，是近似 fallback；提高这六张图的分辨率不能恢复被遮住的内层。
- 配置了无效/过期资产、不支持的 chart 材质，或 owner 所需卡片无法完整装入池时，该 owner 不会部分接纳。检查烘焙日志、资产引用、材质类型和卡池/字节预算；不能把少捕获的 chart 当作完整结果。
- `Tools > Hybrid Lumen GI > Validation > Log Runtime Diagnostics` 输出 `chartedOwners`、`approximateOwners`、`requiredSurfaceCards`、`readyCards`、`pendingCards`、`warmupBudgetBlockedCards` 及回读计数。这些是汇总和调度状态，**不是逐 chart 覆盖率**。逐卡验收需用 Unity/GPU 调试工具检查 metadata 中的 owner/chart ID、对应 atlas 有效 texel、anchor 和 cache 输出；当前没有自动表面积覆盖证明。
- 每张必需 chart 至少需要一个真实覆盖 patch，且所有已覆盖 patch 达到初始化计数后，才可能通过 HLOD 回读门控。无 chart 资产的 fallback 只有对象级非空检查。`readyCards` 增加只表示捕获/anchor 工作已记录，不能代替 GPU 回读或覆盖检查。
- 极小三角、材质裁剪、剔除面或投影问题可能产生全空 chart。此时目标应保持 warming，旧表示可用时继续保留。检查实际 atlas 和 anchor，修正源几何/材质、合理提高捕获精度或拆分并重烘焙，再观察恢复。平均材质 fallback 或一张其他 chart 非空均不能替代该必需 chart 的覆盖；初始化通过也不证明全表面覆盖或照明收敛。

## 三角命中身份专项验收

硬件路径保留原始submesh/primitive到chart的16B精确绑定，并验证owner、布局、几何版本与ready页。新工作区在命中UV处求材质，chart仅查缓存入射光；未知材质继续遮挡并拒绝辐射度估计，不能用常量近似把它变成已知，也不能扫描其他薄层或借用首材质。SDF/解析形状仍是明确近似，不具有真实三角/UV/面积PDF身份。测试时核对当前交付清单中的候选版本与源码哈希。

- 用两张间距小于旧位置容差、颜色和发光不同的薄层，确保同 owner 内部和不同子网格都不会串色。分别制造缺页、空 chart、超出卡池容量及旧资产状态，检查 exact 查询失败后不会跳到另一层。
- 固定几何绕序，只反转顶点 Ns 或使用强法线贴图；再分别设置 Cull Back、Front、Off，从前后两侧观察，并加入镜像/非均匀缩放。`rawNg` 使用逆转置的源绕序，不随射线或 Ns 翻转；stock Lit 的背面 Ns 保留作者方向，不能用自动 face-forward 冒充一致。真实 chart 的几何方向与 Cull 调整后的捕获方向分开。六面 fallback 依赖默认 Unity DX12 raster 绕序；外部代码未恢复 invert-culling 不在支持范围。
- 对可见背面检查射线起点：history Ng 可以朝相机，但 gather bias 要朝采样 Ns 半球，不能立即命中自己的平面。另检查阴影 bias 没有改变材质法线或命中身份。
- 给两个子网格配置不同金属度、HDR emission、Cull 和颜色。测试 renderer MPB，以及只覆盖一个属性的 submesh MPB；非空 submesh block 应整体替代 renderer block，其余字段回到该子网格材质。运行颜色探针并单独检查 MPB SetColor/SetVector 与实际 Lit 输入；离线 adapter 不能证明 Unity 原生上传约定。
- 在持续渲染中换几何、重烘焙 chart、改变布局、回收并复用同一卡页和 scene slot。观察旧绑定被拒绝，当前 geometry/layout 更新后恢复；刚体或普通材质更新不应持续重传未改变的三角属性/绑定。

诊断 `surfaceTriangleMappingCpuBytes` 是每相机 CPU 映射载荷，含4B/primitive及数组引用、上限16MiB。精确三角属性另含每实例128B身份/法线矩阵和64B对象变换，每三角80B法线/UV、96B位置/切线、16B chart绑定。软件 BVH 另用32B/node和64B/leaf；未改变几何时复用其 CPU 表和 GPU 缓冲。`hardwareBindingUploads`是上传次数，不是覆盖率。CPU 已接纳 cutout，软件/DXR 共用真实候选 alpha；仍需朋友工程验证实际渲染。

材质测试先用小贴图建立正向用例，再检查复用与预算：稳定帧不重复复制旧纹理，修改一张只更新该页；旧读者未完成前该页不能复用。符合格式条件的颜色用配对 half 存储，alpha-test 的 BaseMap/视差高度和未知 HDR 格式保留 float32。跨帧稳定大页按复制额度渐进完成；动态 RenderTexture 不能拼接不同帧内容。保存 `hardwareMaterialStatus`、全局分配和上传额度/消耗、实际 `hardwareBackend`/`exactSoftwareGeometry`。全局字节不可按相机相加，请求 DXR 也不等于实际执行 DXR。

## 第一轮验收

直接光／阴影分层策略的完整合同见 [DirectLighting.md](DirectLighting.md)。已有历史上下文与采样修复保留，receiver 来源票据与可选对象历史按当前候选报告及源哈希核验；Unity、Player及实体GPU验收仍未执行。灯记录80B、owner策略16B/slot和屏幕整数policy8B/pixel。关闭对象历史且含policy时，1080p半分辨率GI的屏幕理论分配约为Additive94.9MiB、原生替换118.7MiB，另计世界资源和owner策略；平台还需支持R32G32_UInt render/sample及3／4个MRT。这些不是实体显存测量。

直接光专项场景：

- 对同一灯比较None、Hard、Soft及strength=0／0.5／1。当前Soft仍为硬阴影，有遮挡的直接光按`1-strength`衰减；不宣称半影、shadowmask、cookie／IES、完整receiveShadows或Mixed Lighting已实现。
- 把前方对象设ShadowCastingMode.Off，后方仍放合法投影者：前方不得投影，也不能让后方遮挡消失；同时确认前方对象仍参与GI几何可见性和材质反弹。对On／TwoSided／ShadowsOnly及Cull Front／Back／Off分别检查；TwoSided只改变DXR阴影候选面向，普通GI查询不能跟着翻面。软件SDF没有相同三角Cull信息，单独记录其保守差异。
- 测试GameObject层31和完整32位rendering mask。URP rendering layers启用时，零mask应为合法空集合；禁用时只跳过rendering层过滤，GameObject cullingMask仍生效。测试bit31照明前，先在URP定义相应rendering layer，避免把正确的未定义层过滤误判成位丢失。
- 将灯照明层与custom shadow layers设为不同集合，确认接收者和投影者筛选独立。然后直接修改`Light.renderingLayerMask`，确认阴影采用这个原生有效值，照明仍来自AdditionalLightData。记录旧／新灯范围的照明响应。
- 在首相机扫描后启用一个已存在inactive灯，再在同帧创建新灯。前者应能被后续相机准备观察到；后者最迟在下一渲染引擎帧被发现。多相机之间修改灯／对象layer、rendering mask及shadow mode，检查版本幂等、旧HLOD票据拒绝且没有不必要的DXR三角属性重传。
- 测量包含inactive的每帧Light扫描、每相机重新打包及最多32个互斥单层RendererList成本；检查整数policy捕获在普通／原生替换和实例化变体中保留原始uint。原生shader当前draw的builtin数据与MRT结果需实际Unity检查，CPUadapter不构成证据。

历史上下文与采样中心专项场景：

- 固定相机和场景，将 full width 从 1920 改为 1921，同时确认 GI width 仍为 960。首帧应拒绝旧历史，之后在尺寸稳定且上一帧成功时恢复；不能仅因低分辨率纹理没重建就沿用旧来源。再独立改变高度、GI 尺寸和 viewport 偏移，检查相同规则。
- 保持目标尺寸相同，换成另一个 RenderTexture，再切回 backbuffer；即使数字 InstanceID 可复用，新引用也应从新历史开始。同一目标引用不应每帧重置。创建／销毁相机并交替渲染多相机，检查旧 CameraState 不被新相机继承。
- 测试同一相机同帧重复渲染、跳帧、恢复和受控记录失败。重复／缺失／失败来源不应复用；在重新成功记录后按连续帧恢复。前帧 VP、逆 VP、jitter、相机位置及旋转应属于同一成功 receipt，失败或过期回调不能提前发布其中任一字段。这里只承诺命令成功记录，不能把 CPU receipt 当作 GPU fence。
- 使用静止斜面、薄边和高对比材质，测试奇数宽高及 1/2、1/3 等分辨率比例。核对深度和 motion 对应的实际 full-resolution texel 中心、历史接受视图及上采样图像；静止有效接收面不应因半个 full pixel 的偏移持续丢历史或出现偏边。缩放比例和 viewport 稳定后再比较，不能把合理的首次重置误判为错误。
- 在 Replace Native Diffuse GI 中制造缺失／无可信 GI 上采样支持的接收面，确认保留原生光照，不把缺失估计当作黑色 GI 扣除。另检查未知几何法线的有效单帧样本只解析到自己的 full-resolution 采样点，不传播到邻接接收面。

CPU来源记录保存Renderer/Mesh引用、submesh、几何／材质代次和对象矩阵，并与各相机成功记录的receipt绑定。新增 `receiverObjectHistory` 默认关闭；开启后自动启用CPU跟踪，并将当前像素的来源代次和primitive与前帧身份纹理匹配，再使用对象前帧变换检查位置和法线。当前限定普通可读、未形变MeshRenderer、single-sample、完整归一化viewport及所需DX12能力；相对非均匀缩放、剪切、反射变化及未知覆盖拒绝历史。它仍需下面的Unity验证，不能据离线结果宣称Skinned或完整形变历史已完成。

对象历史专项验收：

- 从默认关闭状态开始，记录基线，再开启 `receiverObjectHistory`。检查移动物体与相机同时运动、静止物体和ForceNoMotion情形；验证正确身份与pose对应才接受历史。贴图法线保持着色法线，几何法线独立参与拒绝。
- 放置共面不同对象、同对象重叠子网格和重叠三角形。第二个合法fragment即标冲突，不应靠最后一次写入选择身份；未知LOD、额外顶点流、parallax或未知材质覆盖应保留当前GI并拒绝历史。测试GPU DEBUG_DISPLAY和alpha-to-coverage状态，确认不会写入不相容身份。
- 让另一扇门穿过静止接收面的旧／新影响域，确认不会借用接收面自己的位姿豁免。只有当前帧Renderer group精确匹配的自身纯位姿域可以豁免；其他对象、未知owner、同bounds混合owner、拓扑和材质变化仍硬拒绝。
- 以1080p、Additive、64MiB屏幕预算测试身份资源不足：应退回基础当前GI并关闭对象历史。身份资源的逻辑增量为16B/full pixel、32B/GI pixel双身份历史和80B/对象row；独立变化域buffer为1,088×48B。实际显存另含世界资源、驱动及加速结构。
- 验证多相机、同帧重复、跳帧、取消图执行、部分draw或resolve失败、关闭Feature以及GPU积压。无效回调不得发布旧身份；未通过fence的私有Material/MPB不得提前销毁。保存 `receiverIdentityEnabled`、`receiverIdentityStatus`、`receiverIdentityDraws`、`receiverUnknownRectangles`、`receiverIdentityBufferBytes` 和 `changeRegionBytes`。

身份四个 pass 现已纳入可选反馈：原生首段延伸到身份解析末尾，Recorder 使用七个局部范围。仍需用 GPU profiler 分别测量这些阶段，核对依赖顺序、阶段间等待及范围外成本；反馈之和不能代表全部 GI 或整个应用的 GPU 时间。

可选 receiver 来源票据专项场景：

- `receiverSourceTracking` 默认关闭。单独启用后，默认最多 1,024 条 submesh 记录，`receiverFingerprintBudgetMiB=16` 是每次 prepare 和每次捕获前 revalidate 各自的逻辑网格字节预算，不是两次合计的每帧预算、CPU 时间或峰值内存上限。记录额外对象扫描、材质观察、hash 与分配成本，多相机分别测量。超预算／不可读／不支持来源维持当前 GI，不能被当作已跟踪像素。
- 放置普通无 Proxy 的 opaque URP Lit MeshRenderer，确认它可以进入 CPU 来源记录；同场景放置不可读网格、Skinned、LOD 成员、静态合批或额外顶点流作为拒绝对照。没有 Proxy 不应单独成为 CPU 跟踪失败原因，也不代表已自动加入世界 GI 遮挡结构。
- 两个实例共享同一可读 Mesh，在保持顶点数、索引数和 bounds 不变时编辑顶点／索引／捕获属性，故意不通知一次以检查预算内指纹核验；再测试显式 `NotifyGeometryChanged`。首次成功核验也应使此前缓存的 SDF/chart 来源重新验证。切换预算与记录容量后，未知不能冒充未变化；过期烘焙资产仍需重烘焙，检测本身不重建资产。
- 用两个相机交替渲染，在 prepare 后、捕获前改变变换、网格、材质、贴图版本或对象层／lightmap 输入。来源重验失败应撤销该待发布快照，不停止当前 GI；同帧重复、跳帧、失败、销毁重建和过期回调不得发布其他相机／其他 receipt 的矩阵。这里只是命令成功记录的 CPU 合同，不是 GPU fence 或像素身份测试。
- 比较 renderer MPB 与非空 submesh MPB 的整体替代规则。修改材质 `_Cull` 应改变来源；仅在有效 MPB 中写 `_Cull` 不应被解释为修改 raster Cull，仍按源材质绘制。对 Lit 使用 RenderTexture／CustomRenderTexture，更新 GPU 内容后检查当前材质捕获仍更新，同时来源不获得可复用历史资格；普通 Texture2D 的 GPU／原生写入需生产者正确递增更新计数，不能只相信引用未变。
- 保存 `receiverTrackedSubmeshes`、`receiverUntrackedRenderers`、`receiverFingerprintMeshes`、`receiverFingerprintBytes`、`receiverSourcesPublished`。前两项是 CPU 来源数量；fingerprint 两项是准备阶段的成功网格数和已记账逻辑字节，不是两次核验总成本。Published 可只包含部分合格来源，仅表示成功记录票据，不能据此声称像素覆盖、GPU 完成或对象 motion 已启用。

其余集成验收：

- 先记录 Console 导入结果，再做独立 Player 构建，保存 Editor/Player 日志。检查有无缺失 kernel、未绑定 buffer/texture、Render Graph 验证错误。
- 运行 `Tools > Hybrid Lumen GI > Create Validation Scene Assets` 创建独立验证场景。先关闭其他 GI、环境/probe/baked 间接项和自动曝光，避免把重复光照误认为颜色反弹。
- 先软件路径：白墙与色墙、黑室、发光面、金属、贴图/多子网格、薄墙、凹腔、离屏物体、移动门与移动灯。分别记录真实 chart 和六面 fallback；真实 chart 凹腔捕获已接入，但实际覆盖、漏光和有限分辨率误差仍须逐项验收。
- 运行 `Tools > Hybrid Lumen GI > Validation > Probe CPU and GPU Color Contract`，保留项目 `Logs` 中的 JSON。它用于核实 CPU 材质颜色和真实 URP shader 输入约定。
- 然后启用硬件路径，记录实际是否进入 DXR 及 fallback 原因。颜色、遮挡与软件路径的差异需逐项解释。
- 验证发光方向采样：默认 `emissiveSamplingWeight=0.5`、`maxEmissiveProposals=16`（上限 32），分别测试权重零、预算零和默认值；零预算仍清空提议表，不能保留旧源。用发光贴图、动态 MPB、遮挡小亮面、页复用和 HLOD 新旧切换，检查同队列捕获/统计后只由 published 对象构建提议。固定曝光与总射线数，将稳定亮度均值对照关闭采样的高采样参考，再分别记录方差和 GPU 时间；不能把更亮当作改善。
- 运行 `Tools > Hybrid Lumen GI > Validation > Log Runtime Diagnostics`，保留Console JSON：观察warming、材质页预算、GPU回读失败、global bricks积压、DXR重建与属性上传计数。正常刚体更新不应持续增加三角形属性上传计数。
- `proposalCapacity/proposalBudget` 属于原 atlas 方向引导；`maxAreaEmitterTriangles` 控制新增精确面积样本。分别关闭方向引导、面积采样，再一起开启，以高采样参考检查均值和方差。只配对命中 Le，反射/cache 项维持原权重；屏幕最近命中胜出时抑制对应面积项。alpha 孔、不同子网格、薄层和镜像实例需实际对照。参见 [EmissiveSampling.md](EmissiveSampling.md)；离线积分不能替代图像和时间检查。
- 测试 HLOD 时，先让新表示完成材质和 patch 初始化；只有来源、卡索引、布局和代次仍匹配的 GPU 回读才能授权整组发布。用极小容量、变长 chart 集合、快速往返、旧资产替换及运行时纹理编辑检查旧票据不会误发布。改变 patch grid 应重建 atlas/anchors 并重新初始化。分块卸载需应用在 fallback 已发布、所有相机无引用后显式回报安全；加载完成本身不代表 GI 已就绪。
- 如验证原生漫反射GI替换，选择stock Lit专用层、Forward/Forward+、关闭MSAA并使用signed RGBA16/32F HDR。保持默认Additive的项目不会自动扣原生GI。Deferred、APV、Subtractive、非标准材质不是此替换路径的已支持范围。
- 固定相机序列、曝光和随机条件，保存线性 HDR 对照及 GPU profiler capture。记录移动/关灯后的残留时间、稳定后的误差、CPU/GPU p95/p99 与峰值显存。

完整场景矩阵见 Validation.md。请将工程版本、日志、颜色探针 JSON、复现步骤、画面对照和 profiler capture 一起返回；不要仅以“看起来有效”作为生产放行证据。

## 可选 GPU 预算反馈验收

`adaptiveGpuBudget` 默认关闭，`targetGpuMilliseconds` 默认零；关闭时不探测或加载计时 DLL。先记录目标设备基线，再设置正数目标并启用。每相机只调整 patch/capture/brick 更新数量，最低比例默认 0.125；容量、分辨率、射线数和材质 draw 上限保持不变。原生计时保留三个区间，首段在启用对象身份时覆盖材质捕获与身份四个 pass；Recorder 则使用三个或七个在各自 pass 内配对的范围。原生区间可能包含阶段间等待，与 Recorder 局部范围之和并不严格相等。两者都不包含范围外准备上传或末尾的原生 query resolve，也不代表整个应用 GPU 帧时间。

如需验证可选原生计时，按 [NativeGpuTiming.md](NativeGpuTiming.md) 构建或取得对应候选的 `HybridLumenGIGpuTiming.dll`，放入测试工程 `Assets/Plugins/x86_64`，在 Plugin Inspector 中仅启用 Windows Editor/x86_64 和 Windows x86_64 Player，关闭 Any Platform。源码包不会自动安装该 DLL；不要保留同名副本或手动热卸载。`preferNativeGpuTiming=true` 优先使用就绪原生提供器，缺失/不支持时回退 Recorder；两者无有效反馈时使用静态配额。

原生池有 128 个可按 fence 完成循环回收的提交槽，每项明确关联相机 owner、配置/设备代次及源帧。Recorder 回退仍只有 32 个不复用的生命周期通道，也没有 query ID 或跨 pass 原子快照。诊断应同时保存 `gpuTimingProvider`、`nativeGpuTimingStatus`、`nativeGpuPendingSubmissions`、`nativeGpuMeasuredSourceFrame`、有效观测标志、工作配额和最低配额压力标志。原生 ring 暂满是缺测，不应导致提供器反复切换；消费帧不能当成原生结果的来源帧。

分别在 Editor、Development 和 Release Player 对照独立 GPU profiler；测试原生 render pass 开/关、两个相机、长期创建销毁相机、停用恢复、同帧重复渲染、配置/后端切换、设备重建和 GPU backlog。还需检查身份开启、关闭、因能力或预算回退时的实际计时范围与反馈重置；Clear 必须在材质捕获后执行，Resolve 必须在传输前完成。另验证 DLL 缺失时的 Recorder 回退，以及 Recorder 生命周期通道耗尽后的静态回退。计时标记命令异常应保留 GI 业务执行；未知录制结果会使该 Recorder 通道停用，不得靠切换设置重新使用它。真实计算或绘制失败仍须撤销屏幕历史。短缺测保留配额，持续缺测恢复静态上限。现有 C++ 与 WARP 软件适配器测试使用模拟 Unity 宿主，不是 Unity、实体显卡或实际设备丢失证据；不能认定生产预算调度已完成。控制规则与剩余验收见 [GpuBudget.md](GpuBudget.md)。

## 文件完整性

交付归档包含 `SOURCE-MANIFEST.json`，列出每个文件的大小与 SHA-256。在解压的包目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File Tests/VerifySourcePackage.ps1 -ArchivePath "下载的源码包绝对路径.zip"
```

通过仅说明传输和归档完整性。`Tests/offline-validation-results.json` 保存该候选统一离线检查的输出、退出码、源码哈希和编译记录；`Tests/shader-validation-results.json` 是核心 shader 报告的独立副本。以统一 JSON 的实际结果为准，不沿用旧候选的测试总数。执行 `Tests/Verify-OfflineReport.ps1` 核对本地源码与报告一致。打包脚本拒绝缺失、失败或过期报告；此门控也不代表 Unity/GPU 验收通过。

## 尚未关闭的主要生产关卡

剩余生产关卡主要是 Unity 导入/API 编译、Player、实际软件/DXR画面、动态收敛、大规模覆盖、GPU p95/p99、峰值显存与长时稳定性。生成的 charts/SDF、精确三角与形变快照均有有限精度和工作预算；全表面积覆盖、任意 ShaderGraph/透明/私有 GPU 顶点变形、完整 Lumen reflections 不因本包而自动成立。按 GPU 观测调整配额及独立 IO/复制/RTAS 准入不构成设备毫秒硬上限。ProductionPlan 的生产放行条件仍有效，不能由离线结果勾选真实运行验收。
