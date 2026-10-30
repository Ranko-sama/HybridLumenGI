# GPU监测／反馈控制不再撤销已有光照

2026-10-31，基线a98a99e。原目标2／3、G3／G4的一处使用行为修复，整体关卡保持开放。

此前Feature把完整Settings JSON的hash用于世界epoch、屏幕历史与HLOD readiness失效。普通UI的Off→Measure或目标毫秒调整也改变该值，即使场景、光照、材质和质量配置不变，仍撤销已有有效性。它不是立即清零所有缓冲，但会使后续路径不能继续正常复用已有光照。独立源码审查确认这与独立GPU计时／控制器代次的职责重复，未找到必须失效光照的理由。

改动只排除五个监测／反馈字段：measureGpuCost、preferNativeGpuTiming、adaptiveGpuBudget、targetGpuMilliseconds、minimumGpuWorkFraction。完整JSON变化时，用Settings浅复制将五个值类型字段规范化，再比较其余传输配置；不修改实时Settings，也不手工枚举其他字段。首次及其他设置变化仍撤销原历史/readiness；PrepareGpuBudget继续使用完整JSON。其余质量、debug、intensity和资源设置不放宽失效。

独立实现复核无阻断。必要验证限定为实际Unity Settings／JsonUtility的控制字段与传输字段区别、原Settings不被修改，再由同一Editor进程调用既有普通Release构建器。临时入口只存在于Editor目录，退出后移出Assets；没有Player、截图、成本窗口、新宿主或哈希校验。该检查不等于渲染后历史／GPU计时的原生整体验收。

## 采用与交付

源码`171e6fcba3b397e1bf6ceb250aa9c53f05899cde`已通过[实际Unity配置检查](settings-check.json)。临时Editor入口反射调用当前产品的TransportSettingsJson，用实际JsonUtility确认五项控制单独及组合改变完整计时配置而不改变传输配置、活Settings不被修改，ray／bounce变化仍能触发传输差异。独立结果复核确认没有复制被测逻辑；首次及三处失效动作的接线另由源码审阅确认。这不证明渲染后历史连续性或原生GPU计时行为。

同一Unity6000.0.85f1进程PID4260随后调用既有公开构建器，唯一普通Release96／None构建成功，0 errors／23 warnings保留，native exit0。Renderer、QualitySettings及初始化入口恢复，临时Editor目录已移出Assets；未启动Player或新观察器。[本机统一入口](<I:/Unity test/Comparison/Builds/LocalRelease96/Start-LocalRelease.cmd>)保留2ray／filter4／DXR与既有场景。

Astra同意有限采用和沿用既有打包流程。[Windows实验性演示包](https://github.com/Ranko-sama/HybridLumenGI/releases/tag/release96-demo)已发布至授权私有仓库，完整运行依赖、StreamingAssets及许可证随包保留；[发布状态](published-release.json)确认prerelease与已上传资产。仅关闭此配置职责混淆及发布整合，G0保持完成、G1–G5整体保持开放。既有画质、颜色和性能数据继续注明原版本，不改标96。
