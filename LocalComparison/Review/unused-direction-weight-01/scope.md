# 跳过未消费的方向权重

原目标4的有限性能候选，基于Release83／0181ef2。当前用户目标为960×540／30 FPS；此候选只判断GI区间的成本，不承担实际呈现帧率验收或替用户设置GI／显存预算。

`CSTrace`和`CSUpdateCache`先调用方向sampler，再立即调用面积光Matched权重。面积光开启时，后者不读取sampler的旧weight。一次当前完整精确软件CSTrace的DXC `-O3`编译确认第一次vMF PDF求和仍在：本目录保留的`baseline-cstrace.ll`第64458–64580行先遍历proposal，64609–64612才判断面积光开关，64773–64895又遍历，64915–64924选择第二次权重。该产物不是驱动最终机器码或毫秒测量。

候选只在这两个caller明确会覆盖权重时，跳过sampler末尾的PDF／weight求值。方向生成及RNG已完成，skip分支显式写weight=0；Matched原算术及拒绝门不变。面积光关闭与emissive关闭保持原路径。不同PDF表达的浮点分组不同，因此不直接复用旧PDF数值。

Astra及独立源码审查认可限定范围。一次已有WARP宿主的真实函数配对已通过，原始结果保留在`finite/output/result.json`；它仅证明固定输入下的方向、RNG、有效权重及拒绝语义，不证明完整图像等价或性能。适配器只将proposal资源装为线程内固定数组，并提升caller局部变量以观察结果；详见`finite/README.md`。

性能决定在候选运行前写入`retention-criterion.json`：复用Release83既有观察器、保存场景、960×540／半分辨率GI／精确软件／反馈关闭和同一固定源窗口；不新增query、图片或分pass探针。唯一候选窗口须完整，GI合计中位至少降低5%，全部64帧块中位低于基线全部块，p95/p99不增。任一不满足就恢复候选并结束，不补跑或调参。这是有限工程取舍，不是显著性证明或G5放行。

编译命令：Windows SDK 10.0.26100.0 x64 `dxc.exe -T cs_6_0 -E CSTrace -O3`，使用现有`TEMP/HybridLumenGI-shader-validation` includes与`Runtime/Resources/HybridLumenGI`，定义`SHADER_API_D3D11=1`、`SHADER_STAGE_COMPUTE=1`、`UNITY_COMPILER_DXC=1`、`UNITY_VERSION=600000`，输入`HybridLumenGIExactSoftware.compute`；exit0，无诊断。没有新hash核验。
