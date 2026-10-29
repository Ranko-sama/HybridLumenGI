# 当前本机 Release73

入口：[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease73/Start-LocalRelease.cmd>)。

产品来源 `95a3213aedef41ac6a021c0723e73343abffd748`，新增[接收面身份与 URP 矩阵同源修复](ReviewBrief-CameraMotionTaaResponse03.md)。该修复已通过原 48 帧相机/TAA 回归；本次普通 Player 整合保留 Release72 的导航、形变和显式渲染 Host。

Unity 6000.0.85f1 / URP 17.0.4 / Windows x64 Mono / DX12 / Linear / RTX2080Ti。Release、None 构建成功，0 错误、23 警告；112 产品源、8 个构建接线文件和 189 个构建产物核对完成，Unity 工程与临时资产已恢复。

同一 EXE 完成一次 120 帧显式 `StandardRequest`：请求、camera/context begin/end 均为 120，连续引擎帧完整，正常退出，无 watchdog。末帧 Final RGBA32F 全有限，EXR/PNG 尺寸与来源核对通过，并查看了原生预览。首渲染等待 3.4737555 秒；用户同时游戏，缓存状态也未经控制，不能与旧等待时长比较为性能改善。

普通操作仍为 WASD 平移、Q/E 升降、方向键转向、R 复位、空格启停格纹薄板形变、Esc 退出，默认常驻。本轮没有重复 OS 键盘或普通自动隐藏渲染验收。静态 120 帧整合不替代相机/TAA 专项，也不代表全场景物理画质、动态收敛、性能或 G0–G5 完成。

证据：[构建与来源](../LocalComparison/Review/current-local-release-73/build-analysis.json)、[构建与资产恢复](../LocalComparison/Review/current-local-release-73/analysis67-build.json)、[真实运行](../LocalComparison/Review/current-local-release-73/native-explicit/analysis.json)、[原生预览](../LocalComparison/Review/current-local-release-73/native-explicit/run/frame-0119.png)。历史 [Release72](ReviewBrief-CurrentLocalRelease72.md) 保持其 `13f31ec` 来源。
