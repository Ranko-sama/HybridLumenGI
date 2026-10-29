# Release72 当前修复整合

2026-10-29，产品来源 `13f31ec3e3edcd4634de44712d3f26498a96777e`。本次将[引导权重与接收面几何解耦修复](ReviewBrief-GuidingReceiverGeometry01.md)整合进普通 Player；已包含此前的未知缓存连接与动态历史上限修复。普通导航、薄板形变入口和有限检查 Host 与 Release71 字节一致。

双程序集预检、Windows x64 / Mono / DX12 / Linear Release 构建、一次真实 Player 检查均通过。112 个产品源、8 个临时接线文件、189 个产物、实际 Feature/Cube 输入及工程恢复已核对。构建保留 23 条 warning、0 errors；产品与 Unity 部署保持一致。

后台检查使用既有显式 StandardRequest 路径：相机禁自动渲染，连续引擎帧 1–120 各提交一次完整 URP 请求。请求、相机 begin/end、上下文 begin/end 均为 120，GI 持续推进；末帧 Final HDR/EXR/PNG 有效且数值有限，native exit0、watchdog 未触发。主代理已查看实际 PNG。这些结果验证当前源码整合，不构成物理图像或整体动态画质验收。

首帧等待 **121.382996 秒**。用户报告同时运行游戏、占用 GPU；未独立测量占用，本次耗时不用于判断性能回退或改善。普通 OS 按键与自动隐藏相机没有重新验收，相关历史来源保持不变。

当前入口：[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease72/Start-LocalRelease.cmd>)。默认常驻，空格启停薄板形变，WASD/QE/方向键移动，R 复位相机，Esc 退出。有限后台检查不会随普通启动自动执行；Release71 保留回退。

[构建资格](../LocalComparison/Review/current-local-release-72/build-analysis.json)、[Player 资格](../LocalComparison/Review/current-local-release-72/native-explicit/analysis.json)、[实际运行](../LocalComparison/Review/current-local-release-72/native-explicit/run/release-result.json)、[Final 预览](../LocalComparison/Review/current-local-release-72/native-explicit/run/frame-0119.png)、[并行游戏条件](../LocalComparison/Review/current-local-release-72/run-environment.json)。整体画质、默认多次反弹、性能、显存及 G0–G5 继续开放。
