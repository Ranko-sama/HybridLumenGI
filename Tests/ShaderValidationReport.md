> 历史专项快照：下文次数与哈希仅属于记录时的来源。当前交付的通过结果以 [统一离线报告](offline-validation-results.json) 和 [证据入口](../Documentation/OfflineValidation.md) 为准；不能把本文旧哈希继承给新源码。

# Shader 离线验证记录

更新：2026-10-27。**integration-14 统一离线回归已通过**：70 阶段、275 份来源一致、49 份 C# 语法输入无错误，共 147 项选定 DXC。基础矩阵为核心 46、Native Diffuse 42、Global SDF 3、Receiver Policy 22、Receiver Identity 12、Receiver Temporal helper 1；另有九个材质/查询专项的 21 项入口，全部属于同次运行。当前主报告 SHA256 为 `BC0AE87C79357568FE53F1CF73E4F787B4BF3DD40C260BC3FF5263164D361FF7`，报告、工件范围及首轮失败修复见 [OfflineValidation.md](../Documentation/OfflineValidation.md)。以下 13 的历史矩阵保留为旧版本说明，不把其旧报告链接指向当前 JSON。Unity/Player、真实 DXR 和实体 GPU 未验收；编译不等于 URP 绑定、GI 图像或性能验收。

## 历史 integration-13 编译环境与通过矩阵

下表列出integration-13当时重新编译并绑定封存来源的126项选择范围，不代表后续工作区或当前运行。CSTemporalIdentity在软件与硬件两个核心入口中编译，另一个独立Temporal入口执行实际数学helper，二者验证范围不同。

| 项目 | 结果 |
| --- | --- |
| 编译器 | Windows SDK 10.0.26100.0 的 x64 DXC；dxcompiler.dll 1.8.2502.11 (239921522) |
| Unity shader includes | 官方 Unity-Technologies/Graphics，6000.0/staging 的固定提交 `feb4de2d9a93a4ae10d287d3a6d7003d08ea3e53`；缓存 include 的哈希保存在核心报告 JSON |
| 软件追踪 | `CSUpdateCache / CSTrace / CSTemporal / CSTemporalIdentity / CSFilter`，`cs_6_0`，5/5通过 |
| 硬件追踪 | 同样五个kernel，`cs_6_5`，5/5通过 |
| Composite | 提取实际 HLSLINCLUDE，`Vert` / `Frag`，`vs_6_0` / `ps_6_0`，2/2 通过 |
| Surface capture | 提取实际 HLSLPROGRAM；`_METALLICSPECGLOSSMAP`、`_EMISSION`、`_OCCLUSIONMAP` 的八种组合，每种编译 vertex / fragment，16/16 通过 |
| World cards | 实际capture vertex、8种fragment组合、clear vertex/fragment、可变owner/card查询和覆盖anchor/发光归约compute，共13项；独立SurfaceCards脚本检查同一组入口，不重复计入126项 |
| Emissive proposals | `CSBuildEmissiveProposals`，`cs_6_0`，1项；方向PDF/采样函数同时由软件/硬件transport入口覆盖 |
| Color contract probe | 读取真实URP LitInput的vertex及Base/Specular/Emission fragment，4/4通过；不是GPU颜色回读 |
| Native Diffuse capture | 21组选择的材质/SH/lightmap/SSAO/雾及拒绝路径，每组vertex+fragment，共42项；非穷举全部变体 |
| Global SDF | `CSMergeBricks / CSPublishBricks / CSQuery`，`cs_6_0`，3项；包含独立query harness |
| Receiver Policy | 普通capture的8种fragment组合各覆盖非实例/实例路径，另4个vertex和原生capture的2个实例fragment，共22项；签名检查确认18个PS整数MRT与10个实例PS rendering-layer数组，PS5/pwsh单项均通过 |
| Receiver Identity | Cull Off/Front/Back各编译vertex、普通fragment和DEBUG_DISPLAY fragment，另编译clear/unknown-mask/resolve三个compute，共12项；检查80B row、u1 UAV和primitive/uint输出，三个debug PS不得包含atomic claim |
| 实际Temporal helper | 独立compute包装实际ReceiverTemporal.hlsl，1项DXC；同一DXIL在D3D12 WARP软件适配器执行，2,179用例/46,841断言，与独立double源几何oracle比较 |

该历史矩阵包含 mesh SDF、global clipmaps、实例BVH、真实三角形inline ray query、世界材质卡片和patch缓存、完整混合PDF引导、局部变化域、深度一致性、历史重投影、滤波与有符号原生漫反射替换。Unity 专用 pragma 由原生 DXC 忽略；直接指定 DXIL profile 和阶段宏，Native Diffuse使用HLSL 2018语义。所有编译产物与外部 include 均保存在系统临时目录，没有放入运行时包。

integration-13当时附有核心、Native Diffuse、Global SDF、Receiver Policy、Receiver Identity、Receiver Temporal与Native GPU Timing共7份伴随报告；56阶段、194份来源和编译记录的核验只针对该封存版本。对应历史原件须从integration-13归档取用，不能把之后推广的工作区副本认作旧报告。当前候选报告入口为 [OfflineValidation.md](../Documentation/OfflineValidation.md)。矩阵编译与模块WARP结果不等于另行完成了所有DXIL文件的独立归档审计。

历史补充证据：采样中心修复先行专项曾编译软件/硬件的CSTrace、CSTemporal、CSFilter共6个入口，记录为`$env:TEMP/hlgi-screen-sampling-dxc-bf0eb795466c460dbacd1624b0152fbf/report.json`。它绑定当时Kernels SHA256 `3C769E93E8C24551DF9FDDB77CA25C690FF572AC94941811BBB6856BF5DCBEA7`，未编译Composite，也不验证其后的对象历史改动。当前来源与结果以 [OfflineValidation.md](../Documentation/OfflineValidation.md) 所列证据为准；历史重复入口不增加integration-13的126项总数。

既有整数映射固定每个GI texel实际拥有的fullres深度点；motion从同一中心起算，前帧取最近实际历史中心，oldP、时域邻域和滤波共享坐标函数，Composite按真实中心距离插值。其1,213,438项独立数值/接线检查不是HLSL执行。CPU来源跟踪本身不分配像素身份；另一个默认关闭的receiverObjectHistory选项自动启用跟踪，并连接Frame、四个身份pass与CSTemporalIdentity。像素key+primitive、无冲突候选、f-1 receipt及正相似相对变换均有效才复用；未知Ng或其他失败保留当前GI。对象历史分配16B/full、32B/GI及80B/row，FrameContext失配仍先拒绝历史。

接收者捕获新增R32G32_UInt附件，普通capture为SV_Target2、原生漫反射capture为SV_Target3。x通过每GameObject层的独立RendererList取得单bit身份；y由URP `GetMeshRenderingLayer()`按位读取完整mask，包含bit31和合法零mask。两通道不经数值float转换。原有diffuse、emission、material AO与native fog输出保持原合同。Native拒绝变体返回的材质有效位与policy均为零。

独立Receiver Policy脚本读取实际shader/include，并记录3个来源文件、68个当前缓存include、完整命令、DXIL/listing哈希和签名结果。实例适配显式设置`SHADER_TARGET=45`、`INSTANCING_ON=1`和`UNITY_INSTANCED_RENDERING_LAYER=1`；`-flegacy-macro-expansion`用于固定UnityInstancing中先展开再拼接token的宏语义，未修改官方include。每个实例fragment还必须实际出现`unity_RenderingLayerArray`，避免把未激活实例分支的编译误记为通过。此处没有验证Unity真实builtin上传或材质批处理，也未穷举全部keyword组合。

报告校验器检查阶段、字段、来源和产物记录；实际产物的独立核对须另列证据。各候选的报告负例和实际输入/产物审计状态见 [OfflineValidation.md](../Documentation/OfflineValidation.md)，不把integration-13或更旧审计标为当前新结果。有限负例不是任意伪造报告的完整防篡改证明。

## 必须保留的限制

- 本机没有Unity，也没有安装。未执行Unity shader importer、Editor/Player build、RenderGraph实际录制验证、C#对Unity API的语义编译或实体GPU渲染。Temporal helper已在D3D12 WARP软件适配器dispatch/readback；它不执行完整CSTemporalIdentity图像或身份raster，更不能证明真实Unity资源屏障。
- 常规离线矩阵将 [ShaderAdapters/UnityRayQuery.cginc.txt](ShaderAdapters/UnityRayQuery.cginc.txt) 复制到临时目录 `Adapters/UnityRayQuery.cginc`，把名称映射到 DX12 的原生 `RayQuery`。另已直接核查并使用官方 Unity 6.0.65f1 发布包中的真实 header 编译硬件命中 helper，见下节；该默认 header 使用相同别名。这确认默认 DX12 header 的 API 表面，仍未验证 Unity importer、平台覆盖宏、引擎绑定或运行。包内 adapter 保留 `.txt` 后缀，避免 Unity shader include 误用；不能把它放进 Runtime 或代替 Unity 引擎文件。
- profile `cs_6_0 / cs_6_5` 成功不能推导出 Shader Model 5、DX11、Vulkan、Metal 或 Unity 内所有 keyword/instancing/XR 变体兼容。
- 额外进行了 FXC `cs_5_0` 兼容性探测：对 Unity include 进行预处理后，实际报告 `X3531: can't unroll loops marked with loop attribute`，位置在 `TraceScene` 的动态代理循环。关闭 FXC 优化也仍失败。因此 compute 已显式添加 `#pragma use_dxc`，当前验收目标限定 DX12；没有将 FXC 或 DX11 标记为通过。
- 真实三角形后端仍需在支持 inline ray tracing 的显卡上验证 RTAS 构建、submesh/primitive 索引、法线插值、更新时序和退化路径。材质捕获的 override shader 行为也需要实际 URP 场景核对。
- 既有light-layer/culling-mask与ShadowCastingMode候选过滤虽被实际HLSL入口编译覆盖，仍需验证不同RendererList、实例化材质、零mask和bit31的设备结果。新增整数附件每全分辨率像素占8B；编译不证明MRT绑定、写入、资源屏障、带宽或性能达标。receiveShadows、软阴影、cookies与完整mixed-lighting语义不由这两个mask字段实现。
- GPU预算反馈已纳入身份清零/上传、unknown mask、raster claim、resolve四个pass：原生ABI1仍是三个范围，ReceiverCapture延伸至身份resolve；Recorder按实际identity开关使用3/7个局部成对范围。计时API和七个诊断scope的失败不会中断GI；这些C#接线的录制替身测试不增加DXC入口计数，也不能证明Unity实际marker/query行为。范围外CPU准备、上传、query resolve、驱动成本以及峰值显存仍须独立实测。

## 硬件命中身份与官方 header 的独立补充证据

历史integration-13的硬件实例布局为 **128B**，三角属性为 **80B**，逐三角 chart 绑定为 **16B**；当时实际 C# 类的 **4418/4418** 录制式测试由该历史统一报告绑定。其后新增属性与材质链的来源绑定专项见 [HardwareBackendValidationReport.md](HardwareBackendValidationReport.md)，不能将旧计数作为当前源码结果。source-only Cull 与精确快照另有 SurfaceCache/MaterialSource 专项；不是GPU候选执行或实际光栅一致性验证。CPU断言不计入历史126项DXC矩阵。

实际硬件查询使用 `FORCE_NON_OPAQUE` 让每个三角候选先经过对应 submesh 的 Cull 判断，再调用 `CommitNonOpaqueTriangleHit`，持续遍历最近合法命中。命中保留原始 Ng、源 Ns、owner/submesh/primitive、重心坐标/UV 与版本化 chart 绑定；缺少精确绑定时不会以别的卡片冒充它。源 Ns 未被统一翻转为物理双面材质，逐侧 irradiance 缓存不在本次实现范围。候选提交的语义依据是 [Microsoft DXR RayQuery 规范](https://microsoft.github.io/DirectX-Specs/d3d/Raytracing.html#rayquery-commitnonopaquetrianglehit)。

从 [Unity 6000.0.65f1 官方发布页](https://unity.com/releases/editor/whats-new/6000.0.65f1)的 Shaders 链接下载 `a18e2220bd50/builtin_shaders-6000.0.65f1.zip`，读取内部 `build/BuiltinShaders/builtin_shaders.zip` 的 `CGIncludes/UnityRayQuery.cginc`。该 header SHA256 为 `95F9B7E5F5361CD6577F09EE36E2702F1C35635BCA493746B42E29DA939843E6`；未定义平台替换宏时，它直接把 `UnityRayQuery` 映射为原生 `RayQuery`。

历史补充证据（2026-10-27，integration-08）：独立临时harness调用当时的 `HLGIHardwareTraceHit` 与 `HLGIHardwareFallbackMaterial`，使用上述官方header、固定Graphics includes和 `cs_6_5` 编译成功，退出码0、无诊断。它对应当时HardwareTrace源SHA256 `CCF4C1EEBBA4C4EEA4142547CF7812C3955F8F8F3731321BD6A6EB121B22398F`，**不作为其后新增shadow-policy源码的编译证据**。记录位于本机 `$env:TEMP/HybridLumenGI-shader-validation/HardwareHit.validation.hlsl` 与 `HardwareHit.official-header.validation.dxil`，header位于`OfficialUnityRayQuery-6000.0.65f1/`；这些临时文件不随包分发，且没有另存独立JSON日志。当前候选的独立结论须从 [OfflineValidation.md](../Documentation/OfflineValidation.md) 所列当前证据确认。历史额外检查不增加常规矩阵计数，也不证明实际RTAS、Unity导入或设备执行。

## 复现

在包根目录使用 PowerShell：

```powershell
./Tests/ValidateShaders.ps1 -DownloadIncludes
./Tests/Validate-NativeDiffuseCapture.ps1 -DownloadIncludes
./Tests/Validate-GlobalSdf.ps1
./Tests/Validate-ReceiverPolicyShaders.ps1 -ReportPath Tests/receiver-policy-shader-validation-results.json
./Tests/Validate-ReceiverIdentityShaders.ps1 -ReportPath Tests/receiver-identity-shader-validation-results.json
./Tests/Validate-ReceiverTemporal.ps1 -ReportPath Tests/receiver-temporal-validation-results.json
```

脚本寻找现有 Windows SDK 的 x64 `dxc.exe`，也可用 `-CompilerPath` 指定。`-DownloadIncludes` 会下载固定提交的官方 shader include 到临时目录；已下载后去掉此开关即可离线运行。使用 `-IncludeRoot` 可指定已有 include 目录。脚本输出每项退出码、源文件和 include 哈希以及完整诊断 JSON。通过不应替代朋友机器上的 Unity 导入和画面验收。
