下载 **HybridLumenGI-Release95-Windows-x64.zip**，完整解压后运行 `Start-LocalRelease.cmd`，无需Unity编辑器。GitHub自动生成的Source code压缩包不是可运行演示。

Release95修复合法高反射率材质在屏幕／世界命中间的直接反弹差异：直接项保留真实rho，0.98仅用于递归缓存反馈。保留统一示例960×540／半GI／2ray／filter4、DXR偏好及94骨骼停稳历史。产品来源 `1503738`，既有函数检查与一次普通构建支持此次整合，没有新增Player、画面或成本采集。

这是实验性版本。G0本机基线锁定，G1–G5仍开放；整景颜色、多跳残留、完整运动／精确收敛及长时负载未完成，CI暂缓。25ms／1GiB预算的既有有限结果仍属Release93，不改标为95。0.98反馈限制仍会给高阶反弹引入偏差。

本机环境：Unity6000.0.85f1／URP17.0.4、Windows x64／Mono／DX12／Linear、RTX2080Ti。其他设备未完成验收。操作与第三方通知随包保留，完整适用范围见[项目首页](https://github.com/Ranko-sama/HybridLumenGI)。
