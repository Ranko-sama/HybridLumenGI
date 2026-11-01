下载 **HybridLumenGI-Release98-Windows-x64.zip** 并完整解压。双击 `Start-LocalRelease.cmd` 运行 Windows 演示，双击 `PictureComparison\index.html` 离线查看颜色反弹与动态响应。两个入口和五张原图都在同一包内。

Release98 修复统一示例 C 键对静态红墙的换色。材质槽已有独立属性块时，现在也会变蓝，并保留该槽的金属度等其他属性。再次按 C 或关闭交互会恢复原块。没有槽级覆盖的槽继续继承 Renderer 级颜色。无图形设备的 Unity 6000.0.85f1 编辑器使用真实 Renderer 检查了有槽级覆盖与继承两种情况，同一进程完成 Windows x64 普通 Release 构建，0 个错误、23 条警告。产品源码 `183d2fb8a7d13f4b07046575a3fba160bba55fba`。

随附页面汇集四项已有画面对照，包括静止时与独立参考的颜色误差、换色与关灯后的残留、门运动与停止后的轮廓，以及恢复灯光后第 30／59 帧的亮度。图像与数据保留 Release78、83、88／92、93 的采集来源和局限。

统一示例默认 960×540、半分辨率 GI、2 条射线、4 级空间滤波，优先 DXR。开发环境为 Windows x64、Mono、DX12、Linear、URP 17.0.4、RTX 2080 Ti。G0 本机基线已锁定，G1–G5 仍开放。完整操作与许可证见包内 `READ-ME-FIRST.md`。[项目首页](https://github.com/Ranko-sama/HybridLumenGI)
