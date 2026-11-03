# 普通 Lit 裁剪输入的同帧覆盖

**本机普通 Additive、运行时 `_AlphaToMask=0` 的这个二值 cutout 输入，原生深度与 GI 重绘深度逐点一致，裁空处正确露出背板。** 关闭的是该限定配置的屏幕覆盖合同，不是通用 cutout 或整体 G1／T2 放行。

| 预先定义的前景几何内部域 | 实际结果 |
| --- | --- |
| 几何投影内缩 2 个全分辨率像素，内部 alpha 边界保留 | 6,724 个有效像素，无未知点 |
| 原生前景／后方背板 | 各 3,362 个像素，确有两种深度 |
| 原生深度／GI 捕获深度最大绝对差 | 0 |
| 按原 10⁻⁶ 容差判定的差异像素 | 0 |
| 近处捕获材质平均 RGB | (0.914883, 0.042967, 0.003922) |
| 洞口捕获材质平均 RGB | (0, 0, 0.960784)，蓝色背板 |

观察使用现有 `HybridLumenGIValidationCapture` 的 `depth`、`captureDepth` 和 `material`，不新增 GPU 探针或产品插桩。原生深度来自普通 URP 相机，捕获深度来自 GI 独立的 `DrawingSettings.overrideShader` 重绘，两者为同一源帧。域由源 Quad 的投影确定，不按候选结果选点。近／远深度分别约为 0.707071／0.656566，与实际相机矩阵及两个平面的位置相符。

## 输入与范围

Unity 6000.0.85f1／URP 17.0.4、Windows D3D12／Linear。固定 128×128 正交相机、半分辨率 GI；普通 Additive，关闭 MSAA、抖动、后处理和雾。发行质量参数来自 Release122，此分辨率不用于性能或整景质量验收。两帧预热后只在逻辑／GI 工作帧 2 捕获一次。

前景借用旧 `RuntimeAudit/Cutout.mat` 与 32×32 BaseMap，保留 `_ALPHATEST_ON`、cutoff 0.5、Cull Back、UV／纹理过滤和颜色。mip0 有 512 个 alpha=0 与 512 个 alpha=255 纹素。为了限定现有单采样合同，运行时副本只将 `_AlphaToMask` 设为 0；作者资产不改写。前景在 z=0，蓝色不透明背板在 z=0.5，相机在 (0,0,−3)。

本结果不覆盖 URP 作者材质自动保留的 `_AlphaToMask=1`、A2C／MSAA、smoothness-alpha 组合、Replace Native Diffuse、DXR alpha 遍历、Player 或任意材质矩阵。近区颜色用于确认捕获来自裁剪前景，远区颜色用于确认洞口读到背板，不是新的辐照度误差参考。

## 准备失败与纠正

首轮在零渲染请求时因输入检查终止：URP 导入把资产副本的 `_AlphaToMask=0` 恢复成 1。实际材质和失败已保留在[首轮输出](<I:/Unity test/Comparison/AlphaCoverage124>)。锁定 URP 的 `BaseShaderGUI.cs` 会在导入验证中重写该属性；这不是观察到的覆盖产品错误。

Astra Max 允许一次纠正：在 Play 的 Start 中使用不经导入的运行时材质副本，维持原输入断言、域与容差。纠正的首次启动准备又遇到脚本循环变量覆盖日志名，Unity 启动器在进程启动前拒绝了文件名；该准备目录也保留，随后仅修复独立日志变量。唯一形成覆盖数据的运行正常结束，native exit 0，Editor 场景与 Quality 设置恢复。上述失败不追认为产品通过，也没有隐藏为成功运行。

[数据与判断](result.json) · [实测平面及固定域](signals.npz) · [读取脚本](analyze.py) · [有效运行](<I:/Unity test/Comparison/AlphaCoverage124RuntimeInput>) · [原生退出及恢复](<I:/Unity test/Comparison/AlphaCoverage124RuntimeInputSetup>) · [启动准备失败保留目录](<I:/Unity test/Comparison/AlphaCoverage124CorrectedSetup>)

Astra Max 已复核，认可上述限定覆盖合同可以关闭并收束；本轮没有产品修复，不追加变体、运行或构建。其他 T2 条款继续开放。
