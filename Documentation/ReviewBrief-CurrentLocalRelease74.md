# 当前本机 Release74：统一交互示例

入口：[Start-LocalRelease.cmd](<I:/Unity test/Comparison/Builds/LocalRelease74/Start-LocalRelease.cmd>)。

本版本关闭了原计划中“分页/HLOD、软件/DXR、动态操作各自分散，缺少一个普通可用入口”的缺口。同一场景提供相机导航、近远表示、分页释放/重载、软件/DXR 偏好、墙面换色、灯光开关、门移动和真实网格形变。默认常驻，历史 Release73 保留。

操作：WASD 平移，Q/E 升降，方向键转向；1/R 近景、2 远景、3 离开；4 软件、5 DXR 偏好；C 红/蓝墙，L 灯开关，M 门运动，空格形变启停；B 释放/重载组，F1 隐藏面板，Esc 退出。关灯保留发光面；停止形变后异步 GI 快照可能继续追上。

构建包含[全局照明变化后的屏幕历史修复](ReviewBrief-GlobalLightHistoryReset01.md)。实际 Unity 构建及同 EXE 的有限场景整合通过，临时工程设置已恢复；普通窗口实际执行了换色、形变启停、前移与正常关闭。没有额外展开键盘、退出或性能矩阵。

当前适用范围是 Unity 6000.0.85f1 / URP 17.0.4、Windows x64 Mono、DX12、Linear、单相机；分页组为三个简单静态接收体与一个保留三角形的 aggregate，其余场景仍常驻。实际后端以面板诊断为准；资源估算不是总 VRAM。默认 960×540 窗口不是生产性能目标。

[首批独立画面对照](../LocalComparison/Review/dynamic-picture-comparison-01/index.html)回答颜色误差、换色/关灯残留、运动拖影和收敛时间。其720序列图保持修复前来源，不能宣称是本版本修后画质。完整颜色准确度、局部换色和多跳缓存残留仍有缺口；G1–G5 未因此关闭。

来源与必要交付记录：[构建](../LocalComparison/Review/current-local-release-74/build-analysis.json)、[运行](../LocalComparison/Review/current-local-release-74/run-verification-first.json)、[实际构建来源](../LocalComparison/Review/current-local-release-74/instrumentation/manifest.json)。
