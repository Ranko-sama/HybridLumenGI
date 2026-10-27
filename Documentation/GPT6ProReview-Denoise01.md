# GPT-6 Pro 审查与下一步开发计划

审查日期：2026-10-28（Asia/Shanghai）。对象：`local-development-denoise-01`。用户范围：本机开发；本轮只审查与规划，不制作朋友交付包，不执行下一轮修复。

本次实际使用 ChatGPT 网页端 **GPT-6 / Pro**，通过 `Codex with ChatGPT · HybridLumenGI` 只读连接检查工作区。模型先调用工作区信息并读取 README，确认工作区及版本，再阅读源码、保存的基线/补丁、验证记录和前后图。Codex 另行核对了下述关键代码与预算位置。没有重新运行 Unity 或测试，没有修改运行时代码。

- [ChatGPT 审查对话](https://chatgpt.com/g/g-p-6ae0cd4a81b08191a236b6c97ab6a0e8-hybridlumengi/c/6ae0cddc-9d18-83e8-b288-1b3f96ffa34e)
- [GPT-6 Pro 完整回复原文](../LocalComparison/Review/denoise-01/gpt6-pro-review.txt)
- [审查来源记录](../LocalComparison/Review/denoise-01/gpt6-pro-review-provenance.json)
- [审查材料入口](ReviewBrief-Denoise01.md)

## 结论

保留当前局部空间降噪改进。门内固定 ROI 的单帧高频残差下降 67.31%、平均亮度变化 −1.21% 有已有证据支持；这些结果不能关闭时间闪烁、残影、保边、物理正确性或性能关卡。

确认两项问题：**P1 既有 HDR 时间矩存储缺陷**、**P2 本次新增调试视图语义回归**。另有两个需要定向验证的风险。当前并未证明薄壁异常由本次滤波改动造成。

## 确定发现

### F1 / P1：时间二阶矩的半精度存储范围不足（继承缺陷）

有效 HDR 输入本身可存入半精度 GI，但其亮度平方可能不可表示。例如灰度 1000 的二阶矩约为 1,000,000，大于半精度最大有限值 65504。

证据位置：

- `Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl:351` 只检查 float32 运算有限性；`:355` 和 `:470`、`:477`、`:481` 仍写入未缩放的时间二阶矩。
- `Runtime/HybridLumenGIRendererFeature.cs:328` 将两张 moments 分配为 `R16G16B16A16_SFloat`。
- `Runtime/Resources/HybridLumenGI/HybridLumenGIRadianceValidity.hlsl:49` 要求全部 moments 分量有限，存储溢出后会拒绝原本可复用的历史。
- `HybridLumenGIKernels.hlsl:497` 起的滤波路径直接使用时间矩；非有限二阶矩可能使亮度差抑制失效。
- `LocalComparison/Harness/DenoiseRegressionEditor.cs:50` 起已有亮度 1000 的邻居，但断言仅覆盖中心像素及中心空间方差，没有检查亮像素自身的时间矩。

这条时间矩写入路径存在于保存基线中，不是本次新增。审查确认的是可表示范围合同缺陷；当前材料没有证明它已在本轮真实场景中造成可见故障。

建议采用易核查的修复：两张 moments 提升为 RGBA32F，并同步预算。新增逻辑存储为 **16 字节/GI 像素**；`HybridLumenGIScreenBudget.cs:53` 的基础/identity 步幅由 96/128 更新为 112/144，同时核对 Feature 的 `lowPixelBytes` 默认值和已有预算测试。比较时必须确认实际 GI 分辨率不因预算重新规划而变化。

不建议只截断 `moments.y`，也不通过开启有偏的 radiance clamp 掩盖溢出。修复必须用真实纹理写入—读取验证，而非仅检查写入前 float32 数值。

### F2 / P2：HistoryAcceptance 调试显示已失真（新增回归）

`moments.w` 已改为空间方差，但其调试消费者仍按历史接受标记使用：

- `Runtime/HybridLumenGIRendererFeature.cs:15`：枚举值 3 仍为 `HistoryAcceptance`。
- `Runtime/Resources/HybridLumenGI/HybridLumenGIComposite.shader:111`：模式 3 仍显示 `_HLGI_Moments.www`。
- `Runtime/Resources/HybridLumenGI/HybridLumenGIKernels.hlsl:477`：现在向 w 写入空间方差。
- `Documentation/ValidationSequence.md:10`：仍指导使用 HistoryAcceptance。

已接受且均匀的历史可能显示黑色，被拒绝且有空间噪声的首帧可能显示非零。这是调试消费者合同遗漏，不等于正常 Final 输出必然错误。此前关于 w 没有其他相关消费者的判断不成立。

最小修复建议：保留枚举数值 3，明确改名为 `SpatialVariance`，使用有界显示映射并同步文档。若需要保留真正的历史接受视图，应提供明确状态；不能以 `z > 1` 推断接受，因为 `maxHistory=1`、未知当前值保留旧历史等情况不满足该推断。

## 待验证风险

| 风险 | 已确认的代码事实 | 尚不能宣称的结论 | 有限验证 |
| --- | --- | --- | --- |
| R1：跨薄层混合 | 方差采样使用硬平面条件，但 `CSFilter` 在 `HybridLumenGIKernels.hlsl:519` 使用软指数衰减；距离一倍阈值时仅平面项约为 0.368 | 不能据此认定真实薄壁亮度差就是漏光，也不能把 separate-plane 的 temporal 测试当完整滤波通过 | temporal 后接真实 filter，步长 1/2/4；近距离平行面、材质和法线边界，记录暗侧引入量 |
| R2：历史长度 3→4 跳变 | `HybridLumenGIKernels.hlsl:502` 在 z<4 使用空间补偿，到 z=4 直接取消 | 公式不连续不等于已证实可见闪烁 | 连续历史 1→5、运动停止、重置、reactive 和低 maxHistory；测到问题后才调整衰减 |

空间方差不授予历史有效性，未知中心也没有被邻居制造成有效测量。本次改动复用了既有纹理与循环，未新增 dispatch；在已检查范围内没有发现新增读写别名或资源生命周期破坏。新增计算的 GPU 成本仍未测量。

## 证据边界

- 第179帧门内 ROI 的残差 RMS 为 0.03334195 → 0.01089995，均值 Y 为 0.34841809 → 0.34418508。第119/179帧未滤波历史最大绝对差记录为 0，支持展示的差异来自空间重建。
- 第179帧整图均值约增加 1.40%；局部 ROI 的均值变化不能推导全图能量守恒。该变化本身也不足以判错。
- 原五例固定 `_HLGI_HistoryValid=0` 且只执行 `CSTemporal`，未覆盖连续有效历史、完整 identity 变体和 filter 链。
- 最终 420 帧、21 张 HDR、零采集错误的记录仍为 `incomplete-probe`，不能当作完整 720 帧验收。
- GPT 能核对脚本、汇总与 PNG，但未独立重算工作区外的完整 HDR、420 份 receipt 或全部 109 个产品文件。本轮 Codex 仅补做关键源码与哈希核对。
- 当前源码的 Player/DXR、可信 GI GPU 时间、峰值显存尚未验证；335.44 秒首次出帧包含初始化成本，不能当 GI 帧时间。

## 下一工作包：denoise-02-contracts

此计划尚未执行。目标限于关闭 F1/F2，揭示 R1/R2，并取得足够的局部动态证据。

1. **补齐现有证据。** 将诊断基线与最终运行所需的配置、receipt、119/179 帧 HDR、history/moments、日志和来源清单复制到评审子目录。按需要附关键像素/ROI 的可读数值导出。先确认来源、内部帧号、identity 状态、实际 GI 尺寸及回退范围；不重跑已有足够证据的项目。
2. **修两个明确合同。** 修改 moments 格式及预算；修调试模式名称/显示/文档。涉及 Feature、ScreenBudget、Composite、`Tests/StandaloneScreenBudget/Program.cs.txt`、ValidationSequence 和本轮记录。保存新 before/patch，保留 candidate-16 历史证据。
3. **扩展现有 GPU 入口。** 保留五例，增加 HDR 往返、有效性/失败路径、历史长度边界、真实 filter 链四组定向用例。HDR 用 255/256/1000/接近半精度辐射上界的恒定输入，至少四帧 ping-pong，检查全纹理全分量和历史增长。实际运行两个 temporal kernel；identity 用例必须绑定真实身份资源，不能以编译代替执行。运行已有屏幕预算验证入口。
4. **最多一组有界前后配对。** 每侧最多 420 帧；仅为缺失的动态证据增加门开始/停止/返回运动与薄壁切镜的连续采集窗口。保持光照、曝光、射线数、缓存设置和实际分辨率一致，同时记录 raw、未滤波历史、moments 和最终图像。无法可靠运动对齐或没有参考时，明确保留未验收状态。

成功标准：

- HDR 存储往返的必要分量有限；有效历史按预期增长；恒定场输出不靠截断亮度保持。
- 调试枚举、显示、文档与记录一致。
- 原用例和新增有效性用例通过；预算无漏计，无静默降分辨率或新增读写混用。
- 合成输入按事先约定的格式/数值容差判定；动态证据和限制完整归档。通过后只关闭对应局部合同，不关闭 G1/G2/G3 总关卡。

停止条件：发现首个非有限内部值、错误历史复用、未知中心被填为有效、来源/设置不匹配、无法解释的后端回退或采集失败时，停止质量调参并保存最小复现。若需要重写编码、重投影或传输方程，另拆工作包。不得为保留“67%”指标改变光强、曝光或 radiance clamp。

## 后续优先级

| 顺序 | 工作 | 完成判据与范围 |
| --- | --- | --- |
| 1 | 薄壁正确性、动态参考 | 分层检查 raw gather、时间历史、空间滤波、合成；再隔离直接光、单次反弹和缓存反馈。用参考和分层证据定位，不能按旧版较暗定错 |
| 1（可独立推进） | 退出资源警告 | 取得分配来源日志，有限复现退出 Play、禁用 Feature、销毁相机；检查 CameraState 与资源退休队列。不能提前释放仍被 GPU 使用的资源来消除警告 |
| 2 | 冷启动、可信性能与显存 | 明确缓存状态的冷/热各一次；区分编译、驱动初始化和首个有效 GI。无图像写盘干扰的有限运行测 GI GPU 时间与峰值显存 |
| 3 | 扩展当前版本支持组合 | 核心合同稳定后再验证 Player/DXR、identity 开关、奇数尺寸/分辨率变化、选定材质/形变；旧版结果保持历史属性 |

以上为 GPT-6 Pro 结论经本地交叉核对后的执行摘要；详细推理、文件位置和限制保留在原文中。后续开发不再以朋友反馈作为停点。
