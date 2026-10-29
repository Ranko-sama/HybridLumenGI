# 完整 Feature 的有限色墙参考

2026-10-29。当前产品源码保持 `269241b` 的两项修复；本轮新增独立参考、临时观察接线和真实场景验证，没有修改产品行为。

## 结果

RTX 2080 Ti / DX12 / Unity 6000.0.85f1 上，完整 Feature 的 `CSTrace raw E/pi` 在 **27 个预选地面像素全部符合独立有限射线参考**。216 条采样输入射线由独立平面／矩形求交得到 47 次色墙命中，覆盖每像素 0、1、2、3、4 次命中。额外除以 π、交换颜色通道、把未知测量视作有效的三个负例均被拒绝。

场景只有一个白色方向光、一个有限色墙和一个水平接收面。色墙通过真实 URP Lit / MPB 设置线性底色 `(0.5,0.25,0.125)`，独立反射率为 `(0.48,0.24,0.12)`；源几何、材质、灯光与设置都记录实际值。关闭环境、屏幕追踪、引导、发光采样、多次反馈、时域与滤波，单独核对一次反弹。参考不接收产品命中结果或 RGB。

例如近处中心像素八条射线中有两条命中色墙，独立期望为 `(0.12,0.06,0.03)`，真实 RGBA16F 存储读回为 `(0.1199951172,0.0599975586,0.0299987793)`。零命中点得到已知黑色，而非未知值。比较使用运行前冻结的 binary32 运算界和半精度存储界。

## 来源闭合与保留的失败

第一次场景执行完成 180 次完整渲染，但观察器把关闭选灯统计时的 `-1` 标记误要求为 0，导致没有选择样本；空的初始场景恢复也报错。[01 原记录](../LocalComparison/Review/finite-wall-color-reference-01/result.md)保留。修正观察器后，02 完成两次显式 `StandardRequest` 渲染，四类相机／上下文回调均为两次，捕获第二次实际 Gather 的 `Work.frame=0`，而非从前一帧诊断猜测帧号。

02 原始输入解码仍有一个失败：18 个点的 GPU 地面逆投影偏差超过最初固定世界空间界。该判据遗漏了光栅顶点子像素吸附。原解码器及失败保持不变，另以实际矩阵、已知地面和规范的子像素精度计算独立输入一致性区间，再用逐运算向外取整区间核对逆投影。27 点符合该限定区间；其深度吸附界由源数据和规范计算，未从观测残差拟合。它是来源一致性检查，不宣称穷尽所有前向变换／裁剪实现误差。精度依据为 [Direct3D 11.3 Functional Specification §3.2.4.1、§3.4.1、§15.16](https://microsoft.github.io/DirectX-Specs/d3d/archive/D3D11_3_FunctionalSpec.htm)。

颜色比较在独立期望生成、112 个产品文件、8 个观察文件、实际场景与输入来源核对后进行。没有重跑 GPU，没有改原始射线、RGB、数学参考或颜色阈值。临时工程文件已归档并移除，112 个产品源及原有 QualitySettings、GraphicsSettings、Functional 场景均恢复／保持一致。

## 范围与后续

此结果证明当前完整 DXR 链路在指定单次反弹场景、有限射线输入下的颜色与能量比例一致。解析色墙积分另给出无限样本参考，但不拿它要求一帧八射线无噪声。它不证明采样分布、默认多次反弹、遮挡复杂场景、动态画质或生产性能全部正确。

下一项验证接收面在色墙 MPB 变色、方向灯关闭后的真实 raw、历史和失效输入，区分允许的短期混合与漏失效／旧可信颜色。

证据：[比较结果](../LocalComparison/Review/finite-wall-color-reference-02/native/finite-comparison-qualified.json)、[独立期望](../LocalComparison/Review/finite-wall-color-reference-02/native/finite-reference-qualified.json)、[实际输入资格](../LocalComparison/Review/finite-wall-color-reference-02/native/rays-native-qualified.json)、[原始首次失败](../LocalComparison/Review/finite-wall-color-reference-02/first-analysis-failure.json)、[独立参考说明](../LocalComparison/Reference/ColorBounceRectangle/README.md)。
