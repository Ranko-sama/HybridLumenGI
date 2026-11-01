下载 **HybridLumenGI-Release100-Windows-x64.zip** 并完整解压。双击 `Start-LocalRelease.cmd` 运行 Windows 演示，双击 `PictureComparison\index.html` 离线查看画面对照。

Release100 在相机诊断中显示 HLOD 预热时最近一次读回的首个可归属覆盖阻断。普通示例按 F2 后可在日志中查找 `lastHlodCoverageBlock`。Unity 编辑器的 **Tools > Hybrid Lumen GI > Validation > Log Runtime Diagnostics** 也提供这项信息。读回明确观察到阻断时，记录会列出工作帧、对象、卡序号、物理卡索引和原因，帮助区分必需 chart 没有可用覆盖与已覆盖 patch 尚在积累。该记录的解释范围限于对应工作帧的首个阻断，覆盖面积和整景收敛仍需另行判断。

离线页面在原有五张颜色与动态对照图之外收录了 Release99 白炉 PNG、对应的原始线性 EXR，以及 V209 全金属与黑色接收面的合成前后对照。新普通包内共有七张 PNG，均保留来源版本。旧版独立附件仍为原来的五张图。

普通示例沿用 960×540、半分辨率 GI、每像素 2 条射线、4 级空间滤波，优先 DXR。开发环境为 Windows x64、Mono、DX12、Linear、Unity 6000.0.85f1、URP 17.0.4、RTX 2080 Ti。产品源码 `192afe9f83412097fb9efb2e7adbeb6e6fd62474`。操作与许可证见包内 `READ-ME-FIRST.md`。[项目首页](https://github.com/Ranko-sama/HybridLumenGI)
