# Release71 当前修复整合

2026-10-29，产品来源 `269241b38c45a97f29758fb92640cdb36f5092f8`。Release71 已包含缓存未知材质覆盖和 reactive 历史上限两项修复，普通交互和连续形变示例沿用 Release69。

本次双程序集预检、Windows x64 / Mono / DX12 / Linear Release 构建和一次 Player 运行均通过。112 个产品源、8 个临时接线文件、189 个产品文件、实际静态 Cube 配置与恢复记录已核对。产品及原工程输入恢复保持一致。

隐藏 Player 使用新增的显式参数 `-localReleaseExplicitRequest`，与 `-batchmode -localReleaseFinalImage120` 配套。相机禁自动渲染，每引擎帧提交一次完整 URP StandardRequest。120 次请求、相机 begin/end 和上下文 begin/end 均为 120，GI 状态持续推进，最终 HDR/EXR/PNG 读回有效，native exit0。**首次渲染等待 99.2426 秒**，这一限制保留；未采集或认证稳态性能。

该后台路径解决了本轮验证时自动相机无回调的问题；Release70 的两次失败未回填。普通默认分支保留原行为，本轮没有重新验收操作系统按键，也不将显式请求结果冒充自动隐藏渲染通过。

本机入口：[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease71/Start-LocalRelease.cmd>)。默认常驻，空格启停薄板形变，WASD/QE/方向键移动，R复位相机，Esc退出。Release69 保留回退。有限后台检查不会随普通启动自动执行。

[运行资格](../LocalComparison/Review/current-local-release-71/native-explicit/analysis.json)、[原始结果](../LocalComparison/Review/current-local-release-71/native-explicit/run/release-result.json)、[Final预览](../LocalComparison/Review/current-local-release-71/native-explicit/run/frame-0119.png)、[构建来源](../LocalComparison/Review/current-local-release-71/build-analysis.json)。图像采用既有固定映射；该工程演示环境不是物理参考，颜色正确性另见[独立有限色墙证据](ReviewBrief-FiniteWallColorReference02.md)。整景动态、默认多次反弹、性能、显存和 G0–G5 继续开放。
