# 额外材质槽的精确覆盖资格

Unity 在材质槽多于子网格时，用额外槽重复绘制最后一个子网格。Release198 对这种布局仍按一槽一子网格解释，导致精确查询可从首槽透明处穿过实际可见的额外槽。修复在几何准入和录制前重抓使用同一规则。额外槽若能绘制末子网格，整个对象沿用现有 SDF／解析后备。末子网格无索引时保留原准入规则。[Unity 6.0 材质槽规则](https://docs.unity.com/en-us/engine/6000.0/manual/assets-and-media/asset-types/mesh/components-reference/class-mesh-renderer#materials) · [运行时代码](../../../Runtime/HybridLumenGIHardwareBackend.cs)

实机使用 Unity 6000.0.85f1、Direct3D12 和 RTX 2080 Ti。两个普通 URP Lit 网格各有一个子网格。近板主槽 alpha 为 0，阈值为 0.5，额外槽为不透明绿色，后板为不透明蓝色。固定射线沿 +Z，近板三角在 t=1，后板三角在 t=2。原生相机只用于确认中心覆盖。软件和 DXR 各自准备实际几何和材质，调用产品混合表面与阴影查询。候选在同一 Release198 工程仅覆盖 `HybridLumenGIHardwareBackend.cs`。

| 近板状态 | 原生中心颜色 | Release198 软件／DXR | 修复版软件／DXR |
| --- | --- | --- | --- |
| 单裁剪槽 | 蓝 | 后板精确，t=2 | 后板精确，t=2 |
| 增加不透明槽 | 绿 | 后板精确，t=2 | 近板解析，t≈0.999 |
| 撤去额外槽 | 蓝 | 后板精确，t=2 | 后板精确，t=2 |

加槽后重新准备前，两个旧精确批次均通过了原版的材质重抓，修复版明确以槽布局不匹配拒绝。随后两个对象继续发布，近板转入解析 Box，后板保持精确。撤槽恢复两个精确对象，两侧均正常退出。[Release198 原生及查询读数](baseline.json) · [修复版查询读数](fixed.json)

首次观察的中心颜色太暗，未提交查询。改用固定方向光后得到原定覆盖依据，几何与裁剪条件沿用原输入。更正后的旧版在原生相机请求之后立即结束时记录了待退休缓冲与 D3D12 退出警告。修复侧的项目退休记录清空，D3D12 报告内部 scratch 资源警告。采用范围为材质资格和混合遮挡。完整叠绘颜色、纹理覆盖及正常 Player 资源生命周期继续按各自条款验收。[首次资格不足](initial-insufficient.json) · [旧版日志](<I:/Unity test/Logs/ExtraMaterialSlots235BaselineCorrected.log>) · [修复版日志](<I:/Unity test/Logs/ExtraMaterialSlots235Fixed.log>)
