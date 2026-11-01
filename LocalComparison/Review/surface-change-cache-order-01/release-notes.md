下载 **HybridLumenGI-Release99-Windows-x64.zip** 并完整解压。双击 `Start-LocalRelease.cmd` 运行 Windows 演示，双击 `PictureComparison\index.html` 离线查看颜色反弹与动态响应。两个入口和五张原图都在同一包内。

Release99 为受局部表面变化影响的世界缓存增加了更新优先级。已发布的墙面换色后，当每帧名额有限，追踪距离内的接收面可以排在远处接收面之前。在固定的四项 CPU 调度对照中，按「最久未服务项、远端接收面、墙面、近端接收面」排列，三个名额的选择从 `1,1,1,0` 变为 `1,0,1,1`。此结果说明实际调度次序。画面颜色误差、换色或关灯残留、运动拖影和开灯恢复程度沿用对照页中的历史图片与测量，采集版本为 Release78 至 Release93。

GPU 面板已说明更改计时与预算反馈控制会重置计时和反馈，同时保留光照历史。普通示例沿用 960×540、半分辨率 GI、2 条射线、4 级空间滤波，优先 DXR。开发环境为 Windows x64、Mono、DX12、Linear、URP 17.0.4、RTX 2080 Ti。产品源码为 `e20759384555c918e1a91b48665082cbe9a0942c`。操作与许可证见包内 `READ-ME-FIRST.md`。[项目首页](https://github.com/Ranko-sama/HybridLumenGI)
