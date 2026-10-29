# 真实相机移动与 TAA：覆盖失败及身份中断

2026-10-29，产品来源 `13f31ec3e3edcd4634de44712d3f26498a96777e`。一次固定 48 帧 Unity / DX12 完整 URP 采集已完成，**整体运动/TAA验收仍失败**。原输出判据在 43 个合格显露点和 462 个持续可见控制点未发现违例，但第 38、39 帧没有合格显露点，第 41–43 帧没有足够控制点，不能以局部通过替代整体覆盖。

场景、相机路径、264 个作者点、32 帧预热、真实 High TAA、非零 jitter、历史参数及覆盖门槛均在运行前固定。三块有限平面静止，相机在第 32–39 帧平移后停稳；关闭引导、缓存反馈、屏幕追踪和过滤以隔离历史对应。原始 48 帧和三张上下文预览全部保留。112 个产品文件与当前部署一致，9 个临时源及工程恢复经独立核验；没有为补判追加 GPU 帧。

下一步具体问题是按表面发生的身份中断：第 37 帧全部 69 个面板法线样本、第 41 帧全部 206 个地面法线样本的候选和身份为零，同帧另一表面仍正常。33 个地面控制点的实际历史年龄在第 40–44 帧依次为 32、1、1、2、3；第 41、42 帧实际输出等于当前 raw。第 2–47 帧所有已捕获的同像素前驱记录均逐字节闭合，降低了观察器错绑的可能，仍只证明已观察地址。源记录与变化控制保持稳定；目前没有记录身份片元的三路深度，不能直接归因严格深度比较、矩阵精度或某个渲染调用。原完整结果继续为 FAIL，诊断不会降低覆盖门槛。详见[身份中断诊断](../LocalComparison/Review/camera-motion-taa-response-02/diagnosis/README.md)。

输入准备和分析中的原失败也完整保留：

- 01 包在首帧因临时观察 shader 缺少 identity 宏隔离而失败，未进入移动；02 仅为该观察代码增加宏隔离，并完成三后端、普通与 identity 共 18 个完整入口编译。
- 02 日志扫描器从 `readbacksDrained:true` 跨 JSON 字段匹配到材质状态 `GPU completion unproven`。独立、精确到原日志行哈希的资格核对了结构化结果及所有其他错误规则，原执行 FAIL 未改写。
- 原分析器要求包含代数的来源记录从第 0 帧起完全相等，超出了合同预热窗口。全 48 帧物理字段不变，唯一代数变化在第 1 帧且实际历史无效；单独资格要求第 30–47 帧完整记录固定，原历史/输出门保持不变。具体初始化调用者未被记录。
- 后续分析在作者点坐标处失败。48×264 个实际作者点均精确匹配 binary32 字面量的有理数乘加后最终 RN32 存储；旧模型却逐步舍入中间乘积。新的独立输入资格只校验此 C# 表达式并把实际作者点交给原投影检查，没有添加 epsilon、修改像素或输出条件。[C# 规范允许较高精度中间运算](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/types#837-floating-point-types)，本次不宣称识别了具体 JIT 指令。

最终同数据分析记录 17 个非零 jitter 帧。43 个合格显露点的历史四分量与当前 raw 精确相等、年龄为 1；462 个合格控制点保持有效历史且年龄大于 1；这些合格样本中 unknown 和输出违例均为 0。未合格输入和五项覆盖失败仍单列，不外推绝对拖影、默认采样分布或整体动态画质。

[原合同](../LocalComparison/Review/camera-motion-taa-response-02/contract.txt)、[最终同数据 FAIL](../LocalComparison/Review/camera-motion-taa-response-02/analysis-source-expression-qualified.json)、[执行/恢复资格](../LocalComparison/Review/camera-motion-taa-response-02/qualification-log/result.json)、[初始化来源资格](../LocalComparison/Review/camera-motion-taa-response-02/initialization-source-qualification/result.json)、[作者点精确输入资格](../LocalComparison/Review/camera-motion-taa-response-02/target-input-qualification/result.json)。用户报告同时游戏占用 GPU；采集耗时不用于比较性能，正确性标准保持不变。
