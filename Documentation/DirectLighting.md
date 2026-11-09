# 直接光、分层与独立阴影查询

直接光策略从 integration-09 起接入屏幕接收面、世界卡片和软件／DXR 阴影查询。它仍是独立漫反射传输的受限实现，**不是完整 URP Lit 光照等价实现**。早期离线候选的报告及源码哈希以 [OfflineValidation.md](OfflineValidation.md) 为入口，不能沿用旧归档结果。工作区 Tests JSON 会随候选推广更新，不是 integration-13 原件的固定链接。早期原生 D3D12 证据使用 WARP 软件适配器和模拟 Unity 宿主；后续各自来源的有限Unity/实体GPU结果见[推进表](DevelopmentProgress.md)，本节各项合同不因此获得整体验收。

封存integration-13的精确材质来源、CPU receiver跟踪及可选对象历史有56阶段/126项选定DXC的历史统一离线证据。新增命中材质和足迹传播改变了当前传输接口，单项结果不能替代新的统一通过结论。版本与范围见 [OfflineValidation.md](OfflineValidation.md)。这也未补齐完整Lit光照；像素身份与对象历史的受限范围见 [GeometryHistoryContracts.md](GeometryHistoryContracts.md)，实际Unity/Player覆盖与图像仍待验收。

## 灯光快照与照明

方向、点和聚光灯的 `Light.bounceIntensity` 控制这盏灯注入次级命中表面的照明。倍率 1 使用原强度，正倍率只在灯源处乘一次，倍率 0 让灯退出 GI 灯表。相机所见的原生 URP 直射仍由该灯的颜色与强度决定。无 cookie 点光的朝向也不参与 GI 灯表比较，原地旋转不会重置附近的照明历史。聚光灯方向仍参与比较。[固定点光与离屏色墙的画面对照](../LocalComparison/Review/analytic-light-bounce-01/result.md) · [Unity 6 灯光间接倍率](https://docs.unity.com/en-us/engine/6000.0/script-reference/unityengine/light/bounceintensity)

可选 `environmentCubemap` 为确定逃逸的世界射线提供方向性环境辐亮度Li；它只接受静态、未编码线性RGBAHalf/RGBAFloat，以LOD0读取，并替代原常量环境。空引用保留 `environmentRadiance` 的原转换与行为，不支持的格式会警告后回退常量。原权重继续计算D=E/π，不额外乘反射率、曝光或π。调用方持有资产并保证使用期间内容不可原地修改；引用切换沿用设置失效。完整输入及有限compute证据见[环境合同](EnvironmentRadiance.md)。

输入Cube不改变可见skybox、环境SH、lightmap或反射。默认Additive仍保留原URP漫反射GI，可能重复计能；指定Cube不会自动切换到 `ReplaceNativeDiffuseGI` 或清空全局Lighting设置。选择替换模式须满足其独立[合成合同](NativeDiffuseComposition.md)，本轮Cube验证不扩大支持范围。

`HybridLumenGILights` 在每个被渲染的引擎帧扫描一次 `Light`，包含 inactive 对象，并按 InstanceID 排序；同一 Renderer Feature 的其他相机复用引用列表，再读取当前活动状态和属性。扫描时已存在的 inactive 灯在同帧激活后可以被后续准备观察到；扫描后新创建的灯最迟在下一渲染引擎帧被发现。它不依赖某个相机的 visible-light 列表。支持方向、点、聚光灯，排除 Baked-only、未启用及无效数据；Mixed 的完整烘焙混合语义不在此合同内。默认最多选择 16 灯，上限 32，选择顺序不是按光照重要性排序。

直接漫反射量仍为 `D = E/pi`，物理方程为 `Le + rho * (D_direct + AO * D_indirect)`，不会把已经照亮的 camera color 当作光源。实际screen/world命中的直接项使用`rho∈[0,1]`，递归缓存项单独使用`min(rho,0.98) * AO * bounceFeedback * D_cache`；该反馈限制有偏，不再同时压低高反射率材质的直接反射。见[路径一致性修复](../LocalComparison/Review/direct-reflectance-consistency-01/result.md)。点／聚光使用距离和范围衰减，聚光另有内外角衰减；线性颜色、强度及启用时的色温进入灯记录。是否匹配目标工程的真实光照单位和图像，仍需参考渲染验证。

已知且有效的零漫反射表面，其入射光项权重严格为零。世界命中按`saturate(diffuse)`判断，屏幕命中按捕获RGB精确全零判断：通过原命中/材质及有限性资格后，只返回原发光贡献；世界路径仍乘原发光MIS权重，total与非解析来源输出保持同一发光值。无关阴影或反弹缓存的unknown不再撤销这份已知发光／已知黑。未知材质、非有限输入和任何小正漫反射不会借此变成已知零；屏幕命中、距离和未知规则保持。该改动不扩展完整金属镜面传输，也不构成实测加速或整景颜色验收。见[原零漫反射修复与Release80整合](../LocalComparison/Review/zero-diffuse-known-radiance-01/result.md)。

后续源码对严格零AO作同类收束：仍计算有效直接光与Le，仅跳过权重为零的反弹缓存查询；微小非零AO与异常输入保持原处理，屏幕沿用原材质AO解码。该追加原仅有独立源码审阅，现已随Release81部署并通过普通构建；未新增该条件的专项运行或画质结论。Release80不包含此追加。反馈系数为零原本已经跳过缓存，不重复算作修复。

接收面的 GameObject layer bit 必须与 `Light.cullingMask` 相交。URP rendering layers 启用时，再检查接收面的 rendering-layer mask 与灯的照明 mask；照明 mask 来自 `UniversalAdditionalLightData.renderingLayers`，按 URP 的已定义层限制。阴影 mask 最终读取原生 `Light.renderingLayerMask`：URP 通常按 `customShadowLayers ? shadowRenderingLayers : renderingLayers` 同步它，但脚本之后直接覆盖原生值时，以实际原生值为准。因此不能把它当照明 mask，也不能只从 AdditionalLightData 推导投影策略。[固定版本的层数据与同步实现](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Runtime/UniversalAdditionalLightData.cs#L166)、[照明层规范化](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Runtime/ForwardLights.cs#L537)。

灯记录的独立 flag 指示是否启用 rendering-layer 过滤，不能用 mask 是否为零推断功能开关。启用时 mask=0 是合法空集合；禁用时跳过这一维过滤，包括接收面 rendering mask=0 的情况。GameObject `cullingMask=0` 始终排除所有接收面与投影者。所有 mask 保留完整 uint32，包括 bit 31。

构建相机的 GI 灯表时，`cullingMask` 为零的灯会让出名额；启用渲染层时，有效照明层掩码为零的灯也会让出名额。最后一盏有效灯因此退出时，收集器报告旧灯移除，灯表变空，以便缓存清理原解析光贡献。单独将投影者的阴影层掩码设为零，灯仍可照亮接收面。公开的 `TryPack` 仍可读取原始掩码。

## 阴影不等于 GI 可见性

`TraceShadow` 与一般表面／GI 可见性查询分开。`LightShadows.None` 或 shadow strength=0 跳过该灯的阴影射线；有遮挡时直接光乘 `1 - saturate(shadowStrength)`，无遮挡时乘 1。Soft 模式目前也只得到硬阴影，不生成半影。这与 URP 将阴影衰减向白色插值的强度约定一致，但不等于重现其 shadow-map 过滤。[固定版本 Shadows.hlsl](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl#L328)。

阴影候选须为 published owner，并同时通过 GameObject culling mask、启用时的阴影 rendering layers，以及 `Renderer.shadowCastingMode != Off`。DXR 在提交每个候选前过滤；排除前方不投影或层不匹配对象后，仍继续寻找后方合法投影者，不能先取最近命中再将整条射线判为无遮挡。

普通 URP Lit 的逐材质 `ShadowCaster` 通道也参与精确候选覆盖。关闭通道时，软件 BVH 和 DXR 跳过该材质的阴影覆盖，继续寻找后方投影者。普通表面按独立的覆盖规则判断。通道切换纳入既有阴影覆盖比较，远处接收面刷新与收敛仍按 G3 验收。SDF 和解析体仍按各自的近似规则处理。[双后端实机对照](../LocalComparison/Review/shadow-pass-227/result.md)

新命中材质路径将已到达表面的空间足迹投影到阴影方向：方向光保持平行半径，点/聚光向实际灯位置收缩。点光阴影射线从加bias的原点重新计算方向和焦距；N.L与距离衰减仍在真实表面点求值。近远场跳跃只推进半径，不改变材质观察源。普通表面覆盖在依赖已赋值的 BaseMap 时保留 parallax。默认白底图可直接以材质 alpha 判定覆盖，stock-shadow 覆盖禁用 parallax。未知覆盖仍遮挡并使入射光未知。当前 CPU 材质快照与精确几何准入允许普通 Lit 二值 alpha-test；DXR 强制非不透明候选逐项求值，已知透明继续遍历，已知实心或未知覆盖保留遮挡。代码接入不代替实际候选遍历的验收，也不扩展至 MSAA／A2C 或完整材质等价。空间LOD过滤也不能替代完整区域可见性或软阴影。[默认底图对照](../LocalComparison/Review/default-base-alpha-207/result.md)

成功录制的精确命中材质会保存投影覆盖输入。覆盖变化时，已选实时投影光的可达距离加一段 GI 追踪距离用于局部时域失效和缓存优先级。方向光取阴影距离，点光和聚光取范围。[实际方向光对照](../LocalComparison/Review/cutout-shadow-change-209/result.md)

Scene 记录投影策略变化前后的层掩码及面向策略。某盏已选实时投影灯的遮挡资格或双面覆盖发生变化，且可达距离超过原局部范围时，按灯的距离扩展旧／新边界并提高域内缓存的调度优先级。保持禁投影时的层掩码变更沿用原局部范围。实测点光关闭投影的软域半径为 34，远地板取得调度优先级。[实际通知与对照](../LocalComparison/Review/shadow-policy-reach-217/result.md)

已发布投影者移动或撤除时，Scene 保留对应旧、新边界的投影资格，按所选灯的实际范围通知可能受影响的远处缓存。加入和拓扑事件共用端点规则。照明域与刚体旧缓存拒绝半径分别记录，原几何分类和来源判断继续生效。双网格 DXR 实测覆盖移动和撤除。[实际通知和适用范围](../LocalComparison/Review/shadow-caster-reach-218/result.md)

手动通知导致旧投影者实际撤出、而新网格未获上传时，当前帧按旧发布的投影资格扩大照明通知。新网格取得上传名额后按加入事件通知当前边界。实测覆盖同一可读网格保持顶点数和包围盒的原地编辑，以及一个更近代理占用当帧名额的情况。[延期与恢复的实际结果](../LocalComparison/Review/deferred-caster-reach-219/result.md)

精确软件与 DXR 只在实际采样已分配纹理时要求有效足迹。无足迹时仍可按标量判定已知透明或实心，确需纹理的覆盖保持未知并保守阻挡。完整材质解析另外要求其自身使用的纹理与属性有效。[双后端实机对照](../LocalComparison/Review/exact-footprint-and-page-admission-155/result.md#足迹缺失时的精确命中)

| Renderer 模式 | 当前阴影查询 | 一般表面／GI 查询 |
| --- | --- | --- |
| Off | 跳过此投影者 | 保留其几何遮挡和材质命中 |
| On | DXR 遵守该子网格有效材质 Cull | 按原有材质／表示合同 |
| TwoSided | DXR 阴影候选绕过材质 Cull | 不因此改变一般表面的 Cull、rawNg 或 Ns |
| ShadowsOnly | 作为投影者，DXR 遵守有效 Cull | 不借此删除已注册世界几何；相机可见性仍由 Unity 的绘制路径决定 |

这些模式对应 [Unity ShadowCastingMode 枚举](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.ShadowCastingMode.html)。软件 SDF／解析体可以筛选 owner 的 Off 与层 mask，但没有原生三角 submesh 和面向信息，不能精确复制材质 Cull；其保守双面遮挡须单独验收。rawNg、Ns 与偏移的区别见 [GeometryHistoryContracts.md](GeometryHistoryContracts.md)。

这里的材质 Cull 来自原始 source Material。[Unity MPB 不支持改变 render state](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/MaterialPropertyBlock.html)，所以 per-renderer 或 per-material `_Cull` 不改变原对象的 raster Cull，也不再改变世界卡捕获副本、卡片面向 metadata 或硬件逐子网格 fallback 的 Cull。受支持颜色、金属度、发光等 uniform 仍遵守非空 per-material MPB 整块优先规则；不能为了忽略 `_Cull` 而合并两个 MPB 或丢弃其他有效覆盖。真实 source Material Cull 改变会更新相应页和命中策略，TwoSided 阴影模式的独立规则不变。

## 数据与生命周期

| 数据 | 布局／成本 | 生命周期 |
| --- | --- | --- |
| 灯记录 | 80B：四个 float4，加 culling／照明层／阴影层／flag 四个 uint | 每相机保留 32 项 buffer，即 2,560B；有效项按当前灯快照更新 |
| owner 策略 | 16B/scene slot：GameObject layer bit、rendering mask、shadow mode、保留零 | 与 80B ProxyGpuData 共用槽位、dirty 上传区间和相机生命周期；未驻留／等待上传槽清零 |
| 屏幕接收面策略 | 通常为全分辨率 `R32G32_UInt`，8B/pixel | 活动的静态 Shadowmask 使用 RGBA32 UInt，前两个字保留完整层掩码，新增两个字存四个半精度遮罩通道 |

UnityPerDraw 不提供 GameObject layer。当前捕获将材质层与相机 culling mask 相交，建立最多 32 个互不重叠的单层 RendererList；每次 draw 前只传 0–31 的 layer index，shader 转成 uint bit。`GetMeshRenderingLayer()` 从当前 draw／instance 的数据读取完整 uint mask。普通捕获使用 MRT Target2，原生漫反射替换使用 Target3；fragment 的 instance setup 在读取策略之前完成。mask 不经过 half、颜色编码或浮点整数往返。平台必须支持该整数格式的 render/sample 用法，且普通／替换模式分别至少支持 3／4 个同时 MRT，否则跳过此 GI 路径。真正的 Unity builtin 绑定、实例变体与整数 MRT 行为仍须在目标工程验证。

Proxy 在主线程渲染边界观察这三项策略变化，只提升传输版本，不提升 mesh geometry-content revision。Scene 产生 `ChangeKind.Lighting=128`；纯策略变化保留几何并使附近照明 reactive，同时拒绝旧 HLOD 票据。与移动、拓扑或显式几何编辑组合时仍保留相应硬失效。策略变化本身不要求重传 DXR 三角属性；当前 owner revision 仍可能保守触发表面重捕获和本地 cache 初始化。

世界表面现在保存 `MaterialSource` 的逐槽不可变观察，比较来源引用、shader/keywords、属性存在位与值、纹理引用/`updateCount`/sampler 状态；compact hash 相同也必须通过精确比较和出版前重验。哈希中的同值不同属性别名已修复，实际等价证明由快照承担。原 Renderer、Material 和 MPB 不被修改；材质作者颜色与 MPB shader-space 值的来源被保留，不能在比较时重复做 gamma 转换。[GPU 写入纹理须显式递增 updateCount](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Texture-updateCount.html)：RenderTexture/CustomRenderTexture 仍允许当前捕获，但不复用旧来源票据；普通 Texture2D 的未通知 GPU/native 写入也无法自动验证。动态 probe、shader 全局数据和未观察到的后续修改另需失效策略。

另有默认关闭的 `receiverSourceTracking` 开发选项：共享 `MeshSource`、`Discovery/Registry` 和每相机 `ReceiverHistory` 已接入 Feature 准备、capture 前重新验证与完成票据。它覆盖不依赖 Proxy 驻留的普通来源，并重新检查同帧 source set、矩阵、有效材质、renderer lightmap/layer 上下文和预算内完整 Mesh 指纹；首次网格观察也通知共享来源版本。默认 1,024 条 submesh 记录及每次准备/重验各 16 MiB 逻辑指纹字节限额，超预算或不支持来源标记未知，仍保留当前 GI。单独启用该选项只运行CPU跟踪。另一个默认关闭的 `receiverObjectHistory` 选项会自动启用来源跟踪，并接入显式身份UAV、双身份历史与CSTemporalIdentity；仅对完整身份、f-1票据及正相似相对变换尝试复用，失败保留当前GI。跟踪 `receiveShadows` 的变化仍不等于完整实现其光照语义。完整合同见 [GeometryHistoryContracts.md](GeometryHistoryContracts.md)。

对象历史关闭时，基础屏幕理论分配为每相机：

```text
Additive = 24 * fullWidth * fullHeight + 112 * giWidth * giHeight
Replace  = 36 * fullWidth * fullHeight + 112 * giWidth * giHeight
```

1920×1080、960×540 GI 时分别为 107,827,200B（102.83203125 MiB）和 132,710,400B（126.5625 MiB）。两张 RGBA32F moments 已计入，相对旧 RGBA16F 增加16B/GI像素。owner 策略另加 `16 * sceneSlotCapacity`，默认 128 槽为 2 KiB。这些是逻辑分配估算，不含灯／BVH／SDF／卡片／世界缓存、RTAS、驱动或资源分配粒度。每渲染引擎帧全灯扫描、同帧多相机打包及最多 32 个 RendererList 的 CPU 与 GPU 成本需要实测。

`spatialLightSelection` 默认关闭。开启且有效灯数超过 `maxLights` 时，可在已证明覆盖的有限求值范围之外排除点光／聚光；剩余灯保持原发现顺序、重数、强度和80字节记录。范围包含本相机实际逆投影覆盖的屏幕，以及全部本次 published/warming 遍历与表面捕获范围，包含离屏缓存。首版只支持 Direct3D12、完整视口、非XR、有限普通透视／正交相机；未知、自定义、物理相机或不可靠范围均退回原准入。范围可能很宽，不能保证每个场景都能节省灯位。

方向光、相交／边界与不能可靠证明无贡献的局部灯继续参与准入。相关灯仍超过容量时按原顺序截断；这不是重要性排名或完整光能保证，也不增加32灯上限。诊断分别报告有效候选、实际域外排除、入选、剩余容量遗漏、范围有效性与回退原因。关闭模式不额外完整打包所有灯，因此候选总数与遗漏数显示 `-1`（未统计）。逐相机精确变化列表继续处理实际入选／退出，而不把表压缩当作光照变化。

可选对象历史另加16B/full pixel、32B/GI pixel和80B×max(1,预留row容量)；世界变化域buffer为1,088×48B，单独计入世界资源。身份预算不足先关闭对象history、重算基础当前GI，只有基础GI也无法容纳才跳过相机。只读Mesh指纹预算不等于CPU时间或峰值内存：发现扫描、读取/哈希、材质快照、显式draw和未知mask须另行profiling。GPU反馈已纳入身份四pass：原生ABI1的ReceiverCapture从材质捕获延伸到身份resolve后，另有transport/composite；Recorder按实际identity开关汇总3/7个局部成对范围。计时API或诊断marker失败只影响反馈，真实渲染失败仍撤销历史。CPU准备、范围外上传、query resolve和额外驱动成本不在该和式内；这些接线不是全部GI硬预算或Unity实测证明。

## 尚未完成的合同与验收

在 URP 开启 Mixed Lighting、质量模式为 Shadowmask 且场景有有效烘焙遮罩时，静态受光面按每盏已烘焙 Mixed 灯的通道取遮挡。屏幕捕获使用该 draw 的静态光图坐标；世界端在图卡捕获时按 renderer 的 lightmapIndex、UV2 与 lightmapScaleOffset 采样真实遮罩。每张活动世界图集增加一张 RGBA16F 纹理，8B/texel，计入原有表面预算。实时投影与烘焙遮挡共同限制该灯的反射。材质关闭接收实时阴影时，烘焙遮挡仍可生效。同槽遮罩纹理或其内容代次变化会使旧历史失效。

世界端需要当前命中与可用的图卡像素匹配。已有遮罩但缺少可信图卡 UV 时，受影响且不能由实时遮挡确定的估计记为未知。普通静态非合批 MeshRenderer 的原 UV2 可用于图卡，额外顶点流替换 UV2、变形快照、动态探针遮挡及 Distance Shadowmask 有各自的支持边界。

非三角的世界命中可以采用受光面的材质阴影策略。启用材质读取、只有一个材质槽及子网格的普通不透明 URP Lit MeshRenderer 使用材质的 `_RECEIVE_SHADOWS_OFF` 关键字。关闭接收实时阴影后，该面仍可受到被遮灯的直接照明并将其反射给其他表面。物体自身投射阴影仍由投射策略决定。手动代理材质及来源不唯一的多槽回退保留接收阴影，精确三角命中沿用其实际子网格材质。

完整 Mixed Lighting、软阴影／半影、cookie／IES、Renderer 级接收阴影、原生 hit-UV alpha-test 阴影及 SDF 三角 Cull 仍有未覆盖条件。方向光阴影距离与场景驻留也会限制遮挡范围。

朋友应测试 shadow strength 0／0.5／1、Off 保留 GI 可见性、前方不投影而后方仍遮挡、TwoSided 只影响阴影、GameObject bit31、已定义 rendering bit31、空 mask 与功能禁用、独立 custom shadow layers 及之后直接覆盖原生 shadow mask、同帧激活旧灯／创建新灯，以及多相机之间的灯和对象层变更。保存独立 Lit 对照、线性 HDR 图像、Console／Player 日志及 profiler capture。CPU adapter、录制测试和 DXC 通过均不能代替这些引擎与实体 GPU 结果。
