# 几何来源、法线与屏幕历史

工作区已在共享Mesh版本、普通接收面发现、精确材质观察和每相机CPU票据之上，接入可选像素身份与对象运动历史。`receiverObjectHistory`默认关闭，开启时自动启用CPU来源跟踪；单独开启`receiverSourceTracking`仍只建立CPU票据。历史主报告 SHA256 `54C24D2BAA65BC30D725B226C86EBC460307173FA0674145D67A088A455AF7C7`只对应封存integration-13的56阶段结果；工作区 Tests JSON 会随候选推广更新，不能作为该历史原件的固定链接。integration-14已把新增命中材质与空间足迹纳入70阶段统一回归并通过。版本、当前报告与证据范围以 [OfflineValidation.md](OfflineValidation.md) 为入口。Unity/Player/实体GPU验收仍待完成，旧归档不能代替当前来源证据。

## 几何更新与 SDF 来源

每次 `Scene.Prepare` 在读取实例版本之前调用代理的 `RefreshSignatureForRender()`。它与 `LateUpdate` 共用同一签名检查，所以后执行的脚本或手动相机渲染前的变换也能被观察；同一状态被多个相机查询不会重复增加版本。

原地修改顶点、索引或来源属性后，在主线程调用 `HybridLumenGIMeshSource.NotifyGeometryChanged(mesh)`；有代理时也可调用该 Mesh 任一代理的 `MarkDirty()`。共享来源按实际 Mesh 引用保存不可变版本对象，不以 InstanceID 或可回绕数字单独判同。Proxy、SDF 来源检查和 receiver registry 读取同一个版本；不依赖当前相机的卡片、SDF 或 DXR 驻留。代理的几何内容版本独立加入 `Manual` 变化标记，同时发生移动或材质变化不会吞掉几何重建请求。刚体运动和自动检测到的普通材质变化仍只更新传输版本。`MarkDirty()` 是保守通知，手动材质属性块修改使用它时也可能触发几何重建。

普通 MeshRenderer 使用同一网格移动且前后来源范围不相交时，同帧材质变化也会触发邻近世界缓存的可见性刷新。世界缓存按原影响半径拒绝旧递归输入。屏幕历史把包含材质变化的事件作为硬失效，仅纯姿态事件能获得本对象的历史例外。[同帧移动与改色的接线对照](../LocalComparison/Review/mixed-portal-change-296/result.md)

SDF 资产保存实际顶点位置和三角索引的 SHA-256 指纹。烘焙开始与提交时检查同一来源；提交前来源不符会拒绝结果而保留旧资产。载入后及显式网格通知后进行内容比对，稳定帧和刚体移动复用检查结果。多个 SDF 资产通过弱键 Mesh 标记共享失效；不同资产的有效性仍分别验证。法线贴图、UV 或材质不是距离体积的几何输入。

**旧版没有来源指纹的 SDF 需要重新烘焙一次。** 过期、无指纹或无法验证来源的资产不再进入就绪 SDF 元数据；对应旧/新表示域被失效，软件路径按既有规则回退为明确的解析近似，不能把它当成真实网格。诊断字段 `rejectedSdfSources` 给出该帧被拒绝的实例数。HLOD 的源检查也拒绝这些资产，不能用旧就绪票据发布它们。

相同顶点数、索引数及 bounds 的编辑不能靠廉价元数据识别。开启 receiver 来源跟踪后，注册表在预算内对受支持、可读 Mesh 执行完整内容指纹检查，可检测这类未通知编辑；关闭该功能、超出预算、不可读或不支持的来源仍须显式通知，不能沿用旧观察作为已验证内容。每个注册表对 Mesh 的**首次成功完整观察也调用共享通知**，防止该注册表建立前已发生的编辑继续使用旧 SDF/chart 肯定结果。来源通知本身只使旧数据失效；新增 `HybridLumenGIDeformedMesh` 负责 Skinned 或显式可读 producer 快照的后台 SDF/chart 重建与原子发布，详见 [形变流程](DeformedGeometry.md)。GPU 私有变形需先提供已完成的可读快照；这不扩大 receiver 对象历史的来源支持合同。

完整指纹预算使用只读 Mesh 数据计算逻辑字节，包括顶点流、索引、布局/submesh、bind poses 和骨骼数据；当前不接纳 blend shape 来源。默认 `receiverFingerprintBudgetMiB=16`，分别约束来源准备和捕获前重新验证，每次操作内共享 Mesh 只计一次。`FingerprintBytes` 不是 CPU 毫秒、实际内存读取量或峰值分配保证；指纹、发现扫描和快照数组仍需目标场景测量。预算不足返回未知来源，不能用旧指纹补齐验证。

## 有效材质快照与世界表面页

`HybridLumenGIMaterialSource` 只读观察普通 Renderer 的指定 material slot，不要求 Proxy。快照保留 Renderer/Material/Shader 实际引用、槽位及布局、排序后的 keywords、pass/queue/raster 状态、受支持 Lit 属性的存在位和原始值，以及纹理引用、`updateCount`、布局和 sampler 状态。材质作者颜色与 MPB shader-space 值保留不同来源，不在身份比较时重复做颜色空间转换。数组由快照独占；原 Renderer、Material 与 MPB 不被改写。

有效 MPB 按 Unity 的[整块优先规则](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Renderer.SetPropertyBlock.html)选择：非空 per-material block 完全取代 per-renderer block，再由该 Material 补足未覆盖字段。即使 per-material block 只有无关属性，也不能从 renderer block 合并剩余字段。[MPB 不支持改变 render state](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/MaterialPropertyBlock.html)，因此 Cull 取自来源 Material；MPB `_Cull` 不得改变原对象的剔除规则。世界卡捕获副本、卡片面向 metadata 和硬件逐子网格 fallback 都按此处理，其他受支持 uniform 仍遵守 MPB 优先级。

SurfaceCache owner 保存逐槽精确快照。重捕获和 `IsSlotSourceCurrent` 不再只凭 32 位 CRC/hash 判断：compact signature 可提前提示变化，值相等时仍必须逐项比较实际来源。旧 BlockHash 同值不同属性的确定别名已补 property ID 和存在位，精确快照才是材质等价证明。无效属性不能发布新页；几何来源版本和签名是另一个合同，不因材质比较精确就宣称全部几何身份已精确化。

[Texture.updateCount 的官方合同](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Texture-updateCount.html)要求 GPU 写入方自行递增计数。RenderTexture/CustomRenderTexture 快照仍允许当前世界材质捕获，但 `CanReuseHistory=false`，下一次 Prepare 要求更新，旧 HLOD 来源票据不能据此证明稳定；预算不足沿用既有缺页 fallback。普通 Texture2D 的未通知 GPU/native 写入同样不可由 CPU 自动验证，生产方须通知更新。全局 shader 数据、shader 热重载、动态 probe、稍后回调和实际 GPU 同步仍有独立失效责任；快照不是纹理像素哈希或 fence。

## Ng 与 Ns 的职责

Ng 是几何法线，Ns 是着色法线。表面卡片选择、捕获深度层匹配、缓存插值的平面约束和射线起点偏移使用 Ng；漫反射照明与着色方向相似性使用 Ns。强法线贴图不应导致正确材质 texel 被误判为另一层，也不能让同一几何平面的邻居被错当成跨层。

屏幕没有原始三角面法线时，用全分辨率深度邻域估计 Ng。它参考固定 Unity Graphics 版本的 Tap9 斜率选择，并增加世界空间外推、边界、有限性和退化检查；这是有拒绝条件的估计，不能当成精确三角身份。短距离世界追踪只有在位置与 Ng 一致时才能提供匹配命中的几何法线。

估计每个接收点最多增加八次邻域深度读取与五次逆投影；已确认的屏幕射线命中还需重读一次中心深度。实际开销需要 GPU 测量。重建失败时仍可保留当前屏幕单次反弹估计，但不会以 Ns 猜测世界缓存层。

## 屏幕历史纹理格式

继续使用原有的 RGBA32F 几何历史，容量与显存估算不变：

| 通道 | 内容 |
| --- | --- |
| xy | Ns 的八面体坐标，float2 |
| z | Ng 的 12+12 位八面体量化整数加一，合法范围 1 至 16,777,216 |
| w | 原始深度 |

z=0 表示无效接收面，z=-1 表示接收面有效但 Ng 未知。全部正整数编码可由 float32 精确保存；禁止把该纹理改成 half 格式，或对编码值进行双线性过滤。Ns/Ng 均须先解码再参与比较。CPU 方向样本中的 Ng 最大量化角误差约 0.0584°，不等于实际 GPU 误差上限。

时域重建保留 Ns 相似性检查，平面判断使用 Ng。空间滤波对两端 Ng 检查跨层距离。最终上采样以已知样点的 Ng 计算世界空间平面距离，在归一前拒绝超过原平面容差的样点。未知 Ng 的像素保留当前自身估计，上采样仅允许同一个全分辨率采样中心使用未知 Ng。没有可信候选时，合成保留已有画面和原生漫反射。[固定双层 DX12 对照](../LocalComparison/Review/composite-layer-edge-332/result.md)

局部解析灯的原变化域内，当前测量未知时可显示通过原重投影校验的旧值，年龄标为 0.5。滤波与合成沿用待替换样点的隔离规则，首次可信估计直接接管。已知测量沿用局部反应的短历史，灯光影响半径与同 Bounds 的其他变化分别保留。[固定平面实际着色器对照](../LocalComparison/Review/local-light-history-303/result.md)

## 历史来源与完成状态

URP 运动矢量描述引擎帧 f 到 f-1。屏幕历史必须来自同一相机在 f-1 成功记录的输出，不能仅凭纹理存在就复用。同帧重复、跳帧、时间倒退、资源重置与失败会拒绝旧历史；过期回调不能发布新帧的完成状态。此判断独立于 GPU 反馈是否开启。

Release83新增[实际双Base切镜的有限确认](../LocalComparison/Review/multi-camera-history-01/result.md)：同一Feature、两个独立HDR目标，B103切镜后57448个已知D／Ng点全部使用长度1；下一引擎帧A104原有46705个成熟点全部保持长度32、几何／材质与已知状态不变。仅此精确软件场景，不覆盖任意多相机、全部后端或完整图像／退休验收。

完成票据在合成绘制成功、计时清理已尝试后发布。它表示渲染命令成功记录到有序队列，**不是 GPU fence 完成证明**。真实渲染记录失败同时撤销屏幕历史与对应计时；可选计时标记失败只拒绝反馈，不撤销有效历史。没有为此额外重置世界缓存 epoch。

可选对象历史现在另存整数像素身份，并通过当前帧对象表提供已验证的前帧预测变换；未开启或无法证明身份时保留原来的保守路径。当前射线的局部命中身份仍不能替代屏幕像素身份，完整形变历史和一般遮挡依赖传播尚未完成。

## 灯光策略变化与可见性

Proxy的主线程签名检查新增GameObject layer、完整uint renderingLayerMask和shadowCastingMode。来源Renderer缺失时使用proxy GameObject层、默认rendering mask=1及ShadowCastingMode.On。改变这些值只提升传输revision，Scene记录`Lighting=128`；纯策略变化产生附近照明reactive，不冒充Manual几何编辑，也不因投影开关删除普通GI遮挡。组合移动/拓扑/显式内容编辑仍保留真实几何硬失效。Scene每槽位另有16B策略buffer，与80B代理记录同容量/上传区间，失效或等待上传槽清零；HLOD旧revision票据同时撤销。表面缓存目前可因owner revision保守重捕获，这不等于mesh属性重建。

投影模式和灯的阴影层用于独立shadow query；接收面的照明层另行筛选直接光。Off不妨碍普通表面命中；DXR的TwoSided只对shadow候选绕过材质Cull，不翻转rawNg或Ns，也不改变一般GI射线。软件SDF/解析体没有相同的源三角侧信息，不能宣称其材质Cull与DXR一致。屏幕接收面的当前帧8B整数policy纹理保存GameObject层bit和per-draw rendering mask；它不是前帧对象ID。新增 CPU 来源票据也没有赋予该纹理稳定对象身份。完整Lit缺口见 [DirectLighting.md](DirectLighting.md)。该灯光策略与新增对象历史已由本轮统一离线报告重新绑定；Unity、Player及实体GPU验收未执行。

## 三角命中、材质身份与偏移

`HLGIHit` 在调用栈中保留距离/位置、原始几何法线、独立Ns、owner身份和版本，以及有有效位的submesh/primitive/重心/UV/front-face。近远场空区推进只恢复调用者的绝对距离和位置，不能丢弃命中身份。硬件三角、signed/unsigned SDF和解析体是不同表示；SDF梯度不能制造源三角或面积PDF。

硬件的每个submesh仍对应独立instance，primitive ordinal通过16B表直接绑定物理card、chart ID、layout代次和geometryRevision。查询还核对当前owner range中的geometryRevision、stableId/revision及ready页；失效时不能重新扫描所有卡片。对应submesh的无贴图常量是明确的退化估计，不能被描述为正确hit-UV纹理求值。signed/analytic几何搜索的confidence减半，unsigned有效梯度双向近似搜索再乘0.25；置信度是保守权重而非经图像标定的错误概率。

硬件在提交候选前判断有效Cull规则，继续遍历以找到后方合法面。rawNg按源几何的逆转置方向保存，不向入射射线翻转；stock Lit的Ns同样不按观察面翻转。真正物理双面翻转Ns的模型还需要按侧分开的照明缓存，当前未实现。

真实chart捕获使用独立于Ns的原始chart几何方向校正导数facet，支持反向自定义顶点法线；导数按尺度归一化后求cross，避免绝对面积阈值把很小的有效chart裁空。六面fallback使用明确的DX12默认raster绕序与物体反射符号合同，任意外部未恢复invert-culling状态不在当前范围内。实际光栅化和镜像实例仍需Unity验证。

屏幕历史Ng朝相机，采样轴沿材质Ns，两者在背面可能相反。gather与世界缓存的起点偏移单独朝采样半球，阴影起点朝光方向；偏移不改变材质匹配Ng或历史Ng。独立平面反例中的1000条背面半球射线，旧偏移全部自交，修正偏移没有正距离自身平面命中；这不是实际GPU图像证明。

## Player 接收面来源与对象运动历史：统一离线已通过，待实机验收

Feature 现在连接 `Discovery → Registry → ReceiverHistory → ReceiverIdentityFrame → ReceiverIdentityPass → CSTemporalIdentity`。已有几何历史仍按实际全分辨率采样中心逆投影，完成票据绑定 full/GI 尺寸、viewport、投影、目标纹理与相机引用。仅同一相机、同一坐标合同、成功记录的 f-1 输出可进入对象重投影。功能默认 `receiverObjectHistory=false`；开启后自动运行 CPU 来源跟踪，即使 `receiverSourceTracking` 单独选项为 false。当前支持门控限定为 DX12、非 XR、single-sample、完整归一化 viewport，以及所需整数纹理/UAV能力；这些接线尚不等于 Unity Player 支持已经验收。

### 固定版本 API 核查

本次读取的引擎源码固定为 UnityCsReference `1c2d7db69c060103b6dc087af725442d1efaef9c`，URP/Core 固定为 Graphics `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53`。结论仅针对该 Unity 6000.0 / URP 17 基线，不外推到所有 Unity 版本。

| 候选路径 | 实际证据与采用结论 |
| --- | --- |
| Renderer 自定义 per-draw ID | 固定 [GraphicsRenderers.bindings.cs](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/Graphics/GraphicsRenderers.bindings.cs) 没有 `rendererUserValue` / `SetRendererUserValue`，固定 [UnityInput.hlsl](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl) 没有 `unity_RendererUserValue`。没有找到可供普通 RendererList 直接携带稳定用户 ID 的已证实公开接口；不依赖这些名称。 |
| ObjectIdRequest | 固定 [URP IsRenderRequestSupported](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Runtime/UniversalRenderPipeline.cs#L509) 只处理 StandardRequest / SingleCameraRequest；引擎 [Camera.bindings.cs](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/Camera/Camera.bindings.cs#L478) 的内建 ObjectId 提交带 `NativeConditional("UNITY_EDITOR")`。即使 [RenderPipeline.SupportsRenderRequest](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/RenderPipeline/RenderPipeline.cs#L81) 为该请求返回 true，也不能据此声称 Player 支持；本方案不使用它。 |
| 前帧对象矩阵 | 固定 [MotionVectorRenderPass](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Runtime/Passes/MotionVectorRenderPass.cs#L87) 明确设置相机 MotionVectors / Depth，并在绘制中设置 `PerObjectData.MotionVectors`。首次启用仍需等待有效历史。实例化路径必须使用 [UNITY_PREV_MATRIX_M / I_M 宏](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl#L425)，不能假设直接读取单一 uniform 等价。 |
| 显式 draw | 固定 [RenderingCommandBuffer.cs](https://github.com/Unity-Technologies/UnityCsReference/blob/1c2d7db69c060103b6dc087af725442d1efaef9c/Runtime/Export/Graphics/RenderingCommandBuffer.cs#L504) 提供 `DrawMesh(mesh, matrix, material, submesh, pass, properties)`；`DrawRenderer(renderer, material, submesh, pass)` 没有每次调用的 MPB 参数。这两者可构造专用身份捕获，但不自动继承原 Lit RendererList 的全部语义。 |

`SV_InstanceID` / `unity_InstanceID` 是绘制或批次寻址信息，不能直接充当跨帧 renderer 身份。矩阵哈希不能区分共面实例；相邻世界命中、SDF owner 或材质颜色也不能证明屏幕接收面身份。引擎前帧矩阵对应引擎帧，不替代本相机成功完成的历史票据；[ObjectMotionVectors.hlsl](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/ObjectMotionVectors.hlsl#L79) 还单独处理旧顶点位置，所以仅矩阵不覆盖蒙皮或顶点形变。

### 来源快照、像素身份与录制资源

[Discovery](../Runtime/HybridLumenGIReceiverDiscovery.cs) 每次相机准备扫描普通不透明MeshRenderer及下述受限SkinnedMeshRenderer来源，注册表不依赖 GI proxy、卡片、SDF、BVH 或 DXR 驻留。静态合批、额外顶点流、LODGroup及其他不支持来源保留未知标记。[Registry](../Runtime/HybridLumenGIReceiverRegistry.cs) 按 Renderer/source submesh 保存独立记录和不复用的 geometry/material generation；默认容量1,024条，上限16,384，整 Renderer 超预算时不部分接纳。来源未知、容量或完整指纹预算不足时撤销身份资格，当前 GI 仍可计算。

每次准备冻结矩阵、源 submesh、完整网格指纹和有效材质快照，并在 Scene/SDF 就绪发布之前完成。原材质捕获和身份捕获回调绘制前重新发现来源，核对同帧 source set、camera culling、矩阵、材质及网格指纹。新建/激活、移除、来源改变或再验证超预算会撤销来源票据；不得拿旧观察补齐。世界材质快照允许当前 RenderTexture 捕获，但这类无法证明稳定的来源不能进入 receiver 可复用记录。

[MaterialSource.Snapshot.IdentityCoverage](../Runtime/HybridLumenGIMaterialSource.cs) 从冻结的属性、纹理引用和关键词数组取得有效 BaseMap、BaseMap_ST、BaseColor alpha、Cutoff、来源 Material 的 Cull、alpha-test 与 smoothness-from-albedo-alpha 关键词及支持标记。身份绘制用独立的 draw 参数消费冻结输入。alpha-test 由关键词决定，smoothness 使用 base alpha 时，覆盖 alpha 取 BaseColor.a，否则取贴图 alpha 与 BaseColor.a 的乘积。未建模的 parallax、LOD crossfade、precomputed vertex motion 和不兼容 alpha 纹理拒绝身份。相机单采样且实际 A2C 关闭时，作者默认 `_AlphaToMask=1` 的普通裁剪仍可取得身份历史。[同输入实机对照](../LocalComparison/Review/author-cutout-history-263/result.md)

[IdentityFrame](../Runtime/HybridLumenGIReceiverIdentityFrame.cs) 保留来源记录顺序和 holes，不因不支持条目而压缩后续索引。每行80B：前64B为 currentToPrevious，offset64为 uint2 key，offset72为 flags，offset76的字段名 reserved 现在保存**当前帧 Renderer group**。group 同一 Renderer 跨 submesh 一致，只用于本帧变化域归属；它不是跨帧身份。key 为该 submesh 记录的 max(geometryGeneration, materialGeneration)，代次由注册表全局单调分配、不复用。primitive 是该 submesh draw 内的原始三角序号，因此 key 加 primitive 能区分不同 submesh；ownerIndexPlusOne 只是本帧 row 寻址。

[IdentityPass](../Runtime/HybridLumenGIReceiverIdentityPass.cs) 使用独立私有 Material、每 draw 自有 MPB、显式 object-to-world/view-projection、原 source Mesh 与指定 submesh。[Identity shader](../Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverIdentity.shader) 的 pass0/1/2 固定为 Cull Off/Front/Back，不能用 MPB_Cull 改原 raster state。raster 尺寸通过可精确表示1..16384整数的 float4 MPB 输入再转 uint2；compute 尺寸使用整数接口。原 Lit/原生漫反射 RendererList 继续负责照明捕获，身份 draw 本身不求光照。

受支持的Skinned来源改用同一私有材质的DrawRenderer，读取实际骨骼顶点流，不能拿bind-pose的DrawMesh代替。冻结的私有identity参数通过CommandBuffer排队；只读检查当前生效的per-slot或renderer MPB，若它覆盖这些私有绑定则拒绝，不修改来源属性块。覆盖参数仍来自已验证快照，额外读取仅用于私有绑定冲突检查。

RenderGraph 录制四阶段：清零候选并上传对象表、按保守矩形写未知遮罩、raster 原子声明、独立 compute resolve。候选为 full-resolution 的12B uint3(ownerIndexPlusOne, conflict, primitivePlusOne)，pixel shader 使用 u1，另有一个 RGBA8 dummy RT。resolve 在完整资源依赖之后，按 ScreenSampling 的实际 full 采样中心读取候选，输出 GI 分辨率 uint4(keyLow, keyHigh, primitivePlusOne, valid=1)；未知为全零。resolve 不要求前帧 eligible：首次有效当前帧也必须能写入下一帧要核对的身份。

### 可见覆盖、GPU 状态与歧义拒绝

身份 PS 在同一 full pixel 明确读取 camera depth 和 material capture depth，要求它们与当前 fragment depth 精确相等且全部有限，并先通过 alpha 覆盖，再执行 CAS。ZTest 或晚期 depth test 不能替代这一 UAV 副作用前的显式校验。严格相等可能保守拒绝因原绘制/精度差异产生的样本；不放宽容差来猜测相邻层身份。

CPU 的 global/keyword 检查仅用于提前拒绝，不能证明已经排队的 GPU 状态。PS 还读取 GPU 的 _AlphaToMaskAvailable，非零即 discard；三个 Cull pass 均提供 DEBUG_DISPLAY 变体，该分支只 discard，不编译候选 UAV 或原子 claim。固定 URP alpha-to-coverage 路径即使材质 _AlphaToMask 为零也可能改变 clip，DEBUG_DISPLAY 也可改覆盖，因此不能只看材质快照或 CPU Shader.GetGlobalFloat。

CAS 从零声明 owner；只有成功者写 primitive。**任何第二个有效 fragment 都使 conflict 永久置位，包括相同 owner、同一 submesh 自重叠与共面对象**；draw 顺序不能清掉冲突。resolve 只接受无冲突、owner 在当前 row 范围内、primitive 非零且 key 非零的候选。多字段写入不是一个原子事务，所以只在 raster UAV 写入和独立 resolve 的资源依赖完成后读取它们。

未参与身份捕获的对象也可能是原画面的共面赢家。Frame 对未知/不完整 Renderer 的冻结 bounds 建立保守投影矩形，按单矩形 compute dispatch 设置 sticky conflict，不能被合格 draw 覆盖。无可靠 bounds、投影 W≤1e-6、来源扫描不完整或未知矩形容量耗尽时使用全屏未知。LODGroup、透明、不满足以下资格的Skinned、自定义顶点路径、不可验证的静态合批/额外顶点流保持拒绝；source Mesh 不能代替未观察到的实际可见几何。

### 普通骨骼停稳历史

[SkinPose](../Runtime/HybridLumenGIReceiverSkinPose.cs)只支持普通骨骼输入：Renderer/sharedMesh/rootBone与有序bones引用、renderer-local骨矩阵、SkinQuality及全局skinWeights被冻结，并在捕获前重核。矩阵逐元素完全相等才视为未形变；网格bindposes和完整骨权重沿用既有来源检查。绝对Renderer运动仍受原正相似变换门槛约束，不放宽为通用形变重投影。pose变化递增几何代次，稳定后才能恢复相邻成功帧的历史。

Cloth（包括disabled）、blend shapes、无效／缺失骨与不可读网格拒绝；外部GPU写入或自定义顶点变形不在此合同内。姿态数组逻辑字节计入已有来源准备与重新验证预算，不是实际内存或CPU开销保证。一次[统一场景GPU观察](../LocalComparison/Review/skinned-stopped-history-01/result.md)确认骨变化样点历史≤1、停稳后恢复到32；限该简单双骨场景，未补齐任意动画、辐射质量、精确收敛、性能或退出清理验收。

### f-1 身份、对象重投影与双法线

[ReceiverHistory](../Runtime/HybridLumenGIReceiverHistory.cs) 只保留同相机、同 registry、成功记录 f-1 的来源快照。身份 resolve 成功记录后才产生身份票据，合成完成时与既有 history frame token 提交；重复、跳帧、过期或失败不能部分推进。该完成状态是有序命令记录成功，**不是 GPU fence 完成**。

Frame 以双精度求相对变换 A = Mprev * inverse(Mcur)，然后保存到80B row。它只对正相似相对变换设置 previousEligible：允许平移、旋转和正的统一缩放；相对非均匀缩放、剪切、反射符号变化拒绝。恒定非均匀或镜像源变换并不自动拒绝，判断的是相邻成功快照之间的相对变换。

[CSTemporalIdentity](../Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl) 与[实际数学 helper](../Runtime/Resources/HybridLumenGI/HybridLumenGIReceiverTemporal.hlsl) 核对当前 key/primitive、候选 conflict、row key、previousEligible 和旧像素的 key+primitive。expectedOldP = A * currentP；正相似范围内 normalize(A * Ns/Ng) 与相应法线方向一致。非有限位置/变换结果、退化法线、未知 Ng 或不匹配身份都保留当前估计，不能用对象矩阵假装支持蒙皮或任意仿射 Ns 重建。

先由 expectedOldP 投影得到 pose 预测位置。URP motion 在同一 full 采样中心读取，按 current-minus-previous UV 及一次 jitter 修正求候选；只有与 pose 预测在**每个轴均相差不超过1个 full pixel**时才采用 motion UV，否则保留 pose 预测。没有 motion 纹理也不以零 motion 覆盖已验证 pose。随后选择实际保存的最近 GI/full 采样中心，重建 oldP，并分别检查 expectedOldP 的位置距离、双向 Ng 平面、Ns 方向、漫反射材质和旧身份。屏幕 Ng 各自朝相机，对象历史比较采用无向平面一致性；Ns 仍按有向着色法线比较。

前帧最终 Ns 不能普遍由当前最终 Ns 乘一次逆转置精确恢复。固定 [GetVertexNormalInputs](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl#L30) 和 [LitForwardPass](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl#L71) 包含 normal/tangent 分别变换、插值、TBN、normal-map 与归一化。扩大到变化的非均匀缩放、剪切或形变，仍需原 primitive/重心、源顶点 normal/tangent/UV、前帧顶点或变换及一致的材质采样数据；目前只实施上述保守正相似范围。

### 自身 pose 豁免与其他变化域

[变化域 Region](../Runtime/HybridLumenGIChangeRegions.cs) 现在为48B，新增 float4.receiver；receiver.x 是本帧 Renderer group。Frame row 的 offset76 group 与它对应，同一 Renderer 的不同 submesh 共用 group；不能把某个 submesh 的 key 或任意有效 receiver 当成域的 owner。

[HLGIChangeAtReceiver](../Runtime/Resources/HybridLumenGI/HybridLumenGIChanges.hlsl) 只有在完整像素/历史几何检查有效，且非零当前 group 与域 group 相等时，才豁免该接收体自身纯 pose 域的 hard reject。其他遮挡物移动、未知归属、拓扑/内容/表示强变化及全局硬失效仍然拒绝。周围照明变化保持 reactive；自身运动豁免不代表反弹照明已经稳定，也不取消世界光照缓存的变化失效。

[SDF TransformChanges](../Runtime/HybridLumenGISdfAtlas.cs) 携带 old/new bounds 与冻结 Renderer 引用，Feature 将其解析为当前 frame group。旧来源消失、无法解析 owner 或只存在来源不确定的变化时不能伪造自身豁免。SDF 内容与真实表示失效仍走 GeometryChangedBounds 的硬路径。

### 预算、回退与资源寿命

[ScreenBudget](../Runtime/HybridLumenGIScreenBudget.cs) 将 identity 作为可选开销：先在包含全部身份资源的条件下选取可容纳的 GI 尺寸；到质量下限仍不足时，关闭对象历史并重新规划基础当前 GI。只有基础捕获/GI本身也放不下才跳过该相机。身份资源不足不应单独导致本来可渲染的当前 GI 消失。

| 身份增量 | 逻辑分配 |
| --- | --- |
| Full-resolution candidate + dummy RT | 12B + 4B = 16B/full pixel |
| 两张 GI-resolution identity history | 2 × 16B = 32B/GI pixel |
| 当前对象 rows | 80B × max(1,rowCount)，预算按配置容量预留 |
| 独立世界变化域 buffer | 1,088 × 48B = 52,224B，单独计入世界资源 |

以上是逻辑字节，不是 driver 实际分配或峰值显存保证。RenderGraph 拥有瞬态 buffers/dummy RT，相机状态拥有双 identity history；私有 Material/MPB 采用 recorder 的 fence/退休上限管理。无完成证明不能按年龄回收已经尝试 GPU 使用的资源，容量耗尽时拒绝身份。额外显式 draw、CPU 指纹、快照和未知矩形成本仍需目标场景测量。GPU反馈已包括身份清零/对象表上传、unknown mask、raster claim和resolve四个pass：原生ABI1仍用三个时间戳范围，ReceiverCapture从材质捕获延伸到身份resolve之后；Recorder在身份关闭/开启时分别汇总3/7个逐pass成对范围。范围外CPU准备、上传、驱动成本和计时query resolve仍不包括在内，也不是硬毫秒保证。

### 当前模块证据与剩余验收

[身份 shader 编译入口](../Tests/Validate-ReceiverIdentityShaders.ps1) 已在 Windows PowerShell 5.1 与 pwsh 编译12个选定 DXC入口，核对80B row、u1 structured UAV、uint primitive/输出及3个无 atomic 的 DEBUG_DISPLAY PS；[独立 identity 参考](../Tests/Validate-ReceiverIdentity.mjs) 已检查31,861项，包括原子操作交错、同owner冲突、深度/alpha、未知矩形和采样中心。它们不执行 Unity raster。

[ReceiverTemporal WARP 入口](../Tests/Validate-ReceiverTemporal.ps1) 直接编译实际 helper，在 D3D12 WARP 软件适配器上 dispatch、fence、readback，双 shell 均通过2,179用例/46,841断言。独立 double 源几何 oracle 覆盖2,048个变换样本和高32位 key、primitive、conflict、flags、非有限值、退化法线与列主序；最大位置误差约1.78e-5、法线分量误差约1.81e-7。范围与复现见[模块说明](../Tests/StandaloneReceiverTemporal/README.md)；该证据不包括完整 CSTemporalIdentity 图像、Unity、像素归属、RenderGraph 实际屏障或实体 GPU。

[录制测试报告](../Tests/ReceiverIdentityPassValidationReport.md) 使用实际 recorder 类及明确的 Unity/RenderGraph/Frame/fence 替身，覆盖回调、拒绝票据、资源退休和完整计时边界；它不能替代真实 API 运行。这些模块与Feature接线、Renderer group豁免和预算回退曾纳入历史integration-13的56阶段统一离线回归。以下计数属于当时来源：Frame为13场景/339,710断言，IdentityPass为17场景/439断言，ScreenBudget为11,381种独立预算计划/95,207断言；FrameTiming为7场景/1,048断言，Recorder为15场景/9,583断言，HistoryLifecycle为17场景/749,179断言，其中末场景只检查局部源码接线。当前候选的重新验证状态见 [OfflineValidation.md](OfflineValidation.md)。计时observer或诊断marker异常不撤销有效GI/屏幕历史；真实渲染异常仍清历史。未知marker命令结果使Recorder通道永久拒绝反馈，普通来源/图取消不按marker故障处理，实际identity开关变化重置反馈。依赖替身不验证Unity API语义或真实GPU录制。归档完整性以对应Delivery审计为准；Unity与生产验收仍未完成。

之后需在 Unity Player 验收真实 depth/alpha/Cull/LOD 对齐、GPU全局状态与keyword、MPB/整数UAV绑定、raster→resolve屏障、共面/重叠/未知遮罩、物体与相机同时运动、遮挡显露、多相机、失败后恢复、fence退休、图像拖影及CPU/GPU/显存成本。任一身份或历史验证失败都保留当前GI，不用猜测身份来提高历史命中率。

## 复现与实机验收

单项入口包括 Tests 中的 `Validate-MaterialSource.ps1`、`Validate-ReceiverHistory.ps1`，以及原有 `Validate-ProxyUpdates.ps1`、`Validate-HistoryLifecycle.ps1`、`Validate-SdfAtlasRepresentation.ps1`、`Validate-SurfaceGeometryNormals.mjs`、`transport-normal-reference.mjs`、`Validate-ScreenGeometryPacking.mjs`、`Validate-SurfaceHitIdentity.mjs`、`Validate-SurfaceCache.ps1` 和 `Validate-HardwareBackend.ps1`。已有实际类测试依赖明确的 Unity API 替身；新增对象身份、Frame/Pass 与预算测试入口见上文。56阶段/126 DXC/41 C#及194份来源匹配仅为历史integration-13结果；当前统一状态、报告负例与实际输入/日志范围见 [OfflineValidation.md](OfflineValidation.md)。封装后还须独立核对归档字节和报告绑定，不能把离线通过写成Unity生产验收。

朋友应测试：强法线贴图和反向顶点Ns下的颜色/发光反弹；相邻薄层、多子网格与法线边缘；Cull三模式、镜像和背面自交；相机停用后恢复及同帧重复渲染；同一Mesh的多个实例和多个相机；网格编辑并同时移动/改材质；旧SDF迁移、拒绝诊断与重新烘焙恢复。源、模拟依赖和数值测试不能替代上述Unity/Player图像与耗时检查。命中链的实机验收及完整面积光NEE仍见ProductionPlan的后续关卡。
