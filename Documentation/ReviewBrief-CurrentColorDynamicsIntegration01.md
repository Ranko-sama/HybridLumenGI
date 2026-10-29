# 当前颜色与动态修复的原生整合

2026-10-29，按完整原计划继续本机开发，不使用 Codex with ChatGPT。本轮产品来源为 `269241b38c45a97f29758fb92640cdb36f5092f8`，两个修复见[源码结果](ReviewBrief-ColorBounceDynamicLimits01.md)。

## 已确认结果

- Unity 6000.0.85f1 / RTX 2080 Ti / DX12 / Linear 使用完整当前 `CSTemporal` 和 `CSTemporalIdentity`，在真实 RGBA16F 历史、RGBA32F moments 与 UInt4 身份纹理上完成 168 次计算。
- 两入口各七个固定用例、事件与恢复共 28 行通过。`maxHistory=1` 的变化帧实际 RGB 为当前值 `1.03125`，历史长度保持 1；56 份完整纹理原始读回保留。固定几何和合成信号验证不等同于整景动态画质验收。
- Release70 使用当前 112 个产品源文件构建成功，构建记录列出 188 个产品文件；双程序集预检、构建来源、实际 Feature 的既有静态 Cube 配置和临时工程恢复核对通过。Unity 部署保留当前两个产品修复。
- 首次离线数据复读错误要求 moments 逐位相等，修正为原生合同原有的 `0.000002` 界；RGB 与历史长度仍精确比较。没有改原生输出、报告或原生阈值，没有为此重跑 GPU。

## 未通过的运行检查

同一个 Release70 在隐藏普通模式及隐藏 batch 模式下，均在接到第一个相机渲染回调前达到既有 120 引擎帧启动界，exit1、实际相机帧 0。两次记录完整保留；未增加启动阈值、未把设备创建当成渲染通过。现有日志不足以确定根因，不能宣布普通 Player 运行验证完成。

Release70 已构建，但当前已完成运行验证的使用基线仍是 Release69。新颜色参考场景将采用本地 URP 支持的显式 `RenderPipeline.StandardRequest` 路径，区分后台自动相机调度与完整 Feature 执行；不会以此回填 Release70 两次失败。

## 原始证据

[汇总资格记录](../LocalComparison/Review/current-color-dynamics-integration-01/qualification.json)、[原生纹理报告](../LocalComparison/Review/current-color-dynamics-integration-01/native-temporal-report.json)、[构建来源](../LocalComparison/Review/current-color-dynamics-integration-01/build-analysis.json)、[首次播放器失败](../LocalComparison/Review/current-color-dynamics-integration-01/native-window/run/release-result.json)、[batch 失败](../LocalComparison/Review/current-color-dynamics-integration-01/native-batch/run/release-result.json)。

原计划的颜色参考、整景动态质量、生产性能和 G0–G5 继续推进，未因本次局部通过而标为完成。
