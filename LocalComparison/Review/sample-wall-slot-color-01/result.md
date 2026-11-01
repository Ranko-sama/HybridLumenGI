# 统一示例换色与离线画面对照

Release98 的 C 键支持带材质槽属性覆盖的静态墙。此前，即使一个槽只覆盖了金属度，它也会优先读取自己的属性块。按钮显示已换蓝，该槽却继续显示原色。默认示例墙的既有测量使用 Renderer 级换色。此次修复面向同一公开示例入口所接受的带槽覆盖的墙。

交互启动时保存 Renderer 属性块与已有非空槽块。按 C 只替换这些块内的 `_BaseColor`，再次按 C 或关闭组件时复用同一方法复原。空槽继续继承 Renderer 设置。适用范围是交互拥有换色操作、材质槽布局固定的普通静态墙。

Unity 6000.0.85f1 使用无图形设备，在同一面墙上调用普通换色及复原入口。带 `_Metallic=0.375` 的槽变蓝且保留金属度，复原后移除临时颜色。另一槽在整个操作中均无槽块，由 Renderer 的颜色覆盖控制。该进程随后以 Release／None 构建原保存的 Windows x64 普通场景，0 个构建错误、23 个警告，正常退出。源码为 `183d2fb`。[检查入口](WallColorBuildCheck.cs) · [构建输入](release-build-attempt.json) · [本机日志](<I:/Unity test/Logs/LocalRelease98Build.log>)

这一结果关闭了统一示例换色操作在合法槽覆盖输入下失效的缺口。照明层面的颜色误差、残留、拖影与恢复仍按各自采集版本解释。已将目标画质的现有原图、读数与不确定性整理到可离线打开的读图页。独立附件也可随 Release97 下载。[读图页](../picture-comparison.html) · [独立附件](https://github.com/Ranko-sama/HybridLumenGI/releases/download/release97-demo/HybridLumenGI-Release97-PictureComparison.zip)

已发布的 Windows x64 包大小为 40,822,029 字节。完整解压后，`Start-LocalRelease.cmd` 运行示例，`PictureComparison/index.html` 展示离线对照。包内 HTML 引用的五张原图均可按相对路径找到。[下载 Release98](https://github.com/Ranko-sama/HybridLumenGI/releases/download/release98-demo/HybridLumenGI-Release98-Windows-x64.zip) · [发布记录](published-release.json)
