# 固定场景与线性 HDR 采集序列

Release112 已用原生 Unity 相机完整走通规定的门、灯与切镜路线，后端全程报告 DXR。运行采用 640×360 普通 Final、半分辨率 GI、2 条射线和 4 级滤波。[实拍、关键读数与范围](../LocalComparison/Review/full-dxr-sequence-112/result.md)

这组工具把验证动作、采集帧与文件格式固定下来，供已有 Unity 6 / URP 17 工程或 Player 重复运行。项目已有有限原生验证，具体来源和边界见 [开发进度](DevelopmentProgress.md)；不能把其它场景的成功当作本序列或独立物理参考通过。它不取代 [完整验证矩阵](Validation.md)。

## 准备一次独立运行

1. 使用 **Tools > Hybrid Lumen GI > Create Validation Scene Assets**。生成器在 `Assets/HybridLumenGIValidation/Run*` 保存独立场景与材质，不替换当前场景。之后单独打开生成的 `Validation.unity`，不要与其它游戏场景一起运行。
2. 给该相机实际使用的 URP Renderer 添加 `HybridLumenGIRendererFeature`。生成器从该相机实际选择的 Renderer Data 中解析唯一启用、持久保存的 GI Feature 并预填 **Validation Sequence**，无关已加载资产不参与选择；无可用或唯一结果时留空并提示，仍生成几何。此时配置 Renderer 后手动指定该 Feature 资产。保持一个非 XR Base 相机、无相机堆栈，使用 Linear / Direct3D 12。组件不会修改 Feature 私有设置，也不反射读取它们。
3. 生成器现在按唯一源 Mesh 自动烘焙并复用 32³ SDF 和 Surface Charts，全部成功后才绑定 Proxy 并保存场景。取消或失败只清理本次新 Run，恢复原活动场景。更改网格内容后需要重烘焙；薄壁的分辨率、缩放与偏移仍需要实测，资产存在本身不是查询精度通过。
4. 在 Feature Inspector 选择真实输出模式，如 `IndirectOnly`、`Final`、`Confidence` 或 `SpatialVariance`，并固定光照、缓存、采样和降噪设置。`SpatialVariance` 保留枚举值 3，显示空间亮度方差 `v/(1+v)` 的灰度（零方差为黑、方差 1 为 0.5），不表示历史接受率；旧 `HistoryAcceptance` 名称已纠正。`Expected Backend` 选择 Software、Hardware 或 FeatureDisabled；软件 / 硬件请求还应分别设置 `preferHardwareTracing`。禁用对照需要在 Renderer 资产中关闭 Feature；组件仍需持有该资产以记录配置。`Run Label` 只是人工标签，不能代替实际模式 / 后端证据。
5. 检查烘焙 GI、Light Probe、Reflection Probe、其它 Renderer Feature、Volume、动态曝光等额外贡献。生成场景设置 ambient 为黑、intensity / reflection intensity 为 0、无 skybox / fog，盒体关闭探针使用，灯为 Realtime。Feature 自己的 `environmentRadiance` 等仍由 Inspector 决定，保存在快照；要做零环境漏光实验应显式设为 0。采集临时禁用该相机后处理、MSAA 与动态分辨率。
6. 每种对照都从**新 Player 进程或重新进入 Play**开始。不要在一次运行中切换 Feature 设置。若关闭 Editor Domain Reload，需手动确认 Feature 实例和缓存确实重建；否则使用新 Player。组件不重置 GI 内部 frame / RNG / 缓存，不承诺逐样本确定性重放。Player 需包含生成场景和所需 shaders / 资产；设置在构建前配置好。

默认 `640×360`、每 30 帧保存一次，以及每个事件的前后边界；`Capture Every` 可设为 1 以取得黑室 300 帧的完整像素序列。运行输出目录在 Console 中给出，默认位于 `Application.persistentDataPath/HybridLumenGIValidation/<UTC>-<UUID>/`。每次使用新目录，不覆盖旧证据。`Output Root` 可设为可写绝对路径。

## 固定逻辑帧

| 逻辑帧（包含两端） | 动作 |
| --- | --- |
| 0–119 | 红 / 绿墙、白 / 金属 / 黑接收体与发光面，固定相机 |
| 120–179 | 门按逻辑帧匀速横移至打开位置 |
| 180–209 | 门保持打开 |
| 210–239 | 门返回原位 |
| 240–299 | 五个选定直接灯关闭；原场景发光材质仍保留 |
| 300–359 | 直接灯恢复初始 enabled 状态 |
| 360–419 | 切到 3 cm 薄壁测试区，灯位于墙另一侧 |
| 420–719 | 切入完全封闭的普通灰白反射房间，内部无灯和发光面，外部仍有照明 |

黑室六面相互覆盖封闭，内部接收体也使用普通反射材质。黑室不是用全黑材质制造黑输出；彩墙区的黑 / 金属块另用于零漫反射检查。薄壁边缘可能存在真实间接入射，因此没有参考图时不把“全部像素必须为零”设为通用判据。

`ValidationMotion` 不使用 `Time.time` 或 `deltaTime`。每个逻辑帧只在目标 Camera 实例产生一次 `endCameraRendering` 后推进；重复 render、跳引擎帧、下一引擎帧仍缺 receipt 都终止为失败。Editor 暂停且 `Time.frameCount` 不推进时不触发缺帧失败。不要另加控制这些门、灯或相机的脚本。

每帧记录 `logicalFrame`、引擎 `Time.frameCount` 和独立的 GI `frame` counter。GI 诊断只能按相机名字匹配，因此多条同名结果、缺结果或 counter 不连续都会拒绝；名字不等同稳定对象身份。`run.json` 保存采集前、首帧 GI counter 与首个引擎帧，比较结果保留起始偏移。即使偏移为零，也不能推断 GPU 随机样本完全一致。

## 文件与完成语义

- `feature.json`：`JsonUtility.ToJson(feature)` 的序列化字段快照，包含该 Feature 的设置，不是所有引擎 / 项目配置或私有运行时状态的快照。运行中这份序列化内容或目标 RT 改变会失败。
- `run.json`：输出模式标签、请求后端、Unity / URP assembly / API / GPU 信息、Linear target 格式、环境 / lightmap 数、初始灯参数与 mask、首帧 counter、错误和完成状态。URP assembly 版本不一定等同 package.json 版本，交付日志仍应附确切 Unity / URP 包版本。
- `frames.jsonl`：每个相机 render receipt、相机位置 / 旋转 / 投影、门位置、灯阶段与该相机诊断。`reported-hardware` / `reported-software` 来自 `CameraDiagnostics.hardwareBackend`，**不是硬件执行证明**。`hardwareMaterialGlobalAllocatedBytes` 是全局字段，不可跨相机重复求和。
- `frame-NNNN.json`：选择采集帧的完成或失败信息、对应 receipt、均值亮度 / 最大 RGB、非有限计数及文件名。
- `frame-NNNN.rgba32f`：无文件头，little-endian，逐像素 RGBA 四个 IEEE754 float32，恰好 `width × height × 16` 字节；保持 GPU 回读行顺序，不 CPU 翻转。RGB 是 Linear HDR，alpha 不是质量评分。
- `frame-NNNN.exr`：同一回读的 RGBA float EXR，不做曝光或显示映射。比较脚本只比较 raw，EXR 仅检查 magic header，不实现完整 EXR 解码。
- `unity-log.jsonl`：运行期间 Unity log / warning / error；Error / Exception / Assert 会保留失败状态。

最多两项 GPU 回读在途。超出上限会标记该采集失败，**不暂停逻辑序列等磁盘**；磁盘、EXR 编码、非有限像素或回读错误都会使运行失败。此方案是视觉验证采集，主线程复制 / EXR 编码 / 写文件会影响时间，不能拿它测 GPU 帧预算。

正常结束或禁用组件时等待自己已发出的回读，再恢复相机 / 灯 / 门并释放 RT。失败的等待若仍不能证明回读结束，会保留 RT，直到其回调确认完成；不会提前释放 GPU 可能使用的存储。恢复对象已销毁或恢复属性抛错时，自有 writer / log 订阅清理仍会执行；进程被强制终止则可能只有 `running` manifest 和部分文件，这不是成功结果。

使用 Unity 官方 [AsyncGPUReadback.Request](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.AsyncGPUReadback.Request.html)、[WaitForCompletion](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.AsyncGPUReadbackRequest.WaitForCompletion.html)、[endCameraRendering](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/Rendering.RenderPipelineManager-endCameraRendering.html) 和 [EncodeArrayToEXR](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/ImageConversion.EncodeArrayToEXR.html)。固定 [URP 17 源码](https://github.com/Unity-Technologies/Graphics/blob/feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53/Packages/com.unity.render-pipelines.universal/Runtime/UniversalRenderPipeline.cs) 的相机 scope 在 `RenderSingleCamera` 的 `context.Submit()` 后发送 end 回调。**这个事件加成功回读只证明采集顺序，不证明全部 GI Feature pass 成功、真实 DXR dispatch 或图像正确**；这些仍需 Unity 日志 / Frame Debugger / 原生 GPU capture。

`completed` 只表示这套采集合同完成；后端不符合请求时是 `completed-with-backend-mismatch`，保留文件供排查，默认比较拒绝。图像质量仍为 `reference-required`，不会自动设合格。

## 对比和待建立参考

### 同场景来源与合成边界导出（v2）

在 Validation Sequence 启用默认关闭的 `Export Reference Package`，并使用 active Feature / Final 输出。它保留上述原序列和旧采集文件，另保存 `candidate.json`、物理 `source.json`、每个选择帧的源状态，以及同一次渲染中 HLGI 合成前、合成后的相机 HDR 和滤波后间接入射量。合成前输出还可能包含 URP 的镜面、发光、环境等贡献，不等同于“纯直接光”；合成前后差值只是诊断数据。

`source-provenance.json` 单独保留原 scene、renderer、产品/工具和烘焙近似资产来源，避免产品实现变化混入物理源哈希。动态源状态在渲染前冻结，再绑定实际渲染相机矩阵；无法完整表示的源明确标记 unsupported。`Reference Source Package` 指定已导出的来源目录，Editor 和 Player 都优先校验、复制该目录；Player 必须提供。Editor 自动化先在进入 Play 前完成导出，避免在被测管线运行中加载和遍历资产。该输入目录不证明正在运行的 Player 代码版本，构建来源仍须单独保存。

生成器为每个新 Run 保存独立的 LightingSettings，关闭 Unity baked/realtime GI 并显式清除该新场景的 LightingDataAsset；普通实时灯与 HLGI 继续工作。导出器仍逐个检查所有已加载场景的烘焙数据，不会把未解码的非空资产当作已知零贡献。

`Explicit Render Requests` 供自动化调用者在 URP 就绪后使用：每个逻辑帧提交一次 StandardRequest，关闭相机自动渲染。请求中的失败恢复延后到请求返回；调用者应等待 `ReferenceCaptureDrained`，不能只看到旧 `run.json` 完成就退出。v2 的读回有独立在途数量和存储上限，超限或缺失保持 incomplete，不暂停原逻辑序列来隐藏缺帧。

本机测试宿主还等待同一个 URP 管线跨两个完整 Update 稳定后再开始序列，不预热 GI。Editor 初入 Play 时可能替换刚由显式请求初始化的管线；正式序列中若发生替换或跳帧，原连续性检查仍拒绝结果。

独立参考协议见 [validation-reference-schema.md](../Tests/validation-reference-schema.md)。数据完整、来源一致与物理质量是不同条件；没有独立参考、覆盖不足或没有显式误差阈值时，比较器不会通过：

```powershell
node Tests/compare-validation-reference.mjs --candidate 'C:/captures/run/candidate.json'
```

### 原始采集间比较（v1）

需要 Node.js 18 或更新版本。输入必须是这套序列的完整输出目录。两组运行需一致的分辨率、动作、模式、关键环境和 GI 设置；比较器核验全部 720 receipts、采集清单、诊断推进、raw 长度与有限性。尚未提供离线路径追踪器的参考导出器，也未随源码提供可信参考图。

```powershell
# 没有参考：输出像素统计和 reference-required（退出码 2），不会通过。
node Tests/compare-validation-captures.mjs --candidate 'C:/captures/current'

# 有参考但没有阈值：只输出每帧 RGB RMSE / maxError（退出码 2）。
node Tests/compare-validation-captures.mjs --candidate 'C:/captures/current' --reference 'C:/captures/reference'

# 用户按目标硬件 / 可信参考确定阈值后再输入；此处没有默认阈值。
node Tests/compare-validation-captures.mjs --candidate 'C:/captures/current' --reference 'C:/captures/reference' --rmse $ChosenRmse --max-error $ChosenMaxError

# 比较器本身的合成输入与算术自检，不运行 Unity。
node Tests/compare-validation-captures.mjs --self-test
```

软件 / 硬件对照显式加 `--allow-backend-difference`：仅豁免请求后端与设置中 `preferHardwareTracing` 的差异，不豁免其它 GI 模式和材质 / 光照合同。启用 / 禁用 Feature 的最终画面对照还需 `--allow-feature-state-difference`；它是差异分析，不自动成为物理正确参考。不同后端回退导致的错误标签不能用这两个参数绕过。

阈值作用于每张图的线性 RGB RMSE 和最大绝对通道误差，alpha 仅检查有限性。所有图片都满足用户给定阈值才输出 `within-user-thresholds` / 退出 0；超阈值、坏输入或不完整采集退出 1。这不等于能量守恒、无漏光、时域稳定或生产验收。参考图必须另行建立并审查光照单位、BRDF、环境与收敛程度；当前没有参考的结论保持“待建立”。

回传时附完整采集目录、准确 Unity / URP 包版本、用于运行的场景与烘焙资产、原始日志，以及对应源码包的 SOURCE-MANIFEST.json。保留原始文件；不要只发送经过曝光处理的截图或口头通过结论。

