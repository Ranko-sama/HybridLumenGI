HybridLumenGI — 本机普通 Release44

双击 Start-LocalRelease.cmd 启动。窗口保持运行，点击关闭按钮退出。
使用既有 Functional 初始视图；不执行自动门运动、材质修改、形变测试或阶段截图。
窗口640×360沿用有限验证尺寸，不是生产目标。配置偏好DXR，保留产品回退规则。
日志写入本目录 local-release.log。请保留EXE、完整Data目录及随附文件。

Windows x64 / Mono / Direct3D12 / Linear，BuildOptions.None。
产品源码来自5120a8c，包含附加视点冷加载需求、SDF未完成查询传播及可选合并形变请求。
静态场景运行不代表新API分别获得原生覆盖或动画同步验收。

默认启动不计帧、不采样诊断、不自动退出。
独立参数 -localReleaseSteady300 配合新的绝对 -localReleaseOutput 目录才会开启固定300秒公开计账验证。
旧 -localReleaseVerify120 仍保留，本轮未重复运行。

来源、完整产物清单、首次固定窗口结果：仓库 LocalComparison/Review/local-release-steady-use-01。
是否通过本次有限窗口以该目录native-window/analysis.json为准，本文不提前宣告结果。
公开计账不等于驱动总VRAM；不代表完整画质、性能、生产长测或所有平台验收通过。
