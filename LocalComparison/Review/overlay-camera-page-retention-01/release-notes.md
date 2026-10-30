下载 **HybridLumenGI-Release97-Windows-x64.zip**，完整解压后运行 `Start-LocalRelease.cmd`，无需Unity编辑器。GitHub自动生成的Source code压缩包不是可运行演示。

Release97修复活动相机Base→Overlay后的旧GI页需求残留：卸载协调不再把已停止运行GI的Overlay相机旧场景当作消费者。缺少AdditionalCameraData时仍按Base，Scene View保留URP强制Base规则。其他相机及原最终context fence／lease退休条件保持；没有主动清空全部CameraState。

产品来源 `3de97f4`，独立源码审阅与一次普通Release构建支持此次整合，没有新Player、图像或内存窗口。统一示例保持960×540／半GI／2ray／filter4、DXR偏好，保留96计时控制隔离、95直接反弹修复及94骨骼停稳历史。操作、依赖与许可证随包保留。

这是实验性版本。G0本机基线已锁定，G1–G5仍开放，CI暂缓；本次不代表Base→Overlay完整资源生命周期实机通过。颜色、动态响应和25ms／1GiB起始预算的既有有限依据保持原版本来源。本机Unity6000.0.85f1／URP17.0.4、Windows x64／Mono／DX12／Linear、RTX2080Ti，其他设备未完成验收。完整边界见[项目首页](https://github.com/Ranko-sama/HybridLumenGI)。
