下载 **HybridLumenGI-Release96-Windows-x64.zip**，完整解压后运行 `Start-LocalRelease.cmd`，无需Unity编辑器。GitHub自动生成的Source code压缩包不是可运行演示。

Release96修复普通GPU监测／反馈控制触发无关光照失效：Measure only、计时提供器偏好、反馈开关、目标毫秒及最低工作比例，现在独立刷新计时与控制器，保留已有世界缓存、屏幕历史和HLOD就绪。其他物理／质量设置保持原失效规则。产品来源 `171e6fc`，实际Unity Settings检查与普通Release构建支持此次整合，没有新增Player或采集。

统一示例保持960×540／半GI／2ray／filter4、DXR偏好，以及95高反射率直接反弹修复和94骨骼停稳历史。操作、依赖与许可随包保留。

这是实验性版本。G0本机基线已锁定，G1–G5仍开放；整景颜色、多跳残留、完整运动／精确收敛及长时负载未完成，CI暂缓。25ms／1GiB起始预算的已有有限依据仍属93，不改标96。本机为Unity6000.0.85f1／URP17.0.4、Windows x64／Mono／DX12／Linear、RTX2080Ti，其他设备未完成验收。完整边界见[项目首页](https://github.com/Ranko-sama/HybridLumenGI)。
